# 原生 C++ 示例

Windows、macOS、Linux共用此入口。只需要编译后的SDK和公开头文件，不依赖Java、Python或SDK算法源代码。

```bash
cmake -S demos/cli -B build-cli -DCMAKE_PREFIX_PATH=/path/to/sdk/platform/arch/shared
cmake --build build-cli --config Release
```

共享库会复制到可执行文件目录；macOS和Linux使用相对运行库搜索路径。也可将前缀改成同一架构的 `static` 目录，链接静态SDK。

```bash
mvs_demo_cli input.ppm sharpened.ppm
mvs_demo_cli input.ppm pupil.ppm 0.75 landmarks.txt
```

图像为P6 RGB PPM。瞳孔控制为0缩小、0.5原状、1放大，算法内部半径变化上限为±16.8%；输入关键点文件为478行归一化 `x y z`，必须与原图方向及镜像一致。此示例直接消费调用方提供的关键点，不执行模型推理。调整虹膜与中心瞳孔整体大小，固定眼睑轮廓。

完整接口与Android/iOS/鸿蒙示例见[瞳孔大小说明](../../docs/PUPIL_SIZE.md)。
