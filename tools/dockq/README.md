# DockQ v2

| | |
|---|---|
| Status | **verified** 2026-09-26 — built, published, and `test.sh`'s four cases passed on `ccpu1-01` (CPU, `community_short`) through the share's copy |
| Image | `dockq_2.sif` from [`dockq_2.def`](dockq_2.def); 196 MB on a `python:3.12-slim` base |
| GPU | none. CPU only, and that is a fact about the tool: no `--nv`, no `GPU_MAX_CC` |
| Weights | none. DockQ is arithmetic over two structure files |
| Licence | MIT |
| Upstream | <https://github.com/bjornwallner/DockQ>, pip `DockQ` **2.1.3**; python 3.12.14, numpy 1.26.4, biopython 1.88 |
| Citation | Mirabello & Wallner, *Bioinformatics* **40**(10), 2024, [btae586](https://doi.org/10.1093/bioinformatics/btae586) |

DockQ v2 scores a predicted complex against a reference: a single DockQ value
plus iRMSD, LRMSD, fnat, fnonnat, F1 and a clash count, for protein multimers,
nucleic acids and — with `--small_molecule` — small-molecule poses. **This is
not a predictor, and that is why it is here.** Every other entry in the
co-folding family produces structures; none of them can tell you whether those
structures are right.

## Run it

Nothing to fetch: no weights, no databases, no GPU, nothing staged on FAC. The
image is on the share and the wrapper is published.

```bash
salloc -p community_short --qos=cmnt_short -c 8 --mem 16G -t 0:30:00   # or -p cpu for a long batch
chpc-tool exec dockq -- DockQ model.pdb native.pdb --mapping AB:AB --json dq.json
```

`--mapping MODELCHAINS:NATIVECHAINS` is not optional in a pipeline; see Traps.
The published wrapper `dockq` is the same thing under a shorter name, so
`dockq model.pdb native.pdb --mapping AB:AB` works on the login node too.

Send it to `cpu`, or to `community_short` — 1 h, and it **requires
`--qos=cmnt_short`**. It has no business queueing behind the `gpu` partition's
8-GPU, 21-job per-user cap for a 30-second job.

The score to read out of `--json` is the top-level `GlobalDockQ`; per-interface
metrics are under `best_result[<chain pair>]`. The full schema is in Provenance.

Rebuild and republish: [`../README.md`, Add a tool](../README.md#add-a-tool).

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

**Run 2026-09-26** on `ccpu1-01` (`community_short`, 8 CPU, 16 GB), against
DockQ 2.1.3, through the share's published copy of the image as well as the
scratch build. All four cases passed; the measured scores are in the table.

### What `test.sh` proves, and why a self-comparison is not enough

`DockQ x x` returns the perfect score from a tool that has silently mapped
every chain to itself — the one case in which a broken chain mapping cannot
show. So the test has four cases:

| # | Input | Asserted | Measured 2026-09-26 |
|---|---|---|---|
| 1 | native vs itself | DockQ ≥ 0.99 — the perfect score | **1.000** High quality |
| 2 | chain B slid 12 Å along the interface | < 0.80, and **below** case 1 — the score responds | **0.131** Incorrect |
| 3 | chains renamed `M`/`N`, `--mapping MN:AB` | back to ≥ 0.99 — the flag is honoured | **1.000** High quality |
| 4 | same input, `--mapping NM:AB` | **exit 0**, and < 0.80 — the trap, demonstrated | **0.144** Incorrect, **exit 0** |

Case 4 is the one to keep in mind: the same file, scored against itself, read
through a transposed mapping, returned 0.144 and exit status 0. Nothing in that
output says anything is wrong.

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

### Settled by the first build, 2026-09-26

Four things were carried as explicitly unverified until the entry was built.
All four are now measured, and the files that hedged against them have been
updated rather than left with stale warnings.

- **The JSON schema.** `--json` writes an object with top-level keys
  `GlobalDockQ`, `best_dockq`, `best_mapping`, `best_mapping_str`,
  `best_result`, `model`, `native`. `GlobalDockQ` holds the overall score — the
  same number the text report calls "Total DockQ over N native interfaces".
  Per-interface metrics live under `best_result["AB"]`: `DockQ`, `iRMSD`,
  `LRMSD`, `fnat`, `fnonnat`, `F1`, `clashes`, `chain1`, `chain2`, `chain_map`,
  `class1`, `class2`, `is_het`, `len1`. `test.sh`'s extractor now reads
  `GlobalDockQ` and **fails loudly** if it is absent; the exploratory walk for
  "the largest value under any DockQ key" is deleted, because a fallback like
  that masks a schema change instead of reporting one.
- **Whether the text report prints a CAPRI category. It does not.** The
  thresholds appear exactly once, in the startup banner, as a legend. The
  per-interface block prints the seven metrics and no category line. The brief
  this entry was written from said DockQ "emits ... a CAPRI category" — that was
  the one claim in it that could not be confirmed, and it is wrong. Deriving the
  category from the score, which `test.sh` already did, is the only option.
- **Whether the generated fixture makes a scorable interface. It does.** At
  `dx=7.0` DockQ reports "Total DockQ over 1 native interfaces" and scores it.
  The offset did not need tightening.
- **Whether DockQ is pure Python. It is not.** It ships a Cython extension and
  needs `gcc` to install. That is the build's one real surprise and it has its
  own section under Build notes.

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

**A C compiler IS needed, and the first version of this entry argued at length
that it was not.** That argument was about the wrong compiler. It reasoned
about kernels compiled at first *use* — boltz's cuequivariance and Triton
paths, DeepSpeed's op builder — and correctly concluded DockQ has none. DockQ
needs `gcc` at *install* time, which is a different question, and nobody asked
it: the package ships `src/DockQ/operations.pyx` with its generated
`operations.c` and builds them as a Cython extension. On a `python:3.12-slim`
base the build therefore died in `build_ext` with

```
error: [Errno 2] No such file or directory: 'gcc'
```

after several minutes of healthy-looking pip output (measured here
2026-09-26). `build-essential` is in `%post` now, and the finished image keeps
it: a few hundred MB against a 5 TB share, against a future DockQ growing a
fast path and failing inside a read-only squashfs for reasons a job log will
not explain. The measured image is 196 MB *with* the toolchain, which is where
the original 200 MB estimate landed anyway.

The generalisable lesson: **"does it need a compiler" has to be asked of the
wheel, not only of the runtime**, and the cheap way to ask is to look for a
`.pyx`, a `.c` or an `ext_modules` in the sdist before reasoning about it.

**The fallback is what made this dangerous.** DockQ ships
`operations_nocy.py`, a pure-Python implementation, and imports it when the
extension is missing. A compiler-less image would have installed, imported,
answered `--help` and scored *correctly* — just far slower, silently, on the
one tool here expected to run thousands of times per campaign. So `%post` and
`%test` both assert that the module which loaded is the compiled one:

```python
import DockQ.operations as ops
assert not ops.__file__.endswith(".py")     # not the operations_nocy fallback
```

The built image loads
`DockQ/operations.cpython-312-x86_64-linux-gnu.so`. `%environment` still sets
`NUMBA_CACHE_DIR` defensively, and `%post` still reports whether `numba` and
`triton` are present, so a future fast path shows up in a build log rather
than in a job. The read-only-squashfs trap itself is documented once, in
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
