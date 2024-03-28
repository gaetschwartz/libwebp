cmake_minimum_required(VERSION 3.10)

# Project-level configuration.
set(PROJECT_NAME "libwebp_flutter_libs")
project(${PROJECT_NAME} LANGUAGES C)
option(BUILD_SHARED_LIBS "Build using shared libraries" ON)

include(FetchContent)

# Fetch the libwebp source code.
FetchContent_Declare(
  libwebp_git
  GIT_REPOSITORY https://chromium.googlesource.com/webm/libwebp
  GIT_TAG v1.3.2
)

FetchContent_GetProperties(libwebp)
if(NOT libwebp_git_POPULATED)
  FetchContent_Populate(libwebp_git)
endif()

# disable building all executables
set(WEBP_BUILD_ANIM_UTILS OFF)
set(WEBP_BUILD_CWEBP OFF)
set(WEBP_BUILD_DWEBP OFF)
set(WEBP_BUILD_EXTRAS OFF)
set(WEBP_BUILD_GIF2WEBP OFF)
set(WEBP_BUILD_IMG2WEBP OFF)

add_subdirectory(${libwebp_git_SOURCE_DIR} ${libwebp_git_BINARY_DIR})

add_library(webp::webp ALIAS webp)
add_library(webp::libwebpmux ALIAS libwebpmux)
add_library(webp::webpdemux ALIAS webpdemux)

set(WEBP_LIBRARY "webp_flutter_libs")
add_library(${WEBP_LIBRARY} SHARED main.c)
target_link_libraries(${WEBP_LIBRARY} PUBLIC webp::webp)
target_link_libraries(${WEBP_LIBRARY} PUBLIC webp::libwebpmux)
target_link_libraries(${WEBP_LIBRARY} PUBLIC webp::webpdemux)

target_compile_definitions(${WEBP_LIBRARY} PUBLIC DART_SHARED_LIB)

