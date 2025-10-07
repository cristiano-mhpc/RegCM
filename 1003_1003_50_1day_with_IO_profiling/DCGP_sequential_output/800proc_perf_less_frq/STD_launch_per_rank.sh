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
export BINDIR=/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin 
INPUT_FILE=EURR-3_namelist.in

echo "[Wrapper][Rank $SLURM_PROCID][Local $SLURM_LOCALID] on $(hostname): CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"

# For Perf
FREQ="${PERF_FREQ:-200}"  # samples/seconds 

# output directory per job 
OUTDIR="${PERF_OUTDIR:-$SCRATCH/perf/with_IO/DCGP/800proc/perf_${SLURM_JOB_ID}}" 
mkdir -p "$OUTDIR" 
umask 007   # files created with 600 permissions    

# Unique filename per rank & node  
OUTFILE="${OUTDIR}/perf.data.rank${SLURM_PROCID}" 

 # common perf args  
common_args=(   
       -F "$FREQ"
       --output="$OUTFILE"
       --call-graph dwarf 
       -e cycles:u,instructions:u
)

# Launch the binary
exec perf record "${common_args[@]}" -- $BINDIR/regcmMPICLM45 "$INPUT_FILE"  

