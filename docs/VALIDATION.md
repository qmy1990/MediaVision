# 0.4.2 分发验证 / Distribution validation

验证日期：2026-10-11。所有平台配套 SDK 与头文件使用 **0.4.2 / C ABI 11**。

| 项目 | 结果 |
|---|---|
| Android SDK | Release AAR、四架构 C/C++ core、三架构相机 JNI 重新编译；公开 `blushMode()`、`blushColor()` 与 14 色常量保留 |
| Android Demo | 使用发布 AAR 和 POM 的公开工程 Debug / Release 编译通过；版本 0.4.2、应用 ID `com.moon.mediavision.demo` |
| Maven / JitPack | 本地 Maven 发布通过，POM 保留 6 个运行依赖；远程 JitPack 状态记录于 `manifest/platforms.json` |
| iOS | device arm64、simulator arm64/x86_64 的 Core 与封装 XCFramework 重编译；公开 Demo 只链接预编译 SDK，Release 构建通过；IPA 未签名 |
| macOS | x86_64、arm64 静态/动态库重编译；四组公开 C++ 示例编译通过；Intel 静态/动态示例均使用 Metal 处理图片成功 |
| 原生测试 | Intel macOS：9 项测试全部通过，覆盖选项/接口、模型加载、参考美白、腮红、遮罩与 GPU 像素处理 |
| 后端效果对比 | 68 组真实图片 CPU/Metal 对比：美白最大差 2 个 RGB 色阶、磨皮 3、腮红 1、组合 5；99% 通道差不超过 2，属于采样精度与取整差异 |
| Windows | x86、x64、ARM64 的 MSVC 静态库、DLL 和公开 C++ 接入示例交叉编译通过 |
| Linux | x86、x86_64、ARMv7 hard-float、aarch64 的 glibc 2.28 静态/动态库及公开 C++ 接入示例交叉编译通过 |
| 资源及版本 | 各架构公共 `sdk.h` 与根目录头文件一致；CMake 包版本均为 0.4.2；Apple 封装版本为 0.4.2 / build 6 |
| 循环 GIF | 10 个 360px / 15 FPS GIF 保留对比过程，均设置无限循环；MP4 保留原始文件 |
| 分发边界 | 公开文件校验工具检查清单与哈希；自有核心源码、shader 源文件、加密密钥与签名材料不随分发 |

Windows/Linux 与 macOS ARM64 本次为交叉编译和链接验证，没有新增目标系统运行或持续 FPS 验收。本次最终分发安装包没有新增 Android/iOS 真机安装及运行验收。图片后端一致性测试不代表动态视频或各芯片性能达标。GIF 的播放帧率也不代表 SDK 处理速度。

第三方运行库保留各自许可证与内部机制；部分第三方 GPU 运行时会包含用于运行时编译的程序字符串。自有 Metal shader 使用预编译库，公开仓库不包含自有 shader 源文件。

## English

All five platforms ship newly built SDK 0.4.2 libraries and matching ABI 11 headers. Android public Debug/Release demos and the iOS binary-only Release demo build successfully. Windows x86/x64/ARM64, Linux x86/x86_64/ARMv7/aarch64, and macOS x86_64/arm64 static/shared C++ consumers compile against the public packages. Both Intel macOS consumers process an image with Metal; all nine native tests pass.

Across 68 real-photo CPU/Metal cases, maximum RGB differences are 2 for whitening, 3 for smoothing, 1 for blush, and 5 for combined effects; the 99th-percentile channel difference is at most 2. The README shows ten infinitely looping GIFs. JitPack remote publication checks are recorded in the platform manifest.

Cross builds do not establish native runtime or FPS results. Windows/Linux and macOS ARM64 received no new target-device performance tests; the final Android/iOS installers have not received a new installation/runtime test in this release packaging pass. Image parity and GIF playback FPS are not mobile video throughput measurements.
