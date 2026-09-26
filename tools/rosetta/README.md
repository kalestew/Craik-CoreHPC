# Rosetta

| | |
|---|---|
| Status | verified 2026-09-19 on a CoreHPC compute node, CPU (`chpc-tool test rosetta`; no job id recorded) |
| Installs to | `$CHPC_SOFTWARE/rosetta314` (`bin/`, `database/`, `lib/`, `PROVENANCE`) — a native build, not a container |
| Provides | `rosetta_scripts`, `cartesian_ddg` — and nothing else |
| Suffix | `default.linuxgccrelease` (`$ROSETTA_SUFFIX`; the binaries carry it in their names) |
| GPU | CPU only |
| Weights | none — a 2.8 GB parameter database at `$ROSETTA_DB`, read at run time |
| Licence | free for academic/non-commercial; commercial needs a paid RosettaCommons licence |
| Upstream | `RosettaCommons/rosetta` @ `v2026.38-dev62288` (`06b084e5`) |
| Version | `tool.conf` says `VERSION=3.14` and the directory is `rosetta314`; the content is the 2026 release above. The name is historical — "Pinned, where the Mac build floats", below. |

## Run it

```bash
salloc -p cpu -c 8 --mem 16G -t 4:00:00
mkdir -p /mnt/scratch/user/$USER/rosetta/run1 && cd "$_"   # cartesian_ddg writes to the cwd, so start in one you own
eval "$(chpc-tool export rosetta)"                         # ROSETTA_BIN, ROSETTA_DB, ROSETTA_SUFFIX in THIS shell

# a protocol: rosetta_scripts with an XML
"$ROSETTA_BIN/rosetta_scripts.$ROSETTA_SUFFIX" -database "$ROSETTA_DB" \
    -parser:protocol protocol.xml -s in.pdb -nstruct 1 -out:file:scorefile score.sc

# a ddG: cartesian_ddg with a mutfile
"$ROSETTA_BIN/cartesian_ddg.$ROSETTA_SUFFIX" -database "$ROSETTA_DB" -s in.pdb \
    -ddg:mut_file mut.txt -ddg:iterations 3 -ddg:cartesian -ddg:dump_pdbs false \
    -score:weights ref2015_cart -fa_max_dis 9.0
```

`-ddg:iterations 3` is a production figure **(untested)**: the self-test runs
`-ddg:iterations 1`, which is enough to prove the machinery and not enough to
average anything. Everything else on both lines is what was tested.

