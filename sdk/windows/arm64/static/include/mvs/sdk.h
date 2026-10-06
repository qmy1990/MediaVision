#ifndef MEDIAVISIONSDK_INCLUDE_MVS_SDK_H_
#define MEDIAVISIONSDK_INCLUDE_MVS_SDK_H_
#include <stddef.h>
#include <stdint.h>
#if defined(_WIN32) && defined(MVS_SHARED)
#ifdef MVS_BUILDING
#define MVS_API __declspec(dllexport)
#else
#define MVS_API __declspec(dllimport)
#endif
#elif defined(__GNUC__)
#define MVS_API __attribute__((visibility("default")))
#else
#define MVS_API
#endif
#ifdef __cplusplus
extern "C" {
#endif

#define MVS_ABI_VERSION 9
typedef struct MvsEngine* MvsHandle;
typedef enum MvsStatus {
  MVS_OK = 0,
  MVS_INVALID_ARGUMENT = 1,
  MVS_UNSUPPORTED = 2,
  MVS_MISSING_ANALYSIS = 3,
  MVS_OUT_OF_MEMORY = 4,
  MVS_BACKEND_ERROR = 5,
  MVS_INFERENCE_ERROR = 6,
  MVS_TIMESTAMP_ERROR = 7
} MvsStatus;
typedef enum MvsBackend {
  MVS_AUTO = 0,
  MVS_CPU = 1,
  MVS_VULKAN = 2,
  MVS_METAL = 3
} MvsBackend;
typedef enum MvsPixelFormat { MVS_RGBA8 = 0, MVS_BGRA8 = 1 } MvsPixelFormat;
typedef enum MvsBackground {
  MVS_BACKGROUND_NONE = 0,
  MVS_BACKGROUND_BLUR = 1,
  MVS_BACKGROUND_REPLACE = 2,
  MVS_BACKGROUND_MASK = 3
} MvsBackground;
typedef enum MvsAccessory {
  MVS_PROP = 0,
  MVS_HEADWEAR = 1,
  MVS_JEWELRY = 2
} MvsAccessory;
/* Common sRGB lipstick presets encoded as 0xRRGGBB. Applications may also pass
 * any custom 24-bit sRGB value through MvsOptions.lipstick_color. */
typedef enum MvsLipstickColor {
  MVS_LIP_CLASSIC_RED = 0xB52A3A,
  MVS_LIP_CORAL = 0xD85A4F,
  MVS_LIP_ROSE = 0xA23A55,
  MVS_LIP_BEAN_PASTE = 0x8F4A4A,
  MVS_LIP_ORANGE_RED = 0xE14B35,
  MVS_LIP_NUDE = 0xB97868,
  MVS_LIP_PINK = 0xE889A0,
  MVS_LIP_PEACH = 0xF09278,
  MVS_LIP_GRAPEFRUIT = 0xF27676,
  MVS_LIP_SAKURA_PINK = 0xF3A6BA,
  MVS_LIP_STRAWBERRY_RED = 0xDC4664,
  MVS_LIP_WATER_GLOSS = 0xE96F86
} MvsLipstickColor;
typedef enum MvsSkinTone {
  MVS_SKIN_NATURAL_WHITE = 0,
  MVS_SKIN_COOL_WHITE = 1,
  MVS_SKIN_ROSY_WHITE = 2,
  MVS_SKIN_TAN = 3
} MvsSkinTone;
enum { MVS_ANALYZE_PERSON = 1, MVS_ANALYZE_FACE = 2 };

typedef struct MvsConfig {
  uint32_t struct_size, abi_version;
  MvsBackend backend;
  uint32_t max_width, max_height;
} MvsConfig;
/* Buffers are borrowed only for the synchronous call. Input/output may alias.
 * Rows are top-to-bottom. Rotate camera images BEFORE inference and processing.
 * YUV conversion belongs to the platform input adapter. No implicit conversion.
 */
typedef struct MvsFrame {
  const uint8_t* data;
  size_t size_bytes;
  uint32_t width, height, stride_bytes;
  MvsPixelFormat format;
  int64_t timestamp_ms;
} MvsFrame;
typedef struct MvsOutput {
  uint8_t* data;
  size_t size_bytes;
  uint32_t stride_bytes;
  MvsPixelFormat format;
} MvsOutput;
typedef struct MvsLandmark {
  float x, y, z;
} MvsLandmark;
/* SDK Face468/Face478 landmark layout. One face per stream. See
 * LANDMARK_LAYOUT.md. Mask = PERSON probability, not background; normalized
 * [0,1], tightly packed. Landmarks and mask use the oriented input coordinate
 * system. Async callers may supply a small normalized mask offset to compensate
 * prediction latency. */
typedef struct MvsAnalysis {
  const float* person_mask;
  uint32_t mask_width, mask_height;
  size_t mask_count;
  const MvsLandmark* landmarks;
  uint32_t landmark_count;
  int64_t timestamp_ms;
  /* Optional normalized motion prediction applied while reusing an asynchronous
   * mask. */
  float person_mask_offset_x, person_mask_offset_y;
} MvsAnalysis;
typedef struct MvsOptions {
  uint32_t struct_size;
  float beauty, whitening,
      sharpen; /* [0,1]; beauty uses person matte + skin probability */
  MvsBackground background;
  uint32_t blur_radius;             /* [1,32] pixels at processing resolution */
  float mask_smoothing;             /* [0,0.95], motion-aware temporal filter */
  uint32_t prop, headwear, jewelry; /* boolean; procedural demo meshes */
  /* Commercial beauty controls. Every strength is normalized to [0,1].
   * Geometric controls require 468/478 face landmarks. */
  float eye_enlarge, face_slim, blemish_removal;
  float lipstick, blush, nose_slim;
  float eyebrow_darkening;
  /* Both controls use 0.5 as neutral. Cheekbone values above 0.5 contract,
   * below 0.5 expand the paired lateral fields while excluding the eye
   * socket. Maximum outward displacement is half the inward displacement.
   * Eye spacing moves closer/wider below/above 0.5. */
  float cheekbone_reduce, eye_spacing;
  /* Whole-head scaling, including hair. 0 is identity, 1 is maximum. */
  float small_head;
  uint32_t lipstick_color; /* 0xRRGGBB, see MvsLipstickColor */
  MvsSkinTone skin_tone;   /* whitening/tone target, see MvsSkinTone */
  /* Diagnostic overlays rendered in the SDK's final image coordinates.
   * They are disabled by default and require face landmarks. */
  uint32_t debug_landmarks;
  uint32_t debug_face_mesh;
} MvsOptions;
/* Optional inference provider: callback populates borrowed views, valid until
 * process returns. The host owns model loading. Mobile SDK wrappers implement
 * this using the built-in inference adapter. Calls on one engine must not
 * re-enter the same engine. */
typedef MvsStatus (*MvsAnalyzeFn)(void* user, const MvsFrame* frame,
                                  uint32_t requirements, MvsAnalysis* result);
/* Custom effects run after built-ins, in registration order, on packed RGBA8.
 */
typedef MvsStatus (*MvsEffectFn)(void* user, uint8_t* rgba, uint32_t width,
                                 uint32_t height, const MvsAnalysis* analysis);
typedef struct MvsVertex {
  float x, y, z, r, g, b;
} MvsVertex;

MVS_API const char* mvs_version(void);
MVS_API const char* mvs_status_string(MvsStatus status);
MVS_API MvsConfig mvs_default_config(void);
MVS_API MvsOptions mvs_default_options(void);
MVS_API MvsStatus mvs_create(const MvsConfig* config, MvsHandle* output);
MVS_API void mvs_destroy(MvsHandle engine);
MVS_API MvsBackend mvs_backend(MvsHandle engine);
MVS_API MvsStatus mvs_set_options(MvsHandle engine, const MvsOptions* options);
MVS_API uint32_t mvs_analysis_requirements(MvsHandle engine);
MVS_API MvsStatus mvs_set_analyzer(MvsHandle engine, MvsAnalyzeFn analyze,
                                   void* user);
MVS_API MvsStatus mvs_process(MvsHandle engine, const MvsFrame* input,
                              MvsOutput* output);
MVS_API MvsStatus mvs_process_with_analysis(MvsHandle engine,
                                            const MvsFrame* input,
                                            const MvsAnalysis* analysis,
                                            MvsOutput* output);
/* Copies background/mesh data; caller may release input immediately afterwards.
 */
MVS_API MvsStatus mvs_set_background(MvsHandle engine, const MvsFrame* image);
MVS_API MvsStatus mvs_set_mesh(MvsHandle engine, MvsAccessory slot,
                               const MvsVertex* vertices, uint32_t vertex_count,
                               const uint32_t* indices, uint32_t index_count);
MVS_API MvsStatus mvs_add_effect(MvsHandle engine, const char* id,
                                 MvsEffectFn effect, void* user);
MVS_API MvsStatus mvs_remove_effect(MvsHandle engine, const char* id);
MVS_API void mvs_reset(
    MvsHandle engine); /* reset temporal state when changing camera/stream */
#ifdef __cplusplus
}
#endif
#endif  // MEDIAVISIONSDK_INCLUDE_MVS_SDK_H_
