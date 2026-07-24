#!/usr/bin/env bash

set -euo pipefail

: "${SLURM_PROCID:?This wrapper must be launched with srun}"
: "${SLURM_LOCALID:?This wrapper must be launched with srun}"

readonly BINARY=/leonardo/home/userexternal/ctica000/MS_thesis/RegCM/bin/clm45/regcmMPICLM45
readonly NAMELIST=${1:-EURR-3_namelist.in}

export OMP_NUM_THREADS="${SLURM_CPUS_PER_TASK:-1}"

[[ -x "$BINARY" ]] || { printf 'Rank %s cannot execute %s\n' "$SLURM_PROCID" "$BINARY" >&2; exit 1; }
exec "$BINARY" "$NAMELIST"
