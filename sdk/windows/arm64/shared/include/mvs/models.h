#ifndef MEDIAVISIONSDK_INCLUDE_MVS_MODELS_H_
#define MEDIAVISIONSDK_INCLUDE_MVS_MODELS_H_
#include "sdk.h"
#ifdef __cplusplus
extern "C" {
#endif
/* One encrypted package per platform. Opening decrypts and validates once.
 * Views are read-only and valid until the last reference is closed. The caller
 * must keep a reference while using a view. Model IDs may be extended freely.
 */
typedef struct MvsModels* MvsModelsHandle;
enum { MVS_MODEL_FACE = 1, MVS_MODEL_PERSON = 2, MVS_MODEL_MATTING = 3 };
typedef struct MvsModelView {
  const uint8_t* data;
  size_t size_bytes;
  uint32_t id;
  char name[32];
} MvsModelView;
/* Paths are UTF-8. Invalid/unsupported/corrupt packages return
 * INVALID_ARGUMENT. open_memory copies the package; the encrypted input can
 * then be released. */
MVS_API MvsStatus mvs_models_open(const char* package_path,
                                  MvsModelsHandle* result);
MVS_API MvsStatus mvs_models_open_memory(const void* data, size_t bytes,
                                         MvsModelsHandle* result);
MVS_API uint32_t mvs_models_count(MvsModelsHandle models);
MVS_API MvsStatus mvs_models_get(MvsModelsHandle models, uint32_t id,
                                 MvsModelView* result);
MVS_API MvsStatus mvs_models_at(MvsModelsHandle models, uint32_t index,
                                MvsModelView* result);
MVS_API void mvs_models_retain(MvsModelsHandle models);
MVS_API void mvs_models_close(MvsModelsHandle models);
#ifdef __cplusplus
}
#endif
#endif  // MEDIAVISIONSDK_INCLUDE_MVS_MODELS_H_
