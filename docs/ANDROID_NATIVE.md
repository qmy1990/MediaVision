# Android C/C++ 原生推理 · 0.4.3

Android 的 LiteRT 会话、Delegate 选择、Tensor、分割预处理/后处理、人脸检测、ROI 跟踪及坐标投影均在 `libmvs_inference.so` 中执行。Java 封装通过 JNI 提交模型、输入和参数，管理 Android 生命周期、异步缓冲及显示；生产代码不再使用 Java LiteRT Interpreter 或 MediaPipe Tasks 执行模型。

第三方可以选择现有 `VisionSdk` 接口，也可以直接使用 C 头文件和共享库。后者无需 Java、JNI 或 JVM；相机采集、YUV 转换、方向处理和显示仍由宿主应用负责。

## 库与头文件

| 文件 | 作用 | 必需条件 |
|---|---|---|
| `include/mvs/sdk.h`、`models.h` | 效果接口、加密模型包加载 | SDK 集成 |
| `include/mvs/litert.h`、`inference.h` | Tensor / 分割 / Face478 / 分析适配器 | Android 原生推理 |
| `sdk/android/camera-native/<ABI>/libmvs_sdk.so` | 效果及模型包核心 | 效果处理、SDK 模型包 |
| 同目录 `libmvs_inference.so` | 原生模型推理 | 原生推理 |
| 同目录 `libmvs_android.so` | JNI 与 Android Surface/相机接口 | 使用 Java 或原生相机接口时 |
| `sdk/android/native-runtime/<ABI>/libtensorflowlite_jni.so` | LiteRT 1.4.2 原生运行库；包含公开 C API | 原生推理；文件名含 JNI，但 C 调用不启动 JVM |
| 同目录 `libtensorflowlite_gpu_jni.so` | LiteRT 1.4.2 GPU Delegate | GPU / AUTO |
| 同目录 `libc++_shared.so` | NDK 27 C++ 运行库 | 原生推理 |
| arm64 同目录 `libQnnTFLiteDelegate.so`、`libQnnHtp*.so`、`libQnnSystem.so` | QNN 2.45 HTP 运行库、Stub 和 Skeleton | 可选 Qualcomm HTP |

Android API 26+；四种 ABI 为 arm64-v8a、armeabi-v7a、x86、x86_64。QNN 包仅提供 arm64；其他 ABI 使用 GPU/NNAPI/CPU。效果 core 可单独使用，宿主提供 `MvsAnalysis` 时不需要 LiteRT 运行库。不能混合不同 ABI、不同 LiteRT/QNN 版本或重复放入冲突的 C++ 运行库。

使用 Maven 的 Android APP 无需手工复制上述第三方 `.so`，POM 会解析运行库。纯 NDK 工程将对应 ABI 的库部署到 `jniLibs/<ABI>` 或本机加载目录，并链接 `mvs_inference`、`mvs_sdk`。共享库的依赖必须在 Android linker 可访问的同一命名空间中。

## 方案一：直接推理自己的 TFLite 模型

```c
#include <string.h>
#include "mvs/litert.h"

MvsLiteRtOptions options = mvs_litert_default_options();
options.backend = MVS_LITERT_AUTO;
options.threads = 2;
options.cache_dir = app_code_cache_path;
options.model_token = "portrait-sha256-and-contract-v1";
MvsLiteRtHandle model = NULL;
MvsStatus status = mvs_litert_create(model_bytes, model_size, &options, &model);
if (status != MVS_OK) { /* inspect mvs_litert_last_error() */ }

MvsLiteRtTensor input = {0};
status = mvs_litert_tensor(model, false, 0, &input);
/* Check input.type/rank/dimensions/bytes against your model's contract. */
if (status == MVS_OK && input.bytes == normalized_input_size)
  memcpy(input.data, normalized_input, input.bytes);
status = mvs_litert_invoke(model);
MvsLiteRtTensor output = {0};
if (status == MVS_OK) status = mvs_litert_tensor(model, true, 0, &output);
/* Consume/copy output before the next invocation or destruction. */
mvs_litert_destroy(model);
```

模型数据和配置字符串在创建时复制，创建成功后可释放原始模型。输入输出 Tensor 是借用内存，不能释放；输入可写、输出只读，每次调用后重新获取输出视图。类型采用 LiteRT 数值，如 float32=1、uint8=3、int8=9。量化模型需按 `scale` / `zero_point` 编码和解码；通用 `invoke` 不会替宿主归一化输入。

此 API 使用模型自带的静态输入形状，不提供 resize API。多输入、多输出可通过 count 和索引访问。算子支持范围取决于配套 LiteRT 和 Delegate；任意自定义算子或任意模型不能保证运行。泛用 Tensor API 不自动把任意输出解释成 SDK 人物 Mask 或 478 点布局。