As a job: copy `templates/slurm/tool-gpu.sbatch`, set its four EDIT lines to the
values above, and take the CPU variant its header describes (`--partition=cpu`,
no `--gres`, no `nvidia-smi`). The method and the `eval` idiom:
[`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

`rosetta_scripts` takes a PDB and a protocol XML (`-parser:protocol`). The
self-test's XML is a scorefunction with empty `<MOVERS>` and `<PROTOCOLS>`,
which is the least that parses; `test.sh:56-62` is the shape.

`cartesian_ddg` takes a PDB and a mutfile:

```
total 1
1
S 3 A
```

`total <N>` for the file, then **per block** a count line, then that block's
mutations. `S 3 A` is Ser 3 → Ala in Rosetta's numbering, which is not the
PDB's — see the FoldX bullet below.

`rosetta_scripts` appends one `SCORE:` row per structure to
`-out:file:scorefile` and writes the output PDBs beside it. Column order is not
fixed across Rosetta versions, so read `total_score` by name from the `SCORE:`
header row rather than by position (`test.sh:75-78` does exactly that).
`cartesian_ddg` writes `<mutfile>.ddg` — `mut.ddg` for `mut.txt` — into the
current working directory, with `COMPLEX` rows in it (the self-test's single
iteration produced two).

Neither output is ranked. Before trusting a ddG: it is an average over
`-ddg:iterations`, so one iteration is a smoke test rather than a number; it is
only comparable with numbers from this same install, because a different
Rosetta version moves every value; and the mutation has to be addressed in
Rosetta's numbering.

## Do not miss

- **A mutfile needs a per-block count line**, not just `total N`. Omitting it —
  which looks redundant for a single mutation — gets you
  `ERROR: Assertion 'num_mutations>0' failed` at `cartesian_ddg.cc:188` and a
  developer backtrace, which says nothing about the file being one line short.
- **`cartesian_ddg` ignores `-out:path:all`** for its own `.ddg` table and its
  dumped PDBs, and writes them to the current working directory. `cd` into the
  output directory first. Before that, ddG results landed in the repo root
  while the job reported success.
- **Only `rosetta_scripts` and `cartesian_ddg` are built.** `relax` is
  deliberately absent: relaxation goes through `rosetta_scripts` with a
  protocol XML, and a second binary nothing calls is a second binary to build.
- **Do not substitute the Sali module's Rosetta 3.10.** Every ddG number
  changes and Gate 6 has to be re-run. `tool_doctor` checks `$PREFIX`, not
  `PATH`, for exactly this reason.
- **FoldX and Rosetta disagree about residue naming**, and neither notices:
  chymotrypsinogen 193 is `GA193F` to FoldX and `G 179 F` in a Rosetta
  mutfile. Go through `pipelines/filters/foldx_ddg.py prepare`.

---

## Provenance

Built 2026-09-19 on CoreHPC from `v2026.38-dev62288`: `scons` exit 0 in 11m24s
on 32 cores, 0 errors / 91 warnings, installed to `$CHPC_SOFTWARE/rosetta314`
with a `PROVENANCE` file recording ref, commit, compiler and date. Verified the
same day on a compute node; the entry records no job id for that run.

### What the test proves

`chpc-tool test rosetta` scores six residues of real backbone (3rgk 1–6) with
`ref2015` through `rosetta_scripts`, then runs one `cartesian_ddg` mutation:

```
ok: rosetta_scripts total_score=2.723, cartesian_ddg wrote 2 rows to mut.ddg
```

Both, because they fail differently — `rosetta_scripts` exercises the XML
parser and the scorefunction, `cartesian_ddg` the minimizer and the mutation
machinery, and it is `cartesian_ddg` whose output the ddG cascade reads.

## Build notes

Build it with [`build-linux.sh`](build-linux.sh).

### Why native, when everything else here is an image

The build is the expensive artifact — hours, not minutes — and the output is
a plain binary with no python or CUDA stack to isolate. The database is 2.8 GB
of parameter files the binaries read at runtime, which is exactly the thing
that belongs on a share rather than inside a squashfs you would have to
rebuild to change one params file.

### Two halves that refuse to swap places

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

### Pinned, where the Mac build floats

`pipelines/local/build_rosetta_macos.sh` clones `--branch main`, so it builds
whatever HEAD happened to be that day and cannot be reproduced. This pins
`v2026.38-dev62288` — the release current when it was first built, the same
week, so a Mac built then matches.

**Bumping this changes ddG numbers and Gate 6 has to be re-run.**

Note also that the directory is called `rosetta314` and the content is a 2026
release. The name is historical. `install` writes a `PROVENANCE` file with the
ref, commit, compiler and date, so what is actually there is recorded next to
it rather than inferred from a directory name.

### Two compiler traps, both specific to this cluster

Neither is in the Mac script, whose workarounds (a `-Wno-error` `site.settings`
and a vendored-Boost patch) exist for Apple clang. gcc has never treated
`enum-constexpr-conversion` as an error, so the Boost patch does not apply
here at all.

#### scons runs a different compiler from the one it detects

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

#### `-Werror` against a compiler newer than upstream tests

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

### The binaries are 62 KB, and that is the third trap

`rosetta_scripts` is 62 KB and `cartesian_ddg` 216 KB, because Rosetta links
them against ~39 shared libraries. scons bakes an RPATH of

```
<build>/src/...:<build>/external/...:$ORIGIN:$ORIGIN/../lib
```

so a freshly installed copy **works** — by reaching back into the build tree
on **scratch**, which is purged. The install would keep working for weeks and
then start failing with `error while loading shared libraries`, pointing at a
directory nobody remembers creating.

No `patchelf` is needed, and none is installed on this cluster: that RPATH
already ends in `$ORIGIN/../lib`, so `install` puts the libraries in
`$PREFIX/lib` and they resolve relative to the binary. The scratch entries
simply stop matching once they are gone.

`install` then asserts it, by listing every library the binary currently
resolves out of `/mnt/scratch` and checking each one also exists in
`$PREFIX/lib`. That is the check that would have caught this at install time
rather than after a purge.
