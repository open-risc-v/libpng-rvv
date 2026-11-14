#!/usr/bin/env bash
# libpng 1.8 的 riscv/ 目录只有实现文件，没有接线（arm/intel/mips/powerpc 都有 check.h）。
# 本补丁把接线补到**副本**里，baseline 保持原样：
#   1) 新增 riscv/check.h（仿 arm/check.h）
#   2) pngtarget.h 加 include
#   3) pngpriv.h 补 7 个 row filter 的声明（riscv_init.c 要用）
#   4) riscv_init.c 去掉重复的 pngpriv.h 包含（该文件由 pngsimd.c 包含）
#   5) CMakeLists 把 riscv/filter_rvv_intrinsics.c 当独立 TU 加进库
set -euo pipefail
SRC=$1
cat > "${SRC}/riscv/check.h" <<'CHK'
/* riscv/check.h - RVV optimised filter functions (本地接线，仿 arm/check.h) */
#if defined(__riscv_vector) && PNG_RISCV_RVV_IMPLEMENTATION
#  ifndef PNG_ALIGNED_MEMORY_SUPPORTED
#     define PNG_ALIGNED_MEMORY_SUPPORTED 1
#  endif
#  define png_target_impl "riscv-rvv"
#  define PNG_TARGET_IMPLEMENTS_FILTERS
#  define png_target_init_filter_functions_impl png_init_filter_functions_rvv
#  define PNG_TARGET_CODE_IMPLEMENTATION "riscv/riscv_init.c"
#endif
CHK
python3 - "$SRC" <<'PY'
import sys, io
src = sys.argv[1]

# 2) pngtarget.h
p = src + '/pngtarget.h'; s = io.open(p, encoding='utf-8').read()
if 'riscv/check.h' not in s:
    s = s.replace('#     include "powerpc/check.h"',
                  '#     include "powerpc/check.h"\n#     include "riscv/check.h"')
    io.open(p, 'w', encoding='utf-8').write(s)

# 3) pngpriv.h 声明
p = src + '/pngpriv.h'; s = io.open(p, encoding='utf-8').read()
if 'png_read_filter_row_up_rvv' not in s:
    decls = '''
#if PNG_RISCV_RVV_IMPLEMENTATION == 1
/* 本地接线：RVV 行过滤内核（riscv/filter_rvv_intrinsics.c） */
PNG_INTERNAL_FUNCTION(void, png_read_filter_row_up_rvv, (png_row_info *ri, png_byte *row, const png_byte *prev_row), PNG_EMPTY);
PNG_INTERNAL_FUNCTION(void, png_read_filter_row_sub3_rvv, (png_row_info *, png_byte *, const png_byte *), PNG_EMPTY);
PNG_INTERNAL_FUNCTION(void, png_read_filter_row_sub4_rvv, (png_row_info *, png_byte *, const png_byte *), PNG_EMPTY);
PNG_INTERNAL_FUNCTION(void, png_read_filter_row_avg3_rvv, (png_row_info *, png_byte *, const png_byte *), PNG_EMPTY);
PNG_INTERNAL_FUNCTION(void, png_read_filter_row_avg4_rvv, (png_row_info *, png_byte *, const png_byte *), PNG_EMPTY);
PNG_INTERNAL_FUNCTION(void, png_read_filter_row_paeth3_rvv, (png_row_info *, png_byte *, const png_byte *), PNG_EMPTY);
PNG_INTERNAL_FUNCTION(void, png_read_filter_row_paeth4_rvv, (png_row_info *, png_byte *, const png_byte *), PNG_EMPTY);
#endif /* PNG_RISCV_RVV_IMPLEMENTATION */
'''
    s = s.rstrip() + '\n' + decls
    io.open(p, 'w', encoding='utf-8').write(s)

# 4) riscv_init.c：去掉重复 include
p = src + '/riscv/riscv_init.c'; s = io.open(p, encoding='utf-8').read()
s = s.replace('#include "../pngpriv.h"', '/* pngpriv.h 由 pngsimd.c 先包含，这里不能重复 */')
io.open(p, 'w', encoding='utf-8').write(s)

# 5) CMakeLists 加独立 TU
p = src + '/CMakeLists.txt'; s = io.open(p, encoding='utf-8').read()
if 'riscv/filter_rvv_intrinsics.c' not in s:
    s = s.replace('    pngsimd.c\n)', '    pngsimd.c\n    riscv/filter_rvv_intrinsics.c\n)')
    io.open(p, 'w', encoding='utf-8').write(s)
PY
