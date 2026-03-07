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
export BINDIR=/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin
INPUT_FILE=isc24_small.in

# Set a unique temp directory using TMPDIR only
TMPDIR_BASE=$SCRATCH/tmp_nsys
export TMPDIR=$TMPDIR_BASE/rank_${SLURM_PROCID}
mkdir -p "$TMPDIR"

# Set output path for Nsight profile
NSYS_OUT="$SCRATCH/NSight/no_IO/16gpu_16proc/nsys_rank${SLURM_PROCID}"
mkdir -p "$NSYS_OUT" 
umask 007   # files created with 600 permissions 

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
  "$BINDIR/regcmMPIOPENACC_STDPAR_RCEMIP" "$INPUT_FILE"

