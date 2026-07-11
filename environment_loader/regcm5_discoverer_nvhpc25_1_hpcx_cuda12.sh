#!/usr/bin/env bash
#
# RegCM5 Discoverer+ environment candidate for:
#   ./configure --enable-clm45 --enable-openacc-stdpar
#
# Discoverer offline docs used as primary reference:
#   pages_md/nvidia_hpc_sdk.md
#   pages_md/mpi.md
#   pages_md/hdf5.md
#   pages_md/netcdf.md
#   pages_md/pnetcdf.md
#   pages_md/where_to_compile.md
#
# Current Discoverer+ module reality checked on login-plus:
#   nvidia/hpcsdk/nvhpc-hpcx-cuda12/25.1 provides NVHPC 25.1 + HPC-X/OpenMPI
#   public HDF5/NetCDF modules pull LLVM/GCC OpenMPI, not NVHPC/HPC-X
#   no public pnetcdf module was visible via module avail pnetcdf
#
# Usage:
#   source /valhalla/projects/ehpc-ben-2026b06-085/tchristian/work/RegCM/environment_loader/regcm5_discoverer_nvhpc25_1_hpcx_cuda12.sh
#
# Optional private dependency prefixes, expected to be built with this same
# NVHPC/HPC-X stack:
#   export REGCM_DISCOVERER_HDF5=/path/to/hdf5
#   export REGCM_DISCOVERER_NETCDF_C=/path/to/netcdf-c
#   export REGCM_DISCOVERER_NETCDF_FORTRAN=/path/to/netcdf-fortran
#   export REGCM_DISCOVERER_PNETCDF=/path/to/parallel-netcdf
#
# If all private prefixes are available, this loader can support:
#   ./configure --enable-clm45 --enable-openacc-stdpar --enable-pnetcdf
#
# This file must be sourced, not executed, because it modifies the current shell.

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
module purge

# Closest Discoverer+ module to the Levante NVHPC + OpenMPI CUDA stack.
# It provides nvc, nvc++, nvfortran, and HPC-X/OpenMPI wrappers whose
# Fortran wrapper resolves to nvfortran.
module load nvidia/hpcsdk/nvhpc-hpcx-cuda12/25.1

# Clean user-owned OpenMPI shim, patterned after the Leonardo loader. The site
# module exposes the full HPC-X tree, including UCX/UCC/HCOLL/SHARP component
# paths. The Leonardo known-good runtime kept only the OpenMPI prefix in the
# default runtime path and disabled UCC collectives.
_regcm_use_mpi_shim=${REGCM_DISCOVERER_USE_MPI_SHIM:-1}
export MPI_SHIM=${REGCM_DISCOVERER_MPI_SHIM:-/valhalla/projects/ehpc-ben-2026b06-085/tchristian/software/discoverer-hpcx-2.21-ompi-shim}
if [ "$_regcm_use_mpi_shim" = 1 ] && [ -d "$MPI_SHIM/bin" ] && [ -d "$MPI_SHIM/lib" ]; then
  export PATH="$MPI_SHIM/bin:$PATH"
  export LD_LIBRARY_PATH="$MPI_SHIM/lib"
fi

_regcm_disable_ucc=${REGCM_DISCOVERER_DISABLE_UCC:-1}
if [ "$_regcm_disable_ucc" = 1 ]; then
  export OMPI_MCA_coll=^ucc
else
  unset OMPI_MCA_coll
fi

# --------------------------------------------------------------------
# 2. Derive NVHPC, CUDA, and link-time helper paths
# --------------------------------------------------------------------
if command -v nvfortran >/dev/null 2>&1; then
  NVFORTRAN_BIN="$(readlink -f "$(command -v nvfortran)")"
  export NVHPC_ROOT="$(dirname "$(dirname "$(dirname "$NVFORTRAN_BIN")")")"
fi

