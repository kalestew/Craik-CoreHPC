# <Tool name>

<!-- Delete these comments and every row or alternative that does not apply.
     The first word of the Status cell MUST be the STATUS from tool.conf
     (planned | built | verified): tests/test_tool_readmes.py checks it.
     For a planned entry, replace "## Run it" with "## Not built yet" (what
     blocks it, what to use meanwhile, "Build and publish: ../README.md, Add a
     tool") and keep "## Do not miss" for what a user needs before asking. -->

| | |
|---|---|
| Status | verified 2026-MM-DD on an L40S (`chpc-tool test <tool>`, job NNNNNNN) |
| Image | `<tool>_<ver>.sif`, N.N GB; recipe [`<tool>_<ver>.def`](<tool>_<ver>.def) |
| GPU | `--gres=gpu:1`, any node / `--gres=gpu:nvidia_l40s:1` or `nvidia_h100_nvl:1` (`GPU_MAX_CC=9.0`) / CPU |
| Weights | N GB at `$<TOOL>_CACHE` (`$CHPC_LAB/data/<tool>`), fetched by [`fetch-weights.sh`](fetch-weights.sh) / in the image / none |
| Licence | |
| Upstream | `<pin>` |

## Run it

```bash
srun -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 2:00:00 --pty bash -l
mkdir -p /mnt/scratch/user/$USER/<tool>/run1 && cd "$_"   # inputs here; the same path is valid inside the container
eval "$(chpc-tool export <tool>)"                        # only if a $VARIABLE appears on the line below
chpc-tool exec <tool> -- <program> in.<ext> --out out     # production defaults, not the test's
```

As a job: copy `templates/slurm/tool-gpu.sbatch` and set its four EDIT lines to
the values above. The method, the `eval` idiom and which GPU to ask for:
[`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

What the input file is, where the output lands, whether it is ranked, and the
one or two things to know before trusting a number in it.

## Do not miss

- **One rule per bullet, bold lead.** The flag or habit that silently ruins a
  run on this cluster, and the reason. Two to five of these.

---

## Provenance

Built 2026-MM-DD by <user> on the CoreHPC login node (NNN s). What
`chpc-tool test <tool>` proves, the measured result, the date and the GPU model
it ran on. What was taken on trust.

## Build notes

The recipe decisions and the failures that shaped them. When an entry is
restructured this material moves here intact; write new notes the same way.

## Traps

Everything else that bit, one bold-led bullet each.
