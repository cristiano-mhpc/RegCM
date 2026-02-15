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

# 1) Merge all into gmon.sum (chunked via xargs to avoid argv limits)
echo "==> Merging profiles into $JOBDIR/gmon.sum ..."
(
  cd "$JOBDIR"
  rm -f gmon.sum
  # Use newest per rank if you prefer:
  # for r in $(ls -1 gmon_out_rank*.* | sed -E 's/.*gmon_out_rank([0-9]+)\..*/\1/' | sort -n | uniq); do
  #   gprof -s "$EXE" "$(ls -1t gmon_out_rank${r}.* | head -1)"
  # done
  find . -maxdepth 1 -type f -name 'gmon_out_rank*.*' -print0 \
    | xargs -0 -n 200 gprof -s "$EXE"
)
echo "   Merged: $JOBDIR/gmon.sum"
echo

# 2) Human-readable merged report
MERGED_TXT="gprof_all_ranks_${JOBID}.txt"
echo "==> Writing merged report: $MERGED_TXT"
gprof -b "$EXE" "$JOBDIR/gmon.sum" > "$MERGED_TXT"

echo
echo "Done. Artifacts:"
echo "  - $JOBDIR/gmon.sum"
echo "  - $MERGED_TXT"
echo "  - $REPORTS_DIR/rank_<N>.txt"
echo "  - top20_${JOBID}.txt"

