# 接口说明 / API guide · 0.4.2

Android/iOS 相机 SDK 提供模型推理与 GPU 效果处理；原生 C/C++ core 由宿主提供对应帧的分析数据。初始化、输入格式及资源生命周期见 [集成指南](INTEGRATION.md)。

## Android

```groovy
implementation 'com.github.qmy1990:MediaVision:0.4.2'
```

```java
VisionOptions options = new VisionOptions.Builder()
    .beauty(.55f).whitening(.25f).blemishRemoval(.35f)
    .blush(.50f)
    .blushMode(VisionOptions.BLUSH_CHEEKS_AND_NOSE)
    .blushColor(VisionOptions.BLUSH_PEACH_PINK)
    .build();
sdk.configure(options);
// 仅改变妆色，保留原有强度和模式。
sdk.configure(options.toBuilder().blushColor(0xE88D9F).build());
```

`VisionOptions` 为不可变对象，`defaults()` 返回中性配置；用 `toBuilder()` 更新部分选项。常规效果强度为 0–1，0 关闭、1 最大；Demo 使用 0–100 显示。

| Java Builder | C / Objective-C 字段 | 用途 / Purpose |
|---|---|---|
| `beauty()` | `beauty` | 磨皮 / Skin smoothing |
| `whitening()` | `whitening` | 美白 / Whitening |
| `sharpen()` | `sharpen` | 锐化 / Sharpening |
| `blemishRemoval()` | `blemish_removal` | 祛痘 / Blemish removal |
| `eyeEnlarge()` | `eye_enlarge` | 大眼 / Eye enlargement |
| `faceSlim()` | `face_slim` | 瘦脸 / Face slimming |
| `smallHead()` | `small_head` | 小头 / Head scaling |
| `noseSlim()` | `nose_slim` | 鼻翼调节 / Nose width |
| `eyeSpacing()` | `eye_spacing` | 眼间距，0.5 中性 / Eye spacing, 0.5 neutral |
| `cheekboneReduce()` | `cheekbone_reduce` | 颧骨，0.5 中性 / Cheekbones, 0.5 neutral |
| `lipstick()` / `lipstickColor()` | `lipstick` / `lipstick_color` | 口红强度及 RGB / Lipstick intensity and RGB |
| `blush()` / `blushColor()` | `blush` / `blush_color` | 腮红强度及 RGB / Blush intensity and RGB |
| `blushMode()` | `blush_mode` | 腮红模式 / Blush mode |
| `eyebrowDarkening()` | `eyebrow_darkening` | 眉毛加深 / Eyebrow darkening |
| `skinTone()` | `skin_tone` | 自然白、冷白、红润、美黑 / Skin-tone preset |
| `background()` / `blurRadius()` | `background` / `blur_radius` | 背景模式及虚化半径 / Background mode and blur radius |
| `maskSmoothing()` | `mask_smoothing` | 遮罩平滑 0–0.95 / Mask smoothing |
| `debugLandmarks()` / `debugFaceMesh()` | `debug_landmarks` / `debug_face_mesh` | 关键点、网格显示 / Diagnostic overlays |

## C / C++ 与 iOS

```cpp
MvsOptions options = mvs_default_options();
options.blush = .5f;
options.blush_mode = MVS_BLUSH_CHEEKS_AND_NOSE;
options.blush_color = MVS_BLUSH_PEACH_PINK;
MvsStatus status = mvs_set_options(engine, &options);
```

```objc
MvsOptions options = mvs_default_options();
options.blush = .5f;
options.blush_mode = MVS_BLUSH_CHEEKS_AND_NOSE;
options.blush_color = MVS_BLUSH_PEACH_PINK;
NSError *error = nil;
BOOL success = [processor configure:options error:&error];
```

