#!/bin/bash

set -euo pipefail

RANK=${SLURM_LOCALID:-${OMPI_COMM_WORLD_LOCAL_RANK:-}}
GLOBAL_RANK=${SLURM_PROCID:-${OMPI_COMM_WORLD_RANK:-unknown}}

if [ -z "$RANK" ]; then
  echo "SLURM_LOCALID not set; this script should be run under srun."
  exit 1
fi

# Slurm exposes the node's GPUs to each task; select one by local rank.
export CUDA_VISIBLE_DEVICES=$RANK
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=0

REGCM_EXE=${REGCM_EXE:-/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/Main/regcm}

if [ ! -x "$REGCM_EXE" ]; then
  echo "RegCM executable is missing or not executable: $REGCM_EXE" >&2
  exit 1
fi

echo "[Wrapper][Rank ${GLOBAL_RANK}][Local ${RANK}] host=$(hostname) CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} ACC_DEVICE_NUM=${ACC_DEVICE_NUM}"

exec "$REGCM_EXE" EURR-3_namelist.in
