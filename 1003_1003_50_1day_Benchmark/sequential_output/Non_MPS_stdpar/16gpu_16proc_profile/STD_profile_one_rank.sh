#!/bin/bash
set -x

RANK_GLOBAL=${SLURM_PROCID:-0}
RANK_LOCAL=${SLURM_LOCALID:-0}

PROFILE_RANK=0  # Which rank to profile
TRACE_DOMAINS=${TRACE_DOMAINS:-nvtx}
NSYS_SAMPLE=${NSYS_SAMPLE:-none}

BINDIR=${BINDIR:-/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin}
BIN=${BIN:-regcmMPICLM45_OPENACC_GPU_STDPAR}
INPUT_FILE=EURR-3_namelist.in


# Respect Slurm GPU binding if present; else fallback
if [[ -z "${CUDA_VISIBLE_DEVICES:-}" ]]; then
  export CUDA_VISIBLE_DEVICES="$RANK_LOCAL"
fi
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM="${CUDA_VISIBLE_DEVICES%%,*}"
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}

# Precreate dirs in the SBATCH script (not per rank). Keep wrapper light.
NSYS_OUT="${SCRATCH:-/tmp/$USER}/profile/nsys_rank${RANK_GLOBAL}"

# Launch quickly and symmetrically
if [[ "$RANK_GLOBAL" -eq "$PROFILE_RANK" ]]; then
  exec nsys profile \
    --force-overwrite=true \
    --stats=false \
    --stop-on-exit=true \
    --capture-range-end=stop \ 
    --sample="$NSYS_SAMPLE" \
    --trace="$TRACE_DOMAINS" \
    --output="$NSYS_OUT" \
    "$BINDIR/$BIN" "$INPUT_FILE"
else
  exec "$BINDIR/$BIN" "$INPUT_FILE"
fi

