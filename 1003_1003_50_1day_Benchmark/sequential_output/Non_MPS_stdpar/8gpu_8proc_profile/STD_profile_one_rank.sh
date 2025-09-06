#!/bin/bash
# profile_STD_profile_per_rank.sh
# Run only one MPI rank under Nsight Systems, others run normally.

# ----------------------------
# Config (tweak as needed)
# ----------------------------
: "${PROFILE_RANK:=3}"                       # which global rank to profile
: "${TRACE_DOMAINS:=cuda,nvtx,mpi}"         # add 'osrt' later if needed
: "${NSYS_SAMPLE:=none}"                    # keep small: none | cpu
: "${MAKE_STATS:=true}"                     # nsys --stats at the end

# ----------------------------
# Rank & GPU binding
# ----------------------------
RANK_GLOBAL=${SLURM_PROCID:-0}
RANK_LOCAL=${SLURM_LOCALID:-0}

# Respect Slurm GPU binding if present; else fall back to 1 GPU per local rank
if [[ -z "${CUDA_VISIBLE_DEVICES:-}" ]]; then
  export CUDA_VISIBLE_DEVICES="$RANK_LOCAL"
fi

# OpenACC/NVHPC knobs (if relevant)
export ACC_DEVICE_TYPE=nvidia
# If CUDA_VISIBLE_DEVICES is CSV, pick the first item for ACC
export ACC_DEVICE_NUM="$RANK_LOCAL"

# ----------------------------
# Paths
# ----------------------------
export BINDIR=/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin
INPUT_FILE=EURR-3_namelist.in

# Per-rank temp (nsys uses TMPDIR heavily)
export TMPDIR="$SCRATCH/tmp_nsys_8gpu/rank_${RANK_GLOBAL}"
mkdir -p "$TMPDIR"

# Output base (we’ll prepend rank-specific names as needed)
OUTDIR="$SCRATCH/profile_8gpu"
mkdir -p "$OUTDIR"

echo "[Rank $RANK_GLOBAL on $(hostname)] GPUs=$CUDA_VISIBLE_DEVICES TMPDIR=$TMPDIR"

# ----------------------------
# Helper: run under NSYS or plain
# ----------------------------
run_under_nsys() {
  local out_base="$OUTDIR/nsys_rank${RANK_GLOBAL}"
  # Ensure parent directory exists
  mkdir -p "$(dirname "$out_base")"

  echo "[Rank $RANK_GLOBAL] Profiling to ${out_base}.nsys-rep (trace: $TRACE_DOMAINS, sample: $NSYS_SAMPLE)"
  nsys profile \
    --force-overwrite=true \
    --stop-on-exit=true \
    --stats="${MAKE_STATS}" \
    --sample="${NSYS_SAMPLE}" \
    --trace="${TRACE_DOMAINS}" \
    --output="${out_base}" \
    "$BINDIR/regcmMPICLM45_OPENACC_GPU_STDPAR" "$INPUT_FILE"
}

run_plain() {
  exec "$BINDIR/regcmMPICLM45_OPENACC_GPU_STDPAR" "$INPUT_FILE"
}

# ----------------------------
# Selective profiling logic
# ----------------------------
if [[ "$RANK_GLOBAL" -eq "$PROFILE_RANK" ]]; then
  run_under_nsys
else
  run_plain
fi

