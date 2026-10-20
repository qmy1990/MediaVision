# Android native runtimes · 0.4.4

LiteRT 1.4.2 CPU/GPU and NDK 27 C++ runtime binaries are supplied for four Android ABIs. QNN 2.45 HTP host, stub, prepare, system and skeleton libraries are optional and arm64-only. Use matching ABI libraries with `sdk/android/camera-native/<ABI>/libmvs_inference.so`. Maven apps resolve the same dependencies automatically.

See [Android native integration](../../../docs/ANDROID_NATIVE.md) and [third-party licenses](../../../licenses/THIRD_PARTY_NOTICES.md). Skeleton files must be accessible on disk; pass their absolute directory through `qnn_skeleton_dir`. CPU/GPU standalone consumers do not require QNN or a JVM.
