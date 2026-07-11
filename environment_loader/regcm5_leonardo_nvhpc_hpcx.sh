#!/usr/bin/env bash
#
# RegCM5 Leonardo environment:
#   NVHPC 25.11
#   CUDA 12.2 , previously CUDA 12.6 but the drivers on compute node 535.274.02 supports CUDA 12.2 
#   Spack-built HDF5 / PnetCDF / NetCDF-C / NetCDF-Fortran
#   External NVHPC-bundled HPC-X/OpenMPI via a clean WORK shim prefix
#
# Usage:
#   source /leonardo_work/ICT26_ESP_0/christian/env/regcm5_leonardo_nvhpc_hpcx.sh
#
# Important:
#   This file must be sourced, not executed, because it modifies the current shell.
#
#   Correct:
#     source /leonardo_work/ICT26_ESP_0/christian/env/regcm5_leonardo_nvhpc_hpcx.sh
#
#   Wrong:
#     ./regcm5_leonardo_nvhpc_hpcx.sh

# Leonardo's module/Spack setup scripts reference some optional variables while
# they are still unset. Keep this loader sourceable from strict job scripts.
_regcm_restore_errexit=0
_regcm_restore_nounset=0
case $- in
  *e*) _regcm_restore_errexit=1; set +e ;;
esac
case $- in
  *u*) _regcm_restore_nounset=1; set +u ;;
esac

# --------------------------------------------------------------------
# 1. Start from a clean module environment
# --------------------------------------------------------------------
# This avoids accidentally mixing system OpenMPI, GCC, Intel, or older CUDA
# modules with the NVHPC/HPC-X stack.
module purge

# Spack module used on Leonardo for this environment.
module load spack/0.22-06

# Use a newer GNU linker. The system /usr/bin/ld is too old for some
# Spack-built libraries and can fail on compressed debug sections.
module load binutils/2.42

# NVIDIA compiler suite.
# Provides nvc, nvc++, nvfortran, and the bundled HPC-X/OpenMPI tree.
module load nvhpc/25.11

# CUDA module used together with NVHPC 25.11 on Leonardo.
module load cuda/12.2

# Force NVHPC to use the system CUDA toolkit compatible with the node driver.
# Leonardo A100 compute nodes currently report driver CUDA compatibility 12.2.
# Without this, NVHPC 25.11 may use its bundled CUDA 13.x toolkit, producing
# binaries that fail at runtime with CUDA_ERROR_INVALID_IMAGE.
if [ -n "${CUDA_HOME:-}" ]; then
  export NVHPC_CUDA_HOME="$CUDA_HOME"
else
  export NVHPC_CUDA_HOME="$(dirname "$(dirname "$(which nvcc)")")"
fi

NVFORTRAN_BIN="$(readlink -f "$(which nvfortran)")"
export NVHPC_ROOT="$(dirname "$(dirname "$(dirname "$NVFORTRAN_BIN")")")"

# NVHPC 25.11's -cudalib=nvtx,cusparse needs libnvtx3interop from the
# NVHPC-bundled CUDA tree, even while forcing code generation against CUDA 12.2.
export NVHPC_CUDA_TARGET_LIB="$NVHPC_ROOT/cuda/12.9/targets/x86_64-linux/lib"

# Link-time paths. Keep CUDA stubs out of LD_LIBRARY_PATH so runtime uses the
# real driver library, but make them available for configure/link tests.
export LIBRARY_PATH="$CUDA_HOME/lib64:$CUDA_HOME/lib64/stubs:$NVHPC_CUDA_TARGET_LIB:$NVHPC_ROOT/compilers/lib:$NVHPC_ROOT/REDIST/compilers/lib:$NVHPC_ROOT/math_libs/lib64:${LIBRARY_PATH:-}"

if [ -d "$NVHPC_CUDA_TARGET_LIB" ]; then
  export LD_LIBRARY_PATH="$NVHPC_CUDA_TARGET_LIB:${LD_LIBRARY_PATH:-}"
fi

echo "CUDA_HOME=$CUDA_HOME"
echo "NVHPC_CUDA_HOME=$NVHPC_CUDA_HOME"
echo "NVHPC_ROOT=$NVHPC_ROOT"
nvcc --version


