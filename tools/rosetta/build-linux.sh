#!/bin/bash
# Build the two Rosetta binaries the pipelines call, natively, on CoreHPC.
#
#   rosetta_scripts   FastRelax under enzdes constraints
#   cartesian_ddg     the ddG shell
#
# Everything else in Rosetta is left unbuilt: scons still has to compile most
# of core/ and protocols/, but skipping the other ~70 apps is most of the time.
#
# This is NOT a port of pipelines/local/build_rosetta_macos.sh. That script
# exists to work around Apple clang: it writes a site.settings full of
# -Wno-error and patches vendored Boost, because clang >=16 makes
# enum-constexpr-conversion a hard error and Apple clang 21 no longer accepts
# the flag Rosetta uses to suppress it. gcc has never treated that as an error,
# so none of it applies here and copying it across would be cargo cult.
#
# WHY NOT A CONTAINER: every other entry in this registry is an image. Rosetta
# is native because the build is the expensive artifact (hours), the output is
# a plain static-ish binary with no python or CUDA stack to isolate, and the
# database is 3 GB of data files the binaries read at runtime -- exactly the
# thing that belongs on a share rather than inside a squashfs that has to be
# rebuilt to change one params file.
#
# LICENSING: Rosetta is free for academic/non-commercial use; commercial use
# needs a paid RosettaCommons licence. Cloning and building it is the PI's
# decision, not this script's.
#
#   build-linux.sh fetch      # LOGIN NODE  -- the only node with internet
#   build-linux.sh compile    # COMPUTE NODE -- under salloc/sbatch
#   build-linux.sh install    # either      -- publish into $PREFIX
#
# The split is not fussiness. Compute nodes reach no proxy that allows github
# (they get a 403, not a hang), and the login node's cgroup is 4 CPUs with a
# soft 8 GiB cap, so a 32-way compile there is throttled into uselessness and
# antisocial besides. Each half refuses to run in the wrong place.
set -uo pipefail

# Pinned, unlike the Mac script, which clones --branch main and therefore
# builds whatever HEAD happened to be that day. Week 38 of 2026 is the release
# current when this was first built, so a Mac built from main the same week
# matches. Bumping this changes ddG numbers: Gate 6 has to be re-run.
REF="${ROSETTA_REF:-v2026.38-dev62288}"

: "${CHPC_LAB:?not set -- source chpc.env first}"
# Derived with a fallback rather than required outright, the same way
# chpc-tool does it. The copy of chpc.env published on the share can lag the
# one in this checkout -- it did exactly that the first time this script ran,
# and a bare ${CHPC_SOFTWARE:?} turned "your env file is a few commits old"
# into "this build script is broken".
: "${CHPC_SOFTWARE:=$CHPC_LAB/software}"
PREFIX="${ROSETTA_PREFIX:-$CHPC_SOFTWARE/rosetta314}"
SRC="${ROSETTA_SRC:-/mnt/scratch/user/$USER/rosetta-build/rosetta}"
SUFFIX=default.linuxgccrelease

_say() { printf '[%s] %s\n' "$(date -u +%H:%M:%S)" "$*"; }
_die() { printf 'FATAL: %s\n' "$*" >&2; exit 1; }

# ------------------------------------------------------------------ fetch ---
do_fetch() {
  [ -z "${SLURM_JOB_ID:-}" ] || _die "fetch must run on the LOGIN node.
Compute nodes have no route to github: the compute proxy returns 403 for
github.com, so this would fail in a way that looks like a network hang.
Run it on the login node, then salloc for 'compile'."

  mkdir -p "$(dirname "$SRC")" || _die "cannot create $(dirname "$SRC")"
  if [ -d "$SRC/.git" ]; then
    _say "already cloned: $SRC ($(git -C "$SRC" rev-parse --short HEAD))"
  else
    _say "shallow clone of RosettaCommons/rosetta @ $REF (several GB, slow)"
    # --recurse-submodules matters: source/external/boost_submod is a submodule
    # and the build does not get far without its headers. --shallow-submodules
    # keeps it from dragging in their history too.
    git clone --depth 1 --branch "$REF" \
        --recurse-submodules --shallow-submodules \
        https://github.com/RosettaCommons/rosetta.git "$SRC" \
      || _die "clone failed"
  fi

  # Fail now, loudly, rather than 40 minutes into a compile on a node that
  # cannot fetch the missing piece.
  [ -d "$SRC/source" ]   || _die "no source/ in the clone"
  [ -d "$SRC/database" ] || _die "no database/ in the clone -- the binaries
need it at runtime and a compute node cannot fetch it later"
  [ -f "$SRC/source/scons.py" ] || _die "no source/scons.py -- Rosetta ships its
own scons under external/scons-local, so a missing one means a partial clone"
  _say "fetched: $(git -C "$SRC" rev-parse --short HEAD)  database $(du -sh "$SRC/database" 2>/dev/null | cut -f1)"
}

