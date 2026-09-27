# 1. Access and SSH

Start here if you have never used a terminal or logged into CoreHPC. You
need an activated account before the login steps will work. This page gets
you to the **login node**; [interactive jobs](03-interactive-jobs.md) and
[batch jobs](04-batch-jobs.md) explain how to run work on a **compute node**.
For the structure-prediction example, continue to the
[P1B7 / 8UDR walkthrough](11-p1b7-walkthrough.md) after setup.

## Before copying a command

On a Mac, open **Applications → Utilities → Terminal**. On Windows, use the
terminal supplied with your Linux/WSL environment or ask a lab member to
help set that up. The command blocks below use a Unix shell (Bash or zsh).

- Paste a command block into the terminal, then press **Return**. Run the
  blocks in order, stopping if you see an error. Lines beginning with `#`
  are explanatory comments. In macOS zsh, run `setopt interactivecomments`
  once if you want to paste comment lines along with commands.
- A **prompt** is the text the terminal shows before you type. Do not copy
  a prompt such as `$` or `username@hostname`. Our command blocks omit it.
- Passwords and key passphrases show **no characters**, even while you type.
  Type the password and press Return once; this is normal.
- `Ctrl-C` means hold Control and press C. It interrupts the current
  foreground command. It does not cancel a batch job you already submitted.
- `~` means your home directory on the machine where the command runs.
  `$USER` expands to your username on that machine. Your Mac username may
  differ from your campus username.
- `pwd` prints your current folder; `ls` lists its contents; `cd` changes
  folders. A path beginning with `/` is an absolute path. Quote paths and
  variables as shown so spaces are handled correctly.
- Some commands span several lines with a final `\`. Paste the whole block;
  the backslash joins the next line to the same command. A temporary `>`
  prompt means the shell is waiting for the rest of a command.

**Check where you are whenever unsure:**

```bash
hostname
whoami
pwd
```

Before connecting, `hostname` prints your laptop's name. After connecting
with `ssh chpc`, it should print `chpc-ucsf-login-vm1` (possibly with a domain
suffix). `exit` leaves the current shell: from the login node it returns you
to your laptop. Opening another terminal window starts a new local shell;
it does not automatically connect to CoreHPC.

## Prerequisites

- A UCSF campus account (or Medical Center account). Collaborators need a
  UCSF affiliate account sponsored by the PI; start that HR process early.
- Duo/MFA enrolled on a personal device
  (<https://it.ucsf.edu/how-to/enrolling-your-first-device-duo>).
- UCSF VPN. CoreHPC's wiki says the on-campus `UCSFwpa` Wi-Fi also works and
  merely recommends VPN; treat the VPN as required until you have checked
  otherwise from the subnet you are on (verified 2026-09-21 from `UCSFwpa`,
  client address `10.63.130.229`: port 22 on both bastions, `10.98.128.32` and
  `10.98.128.33`, does not connect, and `traceroute` dies after three
  campus-core hops; with the tunnel up both answer `SSH-2.0-OpenSSH_9.9`
  immediately). The bastions are unreachable from anywhere else.
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

## First login: check your account

**On your laptop**, connect the UCSF VPN first. Then paste this block. At
the question, type your own **short campus username**, such as `jdoe` (not
your email address or the example name), and press Return:

```bash
printf 'Your short UCSF campus username: '
read -r CHPC_LOGIN
```

After entering your username, run this next block:

```bash
ssh "$CHPC_LOGIN@chpc-ucsf-bastion-vm1.corehpc.ucsf.edu"
```

At the first connection SSH may ask about a host key. Verify the host's
fingerprint with CoreHPC support before accepting an unfamiliar key; do not
ignore a warning that an existing host key has changed. Enter your campus
password and complete Duo when asked.

**Now on the bastion**, enter:

```bash
ssh chpc-ucsf-login-vm1
```

Once that connection finishes, **on the login node**:

```bash
hostname
whoami
```

The hostname should now contain `chpc-ucsf-login-vm1`, and `whoami` should
be your campus username. The bastion is only an entry point; it is not where
you submit jobs or store your project files.

For the one-time setup below, return to your laptop. Run each `exit`
separately and check the hostname afterward:

```bash
exit
```

You are back on the bastion. Then:

```bash
exit
```

Check the location with `hostname`. You should now see your laptop's hostname. If manual login failed, resolve
that with CoreHPC support before proceeding to SSH-key setup.

## Set up the shorter `ssh chpc` command

This configuration gives the two cluster hosts short names, tunnels the login
connection through the bastion, and reuses authenticated connections for up
to 10 hours. You still complete Duo when required. The configuration matches
[this repository's SSH example](../ssh/config.example); the steps below
preserve any SSH settings you already have.

### 1. Create a dedicated SSH key on your laptop

**On your laptop:**

```bash
mkdir -p "$HOME/.ssh"
chmod 700 "$HOME/.ssh"
if [ -e "$HOME/.ssh/chpc" ] || [ -e "$HOME/.ssh/chpc.pub" ]; then
  printf 'A CoreHPC key already exists. Keep it; do not overwrite it.\n'
