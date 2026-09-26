# DockQ v2

| | |
|---|---|
| Status | planned — recipe and a four-case `test.sh` written, never executed |
| Image to be | `dockq_2.sif` from [`dockq_2.def`](dockq_2.def); around 200 MB on a `python:3.12-slim` base (untested) |
| GPU | none. CPU only, and that is a fact about the tool: no `--nv`, no `GPU_MAX_CC` |
| Weights | none. DockQ is arithmetic over two structure files |
| Licence | MIT |
| Upstream | <https://github.com/bjornwallner/DockQ>, pip `DockQ`; the exact version is pinned at build time |
| Citation | Mirabello & Wallner, *Bioinformatics* **40**(10), 2024, [btae586](https://doi.org/10.1093/bioinformatics/btae586) |

DockQ v2 scores a predicted complex against a reference: a single DockQ value
plus iRMSD, LRMSD, fnat, fnonnat, F1 and a clash count, for protein multimers,
nucleic acids and — with `--small_molecule` — small-molecule poses. **This is
not a predictor, and that is why it is here.** Every other entry in the
co-folding family produces structures; none of them can tell you whether those
structures are right.

## Not built yet

Nothing to fetch: no weights, no databases, no GPU, nothing to stage on FAC.
The image is the only missing piece and the recipe is written.

```bash
chpc-tool build dockq       # login node only; /usr/bin/apptainer 1.5.2,
                            # --fakeroot UNAVAILABLE, no `module load apptainer`
chpc-tool publish dockq
chpc-tool test dockq        # CPU -- this is what `verified` means
```

The intended command, read from [`test.sh`](test.sh):123 and **untested**:

```bash
salloc -p cpu -c 8 --mem 16G -t 2:00:00     # or -p community_short --qos=cmnt_short for a 30 s job
chpc-tool exec dockq -- DockQ model.pdb native.pdb --mapping MODELCHAINS:NATIVECHAINS --json dq.json   # (untested)
```

Send it to the `cpu` partition, or to `community_short` — 1 h, and it
**requires `--qos=cmnt_short`**. It has no business queueing behind the `gpu`
partition's 8-GPU, 21-job per-user cap for a 30-second job.

Build and publish: [`../README.md`, Add a tool](../README.md#add-a-tool).

## Do not miss

- **`--mapping` is load-bearing.** Model chains and native chains are different
  alphabets, and DockQ searches chain permutations and reports the best one it
  finds. A wrong mapping therefore does not error: it returns a plausible
  number with exit 0. Pass `--mapping MODELCHAINS:NATIVECHAINS` explicitly —
  wildcards are allowed (`A*:W*`, `:WX`) — and never let a pipeline rely on the
  search. The full story is in Traps.
- **CAPRI thresholds**, from upstream: below 0.23 Incorrect, 0.23–0.49
  Acceptable, 0.49–0.80 Medium, 0.80 and above High quality. Upstream documents
  them as a *legend*; that the text report prints a category per interface is
  unconfirmed, so `test.sh` derives the category from the score instead of
  parsing one.
- **`--small_molecule` needs the ligand on its own chain identifier** in the
  PDB or mmCIF you hand it.
- **A confidence score is not a check, which is the point of scoring against a
  native.** HA-ADAPT's quarantined Chai-1 corpus moved ipTM by 0.012 between a
  wrong covalent attachment and the right one:
  [`../covalent-bonds.md`](../covalent-bonds.md).

---

## Provenance

**Never run.** `STATUS=planned`, there is no image, and `test.sh` has never
executed. Everything below is what the test *will* prove once someone builds
the entry.

### What `test.sh` will prove, and why a self-comparison is not enough

`DockQ x x` returns the perfect score from a tool that has silently mapped
every chain to itself — the one case in which a broken chain mapping cannot
show. So the test has four cases:

| # | Input | Asserted |
|---|---|---|
| 1 | native vs itself | DockQ ≥ 0.99 — the perfect score |
| 2 | chain B slid 12 Å along the interface | < 0.80, and **below** case 1 — the score responds |
| 3 | chains renamed `M`/`N`, `--mapping MN:AB` | back to ≥ 0.99 — the flag is honoured |
| 4 | same input, `--mapping NM:AB` | **exit 0**, and < 0.80 — the trap, demonstrated |

Case 2 is the half case 1 cannot supply: a scorer stuck at `1.000` passes a
self-comparison perfectly. Case 4 is the one worth keeping. Its assertion is
deliberately *not* "it fails" — it is that DockQ succeeds and returns a number,
because that is the real behaviour and the reason the flag has to be passed.

The fixture is two 40-residue mixed-topology chains from
[`../_template/make_test_pdb.sh`](../_template/make_test_pdb.sh), parallel,
axes 7.0 Å apart. Measured on the generated coordinates before any of this was
written: **205 heavy-atom pairs under 5 Å, closest approach 3.28 Å** — a real
interface with no clash. `dx=8.0` gives only 42 contacts and `dx=6.5` gives 319
with a 2.87 Å closest approach, so 7.0 is the middle of the usable range rather
than a guess. The decoy keeps 99 contacts under 5 Å, so it is still a touching
complex — a decoy that no longer touched would be scored badly by anything.

The two chains carry the **same sequence on purpose**. That is what makes case
4 possible: a wrong mapping between two interchangeable chains is precisely the
case DockQ cannot detect. A wrong mapping between chains of different lengths
is the easy case, not the dangerous one.

Mixed topology and cycling residue names come from the shared generator and are
not decoration — a pure helix is one 3Di state and poly-alanine is one residue
type, and a fixture that degenerate fails to match *itself*, which reads as a
broken tool (see `../foldseek`).

### What was verified against upstream, and what was taken on trust

Verified against upstream on 2026-09-24:

- MIT licence, as stated on the repository (read from the GitHub project page,
  not from the `LICENSE` file itself);
- the console script is `DockQ` (capital D, capital Q), invoked
  `DockQ <model> <native>`;
- `--mapping MODELCHAINS:NATIVECHAINS`, with wildcard forms `A*:W*` and `:WX`;
- `--json <file>`, `--short`, and `--small_molecule` (small molecules must be
  in the PDB/mmCIF with their own chain identifiers);
- the reported metrics: DockQ, iRMSD, LRMSD, fnat, fnonnat, F1, clashes;
- the example report showing DockQ searching the mapping and printing the one
  it chose — quoted in Traps;
- the CAPRI thresholds: `<0.23` Incorrect, `0.23–0.49` Acceptable,
  `0.49–0.80` Medium, `≥0.80` High quality;
- nucleic-acid interfaces scored alongside protein ones;
- `pip install DockQ`;
- the citation and DOI.

**Not** verified, and marked as such in the files that depend on it:

- **that the text report prints a CAPRI category per interface.** Upstream
  documents the thresholds as a *legend*; the example report block does not
  show a category line. `test.sh` therefore **derives** the category from the
  score using those thresholds rather than parsing one. The brief this entry
  was written from says DockQ "emits ... a CAPRI category"; that is the one
  claim in it that could not be confirmed.
- the JSON schema — specifically which key holds the overall score.
  `test.sh`'s extractor prefers `GlobalDockQ`, falls back to a top-level
  `DockQ`, and otherwise walks the document for the largest value under any
  `DockQ` key, reporting the top-level keys if it finds none. Fix it to the
  real key the first time this runs and delete the walk.
- that DockQ accepts the generated fixture as an interface. If it reports no
  interfaces, tighten the 7.0 Å offset — the contact count climbs steeply.
- whether `DockQ` is pure Python in the pinned version — `%post` prints what
  it finds.

## Build notes

`python:3.12-slim` rather than a CUDA base keeps the image around 200 MB
instead of several GB, which matters because this is the one tool in the
covalent family that will be invoked thousands of times per campaign rather
than dozens.

Three deliberate absences, because in a directory where every sibling has them
an absence looks like an omission. **No weights**, so no `fetch-weights.sh` and
no `assets.tsv`: a fetch script that fetches nothing would be a lie about the
shape of the tool, and `../foldseek` and `../mmseqs2` have the same shape for
the same reason. **No `GPU_MAX_CC`**, because that field stops a CUDA binary
landing on a device it has no kernels for (doc 05) and a CPU tool has no
kernels, no device and no ceiling; `chpc-tool` only consults it when `GPU=1` in
any case. As of 2026-09-25 the GPU entries added alongside this one do carry a
measured ceiling — `protenix` and `intellifold` at 9.0, `openfold3` at 12.0 —
so nothing here is waiting on a measurement. **`GPU=0` is written out
explicitly** even though it is the default, so that nobody adds `--nv` to match
the neighbours.

No C compiler either: DockQ has no GPU kernels and no JIT path that could be
found — it is numpy and Biopython — so a toolchain would double the image for
nothing. `%post` *reports* instead, printing whether `numba`, `cython` and
`triton` are present, so that if a future DockQ grows a fast path the build log
says so rather than a job finding out; `%environment` sets `NUMBA_CACHE_DIR`
defensively for the same reason. The trap itself is documented once, in
[`../../docs/07-containers-apptainer.md`](../../docs/07-containers-apptainer.md),
"A kernel that compiles at first use".

## Traps

- **A wrong `--mapping` does not error. It produces a plausible number.** Model
  chains and native chains are different alphabets: a predictor emits `A`, `B`,
  `C` in whatever order its input listed them; a native from the PDB uses
  whatever the depositor chose. DockQ will search chain permutations and report
  the best one it finds — upstream's own example output says so on its face:

  ```
  Total DockQ over 3 native interfaces: 0.653 with BAC:ABC model:native mapping
  Native chains: A, B
  	Model chains: B, A
  ```

  In bulk scoring that is indistinguishable from a result: not a crash, not a
  `nan`, just a column of numbers quietly about the wrong correspondence.
  `test.sh` asserts this as behaviour, in case 4, rather than leaving it as a
  warning someone may read.
- **A perfect score proves nothing on its own.** `DockQ x x` is the one
  comparison in which a broken chain mapping cannot show, so it is never
  evidence that an installation works. The four cases above are.
- **Do not send it to the `gpu` partition.** A 30-second scoring job behind the
  8-GPU, 21-job per-user cap is an own goal; `cpu`, or `community_short` with
  `--qos=cmnt_short`.
