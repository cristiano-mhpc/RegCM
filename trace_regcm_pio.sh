#!/bin/bash
# Trace RegCM parallel I/O call relationships

# Step 1: Extract I/O routine names from mod_mppparam.F90
echo "[*] Extracting I/O routines..."
routines=$(grep -E 'subroutine grid_nc_|interface grid_nc_' Main/mpplib/mod_mppparam.F90 \
    | sed -E 's/.*subroutine //; s/.*interface //; s/\(.*//; s/,.*//' | sort -u)

echo "[*] Found routines:"
echo "$routines" | sed 's/^/    /'

echo
echo "[*] Searching for calls in codebase..."
echo "======================================"

# Step 2: Find where they are called
for r in $routines; do
    echo "Calls to $r:"
    grep -RIn --include='*.F90' -E "\b$r\b" . \
        | grep -v 'mod_mppparam.F90' \
        | sed 's/^/    /'
    echo
done

