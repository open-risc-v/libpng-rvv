#!/usr/bin/env bash
# libpng G3：RVV 行过滤（up/sub/avg/paeth）A=RVV 接线@rv64gcv，B=纯 C@同一 march。
# riscv zlib 复用 zlib-ng G3 的 off 前缀（静态库，两侧共用，唯一变量仍是 libpng 的 RVV）。
set -euo pipefail
cd "$(dirname "$0")/.."
IMAGE=${IMAGE:-rvv-cross:2}
docker run --rm -v "$PWD":/work -v "$(cd .. && pwd)":/host -w /work "${IMAGE}" \
  bash -lc 'MARCH='"${MARCH:-rv64gcv}"' bash /work/scripts/rvv-k-inner.sh'
