# CoreHPC live facts

Not captured yet. Run `scripts/chpc-prime.sh` (answer Duo) and then
`scripts/chpc-discover.sh` from this repo; it replaces this file with the
live partition table, QoS limits, your accounts, full module lists (top
level, CBI, Sali, nvidia-hpc), Apptainer version and bind configuration,
storage mounts and quotas, and the FAC / group-scratch directories visible
to you. Commit the result so the lab has a dated snapshot.
