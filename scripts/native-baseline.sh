#!/usr/bin/env bash
# 本机不编译：native A/B 在 Linux 容器里跑，且与交叉侧用同一个 zlib 提供方（zlib-ng），
# 否则 PNG 码流会因 deflate 实现不同而字节不同（像素仍一致）。
# 前置：先在 ../zlib-ng-rvv 跑一次 ./scripts/native-baseline.sh。
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE=${1:-${IMAGE:-rvv-cross:2}}
ZLIB=$(cd ../zlib-ng-rvv/build/ab-a/pkg/prefix 2>/dev/null && pwd || true)
[ -f "${ZLIB}/include/zlib.h" ] || { echo "缺 native zlib 前缀：先跑 zlib-ng-rvv 的 native-baseline" >&2; exit 1; }
docker run --rm -v "$PWD":/work -v "${ZLIB}":/zlib -w /work "${IMAGE}" bash -lc '
  set -e
  rm -rf build/ab-a build/ab-b build/ab-data
  CMAKE_ARGS="-DZLIB_INCLUDE_DIR=/zlib/include -DZLIB_LIBRARY=/zlib/lib/libz.a" ./test/run_ab.sh
'
