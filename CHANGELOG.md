# 更新日志 / Changelog

## 0.4.2 · 2026-10-11

### 中文

- 优化美白效果，改善肤色提亮与人像边缘表现。
- 优化磨皮效果，兼顾平滑和皮肤纹理。
- 优化腮红位置、形状及上下、鼻侧的渐淡过渡。
- 新增“脸颊＋鼻尖”腮红模式，保留“脸颊”模式。
- 新增 14 种腮红颜色，支持自定义 RGB 和独立强度调节。
- 同步更新 Android、iOS、Windows、macOS、Linux 的 SDK、公共接口和 Demo、接口说明及循环 GIF；JitPack 引用升级至 `0.4.2`。

### English

- Improved whitening for skin brightening and portrait boundaries.
- Improved skin smoothing while retaining skin texture.
- Refined blush placement, shape, and falloff above, below, and toward the nose.
- Added a cheeks-and-nose-tip blush mode alongside the cheeks-only mode.
- Added 14 blush shades, custom RGB colors, and independent intensity control.
- Updated SDK binaries, public APIs, and demos across Android, iOS, Windows, macOS, and Linux, API documentation, and looping GIFs; upgraded the JitPack dependency to `0.4.2`.

### 接口兼容 / Compatibility

所有平台的 0.4.2 SDK 统一使用 C ABI 11。新增字段追加至 `MvsOptions`，请使用随库提供的头文件并重新编译 C/C++ 调用方。Windows ARM64 本版提供 MSVC `.lib`，替换旧 GNU 交付格式；Linux 静态库使用 Clang/libc++ ABI。

All 0.4.2 platforms use C ABI 11. Rebuild native callers with the matching headers. Windows ARM64 now includes MSVC libraries; Linux static libraries use the Clang/libc++ ABI.

## 0.4.1

完善 JitPack 发布与接入配置，沿用 SDK 0.4.0 二进制。 / Improved JitPack publishing and integration while retaining SDK 0.4.0 binaries.

## 0.4.0

首次公开 SDK 二进制、加密模型与跨平台 Demo。 / Initial public binary SDK, encrypted models, and cross-platform demos.
