# 美瞳颜色预设与自定义颜色

Android、iOS、HarmonyOS Demo 提供以下29种美瞳颜色，顺序与 RGB 值一致。默认保持自然棕。颜色名称用于 Demo 选色；RGB 是本工程统一的预设取值，可按需要自定义。

| 颜色 | RGB（sRGB） |
|---|---|
| 纯黑色 | `0x000000` |
| 深棕色 | `0x3B2418` |
| 巧克力棕 | `0x5E3A25` |
| 自然棕 | `0x8C623E` |
| 浅棕色 | `0xB0825A` |
| 焦糖棕 | `0xA66B3D` |
| 蜂蜜棕 | `0xC69445` |
| 奶茶棕 | `0xA58A72` |
| 灰棕色 | `0x8A7A70` |
| 冷棕色 | `0x6E625E` |
| 暖棕色 | `0x9B684C` |
| 琥珀棕 | `0xB38B51` |
| 金棕色 | `0xB88A42` |
| 灰色 | `0x88959D` |
| 浅灰色 | `0xB6BCC4` |
| 蓝灰色 | `0x628DA8` |
| 绿灰色 | `0x7C9690` |
| 紫色 | `0x9381AC` |
| 香芋紫 | `0xB7A0CB` |
| 粉色 | `0xD58BA6` |
| 樱花粉 | `0xF2B4C8` |
| 蓝色 | `0x447DB8` |
| 深海蓝 | `0x1F466A` |
| 绿色 | `0x4F8867` |
| 橄榄绿 | `0x7C8961` |
| 酒红 | `0x6F283D` |
| 墨绿 | `0x204B3F` |
| 湖蓝 | `0x419EAE` |
| 白色 | `0xFFFFFF` |

SDK 接口接受任意 `0xRRGGBB`（0～0xFFFFFF），不限制在预设列表内。纯黑 `0x000000` 和纯白 `0xFFFFFF` 都是有效颜色。此处是虹膜材质的目标颜色，渲染仍保留瞳孔、眼睑遮挡、纹理和高光。

```java
// Android：自定义美瞳 RGB
VisionOptions options = currentOptions.toBuilder()
    .iris(0.8f).irisColor(0x13579B).build();
```

```objective-c
// iOS：将自定义颜色交给 MVSProcessor
MvsPortraitDetails details = mvs_default_portrait_details();
details.iris = 0.8f;
details.iris_color = 0x13579B;
[processor configurePortraitDetails:details error:&error];
```

```typescript
// HarmonyOS：自定义美瞳颜色，沿用现有 setOptions 调用提交
const options: VisionOptions = new VisionOptions();
options.iris = 0.8;
options.irisColor = 0x13579B;
```

C/C++ 同样通过 `MvsPortraitDetails.iris_color` 和 `mvs_set_portrait_details()` 提交。预设清单保存在 `demos/iris_colors.json`。
