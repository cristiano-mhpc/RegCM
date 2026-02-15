#!/bin/bash
# launch_per_rank.sh

# Get the rank of the current MPI process
# RANK=${SLURM_PROCID} # This is global MPI rank, not local
RANK=${SLURM_LOCALID}

# Optional safety check
if [ -z "$RANK" ]; then
  echo "SLURM_LOCALID not set; this script should be run under srun."
  exit 1
fi

# Assign each local rank to a unique GPU on this node
export CUDA_VISIBLE_DEVICES=$RANK
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=$SLURM_LOCALID
export BINDIR=/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin

echo "[Wrapper][Rank $SLURM_PROCID][Local $SLURM_LOCALID] on $(hostname): CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"

# Launch the binary
exec $BINDIR/regcmMPIOPENACC_GPU_STDPAR_RCEMIP isc24_small.in

