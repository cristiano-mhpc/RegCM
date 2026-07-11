#!/bin/bash

set -euo pipefail

RANK=${SLURM_LOCALID:-}

if [ -z "$RANK" ]; then
  echo "SLURM_LOCALID not set; this script should be run under srun."
  exit 1
fi

# One rank per GPU. CUDA_VISIBLE_DEVICES exposes one physical GPU to each rank;
# OpenACC/stdpar should then select device 0 inside that restricted view.
export CUDA_VISIBLE_DEVICES=$RANK
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=0

export BINDIR=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM/bin
export REGCM_EXE=${REGCM_EXE:-$BINDIR/regcmMPICLM45}

echo "[Wrapper][Rank ${SLURM_PROCID}][Local ${SLURM_LOCALID}] host=$(hostname) CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES} ACC_DEVICE_NUM=${ACC_DEVICE_NUM} REGCM_EXE=${REGCM_EXE}"

exec "$REGCM_EXE" EURR-3_namelist.in
