#!/bin/bash
#SBATCH --partition=common
#SBATCH --job-name=build-regcm5-mu
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

REGCM_ROOT=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM
BUILD_ROOT=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM_mem_unified_build
INSTALL_PREFIX=$BUILD_ROOT/install
MEM_UNIFIED_BIN_DIR=$REGCM_ROOT/bin/mem_unified
MEM_UNIFIED_EXE=$MEM_UNIFIED_BIN_DIR/regcmMPICLM45

cd "$BUILD_ROOT"

# Discoverer docs say compilation should run on compute nodes. This wrapper
# builds RegCM with NVHPC/HPC-X and the private NetCDF/HDF5 stack built for
# that MPI. This mem:unified build uses an isolated build/install tree and
# copies only regcmMPICLM45 into $REGCM_ROOT/bin/mem_unified.
module purge

REGCM_STACK=/valhalla/projects/ehpc-ben-2026b06-085/tchristian/software/regcm5-discoverer-nvhpc25.1-hpcx
export REGCM_DISCOVERER_HDF5="$REGCM_STACK"
export REGCM_DISCOVERER_NETCDF_C="$REGCM_STACK"
export REGCM_DISCOVERER_NETCDF_FORTRAN="$REGCM_STACK"
export REGCM_DISCOVERER_PNETCDF="$REGCM_STACK"
export REGCM_REQUIRE_IO_STACK=1
source "$REGCM_ROOT/environment_loader/regcm5_discoverer_nvhpc25_1_hpcx_cuda12.sh"

export MAKE_JOBS="${SLURM_CPUS_PER_TASK:-8}"

if ! grep -q 'mem:unified' configure configure.ac; then
  echo "ERROR: $BUILD_ROOT configure sources do not contain mem:unified." >&2
  echo "Refusing to build because this would not create the requested binary." >&2
  exit 1
fi

mkdir -p "$MEM_UNIFIED_BIN_DIR"

make distclean 2>/dev/null || true

./configure \
  --prefix="$INSTALL_PREFIX" \
  --enable-clm45 \
  --enable-openacc-stdpar

make -j "$MAKE_JOBS"
make install

test -x "$INSTALL_PREFIX/bin/regcmMPICLM45"
install -m 755 "$INSTALL_PREFIX/bin/regcmMPICLM45" "$MEM_UNIFIED_EXE"

echo "Installed mem:unified RegCM executable: $MEM_UNIFIED_EXE"
ldd "$MEM_UNIFIED_EXE" | grep -E 'cuda|cudart|cudafor|nvhpc|netcdf|hdf5|mpi|nvomp' || true
