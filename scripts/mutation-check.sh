#!/usr/bin/env bash
# 变异测试：故意破坏 UP 过滤内核，确认 A 侧哈希变化 —— 证明 RVV 内核真的被调用，
# 而不是"打开了宏但仍走 C 路径"（那样 A/B 一致也毫无意义）。
set -euo pipefail
OUT=build/rvv-k/mut
ZLIB=/host/zlib-ng-rvv/build/rvv-k/off/prefix
rm -rf ${OUT}; mkdir -p ${OUT}
cp -R baseline ${OUT}/src; rm -rf ${OUT}/src/.git
bash scripts/rvv-wiring.patch.sh ${OUT}/src
python3 - ${OUT}/src/riscv/filter_rvv_intrinsics.c <<'PY'
import sys, io
p = sys.argv[1]; s = io.open(p, encoding='utf-8').read()
s = s.replace('__riscv_vse8_v_u8m8(row, row_vals, vl);',
              '__riscv_vse8_v_u8m8(row, row_vals, vl);\n      row[0] ^= 1; /* MUTATION */', 1)
io.open(p, 'w', encoding='utf-8').write(s)
PY
cmake -S ${OUT}/src -B ${OUT}/bld -G Ninja -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/work/${OUT}/prefix \
  -DPNG_SHARED=OFF -DPNG_STATIC=ON -DPNG_TESTS=OFF -DZLIB_LIBRARY=${ZLIB}/lib/libz.a -DZLIB_INCLUDE_DIR=${ZLIB}/include \
  -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
  -DCMAKE_C_FLAGS="-march=rv64gcv -DPNG_RISCV_RVV_IMPLEMENTATION=1" > ${OUT}/cfg.log 2>&1 || { tail -15 ${OUT}/cfg.log; exit 1; }
cmake --build ${OUT}/bld -j > ${OUT}/bld.log 2>&1 || { tail -15 ${OUT}/bld.log; exit 1; }
cmake --install ${OUT}/bld > /dev/null
cmake -S . -B ${OUT}/harness -DCMAKE_BUILD_TYPE=Release -DCMAKE_TOOLCHAIN_FILE=/work/cmake/toolchain-riscv64-linux.cmake \
  -DCMAKE_C_FLAGS=-march=rv64gcv -DPKG_PREFIX=/work/${OUT}/prefix \
  -DZLIB_LIBRARY=${ZLIB}/lib/libz.a -DZLIB_INCLUDE_DIR=${ZLIB}/include > /dev/null 2>&1
cmake --build ${OUT}/harness -j > /dev/null 2>&1
qemu-riscv64 -L /usr/riscv64-linux-gnu ${OUT}/harness/png_harness ${OUT}/out.png > ${OUT}/hash.txt
echo "mutated: $(cat ${OUT}/hash.txt)"
echo "normal : $(cat build/rvv-k/on/hash.txt)"
if cmp -s ${OUT}/hash.txt build/rvv-k/on/hash.txt; then
  echo "== 哈希相同：RVV 内核没有被调用，A/B 对比无效"; exit 1
else
  echo "== 哈希不同：RVV 内核确实在跑"
fi
