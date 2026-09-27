# OpenMM 8

| | |
|---|---|
| Status | **built** 2026-09-26 — image built and published; the CUDA platform is unproven until `test.sh` runs on a GPU node, which is **queued** |
| Image | `openmm_8.sif` from [`openmm_8.def`](openmm_8.def); 575 MB on a `condaforge/miniforge3` base |
| GPU | yes, and the point of the entry. `GPU_MAX_CC` is deliberately **empty** — see below |
| Weights | none. An MD engine; the force field comes with your system |
| Licence | MIT (LGPL for some plugins) — **no licence to chase**, which is why this exists beside `amber` |
| Upstream | <https://openmm.org/>, conda-forge `openmm` 8.6.1, python 3.12, `cuda-version` **13.2** |
| Citation | Eastman et al., *PLoS Comput Biol* **13**(7), 2017, [1005659](https://doi.org/10.1371/journal.pcbi.1005659) |

OpenMM is the **unlicensed alternative to Amber** for near-attack-fraction work
and any other molecular dynamics the programme needs. [`amber`](../amber/README.md)
needs a paid site licence for `pmemd`, and [`gromacs`](../gromacs/README.md) is
a third option; this one has nothing to buy and nothing to wait for.

## Run it

Nothing to fetch and nothing staged on FAC.

The remaining step for `verified` is the test, which **requires a GPU node**
because the CUDA platform cannot be registered without a driver:

```bash
chpc-tool test openmm               # GPU NODE REQUIRED -- this is what `verified` means
```

The production commands, from [`test.sh`](test.sh) and **not yet run on a GPU**:

```bash
salloc -p gpu --gres=gpu:nvidia_l40s:1 -c 8 --mem 32G -t 2:00:00
chpc-tool exec openmm -- python -m openmm.testInstallation      # (untested)
chpc-tool exec openmm -- python my_simulation.py                # (untested)
```

Any GPU model works — `nvidia_l40s`, `nvidia_h100_nvl` or the Blackwell
`nvidia_rtx_pro_6000` — because OpenMM compiles its kernels at run time rather
than shipping fixed SASS. That is why `GPU_MAX_CC` is empty here and not a
measurement anybody still owes: there is no architecture list to exceed, and
the sm_120 problem in [doc 05](../../docs/05-partitions-and-hardware.md) does
not apply. It is the only GPU entry in this registry that can say that.

Build and publish: [`../README.md`, Add a tool](../README.md#add-a-tool).

## Why this is a container and not a conda entry

Same reason as [`anarci`](../anarci/README.md). The entry was declared
`KIND=conda` because conda-forge is where the CUDA builds come from, which is a
fact about the packages and not about how the lab should carry them. An
environment under `$CHPC_USER_SCRATCH/envs` is per-user and lives on scratch,
which is purged at 30 days and wiped at quarterly maintenance. An MD engine the
lab is meant to reach for belongs on FAC, built once.

## Do not miss

- **NAME THE PLATFORM. OpenMM falls back to the CPU silently.** If you do not
  pass a platform, OpenMM picks the fastest one it managed to register — and on
  an installation whose CUDA plugin failed to load, that is the CPU. The
  simulation then runs, produces correct physics, and takes a week instead of
  an hour, reporting nothing wrong at any point. Always:

  ```python
  platform = openmm.Platform.getPlatformByName("CUDA")
  simulation = app.Simulation(topology, system, integrator, platform)
  ```

- **An import proves nothing about CUDA, by design.**
  `openmm/__init__.py` calls `Platform.loadPluginsFromDirectory` and **never
  raises** when a plugin fails; the errors are only retrievable through
  `openmm.Platform.getPluginLoadFailures()`. So the module imports, reports its
  version, and the CUDA platform is simply absent. The symptom, much later, is
  `There is no registered Platform called "CUDA"` with only `Reference` and
  `CPU` in the list. `test.sh` reads the load failures **first**, so a broken
  stack reports its reason rather than only its consequence.
- **`%test` in the recipe does not check CUDA, and that is not an oversight.**
  Registering the CUDA platform needs the NVIDIA driver. The login node is the
  only node with internet, so it is the only node that can build — and it has
  no driver and not even `nvidia-smi`. So the recipe's `%post` and `%test`
  assert the **payload** (`libOpenMMCUDA.so`, `libcufft`, `libnvrtc`, and that
  the CUDA 13 build is the one that got solved) and [`test.sh`](test.sh)
  asserts the **behaviour** on a GPU node. Claiming CUDA works from a node that
  cannot try is how an image gets published broken.
- **`CONDA_OVERRIDE_CUDA` is load-bearing in the build.** conda chooses its
  CUDA build by reading the `__cuda` virtual package, which is the maximum CUDA
  version the *display driver* supports. A driverless login node reports no
  `__cuda` at all, so the solver is free to pick a build the compute nodes
  cannot run. OpenMM's own FAQ names this as "especially common when installing
  on clusters that do not have GPUs (and hence do not have a CUDA driver) on
  the login nodes", and the symptom is `CUDA_ERROR_UNSUPPORTED_PTX_VERSION` in
  a job. The recipe sets `CONDA_OVERRIDE_CUDA=13.2` and pins `cuda-version=13`
  to match the compute nodes; conda-forge's CUDA 12.9 and CUDA 13 builds are
  not binary compatible with each other.
- **The kernel cache needs somewhere writable.** A `.sif` is a read-only
  squashfs, so `%environment` points `OPENMM_CACHE_DIR` at `/tmp`, which
  apptainer binds, is local NVMe on a compute node, and is per-node so
  concurrent array tasks cannot collide.

---

## Provenance

**Never run.** `STATUS=planned`; the image is not built. Everything below is
what the test will prove.

### What `test.sh` will prove, and why it needs a GPU node

There is deliberately no way to skip the CUDA half. An escape hatch is a thing
that gets used at 6pm and then quoted back as a green test.

| # | Asserted |
|---|---|
| 1 | `getPluginLoadFailures()` is empty — read first, so a broken stack reports its reason |
| 2 | `CUDA` is in the registered platform list |
| 3 | a `Context` builds on it, which is what forces the kernels to compile against this driver |
| 4 | the harmonic-bond energy is **0.5 kJ/mol**, exactly |
| 5 | the CUDA answer agrees with the `Reference` platform's on the same system |
| 6 | `python -m openmm.testInstallation` runs and exercises CUDA |

Case 4 is arithmetic rather than a tolerance dressed up as one: a bond of
stiffness 100 kJ/mol/nm² stretched to 0.2 nm from a 0.1 nm equilibrium is
exactly ½·100·(0.1)² = 0.5 kJ/mol. A GPU computing on uninitialised memory, or
running kernels built for the wrong architecture, does not land on 0.5. Case 5
is the stronger form of the same idea — two independent implementations
agreeing beats either matching a number written in a test file. Case 3 is what
catches a CUDA build mismatched to the driver, and it cannot be reached by
inspecting an installation, only by running one.

### Verified against upstream, 2026-09-26

- conda-forge `openmm` 8.6.1, with linux-64 builds for cp311 through cp314
  only — cp310 was dropped after 8.6.0, so this recipe pins python 3.12;
- there is **no** separate CUDA variant package and no `openmm-cuda`: the CUDA
  platform is in the same package, selected through the `cuda-version`
  metapackage, and 8.6.1 offers exactly two variants, `>=12.9,<13` and
  `>=13.0,<14`;
- the feedstock **skips** non-CUDA linux-64 builds, so every linux-64 `openmm`
  has CUDA compiled in — which is precisely why a missing `libcufft` and not a
  missing plugin is the usual cause of an absent CUDA platform;
- no system CUDA toolkit is needed, only the driver; conda pulls
  `cuda-nvrtc`, `libcufft` and the OpenCL loader itself;
- that the import path swallows plugin load failures, and that
  `Platform.getPluginLoadFailures()` is the only way to see them;
- the FAQ text about driverless login nodes and
  `CUDA_ERROR_UNSUPPORTED_PTX_VERSION`, and that `CONDA_OVERRIDE_CUDA`
  overrides the `__cuda` detection.

**Not** verified, and left to the first run on a GPU node: which precision mode
the CUDA platform defaults to on each of our three GPU models, and the device
name it reports. `test.sh` prints both rather than asserting them.
