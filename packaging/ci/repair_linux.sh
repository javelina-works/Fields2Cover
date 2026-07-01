#!/usr/bin/env bash
#
# cibuildwheel Linux `repair-wheel-command`. auditwheel bundles the slim
# GDAL/GEOS/PROJ closure but EXCLUDES the OR-Tools SONAMEs — those resolve at
# runtime from the pip `ortools` wheel via the $ORIGIN/../ortools/.libs RUNPATH
# (the peer-dependency design). LD_LIBRARY_PATH (set in the cibuildwheel Linux
# environment) lets auditwheel find the vcpkg GDAL libs it does bundle.
#
# Usage: repair_linux.sh <wheel> <dest_dir>
set -euo pipefail

WHEEL="${1:?wheel required}"
DEST="${2:?dest dir required}"

# OR-Tools closure to leave unbundled (SONAME globs). libz/libbz2 stay bundled.
EXCLUDES=(
  'libortools*' 'libabsl*' 'libprotobuf*' 'libprotoc*' 'libre2*' 'libutf8*'
  'libscip*' 'libsoplex*' 'libhighs*'
  'libCbc*' 'libCgl*' 'libClp*' 'libCoinUtils*' 'libOsi*'
)
exclude_args=()
for e in "${EXCLUDES[@]}"; do exclude_args+=(--exclude "$e"); done

auditwheel repair "${exclude_args[@]}" -w "$DEST" "$WHEEL"