# --------------------------------------------------------------------
# 2. Remove broken/irrelevant upstream Spack variables
# --------------------------------------------------------------------
# On Leonardo, the site Spack setup may leave upstream-related variables
# pointing to paths that are not valid in this user environment.
#
# If these are not unset, Spack may print warnings such as:
#   upstream not found ...
#   Failed to initialize repository: '$SPACK_REPO_DIR_01'
#
# These warnings were not fatal, but they are noisy and confusing.
unset SPACK_REPO_DIR_01
unset SPACK_UPSTREAM_INSTALL_DIR_01
unset SPACK_UPSTREAM_MODULE_DIR
unset SPACK_UPSTREAM_USER_CACHE_PATH
unset SPACK_UPSTREAM_MODULES_DIR
unset SPACK_UPSTREAM_CACHE_DIR


# --------------------------------------------------------------------
# 3. Define the working Spack environment and MPI shim
# --------------------------------------------------------------------
# This is the successful Spack environment where HDF5, PnetCDF,
# NetCDF-C, and NetCDF-Fortran were built with NVHPC 25.11.
export REGCM_SPACK_ENV=/leonardo_work/ICT26_ESP_0/christian/spack-envs/regcm5-leonardo-nvhpc-hpcx

# This is the clean user-owned prefix that makes HPC-X/OpenMPI look like
# a normal MPI installation to Spack and configure/CMake-based packages.
#
# It contains symlinks:
#   bin     -> real HPC-X/OpenMPI bin
#   include -> real HPC-X/OpenMPI include
#   lib     -> real HPC-X/OpenMPI lib
#   share   -> real HPC-X/OpenMPI share
#
# This shim was necessary because pointing Spack directly to the deep
# NVHPC-bundled HPC-X/OpenMPI prefix concretized, but failed during
# HDF5/PnetCDF MPI detection.
export MPI_SHIM=/leonardo_work/ICT26_ESP_0/christian/externals/hpcx-mpi-2.25.1-ompi-shim


# --------------------------------------------------------------------
# 4. Activate the Spack environment
# --------------------------------------------------------------------
# This makes Spack commands operate inside the selected environment.
# The environment contains:
#   hdf5@1.14.3
#   parallel-netcdf@1.12.3
#   netcdf-c@4.9.2
#   netcdf-fortran@4.6.1
# all built with %nvhpc@25.11 and external hpcx-mpi@2.25.1.
spack env activate "$REGCM_SPACK_ENV"


# --------------------------------------------------------------------
# 5. Load the installed dependency packages
# --------------------------------------------------------------------
# These commands place nc-config, nf-config, pnetcdf-config, headers,
# libraries, and dependency paths into the active shell environment.
#
# For RegCM configure, the most important tools are:
#   nc-config
#   nf-config
#   pnetcdf-config
spack load hdf5
spack load parallel-netcdf
spack load netcdf-c
spack load netcdf-fortran

# --------------------------------------------------------------------
# 6. Put the HPC-X/OpenMPI shim and matching HPC-X component libs first
# --------------------------------------------------------------------
# This ensures that:
#   which mpicc
#   which mpifort
#   which mpirun
# resolve to the HPC-X/OpenMPI wrappers from the shim,
# AND that OpenMPI loads the matching HPC-X UCX/UCC/HCOLL libraries,
# not incompatible system libraries from /lib64.
#
# The shim only exposes the OpenMPI prefix. The real HPC-X tree also has
# sibling component libraries in:
#   ucx/lib
#   ucc/lib
#   hcoll/lib
#
# Without these paths, OpenMPI may load /lib64/libucp.so.0 or fail to load
# libucc.so.1, causing warnings and potentially severe MPI slowdown.

export PATH="$MPI_SHIM/bin:$PATH"
export LD_LIBRARY_PATH="$MPI_SHIM/lib:${LD_LIBRARY_PATH:-}"

