# 瞳孔大小 / Iris and pupil size

控制虹膜与中心瞳孔整体大小，保持眼睑和眼睛外轮廓。独立于“大眼”和美瞳换色；可与美瞳、眼神光、美颜叠加。滑杆0–100，50为原状；接口0–1，0.5为原状，0缩小、1放大。虹膜充分可见时目标半径约为原始的0.832–1.168倍，即缩小和放大的最大变化幅度均为原方案的60%。这一上限在SDK内部的CPU、Metal和Vulkan算法中统一限制，Demo保持完整0–100范围；遮挡和低置信度时继续缩小变形幅度。

```java
sdk.configure(options.toBuilder().pupilSize(0.75f).build());
```

```cpp
MvsEyeGeometry eyes = mvs_default_eye_geometry();
eyes.pupil_size = 0.75f;
MvsStatus status = mvs_set_eye_geometry(engine, &eyes);
// mvs::Engine wrapper: engine.setEyeGeometry(eyes);
```

```objc
MvsEyeGeometry eyes = mvs_default_eye_geometry();
eyes.pupil_size = 0.75f;
BOOL success = [processor configureEyeGeometry:eyes error:&error];
```

```typescript
options.pupilSize = 0.75;
await sdk.configure(options);
```

```bash
python desktop_demo.py --input portrait.jpg --output result.jpg --pupil-size 0.75
```

Windows、macOS、Linux 使用相同 C/C++ 接口；桌面图片、视频和摄像头 Demo 均支持 `--pupil-size`，摄像头界面的 `pupil_size` 滑杆仍为0–100，中性值50。与美瞳、眼神光组合可同时传入 `--iris 1 --catchlight 0.55`。

无Python依赖的C++命令行示例支持调用方提供478个归一化关键点（每行 `x y z`，与输入图同方向、同镜像）：
```bash
mvs_demo_cli input.ppm output.ppm 0.75 landmarks.txt
```
该入口不执行模型推理；自行提供关键点即可验证SDK缩放。macOS使用此原生入口和Metal；完整Python相机示例面向Windows/Linux。

鸿蒙原生使用 `mvs_harmony_configure_eye_geometry(processor, &eyes)`。自行提供分析时，将 `mvs_eye_geometry_analysis_requirements(&eyes)` 和其他效果分析需求按位合并，提供同帧、同方向、同镜像的478点。没有人脸、只有468点、闭眼或虹膜不可信时保持原图，不根据眼角猜测虹膜。

使用现有虹膜拟合和时序稳定结果，在眼部GPU区域内计算逆向径向采样。缩放在虹膜边缘外向原坐标平滑过渡，通过单调三次插值固定当前眼睑交点，使源采样始终留在可见眼球内；虹膜中心被遮挡时仍可处理可见圆弧。CPU、Metal和Vulkan使用同一公式；不新增模型、全帧遮罩、GPU读回或独立全帧pass。0.5时关闭分支。

Android、鸿蒙和Windows/Linux使用Vulkan；iOS、macOS使用Metal。眼部区域外通过专用管线跳过相关计算，缩放、美瞳和眼神光在同一渲染通道内组合；480字节GPU参数区不增加。新上限统一限制在各后端的算法内部，无需由上层缩减滑杆值。

`MvsOptions`维持104字节，`MvsPortraitDetails`维持24字节；新增独立8字节 `MvsEyeGeometry`，效果ABI保持11。已有程序不调用新接口时保持原有行为。Java/JNI兼容旧14/17项参数并新增18项；需要新库才能使用新接口。

## English

Scales the iris and central pupil together inside the current eyelids, preserving the outer eye contour. Values range from 0 to 1: 0.5 is identity,0 smaller,1 larger. For a fully visible, trusted iris, the target radius ranges from 0.832x to 1.168x: both endpoint changes are 60% of the original amplitude. The SDK enforces this limit in CPU, Metal and Vulkan while Demo sliders keep their full 0–100 range. This is independent of eye enlargement, contact-lens color and catchlights. It reuses Face478 iris fitting and temporal stabilization, uses local inverse sampling in the existing render pass, and adds no model or full-frame readback. Missing/untrusted iris or blinking suppresses the warp. All six platforms share the same control. The new 8-byte extension preserves both published options structures and ABI 11.