else
  ssh-keygen -t ed25519 -f "$HOME/.ssh/chpc" -C "$(whoami)-chpc"
fi
```

Choose a passphrase when prompted, then type it again. Keep the private key
`~/.ssh/chpc` private. The `.pub` file is the public half, which the next steps
install on the cluster. If only one of the two files exists, ask for help
recovering the pair before continuing.

### 2. Append the host configuration on your laptop

This asks for your campus username again so it also works in a fresh terminal.
It backs up an existing config and appends the CoreHPC entries. First enter
your username:

```bash
printf 'Your short UCSF campus username: '
read -r CHPC_LOGIN
```

Then run this whole block, including the last `EOF` and `fi` lines:

```bash
if [ -z "$CHPC_LOGIN" ]; then
  printf 'No username entered. Run this block again.\n'
elif [ -f "$HOME/.ssh/config" ] && grep -Eq '^[[:space:]]*Host[[:space:]].*chpc' "$HOME/.ssh/config"; then
  printf 'CoreHPC entries already exist. Review ~/.ssh/config instead of appending duplicates.\n'
else
  if [ -f "$HOME/.ssh/config" ]; then
    cp -p "$HOME/.ssh/config" "$HOME/.ssh/config.before-chpc.$(date +%Y%m%d-%H%M%S)"
  fi
  cat >> "$HOME/.ssh/config" <<EOF

Host chpc-bastion chpc-bastion2 chpc
  IgnoreUnknown UseKeychain
  User $CHPC_LOGIN
  IdentityFile ~/.ssh/chpc
  AddKeysToAgent yes
  UseKeychain yes
  ControlMaster auto
  ControlPath ~/.ssh/cm-%r@%h-%p
  ControlPersist 10h
  ServerAliveInterval 60
  ServerAliveCountMax 3

Host chpc-bastion
  HostName chpc-ucsf-bastion-vm1.corehpc.ucsf.edu

Host chpc-bastion2
  HostName chpc-ucsf-bastion-vm2.corehpc.ucsf.edu

Host chpc
  HostName chpc-ucsf-login-vm1
  ProxyJump chpc-bastion
EOF
  chmod 600 "$HOME/.ssh/config"
fi
```

Check what SSH will use; this command does not connect:

```bash
ssh -G chpc | grep -E '^(hostname|user|identityfile|proxyjump) '
```

Expect `hostname chpc-ucsf-login-vm1`, your campus username, the `chpc` key,
and `proxyjump chpc-bastion`. If an earlier `Host *` entry sets a different
username, move the CoreHPC blocks above that general entry using
`nano ~/.ssh/config` (Control-O, Return to save; Control-X to close).

### 3. Install the public key on both hosts

**On your laptop**, run these one at a time. They append the public key
without replacing existing keys. The bastion and login node have different
home directories, so both commands are needed:

```bash
cat "$HOME/.ssh/chpc.pub" | ssh chpc-bastion 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

```bash
cat "$HOME/.ssh/chpc.pub" | ssh chpc 'mkdir -p ~/.ssh && chmod 700 ~/.ssh && cat >> ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys'
```

Enter your password, key passphrase and/or Duo response when requested.
If either command reports an error, stop and resolve it before continuing.
Then test twice:

```bash
ssh chpc hostname
ssh chpc hostname
```

Both should print the login node hostname. The second normally reuses the
connection without another Duo prompt. To test key authentication after the
initial installation, close the masters and connect again:

