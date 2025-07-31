#!/bin/bash

# Get local rank
RANK=${SLURM_LOCALID}

if [ -z "$RANK" ]; then
  echo "SLURM_LOCALID not set; this script should be run under srun."
  exit 1
fi

# GPU binding
export CUDA_VISIBLE_DEVICES=$RANK
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=$RANK

# Set binary and input paths
# export BINDIR=/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin

export BINDIR=/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/profile_binary
INPUT_FILE=isc24_small.in

# Set a unique temp directory using TMPDIR only
TMPDIR_BASE=$SCRATCH/tmp_nsys
export TMPDIR=$TMPDIR_BASE/rank_${SLURM_PROCID}
mkdir -p "$TMPDIR"

# Diagnostic: show system info
echo "[Rank $SLURM_PROCID] on $(hostname): GPU=$CUDA_VISIBLE_DEVICES, TMPDIR=$TMPDIR"
df -h /tmp
df -h "$TMPDIR"

# Set output path for Nsight profile
NSYS_OUT="$SCRATCH/profile/nsys_rank${SLURM_PROCID}"

# Launch with Nsight profiling
nsys profile \
  --force-overwrite true \
  --stats=true \
  --output "$NSYS_OUT" \
  --trace=cuda,nvtx,osrt,mpi \
  "$BINDIR/regcmMPIOPENACC_GPU_STDPAR_RCEMIP" "$INPUT_FILE"

