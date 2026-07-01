# Include python. Request Development.Module (extension-module headers + the
# Python::Module target), NOT the full Development (which also needs
# Development.Embed -> libpython, for EMBEDDING). manylinux Pythons ship no
# libpython, so `Development` fails there; we only build an extension module, so
# Development.Module is both sufficient and portable (macOS has it too).
find_package(
  Python REQUIRED
  COMPONENTS
    Interpreter
    Development.Module
)

if(Python_VERSION VERSION_GREATER_EQUAL 3)
  list(APPEND CMAKE_SWIG_FLAGS "-py3;-DPY3")
endif()

if(BUILD_DOC)
  list(APPEND CMAKE_SWIG_FLAGS "-doxygen")
endif()

set(CMAKE_SWIG_FLAGS "")
set_source_files_properties(
  ../${PROJECT_NAME}.i
  PROPERTIES CPLUSPLUS ON
)

include_directories(
  ${CMAKE_CURRENT_SOURCE_DIR}/../../include/
  ${Python_INCLUDE_DIRS}
)

# Add swig module
SWIG_ADD_LIBRARY(fields2cover_python
  LANGUAGE python
  SOURCES ../${PROJECT_NAME}.i
)
# Link Python::Module (the FindPython target for EXTENSION modules), NOT
# ${Python_LIBRARIES} (the full libpython, for embedding). Linking libpython into
# an extension makes the module carry a hard dependency on a specific Python, which
# delocate then bundles into the wheel (.dylibs/Python) — loading a second Python
# runtime at import and segfaulting. Python::Module links no libpython and resolves
# Python symbols from the host interpreter at load (dynamic_lookup on macOS).
SWIG_LINK_LIBRARIES(fields2cover_python
  Fields2Cover
  Python::Module
  ${PROJ_LIBRARY}
  ${GDAL_LIBRARIES}
)

# Files to install with Python
set(
  PYTHON_INSTALL_FILES
  ${CMAKE_CURRENT_BINARY_DIR}/fields2cover.py
  ${CMAKE_CURRENT_BINARY_DIR}/_fields2cover_python.so
)

# Configure setup.py and copy to output directory
set(SETUP_PY_IN ${CMAKE_CURRENT_SOURCE_DIR}/setup.py.in)
set(SETUP_PY_OUT ${CMAKE_CURRENT_BINARY_DIR}/setup.py)
configure_file(${SETUP_PY_IN} ${SETUP_PY_OUT})

set(PYPROJECT_IN ${CMAKE_CURRENT_SOURCE_DIR}/pyproject.toml)
set(PYPROJECT_OUT ${CMAKE_CURRENT_BINARY_DIR}/pyproject.toml)
configure_file(${PYPROJECT_IN} ${PYPROJECT_OUT} COPYONLY)

set(MANIFEST_IN ${CMAKE_CURRENT_SOURCE_DIR}/MANIFEST.in)
set(MANIFEST_OUT ${CMAKE_CURRENT_BINARY_DIR}/MANIFEST.in)
configure_file(
  ${MANIFEST_IN}
  ${MANIFEST_OUT}
  COPYONLY
)
configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/../../LICENSE
  ${CMAKE_CURRENT_BINARY_DIR}/LICENSE
  COPYONLY
)
configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/../../README.rst
  ${CMAKE_CURRENT_BINARY_DIR}/README.rst
  COPYONLY
)
configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/__init__.py.in
  ${CMAKE_CURRENT_BINARY_DIR}/__init__.py
  COPYONLY
)
configure_file(
  ${CMAKE_CURRENT_SOURCE_DIR}/__init__.py.in
  ${CMAKE_CURRENT_BINARY_DIR}/fields2cover/__init__.py
  COPYONLY
)

file(
  COPY ${CMAKE_CURRENT_SOURCE_DIR}/../../src
  DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/fields2cover
)
file(
  COPY ${CMAKE_CURRENT_SOURCE_DIR}/../../include
  DESTINATION ${CMAKE_CURRENT_BINARY_DIR}/fields2cover
)


