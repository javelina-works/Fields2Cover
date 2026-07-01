#!/usr/bin/env bash
#
# cibuildwheel macOS `repair-wheel-command`. Bundles the slim GDAL/GEOS/PROJ
# closure into the wheel but EXCLUDES the OR-Tools closure (the 241 dylibs the
# tarball ships) — those resolve at runtime from the pip `ortools` wheel via the
# @loader_path/../ortools/.libs rpath (the peer-dependency design).
#
# --sanitize-rpaths strips the absolute build rpaths (added via
# CMAKE_INSTALL_RPATH_USE_LINK_PATH so delocate could resolve the @rpath deps);
# @loader_path entries are preserved.
#
# Usage: repair_macos.sh <wheel> <dest_dir> <delocate_archs>
set -euo pipefail

WHEEL="${1:?wheel required}"
DEST="${2:?dest dir required}"
ARCHS="${3:?delocate archs required}"

# OR-Tools closure to leave unbundled (substring match on the install name).
# NOTE: libz/libbz2 are intentionally NOT excluded — GDAL needs them bundled.
# `Python` guards against bundling the Python framework (extension modules must
# use the host interpreter's Python, not a bundled copy → else a 2nd Python
# runtime segfaults at import). Should be redundant now that the SWIG module links
# Python::Module rather than libpython, but kept as a safety net.
EXCLUDES=(
  libortools libabsl libprotobuf libprotoc libre2 libutf8
  libscip libsoplex libhighs
  libCbc libCgl libClp libCoinUtils libOsi
  Python
)
exclude_args=()
for e in "${EXCLUDES[@]}"; do exclude_args+=(-e "$e"); done

delocate-wheel --require-archs "$ARCHS" --sanitize-rpaths \
  "${exclude_args[@]}" \
  -w "$DEST" -v "$WHEEL"
