# Amber (the licensed `pmemd` engine)

| | |
|---|---|
| Status | planned — **blocked on a paid licence**, not on work. Everything that does not need one is [`ambertools`](../ambertools/README.md) |
| Install to be | `$CHPC_SOFTWARE/amber26`, a native build of `pmemd` and `pmemd.cuda` against CUDA 13.2 |
| GPU | yes, and that is the whole point of the engine |
| Licence | **paid Amber site licence** from <https://ambermd.org/>. AmberTools is open source and separate |
| Upstream | <https://ambermd.org/> |
| Citation | Case et al., *Amber 2026*; cite the release used |

This entry is **only the licensed MD engine**: `pmemd` and `pmemd.cuda`.
Everything else that ships under the Amber name — `tleap`, `antechamber`,
`parmchk2`, `parmed`, `cpptraj`, `pdb4amber`, `sander` — is open source and
lives in [`ambertools`](../ambertools/README.md), which is built and needs no
licence.

## Not built yet

Nothing can be built here until the lab has a licence. There is no tarball to
download, no conda package, and no container: the Amber engine source is
distributed only to licensees.

### Before buying one, check whether it is needed

The honest answer for most of what this programme does is that it is not:

| Want | Needs a licence? | Route |
|---|---|---|
| Build and parameterise a system | no | [`ambertools`](../ambertools/README.md): `tleap`, `antechamber` |
| Parameterise a novel ligand | no | [`ambertools`](../ambertools/README.md): `antechamber` + `parmchk2` with GAFF2 |
| GPU molecular dynamics | **no** | [`openmm`](../openmm/README.md), reading the Amber `prmtop`/`inpcrd` directly |
| Analyse a trajectory | no | [`ambertools`](../ambertools/README.md): `cpptraj` |
| Short CPU MD / equilibration | no | [`ambertools`](../ambertools/README.md): `sander` |
| Long production MD, large system, maximum single-GPU throughput | **yes** | `pmemd.cuda` — this entry |

OpenMM reads Amber topologies through `openmm.app.AmberPrmtopFile`, so
`ambertools` → `openmm` → `cpptraj` is a complete, licence-free path that runs
on all three of our GPU models. `pmemd.cuda` earns its licence on long
production runs of large systems, where its single-GPU throughput is why people
buy it. It does not earn it to run a few nanoseconds on the final one to three
designs, which is what this entry's note has always said it is for.

### On the day the licence arrives

1. **Record the licence.** Put the licence file or entitlement record in
   `$CHPC_LICENSES/amber/`, mode 640, group only — the same handling as
   [`foldx`](../foldx/README.md). `lab/bin/chpc-assets` is the mechanism, and
   `lab/README.md` describes the directory and its ACL.
2. **Get the source onto the cluster.** It arrives as a tarball from a
   licensee download. It is a licensed payload, so it does not go into git: put
   it on your laptop, `chpc-globus.sh push` it to your scratch
   ([doc 02B-storage-and-data.md#laptop-to-cluster-globus-is-the-normal-transfer-route)), and build
   from there.
3. **Build on a GPU node, not the login node.** `pmemd.cuda` must be compiled
   against the CUDA toolkit and will want to see a device. The login node has no
   driver and not even `nvidia-smi`, which is exactly the trap that
   [`openmm`](../openmm/README.md) documents for conda. Ask for the oldest
   architecture you intend to run on and build for all three:
   L40S is sm_89, H100 NVL sm_90, RTX PRO 6000 Blackwell sm_120.
4. **Install under `$CHPC_SOFTWARE/amber26`**, so the `PREFIX` in `tool.conf` is
   right without editing, and so the binaries are on FAC rather than on scratch,
   which is purged. [`rosetta`](../rosetta/README.md) is the worked example of a
   native install here, including the trap that made its first build useless:
   binaries linked against libraries that were sitting on scratch.
5. **Write a `test.sh`** that asserts `pmemd.cuda` actually integrates on the
   GPU, not that the binary prints usage. The pattern to copy is
   [`../ambertools/test.sh`](../ambertools/test.sh) stage 4: run a short
   minimisation and assert the energy falls. Add an assertion that the run used
   the GPU — `pmemd.cuda` names the device in its output header — because
   `pmemd` and `pmemd.cuda` take the same arguments and a script that calls the
   wrong one gets a correct answer slowly.
6. Set `UPSTREAM_REF` to the exact Amber release, fill in this README's build
   record, flip `STATUS`, and commit.

## Do not miss

- **`AmberTools` and `Amber` are two products with two licences, and the split
  is not where people expect.** The tools everybody uses daily are free; the
  engine is not. This registry used to carry both under one entry, and the
  result was that a missing paid binary made the free toolchain report as
  broken and nobody could use `tleap`.
- **`sander` is not a substitute for `pmemd.cuda`, and it is not nothing
  either.** It ships free in `ambertools`, runs the same force fields, and is
  CPU-only. For equilibration, for testing an input, and for anything short, it
  is the right tool. For production it is orders of magnitude off.
- **A GPU MD run without a licence is available today**, via
  [`openmm`](../openmm/README.md). If somebody is waiting on this entry to do
  molecular dynamics at all, they are waiting unnecessarily.
- **Build against the node driver.** CUDA 13.2. A `pmemd.cuda` built against an
  older toolkit will fail on the Blackwell nodes with "no kernel image is
  available for execution on the device", intermittently, depending on what was
  free — the sm_120 problem in
  [doc 05](../../docs/05-partitions-and-hardware.md). Set `GPU_MAX_CC` in
  `tool.conf` if the build cannot cover all three models.
