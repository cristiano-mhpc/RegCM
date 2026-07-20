#!/bin/bash

set -euo pipefail

LOCAL_RANK=${SLURM_LOCALID:-${OMPI_COMM_WORLD_LOCAL_RANK:-}}
GLOBAL_RANK=${SLURM_PROCID:-${OMPI_COMM_WORLD_RANK:-0}}

if [ -z "$LOCAL_RANK" ]; then
  echo "[DiscovererTopo] ERROR: cannot determine local rank. Run under srun or mpirun." >&2
  exit 1
fi

# Discoverer+ DGX H200 topology from node introspection job 179466 on dgx1:
# GPU0-3 are NUMA 0, GPU4-7 are NUMA 1. The listed HCAs are the closest
# active 400 Gb/s InfiniBand devices for their corresponding GPUs.
case "$LOCAL_RANK" in
  0) GPU=0; CPUSET="+0-1";   NUMA_NODE=0; UCX_NET_DEVICES_LOCAL="mlx5_0:1"  ;;
  1) GPU=1; CPUSET="+2-3";   NUMA_NODE=0; UCX_NET_DEVICES_LOCAL="mlx5_3:1"  ;;
  2) GPU=2; CPUSET="+4-5";   NUMA_NODE=0; UCX_NET_DEVICES_LOCAL="mlx5_4:1"  ;;
  3) GPU=3; CPUSET="+6-7";   NUMA_NODE=0; UCX_NET_DEVICES_LOCAL="mlx5_5:1"  ;;
  4) GPU=4; CPUSET="+8-9";   NUMA_NODE=1; UCX_NET_DEVICES_LOCAL="mlx5_6:1"  ;;
  5) GPU=5; CPUSET="+10-11"; NUMA_NODE=1; UCX_NET_DEVICES_LOCAL="mlx5_9:1"  ;;
  6) GPU=6; CPUSET="+12-13"; NUMA_NODE=1; UCX_NET_DEVICES_LOCAL="mlx5_10:1" ;;
  7) GPU=7; CPUSET="+14-15"; NUMA_NODE=1; UCX_NET_DEVICES_LOCAL="mlx5_11:1" ;;
  *)
    echo "[DiscovererTopo] ERROR: local rank $LOCAL_RANK is invalid for one rank per GPU on DGX H200." >&2
    exit 2
    ;;
esac

export CUDA_VISIBLE_DEVICES=$GPU
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=0

export OMP_NUM_THREADS=${OMP_NUM_THREADS:-${SLURM_CPUS_PER_TASK:-1}}
export OMP_PROC_BIND=true
export OMP_PLACES=cores

if [ "${REGCM_ENABLE_NIC_PINNING:-auto}" = "auto" ]; then
  if [ "${SLURM_NNODES:-1}" -gt 1 ]; then
    export UCX_NET_DEVICES=$UCX_NET_DEVICES_LOCAL
  fi
elif [ "${REGCM_ENABLE_NIC_PINNING:-auto}" = "1" ]; then
  export UCX_NET_DEVICES=$UCX_NET_DEVICES_LOCAL
fi

if [ "${REGCM_ENABLE_UCX_TUNING:-0}" = "1" ]; then
  export OMPI_MCA_pml=${OMPI_MCA_pml:-ucx}
  export OMPI_MCA_osc=${OMPI_MCA_osc:-ucx}
  if [ "${SLURM_NNODES:-1}" -eq 1 ]; then
    # Single-node DGX H200 runs should stay on shared-memory/CUDA IPC paths.
    # The previous unconstrained UCX profile hit mm_posix/UD setup failures.
    export UCX_TLS=${UCX_TLS:-self,sysv,cuda_copy,cuda_ipc}
  else
    export UCX_TLS=${UCX_TLS:-self,sysv,cuda_copy,cuda_ipc,rc}
  fi
fi

if [ "${REGCM_ENABLE_ACC_POOL:-0}" = "1" ]; then
  export NVCOMPILER_ACC_POOL_SIZE=${NVCOMPILER_ACC_POOL_SIZE:-48GB}
  export NVCOMPILER_ACC_POOL_THRESHOLD=${NVCOMPILER_ACC_POOL_THRESHOLD:-95}
  export NVCOMPILER_ACC_POOL_ALLOC_MAXSIZE=${NVCOMPILER_ACC_POOL_ALLOC_MAXSIZE:-1500MB}
fi

export BINDIR=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM/bin
export REGCM_EXE=${REGCM_EXE:-$BINDIR/regcmMPICLM45}

echo "[DiscovererTopo][Rank ${GLOBAL_RANK}][Local ${LOCAL_RANK}] host=$(hostname) gpu=${GPU} cpuset=${CPUSET} numa=${NUMA_NODE} CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} ACC_DEVICE_NUM=${ACC_DEVICE_NUM} UCX_NET_DEVICES=${UCX_NET_DEVICES:-auto} UCX_TLS=${UCX_TLS:-auto} REGCM_EXE=${REGCM_EXE}"

if [ "${REGCM_ENABLE_CPU_BINDING:-1}" = "1" ] && command -v numactl >/dev/null 2>&1; then
  exec numactl --physcpubind="$CPUSET" --membind="$NUMA_NODE" "$REGCM_EXE" EURR-3_namelist.in
fi

exec "$REGCM_EXE" EURR-3_namelist.in
