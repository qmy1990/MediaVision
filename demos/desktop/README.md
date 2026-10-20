# Windows / Linux 桌面 Demo

使用已编译的 native SDK、加密模型包和 ONNX Runtime，支持图片、视频、摄像头：

```bash
python3 -m pip install -r demos/desktop/requirements.txt
python3 demos/desktop/desktop_demo.py --input input.jpg --output output.png --background blur
python3 demos/desktop/desktop_demo.py --input input.mp4 --output output.mp4 --maximum 1280
python3 demos/desktop/desktop_demo.py --input camera:0 --maximum 1280
```

SDK 自动选择当前进程对应的架构，亦可通过 `--sdk`、`--runtime`、`--models` 指定路径。仓库附带的 Python/推理运行库以 Windows x64、Linux x86_64/aarch64 为主，其他架构需提供匹配的 Python、MediaPipe 与 ONNX Runtime，或使用 C/C++ 入口和自己的推理 provider。macOS 使用根目录 CMake / CLI 示例。

0.4.4 支持 `--whitening`、`--beauty`、`--blush`（0–1），腮红模式 `--blush-mode cheeks|cheeks-nose` 和 RGB 色值 `--blush-color F4A18F`。例如：

```bash
python3 demos/desktop/desktop_demo.py --input input.jpg --output output.png \
  --background original --beauty 1 --whitening 1 --blemish 0 \
  --blush 0.5 --blush-mode cheeks-nose --blush-color F4A18F
```

Native SDK selection follows the process architecture. Other architectures need matching Python and inference runtimes, or a C/C++ inference provider. Version 0.4.4 exposes whitening, smoothing, blush intensity, cheeks/nose-tip modes, and custom RGB shades through the same ABI 11 options.

This demo links prebuilt native binaries, supplies face inference and uses the native matting adapter. It does not compile the SDK core or shader source. See [platform constraints](../../docs/PLATFORMS.md) and [integration](../../docs/INTEGRATION.md).
