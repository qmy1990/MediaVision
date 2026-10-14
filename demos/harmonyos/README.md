# MediaVision HarmonyOS Demo

最低 **HarmonyOS 6.0.0 / API20**。Demo使用相机实时预览，支持前后摄像头、480p/720p/1080p、效果强度、关键点、网格及腮红颜色/鼻尖模式。模型使用NNRT/NPU，效果使用Vulkan。

使用最新官方DevEco Studio打开本目录，通过仓库根目录的 `tools/build_harmonyos_demo.py` 将SDK二进制与模型复制到构建目录；该工具仅构建上层Demo。然后在DevEco Studio打开生成的工程，为自己的设备配置签名并运行。依赖目录、HAR引用、相机生命周期和C接口见 [接入指南](../../docs/HARMONYOS.md)。预编译 [HAP](../../installers/harmonyos/MediaVisionDemo-api20-unsigned.hap) 未签名，不能直接免签安装。

Minimum **HarmonyOS 6.0.0 / API20**. The live-camera demo supports front/rear cameras, resolutions, effect strengths, landmarks/mesh, and blush presets. Run `tools/build_harmonyos_demo.py` from the repository root to stage binary SDK/model dependencies and build the app. Open the generated project in official DevEco Studio, configure your own device signature, and run. The distributed HAP is unsigned. See the integration guide for details.
