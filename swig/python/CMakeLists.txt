# Include python
find_package(
  Python REQUIRED
  COMPONENTS
    Interpreter
    Development
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
SWIG_LINK_LIBRARIES(fields2cover_python
  Fields2Cover
  ${Python_LIBRARIES}
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
  set_target_properties(fields2cover_python Fields2Cover steering_functions matplot
    PROPERTIES INSTALL_RPATH "@loader_path;@loader_path/../ortools/.libs")

  install(FILES "${CMAKE_CURRENT_BINARY_DIR}/fields2cover.py"
    DESTINATION fields2cover RENAME __init__.py)
  install(TARGETS fields2cover_python
    LIBRARY DESTINATION fields2cover)
  install(TARGETS Fields2Cover steering_functions matplot
    LIBRARY DESTINATION fields2cover
    RUNTIME DESTINATION fields2cover)
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



