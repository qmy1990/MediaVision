# Windows / Linux 桌面 Demo

使用已编译的 native SDK、加密模型包和 ONNX Runtime，支持图片、视频、摄像头：

```bash
python3 -m pip install -r demos/desktop/requirements.txt
python3 demos/desktop/desktop_demo.py --input input.jpg --output output.png --background blur
python3 demos/desktop/desktop_demo.py --input input.mp4 --output output.mp4 --maximum 1280
python3 demos/desktop/desktop_demo.py --input camera:0 --maximum 1280
```

可通过 `--sdk`、`--runtime`、`--models` 指定对应平台路径，其他选项见 `--help`。默认使用 Windows x64 或 Linux x86_64/aarch64；其他架构应使用 native C/C++ 入口及匹配推理 provider。当前 Python Demo 不默认支持 macOS；macOS 使用根目录 CMake / CLI 示例。

This demo links prebuilt native binaries, supplies face inference and uses the native matting adapter. It does not compile the SDK core or shader source. See [platform constraints](../../docs/PLATFORMS.md) and [integration](../../docs/INTEGRATION.md).
