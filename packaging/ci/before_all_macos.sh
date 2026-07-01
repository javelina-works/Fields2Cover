#!/usr/bin/env bash
#
# cibuildwheel `before-all` for macOS — provision the native build stack once
# per (OS, arch) on the host runner, at STABLE, arch-independent paths that the
# [tool.cibuildwheel.macos].environment block can point CMAKE_PREFIX_PATH /
# ortools_DIR at:
#
#   $PROJECT/vcpkg_installed/active   -> slim GDAL(+geos)/GEOS/PROJ/Eigen3/TinyXML2
#   $PROJECT/.ortools                 -> OR-Tools official C++ build (v9.15.6755)
#
# OR-Tools is a runtime PEER-DEPENDENCY (the pip `ortools` wheel supplies the
# libs at import via the @loader_path/../ortools/.libs rpath); we only need its
# headers + CMake config at BUILD time, which this fetches. The delocate repair
# step (see pyproject) then bundles GDAL/GEOS/PROJ but EXCLUDES the OR-Tools
# closure so it isn't shipped twice.
#
# Usage: before_all_macos.sh [PROJECT_DIR]   (cibuildwheel passes {project})
set -euo pipefail

PROJECT="${1:-$PWD}"
cd "$PROJECT"

ORTOOLS_VER="9.15.6755"          # must equal the pin in pyproject [project].dependencies
ORTOOLS_TAG="v9.15"
VCPKG_REF="2026.06.24"           # pinned vcpkg release for reproducible port versions

arch="$(uname -m)"               # arm64 | x86_64
if [ "$arch" = "arm64" ]; then
  TRIPLET="arm64-osx"
  OR_ASSET="or-tools_arm64_macOS-26.2_cpp_v${ORTOOLS_VER}.tar.gz"
else
  TRIPLET="x64-osx"
  OR_ASSET="or-tools_x86_64_macOS-26.2_cpp_v${ORTOOLS_VER}.tar.gz"
fi

# --- OR-Tools official C++ build (build-time headers/libs only) ---
ORTOOLS_HOME="$PROJECT/.ortools"
if [ ! -f "$ORTOOLS_HOME/lib/cmake/ortools/ortoolsConfig.cmake" ]; then
  echo "[before-all] fetching $OR_ASSET"
  mkdir -p "$ORTOOLS_HOME"
  curl -fsSL "https://github.com/google/or-tools/releases/download/${ORTOOLS_TAG}/${OR_ASSET}" \
    | tar -xz -C "$ORTOOLS_HOME" --strip-components=1
fi

# --- vcpkg: slim GDAL/GEOS/PROJ/Eigen3/TinyXML2 (manifest mode reads ./vcpkg.json) ---
export VCPKG_ROOT="$PROJECT/.vcpkg"
if [ ! -x "$VCPKG_ROOT/vcpkg" ]; then
  echo "[before-all] bootstrapping vcpkg @ $VCPKG_REF"
  git clone --depth 1 --branch "$VCPKG_REF" https://github.com/microsoft/vcpkg "$VCPKG_ROOT"
  "$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics
fi
"$VCPKG_ROOT/vcpkg" install --triplet "$TRIPLET" --x-install-root="$PROJECT/vcpkg_installed"

# Stable arch-independent alias so the (static) cibuildwheel environment block
# doesn't need to know the triplet.
ln -sfn "$TRIPLET" "$PROJECT/vcpkg_installed/active"

echo "[before-all] ready:"
echo "  vcpkg  -> $PROJECT/vcpkg_installed/active ($TRIPLET)"
echo "  ortools-> $ORTOOLS_HOME"
