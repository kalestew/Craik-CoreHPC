# Your first structure prediction: P1B7 / 8UDR

This walkthrough takes a P1B7 input folder on your laptop through a cluster
prediction and back to saved result files. It uses the same complex in Boltz-2, Chai-1, and Protenix, so you can
learn each tool without finding or translating inputs yourself. All inputs,
reference coordinates, and helper scripts are in
[`examples/p1b7/`](../examples/p1b7/README.md).

If you have never connected to CoreHPC, first complete
[the main README's access and environment steps](../README.md#first-hour-on-corehpc).
Everything below labeled **login node** is typed *after* `ssh chpc`.
Commands labeled **compute node** run only after Slurm gives you an allocation.
In a command block, `&&` means “continue only if the previous command succeeded.”
Paste the complete block and stop if it reports an error.

You need a lab account with access to `/mnt/fac/CX500146_DS1` and read access
to this Git repository. No separate installation of the prediction tools is
needed.

## What you will predict

[PDB 8UDR](https://www.rcsb.org/structure/8UDR) is the experimental structure
of the P1B7 Fab bound to a sotorasib-modified KRAS G12C peptide presented by
HLA-A*03:01. The tutorial uses the **full deposited protein sequences**,
including residues absent from the resolved coordinates:

- **A:** HLA-A*03:01 heavy chain, 275 residues.
- **B:** beta-2-microglobulin, 99 residues.
- **C:** KRAS peptide `VVVGACGVGK`, 10 residues.
- **D:** P1B7 Fab heavy chain, 226 residues, including the constant domain.
- **E:** P1B7 Fab light chain, 213 residues, including the constant domain.
- **F:** sotorasib in its bound-form representation, CCD component `MOV`.

That is 823 amino-acid residues across five separate protein chains, plus
the ligand. It is not a full IgG, a single-chain antibody, or the smaller
variable-domain-only example used in some lab projects. Keep each protein as
its own chain; joining their sequences changes the biological input.

The covalent bond connects the peptide cysteine's sulfur atom **SG** to the
ligand's warhead carbon. Three numbering systems matter:

1. In the peptide sequence you supply, the cysteine is **residue 6**.
2. In native KRAS/deposited author numbering, that same residue is **12**.
3. In the deposited `MOV` chemical component, the bonded atom is **C25**.
   A tool that creates atom names from SMILES can give that same atom a
   different name. The bundle records the tool-specific endpoint; do not
   copy an atom name between formats without checking its mapping.

The deposited ligand has label chain **F** but author chain **D**, shared
with the antibody heavy chain. Selecting everything with author chain D
would combine two different entities. The input manifest and output checker
use explicit mappings to avoid this trap. The reference's SG–C25 separation
is approximately 1.765 Å.

## Submit from your laptop with Globus

This is the recommended route: it needs no checkout on the cluster. First
complete [Globus setup](02-storage-and-data.md#laptop-to-cluster), which
puts this repo in your projects folder and lets Globus Connect Personal see
it. Keep the Mac awake and the app running until the transfers finish.

**On your laptop, from the local CoreHPC repository directory:**

```bash
source ./env.sh &&
chpc-globus.sh doctor "$CHPC_REPO/examples/p1b7" &&
python3 "$CHPC_REPO/examples/p1b7/check_inputs.py"
```

If CoreHPC is a submodule in your project, run `source corehpc/env.sh`
instead, using that submodule's actual relative path. `CHPC_REPO` then points
to it automatically. `doctor` checks that Globus can read these actual files.

Read [the Boltz input explanation](../tools/boltz/README.md#run-it), then
preview the complete transfer-and-submit sequence:

```bash
chpc-submit.sh "$CHPC_REPO/examples/p1b7" p1b7.sbatch --dry-run -- boltz
```

This creates no files, transfers nothing, and submits no job. The printed
commands show exactly which folder will go to scratch. To run one Boltz job:

```bash
chpc-submit.sh "$CHPC_REPO/examples/p1b7" p1b7.sbatch -- boltz
```

The helper transfers the example folder directly through Globus, transfers a
small submission script the same way, waits for both to succeed, and then
runs a short SSH command that submits `p1b7.sbatch`. Each invocation gets a
new scratch directory. There is no automatic clone, whole-project sync,
model download, or software installation. The job uses the **shared lab
registry** by default; its log records the resolved tool/image settings.
If you specifically need a pinned cluster checkout, use
`--corehpc /absolute/cluster/path/to/corehpc` before the `--`.

The `--` separates the submit helper's options from the batch script's
arguments. For another predictor, use `-- chai1` or `-- protenix`. For a
template run, use `-- boltz template`, `-- chai1 template`, or
`-- protenix template` after reading that tool's template section. These are
separate jobs, not extra steps required for the first run.

The chosen job folder must be self-contained: all scripts and inputs it
needs must be inside it, or available in the shared cluster installation.
The helper does not infer dependencies outside the folder. It omits common
local configuration, Git, environment, and generated-output paths; consult
`chpc-submit.sh --help` for the precise defaults. Keep the inputs unchanged
until Globus completes the transfer.

### Monitor and retrieve the laptop-submitted job

The helper prints the remote working directory and saves a local receipt.
**On your laptop**, recover the most recent attempt:

```bash
RECEIPT=$(cat "$CHPC_PROJECT/.chpc/submissions/latest") &&
WORK=$(cat "$RECEIPT/remote-dir.txt") &&
JOB_ID=$(cat "$RECEIPT/job-id.txt") &&
ssh "$CHPC_HOST" "squeue -j $JOB_ID"
```

If `job-id.txt` is absent, submission did not return a confirmed job ID.
Read the receipt's `status.txt` and transfer/submission logs. A queued or
timed-out transfer does not mean the job was submitted. If SSH disconnected
while submitting, do not invoke `chpc-submit.sh` again to recover that run:
that would create a new run folder. If `status.txt` says
`submission-response-unknown`, use the recorded recovery command instead:

```bash
cat "$RECEIPT/status.txt"
bash "$RECEIPT/recovery-command.txt"
```

It finishes the original submission if it never reached Slurm, or returns
the saved job ID if already submitted. It cannot automatically submit that
run twice. If the remote result is uncertain, it stops and tells
you which receipt to inspect. A recovered ID is printed but does not update
the local receipt; record that number for monitoring. For a transfer failure,
inspect the transfer logs first rather than using this recovery command.

Submission through this helper uses the combined log `logs/slurm-JOBID.out`
inside the printed remote directory. Once the job starts, read its latest
log lines **from your laptop**:

```bash
LOG=$(cat "$RECEIPT/log-path.txt") &&
ssh "$CHPC_HOST" "tail -n 40 '$LOG'"
```

Before the job starts, the log may not exist yet. `PD` in `squeue` means
pending; `R` means running. Check completion from your laptop:

```bash
ssh "$CHPC_HOST" "sacct -j $JOB_ID --format=JobID,State,ExitCode,Elapsed"
```

After the job has stopped writing files, retrieve its entire directory
**directly into your local project**:

```bash
mkdir -p "$CHPC_PROJECT/results" &&
chpc-globus.sh pull "$WORK" "$CHPC_PROJECT/results/$(basename "$WORK")"
```

Globus Connect Personal must allow writes to that project folder. This
preserves the inputs, settings, logs, and outputs together. Read the tool's
output checks before using a model. For a persistent copy available to the
lab, also follow [Save your results](#save-your-results) on the cluster:
source `/mnt/fac/CX500146_DS1/chpc.env` and set `WORK` to the full remote path
from your receipt. The following manual setup is an alternative route, not
an additional requirement for this laptop-submitted job.

## Manual cluster route

Use this route when you are already working in a cluster checkout or want
an interactive GPU shell. It uses the same input bundle and runner. Files
changed on your laptop must still arrive via Globus; do not replace that
transfer with a large inline script in SSH.

### 1. Get a copy of this repository

**On the login node:**

```bash
cd "$HOME" &&
git clone https://git.kalestew.io/ucsf/craik-lab/Craik-CoreHPC.git corehpc
```

`git clone` downloads a working copy of the guide and its example files;
it does not download model weights. If Git requests credentials, use your
GitLab access credentials or the lab-provided read-only access method. An
access-denied error needs repository access from the maintainer. Do not put
tokens into a pasted URL or a job script.

If Git says `destination path 'corehpc' already exists`, do not delete it.
If it is already a checkout of this repo, use it. The following check must
find the example; an older checkout may need updating with your maintainer.
If you already work from a project's `corehpc/` submodule, set `COREHPC` to
that full path instead of `$HOME/corehpc`.

```bash
export COREHPC="$HOME/corehpc"
ls "$COREHPC/examples/p1b7/manifest.json" &&
source "$COREHPC/env.sh" &&
command -v chpc-tool
```

Expect a path ending in `manifest.json`, followed by a path ending in
`lab/bin/chpc-tool`. `COREHPC` is the location of this repository; `source`
loads its version of the tool registry. Use this checkout consistently for
the rest of the tutorial.

### 2. Make your own working directory

**On the login node:**

```bash
export WORK="$CHPC_USER_SCRATCH/tutorials/p1b7-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$WORK" &&
cp -R "$COREHPC/examples/p1b7/." "$WORK/" &&
cd "$WORK" &&
printf '%s\n' "$WORK" | tee "$HOME/p1b7-last-workdir.txt" &&
git -C "$COREHPC" rev-parse HEAD > corehpc-commit.txt &&
pwd &&
ls
```

`WORK` names a new directory on your own scratch space. The date and time
keep today's run separate from earlier runs. `cp -R` copies the example
bundle, including its subdirectories. Edit this copy for your experiments.
The little file in your home directory remembers where you worked; it does
not contain or back up the results.

You should see `boltz.yaml`, `chai1.fasta`, `chai1.restraints`,
`protenix.json`, `manifest.json`, the `reference/` and `templates/`
directories, and the helper scripts. YAML and JSON are structured text
formats; FASTA stores named sequences. The Chai restraints file is a CSV
that declares the covalent bond separately from the FASTA.

### 3. Check the supplied inputs

**On the login node:**

```bash
python3 check_inputs.py &&
bash run.sh boltz --dry-run
```

The input check is a small offline Python program. It checks the committed
files, chain sequences, ligand mapping, and bond declarations. It requires
no GPU. A dry run prints the intended prediction command without executing
it. Stop if either command reports an error. Copy the complete error and
your working-directory path when asking for help.

The first run is **single-sequence**: no online multiple sequence alignment
(MSA) search and no structural template. This makes the exercise independent
of network services, which compute nodes cannot access. It teaches file
preparation, submission, and chemistry checks. It is not a claim that this
mode provides reliable antibody docking or a production-quality structure.

### 4. Choose one predictor

Start with **[Boltz-2](../tools/boltz/README.md#run-it)**. That page gives
the complete interactive commands and explains the input and output. Then
repeat with **[Chai-1](../tools/chai1/README.md#run-it)** and
**[Protenix](../tools/protenix/README.md#run-it)**. They use the same biological
complex but different file formats and atom-addressing rules.

An optional [ColabFold walkthrough](../tools/colabfold/README.md#p1b7-protein-only-comparison)
uses the same five protein chains as a clearly labeled protein-only control.
It cannot represent the sotorasib attachment. Check a method's capabilities
before treating its output as the same biological experiment.

Choose either the interactive route on a tool's page or the batch route
below. They call the same `run.sh`. Do not submit both routes for the same
tool/mode in the same working directory. The runner refuses an existing
output directory so you do not accidentally mix or overwrite results.

The tutorial requests an L40S GPU, 8 CPUs, 64 GiB of host memory, and four
hours. These are starting allocations, not measured requirements for this
new full-Fab example. Queue time, model runtime, and GPU memory usage vary;
the shorter historical self-tests in each tool README do not qualify this
823-residue example. If GPU memory is exhausted, more `--mem` alone cannot
increase GPU memory; see the troubleshooting steps below.

## Submit a batch job

A batch job lets you close your terminal after submission. **On the login
node**, from the directory prepared above:

```bash
cd "$WORK" &&
mkdir -p logs &&
JOB_ID=$(sbatch --parsable p1b7.sbatch boltz) &&
printf '%s\n' "$JOB_ID" | tee last-job-id.txt &&
squeue -j "$JOB_ID"
```

The returned number is your Slurm job ID. The script requests resources,
loads the repository's environment, and calls `bash run.sh boltz` on a GPU
node. There is no need to request an interactive GPU first. The `logs`
directory must exist before submission because Slurm opens its log before
running the script.

For a different predictor, submit **one** of these from the same prepared
directory, saving its job ID in the same way:

```bash
JOB_ID=$(sbatch --parsable p1b7.sbatch chai1) &&
printf '%s\n' "$JOB_ID" | tee last-job-id.txt
```

```bash
JOB_ID=$(sbatch --parsable p1b7.sbatch protenix) &&
printf '%s\n' "$JOB_ID" | tee last-job-id.txt
```

`last-job-id.txt` remembers only the latest submission; earlier job logs are
kept separately by job ID. The per-tool output directories are separate too.
If `sbatch` reports an error instead of a number, no job was submitted: fix
the error before trying to monitor it.

## Watch a batch job

**On the login node:**

```bash
JOB_ID=$(cat last-job-id.txt)
squeue -j "$JOB_ID"
```

`PD` means pending: the request is queued. `R` means running. A reason such
as `Resources` or `Priority` generally means wait. Do not submit duplicate
jobs to make the queue move faster. Once the job starts, read its log:

```bash
tail -n 60 "logs/p1b7_${JOB_ID}.out"
tail -f "logs/p1b7_${JOB_ID}.out"
```

The first command prints the latest 60 lines. The second keeps watching as
new lines arrive. Press **Ctrl-C** to stop watching; this does not cancel
the batch job. A missing log while the job is pending is normal. A long
first model load or compilation can be quiet; inspect the scheduler before
assuming the job has stopped.

After a job disappears from `squeue`, check its final status:

```bash
sacct -j "$JOB_ID" --format=JobID,JobName,State,ExitCode,Elapsed,MaxRSS
tail -n 80 "logs/p1b7_${JOB_ID}.out"
find out -type f \( -name '*.cif' -o -name '*.pdb' \)
```

`COMPLETED` with `ExitCode` `0:0` means the script finished, including its
tutorial checks. `FAILED`, `TIMEOUT`, `OUT_OF_MEMORY`, or a nonzero exit code
needs investigation. Accounting can take a little time to appear. A model
file by itself is not proof the whole job passed: later geometry checks may
have failed. Confidence scores describe model confidence, not experimental
accuracy or chemical validity.

To **cancel your own job**, confirm the number and then run:

```bash
printf 'Cancelling job %s\n' "$JOB_ID"
scancel "$JOB_ID"
```

This stops the computation; partial outputs remain. See
[the batch guide](04-batch-jobs.md) for more about Slurm.

## Reconnect after closing the terminal

**On your laptop:**

```bash
ssh chpc
```

**On the login node:**

```bash
export COREHPC="$HOME/corehpc"
source "$COREHPC/env.sh" &&
WORK=$(cat "$HOME/p1b7-last-workdir.txt") &&
export WORK &&
cd "$WORK" &&
JOB_ID=$(cat last-job-id.txt) &&
squeue -j "$JOB_ID"
```

Use your project's actual checkout path if you used a submodule. The saved
working-directory file points to the last example you staged, and the job
file points to the latest batch submission there. An interactive run has no
`last-job-id.txt`; use `ls out` to inspect its results instead.

## Add a structural template

A template supplies known structural information. In Boltz and Chai, the
bundle offers **8UDR itself** as a reference-template demonstration. Because
it supplies the known answer, this is a reconstruction exercise, not a blind
test of docking accuracy. The covalent bond remains a separate input; a
template does not replace it.

Protenix filters out near-identical self-template sequences. Its template
example therefore uses a related antibody structure and templates only the
eligible antibody chains. Its date filter and local structure cache also
need explicit configuration. The
[Protenix guide](../tools/protenix/README.md#run-it) explains this different
experiment; it is not equivalent to giving the complete 8UDR complex.

Read the chosen tool's template section, then **on the login node** preview
one mode before submitting it:

```bash
bash run.sh boltz template --dry-run &&
JOB_ID=$(sbatch --parsable p1b7.sbatch boltz template) &&
printf '%s\n' "$JOB_ID" | tee last-job-id.txt
```

Replace `boltz` in **both** lines with `chai1` or `protenix` for those
examples. Template and no-template modes have separate output directories.
Keep those conditions separate when comparing models.

For a later research run, MSAs must be prepared and staged before the GPU
job. Use the per-tool input instructions to specify local MSA paths and
confirm that their sequences match these exact chains. Do not turn on a
remote MSA/template-search flag inside a compute job. Local database searches
also belong on allocated compute resources; the login node is for downloads
and lightweight preparation. Do not assume an MSA from a truncated Fv input
matches the full Fab used here.

## Inspect the predicted bond

The runner checks the peptide–ligand geometry in the generated models. To
repeat the check later, **on the login node**, from your working directory:

```bash
python3 check_output.py boltz out/boltz-none
```

Use the actual tool and output directory printed by your run, for example
`chai1 out/chai1-template`. This is a small coordinate inspection, not a
prediction. Read [the bundle's checker description](../examples/p1b7/README.md)
for the atom mapping, accepted distances, and limits of the check.

A failed geometry check is a result worth keeping with its log, not a reason
to edit the threshold until the model passes. Review every model you plan
to use, including its chain identities, ligand, bond, and binding pose.
The general [covalent-bond guide](../tools/covalent-bonds.md) explains why
high confidence or a connectivity record alone cannot validate the chemistry.

## Save your results

Scratch can be purged after 30 days and at quarterly maintenance. **On the
login node**, after the job has stopped writing files, copy the whole small
tutorial run to your own directory within the lab's persistent results area:

```bash
export SAVE="$CHPC_LAB/results/$USER/$(basename "$WORK")"
mkdir -p "$SAVE" &&
cp -R "$WORK/." "$SAVE/" &&
diff -qr "$WORK" "$SAVE" &&
printf 'Saved run: %s\n' "$SAVE"
```

`diff` should print nothing and return successfully. Any differences or
permission error need attention before treating the copy as complete. Saving
the whole run keeps inputs, reference data, settings, logs, software commit,
and outputs together. Keep that path in your experiment notes. Do not run
subsequent predictions in this FAC copy; make a new scratch run instead.

To download the saved run, follow [Globus setup and transfer instructions](02-storage-and-data.md)
on your laptop. `SAVE` is a variable in the cluster shell, so it will not
automatically exist in a new laptop terminal: use the full saved path printed
above as the remote path. Do not use `scp` or `rsync` through the bastion.

## If something goes wrong

- **`chpc-tool: command not found`:** in a cluster shell, run
  `source /mnt/fac/CX500146_DS1/chpc.env` for the shared installation used
  by the laptop helper. If you chose a cluster checkout, source that
  checkout's `env.sh` instead. Then run `command -v chpc-tool`.
- **`No such file or directory`:** check `hostname`, `pwd`, and `ls`.
  A Mac path is not a cluster path; a file in the repo is not automatically
  in your scratch working directory.
- **The tool or weights are missing:** run `chpc-tool doctor boltz` (or your
  chosen tool). Send the output to the maintainer. Do not download shared
  weights from a compute node or rebuild a container for your first tutorial.
- **The output directory already exists:** inspect that earlier run first.
  To rerun, repeat the staging step to create a new timestamped `WORK`.
  Do not delete files just to make the error disappear.
- **The job keeps retrying a network service:** the first example should be
  entirely offline. Cancel it and compare your command against the dry run;
  check that you did not enable online MSA or template search.
- **CUDA out of memory:** this usually concerns GPU memory, not the Slurm
  host-memory request. Save the error and ask the maintainer about a larger
  permitted GPU or tool-specific memory settings. Do not silently remove
  chains or the ligand to make the scientific input fit.
- **`TIMEOUT`:** preserve the log and inspect how far the job got before
  choosing a longer time request for a fresh run.
- **Geometry check fails after model files appear:** the model may be
  chemically wrong despite a successful prediction process. Keep the files
  and review the named atoms/distances; do not report it as a validated model.

For help, provide the tool/mode, your working-directory path, job ID, final
`sacct` state, and relevant error lines from the log. Include the laptop
submission receipt and the run's `.chpc/submit/environment.txt`, or
`corehpc-commit.txt` if you followed the manual checkout route.
Never include passwords or access tokens.
