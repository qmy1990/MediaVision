# HarmonyOS Demo

最低API20（HarmonyOS 6.0.0），使用实时相机、MindSpore Lite/NNRT推理和Vulkan效果渲染。

“瞳孔大小”滑杆为0–100，50原状，整体调整虹膜与中心瞳孔，保持眼睑轮廓。ArkTS设置 `options.pupilSize = 0.75` 后调用 `await sdk.configure(options)`；C/C++使用 `mvs_harmony_configure_eye_geometry()`。两端最大半径变化统一限制为±16.8%，与Android/iOS保持一致。

复用现有Face478模型、虹膜拟合和Vulkan眼部区域渲染，可叠加美瞳和眼神光，不增加模型或全帧遮罩。HAR、原生头文件与接口用法见[瞳孔大小接入](../../docs/PUPIL_SIZE.md)。HAP真机安装需要自己的调试签名。
