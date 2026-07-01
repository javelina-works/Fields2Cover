#!/usr/bin/env bash
#
# byo_gdal_fixup.sh — make a Fields2Cover wheel "bring-your-own GDAL".
#
# Fields2Cover links GDAL (and GEOS, TinyXML2) — heavy native libraries that are
# painful to bundle into a wheel and that geospatial users almost always already
# have installed (Homebrew / apt / conda). Rather than bundle them, this rewrites
# the wheel's Homebrew-absolute references (e.g. /opt/homebrew/opt/gdal/lib/
# libgdal.39.dylib) to @rpath/<soname> and adds standard system library dirs to
# the rpath, so the wheel links whatever system GDAL is present at import time.
#
# Combined with the pip `ortools` peer-dependency (see pyproject.toml), the
# resulting wheel bundles only Fields2Cover's own small libs and pulls its heavy
# native deps from the system (GDAL) and from pip (OR-Tools).
#
# macOS: uses install_name_tool + codesign (below).
# Linux equivalent: the native SONAME is already path-less, so no rewrite is
#   needed for system GDAL (ld.so finds libgdal.so.NN in /usr/lib); use
#   `patchelf --set-rpath '$ORIGIN/../ortools.libs:/usr/lib'` for the OR-Tools
#   peer-dep dir if required.
#
# Usage: byo_gdal_fixup.sh <input-wheel> <output-dir> [python]
set -euo pipefail

WHEEL="${1:?input wheel required}"
OUTDIR="${2:?output dir required}"
PY="${3:-python3}"

# Standard locations a system GDAL/GEOS may live (Homebrew arm64, Homebrew Intel
# / manual installs, system). The dynamic loader searches these for @rpath libs.
RPATHS=(/opt/homebrew/lib /usr/local/lib /usr/lib)

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

"$PY" -m wheel unpack "$WHEEL" -d "$work" >/dev/null
pkgdir="$(find "$work" -mindepth 1 -maxdepth 1 -type d)"
libdir="$pkgdir/fields2cover"

shopt -s nullglob
for lib in "$libdir"/*.dylib "$libdir"/*.so; do
  # Repoint every Homebrew-absolute dependency to @rpath/<basename>.
  while IFS= read -r dep; do
    install_name_tool -change "$dep" "@rpath/$(basename "$dep")" "$lib"
  done < <(otool -L "$lib" | awk '/\/opt\/homebrew\//{print $1}')

  # Ensure the system lib dirs are searchable (ignore "already present").
  for rp in "${RPATHS[@]}"; do
    install_name_tool -add_rpath "$rp" "$lib" 2>/dev/null || true
  done

  # Re-sign (install_name_tool invalidates the ad-hoc signature on arm64).
  codesign -f -s - "$lib" >/dev/null 2>&1 || true
done

mkdir -p "$OUTDIR"
"$PY" -m wheel pack "$pkgdir" -d "$OUTDIR" >/dev/null
echo "BYO-GDAL wheel written to: $OUTDIR"
