# FoldX 5.1

| | |
|---|---|
| Installed | 2026-09-21, kanderson6, staged from a licensed local copy |
| Verified | 2026-09-21 on the CoreHPC login node — banner clean, no expiry |
| Binary | `foldx_20270131`, 88 MB — ELF 64-bit x86-64, **statically linked** |
| Location | `$CHPC_SOFTWARE/foldx5.1` (`FOLDX_BINARY`) |
| Payload | [`assets.tsv`](assets.tsv) — binary + 15 `molecules/*.json` |
| Upstream | <https://foldxsuite.crg.es/> |
| Licence | proprietary; **free academic, per-user registration** |
| GPU | no |
| Expires | **2027-01-31** |

## The payload lives on the share, not in git

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

## It lapses silently, so the check runs the binary

An expired FoldX is still present, still executable, and only says
`Your foldX time has expired` **when it runs**. A `-x` test therefore reports a
perfectly working FoldX that fails every single call. `tool_doctor` runs
`-h` and greps the banner for exactly this reason, and the filenames encode
their own expiry so `foldx_20270131` is self-documenting.

This copy dies on **2027-01-31**. It was chosen over an otherwise equivalent
2026-12-31 build for that extra month.

## Newer builds ship `molecules/`, not `rotabase.txt`

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

## Where it is used

Wired into `44_foldx_ddg.sh` and `60_cascade.sh` via `jobs/foldx_ddg.sbatch`.
The stability consensus **degrades gracefully**: with `FOLDX_BINARY` empty the
cascade falls back to Rosetta alone and marks single-method rows, so FoldX
blocks nothing.

FoldX addresses residues by PDB numbering plus chain, which is a different
frame from a Rosetta mutfile — chymotrypsinogen 193 is `GA193F` to FoldX and
`G 179 F` to Rosetta, and neither tool notices if they are swapped. Go through
`pipelines/filters/foldx_ddg.py prepare`, which reads the wild type out of the
structure before handing it over and refuses a label that disagrees. FoldX also
cannot mutate a residue carrying an insertion code, which rules out
chymotrypsinogen 36A, 36B, 184A and 188A.
