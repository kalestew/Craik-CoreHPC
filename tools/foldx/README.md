# FoldX 5.1

| | |
|---|---|
| Status | verified 2026-09-21 on the CoreHPC **login node**: `chpc-tool doctor foldx` ran the binary and the banner was clean. No `test.sh`, so no compute-node self-test yet (Provenance) |
| Installs to | `$CHPC_SOFTWARE/foldx5.1/foldx_20270131` (`$FOLDX_BINARY`), 88 MB — ELF 64-bit x86-64, **statically linked**. Native, no image |
| Payload | [`assets.tsv`](assets.tsv) — binary + 15 `molecules/*.json`, on the share, not in git |
| GPU | CPU (`salloc -p cpu`) |
| Weights | none |
| Licence | proprietary; **free academic, per-user registration** |
| Expires | **2027-01-31** |
| Upstream | <https://foldxsuite.crg.es/>, build `foldx_20270131` |
| Installed | 2026-09-21, kanderson6, staged from a licensed local copy |

## Run it

```bash
salloc -p cpu -c 8 --mem 16G -t 2:00:00
mkdir -p /mnt/scratch/user/$USER/foldx/run1 && cd "$_"   # in.pdb and individual_list.txt here; FoldX writes beside them (untested)
eval "$(chpc-tool export foldx)"                          # FOLDX_BINARY: the dated binary, found by glob
"$FOLDX_BINARY" --command=RepairPDB --pdb=in.pdb          # (untested) once per structure; upstream's first step, writes in_Repair.pdb
"$FOLDX_BINARY" --command=BuildModel --pdb=in_Repair.pdb --mutant-file=individual_list.txt   # (untested)
```

