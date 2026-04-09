#!/bin/bash
# launch_per_rank.sh

# Get the rank of the current MPI process
LOCAL_RANK=${OMPI_COMM_WORLD_LOCAL_RANK}
GLOBAL_RANK=${OMPI_COMM_WORLD_RANK}

# Optional safety check
if [ -z "$LOCAL_RANK" ] || [ -z "$GLOBAL_RANK" ]; then
  echo "OMPI rank variables not set; this script should be run under mpirun."
  exit 1
fi

# Benchmark mode: keep GPU launches asynchronous (no debug serialization)
unset CUDA_LAUNCH_BLOCKING

# Assign each local rank to a unique GPU on this node
export CUDA_VISIBLE_DEVICES=$LOCAL_RANK
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=0

#------------
# Nsight Systems Profiling
#-----------------------
export SCRATCH=/gpfs/scratch/ehpc575
export BINDIR=/home/ictp/ictp549985/RegCM/bin
INPUT_FILE=EURR-3_namelist.in

printf '[Wrapper][Rank %02d][Local %02d] on %s: CUDA_VISIBLE_DEVICES=%s ACC_DEVICE_NUM=%s\n' \
"$GLOBAL_RANK" "$LOCAL_RANK" "$(hostname)" "$CUDA_VISIBLE_DEVICES" "$ACC_DEVICE_NUM"

# Set a unique temp directory using a rank-unique suffix
TMPDIR_BASE=$SCRATCH/tmp_nsys
export TMPDIR=$TMPDIR_BASE/rank_${GLOBAL_RANK}
mkdir -p "$TMPDIR"

# Set output path for Nsight profile
NSYS_DIR="$SCRATCH/NSight/with_IO/16gpu_16proc/Nsight_${SLURM_JOB_ID}"
NSYS_OUT="$NSYS_DIR/sys_rank${GLOBAL_RANK}"
mkdir -p "$NSYS_DIR"
umask 007   # files created with 600 permissions 

NSYS_MODE=${NSYS_MODE:-canopy}
PROFILE_RANKS=${PROFILE_RANKS:-all}

should_profile_rank=0
if [ "$PROFILE_RANKS" = "all" ]; then
  should_profile_rank=1 else
  for rank in ${PROFILE_RANKS//,/ }; do
    if [ "$rank" = "$GLOBAL_RANK" ]; then
      should_profile_rank=1
      break
    fi
  done
fi

if [ "$should_profile_rank" -eq 1 ]; then
  NSYS_ARGS=(
    profile
    --force-overwrite=true
    --stats=true
    --output "$NSYS_OUT"
    --trace=nvtx,cuda,openacc
    --cuda-um-cpu-page-faults=true
    --cuda-um-gpu-page-faults=true
    --cuda-memory-usage=true
  )

  if [ "$NSYS_MODE" = "canopy" ]; then
    NSYS_ARGS+=(
      --capture-range=nvtx
      --capture-range-end=repeat:1
      --sample=none
      --cpuctxsw=none
    )
  fi

  printf '[Wrapper][Rank %02d] profiling mode=%s output=%s\n' \
    "$GLOBAL_RANK" "$NSYS_MODE" "$NSYS_OUT"
  nsys "${NSYS_ARGS[@]}" "$BINDIR/regcmMPICLM45" "$INPUT_FILE"
else
  printf '[Wrapper][Rank %02d] profiling disabled; running model directly\n' \
    "$GLOBAL_RANK"
  "$BINDIR/regcmMPICLM45" "$INPUT_FILE"
fi
