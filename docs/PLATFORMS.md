# 平台与交付状态 / Platforms and delivery

所有平台 SDK **0.4.4 / C ABI 11**。使用配套库与头文件；原生 ABI 保留 `mvs_*`，Android 包名为 `com.moon.mediavision`。

| 平台 | 架构 | SDK / Demo | 构建与验证 |
|---|---|---|---|
| Android 相机 | arm64-v8a、armeabi-v7a、x86、x86_64 | AAR、JNI、APK | Release SDK、Debug/Release Demo；Vulkan 相机与平台推理适配 |
| Android C/C++ | 上述四种 | `.a`、`.so`、头文件 | 四架构重新编译；独立 LiteRT 推理库或宿主分析数据 |
| HarmonyOS 6.0.0+ / API20 | arm64-v8a、x86_64 | 共享/静态核心、原生推理库、ArkTS HAR、专用模型、HAP | 官方 SDK 构建；API24真机NNRT/NPU＋Vulkan、201组模型对照及实时相机 |
| iOS | device arm64；simulator arm64/x86_64 | SDK/Core XCFramework、未签名 IPA、Demo 工程 | 封装与 core 重编译，公开工程链接二进制 SDK |
| macOS | x86_64、arm64 | `.a`、`.dylib`、CLI | 两架构重新编译；Intel 原生测试和 Metal 图片效果验证；ARM64 尚无本机运行验证 |
| Windows | x86、x64、ARM64 | MSVC `.lib`、`.dll`、CLI | 使用 clang-cl/MSVC CRT 和 Windows SDK 交叉编译；静态、动态接入示例编译通过 |
| Linux glibc | x86、x86_64、ARMv7 hard-float、aarch64 | `.a`、`.so`、CLI | Zig/Clang，glibc 2.28 目标；静态、动态接入示例编译通过 |

美白和磨皮采用相同参考公式；腮红区域随 468/478 点网格变化，统一支持两种模式与 14 种颜色。渲染后端采用 Metal / Vulkan，CPU 可回退；采样精度与输出取整可能产生少量像素差异。原生 core 的分析数据、模型推理或平台推理适配由宿主提供；Android/iOS 相机封装包含推理适配。

## 运行依赖

- Android：API 26+，保留 `google()`、`mavenCentral()` 与 JitPack，解析 POM 的 LiteRT/QNN 依赖。
- iOS：iOS 15+，App 使用自己的开发团队签名。公开 IPA 未签名，推荐从 Demo 工程构建安装。
- macOS：macOS 13+，系统 Metal/Foundation/QuartzCore；arm64 桌面库与 iOS simulator arm64 是不同产物。
- Windows：MSVC C/C++ ABI；Release 使用静态 CRT，Windows 系统需提供 Universal CRT；Vulkan 需可用驱动。桌面抠像需相同架构的 ONNX Runtime，随仓库的运行库以实际目录为准。ARM64 用户需提供匹配的 ONNX Runtime。
- Linux：glibc 2.28+，共享 C ABI 通常更方便；静态 `.a` 需匹配 Clang/libc++ 工具链，不可假定 GCC/libstdc++ 能直接链接。桌面 ONNX Runtime 需匹配架构。不是 Android Bionic 或 Alpine musl 库。

Windows/Linux 交叉编译完成不等于已在所有目标设备运行。本次发布没有新增 Windows/Linux 本机性能验收；实际验证范围见 [VALIDATION.md](VALIDATION.md)。

## English

Every 0.4.4 platform ships ABI 11 headers and newly built SDK libraries. Whitening, smoothing, landmark-aligned blush regions, colors, and the nose-tip mode are synchronized. Platform rendering, inference adapters, and precision may differ. Windows x86/x64/ARM64 libraries now use the MSVC ABI, including ARM64; rebuild consumers of the previous GNU ARM64 package. Linux targets glibc 2.28 and uses Clang/libc++ for static linking. Windows/Linux cross builds and macOS ARM64 builds have not received new native-device performance tests. The iOS IPA and Android release APK require application signing.

Android 0.4.4 增加四 ABI 的 `libmvs_inference.so`；`sdk/android/native-runtime` 提供配套 LiteRT/GPU/C++ 运行库，arm64 额外提供可选 QNN HTP 运行库。单独使用效果 core 时不需要这些模型运行库。iOS、macOS、Windows、Linux 沿用各自的 Core ML/Vision/ONNX Runtime 适配，未切换为 Android LiteRT 库。

HarmonyOS 本次适配及验证范围见 [HARMONYOS.md](HARMONYOS.md)。Native binary and public-API compatibility builds are not signed Huawei-device runtime validation.
