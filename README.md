# MediaVision · Moon

**跨平台实时人像视觉 SDK**  
`com.moon.mediavision` · C++17 · C ABI 9 · Android / iOS / Windows / macOS / Linux

中文（默认） | [English](README.en.md)

MediaVision 将人像分析、美颜、面部塑形、美妆和背景处理整合为可嵌入应用的视觉 SDK。由 **Moon** 维护，提供平台封装与公共 C/C++ 接口，适用于相机预览、视频处理、直播和视频会议等应用的效果处理环节。

本仓库公开 **Demo、接入代码、公共头文件与构建/打包工具**，并分发编译好的 SDK 和加密模型包。核心算法实现及 shader 源码不公开。Demo 与接入资料使用 MIT；SDK 二进制免费允许个人和商业应用集成，具体见 [授权说明](LICENSE.md)。第三方模型及运行库遵循各自许可证。

## 能力

| 类别 | 当前提供 |
|---|---|
| 人像与背景 | 人物分割、可调强度背景虚化、图片背景替换、Mask 查看 |
| 肤质与画质 | 磨皮、祛痘、肤色调节、自然白 / 冷白 / 红润 / 美黑、锐化 |
| 面部塑形 | 大眼、小头、瘦脸、鼻翼、眼间距、颧骨调节 |
| 美妆 | 可调强度与颜色的口红、晒红/腮红、眉毛加深 |
| 道具 | 基于面部关键点的基础三角网格道具、头饰和首饰示例 |
| 开发与调试 | 人脸关键点/网格查看、模型后端选择、分项计时、公共 C ABI、自定义效果回调 |

Vulkan / Metal 承担图像渲染与效果计算，模型推理按平台和设备选择适合的 GPU、NPU 或 CPU 路径。Android 提供 QNN HTP / NNAPI / GPU 后端与回退机制；Apple 适配层提供 MediaPipe、Vision 和 Core ML 选项。**后端可选不代表所有芯片均已验证 NPU/ANE 执行。**

Android 的相机处理路径采用 AHardwareBuffer 导入与 GPU 缓存，将分析结果与对应输入帧配对，再完成美颜和背景合成。桌面 Demo 支持图片、视频与摄像头；CLI 提供最小 C++ 接入示例。不同平台的模型、封装和优化策略有所区别，不承诺逐像素效果或性能相同。

## 效果对比

以下视频来自项目提供的效果对比素材，可点击查看或下载：

| 效果 | 视频 | 效果 | 视频 |
|---|---|---|---|
| 美颜总开关 | [查看](docs/media/beauty-toggle.mp4) | 祛痘 | [查看](docs/media/blemish-removal.mp4) |
| 大眼 | [查看](docs/media/eye-enlargement.mp4) | 瘦脸 | [查看](docs/media/face-slimming.mp4) |
| 鼻翼 | [查看](docs/media/nose-reshaping.mp4) | 口红 | [查看](docs/media/lipstick.mp4) |
| 眉毛 | [查看](docs/media/eyebrows.mp4) | 美白 | [查看](docs/media/skin-tone.mp4) |

视频用于展示具体场景的变化，不代表所有肤色、光照、姿态或设备下的最终效果。现阶段仍在持续优化动态边缘、遮挡、妆容稳定性及长时间性能。

## 获取完整文件

