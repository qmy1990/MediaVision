# 平台与交付状态 / Platforms and delivery status

SDK 0.4.0，C ABI 9。平台包装层与 Maven 坐标采用 `com.moon.mediavision`；原生 C ABI 保留 `mvs_*`。

| 平台 | 架构 | 产物与路径 | 本次范围 |
|---|---|---|---|
| Android Camera SDK | arm64-v8a / armeabi-v7a / x86 | `sdk/android/maven`、AAR、`camera-native`、APK | 新包名与 JNI 重编译，Release 实现混淆；公开 Maven 消费工程验证 |
| Android C/C++ core | 上述三种 + x86_64 | `sdk/android/core` 静态/动态库 | 保留已有独立 core 交付，移除调试信息；宿主提供推理 |
| iOS | device arm64；simulator arm64/x86_64 | `MediaVisionSDK.xcframework`、`MediaVisionCore.xcframework` | 重新构建，Apple 自有 shader 预编译；公开 Demo 编译；本次无 iPhone 实机验收 |
| macOS | x86_64（Intel） | `sdk/macos/x86_64` 静态/动态库、CLI | 新建二进制交付；6 项 native 测试；公开 C++ Demo 编译运行 |
| Windows MSVC | x86 / x64 | `.dll` / import `.lib` / static `.lib`、CLI | 保留之前已构建的交付文件；本次未在 Windows 重编译/运行 |
| Windows GNU | ARM64 | CPU `.dll` / `.dll.a` / `.a`、CLI | 之前的 Zig 交叉编译产物；未做 ARM64 Windows 实机验收，不能当成 MSVC `.lib` |
| Linux glibc | x86 / x86_64 / ARMv7 hard-float / aarch64 | `.so` / `.a`、CLI | 保留之前的 glibc 2.28 交叉编译交付；本次无 Linux 实机验收 |

Apple Silicon macOS 的独立桌面库本次没有提供，iOS simulator arm64 不能当成 macOS arm64 库。macOS 提供 native core/CLI；完整 Python 图片/视频/相机 Demo 的当前目标是 Windows/Linux。

## 运行依赖

- Android：API 26+；Java/Kotlin App 必须解析 SDK POM 声明的 Tasks/LiteRT/QNN 依赖。非高通设备不因可选 FastRPC 声明而被禁止安装。不同后端失败时仍有回退策略。
- iOS：iOS 15+。SDK framework 仅依赖系统框架和已静态链接的运行库；公开 Demo 不需 Pods。App 真机安装需自己签名，仓库 IPA 未签名。
- macOS：此次在 macOS 13.7.8 / Intel 构建并测试。动态库依赖系统 Metal/Foundation/QuartzCore 和 C++ runtime；选择合适的 SDK 路径构建 C++ Demo。
- Windows：MSVC 库需匹配的 Visual C++ runtime；Vulkan 后端需可用驱动。桌面抠像使用附带 ONNX Runtime，x64 可选 DirectML；选择错误架构不会自动转换 ABI。
- Linux：glibc 2.28 目标，不适用于 Android Bionic 或 Alpine musl。共享库依赖系统 loader/glibc/libm/libpthread/libdl。静态库采用 Clang/libc++ ABI，需要匹配链接工具链；共享 C ABI 通常更便于跨编译器接入。

Windows/Linux Python Demo 依赖 `demos/desktop/requirements.txt` 与 `dependencies/desktop-runtime`。执行时默认加载对应平台 `models/.../mediavision.mvsmodels`，不需要运行时下载模型。

## 安装与示例

Android 可安装 `installers/android/MediaVisionDemo-debug.apk`；`release-unsigned.apk` 需自己签名。iOS `MediaVisionDemo-unsigned.ipa` 仅为待签名产物，建议用公开工程选择自己的 Team 构建运行。Mac/Windows/Linux CLI 处理 P6 PPM，测试锐化与 C++ 调用，不代表自动启用了完整人像推理。

## English notes

Platform/architecture binaries are not interchangeable. The Android Camera AAR and standalone native core have different scopes. Apple XCFrameworks include device/simulator slices, not a macOS ARM64 desktop build. The current macOS deliverable is Intel native core/CLI. Windows/Linux binaries retain their previous build provenance; cross-compiled targets have not all been run on native devices. The iOS IPA and Android release APK are unsigned and require the application's own signing workflow.
