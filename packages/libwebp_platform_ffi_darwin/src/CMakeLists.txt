# The Flutter tooling requires that developers have CMake 3.10 or later
# installed. You should not increase this version, as doing so will cause
# the plugin to fail to compile for some customers of the plugin.
cmake_minimum_required(VERSION 3.10)

project(libwebp_platform_ffi_darwin_library VERSION 0.0.1 LANGUAGES C)

add_library(libwebp_platform_ffi_darwin SHARED
  "libwebp_platform_ffi_darwin.c"
)

set_target_properties(libwebp_platform_ffi_darwin PROPERTIES
  PUBLIC_HEADER libwebp_platform_ffi_darwin.h
  OUTPUT_NAME "libwebp_platform_ffi_darwin"
)

target_compile_definitions(libwebp_platform_ffi_darwin PUBLIC DART_SHARED_LIB)

if (ANDROID)
  # Support Android 15 16k page size
  target_link_options(libwebp_platform_ffi_darwin PRIVATE "-Wl,-z,max-page-size=16384")
endif()
