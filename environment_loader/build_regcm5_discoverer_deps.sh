#!/usr/bin/env bash
#
# Build a private RegCM5 dependency stack on Discoverer+ with:
#   nvidia/hpcsdk/nvhpc-hpcx-cuda12/25.1
#
# Offline Discoverer docs used as the policy reference:
#   pages_md/where_to_compile.md says compilation should run on compute nodes,
#   not on login-plus.discoverer.bg.
#
# This script is intended to be run inside a Slurm allocation or batch job.

set -euo pipefail

ROOT="/valhalla/projects/ehpc-ben-2026b06-085/tchristian"
REGCM_ROOT="${REGCM_ROOT:-$ROOT/work/RegCM}"
PREFIX="${REGCM_DISCOVERER_STACK_PREFIX:-$ROOT/software/regcm5-discoverer-nvhpc25.1-hpcx}"
SRC_DIR="${REGCM_DISCOVERER_SRC_DIR:-$ROOT/software/src/regcm5-discoverer-nvhpc25.1-hpcx}"
BUILD_DIR="${REGCM_DISCOVERER_BUILD_DIR:-$ROOT/tmp/build-regcm5-discoverer-nvhpc25.1-hpcx}"
MAKE_JOBS="${MAKE_JOBS:-${SLURM_CPUS_PER_TASK:-8}}"

ZLIB_VERSION="${ZLIB_VERSION:-1.3.1}"
LIBAEC_VERSION="${LIBAEC_VERSION:-1.1.3}"
HDF5_VERSION="${HDF5_VERSION:-1.14.6}"
PNETCDF_VERSION="${PNETCDF_VERSION:-1.14.0}"
NETCDF_C_VERSION="${NETCDF_C_VERSION:-4.9.3}"
NETCDF_FORTRAN_VERSION="${NETCDF_FORTRAN_VERSION:-4.6.2}"

LOADER="$REGCM_ROOT/environment_loader/regcm5_discoverer_nvhpc25_1_hpcx_cuda12.sh"

if [ ! -f "$LOADER" ]; then
  echo "ERROR: missing Discoverer environment loader: $LOADER" >&2
  exit 1
fi

# Load compiler/MPI/CUDA side only. The private I/O stack is what this script builds.
source "$LOADER"

# The loader may discover system HDF5 helpers such as /usr/bin/h5cc. Do not let
# those paths influence this private dependency build.
unset HDF5 NETCDF PNETCDF

mkdir -p "$PREFIX" "$SRC_DIR" "$BUILD_DIR"

export PATH="$PREFIX/bin:$PATH"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig:${PKG_CONFIG_PATH:-}"
export CFLAGS="-O2 -fPIC ${CFLAGS:-}"
export CXXFLAGS="-O2 -fPIC ${CXXFLAGS:-}"
export FCFLAGS="-O2 -fPIC ${FCFLAGS:-}"
export FFLAGS="-O2 -fPIC ${FFLAGS:-}"

# HPC-X/OpenMPI libraries on Discoverer+ require zlib symbols versioned as
# ZLIB_*. zlib built with nvc does not provide those versions, so use the
# system zlib for this MPI-linked stack and remove stale private zlib artifacts
# from earlier attempts.
SYSTEM_ZLIB="/usr/lib64/libz.so"
PREFIX_CPPFLAGS="-I$PREFIX/include"
PREFIX_LDFLAGS="-L$PREFIX/lib -L$PREFIX/lib64 -Wl,-rpath,$PREFIX/lib -Wl,-rpath,$PREFIX/lib64"

remove_private_zlib() {
  rm -f \
    "$PREFIX/include/zconf.h" \
    "$PREFIX/include/zlib.h" \
    "$PREFIX/lib/libz.a" \
    "$PREFIX/lib/libz.so" \
    "$PREFIX/lib/libz.so.1" \
    "$PREFIX/lib/libz.so.$ZLIB_VERSION" \
    "$PREFIX/lib/pkgconfig/zlib.pc" \
    "$PREFIX/share/man/man3/zlib.3"
}

