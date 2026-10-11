#ifndef MEDIAVISIONSDK_INCLUDE_MVS_LITERT_H_
#define MEDIAVISIONSDK_INCLUDE_MVS_LITERT_H_
#include "sdk.h"
#ifndef __cplusplus
#include <stdbool.h>
#endif
#ifdef __cplusplus
extern "C" {
#endif
/* Android standalone C ABI. Link libmvs_inference and libmvs_sdk; bundle the
 * pinned LiteRT runtime. No Java/JVM is required. Each session has one owner
 * thread: create, invoke, reset and destroy on that thread (GPU requirement).
 * Model bytes and option strings are copied during create. */
typedef struct MvsLiteRt* MvsLiteRtHandle;
typedef struct MvsFaceNative* MvsFaceNativeHandle;
typedef enum MvsLiteRtBackend {
  MVS_LITERT_AUTO = 0, MVS_LITERT_CPU = 1, MVS_LITERT_GPU = 2,
  MVS_LITERT_NNAPI = 3, MVS_LITERT_QNN_HTP = 4
} MvsLiteRtBackend;
typedef struct MvsLiteRtOptions {
  uint32_t struct_size;
  MvsLiteRtBackend backend;
  int32_t threads;
  const char* cache_dir;
  const char* model_token; /* Unique per model contents and inference contract. */
  const char* qnn_skeleton_dir;
  const char* accelerator_name;
  const char* soc_model;
  const char* soc_manufacturer;
  const char* hardware;
  float accelerator_budget_ms;
} MvsLiteRtOptions;
/* Borrowed tensor memory: valid until next invocation or session destruction.
 * Do not free. type uses LiteRT's values: float32=1, uint8=3, int8=9.
 * Input tensors can be filled directly; output tensors are read-only. */
typedef struct MvsLiteRtTensor {
  void* data;
  size_t bytes;
  int32_t type, rank, dimensions[8];
  float quantization_scale;
  int32_t quantization_zero_point;
} MvsLiteRtTensor;
MVS_API MvsLiteRtOptions mvs_litert_default_options(void);
MVS_API MvsStatus mvs_litert_create(const void* model, size_t bytes,
                                    const MvsLiteRtOptions* options,
                                    MvsLiteRtHandle* result);
MVS_API MvsStatus mvs_litert_tensor(MvsLiteRtHandle session, bool output,
                                    uint32_t index, MvsLiteRtTensor* tensor);
MVS_API uint32_t mvs_litert_tensor_count(MvsLiteRtHandle session, bool output);
MVS_API MvsStatus mvs_litert_invoke(MvsLiteRtHandle session);
MVS_API const char* mvs_litert_backend(MvsLiteRtHandle session);
MVS_API double mvs_litert_warm_ms(MvsLiteRtHandle session);
/* Number of original operators actually delegated to the selected backend.
 * NNAPI/QNN reporting zero means CPU fallback, not NPU acceleration. */
MVS_API uint32_t mvs_litert_delegated_ops(MvsLiteRtHandle session);
MVS_API const char* mvs_litert_last_error(void); /* Thread-local, borrowed. */
MVS_API void mvs_litert_destroy(MvsLiteRtHandle session);
/* RGB normalization=(byte-mean)/std; NHWC or NCHW. Output is float32 person
 * probability [0,1], optionally followed by a hair plane. Supports float32,
 * int8 and uint8 models. Caller passes tightly packed oriented RGBA pixels. */
MVS_API MvsStatus mvs_litert_segment_rgba(
    MvsLiteRtHandle session, const uint8_t* rgba, size_t rgba_bytes,
    uint32_t width, uint32_t height, float mean, float stddev, bool nchw,
    int32_t person_class, int32_t hair_class, float* mask, size_t mask_count);
/* Official stored ZIP .task containing detector128 and landmark256/478.
 * Runs native detector decoding, ROI tracking and coordinate projection.
 * Caller owns capacity>=478 output landmarks; count=0 when no face. */
MVS_API MvsStatus mvs_face_native_create(const void* task, size_t bytes,
                                         const MvsLiteRtOptions* options,
                                         MvsFaceNativeHandle* result);
MVS_API MvsStatus mvs_face_native_detect(MvsFaceNativeHandle face,
    const uint8_t* rgba, size_t rgba_bytes, uint32_t width, uint32_t height,
    MvsLandmark* points, uint32_t capacity, uint32_t* count);
MVS_API const char* mvs_face_native_backend(MvsFaceNativeHandle face);
MVS_API void mvs_face_native_reset(MvsFaceNativeHandle face);
MVS_API void mvs_face_native_destroy(MvsFaceNativeHandle face);
#ifdef __cplusplus
}
#endif
#endif
