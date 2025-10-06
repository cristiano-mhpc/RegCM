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
export ACC_DEVICE_NUM=0
# Set thread count for stdpar=multicore
export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK 

export BINDIR=/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin/profile_binary 
INPUT_FILE=EURR-3_namelist.in

# ----------------------------
# Nsight Systems (newer CLI)
# ----------------------------
NSYS_BIN="/leonardo/prod/opt/compilers/nvhpc/25.3/binary/Linux_x86_64/25.3/compilers/bin/nsys"

# Set a unique temp directory using TMPDIR only
TMPDIR_BASE=$SCRATCH/tmp_nsys
export TMPDIR=$TMPDIR_BASE/rank_${SLURM_PROCID}
mkdir -p "$TMPDIR"

# Set output path for Nsight profile
NSYS_OUT="$SCRATCH/DCGP/800proc/nsys_rank${SLURM_PROCID}"

echo "[Wrapper][Rank $SLURM_PROCID][Local $SLURM_LOCALID] on $(hostname): CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"

# Launch with Nsight profiling
$NSYS_BIN profile \
  --force-overwrite true \
  --stats=true \
  --sample=process-tree \
  --backtrace=dwarf \
  --output "$NSYS_OUT" \
  --trace=nvtx,mpi,cuda,osrt \
  --mpi-impl=openmpi \
  --cuda-um-cpu-page-faults=true \
  --cuda-um-gpu-page-faults=true \
  --cuda-memory-usage=true \
  "$BINDIR/regcmMPICLM45" "$INPUT_FILE"



