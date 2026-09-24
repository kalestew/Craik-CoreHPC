# Protenix v1

| | |
|---|---|
| Status | **planned** — nothing built, nothing fetched, nothing run |
| Recipe | [`protenix_1.def`](protenix_1.def) — written, never executed |
| Upstream | <https://github.com/bytedance/Protenix> |
| Licence | code Apache-2.0; **v1 parameters Apache-2.0, commercial use permitted** |
| Weights | not fetched — [`fetch-weights.sh`](fetch-weights.sh), login node only |
| GPU | yes — `GPU_MAX_CC` **UNMEASURED**, see below |
| Pinned at | **v1**, for the licence. See "Why v1". |

An AlphaFold-3-class co-folding model that, unlike AlphaFold 3, is Apache-2.0
on both halves — and, unlike AlphaFold 3, will bond a ligand to a polymer
residue without a `userCCD` detour. That combination is the entire reason this
entry exists beside [`../alphafold3`](../alphafold3).

## Why v1, and why that is not a conservatism

v2 is newer and larger — 464 M parameters against 368 M. Its **weights are
proprietary**. Upstream's own words:

> The model weights of Protenix-v2 are proprietary and confidential
> information of the rights holder, are not released under any open-source
> license, and may not be reproduced, distributed, sublicensed, disclosed, or
> otherwise transferred to any third party in any form without the express
> prior written consent of the rights holder.

against, for everything else:

> The Protenix project including both code and model parameters is released
> under the Apache 2.0 License. It is free for both academic research and
> commercial use.

The AlphaFold 3 entry in this registry records what that distinction costs:
a weights licence restricts the **outputs**, and a structure that enters a
filing or a partnership is the part that gets asked about, years after the
run finished. AF3's restriction is unavoidable if you want AF3. Protenix's is
avoidable — it is a checkpoint name — so choosing v2 here would be repeating
the AF3 output-restriction problem on a model that did not have to have it.

So: `VERSION=1`, `fetch-weights.sh` refuses any model name containing `v2`,
`tool_doctor` fails if a `*v2*` checkpoint appears under `$PROTENIX_ROOT_DIR`,
and `test.sh` refuses to run against one. Four refusals rather than a sentence,
because a sentence is what the sotorasib SMILES had.

Upstream's model table, as read 2026-09-24:

| Model | Released | Params | Licence |
|---|---|---|---|
| `protenix_base_default_v1.0.0` | 2026-02-05 | 368 M | Apache-2.0 — **this one** |
| `protenix_base_20250630_v1.0.0` | 2026-02-05 | 368 M | Apache-2.0 |
| `protenix_base_default_v0.5.0` | 2025-05-30 | 368 M | Apache-2.0 |
| `protenix-v2` | 2026-04-08 | 464 M | **proprietary — not here** |

## Covalent bonds: the addressing is not AlphaFold 3's

A top-level `covalent_bonds` list, each entry

```json
{"entity1": 1, "copy1": 1, "position1": 6, "atom1": "SG",
 "entity2": 2, "copy2": 1, "position2": 1, "atom2": "C1"}
```

Three things here will cost someone a day if they are not written down:

- **`entityN` is a 1-based position in the `sequences` list, not a chain id.**
  Every other tool in this registry that takes a bond — AlphaFold 3's
  `bondedAtomPairs`, IntelliFold's copy of it — addresses by `entity_id`,
  which is a *label*. Protenix's is an *index*. Reorder the `sequences` list
  for any reason and every bond in the file silently points somewhere else.
  Nothing errors; you get a structure.
- **A SMILES ligand's atom has two spellings with two different bases.** A
  0-based index into the SMILES string, or an element-plus-ordinal name like
  `C3` or `N2` whose ordinal is 1-based. An off-by-one in the index form is
  invisible — it is still a valid atom. Prefer the named form, and assert the
  geometry afterwards regardless.
- **Boltz's renumbering warning applies here too**: whatever numbering the
  antibody carries, the bond references positions in the sequence string you
  supplied. Map back to EU numbering explicitly.

`test.sh`'s second case is the check that matters, and it does not trust any
of the above: it folds a one-cysteine peptide with a Michael acceptor and then
asserts, on the coordinates, that exactly one ligand heavy atom is within
2.1 Å of `SG`, that it is a carbon, and that that carbon's only heavy
neighbour inside the ligand is another carbon. The last clause is what
separates a terminal warhead CH₂ from the N-methyl carbon without depending on
what the predictor decided to name things.

That is not defensive writing. It is the HA-ADAPT Chai-1 failure, which
quarantined 1,726 results: the peptide cysteine bonded to an aromatic ring
carbon at 1.68 Å instead of the warhead at 13.59 Å, and **ipTM moved 0.710 →
0.698** between the wrong structure and the right one. No confidence score
detects it. The shared checker is
[`../_template/check_covalent_bond.sh`](../_template/check_covalent_bond.sh).

## MSAs are a login-node stage, not a flag

`pairedMsaPath` and `unpairedMsaPath`, and upstream recommends **absolute**
paths. Compute nodes here have no internet (doc 02), so anything that reaches
an MSA server is a job that hangs until it times out. Generate on the login
node — that is what [`../mmseqs2`](../mmseqs2) and [`../colabfold`](../colabfold)
are for — and pass the files in.

## `GPU_MAX_CC` is UNMEASURED, and that is a deliberate refusal

The `gpu` partition is three different devices: L40S at compute capability
8.9, H100 NVL at 9.0, RTX PRO 6000 Blackwell at 12.0. A bare `--gres=gpu:1`
lands on any of them. Five tools here declare a 9.0 ceiling and die on the
Blackwell nodes with `no kernel image is available for execution on the
device` — which reads as a broken install and is a scheduling accident
(doc 05).

