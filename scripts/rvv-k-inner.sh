#!/usr/bin/env bash
# 容器内执行：libpng RVV 行过滤 A/B
set -euo pipefail
MARCH=${MARCH:-rv64gcv}
OUT=build/rvv-k
ZLIB=/host/zlib-ng-rvv/build/rvv-k/off/prefix
[ -f ${ZLIB}/lib/libz.a ] || { echo "缺 riscv zlib（${ZLIB}）"; exit 1; }

rm -rf ${OUT}; mkdir -p ${OUT}
mkdir -p ${OUT}/on && cp -R baseline ${OUT}/on/src && rm -rf ${OUT}/on/src/.git
bash scripts/rvv-wiring.patch.sh ${OUT}/on/src
mkdir -p ${OUT}/off && cp -R baseline ${OUT}/off/src && rm -rf ${OUT}/off/src/.git

for side in on off; do
  opt=''
  [ "$side" = on ] && opt='-DPNG_RISCV_RVV_IMPLEMENTATION=1'
  cmake -S ${OUT}/${side}/src -B ${OUT}/${side}/bld -G Ninja \
    -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/work/${OUT}/${side}/prefix \
    -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_TESTS=OFF \
    -DZLIB_LIBRARY=${ZLIB}/lib/libz.a -DZLIB_INCLUDE_DIR=${ZLIB}/include \
    -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
    -DCMAKE_C_FLAGS="-march=${MARCH} ${opt}" > ${OUT}/${side}-cfg.log 2>&1 \
      || { tail -20 ${OUT}/${side}-cfg.log; exit 1; }
  cmake --build ${OUT}/${side}/bld -j > ${OUT}/${side}-build.log 2>&1 \
      || { tail -20 ${OUT}/${side}-build.log; exit 1; }
  cmake --install ${OUT}/${side}/bld > /dev/null

  cmake -S . -B ${OUT}/${side}/harness -DCMAKE_BUILD_TYPE=Release \
    -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
    -DCMAKE_C_FLAGS="-march=${MARCH}" -DPKG_PREFIX=/work/${OUT}/${side}/prefix \
    -DZLIB_LIBRARY=${ZLIB}/lib/libz.a -DZLIB_INCLUDE_DIR=${ZLIB}/include > ${OUT}/${side}-hkcfg.log 2>&1 \
      || { tail -15 ${OUT}/${side}-hkcfg.log; exit 1; }
  cmake --build ${OUT}/${side}/harness -j > ${OUT}/${side}-harness.log 2>&1 \
      || { tail -15 ${OUT}/${side}-harness.log; exit 1; }
  qemu-riscv64 -L /usr/riscv64-linux-gnu ${OUT}/${side}/harness/png_harness ${OUT}/${side}/out.png > ${OUT}/${side}/hash.txt
  riscv64-linux-gnu-gcc -O3 -march=${MARCH} -static -I ${OUT}/${side}/prefix/include -I ${ZLIB}/include \
    test/bench_png.c ${OUT}/${side}/prefix/lib/libpng.a ${ZLIB}/lib/libz.a -lm -o ${OUT}/${side}/bench 2>/dev/null || true
done

echo '--- A：RVV 行过滤 ---'; cat ${OUT}/on/hash.txt
echo '--- B：纯 C ---'; cat ${OUT}/off/hash.txt
cmp -s ${OUT}/on/hash.txt ${OUT}/off/hash.txt && echo '== 功能一致' || echo '== 功能不一致'
