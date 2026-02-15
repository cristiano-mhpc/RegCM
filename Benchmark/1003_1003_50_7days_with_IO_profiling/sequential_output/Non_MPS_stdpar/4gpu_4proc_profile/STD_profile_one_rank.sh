#!/bin/bash

# Get the local rank of the process on the node 
RANK=${SLURM_LOCALID}
RANK_GLOBAL=${SLURM_PROCID:-0}

# which global rank to profile 
: "${PROFILE_RANK:=0}" 

# Optional safety check
if [ -z "$RANK" ]; then
  echo "SLURM_LOCALID not set; this script should be run under srun."
  exit 1
fi

# GPU binding
export CUDA_VISIBLE_DEVICES=$RANK
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=$RANK

# Set binary and input paths
export BINDIR=/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin
INPUT_FILE=EURR-3_namelist.in 



if [[ "$RANK_GLOBAL" -eq "$PROFILE_RANK" ]]; then
    # Set a unique temp directory using TMPDIR only
    TMPDIR_BASE=$SCRATCH/tmp_nsys
    export TMPDIR=$TMPDIR_BASE/rank_${RANK_GLOBAL}
    mkdir -p "$TMPDIR"

    # Diagnostic: show system info
    echo "[Rank $SLURM_PROCID] on $(hostname): GPU=$CUDA_VISIBLE_DEVICES, TMPDIR=$TMPDIR"
    df -h /tmp
    df -h "$TMPDIR"

    # Set output path for Nsight profile
    NSYS_OUT="$SCRATCH/profile/nsys_rank${SLURM_PROCID}"

    # Ensure output directory exists
    mkdir -p "$(dirname "$NSYS_OUT")"

    # Launch with Nsight profiling
    nsys profile \
      --force-overwrite true \
      --stats=true \
      --sample=none \
      --output="$NSYS_OUT" \
      --stop-on-exit=true\
      --trace=cuda,nvtx,mpi \
      "$BINDIR/regcmMPICLM45_OPENACC_GPU_STDPAR" "$INPUT_FILE"
else 
    # Launch without profiling
    exec "$BINDIR/regcmMPICLM45_OPENACC_GPU_STDPAR" "$INPUT_FILE"
fi
