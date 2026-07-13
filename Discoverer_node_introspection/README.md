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

The scripts use absolute Slurm log paths and an explicit `BASE_DIR` pointing at this project introspection root, so they can be submitted from any current working directory. This avoids relying on `${BASH_SOURCE[0]}`, which can point at Slurm's spool copy inside a running batch job.

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

### `runs/179836_dgx2_7gpu_strict_cuda_hmm_probe/`

Completed `dgx2` 7 normal-GPU introspection job with both the original OpenACC probe and the stricter CUDA pageable host-memory probe.

Important files:

```text
logs/LOG_discoverer_node_intro_dgx2_7gpu_179836.out
logs/LOG_discoverer_node_intro_dgx2_7gpu_179836.err
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
cudaPointerGetAttributes_status=no error
cuda_hmm_pageable_probe: PASS
CUDA_HMM_PAGEABLE_PROBE=PASS
```

Slurm environment:

```text
SLURM_JOB_NODELIST=dgx2
SLURM_NTASKS=7
SLURM_NTASKS_PER_NODE=7
SLURM_CPUS_PER_TASK=2
SLURM_GPUS_ON_NODE=7
CUDA_VISIBLE_DEVICES=0,1,2,3,4,5,6
GPU_DEVICE_ORDINAL=0,1,2,3,4,5,6
```

This job requested 7 normal GPUs because an 8 normal-GPU request on `dgx2` was rejected by Slurm. The node still reported 8 H200 devices through `nvidia-smi`, while Slurm exposed devices `0-6` for the 7-GPU allocation.

## Failed/Retried Runs

`179586` attempted the `dgx2` 7 normal-GPU probe but failed before introspection because the script derived its base directory from Slurm's spool copy of the batch script. The scripts were patched to use the explicit project introspection root, and the run was successfully repeated as `179836`.

## Notes

The completed `dgx1` topology showed 8 H200 GPUs connected pairwise by `NV18`, GPUs `0-3` associated with NUMA node 0, GPUs `4-7` associated with NUMA node 1, and 12 mlx5 NICs visible in `nvidia-smi topo -m`.
