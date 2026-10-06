# 集成指南 / Integration

SDK 标识：`com.moon.mediavision`。Android 命名空间与 Maven group 使用同一标识；Demo 应用 ID 为 `com.moon.mediavision.demo`。C/C++ 保留公共 `mvs_*` 符号及 ABI 9，避免无意义地改变原生调用约定。

## Android

推荐 Maven 接入，完整配置见 [MAVEN.md](MAVEN.md)。生产 AAR 内含加密运行模型和 JNI 库；平台运行库由 POM 解析。不要把 SDK 当成无依赖单文件 AAR，也不要在应用中放入未验证的候选模型。

`VisionOptions` 是不可变配置：

```java
VisionOptions options = VisionOptions.builder()
    .beauty(0.55f).blemishRemoval(0.35f)
    .background(VisionOptions.BLUR).blurRadius(24)
    .lipstick(0.22f).lipstickColor(VisionOptions.LIP_CLASSIC_RED)
    .build();
VisionSdk sdk = new VisionSdk(context, VisionSdk.AUTO);
sdk.configure(options);
sdk.setOutputSurface(surface);
// 使用 processHardwareBuffer / processYuv 提交对应相机帧。
// 完整 Image 生命周期、旋转/镜像与预览代码见 demos/android。
```

检查应用 CAMERA 权限和相机帧方向；同一引擎不要重入，结束时 `sdk.close()`。连续效果通常为 0–1；眼间距和颧骨为 0.5 中性，具体以公开接口/示例为准。

## iOS

App 集成 `MediaVisionSDK.xcframework` 并 Embed & Sign。模型加入资源并传实际文件路径。MVSProcessor 的 BGRA `CVPixelBuffer` 输入应为指定方向；同步输出需要调用方释放，异步 completion 输出是借用对象，异步保留需要自行 retain。使用同步或异步一种处理方式，不混用同一处理器。

公开 Demo 的 `.xcodeproj` 只链接二进制 framework，不需要 CocoaPods 或私有源码。直接打开工程，选择自己的开发团队并运行。可用 `tools/build_demo.sh ios` 编译未签名设备 App；如修改 `project.yml`，可安装 XcodeGen 后重新生成工程。真机签名与安装由使用者自己的 Apple 开发账号完成。

## C/C++

`sdk.h` 定义生命周期、配置、帧缓冲、分析数据和错误码。`models.h` 提供加密运行包加载；`desktop.h` 提供 Windows/Linux native matting adapter。`android.h` 提供 Android 原生相机导入接口。头文件不包含算法/shader 实现。

基本调用顺序：`mvs_default_config` → `mvs_create` → `mvs_set_options` → `mvs_process` / `mvs_process_with_analysis` → `mvs_destroy`。尺寸、stride、像素格式、内存大小和时间戳必须有效；输入输出缓冲在同步调用期间借用。RGBA8/BGRA8 的格式与各平台输入封装不能混淆。

核心库不自动提供模型推理。宿主可以实现 `MvsAnalyzeFn`，或向 `mvs_process_with_analysis` 提供与输入方向/时间戳一致的人物概率 Mask 和 468/478 点人脸布局。仅锐化等不依赖分析的效果可直接处理输入。自定义 C 回调按注册顺序执行，用于应用扩展效果。

CMake 可用 `find_package(MediaVisionSDK CONFIG REQUIRED)` 与 `MediaVision::SDK`，将选定库的安装前缀加入 `CMAKE_PREFIX_PATH`。仓库根目录工程提供纯上层 `mvs_demo_cli` 示例；它不编译 SDK 内部源文件。

Windows MSVC `.lib` 与 GNU ARM64 `.dll.a/.a` 的工具链不同。Linux 静态库使用 Clang/libc++ ABI，不能假定任意 GCC/libstdc++ 可链接；共享 C ABI 库通常更便于跨编译器接入。具体见 [平台说明](PLATFORMS.md)。

## 模型部署与分发

已有运行模型部署：

```bash
python3 tools/prepare_model_assets.py --platform android \
  --output /path/to/app/src/main/assets/mediavision.mvsmodels
python3 tools/package_distribution.py --output distribution-output/MediaVision-0.4.0.zip
```

模型加密、量化和内部 SDK 编译在私有工程完成。公开工具只校验/部署已打包模型及分发文件，不公开加密密钥或内部编译流水线。候选模型不同输入/输出合约不能直接替换生产包。

二进制分发不等于技术上无法逆向。此仓库不公开核心源码、shader 源码、SDK 混淆 mapping、调试符号或签名私钥；Apple 自有 shader 以预编译库嵌入。加密模型包装是分发形式，不提供“无法提取模型”的保证。

## English summary

Use the platform wrapper for camera/inference integration, or link the public C ABI for native applications. Android uses `com.moon.mediavision:mediavision-sdk:0.4.0`; the POM resolves external runtimes. The iOS demo links the prebuilt framework and requires your own signing team. Native callers supply valid buffers and, when needed, matching inference analysis. Select the correct platform/architecture/toolchain. Public tooling deploys existing encrypted packages and builds demos only; proprietary SDK/model compilation and signing credentials are not published.
