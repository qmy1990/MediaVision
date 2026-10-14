# HarmonyOS C consumer

Only public C headers and OHOS binaries are used. API20+; no ArkTS/Java/JNI. Build and runtime prerequisites: [HARMONYOS.md](../../docs/HARMONYOS.md).

示例使用严格NNRT/NPU模型推理与Vulkan效果。运行需要完整加密模型包和支持NNRT的HarmonyOS设备；x86_64版本仅完成编译验证。

```bash
cmake -S demos/harmonyos-native -B build/harmonyos-native \
  -DCMAKE_TOOLCHAIN_FILE="$OHOS_NATIVE/build/cmake/ohos.toolchain.cmake" \
  -DOHOS_ARCH=arm64-v8a -DOHOS_PLATFORM_LEVEL=20
cmake --build build/harmonyos-native
```

对原生模型/效果接口进行App内集成时，部署 `libmvs_sdk.so`、`libmvs_harmony.so` 和配套 `libc++_shared.so`；不需要ArkTS N-API桥接库。用同版本公共头文件编译调用方。RGBA/YUV输入、padding与相机Surface示例见接入指南。

The example requests strict NNRT/NPU inference and Vulkan effects. Deploy the core, HarmonyOS adapter, and matching C++ runtime when embedding it in an app; the ArkTS N-API bridge is optional for pure native callers. x86_64 is compile-tested only.
