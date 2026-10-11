# 更新日志 / Changelog

## 0.4.3 · 2026-10-12

### 中文

- Android LiteRT 模型执行迁移到 C/C++，Java 通过 JNI 提交模型、帧和参数。
- 新增纯 C/NDK 推理接口，支持 Tensor 输入输出、人物分割、478 点人脸检测和 ROI 跟踪。
- 保留 QNN HTP、NNAPI、GPU、CPU/XNNPACK 后端及回退；增加实际委派算子数量，避免把 CPU 回退误标成 NPU。
- 修正原生 GPU 精度配置，补齐 XNNPACK 回退，并移除生产 Android 的 Java Interpreter/MediaPipe Tasks 推理依赖。
- SDK AAR 支持四种 Android ABI；更新所有系统的库、公共头文件、Demo、安装包及接入文档。
- `sdk/android/aar` 更新为 `mediavision-sdk-0.4.3.aar`；历史 Maven 版本保留供旧项目使用。

### English

- Moved Android LiteRT model execution to C/C++; Java submits models, frames, and parameters through JNI.
- Added standalone C/NDK tensor, portrait segmentation, 478-point face detection, and ROI tracking APIs.
- Retained QNN HTP, NNAPI, GPU, and CPU/XNNPACK selection and fallback, with actual delegated operator counts.
- Aligned native GPU precision settings, restored XNNPACK fallback, and removed production Java Interpreter/MediaPipe Tasks inference dependencies.
- Added four-ABI Android AAR support and refreshed every platform library, public header, demo, installer, and integration guide.
- Replaced the canonical AAR with SDK 0.4.3; historical Maven versions remain available.

### 兼容 / Compatibility

效果 C ABI 仍为 11，现有美颜参数及 Java API 保留。新增原生推理符号由 Android `libmvs_inference.so` 提供，需同时部署配套运行库；其他系统沿用原有推理适配器。

The effect ABI remains 11 and existing Java/options APIs are retained. New Android inference symbols require `libmvs_inference.so` and matching runtimes; other systems keep their established adapters.

## 0.4.2 · 2026-10-11

### 中文

- 优化美白效果，改善肤色提亮与人像边缘表现。
- 优化磨皮效果，兼顾平滑和皮肤纹理。
- 优化腮红位置、形状及上下、鼻侧的渐淡过渡。
- 新增“脸颊＋鼻尖”腮红模式，保留“脸颊”模式。
- 新增 14 种腮红颜色，支持自定义 RGB 和独立强度调节。
- 同步更新 Android、iOS、Windows、macOS、Linux 的 SDK、公共接口和 Demo、接口说明及循环 GIF；JitPack 引用升级至 `v0.4.2`。

### English

- Improved whitening for skin brightening and portrait boundaries.
- Improved skin smoothing while retaining skin texture.
- Refined blush placement, shape, and falloff above, below, and toward the nose.
- Added a cheeks-and-nose-tip blush mode alongside the cheeks-only mode.
- Added 14 blush shades, custom RGB colors, and independent intensity control.
- Updated SDK binaries, public APIs, and demos across Android, iOS, Windows, macOS, and Linux, API documentation, and looping GIFs; upgraded the JitPack dependency to `v0.4.2`.

### 接口兼容 / Compatibility

所有平台的 0.4.2 SDK 统一使用 C ABI 11。新增字段追加至 `MvsOptions`，请使用随库提供的头文件并重新编译 C/C++ 调用方。Windows ARM64 本版提供 MSVC `.lib`，替换旧 GNU 交付格式；Linux 静态库使用 Clang/libc++ ABI。

All 0.4.2 platforms use C ABI 11. Rebuild native callers with the matching headers. Windows ARM64 now includes MSVC libraries; Linux static libraries use the Clang/libc++ ABI.

## 0.4.1

完善 JitPack 发布与接入配置，沿用 SDK 0.4.0 二进制。 / Improved JitPack publishing and integration while retaining SDK 0.4.0 binaries.

## 0.4.0

首次公开 SDK 二进制、加密模型与跨平台 Demo。 / Initial public binary SDK, encrypted models, and cross-platform demos.
