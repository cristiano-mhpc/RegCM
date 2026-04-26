#!/bin/bash
# ORFEO optimized per-rank launcher

LOCAL_RANK=$OMPI_COMM_WORLD_LOCAL_RANK
GLOBAL_RANK=$OMPI_COMM_WORLD_RANK

if [ -z "$LOCAL_RANK" ]; then
  echo "ERROR: Must be run with mpirun"
  exit 1
fi

########################################
# GPU binding
########################################
export CUDA_VISIBLE_DEVICES=$LOCAL_RANK
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=0

########################################
# REMOVE DEBUG SLOWDOWN
########################################
unset CUDA_LAUNCH_BLOCKING

########################################
# UCX tuning (safe baseline)
########################################
export UCX_TLS=cma,rc,mm,cuda_copy,cuda_ipc
export UCX_RNDV_THRESH=128
export UCX_RNDV_FRAG_MEM_TYPE=cuda
export UCX_RNDV_FRAG_SIZE=cuda:32M

########################################
# CPU + NUMA binding (CRITICAL)
########################################

case ${LOCAL_RANK} in
0)
  CPU_RANGE=0-13
  MEM_NODE=0
  NIC=mlx5_0:1
  ;;
1)
  CPU_RANGE=14-27
  MEM_NODE=1
  NIC=mlx5_1:1
  ;;
2)
  CPU_RANGE=28-41
  MEM_NODE=2
  NIC=mlx5_2:1
  ;;
3)
  CPU_RANGE=42-55
  MEM_NODE=3
  NIC=mlx5_3:1
  ;;
4)
  CPU_RANGE=56-69
  MEM_NODE=4
  NIC=mlx5_4:1
  ;;
5)
  CPU_RANGE=70-83
  MEM_NODE=5
  NIC=mlx5_5:1
  ;;
6)
  CPU_RANGE=84-97
  MEM_NODE=6
  NIC=mlx5_6:1
  ;;
7)
  CPU_RANGE=98-111
  MEM_NODE=7
  NIC=mlx5_7:1
  ;;
esac

########################################
# NIC binding (UCX)
########################################
export UCX_NET_DEVICES=$NIC

########################################
# Threading (match Everett)
########################################
export OMP_NUM_THREADS=14
export MKL_NUM_THREADS=14
export OMP_PROC_BIND=true
export OMP_PLACES=cores

########################################
# Debug print
########################################
echo "[Rank $GLOBAL_RANK | Local $LOCAL_RANK]"
echo "  GPU: $CUDA_VISIBLE_DEVICES"
echo "  CPU: $CPU_RANGE"
echo "  NUMA: $MEM_NODE"
echo "  NIC: $NIC"

########################################
# Launch
########################################
BINDIR=/orfeo/cephfs/home/external/ctica/ICTP_RegCM/RegCM/bin

exec numactl --physcpubind=$CPU_RANGE --membind=$MEM_NODE \
  $BINDIR/regcmMPICLM45 EURR-3_namelist.in
