/* libpng 行过滤器 RVV 内核。
 *
 * 覆盖 Sub / Up 两种基类型；Avg / Paeth 依赖已重建的左邻像素，无法做线性扫描，
 * 仍走上游 C 版（见 docs/rvv-notes.md 的取舍说明）。
 *
 * 语义与 pngrutil.c 的 C 版逐位等价：
 *   Up : dst[i] = (int)src[i] + (int)prev[i]                    (mod 256)
 *   Sub: dst[i] = (int)src[i] + (int)dst[i-bpp]                 (mod 256), i >= bpp
 *        前 bpp 字节原样保留
 * 全部用 i8 回绕加法，等价于 C 里 (int)a + (int)b 再 & 0xff。
 */
#ifndef PNG_RVV_FILTER_H
#define PNG_RVV_FILTER_H

#include <stddef.h>
#include "../png.h"

#ifdef __riscv_v_intrinsic
#include <riscv_vector.h>

/* Up：无数据依赖，直接整行向量加。 */
static void
png_rvv_filter_up(png_byte *row, const png_byte *prev, size_t n)
{
   size_t i = 0;

   while (i < n)
   {
      size_t vl = __riscv_vsetvl_e8m1(n - i);
      vint8m1_t a = __riscv_vle8_v_i8m1((const int8_t *)(row + i), vl);
      vint8m1_t b = __riscv_vle8_v_i8m1((const int8_t *)(prev + i), vl);

      a = __riscv_vadd_vv_i8m1(a, b, vl);
      __riscv_vse8_v_i8m1((int8_t *)(row + i), a, vl);
      i += vl;
   }
}

/* Sub：dst[i] += dst[i-bpp] 是 bpp 步长的前缀和，用 Hillis-Steele 倍增 +
 * 跨块进位（上一块末 bpp 字节）实现；LMUL=4（128 字节/块）摊薄循环与 vsetvl 开销。 */
static void
png_rvv_filter_sub(png_byte *row, unsigned int bpp, size_t n)
{
   size_t i = bpp;                     /* 前 bpp 字节不动 */

   while (i < n)
   {
      size_t vl = __riscv_vsetvl_e8m4(n - i);
      vuint8m4_t vid = __riscv_vid_v_u8m4(vl);
      vint8m4_t v = __riscv_vle8_v_i8m4((const int8_t *)(row + i), vl);
      vint8m4_t zero = __riscv_vmv_v_x_i8m4(0, vl);
      /* 进位：本块第 k 个元素（k<bpp）的前驱在 row[i-bpp+k]，已在内存里 */
      vint8m4_t vprev = __riscv_vle8_v_i8m4((const int8_t *)(row + i - bpp), vl);
      vint8m4_t vcarry = __riscv_vrgather_vv_i8m4(vprev, vid, vl);
      vbool2_t mcarry = __riscv_vmsltu_vx_u8m4_b2(vid, (uint8_t)bpp, vl);
      size_t s;

      /* 进位必须先注入：否则第一段 bpp 元素的前驱（上一块末 bpp 字节）不会
       * 通过倍增传播到后面的元素上。 */
      vcarry = __riscv_vmerge_vvm_i8m4(zero, vcarry, mcarry, vl);
      v = __riscv_vadd_vv_i8m4(v, vcarry, vl);

      /* 尾块比 bpp 还短时整块都是"进位区"，没有倍增步骤 */
      for (s = bpp; s < vl; s <<= 1)
      {
         vint8m4_t shifted = __riscv_vslideup_vx_i8m4(zero, v, s, vl);

         v = __riscv_vadd_vv_i8m4(v, shifted, vl);
      }

      __riscv_vse8_v_i8m4((int8_t *)(row + i), v, vl);
      i += vl;
   }
}

#endif /* __riscv_v_intrinsic */

#endif /* PNG_RVV_FILTER_H */
