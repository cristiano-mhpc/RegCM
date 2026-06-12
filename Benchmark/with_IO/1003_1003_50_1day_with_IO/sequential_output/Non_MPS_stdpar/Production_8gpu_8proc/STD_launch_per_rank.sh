#!/bin/bash
# STD_launch_per_rank.sh

set -euo pipefail

RANK=${SLURM_LOCALID:-}

if [ -z "$RANK" ]; then
  echo "SLURM_LOCALID not set; this script should be run under srun."
  exit 1
fi

# export CUDA_LAUNCH_BLOCKING=1

# One rank per GPU. Since CUDA_VISIBLE_DEVICES exposes only one GPU,
# OpenACC should select device 0 inside that restricted view.
export CUDA_VISIBLE_DEVICES=$RANK
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=0

export BINDIR=/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin

echo "[Wrapper][Rank ${SLURM_PROCID}][Local ${SLURM_LOCALID}] host=$(hostname) CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} ACC_DEVICE_NUM=${ACC_DEVICE_NUM}"

exec "$BINDIR/regcmMPICLM45_OPENACC_STDPAR" EURR-3_namelist.in
