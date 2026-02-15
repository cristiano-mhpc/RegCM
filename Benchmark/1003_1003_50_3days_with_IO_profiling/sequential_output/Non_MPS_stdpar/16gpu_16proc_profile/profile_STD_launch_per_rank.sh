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
export ACC_DEVICE_NUM=0

# ----------------------------
# Nsight Systems (newer CLI)
# ----------------------------
NSYS_BIN="/leonardo/prod/opt/compilers/nvhpc/25.3/binary/Linux_x86_64/25.3/compilers/bin/nsys"

# Set binary and input paths
export BINDIR=/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin/profile_binary
INPUT_FILE=EURR-3_namelist.in

# Set a unique temp directory using TMPDIR only
TMPDIR_BASE=$SCRATCH/tmp_nsys
export TMPDIR=$TMPDIR_BASE/rank_${SLURM_PROCID}
mkdir -p "$TMPDIR"

# Set output path for Nsight profile
NSYS_OUT="$SCRATCH/profile_new_nsys_16gpu/nsys_rank${SLURM_PROCID}"

# Launch with Nsight profiling
$NSYS_BIN profile \
  --force-overwrite true \
  --stats=true \
  --sample=process-tree \
  --backtrace=dwarf \
  --output "$NSYS_OUT" \
  --sampling-trigger=perf \
  --sampling-period=1000000 \ 
  --trace=nvtx,mpi,cuda,osrt \
  --mpi-impl=openmpi \
  --cuda-um-cpu-page-faults=true \
  --cuda-um-gpu-page-faults=true \
  --cuda-memory-usage=true \
  "$BINDIR/regcmMPICLM45_OPENACC_GPU_STDPAR" "$INPUT_FILE"