# The Discoverer module does not currently export CUDA_HOME. Prefer the
# NVHPC-bundled CUDA tree advertised by the module over deriving from nvcc,
# because nvcc may resolve through the compiler wrapper directory.
if [ -z "${CUDA_HOME:-}" ] && [ -n "${NVHPC_ROOT:-}" ]; then
  for _regcm_cuda_dir in "$NVHPC_ROOT/cuda/12.6" "$NVHPC_ROOT/cuda"; do
    if [ -d "$_regcm_cuda_dir" ]; then
      export CUDA_HOME="$_regcm_cuda_dir"
      break
    fi
  done
fi
if [ -z "${CUDA_HOME:-}" ] && command -v nvcc >/dev/null 2>&1; then
  _regcm_nvcc_path="$(readlink -f "$(command -v nvcc)")"
  case "$_regcm_nvcc_path" in
    */cuda/*/bin/nvcc|*/cuda/bin/nvcc)
      export CUDA_HOME="$(dirname "$(dirname "$_regcm_nvcc_path")")"
      ;;
  esac
fi
if [ -n "${CUDA_HOME:-}" ]; then
  export NVHPC_CUDA_HOME="$CUDA_HOME"
fi

_regcm_cuda_stubs_status="not used"
_regcm_cuda_stubs_policy="${REGCM_CUDA_STUBS:-always}"
_regcm_gpu_driver_present=0
if command -v nvidia-smi >/dev/null 2>&1 && nvidia-smi -L >/dev/null 2>&1; then
  _regcm_gpu_driver_present=1
elif [ -r /proc/driver/nvidia/version ]; then
  _regcm_gpu_driver_present=1
fi

if [ -n "${CUDA_HOME:-}" ]; then
  _regcm_use_cuda_stubs=0
  case "$_regcm_cuda_stubs_policy" in
    always) _regcm_use_cuda_stubs=1 ;;
    never) _regcm_use_cuda_stubs=0 ;;
    auto|*)
      if [ "$_regcm_gpu_driver_present" = 0 ]; then
        _regcm_use_cuda_stubs=1
      fi
      ;;
  esac

  # Make stubs available for configure/link checks. Do not add them to
  # LD_LIBRARY_PATH, so runtime resolves libcuda.so from the NVIDIA driver.
  if [ "$_regcm_use_cuda_stubs" = 1 ] && [ -d "$CUDA_HOME/lib64/stubs" ]; then
    export LIBRARY_PATH="$CUDA_HOME/lib64/stubs:${LIBRARY_PATH:-}"
    _regcm_extra_ldflags="-L$CUDA_HOME/lib64/stubs ${_regcm_extra_ldflags:-}"
    _regcm_cuda_stubs_status="using $CUDA_HOME/lib64/stubs"
  elif [ "$_regcm_gpu_driver_present" = 1 ]; then
    _regcm_cuda_stubs_status="skipped, NVIDIA driver visible"
  elif [ "$_regcm_cuda_stubs_policy" = never ]; then
    _regcm_cuda_stubs_status="skipped by REGCM_CUDA_STUBS=never"
  elif [ ! -d "$CUDA_HOME/lib64/stubs" ]; then
    _regcm_cuda_stubs_status="not found"
  fi

  _regcm_cuda_target_lib="$CUDA_HOME/targets/x86_64-linux/lib"
  if [ ! -d "$_regcm_cuda_target_lib" ]; then
    _regcm_cuda_target_lib="$CUDA_HOME/lib64"
  fi
  if [ -d "$_regcm_cuda_target_lib" ]; then
    export LIBRARY_PATH="$_regcm_cuda_target_lib:${LIBRARY_PATH:-}"
    export LD_LIBRARY_PATH="$_regcm_cuda_target_lib:${LD_LIBRARY_PATH:-}"
  fi
fi

