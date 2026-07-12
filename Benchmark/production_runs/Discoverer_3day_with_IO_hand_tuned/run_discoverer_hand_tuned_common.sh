#!/bin/bash

set -euo pipefail

RUN_DIR=$PWD
REGCM_ROOT=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM
REGCM_STACK=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/software/regcm5-discoverer-nvhpc25.1-hpcx
DATA_ROOT=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/scratch/EURR3
RUN_ROOT=$REGCM_ROOT/Benchmark/production_runs/Discoverer_3day_with_IO_hand_tuned

export REGCM_DISCOVERER_HDF5="$REGCM_STACK"
export REGCM_DISCOVERER_NETCDF_C="$REGCM_STACK"
export REGCM_DISCOVERER_NETCDF_FORTRAN="$REGCM_STACK"
export REGCM_REQUIRE_IO_STACK=1
source "$REGCM_ROOT/environment_loader/regcm5_discoverer_nvhpc25_1_hpcx_cuda12.sh"

export OMP_NUM_THREADS=${SLURM_CPUS_PER_TASK:-1}
export OMP_PROC_BIND=true
export OMP_PLACES=cores
export REGCM_EXE=${REGCM_EXE:-$REGCM_ROOT/bin/regcmMPICLM45}

echo "=== Job info ==="
echo "SLURM_JOB_ID=$SLURM_JOB_ID"
echo "SLURM_JOB_NODELIST=$SLURM_JOB_NODELIST"
echo "SLURM_NNODES=$SLURM_NNODES"
echo "SLURM_NTASKS=$SLURM_NTASKS"
echo "SLURM_NTASKS_PER_NODE=${SLURM_NTASKS_PER_NODE:-}"
echo "SLURM_CPUS_PER_TASK=${SLURM_CPUS_PER_TASK:-}"
echo "RUN_DIR=$RUN_DIR"
echo

echo "=== Hand-tuned controls ==="
echo "REGCM_ENABLE_CPU_BINDING=${REGCM_ENABLE_CPU_BINDING:-1}"
echo "REGCM_ENABLE_NIC_PINNING=${REGCM_ENABLE_NIC_PINNING:-auto}"
echo "REGCM_ENABLE_UCX_TUNING=${REGCM_ENABLE_UCX_TUNING:-0}"
echo "REGCM_ENABLE_ACC_POOL=${REGCM_ENABLE_ACC_POOL:-0}"
echo

echo "=== Toolchain ==="
command -v nvfortran
command -v nvcc
command -v mpifort
command -v ld
nvcc --version
ld --version
echo "CUDA_HOME=${CUDA_HOME:-}"
echo "NVHPC_CUDA_HOME=${NVHPC_CUDA_HOME:-}"
echo "MPI_SHIM=${MPI_SHIM:-}"
echo "OMPI_MCA_coll=${OMPI_MCA_coll:-}"
echo

echo "=== Binary dependency check ==="
ldd "$REGCM_EXE" | grep -E 'cuda|cudart|cudafor|nvhpc|netcdf|hdf5|mpi|nvomp' || true
echo

echo "=== Data check ==="
test -d input
test -d output
test -d "$DATA_ROOT/RCMDATA"
test -f input/EURR-3_DOMAIN000.nc
test -f EURR-3_namelist.in
echo "input/output symlinks, local namelist, and $DATA_ROOT/RCMDATA are present."
echo

echo "=== GPU layout ==="
nvidia-smi -L
echo

echo "=== Launching RegCM with topology-aware wrapper ==="
srun --mpi=pmix --cpu-bind=none "$RUN_ROOT/STD_launch_topology_aware.sh"