# ---------------------------------------------------------------- compile ---
do_compile() {
  [ -n "${SLURM_JOB_ID:-}" ] || _die "compile must run inside a Slurm allocation.
The login node is 4 CPUs with a soft 8 GiB cap; a Rosetta build there is both
throttled and antisocial. Try:

  salloc -p cpu -c 32 --mem=64G -t 8:00:00 --account hpc_core
  srun corehpc/tools/rosetta/build-linux.sh compile"

  [ -d "$SRC/source" ] || _die "no source at $SRC -- run 'fetch' on the login node first"
  cd "$SRC/source" || _die "cannot cd $SRC/source"

  JOBS="${JOBS:-${SLURM_CPUS_PER_TASK:-8}}"
  PY="$(command -v python3)" || _die "no python3"
  CXX_BIN="$(command -v g++)" || _die "no g++ on PATH"
  CXX_DIR="$(dirname "$CXX_BIN")"
  _say "gcc  : $(gcc --version | head -1)"
  _say "g++  : $CXX_BIN ($("$CXX_BIN" -dumpfullversion 2>/dev/null || echo '?'))"
  _say "scons: $PY $($PY --version 2>&1), -j$JOBS"
  _say "tree : $(git -C "$SRC" rev-parse --short HEAD)"

  # Rosetta's scons resolves the compiler through a SANITIZED PATH. Its
  # tools/build/settings.py does
  #     symbols["ENV"]["PATH"] = self.program_path
  # and basic.settings seeds program_path with the system directories, so the
  # build runs whatever `g++` is in /usr/bin -- while the *version detection*
  # that picks the warning flags runs through the PATH you actually have.
  #
  # On CoreHPC those are two different compilers. The modules give g++ 14.2.0
  # out of /opt/ohpc; /usr/bin/g++ is the OS 11.5.0. So scons configured for
  # 14.2 (the build tree is literally .../gcc/14.2/...), selected
  # -Wno-error=dangling-reference because that warning exists from gcc 13, and
  # then handed it to gcc 11.5:
  #
  #   cc1plus: error: '-Wno-error=dangling-reference': no option
  #   '-Wdangling-reference'; did you mean '-Wdangling-else'?
  #
  # Every single file fails, instantly, so the build dies in 11 seconds with
  # thousands of identical errors and no hint that two compilers are involved.
  # The fix is to make the compiler scons RUNS match the one it DETECTED.
  mkdir -p tools/build
  cat > tools/build/site.settings <<SITEEOF
# Generated by corehpc/tools/rosetta/build-linux.sh -- do not commit.
# program_path BECOMES the build's PATH (tools/build/settings.py:347), and its
# default is the system directories, which on this cluster hold an older g++
# than the one scons detects. Prepending the detected compiler's own directory
# is what keeps detection and execution on the same gcc.
#
# Wno-error: Rosetta compiles with -Werror plus a hand-maintained list of
# -Wno-error= exemptions (array-bounds, stringop-overread, restrict,
# dangling-reference). That list tracks the compilers upstream tests against,
# and gcc 14 raises warnings that are not on it. The first was
#   VectorOption_T_.hh:1111: 'frag_files...state_' may be used uninitialized
#                                            [-Werror=maybe-uninitialized]
# reached by inlining at -O3 from loops_main.cc:100 -- the textbook
# false-positive shape for that warning.
#
# Exempting them one at a time is a losing game: that failure came 1332 object
# files into a build of roughly ten thousand, so each new warning costs another
# multi-minute compile to discover. Warnings-as-errors is a policy for people
# DEVELOPING Rosetta. For a downstream build of a tagged release with a
# compiler newer than upstream tests against, it only converts "upstream tested
# with an older gcc" into "you cannot build this". The warnings are still
# printed; they are just not fatal.
settings = {
    "site" : {
        "prepends" : { "program_path" : [ "$CXX_DIR" ] },
        "appends"  : { "flags" : { "compile" : [ "Wno-error" ] } },
        "overrides": {},
        "removes"  : {},
    }
}
SITEEOF
  _say "site.settings: program_path prepends $CXX_DIR; -Wno-error appended"

  # Preflight the exact combination that failed, so a compiler too old for the
  # flags Rosetta will choose is caught in a second rather than in an hour.
  _probe="$(mktemp -d)/probe.cc"; echo 'int main(){}' > "$_probe"
  "$CXX_BIN" -Wno-error=dangling-reference -c "$_probe" -o /dev/null 2>/dev/null \
    || _die "$CXX_BIN does not accept -Wno-error=dangling-reference.
That flag needs gcc >= 13, and Rosetta selects it from the version it
detects. Load a newer compiler, or make gcc/g++ on PATH agree."
  rm -rf "$(dirname "$_probe")"

  # The target must be the binary's full filename. Given a bare app name scons
  # answers "Do not know how to make File target `bin/rosetta_scripts'", which
  # reads like the app does not exist. The naming is
  # <app>.<extras>.<os><compiler><mode>, per source/tools/build/utility.py.
  _say "building bin/{rosetta_scripts,cartesian_ddg}.$SUFFIX"
  "$PY" ./scons.py -j"$JOBS" mode=release cxx=gcc \
      "bin/rosetta_scripts.$SUFFIX" "bin/cartesian_ddg.$SUFFIX"
  rc=$?
  _say "scons exit $rc"
  [ $rc -eq 0 ] || _die "compile failed -- see above"
  ls -la bin/ | head
}

