# 1. Access and SSH

## Prerequisites

- A UCSF campus account (or Medical Center account). Collaborators need a
  UCSF affiliate account sponsored by the PI; start that HR process early.
- Duo/MFA enrolled on a personal device
  (<https://it.ucsf.edu/how-to/enrolling-your-first-device-duo>).
- UCSF VPN, or the on-campus `UCSFwpa` Wi-Fi. CoreHPC recommends VPN even on
  campus. The bastions are unreachable from anywhere else.
- The lab must have a FAC capacity-storage share before onboarding
  (<https://tiny.ucsf.edu/getfac>). CoreHPC will not onboard a user without it.
- Your PI requests the account at <https://tiny.ucsf.edu/Gethpc>. Each
  account carries a $155/yr access charge (as of July 2026).
- Your username is your short campus login (e.g. `jdoe`). Find it in
  MyAccess: profile menu, "go to profiles", then "account details".

## Topology

```
laptop --VPN--> chpc-ucsf-bastion-vm1.corehpc.ucsf.edu  (Duo; no internet, no cluster storage)
                       |  (alternate: chpc-ucsf-bastion-vm2)
                       v
                chpc-ucsf-login-vm1   (submit jobs, modules, internet via proxy, /home + /mnt/scratch + /mnt/fac)
                       |
                       v  SLURM
                compute nodes         (no internet; same /home, /mnt/scratch, /mnt/fac; local /tmp NVMe)
```

- Home directories are shared across login and compute nodes but NOT on the
  bastions. The bastion has its own tiny home, so SSH keys must be installed
  there separately.
- The login node is for job submission, editing, small builds, downloads.
  Resource-intensive processes on it get killed.

## Manual login (what the wiki describes)

```bash
ssh <username>@chpc-ucsf-bastion-vm1.corehpc.ucsf.edu   # password + Duo
# on the bastion:
ssh chpc-ucsf-login-vm1
```

## One-hop, one-Duo login (what we actually use)

`ssh/config.example` in this repo does three things:

1. `ProxyJump` so `ssh chpc` tunnels through the bastion transparently.
2. `ControlMaster`/`ControlPersist` so the first connection to the bastion
   answers Duo once and every later `ssh`, `scp`, `rsync`, VS Code session
   for the next 10 hours reuses that socket with no prompt.
3. Key-based auth to both hosts.

### Setup steps

```bash
# 1. Create a dedicated key (no passphrase prompts once loaded into the agent/keychain)
ssh-keygen -t ed25519 -f ~/.ssh/chpc -C "$(whoami)-mac-chpc"

# 2. Install the SSH config (edit User= to your campus username)
cp ssh/config.example ~/.ssh/config      # or append if you already have one
chmod 600 ~/.ssh/config

# 3. Put the public key on the BASTION (its home is separate). Password + Duo once:
ssh-copy-id -i ~/.ssh/chpc.pub chpc-bastion

# 4. Put the public key on the LOGIN node (shared home for the whole cluster):
ssh-copy-id -i ~/.ssh/chpc.pub chpc          # bastion hop is now key-based; Duo once

# 5. Test
ssh chpc hostname                              # answers Duo, prints chpc-ucsf-login-vm1
ssh chpc hostname                              # second time: instant, no Duo
```

If `ssh-copy-id` is unavailable:
`cat ~/.ssh/chpc.pub | ssh chpc-bastion 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'`.

### Daily use

```bash
scripts/chpc-prime.sh          # = ssh chpc hostname; answers Duo, opens the master sockets
ssh chpc                       # shell on login node
scp file.txt chpc:/mnt/scratch/user/$USER/
rsync -avP data/ chpc:/mnt/scratch/group/CX500146_DS1/data/
ssh chpc 'squeue -u $USER'
```

### Stale sockets after a VPN drop

Symptoms: `ssh chpc` hangs, or "Connection closed by UNKNOWN port 65535".

```bash
ssh -O exit chpc; ssh -O exit chpc-bastion      # tear down masters
rm -f ~/.ssh/cm-*                               # if -O exit itself hangs
ssh chpc hostname                               # re-prime (Duo)
```

`ssh -O check chpc` tells you whether a master is alive.

### Bastion vm1 down

Use `chpc-bastion2` directly, or temporarily change `ProxyJump chpc-bastion`
to `ProxyJump chpc-bastion2` in the `Host chpc` block.

## Open OnDemand (browser)

<https://chpc-ucsf-ondemand-vm1.corehpc.ucsf.edu/> (beta, VPN required) gives a
web shell plus JupyterLab, RStudio, VS Code and MATLAB sessions that run as
SLURM jobs. Conda envs become Jupyter kernels as described in
`docs/06-software-modules-conda.md`.

## VS Code Remote-SSH

Works with the config above: choose host `chpc`. Prime the socket in a
terminal first so the Duo prompt is not swallowed by VS Code. Keep the remote
workspace on scratch, not home (the VS Code server itself lands in `~/.vscode-server`
and counts toward the 20 GiB home quota; delete old versions occasionally).

## Sessions that outlive your SSH connection

On the login node, `tmux` and `screen` work, and wrapping them in a user
systemd scope keeps them alive for up to 24 h after logout:

```bash
systemd-run --scope --user tmux          # start
tmux detach                              # or Ctrl-b d
tmux ls; tmux attach -t <name>           # later
```

Do not type `exit` inside a session you want to keep. For screen:
`screen -D -R <name>` creates-or-reattaches.

## Security reminders (from the AUP)

- Accounts are personal; never share credentials or keys.
- Access only from UCSF networks/VPN and from endpoints meeting the UCSF
  Minimum Endpoint Security Standard.
- Activity is logged. No persistent network services or reverse tunnels
  without authorization.
