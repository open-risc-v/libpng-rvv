#!/usr/bin/env bash
# libpng：CMake 上游，静态库；zlib 用系统库（macOS SDK 自带）。
set -euo pipefail
SRC=$1
OUT=$2
rm -rf "${OUT}"
cmake -S "${SRC}" -B "${OUT}/bld" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${OUT}/prefix" \
  -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_TESTS=OFF >/dev/null
cmake --build "${OUT}/bld" -j >/dev/null
cmake --install "${OUT}/bld" >/dev/null
echo "== 上游 libpng 构建完成：${OUT}/prefix"