`mvs_litert_segment_rgba` 提供 float32/int8/uint8 分割模型的便利输入路径：紧密 RGBA、宽高、`(RGB-mean)/stddev`、NHWC/NCHW、人物类别和可选头发类别。它按最近邻缩放；单通道输出视为人物概率，多通道输出视为 logits 并做 softmax。传入已输出 softmax 概率的多类别模型时，请使用通用 Tensor API 自行处理，避免重复 softmax。`person_class=-1` 表示多类别模型中的 `1-background(0)`；头发开启时输出紧随人物平面。查验模型实际合约后再调用。

## 方案二：SDK 模型包直接连接效果引擎

```c
#include "mvs/inference.h"

MvsModelsHandle models = NULL;
MvsInferenceHandle analyzer = NULL;
MvsHandle engine = NULL;
MvsStatus status = mvs_models_open(package_path, &models);
MvsLiteRtOptions inference = mvs_litert_default_options();
if (status == MVS_OK)
  status = mvs_inference_create_with_options(models, &inference, &analyzer);
mvs_models_close(models); /* analyzer owns copies after successful creation */
MvsConfig config = mvs_default_config();
if (status == MVS_OK) status = mvs_create(&config, &engine);
if (status == MVS_OK) status = mvs_set_analyzer(engine, mvs_inference_analyze, analyzer);
MvsOptions effects = mvs_default_options();
effects.beauty = .55f;
effects.blush = .35f;
effects.background = MVS_BACKGROUND_BLUR;
if (status == MVS_OK) status = mvs_set_options(engine, &effects);
/* Frame RGBA8/BGRA8, stride and byte counts must match allocated buffers. */
if (status == MVS_OK) status = mvs_process(engine, &frame, &output);
mvs_set_analyzer(engine, NULL, NULL);
mvs_destroy(engine);
mvs_inference_destroy(analyzer);
```

适配器支持发布包中的 PERSON 单通道模型和官方 FACE `.task`（stored ZIP 内含 detector128、landmark256/478）。不是任意模型自动识别器；自己的模型用方案一，再实现 `MvsAnalyzeFn` 或传 `mvs_process_with_analysis`。`mvs_face_native_create` 可直接接受官方 `.task` 字节，并在调用方分配的 478 点数组中返回归一化坐标。无脸时 count=0，不复用上一帧人脸。

默认检测器使用 CPU/XNNPACK；478 点模型自动尝试 GPU，较慢或失败时使用 CPU。分割会探测可用 QNN HTP/NNAPI/GPU/CPU；NNAPI 回退到 CPU 且满足实时预算时保留此路径，减少与人脸 GPU 和 Vulkan 渲染争抢。AUTO 依据当前设备实测选择，不能仅凭芯片名称保证 NPU。iOS/桌面系统保留原有适配器，此 Android `.so` 不能跨系统使用。

## 线程、内存与时间戳

- 在同一个线程创建、推理、reset 和 destroy 原生会话，尤其 GPU 需遵守此规则；不要跨线程复用或并发调用。不同会话可以由不同工作线程持有。
- 会话是同步接口。异步应用可在工作线程上调用；输入和输出缓冲必须保留至调用返回。
- `MvsAnalysis` 的 Mask/landmarks 借用适配器内部内存，下一次 analyze 或销毁后失效。要排队显示，先复制结果或保证消费完成。
- 将相机帧先旋转为处理方向；分析与效果帧必须使用同一方向。镜像显示不能单独镜像分析点。
- `mvs_inference_analyze` 的 timestamp_ms 必须严格递增；新流创建新适配器。销毁前先从效果引擎移除回调。
- 错误时检查 `MvsStatus`。`mvs_litert_last_error()` 是当前线程的借用字符串；参数校验失败可能只有状态码。成功调用后不要依赖旧错误内容。

## 加速诊断和 QNN

`mvs_litert_backend` 返回实际选用路径；`NNAPI/CPU-XNNPACK` 表示没有算子委派给 NNAPI。`mvs_litert_delegated_ops` 报告委派到所选 Delegate 的原始算子数；CPU/XNNPACK 的非零数值仍是 CPU，部分委派也不代表整图在 NPU。`warm_ms` 只计热身后的模型调用，不能当成相机 FPS 或完整处理延迟。

纯 NDK 的 QNN Skeleton 需有实际可读文件。将 arm64 的 `libQnnHtpV*Skel.so` 部署到应用可访问目录，通过 `qnn_skeleton_dir` 传绝对路径；Host `.so` 放入 linker 路径。JNI 封装会从 APK 解出这些资源。QNN 仍需芯片/驱动/算子及精度支持，AUTO 在失败时回退；本次 SM7635 手机不支持此配置的 HTP FP16，实际通过 GPU/CPU 完成验证，未宣称该设备已使用 NPU。

