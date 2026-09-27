# PROSS

| | |
|---|---|
| Status | **external** — a Weizmann web service, deliberately not installed on CoreHPC. Not a pending build |
| Where it runs | <https://pross.weizmann.ac.il/> in a browser, on your laptop |
| GPU | none here; nothing here |
| Licence | free for academic use as a web service. A local install is a Rosetta protocol and needs a Rosetta licence |
| Upstream | <https://pross.weizmann.ac.il/>; Goldenzweig et al., *Molecular Cell* **63**, 2016 |

PROSS takes a structure and returns a small number of **stabilised designs**,
typically carrying 10–30 mutations each. It works by combining a
phylogenetic signal — which substitutions are tolerated across the family —
with Rosetta energy calculations, and keeps mutations that both the alignment
and the force field like. The usual result is a protein that expresses better
and tolerates heat and proteases better, with function retained because the
active site is held fixed.

That last property is why this entry is in the catalogue: stabilising the
parent pays for itself twice here, once in expression yield and once in
serpin resistance.

## Why there is nothing to install

`external` is a terminus in this registry, not a rung on the way to `verified`
([`../README.md`](../README.md#add-a-tool)).

- **It is used as the web server.** Submit a structure, choose the alignment
  depth, receive the designs. There is no command-line distribution.
- **A local install is a Rosetta protocol, unwritten here.** It would depend on
  the [`rosetta`](../rosetta/README.md) entry and its licence, and would need
  validating against the web server before any number from it could be
  trusted. That is a project, not a packaging task.

## How the lab uses it

1. Submit the parent structure. Choose the alignment depth deliberately: a
   shallow alignment gives conservative designs, a deep one gives more
   mutations and more risk.
2. PROSS returns a handful of designs, usually numbered by increasing
   mutational load. Practice here is to order the two or three most
   conservative and keep the aggressive ones in reserve.
3. **Then** use the cluster on what comes back: fold the designs with
   [`boltz`](../boltz/README.md) to check nothing structural broke, and run the
   stability consensus — [`foldx`](../foldx/README.md),
   [`rosetta`](../rosetta/README.md) `cartesian_ddg`, and
   [`thermompnn`](../thermompnn/README.md) — over the individual mutations to
   see which ones the local methods also like.

## Do not miss

- **Do not blindly combine PROSS mutations with active-site redesign.** PROSS
  optimises the scaffold *assuming the functional site is fixed*. A position it
  stabilises may be one [`funclib`](../funclib/README.md) wants to vary, and
  neither tool knows the other exists. Reconcile the two sets by hand before
  ordering anything.
- **A stabilised parent is a different protein.** Any number measured on the
  parent — kinetics, a binding constant, a melting temperature — has to be
  remeasured. It is easy to treat a PROSS design as "the same protein, but
  better" and carry old constants forward.
- **The mutations arrive as a set, and the set is what was validated.** Picking
  a favourite subset out of a PROSS design discards the epistasis the method
  accounted for. If a subset is what you want, run the consensus over it
  rather than assuming it inherits the design's stability.
