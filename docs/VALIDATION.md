# 0.4.3 分发验证 / Distribution validation

验证日期：2026-10-12。所有平台使用 **SDK 0.4.3 / 效果 C ABI 11**；新增 Android 原生推理 C 接口独立于现有效果结构。

| 项目 | 本次验证 |
|---|---|
| Android SDK | 四 ABI 的 Release AAR、效果 core、JNI 和 `libmvs_inference.so`；原生推理库不包含 JNI 导出，生产 Java 类不含 LiteRT Interpreter/MediaPipe Tasks 执行引用 |
| Android 真机 | Infinix X6878 / Qualcomm SM7635；新版 Demo 安装启动；前台自动化 4 项通过，覆盖人物概率、478 点跟踪及 CPU/Vulkan 的效果/背景替换 |
| 分割回归 | 相同 CPU 后端的输出与旧实现逐像素一致；GPU 浮点精度可产生少量概率差异 |
| 人脸回归 | 与旧 Java 路径比较连续 8 帧，每帧 478 点；最大归一化坐标差约 0.0018，reset 后重新检测通过 |
| 纯 C/NDK | 手机上的独立可执行程序无 JVM 地执行人物分割、478 点检测和美颜/虚化；CPU、GPU 两种显式后端均通过，最终公开二进制复跑通过；短帧和重复时间戳拒绝检查通过 |
| 原生分割耗时 | 384×384 RGBA → 256×256 模型/Mask，20 次中后 15 次平均：CPU 4.17 ms、GPU 4.25 ms，包含预后处理；不是完整相机帧率 |
| 最终产物复跑 | Demo 相机保持运行时，公开 C 示例的分割平均 CPU 4.98 ms、GPU 12.05 ms；不同于关闭相机的独立计时，说明单模型 GPU 热身值不能代替组合吞吐 |
| 原生接入编译 | 公开 C 示例仅链接已发布 `.so` 和头文件，四种 Android ABI 均通过 |
| Android Demo | 公开 Demo 使用本地发布 AAR 和 JitPack `com.github.qmy1990:MediaVision:0.4.3` 的 Debug/Release 构建均通过，覆盖四种 ABI；远程 AAR 与发布库逐字节一致 |
| iOS | device arm64、simulator arm64/x86_64 的 Core 与封装重编译；公开二进制 Demo 的未签名 Release 构建通过；此次无 iPhone 运行验收 |
| macOS | x86_64/arm64 静态、动态库与公开 C++ 示例重编译；Intel 示例在 Metal 处理图片成功，9 项原生测试全部通过 |
| Windows / Linux | Windows x86/x64/ARM64，Linux x86/x86_64/ARMv7/aarch64 的静态、动态库及公开 C++ 接入示例交叉编译通过 |
| 文件一致性 | 当前 AAR 目录只放 0.4.3；与 Maven 的 AAR 及其中四 ABI 发布库逐字节一致；公共头文件、CMake 包版本、Apple 版本与安装包同步检查 |
| Android 页面大小 | 自有 SDK / JNI / inference 的所有 ABI ELF LOAD 对齐为 16 KB；第三方依赖按其配套二进制分发 |
| 分发边界 | 核心源码、shader 源文件、密钥、混淆 mapping、调试符号和签名材料不公开；文件清单和 SHA-256 校验工具检查公开文件 |

## 最终发布 AAR 后置相机采样

Infinix X6878 / SM7635，公开 Debug Demo 通过 Release AAR 0.4.3 构建；已核对 UI 的“当前后置”和实际帧尺寸。每档采样约 15 秒，默认组合包括虚化 83、磨皮 55、祛痘 35、美白 25、锐化及脸型/鼻型效果。场景为后置相机拍摄屏幕中的人像，不能作为直接拍摄真人运动的边缘稳定性验收。

| 档位 / 实际尺寸 | 预览刷新 FPS | 实际新帧 FPS |
|---|---:|---:|
| 480p / 480x864 | 29.37 | 27.34 |
| 720p / 720x1280 | 26.70 | 21.40 |
| 1080p / 1080x1920 | 22.27 | 15.23 |

新帧 FPS 排除重复呈现的旧帧。这台设备的组合处理尚未达到 480p/30 和 720p/25 新帧目标；这些短样本不是长时间热稳定性测试。本版解决原生集成与后端选择，不宣称相机性能目标已完成。Release AAR 关闭 SDK 分项诊断日志，因此不将旧人脸诊断日志计入本次新样本。

QNN HTP FP16 在本次 SM7635 手机上不可用，原生 AUTO 通过其他后端运行。本次未连接骁龙 8 Gen 2、天玑 9400 或 iPhone，不把其他设备的历史结果作为 0.4.3 的实测。Windows/Linux 与 macOS ARM64 本次为交叉编译和链接验证，没有目标系统的新增运行或 FPS 验收。

