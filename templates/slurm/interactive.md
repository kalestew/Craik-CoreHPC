# Interactive one-liners

```bash
salloc -p cpu -c 4 --mem 8G -t 2:00:00                                     # CPU shell
srun -p community_short --qos=cmnt_short -c 2 --mem 4G --pty bash -l       # 1 h smoke test (--qos required)
salloc -p community -c 8 --mem 32G -t 2-00:00:00                            # long serial work, usually no wait
srun -p gpu --gres=gpu:1 -c 8 --mem 32G -t 4:00:00 --pty bash -l           # any GPU
srun -p gpu --gres=gpu:nvidia_h100_nvl:1 -c 8 --mem 64G -t 4:00:00 --pty bash -l
srun --jobid=<JOBID> --nodelist=<node> --pty bash                          # attach to a running job
```