if(DEFINED SKBUILD)
  # ---- scikit-build-core: assemble a self-contained `fields2cover` package ----
  # Place the SWIG wrapper (as __init__.py), the extension module, and the
  # runtime C++ libs side by side in the package dir, and resolve siblings via
  # @loader_path. delocate (macOS) / auditwheel (Linux) then bundle the external
  # deps (GDAL, OR-Tools, GEOS, abseil, ...) into the wheel for self-containment.
  # Peer-dependency on the pip `ortools` package: F2C is built against OR-Tools'
  # official build, so its @rpath/libortools + @rpath/libabsl_*/libprotobuf refs
  # (excluded from delocate bundling) resolve from the installed ortools wheel's
  # `.libs/` dir at runtime. libortools then finds its own siblings via its own
  # @loader_path rpath.
  # Resolve sibling libs from the package dir, and the OR-Tools peer-dependency
  # from the installed pip `ortools` wheel's ortools/.libs (same relative layout
  # on both platforms). macOS uses @loader_path; Linux (ELF) uses $ORIGIN.
  if(APPLE)
    set(F2C_PY_INSTALL_RPATH "@loader_path;@loader_path/../ortools/.libs")
  else()
    set(F2C_PY_INSTALL_RPATH "$ORIGIN;$ORIGIN/../ortools/.libs")
  endif()
  set_target_properties(fields2cover_python Fields2Cover steering_functions matplot
    PROPERTIES INSTALL_RPATH "${F2C_PY_INSTALL_RPATH}")

  install(FILES "${CMAKE_CURRENT_BINARY_DIR}/fields2cover.py"
    DESTINATION fields2cover RENAME __init__.py)
  install(TARGETS fields2cover_python
    LIBRARY DESTINATION fields2cover)
  install(TARGETS Fields2Cover steering_functions matplot
    LIBRARY DESTINATION fields2cover
    RUNTIME DESTINATION fields2cover)

  # Bundle PROJ's database so CRS coordinate transforms work in the relocated
  # wheel: the slim PROJ ships libproj but not proj.db, and without it
  # OGRSpatialReference transforms segfault. Pull it from the SAME prefix as the
  # linked libproj (CMAKE_PREFIX_PATH -> vcpkg) so the schema matches. The SWIG
  # module's %pythonbegin points PROJ_DATA at this dir.
  # find_file's default search includes the CMAKE_PREFIX_PATH *environment*
  # variable (which CI/before-all sets to the vcpkg prefix) — do NOT pass
  # `PATHS ${CMAKE_PREFIX_PATH} NO_DEFAULT_PATH`: the CMake *variable* is empty
  # here (only the env var is set), so that searches nothing.
  find_file(F2C_PROJ_DB proj.db PATH_SUFFIXES share/proj)
  if(F2C_PROJ_DB)
    message(STATUS "Bundling PROJ database into wheel: ${F2C_PROJ_DB}")
    install(FILES "${F2C_PROJ_DB}" DESTINATION fields2cover/proj_data)
  else()
    # Hard-fail: a wheel without proj.db segfaults on any CRS transform, and that
    # only shows at test time. Fail the build instead of shipping a broken wheel.
    message(FATAL_ERROR "proj.db not found (searched CMAKE_PREFIX_PATH + system, "
                        "suffix share/proj). CRS transforms would segfault. Ensure "
                        "PROJ (with its data) is on CMAKE_PREFIX_PATH.")
  endif()
else()
  # Legacy: copy the compiled module into site-packages via setup.py.
  if(Python_VERSION VERSION_GREATER_EQUAL 3)
    add_custom_target(install-python
      DEPENDS _fields2cover_python
      COMMAND python3 ${SETUP_PY_OUT} install --prefix=${CMAKE_INSTALL_PREFIX}
    )
    install(CODE "execute_process(COMMAND python3 ${SETUP_PY_OUT} install --prefix=${CMAKE_INSTALL_PREFIX})")
  elseif(Python_VERSION VERSION_GREATER_EQUAL 2)
    add_custom_target(
      install-python
      DEPENDS
        _fields2cover_python
      COMMAND
        python ${SETUP_PY_OUT} install
    )
    install(CODE "execute_process(COMMAND python ${SETUP_PY_OUT} install)")
  endif()
endif()



