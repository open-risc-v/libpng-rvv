#!/usr/bin/env bash
# 真实包用例：libpng 编码（全过滤类型 + zlib 6）→ 解码回环，比较 PNG 字节与像素哈希。
set -euo pipefail
: "${STAGE:=run}" "${SIDE:=A}" "${BIN:=build/native}" "${DATA:=build/ab-data}" "${OUT:=build/ab-data/out}"
mkdir -p "$DATA" "$OUT"
case "$STAGE" in
  gen) ;;
  run)
    [ -x "$BIN/png_harness" ] || { echo "缺少 $BIN/png_harness" >&2; exit 1; }
    "$BIN/png_harness" "$OUT/out.png" > "$OUT/hash.txt"
    size=$(wc -c < "$OUT/out.png" | tr -d ' ')
    [ "$size" -gt 1024 ] || { echo "PNG 过小：$size" >&2; exit 1; }
    ;;
  *) echo "未知 STAGE=$STAGE" >&2; exit 2 ;;
esac
