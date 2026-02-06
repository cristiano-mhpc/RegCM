#!/bin/bash
# STD_launch_per_rank.sh

# Pick local rank: prefer OpenMPI, fall back to Slurm
LOCAL_RANK=$OMPI_COMM_WORLD_LOCAL_RANK
GLOBAL_RANK=$OMPI_COMM_WORLD_RANK

# One GPU per local rank on each node
export CUDA_VISIBLE_DEVICES=$LOCAL_RANK
export BINDIR=/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin

printf '[Wrapper][Rank %02d][Local %02d] on %s: CUDA_VISIBLE_DEVICES=%s ACC_DEVICE_NUM=%s\n' \
       "$GLOBAL_RANK" "$LOCAL_RANK" "$(hostname)" "$CUDA_VISIBLE_DEVICES" "$ACC_DEVICE_NUM"

echo "rank=$OMPI_COMM_WORLD_RANK local=$OMPI_COMM_WORLD_LOCAL_RANK host=$(hostname) CVD=$CUDA_VISIBLE_DEVICES"

exec "$BINDIR/regcmMPICLM45_OPENACC_GPU_STDPAR" EURR-3_namelist.in

