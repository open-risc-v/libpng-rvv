// libpng A/B 探针：编码（filter 0..4 混合 + zlib level 6）→ 解码回环，
// 哈希 PNG 字节与解码后像素。编码走 png_set_filter，覆盖所有行过滤分支。
#include <png.h>
#include <stdint.h>
#include <setjmp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define W 131    /* 非 2 的幂，逼出尾部处理 */
#define H 99

static uint64_t fnv1a(const void *p, size_t n)
{
    const uint8_t *b = p;
    uint64_t h = 1469598103934665603ULL;
    for (size_t i = 0; i < n; i++) { h ^= b[i]; h *= 1099511628211ULL; }
    return h;
}

static unsigned char *make_rgb(void)
{
    unsigned char *rgb = malloc((size_t)W * H * 3);
    if (!rgb) exit(2);
    for (int y = 0; y < H; y++)
        for (int x = 0; x < W; x++) {
            unsigned char *p = rgb + ((size_t)y * W + x) * 3;
            /* 确定性噪声：纯渐变压缩比太高，会掩盖 filter 分支的差异 */
            unsigned int n = (unsigned int)(x * 1103515245u + y * 12345u + 7u);
            n = (n >> 13) ^ (n << 3);
            p[0] = (unsigned char)(((x * 3 + y) & 0xff) ^ (n & 0x1f));
            p[1] = (unsigned char)(((y * 5 + x / 3) & 0xff) ^ ((n >> 5) & 0x1f));
            p[2] = (unsigned char)(((x ^ (y << 1)) & 0xff) ^ ((n >> 11) & 0x1f));
        }
    return rgb;
}

int main(int argc, char **argv)
{
    const char *outp = argc > 1 ? argv[1] : NULL;
    unsigned char *rgb = make_rgb();

    /* ---- 编码 ---- */
    FILE *f = fopen("/tmp/_png_ab_tmp.png", "wb");
    if (!f) return 3;
    png_structp wp = png_create_write_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    png_infop wi = png_create_info_struct(wp);
    if (!wp || !wi) return 4;
    if (setjmp(png_jmpbuf(wp))) { fprintf(stderr, "write failed\n"); return 5; }
    png_init_io(wp, f);
    png_set_compression_level(wp, 6);
    png_set_filter(wp, PNG_FILTER_TYPE_BASE, PNG_ALL_FILTERS);   /* 上/下/平均/Paeth 全覆盖 */
    png_set_IHDR(wp, wi, W, H, 8, PNG_COLOR_TYPE_RGB, PNG_INTERLACE_NONE,
                 PNG_COMPRESSION_TYPE_DEFAULT, PNG_FILTER_TYPE_DEFAULT);
    png_write_info(wp, wi);
    for (int y = 0; y < H; y++) png_write_row(wp, rgb + (size_t)y * W * 3);
    png_write_end(wp, NULL);
    png_destroy_write_struct(&wp, &wi);
    fclose(f);

    /* ---- 解码 ---- */
    f = fopen("/tmp/_png_ab_tmp.png", "rb");
    if (!f) return 6;
    png_structp rp = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
    png_infop ri = png_create_info_struct(rp);
    if (!rp || !ri) return 7;
    if (setjmp(png_jmpbuf(rp))) { fprintf(stderr, "read failed\n"); return 8; }
    png_init_io(rp, f);
    png_read_info(rp, ri);
    png_set_expand(rp);
    png_read_update_info(rp, ri);
    size_t rowbytes = png_get_rowbytes(rp, ri);
    unsigned char *dec = malloc(rowbytes * H);
    unsigned char **rows = malloc(sizeof(void *) * H);
    if (!dec || !rows) return 9;
    for (int y = 0; y < H; y++) rows[y] = dec + (size_t)y * rowbytes;
    png_read_image(rp, rows);
    png_read_end(rp, NULL);
    png_destroy_read_struct(&rp, &ri, NULL);
    fclose(f);

    /* 编码前置：读回尺寸/通道必须与原图一致，否则说明 PNG 结构被改坏 */
    if (rowbytes != (size_t)W * 3) { fprintf(stderr, "rowbytes=%zu\n", rowbytes); return 10; }
    if (memcmp(dec, rgb, (size_t)W * H * 3) != 0) { fprintf(stderr, "pixel mismatch\n"); return 11; }

    FILE *pf = fopen("/tmp/_png_ab_tmp.png", "rb");
    size_t n = 0;
    unsigned char *buf = NULL;
    if (pf) {
        fseek(pf, 0, SEEK_END);
        n = (size_t)ftell(pf);
        rewind(pf);
        buf = malloc(n);
        if (buf) fread(buf, 1, n, pf);
        fclose(pf);
    }
    printf("size=%dx%d png=%zu fnv_png=%016llx fnv_px=%016llx\n", W, H, n,
           (unsigned long long)fnv1a(buf, n), (unsigned long long)fnv1a(dec, rowbytes * H));

    if (outp) {
        FILE *o = fopen(outp, "wb");
        if (o && buf) { fwrite(buf, 1, n, o); fclose(o); }
    }
    free(rows); free(dec); free(buf); free(rgb);
    remove("/tmp/_png_ab_tmp.png");
    return 0;
}
