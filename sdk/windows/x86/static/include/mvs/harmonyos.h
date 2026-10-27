#ifndef MEDIAVISIONSDK_INCLUDE_MVS_HARMONYOS_H_
#define MEDIAVISIONSDK_INCLUDE_MVS_HARMONYOS_H_
#include "models.h"
#define MVS_HARMONYOS_MIN_API 20
#ifdef __cplusplus
extern "C" {
#endif
/* HarmonyOS 6.0.0+ C ABI. No ArkTS/N-API is required by these functions. */
typedef struct MvsHarmonyModel* MvsHarmonyModelHandle;
typedef struct MvsHarmonyProcessor* MvsHarmonyHandle;
typedef enum MvsHarmonyInferenceBackend {
  /* AUTO selects NNRT without CPU fallback. CPU/GPU numeric values are kept
   * for ABI compatibility, but this strict build rejects those selections. */
  MVS_HARMONY_AUTO = 0, MVS_HARMONY_CPU = 1, MVS_HARMONY_NNRT = 2, MVS_HARMONY_GPU = 3
} MvsHarmonyInferenceBackend;
typedef struct MvsHarmonyConfig {
  uint32_t struct_size;
  MvsBackend effects_backend;
  MvsHarmonyInferenceBackend inference_backend;
  uint32_t threads;
  uint32_t enable_fp16; /* Default 1; permits NNRT reduced-precision execution. */
  float accelerator_budget_ms; /* Advisory budget; never enables CPU fallback. */
} MvsHarmonyConfig;
typedef struct MvsHarmonyTensor {
  void* data;
  size_t size_bytes;
  int32_t data_type; /* OH_AI_DataType, e.g. FLOAT32=43 */
  uint32_t rank;
  int64_t dimensions[8];
} MvsHarmonyTensor;
typedef struct MvsHarmonyStats {
  uint32_t struct_size;
  MvsBackend effects_backend;
  uint32_t landmark_count;
  uint32_t mask_width, mask_height;
  double analysis_ms, effects_ms, total_ms;
  char inference_backend[128]; /* Reports the strict registered inference backend. */
} MvsHarmonyStats;
/* Independent additive diagnostics; MvsHarmonyStats ABI stays unchanged. In
 * realtime mode analysis_ms means this frame's blocking/copy wait, while
 * analysis_work_ms is model work overlapped on the analysis thread. */
typedef struct MvsHarmonyPerformance {
  uint32_t struct_size, async_analysis;
  uint64_t analysis_sequence;
  int64_t analysis_timestamp_ms;
  double analysis_work_ms, analysis_wait_ms, analysis_age_ms, analysis_features_ms;
  double person_inference_ms, detector_inference_ms, landmark_inference_ms;
  MvsPerformance effects;
} MvsHarmonyPerformance;
typedef enum MvsHarmonyYuvColorSpace {
  MVS_HARMONY_BT601_LIMITED = 0, MVS_HARMONY_BT709_LIMITED = 1,
  MVS_HARMONY_BT601_FULL = 2, MVS_HARMONY_BT709_FULL = 3
} MvsHarmonyYuvColorSpace;
typedef struct MvsHarmonyNv21Frame {
  const uint8_t* data;
  size_t size_bytes;
  uint32_t width, height, row_stride_bytes;
  uint32_t rotation_degrees; /* clockwise: 0, 90, 180, 270 */
  uint32_t mirror; /* horizontal mirror after rotation */
  MvsHarmonyYuvColorSpace color_space;
  int64_t timestamp_ms;
} MvsHarmonyNv21Frame;
/* Explicit Y/U/V views. NV12/NV21 can share data and use pixel_stride=2;
 * planar I420 uses pixel_stride=1. Offsets and padding are in bytes. */
typedef struct MvsHarmonyYuvPlane {
  const uint8_t* data;
  size_t size_bytes, offset_bytes;
  uint32_t row_stride_bytes, pixel_stride_bytes;
} MvsHarmonyYuvPlane;
typedef struct MvsHarmonyYuv420Frame {
  uint32_t struct_size, width, height;
  MvsHarmonyYuvPlane y, u, v;
  uint32_t rotation_degrees, mirror;
  MvsHarmonyYuvColorSpace color_space;
  int64_t timestamp_ms;
} MvsHarmonyYuv420Frame;
/* Byte layout inside one native camera allocation, not image dimensions.
 * A null layout pointer selects the native driver's image layout instead.
 * Set explicit values only when the producer's actual layout is known. */
typedef struct MvsHarmonyYuv420Layout {
  uint32_t struct_size;
  uint32_t y_offset_bytes, y_row_stride_bytes, y_pixel_stride_bytes;
  uint32_t u_offset_bytes, u_row_stride_bytes, u_pixel_stride_bytes;
  uint32_t v_offset_bytes, v_row_stride_bytes, v_pixel_stride_bytes;
} MvsHarmonyYuv420Layout;
MVS_API uint32_t mvs_harmony_min_api(void);
MVS_API MvsHarmonyConfig mvs_harmony_default_config(void);
/* MindIR Lite (.ms) bytes are copied. Sessions are synchronous, owner-thread only. */
MVS_API MvsStatus mvs_harmony_model_create(const void* data, size_t bytes,
  const MvsHarmonyConfig* config, MvsHarmonyModelHandle* out);
MVS_API uint32_t mvs_harmony_model_tensor_count(MvsHarmonyModelHandle model, uint32_t output);
/* Tensor data is borrowed until the next invoke/destroy. Refresh tensor views
 * after each invoke. AUTO/NNRT never enables CPU model fallback. */
MVS_API MvsStatus mvs_harmony_model_tensor(MvsHarmonyModelHandle model,
  uint32_t output, uint32_t index, MvsHarmonyTensor* tensor);
MVS_API MvsStatus mvs_harmony_model_invoke(MvsHarmonyModelHandle model);
MVS_API const char* mvs_harmony_model_backend(MvsHarmonyModelHandle model);
MVS_API void mvs_harmony_model_destroy(MvsHarmonyModelHandle model);
/* Package IDs: 201 portrait .ms, 202 detector .ms, 203 Face478 .ms. */
MVS_API MvsStatus mvs_harmony_create(const MvsHarmonyConfig* config,
  const void* encrypted_models, size_t model_bytes, MvsHarmonyHandle* out);
MVS_API MvsStatus mvs_harmony_configure_details(MvsHarmonyHandle processor,
    const MvsPortraitDetails* details);
MVS_API MvsStatus mvs_harmony_configure(MvsHarmonyHandle processor, const MvsOptions* options);
MVS_API MvsStatus mvs_harmony_set_background_rgba(MvsHarmonyHandle processor,
  const void* rgba, size_t bytes, uint32_t width, uint32_t height, uint32_t stride_bytes);
/* Borrowed core handle for C callbacks, custom analysis, and accessory meshes.
 * Owner-thread only; do not destroy this handle separately. */
MVS_API MvsHandle mvs_harmony_effect_engine(MvsHarmonyHandle processor);
/* Oriented RGBA/BGRA frame, strictly increasing timestamp; output must not alias input. */
MVS_API MvsStatus mvs_harmony_process(MvsHarmonyHandle processor,
  const MvsFrame* frame, MvsOutput* output, MvsHarmonyStats* stats);
/* Camera NV21: Y rows followed by interleaved VU rows, both using row_stride.
 * Width/height must be even. Converts/rotates before analysis and effects.
 * Caller supplies RGBA/BGRA output with rotated dimensions and no input alias. */
MVS_API MvsStatus mvs_harmony_process_nv21(MvsHarmonyHandle processor,
  const MvsHarmonyNv21Frame* frame, MvsOutput* output, MvsHarmonyStats* stats);
/* Independent plane strides, byte offsets and pixel strides; no assumption
 * that UV starts at width*height or shares the Y row stride. Output RGBA/BGRA
 * uses output->stride_bytes and leaves row padding unchanged. Host-memory
 * input uses CPU color conversion; model inference remains strict NNRT. */
MVS_API MvsStatus mvs_harmony_process_yuv420(MvsHarmonyHandle processor,
  const MvsHarmonyYuv420Frame* frame, MvsOutput* output, MvsHarmonyStats* stats);
/* Optional app-private GPU binary cache, configured before realtime mode.
 * Cache contents include compiled pipelines, never images or analysis results.
 * Driver/shader identity and checksums invalidate incompatible/corrupt data. */
MVS_API MvsStatus mvs_harmony_set_cache_dir(MvsHarmonyHandle processor, const char* directory);
/* Precompile the exact effect/resolution combination before camera streaming. */
MVS_API MvsStatus mvs_harmony_warmup(MvsHarmonyHandle processor, uint32_t width, uint32_t height, const MvsOptions* options);
/* Optional latest-frame analysis pipeline. Owner-thread only. Synchronous
 * mode remains the default. Models and rendering overlap; max_age is 33..200
 * ms. A missing/stale result blocks for valid analysis rather than retaining
 * an old face indefinitely. Reset invalidates the entire stream generation. */
MVS_API MvsStatus mvs_harmony_set_realtime(MvsHarmonyHandle processor, uint32_t enabled, uint32_t max_age_ms);
MVS_API MvsStatus mvs_harmony_last_performance(MvsHarmonyHandle processor, MvsHarmonyPerformance* output);
/* Native camera -> Vulkan -> NativeWindow. The caller owns the CameraKit
 * session and configures its VideoOutput/PreviewOutput with input_surface_id.
 * Close only after stopping the camera producer. No full-frame ArrayBuffer or
 * PixelMap is involved. These functions are owner-thread only, API20+.
 * Camera acquire fences are waited; buffers are returned after GPU conversion.
 * Unsupported drivers return MVS_UNSUPPORTED; the app may use process_nv21.
 */
typedef struct MvsHarmonySurfaceFrame {
  uint32_t struct_size, presented, width, height, analysis_width, analysis_height;
  uint64_t sequence;
  double acquire_ms, import_ms;
  size_t analysis_readback_bytes;
  int64_t source_timestamp_ns;
  double queue_age_ms, capture_to_submit_ms; /* -1 if the producer timestamp is unavailable; excludes display scanout */
} MvsHarmonySurfaceFrame;
MVS_API MvsStatus mvs_harmony_camera_open(MvsHarmonyHandle processor,
  uint64_t preview_surface_id, uint32_t camera_width, uint32_t camera_height,
  uint64_t* input_surface_id);
/* Optional output size after camera_open, before processing. GPU center-crops
 * the rotated source to this aspect ratio and scales without stretching.
 * Pass 0,0 to retain the rotated camera dimensions. Existing ABI is unchanged. */
MVS_API MvsStatus mvs_harmony_camera_set_output_size(MvsHarmonyHandle processor,
  uint32_t output_width, uint32_t output_height);
/* Camera native allocation -> Vulkan SSBO -> GPU YUV conversion, supporting
 * explicit plane padding/offsets without copying camera bytes to the CPU.
 * Must be called after camera_open and before processing. If null, the
 * native YCbCr image importer is used. Unsupported buffer imports fail;
 * they never silently change to CPU conversion or CPU model inference. */
MVS_API MvsStatus mvs_harmony_camera_set_input_layout(MvsHarmonyHandle processor,
  const MvsHarmonyYuv420Layout* layout);
MVS_API MvsStatus mvs_harmony_camera_process(MvsHarmonyHandle processor,
  uint32_t rotation_degrees, uint32_t mirror, MvsHarmonyYuvColorSpace color_space,
  int64_t timestamp_ms, MvsHarmonySurfaceFrame* frame, MvsHarmonyStats* stats);
MVS_API MvsStatus mvs_harmony_camera_close(MvsHarmonyHandle processor);
/* Start a new camera stream without rebuilding models; resets ROI/mask/time. */
MVS_API MvsStatus mvs_harmony_reset(MvsHarmonyHandle processor);
/* Native PixelMaps are borrowed on input; output belongs to caller, release using Image Kit.
 * Output uses API-20 CreatePixelmapUsingAllocator; RGBA/BGRA SDR only.
 */
struct OH_PixelmapNative;
MVS_API MvsStatus mvs_harmony_process_pixelmap(MvsHarmonyHandle processor,
  struct OH_PixelmapNative* input, int64_t timestamp_ms,
  struct OH_PixelmapNative** output, MvsHarmonyStats* stats);
MVS_API const char* mvs_harmony_last_error(void);
MVS_API void mvs_harmony_destroy(MvsHarmonyHandle processor);
#ifdef __cplusplus
}
#endif
#endif
