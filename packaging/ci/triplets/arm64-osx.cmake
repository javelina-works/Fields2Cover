# Overlay triplet for the Fields2Cover wheel build (see before_all_macos.sh).
#
# Same as vcpkg's built-in arm64-osx (DYNAMIC libs, so the closure can be
# relocated into the wheel by delocate) but pins the macOS deployment target.
# Why: PROJ 9.8 uses std::optional::value(), which clang marks unavailable
# before macOS 10.13; vcpkg was otherwise inheriting a 10.9 target from the
# environment and failing. arm64 macOS starts at 11.0. Driven by
# $MACOSX_DEPLOYMENT_TARGET (the CI job sets it) so the vcpkg build and the
# cibuildwheel wheel build use the SAME target and delocate stays happy.
set(VCPKG_TARGET_ARCHITECTURE arm64)
set(VCPKG_CRT_LINKAGE dynamic)
set(VCPKG_LIBRARY_LINKAGE dynamic)
set(VCPKG_CMAKE_SYSTEM_NAME Darwin)
if(DEFINED ENV{MACOSX_DEPLOYMENT_TARGET})
  set(VCPKG_OSX_DEPLOYMENT_TARGET "$ENV{MACOSX_DEPLOYMENT_TARGET}")
else()
  set(VCPKG_OSX_DEPLOYMENT_TARGET "11.0")
endif()
