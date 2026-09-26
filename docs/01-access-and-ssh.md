# 1. Access and SSH

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
   answers Duo once and every later `ssh`, VS Code session and `chpc-*.sh`
   script for the next 10 hours reuses that socket with no prompt.
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
ssh chpc 'squeue -u $USER'
```

Data does **not** travel over this alias. The AUP's approved transfer paths are
Globus, the FAC share and Open OnDemand (doc 02); `scp`/`rsync` through the
bastion is not among them and the CoreHPC training stated it is not permitted.
The master socket is for interactive shells and remote commands. The scripted
route is `scripts/chpc-globus.sh` (doc 02): the bytes go over Globus, and its
FAC leg uses this socket only for the cluster-local copy.

### GlobalProtect will not connect while on `UCSFwpa`

Symptom: the VPN client sits at `Disconnected` on campus Wi-Fi but connects
normally from `UCSFguest`. It is not internal-host-detection suppressing the
tunnel — there is no tunnel to suppress.

**The cause is a stale cached portal config, not the Wi-Fi as such.** Portal
login is what hands the client its gateway list. When that login fails the
client falls back to whatever list it cached last, and on 2026-09-21 that
cached list named exactly one gateway, `gp-ucsf-mb.ucsf.edu`
(`64.54.0.228:443`), which did not answer. The portal itself,
`gp-ucsf.ucsf.edu` (`64.54.0.227:443`), *was* reachable from `UCSFwpa` — only
the pre-login failed:

```
Failed to pre-login to the portal gp-ucsf.ucsf.edu
portal status is Using cached portal config
Gateway gp-ucsf-mb: The network connection is unreachable or the gateway is unresponsive.
<status>Disconnected</status>   <tunnel>no</tunnel>
```

A successful portal login the same hour, from `UCSFguest`, returned a
different and working gateway — `gp-ucsf-prn.ucsf.edu` (Parnassus) — and the
IPSec tunnel came straight up. So `gp-ucsf-mb` looks retired or down, and the
client had been pinned to it by the cache. Both entries in the portal dropdown
resolve to the cached gateway, so switching portals does not help.

**Tested later the same day, with the fresh list: `UCSFwpa` still cannot get
there.** From `10.63.130.229`, VPN off, the two portal/gateway addresses behave
differently and neither is usable:

| address | `nc -z` | real TLS handshake |
|---|---|---|
| `64.54.0.227` (`gp-ucsf-prn`) | OPEN | **fails** |
| `64.54.0.228` (`gp-ucsf`, `gp-ucsf-mb`) | fails | fails |

So the stale cache was a real second problem, but it was never the only one.
`gp-ucsf.ucsf.edu` is a CNAME to `gp-ucsf.lbdn.ucsf.edu` and moves between the
two addresses, which is why the portal looked reachable in the morning and did
not in the evening — the name had changed address, not the network.

**`nc -z` lies here, and it lied both times.** `64.54.0.227:443` completes a TCP
handshake and then no TLS session — something in path answers the SYN with
nothing behind it. A control (`ucsf.edu:443`) agrees between `nc` and `curl`, so
the tool is fine and the result is real. Test a gateway with `openssl s_client`
or `curl`, never with a port check: a port check reported this one open while
GlobalProtect's own pre-login was failing against it.

Whether this is all of `UCSFwpa` or one subnet is still unknown, and CoreHPC has
been reached from `UCSFwpa` on this account before. The evidence above is what to
hand CoreHPC or IT when asking; the working answer meanwhile is `UCSFguest` plus
the VPN.

Workaround: join `UCSFguest`, connect GlobalProtect (this refreshes the cached
config), then prime the SSH master. Logs worth reading when this recurs:
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
