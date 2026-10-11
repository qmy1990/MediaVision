#ifndef MEDIAVISIONSDK_INCLUDE_MVS_INFERENCE_H_
#define MEDIAVISIONSDK_INCLUDE_MVS_INFERENCE_H_
#include "models.h"
#ifdef __cplusplus
extern "C" {
#endif
/* Optional native inference adapter, linked separately from the effect library.
 * Create from one package containing FACE and PERSON. Single-stream ownership.
 * Detach from the engine before destroying the adapter. */
typedef struct MvsInference* MvsInferenceHandle;
MVS_API MvsStatus mvs_inference_create(MvsModelsHandle models,
                                       MvsInferenceHandle* result);
MVS_API MvsStatus mvs_inference_analyze(void* provider, const MvsFrame* frame,
                                        uint32_t requirements,
                                        MvsAnalysis* result);
MVS_API void mvs_inference_destroy(MvsInferenceHandle provider);
#ifdef __cplusplus
}
#endif
#endif  // MEDIAVISIONSDK_INCLUDE_MVS_INFERENCE_H_
