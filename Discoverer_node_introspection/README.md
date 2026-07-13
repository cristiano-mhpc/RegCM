# Discoverer+ Node Introspection

This directory contains Discoverer+ compute-node topology and `mem:unified` probe artifacts.

## Layout

```text
scripts/        Slurm submit scripts for new introspection/probe runs.
runs/           Archived completed run outputs, grouped by job/node/purpose.
introspection/  Staging area for logs and job-specific outputs from pending/running jobs.
```

New probe jobs write their working outputs under:

```text
introspection/${SLURM_JOB_ID}_${SLURM_JOB_NAME}/
```

After completion, move that job-specific directory into `runs/` with an informative name.

## Scripts

```text
scripts/discoverer_node_introspection_mem_unified_probe.job
scripts/discoverer_node_introspection_mem_unified_probe_dgx2_7gpu.job
```

The scripts use absolute Slurm log paths and derive the introspection root from the script location, so they can be submitted from any current working directory.

## Archived Runs

### `runs/179466_dgx1_8gpu_initial_openacc_probe/`

Initial completed `dgx1` 8-GPU introspection job.

Important files:

```text
logs/LOG_discoverer_node_intro_8gpu_179466.out
logs/LOG_discoverer_node_intro_8gpu_179466.err
topology/topo_info.txt
topology/gpu_topology.txt
topology/gpu_list.txt
network/ucx_devices.txt
environment/slurm_env.txt
probes/mem_unified_support.txt
```

Result summary:

```text
MEM_UNIFIED_RUNTIME_PROBE=PASS
```

The OpenACC probe compiled and ran with `-gpu=cc90,lineinfo,mem:unified`, but the compiler reported an implicit copy for the test array.

### `runs/179509_dgx1_8gpu_strict_cuda_hmm_probe/`

Completed `dgx1` 8-GPU introspection job with both the original OpenACC probe and a stricter CUDA pageable host-memory probe.

Important files:

```text
logs/LOG_discoverer_node_intro_8gpu_179509.out
logs/LOG_discoverer_node_intro_8gpu_179509.err
topology/topo_info.txt
topology/gpu_topology.txt
topology/gpu_list.txt
network/ucx_devices.txt
environment/slurm_env.txt
probes/mem_unified_support.txt
probes/mem_unified_probe.cpp
probes/cuda_hmm_pageable_probe.cu
```

Result summary:

```text
MEM_UNIFIED_RUNTIME_PROBE=PASS
cudaDevAttrPageableMemoryAccess=1
cudaDevAttrConcurrentManagedAccess=1
cudaDevAttrManagedMemory=1
cuda_hmm_pageable_probe: PASS
CUDA_HMM_PAGEABLE_PROBE=PASS
```

This is stronger evidence for pageable host-memory/HMM-style support than the OpenACC probe alone.

## Pending Runs

`179586` attempted the `dgx2` 7 normal-GPU probe but failed before introspection because the script derived its base directory from Slurm's spool copy of the batch script. The scripts were patched to use the explicit project introspection root.

`179836` is the resubmitted `dgx2` 7 normal-GPU probe. Its output will appear in `introspection/` when the job starts.

## Notes

The completed `dgx1` topology showed 8 H200 GPUs connected pairwise by `NV18`, GPUs `0-3` associated with NUMA node 0, GPUs `4-7` associated with NUMA node 1, and 12 mlx5 NICs visible in `nvidia-smi topo -m`.
