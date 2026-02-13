#!/bin/bash
# launch_per_rank.sh

# Get the rank of the current MPI process
LOCAL_RANK=$OMPI_COMM_WORLD_LOCAL_RANK
GLOBAL_RANK=$OMPI_COMM_WORLD_RANK

export CUDA_LAUNCH_BLOCKING=1     # pin runtime error to the exact line
NUM_GPUS=${SLURM_GPUS_ON_NODE}

# 4 GPUs shared among 8 ranks:
GPU_ID=$(( LOCAL_RANK % 4 ))

# Assign each local rank to a unique GPU on this node
export CUDA_VISIBLE_DEVICES=$GPU_ID 
export ACC_DEVICE_TYPE=nvidia
export BINDIR=/gpfs/home/ictp/ictp549985/RegCM/bin

# Reduce contention for 2 ranks per GPU
export CUDA_MPS_ACTIVE_THREAD_PERCENTAGE=50

# Diagnostic 
echo "[Wrapper][Rank $GLOBAL_RANK][Local $LOCAL_RANK] using GPU $GPU_ID on $(hostname)"

# Launch the binary
exec $BINDIR/regcmMPICLM45 EURR-3_namelist.in 
