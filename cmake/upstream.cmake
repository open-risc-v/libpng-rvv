# 上游接入：libpng（CMake 原生）→ <build>/pkg/prefix，探针链接 libpng 静态库 + 系统 zlib。

set(PKG_ROOT "${CMAKE_BINARY_DIR}/pkg")
if(NOT DEFINED PKG_PREFIX)
  set(PKG_PREFIX "${PKG_ROOT}/prefix")
  add_custom_target(pkg ALL
  COMMAND "${CMAKE_CURRENT_SOURCE_DIR}/cmake/pkg-build.sh" "${SRC_DIR}" "${PKG_ROOT}"
  COMMENT "构建上游 libpng（${SRC_DIR}）"
  VERBATIM)
  set(HAVE_PKG_TARGET TRUE)
endif()

add_executable(png_harness test/pkg_png.c)
if(HAVE_PKG_TARGET)
  add_dependencies(png_harness pkg)
endif()
target_include_directories(png_harness PRIVATE "${PKG_PREFIX}/include")
target_link_directories(png_harness PRIVATE "${PKG_PREFIX}/lib")
find_package(ZLIB REQUIRED)
target_link_libraries(png_harness PRIVATE png18 ZLIB::ZLIB m)
target_compile_options(png_harness PRIVATE ${RVV_FLAGS})

add_test(NAME png_harness COMMAND png_harness)
