#!/bin/bash

# Get local rank
RANK_GLOBAL=${SLURM_PROCID:-0}
RANK_LOCAL=${SLURM_LOCALID:-0}

PROFILE_RANK=0  # Which rank to profile
TRACE_DOMAINS=${TRACE_DOMAINS:-nvtx}
NSYS_SAMPLE=${NSYS_SAMPLE:-none}

# Set binary and input paths
BINDIR=${BINDIR:-/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin}
BIN=${BIN:-regcmMPIOPENACC_GPU_STDPAR_RCEMIP}
INPUT_FILE=isc24_small.in

# Respect Slurm GPU binding if present; else fallback
export CUDA_VISIBLE_DEVICES="$RANK_LOCAL"
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=$RANK_LOCAL 
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}


# Set a unique temp directory using TMPDIR only
TMPDIR_BASE=$SCRATCH/tmp_nsys_one_rank 
export TMPDIR=$TMPDIR_BASE/rank_${SLURM_PROCID}
mkdir -p "$TMPDIR"

# Precreate dirs in the SBATCH script (not per rank). Keep wrapper light.
NSYS_OUT="${SCRATCH:-/tmp/$USER}/profile_one_rank/nsys_rank${RANK_GLOBAL}"

# Launch quickly and symmetrically
if [[ "$RANK_GLOBAL" -eq "$PROFILE_RANK" ]]; then
  exec nsys profile \
    --duration=900 \
    --force-overwrite=true \
    --kill=none \
    --stats=true \
    --sample="$NSYS_SAMPLE" \
    --trace="$TRACE_DOMAINS" \
    --output="$NSYS_OUT" \
    "$BINDIR/$BIN" "$INPUT_FILE"
else
  exec "$BINDIR/$BIN" "$INPUT_FILE"
fi


