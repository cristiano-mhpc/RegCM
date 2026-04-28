#!/bin/bash
# ORFEO Level 2 wrapper: topology-derived, no-guessing version

LOCAL_RANK=${OMPI_COMM_WORLD_LOCAL_RANK}
GLOBAL_RANK=${OMPI_COMM_WORLD_RANK}

if [ -z "$LOCAL_RANK" ]; then
  echo "ERROR: OMPI_COMM_WORLD_LOCAL_RANK is not set. Run under mpirun."
  exit 1
fi

# 1 rank -> 1 GPU
export CUDA_VISIBLE_DEVICES=${LOCAL_RANK}
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=0

# Remove debug slowdown if it was inherited
unset CUDA_LAUNCH_BLOCKING

# Match the production CPU allocation model
export OMP_NUM_THREADS=14
export MKL_NUM_THREADS=14
export OMP_PROC_BIND=true
export OMP_PLACES=cores

# Exact GPU -> CPU/NUMA/NIC mapping from dgx004 topology
case "${LOCAL_RANK}" in
  0)
    CPU_RANGE="0-13"
    MEM_NODE="0"
    NIC_DEV="mlx5_0:1"
    ;;
  1)
    CPU_RANGE="28-41"
    MEM_NODE="2"
    NIC_DEV="mlx5_1:1"
    ;;
  2)
    CPU_RANGE="42-55"
    MEM_NODE="3"
    NIC_DEV="mlx5_2:1"
    ;;
  3)
    CPU_RANGE="14-27"
    MEM_NODE="1"
    NIC_DEV="mlx5_3:1"
    ;;
  4)
    CPU_RANGE="56-69"
    MEM_NODE="4"
    NIC_DEV="mlx5_4:1"
    ;;
  5)
    CPU_RANGE="84-97"
    MEM_NODE="6"
    NIC_DEV="mlx5_5:1"
    ;;
  6)
    CPU_RANGE="98-111"
    MEM_NODE="7"
    NIC_DEV="mlx5_6:1"
    ;;
  7)
    CPU_RANGE="70-83"
    MEM_NODE="5"
    NIC_DEV="mlx5_7:1"
    ;;
  *)
    echo "ERROR: unexpected LOCAL_RANK=${LOCAL_RANK}"
    exit 1
    ;;
esac

# Use the topology-matched HCA only
export UCX_NET_DEVICES="${NIC_DEV}"

BINDIR=/orfeo/cephfs/home/external/ctica/ICTP_RegCM/RegCM/bin

echo "[Wrapper][Rank ${GLOBAL_RANK}][Local ${LOCAL_RANK}] host=$(hostname) GPU=${CUDA_VISIBLE_DEVICES} CPU=${CPU_RANGE} NUMA=${MEM_NODE} NIC=${NIC_DEV}"

exec numactl --physcpubind="${CPU_RANGE}" --membind="${MEM_NODE}" \
  "${BINDIR}/regcmMPICLM45" EURR-3_namelist.in
