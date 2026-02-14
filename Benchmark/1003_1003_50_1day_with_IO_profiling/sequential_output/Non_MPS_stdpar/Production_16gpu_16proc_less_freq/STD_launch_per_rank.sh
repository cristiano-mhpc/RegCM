#!/bin/bash
# STD_launch_per_rank.sh

# Pick local rank: prefer OpenMPI, fall back to Slurm
if [ -n "$OMPI_COMM_WORLD_LOCAL_RANK" ]; then
    LOCAL_RANK=$OMPI_COMM_WORLD_LOCAL_RANK
elif [ -n "$SLURM_LOCALID" ]; then
    LOCAL_RANK=$SLURM_LOCALID
else
    echo "ERROR: No local rank variable found (OMPI or SLURM)." >&2
    env | grep -E 'OMPI|SLURM' >&2
    exit 1
fi

# Pick global rank: prefer OpenMPI, fall back to Slurm
if [ -n "$OMPI_COMM_WORLD_RANK" ]; then
    GLOBAL_RANK=$OMPI_COMM_WORLD_RANK
elif [ -n "$SLURM_PROCID" ]; then
    GLOBAL_RANK=$SLURM_PROCID
else
    GLOBAL_RANK=$LOCAL_RANK
fi

# One GPU per local rank on each node
export CUDA_VISIBLE_DEVICES=$LOCAL_RANK
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=$LOCAL_RANK

export BINDIR=/u/external/ctica/MS_thesis/RegCM/bin

printf '[Wrapper][Rank %02d][Local %02d] on %s: CUDA_VISIBLE_DEVICES=%s ACC_DEVICE_NUM=%s\n' \
       "$GLOBAL_RANK" "$LOCAL_RANK" "$(hostname)" "$CUDA_VISIBLE_DEVICES" "$ACC_DEVICE_NUM"

exec "$BINDIR/regcmMPICLM45" EURR-3_namelist.in

