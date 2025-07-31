#!/bin/bash
# the local rank on the node 
RANK=${SLURM_LOCALID}

if [ -z "$RANK" ]; then
  echo "SLURM_LOCALID not set"
  exit 1
fi

#The number of MPI ranks on this node
NUM_RANKS=${SLURM_NTASKS_PER_NODE:-1} # Fallback to 1 if not set

# The number of GPUs allocated on the node
NUM_GPUS=${SLURM_GPUS_PER_NODE:-1} # Fallback to -1 if not set

# Distribute the ranks to the GPUs: Block scheduling. 
# Assume: the NUM_RANKS is a multiple of NUM_GPUS 
GPU_ID=$(( RANK * NUM_GPUS / NUM_RANKS ))

export CUDA_VISIBLE_DEVICES=$GPU_ID
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=$GPU_ID
export BINDIR=/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin

echo "[Wrapper][Rank $SLURM_PROCID][Local $RANK] using GPU $GPU_ID on $(hostname)"


# Launch the binary 
exec $BINDIR/regcmMPIOPENACC_GPU_STDPAR_RCEMIP isc24_small.in

