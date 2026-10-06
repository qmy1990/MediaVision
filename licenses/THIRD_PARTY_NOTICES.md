# 第三方组件 / Third-party components

第三方授权不被 Moon SDK 授权替代。以下是本次二进制分发所涉及的主要组件；平台运行库自身附带的 notices 同样适用。

- **MediaPipe Tasks Vision / Tasks Common**：Google，Apache-2.0。Android 使用 `com.google.mediapipe:tasks-vision:0.10.28`；iOS 使用 0.10.14。原始许可保存在 `licenses/third-party/MediaPipe*-LICENSE.txt`。SDK 不宣称包含从公开 Demo 可重建这些上游二进制的源码。
- **Google LiteRT**：Google，Apache-2.0；Android 运行依赖由 Maven POM 声明，版本 1.4.2。上游组件与传递依赖保留各自声明。
- **Qualcomm QNN**：Qualcomm 专有运行库，受其原始授权约束，见 `licenses/third-party/qnn/QUALCOMM_LICENSE.pdf` 和 `NOTICE.txt`。Maven 依赖使用 2.45.0。
- **模型**：生产模型、变体及研究归档的来源资料见 `docs/MODEL_MANIFEST.json`、`manifest/models.json`。包括官方 MediaPipe 模型、Qualcomm AI Hub 转换、MODNet、SlimNet 和人脸解析研究模型。研究模型未被统一重新许可为 MIT 或 Moon SDK 免费商用；使用者须遵循各自上游权重、数据集及转换分发条款，不能把代码许可证等同于训练数据或权重的授权。
- **metal-cpp**：Apple，Apache-2.0，见 `licenses/third-party/metal-cpp-LICENSE.txt`。构建时使用，公共 SDK 不附带其头文件实现。
- **Vulkan**：Khronos API；运行需要兼容 GPU 驱动，不分发 GPU 驱动。Android 使用平台 NDK 接口。
- **AndroidX / MediaPipe 传递依赖**：由 Demo Gradle 与 SDK POM 解析，保留上游许可证。
- **ONNX Runtime / DirectML**：Windows/Linux 桌面运行库保留原始 `LICENSE` 和 `ThirdPartyNotices.txt`，见 `dependencies/desktop-runtime/`。版本和二进制哈希见该目录中的 `runtime-manifest.json`。
- **Zig**：部分此前桌面构建使用该工具链，保留 `licenses/third-party/zig/LICENSE`。
- **Gradle Wrapper**：Gradle，Apache-2.0；公开 Android Demo 保留上游 Wrapper 与其文件声明。

Third-party software, model weights and datasets retain their original terms. The SDK binary integration license grants rights to Moon-authored SDK components, not a replacement license for upstream components. Research packages are separate from production assets and do not establish unrestricted commercial rights to every model. Preserve the bundled upstream license and notice files when redistributing relevant components.
