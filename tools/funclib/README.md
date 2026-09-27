# FuncLib / htFuncLib

| | |
|---|---|
| Status | **external** — a Weizmann web service, deliberately not installed on CoreHPC. Not a pending build |
| Where it runs | <https://funclib.weizmann.ac.il/> in a browser, on your laptop |
| GPU | none here; nothing here |
| Licence | free for academic use as a web service. A local install is a Rosetta protocol and needs a Rosetta licence |
| Upstream | <https://funclib.weizmann.ac.il/>; Khersonsky et al., *Molecular Cell* **72**, 2018; htFuncLib: Weinstein, Khersonsky & Fleishman, *Nature Communications* **14**, 2023 |

FuncLib designs **multipoint active-site libraries** that are enriched for
folded, functional variants. It combines a position-specific scoring matrix
from a homologue alignment with Rosetta modelling of every candidate
combination, and keeps only combinations whose predicted epistasis is
tolerable. The output is a *library* of tens to hundreds of variants, each
carrying several mutations at once.

This is the highest-value classical addition available for subsite redesign,
and it has never been applied to this fold.

## Why there is nothing to install

`external` is a terminus in this registry, not a rung on the way to `verified`
([`../README.md`](../README.md#add-a-tool)). Two facts put this entry there:

- **It is used as the web server, by everyone, including its authors' own
  collaborators.** The service takes a structure and a list of designable
  positions and returns the library. There is no command-line distribution.
- **A local install is not a packaging job, it is a protocol.** The published
  method is a Rosetta pipeline — build the PSSM, enumerate combinations at the
  chosen positions, score each with Rosetta, filter on the epistasis criterion
  — and nobody here has written it. It would depend on the
  [`rosetta`](../rosetta/README.md) entry and on that licence, and it would
  then need validating against the web server's output before anyone could
  trust a number from it.

Carried as `STATUS=planned`, this entry read as a build somebody owed. It is
not. If the lab ever does want it on the cluster, the work starts from the
2018 and 2023 papers and the `rosetta` entry, and it is a project rather than
an afternoon.

## How the lab uses it

1. Pick the designable positions. For a protease subsite that means the
   residues lining the pocket, usually four to six of them; FuncLib's cost
   grows combinatorially, so this choice is the whole experiment.
2. Submit the structure and those positions through the web form.
3. Bring the returned sequence list back as a plain table. Nothing on CoreHPC
   participates in producing it.
4. **Then** use the cluster: the returned variants are exactly the input that
   the co-folding and scoring entries here are for. Fold the interesting ones
   with [`boltz`](../boltz/README.md), score the complexes against a reference
   with [`dockq`](../dockq/README.md), and check stability with
   [`foldx`](../foldx/README.md), [`rosetta`](../rosetta/README.md) and
   [`thermompnn`](../thermompnn/README.md).

## Do not miss

- **The output is a library, not a design.** FuncLib returns variants to
  *screen*. The downstream constraint is expression and assay capacity, not
  which single variant to make, and a library of 200 sequences is a different
  experiment from a shortlist of three.
- **Reconcile it with [`pross`](../pross/README.md) by hand.** PROSS stabilises
  the scaffold assuming the functional site is fixed, and FuncLib varies the
  functional site. The two mutation sets can collide at the same position.
  Neither tool knows about the other.
- **Co-folding models barely respond to point mutations** (Masters 2025), so do
  not rank a FuncLib library by folding each member and comparing confidence
  scores. That is what [`thermompnn`](../thermompnn/README.md), `foldx` and
  Rosetta `cartesian_ddg` are for, and it is why the stability consensus wants
  three votes rather than one.