remove_libtool_archives() {
  # HPC-X ships libtool archives that record unusable absolute dependencies
  # such as /libmpi_usempif08.la. Do not let downstream packages consume .la
  # metadata from this private stack; shared libraries and *-config scripts are
  # sufficient for RegCM and avoid those stale dependency paths.
  rm -f "$PREFIX"/lib/*.la "$PREFIX"/lib64/*.la
}

download() {
  _url="$1"
  _out="$2"
  if [ -f "$_out" ]; then
    return 0
  fi
  if [ "${REGCM_OFFLINE_BUILD:-0}" = 1 ]; then
    echo "ERROR: missing source tarball in offline build mode: $_out" >&2
    echo "       Stage sources first with REGCM_DOWNLOAD_ONLY=1." >&2
    exit 1
  fi
  echo "Downloading $_url"
  if command -v curl >/dev/null 2>&1; then
    curl -L --fail --retry 3 -o "$_out" "$_url"
  elif command -v wget >/dev/null 2>&1; then
    wget -O "$_out" "$_url"
  else
    echo "ERROR: neither curl nor wget is available" >&2
    exit 1
  fi
}

stage_sources() {
  download "https://zlib.net/fossils/zlib-$ZLIB_VERSION.tar.gz" "$SRC_DIR/zlib-$ZLIB_VERSION.tar.gz"
  download "https://gitlab.dkrz.de/k202009/libaec/-/archive/v$LIBAEC_VERSION/libaec-v$LIBAEC_VERSION.tar.gz" "$SRC_DIR/libaec-$LIBAEC_VERSION.tar.gz"
  _regcm_hdf5_release="v$(printf '%s' "$HDF5_VERSION" | tr . _)"
  download "https://support.hdfgroup.org/releases/hdf5/v1_14/$_regcm_hdf5_release/downloads/hdf5-$HDF5_VERSION.tar.gz" "$SRC_DIR/hdf5-$HDF5_VERSION.tar.gz"
  download "https://parallel-netcdf.github.io/Release/pnetcdf-$PNETCDF_VERSION.tar.gz" "$SRC_DIR/pnetcdf-$PNETCDF_VERSION.tar.gz"
  download "https://downloads.unidata.ucar.edu/netcdf-c/$NETCDF_C_VERSION/netcdf-c-$NETCDF_C_VERSION.tar.gz" "$SRC_DIR/netcdf-c-$NETCDF_C_VERSION.tar.gz"
  download "https://downloads.unidata.ucar.edu/netcdf-fortran/$NETCDF_FORTRAN_VERSION/netcdf-fortran-$NETCDF_FORTRAN_VERSION.tar.gz" "$SRC_DIR/netcdf-fortran-$NETCDF_FORTRAN_VERSION.tar.gz"
}

extract() {
  _tarball="$1"
  _name="$2"
  rm -rf "$BUILD_DIR/$_name"
  mkdir -p "$BUILD_DIR/$_name"
  tar -xf "$_tarball" -C "$BUILD_DIR/$_name" --strip-components=1
  if [ ! -e "$BUILD_DIR/$_name/configure" ] && [ ! -e "$BUILD_DIR/$_name/CMakeLists.txt" ]; then
    _regcm_nested_entries=("$BUILD_DIR/$_name"/*)
    if [ "${#_regcm_nested_entries[@]}" = 1 ] && [ -d "${_regcm_nested_entries[0]}" ]; then
      _regcm_nested_dir="${_regcm_nested_entries[0]}"
      shopt -s dotglob
      mv "$_regcm_nested_dir"/* "$BUILD_DIR/$_name/"
      shopt -u dotglob
      rmdir "$_regcm_nested_dir"
    fi
  fi
}

mark_done() {
  mkdir -p "$PREFIX/.regcm-build-markers"
  touch "$PREFIX/.regcm-build-markers/$1.done"
}

is_done() {
  [ -f "$PREFIX/.regcm-build-markers/$1.done" ]
}

run_make_install() {
  make -j "$MAKE_JOBS"
  make install
}

echo
echo "Private RegCM dependency stack build"
echo "  PREFIX    = $PREFIX"
echo "  SRC_DIR   = $SRC_DIR"
echo "  BUILD_DIR = $BUILD_DIR"
echo "  MAKE_JOBS = $MAKE_JOBS"
echo

if [ "${REGCM_DOWNLOAD_ONLY:-0}" = 1 ]; then
  echo "Staging source tarballs only. No compilation will be run."
  stage_sources
  echo "Source staging complete: $SRC_DIR"
  exit 0
fi

stage_sources

echo "Compiler check:"
echo -n "  nvc      -> "; command -v nvc
echo -n "  nvfortran-> "; command -v nvfortran
echo -n "  mpicc    -> "; command -v mpicc
echo -n "  mpifort  -> "; command -v mpifort
echo -n "  mpifort --show -> "; mpifort --show
echo

remove_private_zlib

if [ "${REGCM_BUILD_PRIVATE_ZLIB:-0}" = 1 ] && ! is_done "zlib-$ZLIB_VERSION"; then
  download "https://zlib.net/fossils/zlib-$ZLIB_VERSION.tar.gz" "$SRC_DIR/zlib-$ZLIB_VERSION.tar.gz"
  extract "$SRC_DIR/zlib-$ZLIB_VERSION.tar.gz" "zlib-$ZLIB_VERSION"
  cd "$BUILD_DIR/zlib-$ZLIB_VERSION"
  CC=nvc ./configure --prefix="$PREFIX"
  run_make_install
  mark_done "zlib-$ZLIB_VERSION"
fi

remove_private_zlib

if ! is_done "libaec-$LIBAEC_VERSION"; then
  download "https://gitlab.dkrz.de/k202009/libaec/-/archive/v$LIBAEC_VERSION/libaec-v$LIBAEC_VERSION.tar.gz" "$SRC_DIR/libaec-$LIBAEC_VERSION.tar.gz"
  extract "$SRC_DIR/libaec-$LIBAEC_VERSION.tar.gz" "libaec-$LIBAEC_VERSION"
  rm -rf "$BUILD_DIR/libaec-$LIBAEC_VERSION-build"
  mkdir -p "$BUILD_DIR/libaec-$LIBAEC_VERSION-build"
  cd "$BUILD_DIR/libaec-$LIBAEC_VERSION-build"
  cmake "$BUILD_DIR/libaec-$LIBAEC_VERSION" \
    -DCMAKE_INSTALL_PREFIX="$PREFIX" \
    -DCMAKE_C_COMPILER=nvc \
    -DCMAKE_BUILD_TYPE=Release \
    -DBUILD_SHARED_LIBS=ON
  cmake --build . -j "$MAKE_JOBS"
  cmake --install .
  mark_done "libaec-$LIBAEC_VERSION"
fi

if ! is_done "hdf5-$HDF5_VERSION"; then
  _regcm_hdf5_release="v$(printf '%s' "$HDF5_VERSION" | tr . _)"
  download "https://support.hdfgroup.org/releases/hdf5/v1_14/$_regcm_hdf5_release/downloads/hdf5-$HDF5_VERSION.tar.gz" "$SRC_DIR/hdf5-$HDF5_VERSION.tar.gz"
  extract "$SRC_DIR/hdf5-$HDF5_VERSION.tar.gz" "hdf5-$HDF5_VERSION"
  cd "$BUILD_DIR/hdf5-$HDF5_VERSION"
  CC=mpicc FC=mpifort \
    CPPFLAGS="$PREFIX_CPPFLAGS ${CPPFLAGS:-}" \
    LDFLAGS="$PREFIX_LDFLAGS ${LDFLAGS:-}" \
    LIBS="$SYSTEM_ZLIB ${LIBS:-}" \
    ./configure \
    --prefix="$PREFIX" \
    --enable-shared \
    --enable-hl \
    --enable-parallel \
    --enable-fortran \
    --disable-tests \
    --disable-nonstandard-feature-float16 \
    --with-zlib=/usr \
    --with-szlib="$PREFIX"
  run_make_install
  remove_libtool_archives
  mark_done "hdf5-$HDF5_VERSION"
fi

if ! is_done "pnetcdf-$PNETCDF_VERSION"; then
  download "https://parallel-netcdf.github.io/Release/pnetcdf-$PNETCDF_VERSION.tar.gz" "$SRC_DIR/pnetcdf-$PNETCDF_VERSION.tar.gz"
  extract "$SRC_DIR/pnetcdf-$PNETCDF_VERSION.tar.gz" "pnetcdf-$PNETCDF_VERSION"
  cd "$BUILD_DIR/pnetcdf-$PNETCDF_VERSION"
  CC=mpicc CXX=mpicxx FC=mpifort F77=mpifort \
    LIBS="$SYSTEM_ZLIB ${LIBS:-}" \
    ./configure \
    --prefix="$PREFIX" \
    --enable-shared \
    --enable-fortran
  run_make_install
  remove_libtool_archives
  mark_done "pnetcdf-$PNETCDF_VERSION"
fi

remove_libtool_archives

if ! is_done "netcdf-c-$NETCDF_C_VERSION"; then
  download "https://downloads.unidata.ucar.edu/netcdf-c/$NETCDF_C_VERSION/netcdf-c-$NETCDF_C_VERSION.tar.gz" "$SRC_DIR/netcdf-c-$NETCDF_C_VERSION.tar.gz"
  extract "$SRC_DIR/netcdf-c-$NETCDF_C_VERSION.tar.gz" "netcdf-c-$NETCDF_C_VERSION"
  cd "$BUILD_DIR/netcdf-c-$NETCDF_C_VERSION"
  CC=mpicc \
    CPPFLAGS="$PREFIX_CPPFLAGS ${CPPFLAGS:-}" \
    LDFLAGS="$PREFIX_LDFLAGS ${LDFLAGS:-}" \
    LIBS="-lhdf5_hl -lhdf5 -lsz $SYSTEM_ZLIB ${LIBS:-}" \
    ./configure \
    --prefix="$PREFIX" \
    --enable-shared \
    --enable-netcdf-4 \
    --enable-pnetcdf \
    --disable-dap \
    --disable-byterange
  run_make_install
  remove_libtool_archives
  mark_done "netcdf-c-$NETCDF_C_VERSION"
fi

if ! is_done "netcdf-fortran-$NETCDF_FORTRAN_VERSION"; then
  download "https://downloads.unidata.ucar.edu/netcdf-fortran/$NETCDF_FORTRAN_VERSION/netcdf-fortran-$NETCDF_FORTRAN_VERSION.tar.gz" "$SRC_DIR/netcdf-fortran-$NETCDF_FORTRAN_VERSION.tar.gz"
  extract "$SRC_DIR/netcdf-fortran-$NETCDF_FORTRAN_VERSION.tar.gz" "netcdf-fortran-$NETCDF_FORTRAN_VERSION"
  cd "$BUILD_DIR/netcdf-fortran-$NETCDF_FORTRAN_VERSION"
  CC=mpicc FC=mpifort \
    CPPFLAGS="$PREFIX_CPPFLAGS ${CPPFLAGS:-}" \
    LDFLAGS="$PREFIX_LDFLAGS ${LDFLAGS:-}" \
    LIBS="-lnetcdf -lhdf5_hl -lhdf5 -lsz $SYSTEM_ZLIB ${LIBS:-}" \
    ./configure \
    --prefix="$PREFIX" \
    --enable-shared
  run_make_install
  remove_libtool_archives
  mark_done "netcdf-fortran-$NETCDF_FORTRAN_VERSION"
fi

echo
echo "Build complete. To use this stack with RegCM:"
echo "  export REGCM_DISCOVERER_HDF5=$PREFIX"
echo "  export REGCM_DISCOVERER_NETCDF_C=$PREFIX"
echo "  export REGCM_DISCOVERER_NETCDF_FORTRAN=$PREFIX"
echo "  export REGCM_DISCOVERER_PNETCDF=$PREFIX"
echo "  export REGCM_REQUIRE_IO_STACK=1"
echo "  source $LOADER"
echo
echo "Final tool check:"
echo -n "  h5pcc           -> "; command -v h5pcc 2>/dev/null || true
echo -n "  nc-config       -> "; command -v nc-config 2>/dev/null || true
echo -n "  nf-config       -> "; command -v nf-config 2>/dev/null || true
echo -n "  pnetcdf-config  -> "; command -v pnetcdf-config 2>/dev/null || true
echo -n "  nc-config --version      -> "; nc-config --version 2>/dev/null || true
echo -n "  nf-config --version      -> "; nf-config --version 2>/dev/null || true
echo -n "  pnetcdf-config --version -> "; pnetcdf-config --version 2>/dev/null || true
