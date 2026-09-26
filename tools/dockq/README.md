# DockQ v2

| | |
|---|---|
| Status | **planned** — nothing built, nothing run |
| Recipe | [`dockq_2.def`](dockq_2.def) — written, never executed |
| Upstream | <https://github.com/bjornwallner/DockQ> |
| Licence | MIT |
| GPU | **no** — CPU only, no weights, no `GPU_MAX_CC` |
| Citation | Mirabello & Wallner, *Bioinformatics* **40**(10), 2024, [btae586](https://doi.org/10.1093/bioinformatics/btae586) |

DockQ v2 scores a predicted complex against a reference: a single DockQ value
plus iRMSD, LRMSD, fnat, fnonnat, F1 and a clash count, for protein multimers,
nucleic acids and — with `--small_molecule` — small-molecule poses.

**This is not a predictor, and that is why it is here.** Every other entry in
the co-folding family produces structures; none of them can tell you whether
those structures are right. A confidence score cannot: HA-ADAPT's quarantined
Chai-1 corpus moved ipTM by 0.012 between a wrong covalent attachment and the
right one. Scoring against a native is a different kind of evidence, and it is
the kind that says whether a predictor is any good on *this* family of
complexes rather than on the PDB in general.

## `--mapping` is load-bearing

Model chains and native chains are **different alphabets**. A predictor emits
`A`, `B`, `C` in whatever order its input listed them; a native from the PDB
uses whatever the depositor chose. DockQ will **search chain permutations and
report the best one it finds** — upstream's own example output says so on its
face:

```
Total DockQ over 3 native interfaces: 0.653 with BAC:ABC model:native mapping
Native chains: A, B
	Model chains: B, A
```

A wrong mapping therefore **does not error. It produces a plausible number.**
In bulk scoring that is indistinguishable from a result, and it is the failure
mode this entry exists to warn about: not a crash, not a `nan`, just a column
of numbers that are quietly about the wrong correspondence. Pass
`--mapping MODELCHAINS:NATIVECHAINS` explicitly — wildcards are allowed
(`A*:W*`, `:WX`) — and never let a pipeline rely on the search.

`test.sh` asserts this as behaviour, in case 4, rather than leaving it as a
warning someone may read.

## What the test proves, and why a self-comparison is not enough

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

## No `fetch-weights.sh`, no `assets.tsv`, no `GPU_MAX_CC`

Three deliberate absences, because in a directory where every sibling has them
an absence looks like an omission:

- **No weights.** DockQ is arithmetic over two structure files. A fetch script
  that fetches nothing would be a lie about the shape of the tool, and the next
  person to read the directory would go looking for the payload it implies.
  `../foldseek` and `../mmseqs2` have the same shape for the same reason.
- **No `GPU_MAX_CC`.** That field stops a CUDA binary landing on a device it
  has no kernels for (doc 05). A CPU tool has no kernels, no device and no
  ceiling; `chpc-tool` only consults the field when `GPU=1` in any case. The
  three GPU entries added alongside this one each carried
  `GPU_MAX_CC=UNMEASURED` until they were measured (they now hold 9.0, 9.0 and
  12.0); this one carries nothing at all, and the difference is meaningful —
  unmeasured means "ask later", absent means "there is nothing to ask".
- **`GPU=0` is written out explicitly** even though it is the default, so that
  nobody adds `--nv` to match the neighbours.

Send it to the `cpu` partition, or to `community_short` — 1 h, and it
**requires `--qos=cmnt_short`**. It has no business queueing behind the `gpu`
partition's 8-GPU, 21-job per-user cap for a 30-second job.

## The C-compiler trap does not apply here, and here is why

Boltz's image is built from `python:3.12-slim` with no compiler; its
cuequivariance kernels are Triton, which JIT-compiles at first use, so every
prediction above ~128 total tokens dies four seconds in with
`RuntimeError: Failed to find C compiler` from `triton/runtime/build.py`,
having written nothing. Job array 1928395 in a sibling project lost all five
tasks in under a minute each to exactly that.

**Decision for DockQ: no compiler installed.** The trap belongs to tools whose
GPU kernels are JIT-compiled at first use. DockQ has no GPU kernels at all and
no JIT path that could be found — it is numpy and Biopython. Installing a
toolchain would double the image for nothing.

What `%post` does instead is *report*: it prints whether `numba`, `cython` and
`triton` are present, so that if a future DockQ grows a fast path, the build
log says so rather than a job finding out. `%environment` also sets
`NUMBA_CACHE_DIR` defensively — it costs nothing, and if numba ever does arrive
it is the difference between working inside a read-only squashfs and refusing
at *import* (doc 07, and boltz's four-second failure before any input).

## When someone builds it

```bash
chpc-tool build dockq          # login node only; /usr/bin/apptainer 1.5.2,
                               # --fakeroot UNAVAILABLE, no `module load apptainer`
chpc-tool publish dockq
chpc-tool test dockq           # CPU -- this is what `verified` means
```

Nothing to fetch and nothing to stage on FAC.

## What was verified, and what was taken on trust

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
  it chose — quoted above;
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
