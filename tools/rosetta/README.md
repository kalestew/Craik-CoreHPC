# Rosetta

| | |
|---|---|
| Kind | `native` — built from source, not containerised |
| Upstream | `RosettaCommons/rosetta` @ `v2026.38-dev62288` (`06b084e5`) |
| Apps built | `rosetta_scripts`, `cartesian_ddg` — and nothing else |
| Installs to | `$CHPC_SOFTWARE/rosetta314` (`bin/`, `database/`, `PROVENANCE`) |
| Suffix | `default.linuxgccrelease` |
| Licence | free for academic/non-commercial; commercial needs a paid RosettaCommons licence |
| GPU | no |

Build it with [`build-linux.sh`](build-linux.sh).

## Why native, when everything else here is an image

The build is the expensive artifact — hours, not minutes — and the output is
a plain binary with no python or CUDA stack to isolate. The database is 2.8 GB
of parameter files the binaries read at runtime, which is exactly the thing
that belongs on a share rather than inside a squashfs you would have to
rebuild to change one params file.

## Two halves that refuse to swap places

```
build-linux.sh fetch      # LOGIN NODE   -- the only node with internet
build-linux.sh compile    # COMPUTE NODE -- under salloc/sbatch
build-linux.sh install    # either       -- publish into $PREFIX
```

Each half checks where it is and refuses otherwise, because both mistakes are
slow to diagnose:

- **`fetch` on a compute node** hits the compute proxy, which returns 403 for
  github. That fails like a network hang, not like a denial.
- **`compile` on the login node** is 4 CPUs under a soft 8 GiB cap, so a
  32-way build is throttled into uselessness and is antisocial besides. The
  refusal prints the `salloc` line to use.

`install` copies with `cp -L`, because scons leaves `source/bin/` as symlinks
into `build/`, and the build tree is on scratch, which is purged.

## Pinned, where the Mac build floats

`pipelines/local/build_rosetta_macos.sh` clones `--branch main`, so it builds
whatever HEAD happened to be that day and cannot be reproduced. This pins
`v2026.38-dev62288` — the release current when it was first built, the same
week, so a Mac built then matches.

**Bumping this changes ddG numbers and Gate 6 has to be re-run.**

Note also that the directory is called `rosetta314` and the content is a 2026
release. The name is historical. `install` writes a `PROVENANCE` file with the
ref, commit, compiler and date, so what is actually there is recorded next to
it rather than inferred from a directory name.

## Two compiler traps, both specific to this cluster

Neither is in the Mac script, whose workarounds (a `-Wno-error` `site.settings`
and a vendored-Boost patch) exist for Apple clang. gcc has never treated
`enum-constexpr-conversion` as an error, so the Boost patch does not apply
here at all.

### scons runs a different compiler from the one it detects

The first compile died in 11 seconds with thousands of identical errors:

```
cc1plus: error: '-Wno-error=dangling-reference': no option
'-Wdangling-reference'; did you mean '-Wdangling-else'?
```

on every file including the first. The flag is not wrong and gcc is not
broken — **two compilers are involved and nothing in the output says so.**

Rosetta's scons resolves the compiler through a *sanitized* PATH.
`tools/build/settings.py:347` is

```python
symbols["ENV"]["PATH"] = self.program_path
```

and `basic.settings` seeds `program_path` with the system directories. But the
version *detection* that chooses the warning flags runs through the PATH you
actually have. On CoreHPC those disagree:

| | |
|---|---|
| `g++` on PATH | 14.2.0, from `/opt/ohpc/pub/compiler/gcc/14.2.0/bin` |
| `/usr/bin/g++` | **11.5.0** (Red Hat) |

So scons configured for 14.2 — the build tree is literally
`build/src/release/linux/5.14/64/x86/gcc/14.2/` — selected
`-Wno-error=dangling-reference` because that warning exists from gcc 13, and
handed it to gcc 11.5, which has never heard of it.

`compile` now writes a `site.settings` prepending the detected compiler's own
directory to `program_path`, which is the documented hook for this
(`site.settings.accre` has the same idiom, commented out). It also preflights
that exact flag against that exact binary before starting, and logs which
`g++` it resolved — the fact whose absence turned this into a diagnosis
rather than a read.

### `-Werror` against a compiler newer than upstream tests

With the right compiler, the next failure was 1332 object files in:

```
VectorOption_T_.hh:1111: error: 'frag_files...state_' may be used
uninitialized [-Werror=maybe-uninitialized]
```

reached by inlining at `-O3` from `loops_main.cc:100` — the textbook
false-positive shape for that warning.

Rosetta compiles with `-Werror` plus a hand-maintained list of `-Wno-error=`
exemptions (`array-bounds`, `stringop-overread`, `restrict`,
`dangling-reference`). That list tracks the compilers upstream tests against;
gcc 14 raises warnings that are not on it.

Exempting them one at a time is a losing game — that failure came 1332 files
into a build of roughly ten thousand, so each new warning costs another
multi-minute compile to find. `site.settings` therefore appends a blanket
`-Wno-error`. Warnings-as-errors is a policy for people **developing**
Rosetta; for a downstream build of a tagged release with a newer compiler it
only converts "upstream tested with an older gcc" into "you cannot build
this". The warnings are still printed, just not fatal.

## Traps at run time

- **`cartesian_ddg` ignores `-out:path:all`** for its own `.ddg` table and its
  dumped PDBs, and writes them to the current working directory. Stage scripts
  `cd` into their output directory first. Before that, ddG results landed in
  the repo root while the job reported success.
- **`relax` is deliberately not built.** Relaxation goes through
  `rosetta_scripts` with a protocol XML; adding `relax` would be a second
  binary nothing calls.
- **Do not substitute the Sali module's Rosetta 3.10.** Every ddG number
  changes and Gate 6 has to be re-run. `tool_doctor` checks `$PREFIX`, not
  `PATH`, for exactly this reason.
- **FoldX and Rosetta disagree about residue naming**, and neither notices:
  chymotrypsinogen 193 is `GA193F` to FoldX and `G 179 F` in a Rosetta
  mutfile. Go through `pipelines/filters/foldx_ddg.py prepare`.
