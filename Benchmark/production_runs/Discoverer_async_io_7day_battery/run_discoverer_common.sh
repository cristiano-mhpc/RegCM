#!/bin/bash

set -euo pipefail

RUN_DIR=$PWD
REGCM_ROOT=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM
REGCM_STACK=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/software/regcm5-discoverer-nvhpc25.1-hpcx
DATA_ROOT=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3
RUN_ROOT=$REGCM_ROOT/Benchmark/production_runs/Discoverer_async_io_7day_battery

export REGCM_DISCOVERER_HDF5="$REGCM_STACK"
export REGCM_DISCOVERER_NETCDF_C="$REGCM_STACK"
export REGCM_DISCOVERER_NETCDF_FORTRAN="$REGCM_STACK"
export REGCM_REQUIRE_IO_STACK=1
source "$REGCM_ROOT/environment_loader/regcm5_discoverer_nvhpc25_1_hpcx_cuda12.sh"

export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}
export OMP_PROC_BIND=true
export OMP_PLACES=cores
export REGCM_EXE=$REGCM_ROOT/bin/async_io_mem_managed/regcmMPICLM45
export RCM_ASYNC_OUTPUT_GB=${RCM_ASYNC_OUTPUT_GB:?RCM_ASYNC_OUTPUT_GB must be set}
export RCM_BDYIN_PREFETCH_STEPS=${RCM_BDYIN_PREFETCH_STEPS:?RCM_BDYIN_PREFETCH_STEPS must be set}

echo "=== Job info ==="
echo "SLURM_JOB_ID=$SLURM_JOB_ID"
echo "SLURM_JOB_NODELIST=$SLURM_JOB_NODELIST"
echo "SLURM_NNODES=$SLURM_NNODES"
echo "SLURM_NTASKS=$SLURM_NTASKS"
echo "SLURM_NTASKS_PER_NODE=${SLURM_NTASKS_PER_NODE:-}"
echo "SLURM_CPUS_PER_TASK=${SLURM_CPUS_PER_TASK:-}"
echo "RUN_DIR=$RUN_DIR"
echo

echo "=== Async I/O configuration ==="
echo "REGCM_EXE=$REGCM_EXE"
echo "RCM_ASYNC_OUTPUT_GB=$RCM_ASYNC_OUTPUT_GB"
echo "RCM_BDYIN_PREFETCH_STEPS=$RCM_BDYIN_PREFETCH_STEPS"
echo "OMP_NUM_THREADS=$OMP_NUM_THREADS"
echo

echo "=== Toolchain ==="
command -v nvfortran
command -v nvcc
command -v mpifort
command -v ld
nvcc --version
echo "CUDA_HOME=${CUDA_HOME:-}"
echo "NVHPC_CUDA_HOME=${NVHPC_CUDA_HOME:-}"
echo "MPI_SHIM=${MPI_SHIM:-}"
echo "OMPI_MCA_coll=${OMPI_MCA_coll:-}"
echo

echo "=== Validation ==="
test -x "$REGCM_EXE"
test -d input
test -d output
test -d "$DATA_ROOT/RCMDATA"
test -f input/EURR-3_DOMAIN000.nc
test -f EURR-3_namelist.in
echo "Executable, input/output symlinks, namelist, and RCMDATA are present."
echo

echo "=== GPU layout ==="
nvidia-smi -L
echo

echo "=== Launching RegCM ==="
srun --mpi=pmix "$RUN_ROOT/STD_launch_per_rank.sh"
