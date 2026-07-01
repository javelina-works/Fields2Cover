# Packaging Fields2Cover as a Python wheel

Fields2Cover's Python bindings link heavy native libraries — **GDAL**,
**OR-Tools** (which carries abseil/protobuf), and the smaller **GEOS** /
**TinyXML2**. Bundling all of them into one wheel via `delocate`/`auditwheel` is
brittle: relocating Homebrew's full GDAL closure crashes at import (a symbol /
static-init conflict), and OR-Tools' abseil/protobuf process-globals are fragile
to relocate.

Instead this wheel bundles only Fields2Cover's *own* small libraries and sources
its heavy native deps from where they already live:

| Dependency | Source at runtime |
|---|---|
| **OR-Tools** (`libortools` + abseil/protobuf) | the pip **`ortools`** wheel — declared as an exact `==` dependency |
| **GDAL / GEOS / TinyXML2** | the **system** install (Homebrew / apt / conda) — bring-your-own |
| libFields2Cover / steering_functions / matplot | bundled inside the wheel |

This is a recognized Python packaging tier (cf. the official `GDAL` bindings,
`pygraphviz`, `psycopg2`): a small wheel that requires a system GDAL and pulls
its Python-shipped deps from pip.

## Requirements to install the wheel

- A system **GDAL** (`brew install gdal`, `apt install libgdal-dev`, or conda).
- `ortools==<matching version>` — pulled automatically as a dependency
  (currently pinned to `9.15.6755` in `pyproject.toml`).

The `ortools` pin must be **exact**: Fields2Cover is compiled against OR-Tools'
abseil/protobuf ABI, which is not stable across OR-Tools releases, so bumping
OR-Tools means rebuilding this wheel. See "Why exact" below.

## How the wheel is built

1. **Build** against OR-Tools' official C++ release so F2C's `@rpath/libortools`
   + `@rpath/libabsl_*` / `libprotobuf` references match the pip `ortools` wheel
   exactly, with GDAL/GEOS from the system:

   ```bash
   # Unpack the official tarball matching the pinned ortools version, e.g.
   #   or-tools_arm64_macOS-<n>_cpp_v9.15.6755.tar.gz  (github.com/google/or-tools/releases)
   ORDIR=/path/to/or-tools_<arch>_<os>_cpp_v9.15.6755
   export LIBRARY_PATH=/opt/homebrew/lib:$ORDIR/lib
   export CPATH=/opt/homebrew/include:$ORDIR/include
   python -m build --wheel --no-isolation \
     -C "cmake.define.CMAKE_PREFIX_PATH=$ORDIR;/opt/homebrew" \
     -C "cmake.define.ortools_DIR=$ORDIR/lib/cmake/ortools"
   ```

   `pyproject.toml` declares `dependencies = ["ortools==9.15.6755"]`, and
   `swig/python/CMakeLists.txt` adds `INSTALL_RPATH @loader_path/../ortools/.libs`
   so the OR-Tools peer-dependency resolves from the installed `ortools` package.

2. **BYO-GDAL fixup** — repoint the Homebrew-absolute GDAL/GEOS/TinyXML2
   references to `@rpath/<soname>` and add the standard system lib dirs to the
   rpath, so the wheel links *any* system GDAL rather than a pinned Cellar path:

   ```bash
   packaging/byo_gdal_fixup.sh dist/fields2cover-*.whl wheelhouse/
   ```

   After this the wheel has **no `/opt/homebrew` paths**; gdal/geos/tinyxml2/
   ortools are all `@rpath`, resolved from `/opt/homebrew/lib`, `/usr/local/lib`,
   `/usr/lib`, or the `ortools` package.

## Platform notes

- **macOS** (`byo_gdal_fixup.sh`): rewrites Homebrew-absolute load commands to
  `@rpath/<soname>` via `install_name_tool`, adds the system lib dirs to the
  rpath, and re-signs (ad-hoc).
- **Linux**: the native ELF `SONAME` (e.g. `libgdal.so.34`) is already
  path-less, so `ld.so` finds a system GDAL in `/usr/lib` with no rewrite. Use
  `patchelf --set-rpath '$ORIGIN/../ortools.libs'` only for the OR-Tools
  peer-dependency directory.

## Why exact `ortools==`

F2C's `libFields2Cover` bakes in specific abseil/protobuf sonames
(`@rpath/libabsl_*.2508…`, `@rpath/libprotobuf.33…`) and relies on their C++
ABI. OR-Tools bumps its bundled abseil/protobuf between releases, and those
libraries do not promise ABI stability — so a wheel built against one OR-Tools
release only works with that release's `ortools` package. This is the same
coordinated-release model PyTorch uses with the `nvidia-*` CUDA wheels.
