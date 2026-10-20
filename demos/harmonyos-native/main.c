#define _POSIX_C_SOURCE 200809L
#include "mvs/harmonyos.h"
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
static unsigned char* load(const char* path,size_t* n){
 FILE* f=fopen(path,"rb");if(!f)return NULL;fseek(f,0,SEEK_END);long size=ftell(f);rewind(f);
 if(size<=0 || size>128*1024*1024){fclose(f);return NULL;}unsigned char* p=malloc(size);
 if(!p || fread(p,1,size,f)!=(size_t)size){free(p);fclose(f);return NULL;}fclose(f);*n=size;return p;
}
static void check(MvsStatus status,const char* operation){if(status!=MVS_OK){fprintf(stderr,"%s: %s (%d)\n",operation,mvs_harmony_last_error(),status);exit(1);}}
int main(int argc,char** argv){
 if(argc<6){fprintf(stderr,"usage: %s models.mvsmodels input.rgba width height output.rgba\n",argv[0]);return 2;}
 int w=atoi(argv[3]),h=atoi(argv[4]);if(w<1 || w>4096 || h<1 || h>4096)return 2;
 size_t model_size=0,image_size=0;unsigned char* models=load(argv[1],&model_size),*input=load(argv[2],&image_size);
 if(!models || !input || image_size!=(size_t)w*h*4){free(models);free(input);return 2;}
 MvsHarmonyConfig config=mvs_harmony_default_config();config.effects_backend=MVS_CPU;
 MvsHarmonyHandle sdk=NULL;check(mvs_harmony_create(&config,models,model_size,&sdk),"create");free(models);
 MvsOptions options=mvs_default_options();options.beauty=.55f;options.whitening=.25f;options.blush=.35f;
 options.blush_mode=MVS_BLUSH_CHEEKS_AND_NOSE;options.background=MVS_BACKGROUND_BLUR;options.blur_radius=8;
 check(mvs_harmony_configure(sdk,&options),"configure");
 unsigned char* pixels=malloc(image_size);if(!pixels)return 1;
 MvsFrame frame={input,image_size,(uint32_t)w,(uint32_t)h,(uint32_t)w*4,MVS_RGBA8,1};
 MvsOutput output={pixels,image_size,(uint32_t)w*4,MVS_RGBA8};MvsHarmonyStats stats={0};stats.struct_size=sizeof(stats);
 check(mvs_harmony_process(sdk,&frame,&output,&stats),"process");
 printf("SDK=%s min_api=%u face_points=%u mask=%ux%u total_ms=%.3f backend=%s\n",mvs_version(),mvs_harmony_min_api(),stats.landmark_count,stats.mask_width,stats.mask_height,stats.total_ms,stats.inference_backend);
 FILE* file=fopen(argv[5],"wb");if(!file || fwrite(pixels,1,image_size,file)!=image_size)return 1;fclose(file);
 if(mvs_harmony_process(sdk,&frame,&output,&stats)!=MVS_TIMESTAMP_ERROR)return 1;
 mvs_harmony_destroy(sdk);free(input);free(pixels);return 0;
}
