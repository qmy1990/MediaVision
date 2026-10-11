#define _POSIX_C_SOURCE 200809L
#include "mvs/litert.h"
#include "mvs/inference.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include <time.h>

/* Pure C consumer: no JNI, Java VM, MediaPipe Tasks or private SDK headers. */
static void require(int ok, const char* operation) {
  if (!ok) { fprintf(stderr,"%s: %s\n",operation,mvs_litert_last_error());exit(1); }
}
static unsigned char* read_file(const char* path,size_t* size) {
  FILE* f=fopen(path,"rb");require(f!=NULL,"open input");
  require(fseek(f,0,SEEK_END)==0,"seek input");long n=ftell(f);
  require(n>0 && n<128*1024*1024,"input size");rewind(f);
  unsigned char* p=malloc((size_t)n);require(p!=NULL,"allocate input");
  require(fread(p,1,(size_t)n,f)==(size_t)n,"read input");fclose(f);*size=(size_t)n;return p;
}
static double now_ms(void) {
  struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1000.+t.tv_nsec/1e6;
}
int main(int argc,char** argv) {
  if(argc<6) {fprintf(stderr,"usage: %s models.mvsmodels input.rgba width height output.rgba [backend: 0=auto 1=CPU 2=GPU 3=NNAPI 4=QNN] [QNN-skeleton-dir]\n",argv[0]);return 2;}
  int width=atoi(argv[3]),height=atoi(argv[4]);
  require(width>0 && height>0 && width<=4096 && height<=4096,"frame dimensions");
  size_t size=0;unsigned char* rgba=read_file(argv[2],&size);
  require(size==(size_t)width*height*4,"RGBA byte count");
  MvsModelsHandle models=NULL;require(mvs_models_open(argv[1],&models)==MVS_OK,"model package");
  MvsModelView person={0};require(mvs_models_get(models,MVS_MODEL_PERSON,&person)==MVS_OK,"portrait model");
  MvsLiteRtOptions options=mvs_litert_default_options();
  options.backend=argc>6?(MvsLiteRtBackend)atoi(argv[6]):MVS_LITERT_AUTO;
  options.qnn_skeleton_dir=argc>7?argv[7]:"";
  MvsLiteRtHandle session=NULL;
  require(mvs_litert_create(person.data,person.size_bytes,&options,&session)==MVS_OK,"native model create");
  MvsLiteRtTensor input={0},output={0};
  require(mvs_litert_tensor_count(session,0)==1,"input count");
  require(mvs_litert_tensor(session,0,0,&input)==MVS_OK,"input view");
  require(mvs_litert_tensor(session,1,0,&output)==MVS_OK,"output view");
  require(output.rank==4 && output.dimensions[3]==1,"official portrait tensor contract");
  size_t count=(size_t)output.dimensions[1]*output.dimensions[2];
  float* mask=malloc(count*sizeof(float));require(mask!=NULL,"allocate mask");
  require(mvs_litert_segment_rgba(session,rgba,1,width,height,0,255,0,0,-1,mask,count)==MVS_INVALID_ARGUMENT,"reject short frame");
  double total=0;int foreground=0;
  for(int frame=0;frame<20;++frame) {
    double start=now_ms();
    require(mvs_litert_segment_rgba(session,rgba,size,width,height,0,255,0,0,-1,mask,count)==MVS_OK,"portrait inference");
    if(frame>=5)total+=now_ms()-start;
  }
  for(size_t i=0;i<count;++i) {require(isfinite(mask[i]) && mask[i]>=0 && mask[i]<=1,"finite mask probability");foreground+=mask[i]>.5f;}
  require(foreground>0 && foreground<(int)count,"foreground and background");
  printf("sdk=%s backend=%s delegated_ops=%u input=%dx%d mask=%dx%d mean_ms=%.3f foreground=%d\n",
    mvs_version(),mvs_litert_backend(session),mvs_litert_delegated_ops(session),input.dimensions[2],input.dimensions[1],output.dimensions[2],output.dimensions[1],total/15,foreground);
  mvs_litert_destroy(session);free(mask);

  MvsInferenceHandle provider=NULL;
  require(mvs_inference_create_with_options(models,&options,&provider)==MVS_OK,"native analyzer create");
  mvs_models_close(models); /* Provider copies both models; package may close. */
  MvsFrame frame={rgba,size,(uint32_t)width,(uint32_t)height,(uint32_t)width*4,MVS_RGBA8,1000};
  MvsAnalysis analysis={0};
  require(mvs_inference_analyze(provider,&frame,MVS_ANALYZE_PERSON|MVS_ANALYZE_FACE,&analysis)==MVS_OK,"portrait and face analysis");
  require(analysis.landmark_count==478 && analysis.mask_count>0,"478 landmarks and portrait mask");
  for(uint32_t i=0;i<analysis.landmark_count;++i) require(isfinite(analysis.landmarks[i].x) && isfinite(analysis.landmarks[i].y),"finite landmarks");
  require(mvs_inference_analyze(provider,&frame,1,&analysis)==MVS_TIMESTAMP_ERROR,"reject duplicate timestamp");
  MvsConfig config=mvs_default_config();config.backend=MVS_CPU;
  MvsHandle engine=NULL;require(mvs_create(&config,&engine)==MVS_OK,"effect engine");
  require(mvs_set_analyzer(engine,mvs_inference_analyze,provider)==MVS_OK,"attach native analyzer");
  MvsOptions effects=mvs_default_options();effects.beauty=.65f;effects.whitening=.35f;effects.blush=.6f;
  effects.background=MVS_BACKGROUND_BLUR;effects.mask_smoothing=0;
  require(mvs_set_options(engine,&effects)==MVS_OK,"effect parameters");
  unsigned char* pixels=malloc(size);require(pixels!=NULL,"allocate output");
  MvsOutput result={pixels,size,(uint32_t)width*4,MVS_RGBA8};frame.timestamp_ms++;
  double start=now_ms();require(mvs_process(engine,&frame,&result)==MVS_OK,"native analysis and effects");
  size_t changed=0;for(size_t i=0;i<size;++i)changed+=pixels[i]!=rgba[i];
  require(changed>size/100,"effect output changes pixels");
  printf("landmarks=478 process_ms=%.3f changed_bytes=%zu no_JVM=PASS\n",now_ms()-start,changed);
  FILE* f=fopen(argv[5],"wb");require(f!=NULL,"open output");require(fwrite(pixels,1,size,f)==size,"write output");fclose(f);
  mvs_set_analyzer(engine,NULL,NULL);mvs_destroy(engine);mvs_inference_destroy(provider);
  free(pixels);free(rgba);return 0;
}
