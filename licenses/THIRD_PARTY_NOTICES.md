# Third-party components

- MediaPipe Tasks Vision: Google, Apache-2.0. Current Android Maven coordinate `com.google.mediapipe:tasks-vision:0.10.28`; iOS CocoaPod `MediaPipeTasksVision 0.10.14`. Pinned 0.10.14 source and license are in `third_party/mediapipe/LICENSE`; 0.10.26 reference source is in `third_party/mediapipe-0.10.26`. The latter is not asserted to reproduce the Android 0.10.28 JNI binary. See `docs/delivery/DEPENDENCIES_MODELS.md` for exact source/binary availability.
- Models: official Google MediaPipe distribution, exact URLs and SHA-256 in `models/manifest.json`. Selfie Segmenter is the single-channel person model; Face Landmarker provides face geometry. Consult the corresponding upstream model documentation for model limitations and licensing.
- Qualcomm AI Hub model exports: W8A8 TFLite transformations of the Apache-2.0 MediaPipe Selfie Segmentation and Face Landmark models. Exact tool versions, tensor contracts, and hashes are recorded in `models/manifest.json`; Qualcomm QNN runtime components retain Qualcomm's bundled license and notice.
- metal-cpp: Apple, headers and license in `third_party/metal-cpp/LICENSE.txt`; exact archive pinned in manifest.
- Vulkan: Khronos API; build against Android NDK headers or the host Vulkan SDK. A compatible GPU driver is required; no GPU driver is redistributed.
- CameraX/AndroidX: Google/Android Open Source Project, Apache-2.0; declared in Gradle.
- `platforms/android/src/androidTest/assets/portrait.jpg`: upstream MediaPipe test asset from `https://storage.googleapis.com/mediapipe-assets/portrait.jpg`; used only for instrumentation, excluded from the released SDK.

Downloaded MediaPipe source is retained for API reference and potential custom graph development. Production mobile integration uses the official Tasks distributions; CMake does not pretend to build the Bazel project with FetchContent.
