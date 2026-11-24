#!/usr/bin/env bash
# libpng：CMake 上游，静态库；zlib 用系统库。
# A/B 差异只由位置参数驱动：$3 = -march 值，$4 = 1 时给上游加 -DRVV_KERNELS=1
# （内核是 src/rvv/filter_rvv.h，被 pngrutil.c 直接 include，不需要额外源文件）。
set -euo pipefail
SRC=$1
OUT=$2
MARCH=${3:-rv64gc}
KERN=${4:-0}
mkdir -p "${OUT}"
OUT=$(realpath "${OUT}")
CF="-march=${MARCH}"
if [ "${KERN}" = "1" ]; then CF="${CF} -DRVV_KERNELS=1"; fi
EXTRA=(-DCMAKE_C_FLAGS="${CF}" -DCMAKE_CXX_FLAGS="${CF}")
cmake -S "${SRC}" -B "${OUT}/bld" \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${OUT}/prefix" \
  -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_TESTS=OFF "${EXTRA[@]}" >/dev/null
cmake --build "${OUT}/bld" -j"$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 4)" >/dev/null
cmake --install "${OUT}/bld" >/dev/null
echo "== 上游 libpng 构建完成：${OUT}/prefix (march=${MARCH} kern=${KERN})"