if [ -n "${NVHPC_ROOT:-}" ]; then
  for _regcm_nvhpc_compiler_lib in \
    "$NVHPC_ROOT/compilers/lib" \
    "$NVHPC_ROOT/REDIST/compilers/lib"; do
    if [ -d "$_regcm_nvhpc_compiler_lib" ]; then
      export LIBRARY_PATH="$_regcm_nvhpc_compiler_lib:${LIBRARY_PATH:-}"
      export LD_LIBRARY_PATH="$_regcm_nvhpc_compiler_lib:${LD_LIBRARY_PATH:-}"
    fi
  done

  for _regcm_nvhpc_math in \
    "$NVHPC_ROOT/math_libs/lib64" \
    "$NVHPC_ROOT/math_libs/12.6/targets/x86_64-linux/lib" \
    "$NVHPC_ROOT/math_libs/targets/x86_64-linux/lib"; do
    if [ -d "$_regcm_nvhpc_math" ]; then
      export NVHPC_MATH_LIB="$_regcm_nvhpc_math"
      export LIBRARY_PATH="$NVHPC_MATH_LIB:${LIBRARY_PATH:-}"
      export LD_LIBRARY_PATH="$NVHPC_MATH_LIB:${LD_LIBRARY_PATH:-}"
      _regcm_extra_ldflags="-L$NVHPC_MATH_LIB ${_regcm_extra_ldflags:-}"
      break
    fi
  done
fi

# --------------------------------------------------------------------
# 3. Optional private HDF5 / NetCDF / PnetCDF stack
# --------------------------------------------------------------------
# Do not load Discoverer public HDF5/NetCDF modules here. The visible public
# modules pull LLVM/GCC OpenMPI and are not compiler/MPI-aligned with NVHPC/HPC-X.
_regcm_io_stack_status="not configured"

_regcm_add_prefix() {
  _regcm_prefix="$1"
  if [ -n "$_regcm_prefix" ] && [ -d "$_regcm_prefix" ]; then
    [ -d "$_regcm_prefix/bin" ] && export PATH="$_regcm_prefix/bin:$PATH"
    [ -d "$_regcm_prefix/include" ] && export CPATH="$_regcm_prefix/include:${CPATH:-}"
    [ -d "$_regcm_prefix/lib" ] && export LIBRARY_PATH="$_regcm_prefix/lib:${LIBRARY_PATH:-}"
    [ -d "$_regcm_prefix/lib" ] && export LD_LIBRARY_PATH="$_regcm_prefix/lib:${LD_LIBRARY_PATH:-}"
    [ -d "$_regcm_prefix/lib64" ] && export LIBRARY_PATH="$_regcm_prefix/lib64:${LIBRARY_PATH:-}"
    [ -d "$_regcm_prefix/lib64" ] && export LD_LIBRARY_PATH="$_regcm_prefix/lib64:${LD_LIBRARY_PATH:-}"
  fi
}

_regcm_add_prefix "${REGCM_DISCOVERER_HDF5:-}"
_regcm_add_prefix "${REGCM_DISCOVERER_NETCDF_C:-}"
_regcm_add_prefix "${REGCM_DISCOVERER_NETCDF_FORTRAN:-}"
_regcm_add_prefix "${REGCM_DISCOVERER_PNETCDF:-}"

if [ -n "${REGCM_DISCOVERER_HDF5:-}" ]; then
  export HDF5="$REGCM_DISCOVERER_HDF5"
fi
if [ -n "${REGCM_DISCOVERER_NETCDF_C:-}" ]; then
  export NETCDF="$REGCM_DISCOVERER_NETCDF_C"
fi

if command -v h5pcc >/dev/null 2>&1; then
  export HDF5="$(dirname "$(dirname "$(command -v h5pcc)")")"
elif command -v h5cc >/dev/null 2>&1 && [ -z "${HDF5:-}" ]; then
  export HDF5="$(dirname "$(dirname "$(command -v h5cc)")")"
fi

if command -v nc-config >/dev/null 2>&1; then
  _regcm_netcdf_c_prefix="$(nc-config --prefix 2>/dev/null || true)"
  _regcm_netcdf_c_libdir="$(nc-config --libdir 2>/dev/null || true)"
  if [ -n "$_regcm_netcdf_c_prefix" ]; then
    export NETCDF="$_regcm_netcdf_c_prefix"
  fi
  if [ -n "$_regcm_netcdf_c_libdir" ] && [ -d "$_regcm_netcdf_c_libdir" ]; then
    export LIBRARY_PATH="$_regcm_netcdf_c_libdir:${LIBRARY_PATH:-}"
    export LD_LIBRARY_PATH="$_regcm_netcdf_c_libdir:${LD_LIBRARY_PATH:-}"
  fi
