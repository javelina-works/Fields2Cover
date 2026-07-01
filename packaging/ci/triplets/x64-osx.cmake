# Overlay triplet for the Fields2Cover wheel build (see arm64-osx.cmake for the
# full rationale). x86_64 variant; default min is 10.13 — the floor for PROJ 9.8's
# std::optional::value() — when $MACOSX_DEPLOYMENT_TARGET is not provided.
set(VCPKG_TARGET_ARCHITECTURE x64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
if(DEFINED ENV{MACOSX_DEPLOYMENT_TARGET})
  set(VCPKG_OSX_DEPLOYMENT_TARGET "$ENV{MACOSX_DEPLOYMENT_TARGET}")
else()
  set(VCPKG_OSX_DEPLOYMENT_TARGET "10.13")
endif()