0.4.3 不改变美白、磨皮、腮红的效果公式。0.4.2 的 68 组 CPU/Metal 图片一致性数据保留作为历史参考，未重新宣称为本版视频验收：美白最大差 2 个 RGB 色阶、磨皮 3、腮红 1、组合 5。模型热身、图片回归和 README GIF 帧率都不能替代完整动态视频的吞吐率。

第三方组件保留各自许可证和运行机制；部分第三方 GPU 运行库包含运行时编译程序字符串。自有 Metal shader 以预编译库嵌入，公开仓库不包含自有 shader 源文件。

## English

All five platforms ship SDK 0.4.3 with matching effect ABI 11 headers. The new Android inference APIs are provided by a separate native library. Four Android ABI consumers compile using only public C headers and prebuilt libraries. Standalone CPU and GPU programs were executed without a JVM on an Infinix X6878/SM7635, loading models, producing portrait masks and 478 landmarks, and applying effects. Invalid short frames and duplicate timestamps are rejected.

Four foreground Android fixture tests pass, covering segmentation, an eight-frame face comparison, and CPU/Vulkan effects and replacement. CPU segmentation matches the previous implementation pixel-for-pixel. The maximum normalized landmark difference is approximately 0.0018. Standalone segmentation including preprocessing/postprocessing averages 4.17 ms on CPU and 4.25 ms on GPU for a 384×384 input and 256×256 model/mask; these numbers are not end-to-end camera FPS.

The iOS device/simulator SDKs and unsigned public demo compile. Intel macOS runs the public examples with Metal and passes all nine native tests. Windows/Linux and macOS ARM64 are build/link checks rather than target-device runtime tests. This SM7635 device could not use the configured QNN HTP FP16 path, and no new Snapdragon 8 Gen 2, Dimensity 9400, or iPhone performance claim is made. JitPack `com.github.qmy1990:MediaVision:0.4.3` is published. Its downloaded AAR matches the local release byte-for-byte, and the public demo builds both Debug and Release using the remote dependency.

Final Release-AAR rear-camera sampling used the public Debug demo on the same SM7635 device, with rear-facing state and actual frame dimensions checked. The camera captured a portrait on a screen, so this is a processing-load check rather than a direct live-person motion-quality sign-off. Each tier was sampled for about 15 seconds with default combined effects. Preview / unique-frame FPS was 29.37 / 27.34 at 480x864, 26.70 / 21.40 at 720x1280, 22.27 / 15.23 at 1080x1920. Repeated display frames are excluded from unique FPS. The 480p/30 and 720p/25 unique-frame targets have not been met on this device; no sustained thermal-performance claim is made.

The final public C executable and shared libraries were rerun successfully on CPU and GPU. With the camera demo still running, segmentation averaged 4.98 ms on CPU and 12.05 ms on GPU; this concurrent workload is different from isolated inference and reinforces the need to measure complete camera throughput.

## 远程发布校验 / Remote publication verification

JitPack 坐标：`com.github.qmy1990:MediaVision:0.4.3`，构建提交 `876dcaf4bda1f7521765ba53470968353c78ebdf`。POM 包含 5 项 LiteRT/GPU/QNN 运行依赖，不再包含生产 MediaPipe Tasks 依赖。GitHub Maven 与 Gradle 从 JitPack 解析的 AAR 均与当前 AAR 相同；SHA-256：`35d17412336e7bea5284a8aefebb27a13731d31dc9cd89161b6a53eb8048c9ce`。公开 Demo 远程依赖构建通过，安装包内自有 SDK 库与 AAR 的四 ABI 库一致。

The published coordinate is `com.github.qmy1990:MediaVision:0.4.3`, built from commit `876dcaf4bda1f7521765ba53470968353c78ebdf`. The POM contains five LiteRT/GPU/QNN runtime dependencies and no production MediaPipe Tasks dependency. Both the GitHub Maven AAR and Gradle-resolved JitPack AAR match the release SHA-256 above. Public Debug/Release builds and their four-ABI SDK library contents are verified.

## HarmonyOS 编译与接入验证 · 2026-10-15

ARM64/x86_64 SDK、HAR、HAP和纯C示例官方工具链编译通过。ADA-AL00 / HarmonyOS6.1.0.135 / API24完成NNRT三模型201组输出对照、原生GPU输入128组padding像素对照及实时预览验证。HAR/HAP内的SDK库和模型与独立分发文件一致；x86_64为编译验证。接入说明见 [HARMONYOS.md](HARMONYOS.md)。

Official ARM64/x86_64 SDK, HAR, HAP and C example builds pass. NNRT output checks pass 201 cases and native GPU padding checks pass 128 cases on an ARM64/API24 device. Packaged libraries/models match the distribution. x86_64 is compile-tested.