fi

if command -v nf-config >/dev/null 2>&1; then
  _regcm_netcdf_f_prefix="$(nf-config --prefix 2>/dev/null || true)"
  if [ -n "$_regcm_netcdf_f_prefix" ] && [ -d "$_regcm_netcdf_f_prefix/lib" ]; then
    export LIBRARY_PATH="$_regcm_netcdf_f_prefix/lib:${LIBRARY_PATH:-}"
    export LD_LIBRARY_PATH="$_regcm_netcdf_f_prefix/lib:${LD_LIBRARY_PATH:-}"
  fi
fi

if command -v pnetcdf-config >/dev/null 2>&1; then
  _regcm_pnetcdf_prefix="$(pnetcdf-config --prefix 2>/dev/null || true)"
  if [ -n "$_regcm_pnetcdf_prefix" ] && [ -d "$_regcm_pnetcdf_prefix/lib" ]; then
    export PNETCDF="$_regcm_pnetcdf_prefix"
    export LIBRARY_PATH="$_regcm_pnetcdf_prefix/lib:${LIBRARY_PATH:-}"
    export LD_LIBRARY_PATH="$_regcm_pnetcdf_prefix/lib:${LD_LIBRARY_PATH:-}"
  fi
fi

if command -v nc-config >/dev/null 2>&1 && command -v nf-config >/dev/null 2>&1; then
  _regcm_io_stack_status="NetCDF C/Fortran detected"
  if command -v pnetcdf-config >/dev/null 2>&1; then
    _regcm_io_stack_status="NetCDF C/Fortran + PnetCDF detected"
  fi
fi

if [ -n "${_regcm_extra_ldflags:-}" ]; then
  export LDFLAGS="$_regcm_extra_ldflags ${LDFLAGS:-}"
fi

# --------------------------------------------------------------------
# 4. Compiler choices for RegCM configure/build
# --------------------------------------------------------------------
export CC=nvc
export CXX=nvc++
export FC=nvfortran
export F77=nvfortran
export MPICC=mpicc
export MPIFC=mpifort

# --------------------------------------------------------------------
# 5. Helpful validation summary
# --------------------------------------------------------------------
echo
echo "Loaded RegCM5 Discoverer+ NVHPC 25.1 + HPC-X candidate environment"
echo
echo "Modules:"
echo "  nvidia/hpcsdk/nvhpc-hpcx-cuda12/25.1"
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
echo -n "  nvc             -> "; command -v nvc 2>/dev/null || true
echo -n "  nvfortran       -> "; command -v nvfortran 2>/dev/null || true
echo -n "  mpicc           -> "; command -v mpicc 2>/dev/null || true
echo -n "  mpifort         -> "; command -v mpifort 2>/dev/null || true
echo -n "  mpirun          -> "; command -v mpirun 2>/dev/null || true
echo -n "  nc-config       -> "; command -v nc-config 2>/dev/null || true
echo -n "  nf-config       -> "; command -v nf-config 2>/dev/null || true
echo -n "  pnetcdf-config  -> "; command -v pnetcdf-config 2>/dev/null || true
echo

