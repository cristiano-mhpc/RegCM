#!/bin/bash
set -euo pipefail
set -x

# Rank discovery (works with srun or mpirun)
RANK_GLOBAL=${SLURM_PROCID:-${OMPI_COMM_WORLD_RANK:-0}}
RANK_LOCAL=${SLURM_LOCALID:-${OMPI_COMM_WORLD_LOCAL_RANK:-0}}
PROFILE_RANK=${PROFILE_RANK:-15}

# One GPU per task
export CUDA_VISIBLE_DEVICES="$RANK_LOCAL"
export ACC_DEVICE_TYPE=nvidia
export ACC_DEVICE_NUM=0
export OMP_NUM_THREADS=${OMP_NUM_THREADS:-1}

NSYS_BIN="/leonardo/prod/opt/compilers/nvhpc/25.3/binary/Linux_x86_64/25.3/compilers/bin/nsys"
BINDIR=${BINDIR:-/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin/profile_binary}
BIN=${BIN:-regcmMPICLM45_OPENACC_GPU_STDPAR}
INPUT_FILE=${INPUT_FILE:-EURR-3_namelist.in}

OUTDIR="${SCRATCH}/profile_new_nsys_8gpu"
TMPDIR_BASE="${SCRATCH}/tmp_nsys"
mkdir -p "${OUTDIR}" "${TMPDIR_BASE}/rank_${RANK_GLOBAL}"
export TMPDIR="${TMPDIR_BASE}/rank_${RANK_GLOBAL}"
NSYS_OUT="${OUTDIR}/nsys_rank${RANK_GLOBAL}"

if [[ "${RANK_GLOBAL}" -eq "${PROFILE_RANK}" ]]; then
  echo "[Rank ${RANK_GLOBAL}] Profiling with Nsight Systems"
  exec "${NSYS_BIN}" profile \
      --force-overwrite=true \
      --sample=none \
      --cpuctxsw=none \
      --trace=nvtx,mpi,cuda \
      --mpi-impl=openmpi \
      --output "${NSYS_OUT}" \
      "${BINDIR}/${BIN}" "${INPUT_FILE}"
else
  echo "[Rank ${RANK_GLOBAL}] Running normally"
  exec "${BINDIR}/${BIN}" "${INPUT_FILE}"
fi

