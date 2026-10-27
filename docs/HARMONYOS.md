# HarmonyOS 接入 / HarmonyOS integration

最低 **HarmonyOS 6.0.0 / API 20**，SDK版本0.4.5，效果C ABI 11，包名 `com.moon.mediavision`，ArkTS模块 `@moon/mediavision`。

## 交付内容

| 文件 | 用途 |
|---|---|
| `sdk/harmonyos/har/mediavision-sdk-0.4.5.har` | ArkTS集成，包含两种架构的原生库 |
| `sdk/harmonyos/<ABI>/shared/lib/` | `libmvs_sdk.so`、`libmvs_harmony.so`、`libmediavision.so`、`libc++_shared.so` |
| `sdk/harmonyos/<ABI>/static/lib/libmvs_sdk.a` | 静态效果核心，可由宿主提供分析数据 |
| `include/mvs/harmonyos.h` | 模型、效果、PixelMap、YUV与原生相机C接口 |
| `models/harmonyos/mediavision.mvsmodels` | 加密的分割、人脸检测、Face478模型包 |
| `demos/harmonyos/` | ArkTS实时相机Demo源码 |
| `demos/harmonyos-native/` | 纯C接入示例与CMake配置 |
| `installers/harmonyos/MediaVisionDemo-api20-unsigned.hap` | 未签名Demo，需使用自己的签名安装 |
| `packages/harmonyos/MediaVision-harmonyos-0.4.5.zip` | 完整下载包，含文件SHA-256清单 |

ABI为 `arm64-v8a`、`x86_64`。鸿蒙使用专用OHOS库，不能复用Android的SO或AAR。

## ArkTS接入

在宿主 `oh-package.json5` 中引用HAR：

```json
{ "dependencies": { "@moon/mediavision": "file:./libs/mediavision-sdk-0.4.5.har" } }
```

模型包放入 `entry/src/main/resources/rawfile`。在UIAbility上下文中初始化：

```typescript
import { VisionSdk, VisionOptions } from '@moon/mediavision';
const bytes = await context.resourceManager.getRawFileContent('mediavision.mvsmodels');
const sdk = await VisionSdk.create(bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength));
const options = new VisionOptions();
options.beauty = 0.55;
options.whitening = 0.25;
await sdk.configure(options);
const result = await sdk.processPixelMap(inputPixelMap);
// 使用result.pixelMap；显示完成后由调用方释放。
await sdk.release();
```

RGBA可用 `processRgba(data,width,height,stride,time)`；NV21可用 `processNv21`；任意YUV420平面可用 `processYuv420`。所有帧时间戳严格递增，一个实例一次处理一帧；Promise完成前不能修改或释放输入。

## 实时相机接入

Demo采用 `CameraKit → OH_NativeBuffer → Vulkan → XComponent NativeWindow`。从XComponentController取得显示Surface ID，打开SDK输入Surface，再将返回的ID用于CameraKit输出：

```typescript
await sdk.setRealtime(true, 33);
const inputSurface = await sdk.openSurface(displaySurfaceId, profile.size.width, profile.size.height);
const preview = cameraManager.createPreviewOutput(profile, inputSurface);
// 将preview加入CameraKit session，commit后start；同一实例串行处理。
const frame = await sdk.processSurface(rotation, frontCamera, YuvColorSpace.BT709_LIMITED);
// frame.presented、width、height和stats可用于预览状态与统计。
// 先停止CameraKit生产者，并等待当前处理结束，再关闭消费端。
await sdk.closeSurface();
```

导入相机原生缓冲区后GPU完成YUV转换、旋转、镜像和效果，最终效果直接渲染到交换链图像。模型分析另有缩小图像读回与Tensor填充，不将整个链路称为完全零拷贝。退后台停止相机，切换摄像头时等待在途帧结束并reset。完整示例见 [LiveCamera.ets](../demos/harmonyos/entry/src/main/ets/camera/LiveCamera.ets)。

## C/C++接入

纯原生调用部署 `libmvs_sdk.so`、`libmvs_harmony.so` 及配套 `libc++_shared.so`，无需Java、ArkTS或N-API桥接库。使用同版本公共头文件：

```c
#include "mvs/harmonyos.h"
MvsHarmonyConfig cfg = mvs_harmony_default_config();
cfg.effects_backend = MVS_VULKAN;
cfg.inference_backend = MVS_HARMONY_NNRT;
MvsHarmonyHandle sdk = NULL;
MvsStatus status = mvs_harmony_create(&cfg, model_bytes, model_size, &sdk);
/* 检查status成功后再调用。 */
MvsOptions options = mvs_default_options(); options.beauty = 0.55f;
mvs_harmony_configure(sdk, &options);
MvsFrame in = {rgba, rgba_capacity, width, height, input_stride, MVS_RGBA8, timestamp_ms};
MvsOutput out = {output_rgba, output_capacity, output_stride, MVS_RGBA8};
status = mvs_harmony_process(sdk, &in, &out, NULL);
mvs_harmony_destroy(sdk);
```

输入输出容量须覆盖最后一个有效像素。模型与处理实例由创建它的线程串行使用。独立Tensor模型接口为 `model_create/model_tensor/model_invoke/model_destroy`；输出Tensor视图在下一次调用或销毁后失效。可借用 `mvs_harmony_effect_engine` 与公共核心接口扩展集成，但不能另行销毁借用句柄。