显式指定 CPU/GPU/NNAPI/QNN 时，创建失败会返回错误；AUTO 才负责候选路径选择。NNAPI/QNN 的不支持算子可由 XNNPACK 执行。无需先转换已有可运行的 TFLite 文件才能使用此 C API；量化和 QNN 专用转换属于模型准备阶段，不是把 Java API 换到 C++ 必需的步骤。

## 不启动 JVM 的完整示例

`demos/android-native/main.c` 只包含公开 C 接口：打开模型包、检查 Tensor、分割、检测 478 点、连接美颜/虚化并写出 RGBA；还检查短输入和重复时间戳的错误处理。

```bash
cmake -S demos/android-native -B build/android-native-arm64 \
  -DCMAKE_TOOLCHAIN_FILE="$ANDROID_NDK/build/cmake/android.toolchain.cmake" \
  -DANDROID_ABI=arm64-v8a -DANDROID_PLATFORM=android-26 \
  -DCMAKE_BUILD_TYPE=Release
cmake --build build/android-native-arm64

# 使用你自己的已定向、紧密 RGBA 图片。
adb shell mkdir -p /data/local/tmp/mvs-native
adb push build/android-native-arm64/mvs_native_inference /data/local/tmp/mvs-native/
adb push sdk/android/camera-native/arm64-v8a/libmvs_sdk.so /data/local/tmp/mvs-native/
adb push sdk/android/camera-native/arm64-v8a/libmvs_inference.so /data/local/tmp/mvs-native/
adb push sdk/android/native-runtime/arm64-v8a/. /data/local/tmp/mvs-native/
adb push models/android/mediavision.mvsmodels input.rgba /data/local/tmp/mvs-native/
adb shell 'cd /data/local/tmp/mvs-native && chmod +x mvs_native_inference && LD_LIBRARY_PATH=. ./mvs_native_inference mediavision.mvsmodels input.rgba 384 384 output.rgba 0 .'
```

示例 backend 参数 0=AUTO、1=CPU、2=GPU、3=NNAPI、4=QNN；最后参数为可选 Skeleton 路径。输入应有人像且背景可见，否则示例的验收断言会失败。CPU 示例完整效果速度不代表生产 Vulkan 相机链路性能。

## English

SDK 0.4.3 executes Android LiteRT models entirely in C++: sessions, tensors, delegate selection, segmentation preprocessing/postprocessing, face detection, ROI tracking, and coordinate projection. Java handles Android lifecycle, asynchronous buffer orchestration, and display through JNI. Native consumers can use `mvs/litert.h`, `mvs/inference.h`, `libmvs_inference.so`, and `libmvs_sdk.so` without JNI or a JVM.

Deploy matching ABI/version runtimes from `sdk/android/native-runtime`; LiteRT 1.4.2's library retains the filename `libtensorflowlite_jni.so`, but its exported C API works in a standalone process. GPU uses `libtensorflowlite_gpu_jni.so`; QNN 2.45 HTP is optional and arm64-only. A Maven app receives these dependencies through the POM. Native apps must arrange Android linker visibility themselves and avoid conflicting C++ runtimes.

Creation copies model bytes and option strings. Tensor buffers are borrowed: writable inputs, read-only outputs, and invalid after another invocation or destruction. Reacquire output views after invoking. Inspect type/shape/size/quantization against the actual model contract. Generic invocation performs no automatic normalization or interpretation; it uses static model input shapes and the bundled runtime's supported operators. The segmentation convenience API supports float32/int8/uint8 and NHWC/NCHW, treating single-channel output as person probability and multiclass output as logits. Already-normalized multiclass probabilities should use the generic API.

Create, invoke, reset, and destroy each session on the same owner thread, including GPU initialization and teardown. Keep frame buffers alive until synchronous calls return. Analyzer outputs are borrowed until the next analysis; copy them for queued consumption. Supply oriented RGBA/BGRA frames and strictly increasing timestamps. Detach the analyzer from the effect engine before destroying it.

The packaged analyzer expects the released PERSON contract and official FACE stored-ZIP task. For custom models, use generic tensor APIs and supply your own `MvsAnalysis`. The detector uses CPU/XNNPACK; face tracking tries GPU with CPU fallback. Portrait AUTO measures available delegates and retains a fast NNAPI CPU fallback within budget to avoid contention with face GPU and Vulkan rendering. `delegated_ops` indicates actual delegation, while CPU/XNNPACK remains CPU even with a nonzero count. QNN Skeletons must be real accessible files and the path must be passed explicitly in native integration. Explicit backends return an error on failure; AUTO chooses alternatives. Successful warm invocation is not an end-to-end FPS guarantee.

The C sample above links only public binaries. CPU and GPU standalone paths were validated on an Infinix X6878/SM7635. This device could not use the configured QNN HTP FP16 path; no NPU performance claim is made for it. Other systems retain their established Core ML/Vision/ONNX Runtime adapters. See [validation](VALIDATION.md) for the measured scope.
