# python-bio

| | |
|---|---|
| Status | built (no `test.sh`); a claim about the mechanism, not any one environment, checked on CoreHPC 2026-09-17 against `iggase` (python 3.12.14, gemmi 0.7.5, numpy 2.5.3, biopython 1.83) |
| Conda env | named by `$CHPC_PYENV` (default `bio`, which nothing creates), at `$CHPC_USER_SCRATCH/envs/<name>`; exports `PYTHON` |
| GPU | CPU |
| Licence | various, all open source |
| Upstream | https://conda-forge.org/; the recipe is the project's yml (`ENV_YML` is empty here), e.g. `IgGase_eng/envs/iggase.yml` |

## Run it

There is no `chpc-tool exec python-bio`: a conda entry has no exec form and
the CLI refuses it by design. `export` names the interpreter; you call it.

```bash
salloc -p cpu -c 2 --mem 4G -t 1:00:00
export CHPC_PYENV=iggase                     # the environment's name, on its own line (why: below)
eval "$(chpc-tool export python-bio)"        # PYTHON=/mnt/scratch/user/$USER/envs/iggase/bin/python
"$PYTHON" my_script.py                       # (untested) gemmi, numpy, biopython; no torch
```

`export` is its own line because the one-line form does not work here: in
`CHPC_PYENV=iggase eval "$(chpc-tool export python-bio)"` the command
substitution is expanded *before* the prefix assignment takes effect, so
`chpc-tool export` never sees `CHPC_PYENV` and names `bio`. The prefix form is
fine when nothing is substituted: `CHPC_PYENV=iggase chpc-tool doctor
python-bio` checks the environment, and `CHPC_PYENV=iggase chpc-tool export
python-bio` prints the line without applying it.

As a job: copy `templates/slurm/tool-gpu.sbatch`, switch it to
`--partition=cpu` and delete its `--gres` and `nvidia-smi` lines, and put the
three lines above in place of its `eval` and its `chpc-tool exec` command.
The method: [`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

Whatever your script reads and writes. `$PYTHON` is the interpreter of the
environment you named, with gemmi, numpy, biopython and deliberately no torch.
`CHPC_PYENV=iggase chpc-tool doctor python-bio` prints the versions it found,
or the rebuild command; record those versions beside any number a script
produced, because a numpy bump can move a recorded result with every test
still green.

## Do not miss

- **Name an environment.** Without `CHPC_PYENV`, `doctor` reports `----` (not checked) and `export` names `bio`, which nothing was ever asked to create.
- **`export CHPC_PYENV=...` on its own line, before the `eval`.** The prefix form does not reach the command substitution.
- **No exec form.** `chpc-tool exec python-bio` is refused; run `"$PYTHON"` directly.
- **The environment lives on scratch and is purged.** Rebuild on the login node: `module load CBI; module load miniforge3; conda env create -f <yml>`. Run `doctor` after every purge.
- **Never pipe `module load`.** It is a shell function; piped, it runs in a subshell and the change never reaches you.

---

## Provenance

Built and checked on CoreHPC 2026-09-17 against `IgGase_eng/envs/iggase.yml`:
python 3.12.14, gemmi 0.7.5, numpy 2.5.3, biopython 1.83. STATUS is a claim
about the mechanism (how to build, activate and check a conda env on this
cluster), not about any one environment, because the name comes from the
caller; there is no `test.sh`, so the entry is `built`. An earlier version of
this page said this entry is what `run_tool python` resolves to, 28 of the 43
call sites in the round-0 pipeline; `run_tool` is a function of the downstream
IgGase_eng project, not of this repo.

## Build notes

### The recipe belongs to the project, not here

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

## Traps

### `doctor` reports "not checked", not "broken", when no env is named

Because `PREFIX` contains `$CHPC_PYENV`, a bare `chpc-tool doctor` has no
environment to look at. It used to look for a generic `bio` env that nothing
was ever asked to create and report the registry's only `FAIL`. This entry now
defines `tool_precheck`, which returns 2 and names what to pass. See
[`tools/README.md`](../README.md) — a false FAIL costs more than a missing
row, because it teaches people to skim past doctor's output.

### The environment lives on scratch, which is purged

`PREFIX` defaults under `$CHPC_USER_SCRATCH/envs`. That is correct — the env
is reproducible from a committed yml and does not belong on the share — but
it does mean a purge silently removes the pipeline's interpreter. `doctor`
catches it and prints the rebuild:

```
module load CBI; module load miniforge3; conda env create -f <yml>
```

**Never pipe `module load`** — it is a shell function, so it runs in a
subshell and the change never reaches you. See [`docs/06`](../../docs/06-software-modules-conda.md).
