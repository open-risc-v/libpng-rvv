/* libpng 解码吞吐基准：读入一张 PNG（行过滤走 read_filter 表），逐行解码。
   A（RVV 行过滤）/ B（纯 C）同 -march，真机交替跑。
   用法：bench_png <file.png> [reps] */
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#include <png.h>

static double now_ns(void)
{
	struct timespec ts;
	clock_gettime(CLOCK_MONOTONIC, &ts);
	return (double)ts.tv_sec * 1e9 + (double)ts.tv_nsec;
}

int main(int argc, char **argv)
{
	if (argc < 2) { fprintf(stderr, "usage: %s <file.png> [reps]\n", argv[0]); return 2; }
	int reps = argc > 2 ? atoi(argv[2]) : 5;
	double best = 1e30;
	int w = 0, h = 0;

	for (int r = 0; r < reps; r++) {
		FILE *f = fopen(argv[1], "rb");
		if (!f) { fprintf(stderr, "cannot open %s\n", argv[1]); return 2; }
		png_structp rp = png_create_read_struct(PNG_LIBPNG_VER_STRING, NULL, NULL, NULL);
		png_infop ri = png_create_info_struct(rp);
		png_init_io(rp, f);
		png_read_info(rp, ri);
		w = (int)png_get_image_width(rp, ri);
		h = (int)png_get_image_height(rp, ri);
		unsigned char *row = malloc((size_t)w * 4 + 8);
		double t0 = now_ns();
		png_set_expand(rp);
		png_read_update_info(rp, ri);
		for (int y = 0; y < h; y++) png_read_row(rp, row, NULL);
		double dt = now_ns() - t0;
		if (dt < best) best = dt;
		free(row);
		fclose(f);
		png_destroy_read_struct(&rp, &ri, NULL);
	}
	printf("png %dx%d decode_ms=%.2f\n", w, h, best / 1e6);
	return 0;
}
