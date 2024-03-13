# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(libwebp_flutter_libs_library VERSION 0.0.1 LANGUAGES C)

add_library(libwebp_flutter_libs SHARED
  "libwebp_flutter_libs.c"
)

set_target_properties(libwebp_flutter_libs PROPERTIES
  PUBLIC_HEADER libwebp_flutter_libs.h
  OUTPUT_NAME "libwebp_flutter_libs"
)

target_compile_definitions(libwebp_flutter_libs PUBLIC DART_SHARED_LIB)
