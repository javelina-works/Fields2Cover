#!/usr/bin/env bash
#
# cibuildwheel `before-all` for Linux — runs INSIDE the manylinux_2_28 container
# (AlmaLinux 8) once per (arch). Mirrors before_all_macos.sh but for Linux:
#   $PROJECT/vcpkg_installed/active   -> slim GDAL(+geos)/GEOS/PROJ/Eigen3/TinyXML2
#   $PROJECT/.ortools                 -> OR-Tools official C++ build (v9.15.6755)
#
# manylinux_2_28 == AlmaLinux 8, so we use OR-Tools' AlmaLinux-8.10 C++ tarball
# (glibc matches the container). OR-Tools stays a runtime peer-dependency (the pip
# `ortools` wheel keeps its libs in ortools/.libs/, reached via the $ORIGIN/../
# ortools/.libs RUNPATH); auditwheel bundles only the slim GDAL/GEOS/PROJ closure.
#
# Usage: before_all_linux.sh [PROJECT_DIR]   (cibuildwheel passes {project})
set -euo pipefail

PROJECT="$(cd "${1:-$PWD}" && pwd)"
cd "$PROJECT"

ORTOOLS_VER="9.15.6755"
ORTOOLS_TAG="v9.15"
VCPKG_REF="2026.06.24"

# vcpkg's bootstrap needs curl/zip/unzip/tar. The minimal manylinux_2_28 image
# ships some but not all (it has `unzip` but not `zip`), so install the full set
# outright rather than probing for one of them.
(dnf install -y curl zip unzip tar) || (yum install -y curl zip unzip tar)

arch="$(uname -m)"               # x86_64 | aarch64
if [ "$arch" = "x86_64" ]; then
  TRIPLET="x64-linux-dynamic"
  OR_ASSET="or-tools_x86_64_AlmaLinux-8.10_cpp_v${ORTOOLS_VER}.tar.gz"
else
  TRIPLET="arm64-linux-dynamic"
  OR_ASSET="or-tools_aarch64_AlmaLinux-8.10_cpp_v${ORTOOLS_VER}.tar.gz"
fi
echo "[before-all] arch=$arch triplet=$TRIPLET"

# --- OR-Tools official C++ build (build-time headers/libs only) ---
ORTOOLS_HOME="$PROJECT/.ortools"
if [ ! -f "$ORTOOLS_HOME/lib/cmake/ortools/ortoolsConfig.cmake" ]; then
  echo "[before-all] fetching $OR_ASSET"
  mkdir -p "$ORTOOLS_HOME"
  curl -fsSL "https://github.com/google/or-tools/releases/download/${ORTOOLS_TAG}/${OR_ASSET}" \
    | tar -xz -C "$ORTOOLS_HOME" --strip-components=1
fi

# --- vcpkg: slim GDAL/GEOS/PROJ/Eigen3/TinyXML2 (dynamic libs for auditwheel) ---
export VCPKG_ROOT="$PROJECT/.vcpkg"
# Persist vcpkg's built packages under the (bind-mounted) project so the host
# actions/cache step can save/restore them across runs.
export VCPKG_DEFAULT_BINARY_CACHE="$PROJECT/.vcpkg-bincache"
mkdir -p "$VCPKG_DEFAULT_BINARY_CACHE"
if [ ! -x "$VCPKG_ROOT/vcpkg" ]; then
  echo "[before-all] bootstrapping vcpkg @ $VCPKG_REF"
  git clone --depth 1 --branch "$VCPKG_REF" https://github.com/microsoft/vcpkg "$VCPKG_ROOT"
  "$VCPKG_ROOT/bootstrap-vcpkg.sh" -disableMetrics
fi
"$VCPKG_ROOT/vcpkg" install \
  --triplet "$TRIPLET" \
  --x-install-root="$PROJECT/vcpkg_installed"

ln -sfn "$TRIPLET" "$PROJECT/vcpkg_installed/active"

echo "[before-all] ready:"
echo "  vcpkg  -> $PROJECT/vcpkg_installed/active ($TRIPLET)"
echo "  ortools-> $ORTOOLS_HOME"
