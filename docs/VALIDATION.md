# 0.4.5 分发验证 / Distribution validation

发布日期：2026-10-28。SDK 0.4.5，效果 C ABI 11。

本版同步美瞳、人中调节及配套公共接口。Android、iOS、HarmonyOS Demo 提供29种美瞳颜色，SDK接受自定义RGB。人中调节沿面部上下方向改变长度，0.5为中性。

| 平台 | 已通过的发布检查 |
|---|---|
| Android | 四ABI AAR、原生效果/推理库、Debug/Release Demo；版本、16KB对齐、APK/AAR一致性 |
| iOS | arm64真机及arm64/x86_64模拟器 Core/封装XCFramework；公开二进制Demo、未签名IPA |
| HarmonyOS | API20+，ARM64/x86_64原生SDK、HAR、相机Demo、未签名HAP；库与加密模型一致性 |
| macOS | Intel/ARM64静态与动态库、公开C++示例；Intel原生回归 |
| Windows | x86/x64/ARM64静态与动态SDK及公开C++示例交叉编译 |
| Linux | x86/x86_64/ARMv7/aarch64静态与动态SDK及公开C++示例交叉编译 |
| 分发 | 最新AAR/HAR/ZIP、头文件与版本引用同步；历史Maven版本保持不变；SHA-256与公开文件边界检查 |

交叉编译不代表每个机型完成运行验收；本版发布不新增手机性能结论。iOS/HarmonyOS运行需使用自己的签名。模型包及第三方运行库延续各自授权。

## JitPack

本机15项回归测试全部通过；35个核心二进制的版本及美瞳/人中扩展符号已核对；18组桌面公开C++接入、4种Android NDK接入均编译通过。

坐标：`com.github.qmy1990:MediaVision:0.4.5`。远程 POM、AAR 和公开 Demo 构建均已验证。

## English

SDK 0.4.5 synchronizes contact lenses, philtrum adjustment, public APIs, SDK binaries, demos and installers across all six platforms. Iris colors accept custom 24-bit RGB; the mobile demos include 29 presets. Philtrum adjustment changes vertical length with 0.5 neutral. ABI 11 options retain their layout and portrait details use a separate extension. Cross compilation and package integrity checks do not imply runtime testing on every target device.

## 远程发布校验 / Remote verification

JitPack `0.4.5` 构建成功，提交 `023026589fc0de2926d7edc6cb5404c5c3a11e65`。POM包含5项LiteRT/GPU/QNN运行依赖。公开Android Demo使用默认JitPack仓库及 `--refresh-dependencies` 完成Debug/Release构建。远程AAR、Gradle解析的AAR和GitHub当前AAR逐字节一致，SHA-256：`4a771116841554b7c10fdddd9cbc72505adb7917b5aa0dd62a51f1acd62603fb`。

JitPack build succeeded. The public demo resolves version0.4.5 from JitPack and builds Debug/Release. The remote and Gradle-resolved AARs match the release checksum above; the POM declares five runtime dependencies.