# ---------------------------------------------------------------- install ---
do_install() {
  [ -d "$SRC/source/bin" ] || _die "nothing built at $SRC/source/bin"
  mkdir -p "$PREFIX/bin" || _die "cannot create $PREFIX/bin"

  for app in rosetta_scripts cartesian_ddg; do
    b="$SRC/source/bin/$app.$SUFFIX"
    # scons writes bin/<name> as a symlink into build/; copy the target, not
    # the link, or $PREFIX/bin points back into a scratch tree that gets purged.
    [ -e "$b" ] || _die "missing $b -- did 'compile' succeed?"
    cp -Lf "$b" "$PREFIX/bin/$app.$SUFFIX" || _die "cannot install $app"
    chmod 755 "$PREFIX/bin/$app.$SUFFIX"
    # The short name too: 00_env_check.sh defaults ROSETTA_SUFFIX to
    # 'linuxgccrelease' when nothing sets it, and a bare name costs one symlink.
    ln -sf "$app.$SUFFIX" "$PREFIX/bin/$app.linuxgccrelease"
    _say "installed $app.$SUFFIX"
  done

  # The database is read at runtime and must outlive scratch. rsync rather than
  # cp so a re-install is cheap and interruptible.
  _say "syncing database (3 GB, once)"
  rsync -a --delete "$SRC/database/" "$PREFIX/database/" || _die "database sync failed"

  # Record what this actually is. The directory is called rosetta314 for
  # historical reasons and the content is a 2026 release; without this file the
  # only evidence of which source built these binaries is a scratch tree.
  {
    echo "ref       $REF"
    echo "commit    $(git -C "$SRC" rev-parse HEAD 2>/dev/null || echo unknown)"
    echo "built     $(date -u +%FT%TZ) by $USER on $(hostname)"
    echo "gcc       $(gcc --version | head -1)"
    echo "suffix    $SUFFIX"
  } > "$PREFIX/PROVENANCE"
  cat "$PREFIX/PROVENANCE"

  _say "verifying the installed binaries actually run"
  for app in rosetta_scripts cartesian_ddg; do
    "$PREFIX/bin/$app.$SUFFIX" -database "$PREFIX/database" -help >/dev/null 2>&1
    # Rosetta exits non-zero on -help; what matters is that it loaded the
    # database and got far enough to print usage, not the status code.
    "$PREFIX/bin/$app.$SUFFIX" -database "$PREFIX/database" -help 2>&1 \
      | grep -q . || _die "$app produced no output -- broken install"
    _say "  $app runs"
  done
  _say "done: ROSETTA_BIN=$PREFIX/bin ROSETTA_SUFFIX=$SUFFIX"
}

case "${1:-}" in
  fetch)   do_fetch ;;
  compile) do_compile ;;
  install) do_install ;;
  *) sed -n '28,32p' "$0"; exit 2 ;;
esac