echo "Quick checks:"
echo -n "  MPI_SHIM                 -> "; printf '%s\n' "${MPI_SHIM:-unset}"
echo -n "  MPI shim enabled         -> "; printf '%s\n' "${_regcm_use_mpi_shim:-unset}"
echo -n "  Disable UCC collectives  -> "; printf '%s\n' "${_regcm_disable_ucc:-unset}"
echo -n "  OMPI_MCA_coll            -> "; printf '%s\n' "${OMPI_MCA_coll:-unset}"
echo -n "  CUDA_HOME                -> "; printf '%s\n' "${CUDA_HOME:-unset}"
echo -n "  NVHPC_CUDA_HOME          -> "; printf '%s\n' "${NVHPC_CUDA_HOME:-unset}"
echo -n "  CUDA target lib          -> "; printf '%s\n' "${_regcm_cuda_target_lib:-unset}"
echo -n "  CUDA stubs policy        -> "; printf '%s\n' "${_regcm_cuda_stubs_policy:-unset}"
echo -n "  CUDA stubs status        -> "; printf '%s\n' "${_regcm_cuda_stubs_status:-unset}"
echo -n "  NVHPC_ROOT               -> "; printf '%s\n' "${NVHPC_ROOT:-unset}"
echo -n "  NVHPC_MATH_LIB           -> "; printf '%s\n' "${NVHPC_MATH_LIB:-unset}"
echo -n "  HDF5                     -> "; printf '%s\n' "${HDF5:-unset}"
echo -n "  NETCDF                   -> "; printf '%s\n' "${NETCDF:-unset}"
echo -n "  PNETCDF                  -> "; printf '%s\n' "${PNETCDF:-unset}"
echo -n "  I/O stack status         -> "; printf '%s\n' "$_regcm_io_stack_status"
echo -n "  nc-config --version      -> "; nc-config --version 2>/dev/null || true
echo -n "  nf-config --version      -> "; nf-config --version 2>/dev/null || true
echo -n "  pnetcdf-config --version -> "; pnetcdf-config --version 2>/dev/null || true
echo -n "  mpirun --version         -> "; mpirun --version 2>/dev/null | awk 'NR == 1 {print; exit}' || true
echo -n "  mpifort --show           -> "; mpifort --show 2>/dev/null || true
echo

_regcm_loader_failed=0
for _regcm_tool in nvc nvfortran mpicc mpifort; do
  if ! command -v "$_regcm_tool" >/dev/null 2>&1; then
    echo "ERROR: required compiler/MPI tool not found after loading environment: $_regcm_tool" >&2
    _regcm_loader_failed=1
  fi
done

if [ "${REGCM_REQUIRE_IO_STACK:-0}" = 1 ]; then
  for _regcm_tool in nc-config nf-config pnetcdf-config; do
    if ! command -v "$_regcm_tool" >/dev/null 2>&1; then
      echo "ERROR: REGCM_REQUIRE_IO_STACK=1 but missing tool: $_regcm_tool" >&2
      _regcm_loader_failed=1
    fi
  done
fi

if [ "${_regcm_restore_nounset:-0}" = 1 ]; then
  set -u
fi
if [ "${_regcm_restore_errexit:-0}" = 1 ]; then
  set -e
fi
if [ "${_regcm_loader_failed:-0}" = 1 ]; then
  unset _regcm_loader_failed _regcm_tool _regcm_prefix _regcm_use_mpi_shim _regcm_disable_ucc _regcm_cuda_stubs_policy _regcm_cuda_stubs_status _regcm_gpu_driver_present _regcm_use_cuda_stubs _regcm_cuda_target_lib _regcm_extra_ldflags _regcm_nvhpc_compiler_lib _regcm_nvhpc_math _regcm_io_stack_status _regcm_netcdf_c_prefix _regcm_netcdf_c_libdir _regcm_netcdf_f_prefix _regcm_pnetcdf_prefix _regcm_restore_errexit _regcm_restore_nounset
  unset -f _regcm_add_prefix
  return 1 2>/dev/null || exit 1
fi
unset _regcm_loader_failed _regcm_tool _regcm_prefix _regcm_use_mpi_shim _regcm_disable_ucc _regcm_cuda_stubs_policy _regcm_cuda_stubs_status _regcm_gpu_driver_present _regcm_use_cuda_stubs _regcm_cuda_target_lib _regcm_extra_ldflags _regcm_nvhpc_compiler_lib _regcm_nvhpc_math _regcm_io_stack_status _regcm_netcdf_c_prefix _regcm_netcdf_c_libdir _regcm_netcdf_f_prefix _regcm_pnetcdf_prefix _regcm_restore_errexit
unset _regcm_restore_nounset
unset -f _regcm_add_prefix