`tool.conf` therefore carries the literal `GPU_MAX_CC=UNMEASURED`. `chpc-tool`
compares with `awk` (`a+0 > b+0`) and `awk` reads a non-numeric string as `0`,
so **every** device is above this ceiling and `chpc-tool exec protenix` refuses
on any GPU node until a real number replaces it. Fails closed, on purpose: a
refusal is recoverable in seconds, a wrong ceiling is a job that dies twenty
minutes in with a message about the wrong thing.

Measure it inside the built image, **on the login node**:

```bash
/usr/bin/apptainer exec "$CHPC_CONTAINERS/protenix_1.sif" \
  python -c "import torch; print(torch._C._cuda_getArchFlags())"
```

The highest `sm_NN` is the number: `sm_120` → `12.0`, `sm_90` → `9.0`. The
login node has no `nvidia-smi`, so the guard is silent there and cannot block
its own measurement. Use `_cuda_getArchFlags`, **not**
`torch.cuda.get_arch_list()`, which returns `[]` when no GPU is visible —
exactly the login node. `%post` prints a `GPU_MAX_CC candidate:` line at the
end of the build; that is the same measurement, and it still has to be copied
into `tool.conf` by a human.

## The C-compiler trap: a compiler is installed, on purpose

Boltz's image is built from this same `python:3.12-slim` base with only `git`
and `ca-certificates`. Its cuequivariance kernels are Triton, which
JIT-compiles at first use and needs a C compiler **inside** the image, so every
prediction above ~128 total tokens dies four seconds in with
`RuntimeError: Failed to find C compiler` from `triton/runtime/build.py`,
having written nothing. Independently confirmed outside this registry: job
array 1928395 in a sibling project lost all five tasks in under a minute each
to exactly that error.

**Decision for Protenix: install `build-essential` in `%post` and keep it.**

Upstream's README does not say whether Protenix pulls a Triton-backed or
otherwise JIT-compiled kernel through its torch dependency chain, and that
could not be confirmed either way from the documentation — so this is
insurance, not a diagnosis. It costs ~200 MB against a failure that (a) wastes
a whole GPU job, (b) arrives mid-run rather than at import, (c) is invisible to
`--help`, to `%test`, and to any self-test small enough to be quick, and (d)
has no documented escape hatch here: Boltz has `--no_kernels` only because
someone already paid for that discovery. `%post` and `%test` both assert the
compiler is on `PATH`, and `tool_doctor` probes the built image for `cc`/`gcc`/
`clang` rather than assuming, so a future rebuild from a slimmer base is
noticed instead of discovered.

`%environment` also points `NUMBA_CACHE_DIR`, `TRITON_CACHE_DIR` and
`TORCHINDUCTOR_CACHE_DIR` at `/tmp`. A `.sif` is a read-only squashfs and
anything that caches beside its own source refuses at *import* time inside one
— which is how Boltz's numba failure got past a green build (doc 07).

## When someone builds it

```bash
chpc-tool build protenix            # login node only; /usr/bin/apptainer 1.5.2,
                                    # --fakeroot unavailable, no `module load apptainer`
tools/protenix/fetch-weights.sh     # login node; weights + CCD onto FAC
# read the GPU_MAX_CC candidate out of the build log, put it in tool.conf
chpc-tool publish protenix
chpc-tool test protenix             # GPU node -- this is what `verified` means
```

Weights and the chemical component dictionary go on FAC
(`/mnt/fac/CX500146_DS1`, 5 TB, ~1.1 TB used), never on `/mnt/scratch`, which
is purged at 30 days and is never canonical. Anything created on the share
needs `chpc-fac-fixacl` — the inheritable DENY ACL there makes new files
unreadable by their own owner (doc 02).

Do not flip `STATUS` past `planned` until `chpc-tool exec protenix` has run a
real inference, and not past `built` until `test.sh` — **both** cases —
passes. A container that starts and cannot find its weights looks exactly like
a working one until someone submits real work.

## What was verified, and what was taken on trust

Verified against upstream on 2026-09-24:

- the v1/v2 licence split, quoted above from upstream's README;
- the model table, including `protenix-v2` being the proprietary row;
- `covalent_bonds` field names, the 1-based entity indexing into `sequences`,
  and both SMILES atom spellings (0-based index, or element + 1-based ordinal)
  — upstream `docs/infer_json_format.md`;
- `pairedMsaPath` / `unpairedMsaPath` and the absolute-path recommendation —
  same document;
- installation is `pip install protenix`; inference is
  `protenix pred -i in.json -o out -n <model>`.

**Not** verified, and marked as such in the files that depend on it:

- `PROTENIX_ROOT_DIR` (checkpoints under `$ROOT/checkpoint`, CCD under
  `$ROOT/common`) and `PROTENIX_DATA_ROOT_DIR` come from upstream's training
  documentation read at second hand, not from a running image. If
  `fetch-weights.sh` downloads into `$HOME` instead, that is why, and
  `tool_exports` in `tool.conf` is what to fix.
- the exact `sequences` entry keys (`proteinChain`, `ligand`) used in
  `test.sh` and `fetch-weights.sh`;
- whether `covalent_bonds` sits at the job level or the file level;
- what `positionN` means on the ligand side of a bond when the ligand is a
  single SMILES residue;
- whether Protenix will fold at all with no MSA supplied;
- the output format and the ligand atom naming in it — `test.sh` parses both
  mmCIF and PDB and asserts on geometry rather than names for this reason;
- whether anything in the dependency chain JIT-compiles, which is why the
  compiler is insurance rather than a fix.
