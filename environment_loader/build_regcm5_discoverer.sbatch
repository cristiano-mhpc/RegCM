#!/bin/bash
#SBATCH --partition=common
#SBATCH --job-name=build-regcm5
#SBATCH --time=02:00:00
#SBATCH --account=ehpc-ben-2026b06-085
#SBATCH --qos=ehpc-ben-2026b06-085
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=8
#SBATCH --mem=32G
#SBATCH --gres=gpu:1
#SBATCH --output=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/logs/%x-%j.out
#SBATCH --error=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/logs/%x-%j.err

set -euo pipefail

cd /valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM

# Discoverer docs say compilation should run on compute nodes. This wrapper
# builds RegCM with NVHPC/HPC-X and the private NetCDF/HDF5 stack built for
# that MPI. Installed RegCM binaries go under ./bin via --prefix="$PWD".
module purge

REGCM_STACK=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/software/regcm5-discoverer-nvhpc25.1-hpcx
export REGCM_DISCOVERER_HDF5="$REGCM_STACK"
export REGCM_DISCOVERER_NETCDF_C="$REGCM_STACK"
export REGCM_DISCOVERER_NETCDF_FORTRAN="$REGCM_STACK"
export REGCM_REQUIRE_IO_STACK=1
source ./environment_loader/regcm5_discoverer_nvhpc25_1_hpcx_cuda12.sh

export MAKE_JOBS="${SLURM_CPUS_PER_TASK:-8}"

make distclean 2>/dev/null || true

./configure \
  --prefix="$PWD" \
  --enable-clm45 \
  --enable-openacc-stdpar

make -j "$MAKE_JOBS"
make install