SDK、模型和大型安装包使用 Git LFS。先安装 [Git LFS](https://git-lfs.com)，再执行：

```bash
git lfs install
git clone https://github.com/qmy1990/MediaVision.git
cd MediaVision
git lfs pull
python3 tools/verify_distribution.py
```

直接下载 GitHub 的源码 ZIP 时，大文件可能仍是 LFS 指针。可执行 `python3 tools/fetch_binary_assets.py` 下载清单中的二进制并校验 SHA-256；源码 ZIP 本身不保证包含全部 SDK 文件。

```text
sdk/             平台 SDK、Android Maven 仓库、Apple XCFramework
include/mvs/     公共 C/C++ 接口
models/          各平台运行模型、加密研究归档与候选模型
demos/           Android/iOS App、桌面 Python Demo、C++ CLI
installers/      已编译的 Android APK、iOS 未签名 IPA
tools/           Demo 构建、校验、下载与分发打包工具
docs/            接入、平台状态、路线图及效果视频
licenses/        Demo / SDK 授权与第三方声明
manifest/        版本、平台状态、模型及文件校验清单
```

运行时只需使用对应平台的生产模型包。`models/research/` 和 `models/variants/` 是独立研究资产，**不应整目录加入 App**，也不代表候选模型已经通过生产效果或性能验收。

## 快速接入

### Android：Java / Kotlin 应用

在 `settings.gradle` 的 `dependencyResolutionManagement.repositories` 中添加 GitHub Maven 仓库：

```groovy
maven {
    url 'https://raw.githubusercontent.com/qmy1990/MediaVision/main/sdk/android/maven'
    content { includeGroup 'com.moon.mediavision' }
}
```

同时保留 `google()` / `mavenCentral()`。添加依赖（MediaPipe / LiteRT / QNN 的传递依赖由 POM 声明）：

```groovy
implementation 'com.moon.mediavision:mediavision-sdk:0.4.0'
```

```java
import com.moon.mediavision.VisionSdk;
import com.moon.mediavision.VisionOptions;

VisionSdk sdk = new VisionSdk(context, VisionSdk.AUTO);
VisionOptions options = VisionOptions.builder()
    .beauty(0.55f).blemishRemoval(0.35f).build();
sdk.configure(options);
// 绑定输出 Surface 并提交相机帧，完整流程见 demos/android。
// 释放页面/相机时调用 sdk.close()。
```

SDK 支持 API 26+；完整 Camera AAR 的 ABI 为 arm64-v8a、armeabi-v7a、x86。独立 C/C++ core 另提供 x86_64，该架构不等同于完整 Java Camera SDK。构建公开 Demo：

```bash
cd demos/android
# JDK 17、Android SDK 35；按本机环境配置 ANDROID_HOME。
./gradlew :app:assembleDebug
```

公开 Demo 默认使用随仓库提供的本地 Maven：`maven { url uri('../../sdk/android/maven') }`。也可将上述远程 URL 换成本机 SDK 的 Maven 路径使用。升级只需把依赖中的 `0.4.0` 改为已发布的新版本；不使用 `+` 动态版本。本仓库的 GitHub Maven 是静态文件仓库，**不等同于已发布到 Maven Central 或 GitHub Packages**。维护者发布步骤见 [Maven 发布与引用](docs/MAVEN.md)。

### iOS：Objective-C / Objective-C++

将 `sdk/ios/MediaVisionSDK.xcframework` 设为 Embed & Sign；纯 C/C++ 接入可使用 `MediaVisionCore.xcframework`。将 `models/ios/mediavision.mvsmodels` 加入 App 资源，保证实际路径可访问。

```objective-c
#import <MediaVisionSDK/MVSProcessor.h>

MVSProcessor *sdk = [[MVSProcessor alloc]
    initWithModelPackagePath:packagePath backend:MVS_METAL error:&error];
MvsOptions options = mvs_default_options();
options.beauty = 0.55f;
options.background = MVS_BACKGROUND_BLUR;
[sdk configure:options error:&error];
// 使用 newPixelBufferByProcessing 或异步 submitPixelBuffer 提交相机帧。
```

iOS 15+，包含 device arm64 与 simulator arm64/x86_64。公开 Demo 仅链接二进制 SDK；安装到真机需要使用自己的 Apple 开发团队签名。仓库里的未签名 IPA 不能直接安装。

### C / C++：直接链接 SDK

公共接口位于 `include/mvs/sdk.h`；`mvs.hpp` 提供轻量 RAII 包装。选择与目标平台和架构一致的静态/动态库：

```cpp
#include <mvs/sdk.h>

MvsConfig config = mvs_default_config();
MvsHandle engine = nullptr;
if (mvs_create(&config, &engine) == MVS_OK) {
  MvsOptions options = mvs_default_options();
  options.sharpen = 0.3f;
  mvs_set_options(engine, &options);
  // mvs_process(engine, &input, &output);
  mvs_destroy(engine);
}
```

人像和面部相关效果需要有效的分析结果。可通过 `mvs_set_analyzer` 提供推理回调，或调用 `mvs_process_with_analysis` 提交同帧 Mask / 关键点；只链接 core 不会自动建立手机相机或模型推理链路。

构建独立 C++ Demo，无需任何 SDK 内部源码：

```bash
cmake -S . -B build/demo -DMEDIAVISION_SDK_ROOT=/path/to/platform/sdk
cmake --build build/demo --config Release
```

完整接入步骤、库选择和运行依赖见 [集成指南](docs/INTEGRATION.md)。

## 平台与验证范围

各架构产物、构建来源和真机状态以 [平台清单](docs/PLATFORMS.md) 与 `manifest/platforms.json` 为准。本次交付检查见 [分发验证](docs/VALIDATION.md)。Windows/Linux 部分产物来自此前的交付构建；Linux 交叉编译不能替代 Linux 真机验收。

近期 Snapdragon 8 Gen 2 在 1080×1920 默认效果、30 秒**屏幕静态人像**测试中达到平均 29.99 FPS；该结果不属于真人动态或持续热稳定验收，也不用于承诺所有高端手机均达 30 FPS。iPhone 8 Plus 的 480p/30 FPS、720p/25 FPS 是继续优化的目标，并非本仓库宣称全面达到的保证。

## 路线图

后续按以下顺序增加功能；均为计划项，尚未发布：

1. 瞳孔大小调节
2. 额头宽窄调节
3. 美瞳佩戴
4. 墨镜佩戴
5. 法令纹变淡
6. 牙齿美白
7. 黑眼圈调节
8. 发际线调节
9. 发量调节

同时完善真人动态背景稳定性、头发/脸部边缘处理、美妆与遮挡一致性、CPU 工作迁移、芯片级加速选择、持续性能测试及 Demo 平台一致性。详见 [路线图](docs/ROADMAP.md)。

欢迎通过 Issues 提交设备信息、复现步骤、预期效果与相关日志；请避免上传未获授权的人像或账号凭据。Demo 和接入工具可提交 Pull Request，核心 SDK 以二进制版本更新。
