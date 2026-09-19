# python-bio

| | |
|---|---|
| Verified | 2026-09-17 on CoreHPC — python 3.12.14, gemmi 0.7.5, numpy 2.5.3, biopython 1.83 |
| Kind | `conda` — a **mechanism**, not one environment |
| Exports | `PYTHON` |
| Upstream | https://conda-forge.org/ |
| Licence | various, all open source |
| GPU | no |

The light python layer: gemmi, numpy, biopython, and deliberately **no
torch**. It is what `run_tool python` resolves to, which is 28 of the 43 call
sites in the round-0 pipeline — the most-used entry in the registry.

## The recipe belongs to the project, not here

This is the one entry that is deliberately incomplete. `ENV_YML` is empty and
`ENV_NAME` comes from `$CHPC_PYENV`, because the pins are the *project's*:

```bash
CHPC_PYENV=iggase chpc-tool export python-bio
CHPC_PYENV=iggase chpc-tool doctor python-bio
```

A project that asserts recorded numbers off a pairwise alignment cannot share
an interpreter with one that does not care which numpy it gets. IgGase_eng's
`scripts/02` alignment is sensitive to the aligner and the substitution-matrix
data, and `07_verify.py` asserts values read off it, so a numpy bump there can
move a recorded result with every test still green. If that yml lived in this
submodule, another project bumping numpy would silently move IgGase's
numbers.

So corehpc owns *how* to build, activate and check a conda env on this
cluster; the project owns *which* one.

## `doctor` reports "not checked", not "broken", when no env is named

Because `PREFIX` contains `$CHPC_PYENV`, a bare `chpc-tool doctor` has no
environment to look at. It used to look for a generic `bio` env that nothing
was ever asked to create and report the registry's only `FAIL`. This entry now
defines `tool_precheck`, which returns 2 and names what to pass. See
[`tools/README.md`](../README.md) — a false FAIL costs more than a missing
row, because it teaches people to skim past doctor's output.

## The environment lives on scratch, which is purged

`PREFIX` defaults under `$CHPC_USER_SCRATCH/envs`. That is correct — the env
is reproducible from a committed yml and does not belong on the share — but
it does mean a purge silently removes the pipeline's interpreter. `doctor`
catches it and prints the rebuild:

```
module load CBI; module load miniforge3; conda env create -f <yml>
```

**Never pipe `module load`** — it is a shell function, so it runs in a
subshell and the change never reaches you. See [`docs/06`](../../docs/06-software-modules-conda.md).
