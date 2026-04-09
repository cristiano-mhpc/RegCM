#!/bin/bash
# launch_per_rank.sh

# Get the rank of the current MPI process
LOCAL_RANK=$OMPI_COMM_WORLD_LOCAL_RANK
GLOBAL_RANK=$OMPI_COMM_WORLD_RANK

# Optional safety check
if [ -z "$LOCAL_RANK" ]; then
  echo "OMPI_COMM_WORLD_LOCAL_RANK not set; this script should be run under srun."
  exit 1
fi

# Benchmark mode: keep GPU launches asynchronous (no debug serialization)
unset CUDA_LAUNCH_BLOCKING

# Assign each local rank to a unique GPU on this node
export CUDA_VISIBLE_DEVICES=$LOCAL_RANK
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=0

export BINDIR=/home/ictp/ictp549985/RegCM/bin

printf '[Wrapper][Rank %02d][Local %02d] on %s: CUDA_VISIBLE_DEVICES=%s ACC_DEVICE_NUM=%s\n' \
"$GLOBAL_RANK" "$LOCAL_RANK" "$(hostname)" "$CUDA_VISIBLE_DEVICES" "$ACC_DEVICE_NUM"

# Launch with NSight profiling

$NSYS_BIN profile \
  --force-overwrite true \
  --stats=true \
  --sample=process-tree \
  --backtrace=dwarf \
  --output "$NSYS_OUT" \
  --sampling-period=1000000 \
  --trace=nvtx,mpi,cuda,osrt \
  --mpi-impl=openmpi \
  --cuda-um-cpu-page-faults=true \
  --cuda-um-gpu-page-faults=true \
  --cuda-memory-usage=true \
  "$BINDIR/regcmMPICLM45_OPENACC_STDPAR" "$INPUT_FILE"


