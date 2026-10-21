# 0.4.4 分发验证 / Distribution validation

验证日期：2026-10-21。SDK 0.4.4，效果 C ABI 11。

本版更新磨皮与腮红效果，同步各平台二进制、Demo、安装包、公共接口文档和 Maven 引用。

| 平台 | 发布检查 |
|---|---|
| Android | 四 ABI Release AAR、原生效果/推理库及 Debug/Release Demo；检查版本、依赖、16KB 对齐及 APK/AAR 库一致性 |
| iOS | arm64 真机及 arm64/x86_64 模拟器 Core/封装 XCFramework；公开二进制 Demo 和未签名 IPA |
| HarmonyOS | API20+，ARM64/x86_64 SDK、HAR、相机 Demo 和未签名 HAP；检查库与加密模型一致性 |
| macOS | x86_64/arm64 静态与动态库、C/C++ 示例；Intel 原生回归及动态库版本检查 |
| Windows | x86/x64/ARM64 静态与动态库及 C/C++ 示例交叉编译 |
| Linux | x86/x86_64/ARMv7/aarch64 静态与动态库及 C/C++ 示例交叉编译 |
| 分发 | 当前 AAR、HAR、ZIP 与 Maven 引用统一0.4.4；历史Maven版本保持不变；文件清单和SHA-256检查 |

跨系统交叉编译与接入检查不代表每个机型均完成运行验收。最近的 iPhone 真人与 Android 画质/性能验证对应本版效果同步代码；纯版本升级不改变效果 C ABI 或模型包。iOS/HarmonyOS 安装包使用者需配置自己的签名。

## JitPack

坐标：`com.github.qmy1990:MediaVision:0.4.4`。发布完成后核对远程 AAR 的 SHA-256、POM 运行依赖和公开 Demo 的远程构建。

## English

SDK 0.4.4 retains effect ABI 11 and updates skin smoothing and blush. Native SDKs, public headers, demos and installers are refreshed across all six platforms. Android includes four ABIs; Apple includes device/simulator frameworks; HarmonyOS targets API20+. Windows, Linux and macOS ARM64 use cross-platform build checks. Cross compilation does not imply runtime validation on every target device. Third-party runtimes and encrypted model packages retain their existing licenses. JitPack uses `com.github.qmy1990:MediaVision:0.4.4`.

## 远程发布校验 / Remote verification

JitPack `0.4.4` 构建成功，提交 `1cd4c60ffaf15fce079087e93dcbf2f5ef6cb523`。POM 包含5项 LiteRT/GPU/QNN 运行依赖。公开 Android Demo 使用默认 JitPack 仓库并以 `--refresh-dependencies` 完成 Debug / Release 构建。Gradle 下载的 AAR 与 GitHub Maven/当前 AAR 逐字节一致，SHA-256：`7a83acc67fbc9eb2c414c1aa3dc323410011b1d889a303cb0f26348913c7570b`。

JitPack build succeeded. The public demo resolves the remote dependency and builds Debug/Release. The Gradle-resolved AAR matches the release SHA-256 above; the POM declares five runtime dependencies.