# Keep the runtime path minimal.  Adding the sibling HPC-X UCX/UCC/HCOLL
# libraries removes some warnings, but on this case it reintroduces the CLM
# coordinate abort during startup.  The shim lib path alone is the known-good
# runtime configuration for this NVHPC 25.11 build.
#
# If testing HPC-X UCX again, do it explicitly and keep it out of the default
# path until a full RegCM run completes correctly.  The previous direct UCX
# test reported a GDRCopy mismatch, so exclude gdr_copy for the first retry:
#   export LD_LIBRARY_PATH="$HPCX_ROOT/ucx/lib:$HPCX_ROOT/ucx/lib/ucx:${LD_LIBRARY_PATH:-}"
#   export UCX_TLS="^gdr_copy"

# Do not use UCC collectives for this run.  Without this, OpenMPI probes the UCC
# component and warns if libucc.so.1 is not in the runtime path.
export OMPI_MCA_coll=^ucc


# --------------------------------------------------------------------
# 7. Compiler choices for RegCM configure/build
# --------------------------------------------------------------------
# Plain compilers:
#   CC/CXX/FC/F77 are the actual NVIDIA compilers.
#
# MPI wrappers:
#   MPICC/MPIFC point to the MPI wrapper compilers.
#
# The wrappers should internally use NVHPC:
#   mpicc   --show  should use nvc
#   mpifort --show  should use nvfortran
export CC=nvc
export CXX=nvc++
export FC=nvfortran
export F77=nvfortran
export MPICC=mpicc
export MPIFC=mpifort


# --------------------------------------------------------------------
# 8. Helpful validation summary
# --------------------------------------------------------------------
# These messages make it easy to confirm that the environment loaded
# correctly. They do not stop the script if one command is missing.
echo
echo "Loaded RegCM5 Leonardo NVHPC + HPC-X Spack environment"
echo "REGCM_SPACK_ENV = $REGCM_SPACK_ENV"
echo "MPI_SHIM        = $MPI_SHIM"
echo

echo "Compiler/MPI wrappers:"
echo "  CC     = $CC"
echo "  CXX    = $CXX"
echo "  FC     = $FC"
echo "  F77    = $F77"
echo "  MPICC  = $MPICC"
echo "  MPIFC  = $MPIFC"
echo

echo "Resolved tools:"
echo -n "  nvc             -> "; which nvc 2>/dev/null || true
echo -n "  nvfortran       -> "; which nvfortran 2>/dev/null || true
echo -n "  mpicc           -> "; which mpicc 2>/dev/null || true
echo -n "  mpifort         -> "; which mpifort 2>/dev/null || true
echo -n "  mpirun          -> "; which mpirun 2>/dev/null || true
echo -n "  nc-config       -> "; which nc-config 2>/dev/null || true
echo -n "  nf-config       -> "; which nf-config 2>/dev/null || true
echo -n "  pnetcdf-config  -> "; which pnetcdf-config 2>/dev/null || true
echo

echo "Quick checks:"
echo -n "  nc-config --prefix       -> "; nc-config --prefix 2>/dev/null || true
echo -n "  nf-config --prefix       -> "; nf-config --prefix 2>/dev/null || true
echo -n "  pnetcdf-config --prefix  -> "; pnetcdf-config --prefix 2>/dev/null || true
echo -n "  mpirun --version         -> "; mpirun --version 2>/dev/null | head -n 1 || true
echo

_regcm_loader_failed=0
for _regcm_tool in nvc nvfortran mpicc mpifort nc-config nf-config pnetcdf-config; do
  if ! command -v "$_regcm_tool" >/dev/null 2>&1; then
    echo "ERROR: required tool not found after loading environment: $_regcm_tool" >&2
    _regcm_loader_failed=1
  fi
done

if [ "${_regcm_restore_nounset:-0}" = 1 ]; then
  set -u
fi
if [ "${_regcm_restore_errexit:-0}" = 1 ]; then
  set -e
fi
if [ "${_regcm_loader_failed:-0}" = 1 ]; then
  unset _regcm_loader_failed _regcm_tool _regcm_restore_errexit _regcm_restore_nounset
  return 1 2>/dev/null || exit 1
fi
unset _regcm_loader_failed _regcm_tool _regcm_restore_errexit
unset _regcm_restore_nounset
