# The Flutter tooling requires that developers have a version of Visual Studio
# installed that includes CMake 3.14 or later. You should not increase this
# version, as doing so will cause the plugin to fail to compile for some
# customers of the plugin.
cmake_minimum_required(VERSION 3.14)

# Project-level configuration.
set(PROJECT_NAME "libwebp_flutter_libs")
# project(${PROJECT_NAME} LANGUAGES CXX)

# Invoke the build for native code shared with the other target platforms.
# This can be changed to accommodate different builds.
# add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../src" "${CMAKE_CURRENT_BINARY_DIR}/shared")

# List of absolute paths to libraries that should be bundled with the plugin.
# This list could contain prebuilt libraries, or libraries created by an
# external build triggered from this build file.
set(libwebp_flutter_libs_bundled_libraries
  # Defined in ../src/CMakeLists.txt.
  # This can be changed to accommodate different builds.
  # $<TARGET_FILE:libwebp_flutter_libs>
  # Add any other libraries that should be bundled with the plugin.
  "${CMAKE_CURRENT_SOURCE_DIR}/release-dynamic/x64/bin/libsharpyuv.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/release-dynamic/x64/bin/libwebpmux.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/release-dynamic/x64/bin/libwebpdemux.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/release-dynamic/x64/bin/libwebpdecoder.dll"
  "${CMAKE_CURRENT_SOURCE_DIR}/release-dynamic/x64/bin/libwebp.dll"
  PARENT_SCOPE
)