There is no `test.sh`, so none of these lines has been run through this
registry; the flags are FoldX's own. `chpc-tool exec foldx -- foldx ...` does
**not** work: for a native entry `exec` puts `$PREFIX/bin` on `PATH`, and this
install has no `bin/` and no program called `foldx`. The binary sits directly
under `$PREFIX` as `foldx_20270131` and `tool.conf` names no `ENTRY`, so `exec`
would add nothing the `eval` does not. As a job: copy
`templates/slurm/tool-gpu.sbatch`, switch it to `--partition=cpu` and drop
the `--gres` and `nvidia-smi` lines as its header says, set `TOOL=foldx` (its
`eval` then exports `FOLDX_BINARY`), and replace the `chpc-tool exec` line
with the `"$FOLDX_BINARY"` call above. The method and the `eval` idiom:
[`../README.md`](../README.md#run-a-tool-on-your-inputs).

## Inputs and outputs

Input is a PDB and, for `BuildModel`, `individual_list.txt`: one mutant per
line, each a comma-separated list of `<wt><chain><pdbnumber><mut>` labels
ending in `;`, so `GA193F;` is one single mutant and `GA193F,LA25I;` one
double (untested here). The residue number is the PDB's own, chain included,
and the wild-type letter must match the structure (Do not miss).

Output lands in the working directory (untested): `Dif_<pdb>.fxout` is the
ddG per mutant in kcal/mol, positive destabilising, in the order of
`individual_list.txt`, not ranked; `Raw_<pdb>.fxout` and `Average_<pdb>.fxout`
carry the energy terms; `<pdb>_1.pdb` and `WT_<pdb>_1.pdb` are the mutant and
the re-relaxed wild type for the first mutant.

Before trusting a number: FoldX is deterministic per run but its ddG carries
an error on the order of the effects people look for, so upstream's practice
is `--numberOfRuns 5` and the average (untested here); and a label the tool
accepted is not a label that named the residue you meant, since a wrong
wild-type letter or a Rosetta-style number is not caught by FoldX itself.

## Do not miss

- **The licence expires 2027-01-31 and fails only when it runs.** An expired
  binary is still present and executable and says `Your foldX time has
  expired` at run time, so `chpc-tool doctor foldx` runs `-h` and reads the
  banner. Read that row before a batch of jobs, and read Build notes for the
  one-command renewal.
- **Numbering is PDB numbering plus chain, `GA193F`, not Rosetta's `G 179 F`.**
  Neither tool notices a swap. Read the wild type out of the structure before
  writing the label (Traps).
- **A residue with an insertion code cannot be mutated.** Chymotrypsinogen
  36A, 36B, 184A and 188A are out of reach.
- **`doctor` warning `no rotabase.txt beside the binary` is expected.** This
  build compiles the rotamer data in and ships `molecules/` instead; the
  warning is not a failure (Build notes).
- **The share is where the bytes live.** `$FOLDX_BINARY` empty after the
  `eval` means the payload is not installed for you: `chpc-assets list foldx`
  says what is missing.

---

## Provenance

Installed 2026-09-21 by kanderson6, staged from a licensed local copy through
`chpc-assets install foldx`.

`verified` for this entry means exactly this: on 2026-09-21, on the CoreHPC
login node, `chpc-tool doctor foldx` found `foldx_20270131` under
`$CHPC_SOFTWARE/foldx5.1`, ran it with `-h`, and the banner was clean — no
expiry message, valid to 2027-01-31. That is a run of the binary, not a
computation: there is no `test.sh`, so `chpc-tool test foldx` dies with `no
test.sh in ... (required for STATUS=verified)`, and no FoldX command has been
run on a compute node through this registry.

Follow-up: write a `test.sh` that runs `BuildModel` on a small structure with
a one-line `individual_list.txt` and asserts a non-empty `Dif_*.fxout`, run
`chpc-tool test foldx` on a compute node, and record the date and node here.

## Build notes

### The payload lives on the share, not in git

The lab is licensed to distribute FoldX internally and the GitLab server is
private, so this is a practical choice rather than a legal one. The binary is
88 MB and **expires on a date encoded in its own filename**: one copy on the
share is one thing to replace next January, whereas a committed one sits in
every clone and in history permanently, still expiring. So this directory
carries the manifest and the share carries the bytes, which is the arrangement
`chpc-assets` exists for:

```bash
chpc-assets list foldx                       # the shopping list
chpc-assets install foldx --from <your-dir>  # copy, chmod, verify sha256
chpc-tool doctor foldx                       # run it, read the banner
```

A lab member with share access needs none of this — `FOLDX_BINARY` already
resolves for them. Someone outside the share gets an exact list: ask the lab
for the licensed copy, or register your own at the URL above.

**Renewal is one command.** When the 2027-01-31 copy lapses, download the new
build, edit the first row of `assets.tsv` to its filename, set the sha256 to
`-`, then `chpc-assets install foldx --from <dir> --record` and commit the
manifest it writes back. Everyone on the share picks it up with no action,
because `tool_exports` finds the binary by glob rather than by name.

### Newer builds ship `molecules/`, not `rotabase.txt`

The rotamer data is compiled into the binary now; `molecules/` holds
modified-residue definitions instead. All fifteen in this build are modified
nucleotides (`RA`, `RU`, `6HA`, `TTP`, …), so **none of them is used by protein
ddG** — they are installed so the result matches what the vendor shipped, not
because any stage reads them.

`tool_doctor` still warns when `rotabase.txt` is absent. That warning is
expected on this build and is not a failure. If your download is an older one
that ships `rotabase.txt`, `assets.tsv` says what to change.

`chpc-assets` installs files and never directories, which is why each molecule
is its own manifest row with the subdirectory carried in the destination.

## Traps

- **It lapses silently, so the check runs the binary.** An expired FoldX is
  still present, still executable, and only says
  `Your foldX time has expired` **when it runs**. A `-x` test therefore reports
  a perfectly working FoldX that fails every single call. `tool_doctor` runs
  `-h` and greps the banner for exactly this reason, and the filenames encode
  their own expiry so `foldx_20270131` is self-documenting.

  This copy dies on **2027-01-31**. It was chosen over an otherwise equivalent
  2026-12-31 build for that extra month.
- **Where it is used.** Wired into `44_foldx_ddg.sh` and `60_cascade.sh` via
  `jobs/foldx_ddg.sbatch`. The stability consensus **degrades gracefully**:
  with `FOLDX_BINARY` empty the cascade falls back to Rosetta alone and marks
  single-method rows, so FoldX blocks nothing.
- **FoldX addresses residues by PDB numbering plus chain,** which is a
  different frame from a Rosetta mutfile — chymotrypsinogen 193 is `GA193F` to
  FoldX and `G 179 F` to Rosetta, and neither tool notices if they are swapped.
  Go through `pipelines/filters/foldx_ddg.py prepare`, which reads the wild
  type out of the structure before handing it over and refuses a label that
  disagrees. FoldX also cannot mutate a residue carrying an insertion code,
  which rules out chymotrypsinogen 36A, 36B, 184A and 188A.
