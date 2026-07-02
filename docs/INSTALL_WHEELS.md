# Installing the Fields2Cover Python wheels

This fork publishes **self-contained pre-built wheels** for the Fields2Cover
Python bindings, so you can `pip install` them without a C++ toolchain, without
building GDAL/GEOS/PROJ, and without conda. The slim GDAL/GEOS/PROJ stack (plus
PROJ's `proj.db`) is bundled inside the wheel; OR-Tools is pulled in as a normal
dependency.

## Supported platforms

| OS | Arch | Wheel tag |
|----|------|-----------|
| Linux (manylinux_2_28, glibc ≥ 2.28) | x86_64 | `manylinux_2_28_x86_64` |
| Linux (manylinux_2_28, glibc ≥ 2.28) | aarch64 | `manylinux_2_28_aarch64` |
| macOS 11+ | Apple Silicon (arm64) | `macosx_11_0_arm64` |

Python **3.9 – 3.13** (CPython). Intel macOS and Windows are not built yet
(Intel-mac users can build from source or run the x86_64 wheel under Rosetta).

> OR-Tools is a runtime dependency and is installed automatically
> (`ortools==9.15.6755`, pinned exact — the wheels are built against that exact
> OR-Tools ABI). It ships its own prebuilt binaries for the platforms above.

## Install from a GitHub Release (recommended)

Wheels are attached to each [GitHub Release](https://github.com/javelina-works/Fields2Cover/releases).
Point pip at the release's assets and let it pick the wheel matching your OS /
arch / Python; `ortools` is resolved automatically:

```bash
pip install fields2cover \
  --find-links https://github.com/javelina-works/Fields2Cover/releases/expanded_assets/<TAG>
```

Replace `<TAG>` with the release tag (e.g. `v2.1.0`). To install a *specific*
wheel directly instead:

```bash
pip install https://github.com/javelina-works/Fields2Cover/releases/download/<TAG>/fields2cover-<VERSION>-cp312-cp312-manylinux_2_28_x86_64.whl
```

### uv

```bash
uv pip install fields2cover \
  --find-links https://github.com/javelina-works/Fields2Cover/releases/expanded_assets/<TAG>
```

Or pin it in a project's `pyproject.toml` (uv) via the exact wheel URL for your
platform:

```toml
[tool.uv.sources]
fields2cover = { url = "https://github.com/javelina-works/Fields2Cover/releases/download/<TAG>/fields2cover-<VERSION>-cp312-cp312-manylinux_2_28_x86_64.whl" }
```

## Install from CI artifacts (before a release is cut)

Every "Build wheels" run uploads the wheels as artifacts (`wheels-macos-arm64`,
`wheels-manylinux-x86_64`, `wheels-manylinux-aarch64`). Download your platform's
artifact from the
[Actions tab](https://github.com/javelina-works/Fields2Cover/actions/workflows/build-wheels.yml),
unzip it, and install the wheel for your Python version:

```bash
pip install ./fields2cover-*-cp312-cp312-manylinux_2_28_x86_64.whl
```

## Verify the install

```bash
python -c "import fields2cover as f2c; print(f2c.Point(1, 2).getX())"   # -> 1.0
```

The import name is `fields2cover` (not `jav-fields2cover`).

## Notes

- **Self-contained.** GDAL, GEOS, PROJ (with `proj.db` for CRS transforms), and
  their dependencies are bundled in the wheel — nothing else to install besides
  OR-Tools (automatic).
- **CRS transforms work out of the box.** `proj.db` is bundled and `PROJ_DATA`
  is set on import, so `f2c.Transform` / coordinate conversions function without
  a system PROJ.
- **Building from source** is still the way to get platforms not listed above;
  see the upstream README / docs.
