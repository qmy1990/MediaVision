# 0.4.0 分发验证 / Distribution validation

验证日期：2026-10-07。这里记录公开交付物的验证范围，设备性能结果另见 [平台说明](PLATFORMS.md)。

| 项目 | 结果 |
|---|---|
| Android SDK | Release AAR 构建通过；公开 API 使用 `com.moon.mediavision`；保留 `VisionOptions.Builder`，内部 Java 实现经过压缩混淆 |
| Android Demo | 本地分发 Maven 的构建已通过；当前默认使用 JitPack `0.4.1`，arm64 Debug / Release 均编译通过；应用 ID 为 `com.moon.mediavision.demo` |
| Maven / JitPack | `maven-publish` 发布 AAR / POM；JitPack `0.4.1` 远程构建成功，AAR 与原始 SDK 逐字节一致，保留 6 个运行依赖；真实 Android Demo 编译通过 |
| Apple SDK | iOS arm64、模拟器 arm64/x86_64 的 Core 与封装 XCFramework 构建通过 |
| iOS Demo | 公开工程只链接预编译 XCFramework，编译通过；IPA 未签名，真机安装需要自己的开发团队 |
| macOS | x86_64 静态/动态库构建通过；6 项原生测试全部通过；公开 C++ 示例调用 Metal 后端处理图片成功 |
| 加密模型 | 13 个 `.mvsmodels` 包均可通过 SDK 加载并枚举；研究归档含 80 个模型；加载成功不等于候选模型效果验收 |
| 文件边界 | 自有核心源码、原始 shader 文件、模型加密实现及密钥、签名材料、调试符号不纳入分发；自有 Metal shader 使用预编译库 |

SDK 中使用的第三方运行库保留其内部运行机制和许可证；它们可能在二进制中包含用于运行时编译的 GPU 程序字符串。自有 shader 源文件和自有 shader 文本没有随本次 Apple SDK 分发。

当前发布收尾时没有连接移动设备，因此没有对新包名版本补做 Android / iOS 真机运行测试。Windows / Linux 产物来自此前构建，其具体架构与已验证范围见 `manifest/platforms.json`。本表不构成所有平台、模型或芯片的性能达标承诺。

Android and iOS public demos were built against precompiled SDK artifacts. The macOS C++ example successfully processed an image with Metal, and all six native tests passed. All thirteen encrypted model packages loaded successfully. This release did not receive a new mobile-device runtime test after the package rename. Windows and Linux use earlier delivery binaries; see the platform manifest for their validation scope.

README 的 8 个循环 GIF 均保留完整对比时长，300px 宽、12 FPS，每个小于 5 MB；已确认 GitHub 渲染页面包含全部 8 个内嵌图片，公共 GIF 下载与本地文件一致。GIF 的播放帧率不代表 SDK 处理帧率。
