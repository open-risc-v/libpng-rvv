#include <stdio.h>
#include <stdlib.h>
#include <png.h>
int main(int argc, char **argv){
  int W=1024,H=768; unsigned char *row=malloc(W*3);
  FILE *f=fopen(argv[1],"wb");
  png_structp p=png_create_write_struct(PNG_LIBPNG_VER_STRING,NULL,NULL,NULL);
  png_infop i=png_create_info_struct(p);
  png_init_io(p,f);
  png_set_compression_level(p,6);
  png_set_IHDR(p,i,W,H,8,PNG_COLOR_TYPE_RGB,PNG_INTERLACE_NONE,PNG_COMPRESSION_TYPE_DEFAULT,PNG_FILTER_TYPE_DEFAULT);
  png_set_filter(p,PNG_FILTER_TYPE_BASE,PNG_ALL_FILTERS);
  png_write_info(p,i);
  for(int y=0;y<H;y++){for(int x=0;x<W;x++){unsigned v=(unsigned)((y*W+x)*2654435761u);row[x*3]=(v>>24)&0xff;row[x*3+1]=(v>>16)&0xff;row[x*3+2]=(v>>8)&0xff;} png_write_row(p,row);}
  png_write_end(p,i); png_destroy_write_struct(&p,&i); fclose(f); return 0;
}
