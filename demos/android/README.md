# Android Demo

公开 Demo 仅依赖编译好的 SDK，通过本地 Maven 仓库解析 `com.moon.mediavision:mediavision-sdk:0.4.0`，不包含 SDK 实现模块。用 Android Studio 打开此目录，或在 JDK 17、Android SDK 35 环境下执行：

```bash
./gradlew :app:assembleDebug
```

APK 位于 `app/build/outputs/apk/debug/`。连接并授权 Android 设备后可执行 `./gradlew :app:installDebug`。首次启动需要允许相机权限。使用已编译安装包也可从仓库根目录的 `installers/android/` 获取。Release APK 未签名，正式分发须自行签名。

SDK 支持 API 26+，其中 API 29+ 相机路径使用 Camera2 → AHardwareBuffer / Vulkan 导入 → GPU 缩小分析图 → 人物和人脸模型 → Vulkan 效果 → SurfaceView。每个预览帧与其对应的分析时间戳配对。无需 NDK 或私有核心源码来构建此 Demo。

顶部单行控制栏显示帧率和分辨率；美颜总开关位于网格按钮之后。预览紧接控制栏下缘并顶部对齐。底部功能项保留 5dp 间隔，背景虚化为独立功能项，Mask 与换背景位于列表末尾。背景功能互斥；虚化支持 0–100 强度，100 对应此前基准强度的约 1.2 倍。其他美颜强度独立调节。

远程 Maven 引用和更新方法见 [Maven 文档](../../docs/MAVEN.md)，发布验证范围见 [分发验证](../../docs/VALIDATION.md)。本公开工程不包含 SDK 内部测试或核心编译任务。

This demo consumes the precompiled SDK from the bundled Maven repository. Open it in Android Studio or run `./gradlew :app:assembleDebug` with JDK 17 and Android SDK 35. It contains application integration code only. Release APKs require your own signing. See the linked Maven guide for remote consumption and upgrades.
