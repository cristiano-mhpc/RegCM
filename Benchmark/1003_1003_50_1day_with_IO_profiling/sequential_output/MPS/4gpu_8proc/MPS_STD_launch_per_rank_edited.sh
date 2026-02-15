#!/bin/bash

RANK=${SLURM_LOCALID:-}
if [ -z "$RANK" ]; then
  echo "SLURM_LOCALID not set"
  exit 1
fi

# Determine number of GPUs available on this node.
# Prefer SLURM_GPUS_ON_NODE (numeric). SLURM_GPUS_PER_NODE can be formatted.
NUM_GPUS=""
if [ -n "${SLURM_GPUS_ON_NODE:-}" ]; then
  NUM_GPUS="${SLURM_GPUS_ON_NODE}"
elif [ -n "${SLURM_GPUS_PER_NODE:-}" ]; then
  NUM_GPUS="$(echo "${SLURM_GPUS_PER_NODE}" | grep -oE '[0-9]+' | head -n1 || true)"
elif [ -n "${CUDA_VISIBLE_DEVICES:-}" ]; then
  # If SLURM already set a device list, count it
  NUM_GPUS="$(awk -F',' '{print NF}' <<< "${CUDA_VISIBLE_DEVICES}")"
fi
NUM_GPUS="${NUM_GPUS:-1}"

# 4 GPUs shared among 8 ranks per node: map local rank -> GPU id
GPU_ID=$(( RANK % NUM_GPUS ))

# Constrain each rank to a single GPU. With CUDA_VISIBLE_DEVICES set to one id,
# that GPU becomes device 0 inside the process, so ACC_DEVICE_NUM should be 0.
export CUDA_VISIBLE_DEVICES="${GPU_ID}"
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=0

export BINDIR=/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin

echo "[Wrapper][Rank $SLURM_PROCID][Local $RANK] using GPU_ID=$GPU_ID (visible as device 0) on $(hostname)"

# Launch the binary
exec "$BINDIR/regcmMPICLM45_OPENACC_GPU_STDPAR" EURR-3_namelist.in
