# ANARCI

| | |
|---|---|
| Status | **verified** 2026-09-26 — built, published, and `test.sh`'s six cases passed on `ccpu1-01` (CPU, `community_short`) |
| Image | `anarci_2024.05.21.sif` from [`anarci_2024.05.21.def`](anarci_2024.05.21.def); 292 MB on a `condaforge/miniforge3` base |
| GPU | none. Pure python plus HMMER; there is no CUDA anywhere in the image |
| Weights | none. What it needs instead is a **pressed** IMGT profile set, baked in |
| Licence | BSD-3-Clause |
| Upstream | <https://github.com/oxpig/ANARCI>, bioconda `anarci` 2024.05.21 with `hmmer` 3.4 |
| Citation | Dunbar & Deane, *Bioinformatics* **32**(2), 2016, [btv552](https://doi.org/10.1093/bioinformatics/btv552) |

ANARCI numbers antibody variable domains in **IMGT, Kabat, Chothia, Martin,
Aho and Wolfguy**. It aligns a sequence against germline profiles with HMMER
and maps the result onto the chosen scheme's fixed frame, reporting the chain
type and the germline it matched along the way.

It is in this registry for a specific local reason: this programme juggles EU
numbering for IgG against three protease conventions, and ANARCI is what does
the antibody half without a hand-maintained map. A hand-maintained map is fine
until the first insertion in a CDR, and then it is silently wrong.

## Run it

Nothing to fetch and nothing staged on FAC: the pressed IMGT profile set and
HMMER are inside the image.

```bash
salloc -p community_short --qos=cmnt_short -c 4 --mem 8G -t 0:30:00
chpc-tool exec anarci -- ANARCI -i seqs.fasta --scheme imgt
chpc-tool exec anarci -- ANARCI -i EVQLQQSGAE... --scheme chothia --restrict heavy
```

Schemes: `imgt`, `kabat`, `chothia`, `martin`, `aho`, `wolfguy`. The published
wrapper `anarci` is the same thing under a shorter name, so it works on the
login node too.

From python, which is what a pipeline wants:

```bash
chpc-tool exec anarci -- python -c "
from anarci import number
numbering, chain_type = number(seq, scheme='imgt')"
```

It is CPU-only and fast. Send it to `community_short` — 1 h, and it
**requires `--qos=cmnt_short`** — or to `cpu` for a long batch.

Rebuild and republish: [`../README.md`, Add a tool](../README.md#add-a-tool).

## Why this is a container and not a conda entry

The entry was declared `KIND=conda`, and that was a statement about where the
package lives rather than about how the lab should carry it. A conda
environment under `$CHPC_USER_SCRATCH/envs` is **per-user** and sits on
**scratch**, which is purged at 30 days and wiped entirely at quarterly
maintenance. A lab-wide numbering tool delivered that way needs recreating by
every person, repeatedly, forever — and every recreation is a chance for the
pins to drift. An image on FAC is built once, is immutable, and is shared.

[`python-bio`](../python-bio/README.md) stays `KIND=conda` because its pins
genuinely belong to each project; the same argument does not reach here,
because there is nothing project-specific about IMGT numbering.

## Do not miss

- **An import proves nothing.** ANARCI writes a FASTA to a temporary file and
  shells out to the **`hmmscan` binary**, against a profile set that must have
  been **pressed** with `hmmpress`. Neither is touched by `import anarci`, so
  the module imports cleanly on an installation that cannot number anything,
  and then every call raises `FileNotFoundError: 'hmmscan'`. This is why
  `test.sh` numbers a real sequence and `tool_doctor` looks for `ALL.hmm.h3p`.
- **`pip install ANARCI` is not equivalent.** The PyPI package is a
  third-party repackaging that bundles the profiles but declares **no HMMER
  dependency at all**. It installs, it imports, and it fails at the first
  sequence. HMMER has to come from conda, because it is not on conda-forge
  either — only bioconda.
- **Never rebuild the HMM profiles.** They are built with `hmmbuild --hand`
  from germlines scraped off the IMGT website. Without `--hand`, `hmmbuild`
  drops mostly-gap columns and the alignment comes out narrower than 128
  positions, which ANARCI cannot use. Upstream's own recipe notes that
  `pip install .` "fails to build the HMMs"; the built conda package is the
  supported route and the only one that needs no network.
- **IMGT is 128 positions wide, gaps included.** `number()` returns
  `((position, insertion_code), residue)` pairs with `-` for a gap, so the
  length of the result is the frame, not the length of your sequence. The
  conserved anchors are **23 CYS, 41 TRP, 104 CYS, 118 TRP**, and they are
  what `test.sh` asserts, because a plausible-looking list of 128 pairs with
  the anchors in the wrong place would pass any length check.
- **It refuses non-antibody sequences, and that is a feature.** `number()`
  returns `None` for something that is not a variable domain. A pipeline that
  does not check for `None` will put IMGT positions on whatever it was handed.

---

## Provenance

**Run 2026-09-26** on `ccpu1-01` (`community_short`), against bioconda
`anarci` 2024.05.21 with HMMER 3.4, through the scratch build and again through
the share's published copy. All six cases passed.

### What `test.sh` proves

The fixture is the **12e8 heavy chain**, taken from upstream's own README —
the same sequence bioconda's recipe tests with — so the expected numbering is
not something invented here.

| # | Asserted | Measured 2026-09-26 |
|---|---|---|
| 1 | IMGT gives 128 positions, chain type `H`, and the anchors 23 C, 41 W, 104 C, 118 W | all four anchors correct |
| 2 | the frame is padded: gap positions exist, and the numbered residues are a subsequence of the input | **8 gap positions** |
| 3 | **Kabat returns a different position list from IMGT** — so the `scheme` argument is not being ignored | differs |
| 4 | `run_anarci` reports a species and an hmmscan bitscore above 50, so the pressed profiles were really searched | **species mouse, bitscore 176.2, e-value 4.5e-55** |
| 5 | a non-antibody sequence (a lysozyme fragment) is refused | returns **`False`** |
| 6 | the `ANARCI -i` command-line entry point numbers a FASTA and prints the 23 CYS anchor | yes |

Case 4's `mouse` is a good sign rather than a curiosity: 12e8 *is* a murine
antibody, so the germline assignment is not merely non-empty, it is right.

### A refusal is `False`, not `None`

Case 5 was written asserting `numbering is None` and **failed against a working
installation**: `number()` returns `False` for a sequence that is not a variable
domain. The distinction is not cosmetic, which is why the test now asserts the
exact value as well as falsiness. A caller written as

```python
if numbering is None:        # WRONG -- a refusal is False, not None
    skip()
```

treats a refusal as a successful numbering and carries `False` forward into
whatever consumes it. Test falsiness.

Case 3 is the one that cannot be faked by a cached or constant answer: IMGT and
Kabat genuinely disagree about where the CDRs begin and how insertions are
lettered, so a wrapper ignoring `scheme=` would satisfy every other check here.
Case 5 is the other half of discrimination — a numberer that numbers anything
is worse than none.

### Verified against upstream, 2026-09-26

- BSD-3-Clause, and bioconda `anarci` 2024.05.21 as a `noarch` package whose
  run dependencies are `biopython`, `hmmer >=3.3.2` and `python`;
- that the package ships `dat/HMMs/ALL.hmm` **plus** the pressed `.h3f`, `.h3i`,
  `.h3m` and `.h3p` companions, and `germlines.py`, so no network and no HMM
  build is needed at install time;
- that HMMER is absent from conda-forge, making `-c bioconda` mandatory;
- that ANARCI locates its profiles at
  `<site-packages>/anarci/dat/HMMs/ALL.hmm` and invokes `hmmscan` from `PATH`;
- that the PyPI package declares no HMMER dependency, and that removing
  `hmmscan` from `PATH` makes `number()` raise `FileNotFoundError`;
- the 12e8 numbering itself: chain `H`, 128 positions, 23 C, 41 W, 104 C,
  118 W.

**Not** verified: whether upstream supports python 3.12 or newer. The bioconda
recipe pins its host python to `<=3.11` and the package is `noarch` with no
upper bound, and the runtime imports are standard library plus Biopython. This
recipe pins **3.11** rather than find out in a job.