```bash
ssh -O exit chpc
ssh -O exit chpc-bastion
ssh chpc hostname
```

A `No such file or directory` message from `ssh -O exit` just means no master
was open for that host. Reconnecting may ask for Duo again.

### Daily use

**On your laptop**, connect VPN, then:

```bash
ssh chpc
```

**On the login node**, confirm the location and list your jobs:

```bash
hostname
squeue -u "$USER"
```

A header with no jobs underneath means you have no queued or running jobs.
Continue to the [first batch job](04-batch-jobs.md#your-first-batch-job) or
[P1B7 structure-prediction walkthrough](11-p1b7-walkthrough.md).
When you are finished with the login shell, type `exit`.

If you have this repository on your laptop, `scripts/chpc-prime.sh` is a
convenience command that authenticates and opens the shared SSH connections.
You can also check the queue without opening an interactive shell:

```bash
ssh chpc 'squeue -u "$USER"'
```

The single quotes ensure `$USER` is evaluated on CoreHPC rather than your
laptop, where your username might be different.

Data does **not** travel over this alias. The approved transfer paths are
Globus, the FAC share and Open OnDemand ([storage and transfers](02-storage-and-data.md)).
The CoreHPC training stated that `scp`/`rsync` through the bastion is not
permitted. The scripted transfer route is `scripts/chpc-globus.sh`: bytes
travel over Globus; the FAC leg uses SSH only to run a cluster-local copy.

## Troubleshooting the connection

### GlobalProtect will not connect while on `UCSFwpa`

Symptom: the VPN client sits at `Disconnected` on campus Wi-Fi but connects
normally from `UCSFguest`. Two things were found behind it on 2026-09-21, and
either alone is enough.

**A stale cached portal config.** Portal login hands the client its gateway
list; when that login fails the client falls back to the list it cached last.
The cached list named one gateway, `gp-ucsf-mb.ucsf.edu` (`64.54.0.228`),
which did not answer, and switching portals in the dropdown does not help
because both entries resolve to the cache. The log reads:

```
Failed to pre-login to the portal gp-ucsf.ucsf.edu
portal status is Using cached portal config
Gateway gp-ucsf-mb: The network connection is unreachable or the gateway is unresponsive.
```

A successful login from `UCSFguest` the same hour returned a different,
working gateway (`gp-ucsf-prn.ucsf.edu`, Parnassus) and refreshed the cache.

**`UCSFwpa` itself cannot complete a TLS handshake to either gateway address.**
Tested later the same day with the fresh list, from `10.63.130.229`, VPN off:

| address | `nc -z` | real TLS handshake |
|---|---|---|
| `64.54.0.227` (`gp-ucsf-prn`) | OPEN | **fails** |
| `64.54.0.228` (`gp-ucsf`, `gp-ucsf-mb`) | fails | fails |

`gp-ucsf.ucsf.edu` is a CNAME that moves between those two addresses, which
is why the portal looked reachable in the morning and not in the evening. Test
a gateway with `openssl s_client` or `curl`, never with a port check: `nc`
reported the first address open while the client's own pre-login was failing
against it. Whether this is all of `UCSFwpa` or one subnet is unknown, and
CoreHPC has been reached from `UCSFwpa` on this account before. The table
above is what to hand IT when asking.

**Workaround:** join `UCSFguest`, connect GlobalProtect (this refreshes the
cached config), then prime the SSH master. Logs worth reading when it recurs:
`/Library/Logs/PaloAltoNetworks/GlobalProtect/pan_gp_event.log` and
`~/Library/Logs/PaloAltoNetworks/GlobalProtect/PanGPA.log`.

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
systemd-run --scope --user tmux new -s work
```

To detach while leaving work running, press Control-B, release both keys,
then press D. After reconnecting with `ssh chpc`, run:

```bash
tmux ls
tmux attach -t work
```

Do not type `exit` inside a session you want to keep. See the full
[interactive reconnect example](03-interactive-jobs.md#keep-the-session-alive-across-disconnects).
For screen, `screen -D -R work` creates or reattaches to the named session.

## Security reminders (from the AUP)

- Accounts are personal; never share credentials or keys.
- Access only from UCSF networks/VPN and from endpoints meeting the UCSF
  Minimum Endpoint Security Standard.
- Activity is logged. No persistent network services or reverse tunnels
  without authorization.
