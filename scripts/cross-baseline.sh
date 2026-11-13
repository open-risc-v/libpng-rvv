#!/usr/bin/env bash
# 交叉编译基线版本：libpng 依赖 zlib，riscv64 侧没有系统 zlib，
# 用同仓 zlib-ng-rvv 的 riscv 前缀（ZLIB_COMPAT）当 zlib 提供方。
# 前置：先在 ../zlib-ng-rvv 跑一次 ./scripts/cross-baseline.sh
set -euo pipefail
cd "$(dirname "$0")/.."

IMAGE=${IMAGE:-rvv-cross:1}
MARCH=${MARCH:-rv64gc}
OUT=build/riscv64-b
ZLIB=${ZLIB_PREFIX:-../zlib-ng-rvv/build/riscv64-b/prefix}

[ -f "${ZLIB}/include/zlib.h" ] || { echo "缺 riscv zlib 前缀：${ZLIB}（先跑 zlib-ng-rvv 的 cross-baseline）" >&2; exit 1; }

docker run --rm -v "$PWD":/work -v "$(cd "${ZLIB}" && pwd)":/zlib -w /work "${IMAGE}" bash -lc "
set -e
rm -rf ${OUT}
cmake -S baseline -B ${OUT}/bld \
  -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/work/${OUT}/prefix \
  -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_TESTS=OFF \
  -DZLIB_INCLUDE_DIR=/zlib/include -DZLIB_LIBRARY=/zlib/lib/libz.a \
  -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
  -DCMAKE_C_FLAGS='-march=${MARCH}' > /tmp/cfg.log 2>&1 || { tail -30 /tmp/cfg.log; exit 1; }
cmake --build ${OUT}/bld -j > /tmp/bld.log 2>&1 || { tail -20 /tmp/bld.log; exit 1; }
cmake --install ${OUT}/bld > /dev/null

cmake -S . -B ${OUT}/harness -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
  -DCMAKE_C_FLAGS='-march=${MARCH}' \
  -DPKG_PREFIX=/work/${OUT}/prefix \
  -DZLIB_INCLUDE_DIR=/zlib/include -DZLIB_LIBRARY=/zlib/lib/libz.a > /tmp/h.log 2>&1 || { tail -30 /tmp/h.log; exit 1; }
cmake --build ${OUT}/harness -j > /tmp/hb.log 2>&1 || { tail -20 /tmp/hb.log; exit 1; }

mkdir -p ${OUT}/out
qemu-riscv64 -L /usr/riscv64-linux-gnu ${OUT}/harness/png_harness ${OUT}/out/out.png > ${OUT}/out/hash.txt
echo \"--- riscv64（${MARCH}）---\"; cat ${OUT}/out/hash.txt
echo \"--- native 基线 ---\"; cat build/ab-data/out/01_png_roundtrip/a/hash.txt
"