两种模式：`MVS_BLUSH_CHEEKS` / `VisionOptions.BLUSH_CHEEKS` 为脸颊；`MVS_BLUSH_CHEEKS_AND_NOSE` / `VisionOptions.BLUSH_CHEEKS_AND_NOSE` 为脸颊＋鼻尖。默认脸颊模式、苹果红颜色、强度0。模式、颜色和强度独立，换色不修改腮红范围与渐淡。0.4.2 所有平台均支持网格腮红渐变、鼻尖模式及 RGB 妆色；换色不改变空间范围。各平台使用相同的参考美白、磨皮公式；CPU、Metal、Vulkan 的采样和数值精度可能产生少量像素差异。

## 腮红颜色 / Blush shades

`blushColor(int rgb)` / `blush_color` 接受 24 位 `0xRRGGBB`，没有 Alpha；非法高位会返回配置错误。下列 C 常量在 Java 中去掉 `MVS_` 前缀即可使用。最终显示受光照、肤色和强度影响，保留原有明暗与纹理。

| 名称 / Shade | C constant | RGB |
|---|---|---|
| 樱花粉 / Sakura pink | `MVS_BLUSH_SAKURA_PINK` | `0xF3A6BA` |
| 蜜桃粉 / Peach pink | `MVS_BLUSH_PEACH_PINK` | `0xF4A18F` |
| 玫瑰粉 / Rose pink | `MVS_BLUSH_ROSE_PINK` | `0xD96D8F` |
| 芭比粉 / Barbie pink | `MVS_BLUSH_BARBIE_PINK` | `0xEA70AA` |
| 冷调粉 / Cool pink | `MVS_BLUSH_COOL_PINK` | `0xD982B3` |
| 蜜桃橘 / Peach orange | `MVS_BLUSH_PEACH_ORANGE` | `0xF29D68` |
| 珊瑚橘 / Coral orange | `MVS_BLUSH_CORAL_ORANGE` | `0xF18373` |
| 杏色 / Apricot | `MVS_BLUSH_APRICOT` | `0xDEA281` |
| 苹果红 / Apple red | `MVS_BLUSH_APPLE_RED` | `0xEB5263` |
| 草莓红 / Strawberry red | `MVS_BLUSH_STRAWBERRY_RED` | `0xE65D7D` |
| 浆果红 / Berry red | `MVS_BLUSH_BERRY_RED` | `0xAE4E78` |
| 裸杏 / Nude apricot | `MVS_BLUSH_NUDE_APRICOT` | `0xC79380` |
| 奶茶 / Milk tea | `MVS_BLUSH_MILK_TEA` | `0xBE907C` |
| 豆沙 / Bean paste | `MVS_BLUSH_BEAN_PASTE` | `0xB97983` |

## 兼容与检查 / Compatibility

所有平台 0.4.2 使用 C ABI 11。始终使用 `mvs_default_config()`、`mvs_default_options()` 初始化并保留 `struct_size`；头文件和库必须配套，旧 C/C++ 调用方需重新编译。平台架构与链接方式见 [PLATFORMS.md](PLATFORMS.md)。调用失败时检查 `MvsStatus`；Android 封装和 iOS `NSError` 提供配置或处理错误。

Android/iOS camera wrappers include inference and GPU processing. Native core callers supply synchronized analysis. Strengths are normally 0–1, with 0.5 neutral for eye spacing and cheekbones. Blush intensity, mode, and 24-bit RGB are independent. All 0.4.2 libraries require matching ABI 11 headers. Every platform supports the landmark-aligned blush regions, nose-tip mode, and RGB shades, with shared reference whitening and smoothing equations. Sampling and numerical precision may cause small pixel differences between backends.

## 桌面 Python Demo / Desktop Python demo

```bash
python demos/desktop/desktop_demo.py --input portrait.jpg --output output.jpg \
  --background original --beauty 1 --whitening 1 --blemish 0 \
  --blush 0.5 --blush-mode cheeks-nose --blush-color F4A18F
```

`--blush-mode cheeks` 为脸颊模式；`--blush-color` 为十六进制 RGB。Python `Options` 同步至 ABI 11；加载旧 ABI 时会先拒绝初始化，避免结构体尺寸不匹配。桌面模型分析与运行库安装见 Demo 的说明。
