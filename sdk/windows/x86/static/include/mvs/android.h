#ifndef MEDIAVISIONSDK_INCLUDE_MVS_ANDROID_H_
#define MEDIAVISIONSDK_INCLUDE_MVS_ANDROID_H_
#include <stdbool.h>

#include "sdk.h"
#ifdef __cplusplus
extern "C" {
#endif
struct AHardwareBuffer;
struct ANativeWindow;
/* Optional platform transport; the common SDK options/analysis remain
 * unchanged. The caller must wait for the camera acquire fence before this
 * call. The input Image and HardwareBuffer must remain acquired until the call
 * returns. Rendering is synchronous with GPU completion, presentation is queued
 * by Vulkan WSI. analysis_rgba is optional: only the requested small oriented
 * RGB image is read back for inference. No full-resolution camera pixels are
 * CPU mapped/copied. MVS_UNSUPPORTED means the device cannot use this
 * transport; choose the packed frame API before connecting a CPU producer to
 * the same Surface.
 */
MVS_API MvsStatus
mvs_android_render(MvsHandle engine, struct AHardwareBuffer* input,
                   struct ANativeWindow* surface, uint32_t rotation_degrees,
                   int64_t timestamp_ms, const MvsAnalysis* analysis,
                   uint8_t* analysis_rgba, size_t analysis_capacity,
                   uint32_t analysis_width, uint32_t analysis_height);
/* Same zero-copy transport with an optional horizontal display transform.
 * Mirroring is applied before both the cached image and model resize, keeping
 * all analysis coordinates in exactly the same space as the shown frame. */
MVS_API MvsStatus mvs_android_render_transform(
    MvsHandle engine, struct AHardwareBuffer* input,
    struct ANativeWindow* surface, uint32_t rotation_degrees, bool mirror_x,
    int64_t timestamp_ms, const MvsAnalysis* analysis, uint8_t* analysis_rgba,
    size_t analysis_capacity, uint32_t analysis_width,
    uint32_t analysis_height);
/* Detach before Surface destruction. Keeps the engine options and models. */
MVS_API void mvs_android_detach_surface(MvsHandle engine);
MVS_API const char* mvs_android_render_path(MvsHandle engine);
/* Supplies a compact face-local parsing atlas. RGBA channels are lip, oral
 * cavity, eyebrows and skin probabilities. The camera backend copies the data;
 * the caller may immediately reuse its buffer. */
MVS_API MvsStatus mvs_android_set_face_parts(MvsHandle engine,
                                             const uint8_t* rgba,
                                             uint32_t width, uint32_t height,
                                             int64_t timestamp_ms);
/* Timestamp-paired async pipeline: prepare retains an owned GPU image (not the
 * camera ImageReader slot). Present only accepts the exact cached timestamp.
 * Keep at most one inference in flight; three cache slots bound GPU memory.
 * The initial frame is presented only after all requested analysis is complete.
 */
MVS_API MvsStatus mvs_android_prepare(MvsHandle engine,
                                      struct AHardwareBuffer* input,
                                      struct ANativeWindow* surface,
                                      uint32_t rotation_degrees,
                                      int64_t timestamp_ms,
                                      uint8_t* analysis_rgba, size_t capacity,
                                      uint32_t width, uint32_t height);
MVS_API MvsStatus mvs_android_prepare_transform(
    MvsHandle engine, struct AHardwareBuffer* input,
    struct ANativeWindow* surface, uint32_t rotation_degrees, bool mirror_x,
    int64_t timestamp_ms, uint8_t* analysis_rgba, size_t capacity,
    uint32_t width, uint32_t height);
MVS_API MvsStatus mvs_android_present(MvsHandle engine,
                                      struct ANativeWindow* surface,
                                      int64_t cached_timestamp_ms,
                                      const MvsAnalysis* analysis);
/* Atomically present one completed cached frame while importing/caching the
 * current camera frame and producing its model input in the same GPU submit. */
MVS_API MvsStatus mvs_android_present_and_prepare(
    MvsHandle engine, struct AHardwareBuffer* input,
    struct ANativeWindow* surface, uint32_t rotation_degrees,
    int64_t input_timestamp_ms, int64_t cached_timestamp_ms,
    const MvsAnalysis* analysis, uint8_t* analysis_rgba, size_t capacity,
    uint32_t width, uint32_t height);
MVS_API MvsStatus mvs_android_present_and_prepare_transform(
    MvsHandle engine, struct AHardwareBuffer* input,
    struct ANativeWindow* surface, uint32_t rotation_degrees, bool mirror_x,
    int64_t input_timestamp_ms, int64_t cached_timestamp_ms,
    const MvsAnalysis* analysis, uint8_t* analysis_rgba, size_t capacity,
    uint32_t width, uint32_t height);
#ifdef __cplusplus
}
#endif
#endif  // MEDIAVISIONSDK_INCLUDE_MVS_ANDROID_H_
