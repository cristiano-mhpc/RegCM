#!/bin/bash

RANK=${SLURM_LOCALID}
if [ -z "$RANK" ]; then
  echo "SLURM_LOCALID not set"
  exit 1
fi

# 4 GPUs shared among 8 ranks:
GPU_ID=$(( RANK % 4 ))

export CUDA_VISIBLE_DEVICES=$GPU_ID
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=$GPU_ID
export BINDIR=/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin

echo "[Wrapper][Rank $SLURM_PROCID][Local $RANK] using GPU $GPU_ID on $(hostname)"


# Launch the binary 
exec $BINDIR/regcmMPIOPENACC_GPU_STDPAR_RCEMIP isc24_small.in

