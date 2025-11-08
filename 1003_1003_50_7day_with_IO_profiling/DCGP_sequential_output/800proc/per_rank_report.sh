#!/bin/bash
# gprof_accum.sh
#USAGE: ./gprof_accum.sh <JOBDIR> [EXE]
# Example:
#    ./gprof_acccum.sh gprof_123456 /path/to/regcm_binary/regcmMPICLM45  

set -euo pipefail 
JOBDIR="${1:-}"
EXE="${2:-}"

if [[ -z "$JOBDIR" || ! -d "$JOBDIR" ]]; then
  echo "Usage: $0 <JOBDIR> [EXE]"
  echo "       <JOBDIR> must exist and contain gmon_out_rank<rank>.<pid> files"
  exit 1
fi
if [[ ! -x "$EXE" ]]; then
  echo "ERROR: Executable not found or not executable: $EXE"
  exit 1
fi

JOBID="${JOBDIR#gprof_}"
REPORTS_DIR="reports_${JOBID}"
mkdir -p "$REPORTS_DIR"


echo "==> JOBDIR:  $JOBDIR"
echo "==> JOBID:   $JOBID"
echo "==> EXE:     $EXE"
echo "==> Reports: $REPORTS_DIR"
echo

# Sanity: ensure there are gmon files
shopt -s nullglob
GMON_FILES=( "$JOBDIR"/gmon_out_rank*.* )
shopt -u nullglob
if (( ${#GMON_FILES[@]} == 0 )); then
  echo "ERROR: No files like $JOBDIR/gmon_out_rank<rank>.<pid> found."
  exit 1
fi

# 3) Per-rank reports (pick newest file per rank)
echo "==> Generating per-rank reports in $REPORTS_DIR/ ..."


RANKS=$(
  ls -1 "$JOBDIR"/gmon_out_rank*.* \
  | sed -E 's#.*/gmon_out_rank([0-9]+)\..*#\1#' \
  | sort -n | uniq
)
for r in $RANKS; do
  SRC=$(ls -1t "$JOBDIR"/gmon_out_rank${r}.* | head -1)
  gprof "$EXE" "$SRC" > "$REPORTS_DIR/rank_${r}.txt"
done
