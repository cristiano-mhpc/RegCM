#!/bin/bash
# launch_per_rank.sh

# Get the rank of the current MPI process
LOCAL_RANK=$OMPI_COMM_WORLD_LOCAL_RANK
GLOBAL_RANK=$OMPI_COMM_WORLD_RANK


# Optional safety check
if [ -z "$LOCAL_RANK" ]; then
  echo "OMPI_COMM_WORLD_LOCAL_RANK not set; this script should be run under mpirun."
  exit 1
fi

export CUDA_LAUNCH_BLOCKING=1     # pin runtime error to the exact line

# Assign each local rank to a unique GPU on this node
export CUDA_VISIBLE_DEVICES=$LOCAL_RANK
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=0

export BINDIR=/u/external/ctica/MS_thesis/RegCM/bin

printf '[Wrapper][Rank %02d][Local %02d] on %s: CUDA_VISIBLE_DEVICES=%s ACC_DEVICE_NUM=%s\n' \
"$GLOBAL_RANK" "$LOCAL_RANK" "$(hostname)" "$CUDA_VISIBLE_DEVICES" "$ACC_DEVICE_NUM"

# Launch the binary
exec $BINDIR/regcmMPICLM45 EURR-3_namelist.in 
