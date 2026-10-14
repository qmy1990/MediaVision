#ifndef MEDIAVISIONSDK_INCLUDE_MVS_DESKTOP_H_
#define MEDIAVISIONSDK_INCLUDE_MVS_DESKTOP_H_
#include "models.h"
#ifdef __cplusplus
extern "C" {
#endif
/* Optional Windows/Linux matting adapter. Load one package with models.h,
 * then share it across inference adapters. Runtime path is absolute UTF-8.
 * The adapter retains the package until destruction. No implicit downloads. */
typedef struct MvsMatting* MvsMattingHandle;
typedef enum MvsMattingProvider {
  MVS_MATTING_CPU = 0,
  MVS_MATTING_DIRECTML = 1,
  MVS_MATTING_CUDA = 2
} MvsMattingProvider;
typedef struct MvsMattingConfig {
  uint32_t struct_size;
  MvsModelsHandle models;
  const char* runtime_path;
  MvsMattingProvider provider;
  // Longest side, [256, 1024], multiple of 32; default 512.
  uint32_t inference_size;
  uint32_t cpu_threads;  // [1, 32]
  // Set to 1; prevents reuse of obsolete path-based configurations.
  uint32_t package_api_version;
} MvsMattingConfig;
MVS_API MvsStatus mvs_matting_create(const MvsMattingConfig*,
                                     MvsMattingHandle*);
/* Writes width*height calibrated soft alpha, top-to-bottom [0,1]. The caller
 * feeds it to MvsAnalysis.person_mask. Includes motion-aligned temporal
 * stabilization in uncertain boundaries. Use increasing timestamps. */
MVS_API MvsStatus mvs_matting_process(MvsMattingHandle, const MvsFrame*,
                                      float* alpha, size_t count);
MVS_API void mvs_matting_destroy(MvsMattingHandle);
MVS_API void mvs_matting_reset(MvsMattingHandle); /* new image/stream/seek */
MVS_API const char* mvs_matting_last_error(MvsMattingHandle);
#ifdef __cplusplus
}
#endif
#endif  // MEDIAVISIONSDK_INCLUDE_MVS_DESKTOP_H_