## Padding与平面布局

- RGBA/BGRA输入使用 `MvsFrame.stride_bytes`；输出使用 `MvsOutput.stride_bytes`，行尾padding保持原值。
- 连续NV21接口默认Y/VU共用行跨度，VU起点为 `row_stride_bytes*height`。
- `MvsHarmonyYuv420Frame` 可分别指定Y/U/V的 `data/size_bytes/offset_bytes/row_stride_bytes/pixel_stride_bytes`，支持NV12/NV21/I420视图。
- `mvs_harmony_camera_set_input_layout` / ArkTS `setSurfaceInputLayout` 可指定原生相机分配中的真实布局；NULL/undefined恢复驱动默认布局。在camera_open之后、开始处理之前调用。

```c
MvsHarmonyYuv420Layout layout = {0}; layout.struct_size = sizeof(layout);
layout.y_row_stride_bytes = 864; layout.y_pixel_stride_bytes = 1;
layout.v_offset_bytes = 864*480; layout.u_offset_bytes = 864*480+1;
layout.u_row_stride_bytes = layout.v_row_stride_bytes = 864;
layout.u_pixel_stride_bytes = layout.v_pixel_stride_bytes = 2;
mvs_harmony_camera_set_input_layout(sdk, &layout);
```

上例仅适用于明确以连续NV21写入的864×480缓冲区。ADA-AL00 / OS6.1.0.135的这组PreviewOutput报告896字节行跨度，但实际按864字节写入；Demo为该设备/版本采用显式布局GPU读取，修复旋转后480×864条纹。其他设备沿用默认布局，不全局猜测相机padding。Host内存YUV接口使用CPU颜色转换，模型推理仍为NNRT；实时相机优先原生Surface。

## 模型与转换工具

SDK使用系统MindSpore Lite C API。AUTO/NNRT只创建NNRT加速器会话，不执行CPU模型推理或CPU回退；不支持的模型编译/执行返回错误。效果使用Vulkan，与模型推理后端独立。

| ID | 模型 | 输入NHWC | 归一化 |
|---|---|---|---|
| 201 | 人像分割 | `[1,256,256,3]` float32 | RGB/255 |
| 202 | 人脸检测 | `[1,128,128,3]` float32 | (RGB−127.5)/127.5 |
| 203 | Face478 | `[1,256,256,3]` float32人脸ROI | RGB/255 |

加密包保存三个独立MindIR Lite `.ms` 数据段，不将三个网络融合为一个网络。已打包模型可直接使用；自有TFLite模型可在Linux x86_64通过工具转换：

```bash
python3 tools/convert_harmonyos_models.py \
  --tool-root /path/to/mindspore-lite-2.7.0-linux-x64 \
  --inputs /path/to/tflite-models --output /path/to/mindir-models \
  --nnrt-prelu-fix --flatc /path/to/flatc \
  --schema /path/to/mindspore-lite/schema/model.fbs
```

输入目录包含portrait/detector/landmarker.tflite。转换参数与修复步骤保存在脚本中；Face478逐通道PReLU修正 `channel_shared=false`，斜率形状改为 `[channels]`，常量字节不变。候选模型仍需设备验证。发行模型完成201组NNRT输出对照，记录见 [模型验证](../models/harmonyos/conversion-validation-2.7.json)。转换工具不会生成加密发布包。

## Demo构建与安装

使用最新官方DevEco Studio、配套HarmonyOS SDK/Hvigor/Node。项目的compatibleSdkVersion和targetSdkVersion保持 `6.0.0(20)`：

```bash
python3 tools/build_harmonyos_demo.py \
  --node /path/to/node \
  --hvigor /path/to/node_modules/@ohos/hvigor/bin/hvigor.js \
  --sdk-home /path/to/official/harmonyos/sdk
```

脚本把发布SDK与模型复制到生成工程，并构建HAR和HAP，不编译核心实现。使用DevEco Studio打开生成的目录，在Project Structure → Signing Configs配置自己的调试签名，再编译运行。分发的HAP未签名；不包含开发者证书或设备绑定的签名配置。

共享/静态SDK、HAR/HAP与两ABI的C示例编译通过；ARM64真机验证使用ADA-AL00 / OS6.1.0.135 / API24。x86_64为编译验证。纯C示例的CMake命令见 [原生示例](../demos/harmonyos-native/README.md)。

## English

HarmonyOS 6.0.0 / API20+ ships native ARM64/x86_64 SDK libraries, an ArkTS HAR, public C/C++ APIs, encrypted MindIR Lite models and a live-camera demo. Add the HAR as a local dependency and place the model package in app raw resources. Models use strict system MindSpore Lite/NNRT accelerator contexts; effects use Vulkan. Pure native integration does not require ArkTS or Java.

RGBA/BGRA input/output honors independent row strides. YUV420 accepts independent Y/U/V offsets and strides. Native camera buffers can use explicit layouts for GPU conversion when the producer's real layout differs from allocator metadata. Model analysis still involves image readback and Tensor preparation.

Build with official DevEco Studio tools and configure your own signing credentials before installing the unsigned HAP. The public build script assembles the demo using precompiled SDK binaries. ARM64/API24 device checks and ARM64/x86_64 compile checks are recorded separately.
