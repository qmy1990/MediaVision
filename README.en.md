# MediaVision · Moon

**A cross-platform SDK for real-time portrait effects**  
`com.moon.mediavision` · C++17 · C ABI 9 · Android / iOS / Windows / macOS / Linux

[简体中文（默认）](README.md) | English

MediaVision combines portrait analysis, beauty filters, face reshaping, makeup and background processing behind native integration APIs. Maintained by **Moon**, it provides platform adapters and a public C/C++ interface for the effects stage of camera, video, streaming and conferencing applications.

This repository publishes **demo source, integration code, public headers and build/distribution tools**, together with compiled SDK binaries and encrypted model packages. The core implementation and shader source are not published. Authored demos and integration material are MIT-licensed; Moon's SDK binaries are free to integrate into personal and commercial applications under the [binary SDK license](LICENSE.md). Third-party licenses continue to apply.

## Capabilities

| Area | Available features |
|---|---|
| Portrait and background | Person segmentation, adjustable background blur, image background replacement, mask visualization |
| Skin and image quality | Skin smoothing, blemish removal, skin tone adjustment, four tone presets, sharpening |
| Face reshaping | Eye enlargement, head scaling, face slimming, nose width, eye spacing, cheekbone adjustment |
| Makeup | Adjustable lipstick intensity and color, blush, eyebrow darkening |
| Accessories | Basic landmark-anchored triangle-mesh props, headwear and jewelry examples |
| Integration and diagnostics | Landmark/mesh overlays, backend selection, stage timings, C ABI, custom effect callbacks |

Vulkan and Metal handle rendering and image effects. Inference uses suitable GPU, NPU or CPU paths according to platform and device. Android includes QNN HTP, NNAPI and GPU paths with fallbacks; the Apple adapter exposes MediaPipe, Vision and Core ML options. Available backend settings do not establish NPU/ANE execution on every chipset.

The Android camera path imports AHardwareBuffer images, caches frames on the GPU and pairs analysis with the corresponding input before compositing. The Windows/Linux Python demo supports photos, videos and webcams. A small C++ CLI demonstrates direct native integration. Models and optimizations differ across platforms; pixel-identical output and equal performance are not promised.

## Effect comparisons

Click to view or download the supplied comparison videos:

| Effect | Video | Effect | Video |
|---|---|---|---|
| Beauty toggle | [View](docs/media/beauty-toggle.mp4) | Blemish removal | [View](docs/media/blemish-removal.mp4) |
| Eye enlargement | [View](docs/media/eye-enlargement.mp4) | Face slimming | [View](docs/media/face-slimming.mp4) |
| Nose reshaping | [View](docs/media/nose-reshaping.mp4) | Lipstick | [View](docs/media/lipstick.mp4) |
| Eyebrows | [View](docs/media/eyebrows.mp4) | Skin tone | [View](docs/media/skin-tone.mp4) |

These clips illustrate particular scenes, not all lighting conditions, skin tones, poses or devices. Temporal edges, occlusion, makeup stability and sustained performance remain active development areas.

## Download the complete distribution

SDK binaries, models and large installers use [Git LFS](https://git-lfs.com):

```bash
git lfs install
git clone https://github.com/qmy1990/MediaVision.git
cd MediaVision
git lfs pull
python3 tools/verify_distribution.py
```

GitHub source ZIP downloads may contain LFS pointers. Run `python3 tools/fetch_binary_assets.py` to retrieve manifest-listed binary files and validate SHA-256 hashes. A source ZIP alone is not guaranteed to contain all SDK assets.

| Directory | Contents |
|---|---|
| `sdk/` | Platform binaries, Android Maven repository, Apple XCFrameworks |
| `include/mvs/` | Public C/C++ interfaces |
| `models/` | Runtime packages, encrypted research archive and candidates |
| `demos/` | Android/iOS apps, desktop Python demo, C++ CLI |
| `installers/` | Android APKs and an unsigned iOS IPA |
| `tools/` | Demo builds, validation, downloads and distribution packaging |
| `docs/` | Integration guides, platform status, roadmap and videos |
| `licenses/` | Demo/SDK licensing and third-party notices |
| `manifest/` | Version, platform, model and file integrity metadata |

Ship only the runtime package appropriate for your application. Do not bundle the entire `models/research/` or `models/variants/` tree: these are independent research assets, not production-approved replacements.

## Android integration

Add the repository to `dependencyResolutionManagement.repositories` in `settings.gradle`, alongside `google()` and `mavenCentral()`:

```groovy
maven {
    url 'https://raw.githubusercontent.com/qmy1990/MediaVision/main/sdk/android/maven'
    content { includeGroup 'com.moon.mediavision' }
}
```

```groovy
implementation 'com.moon.mediavision:mediavision-sdk:0.4.0'
```

```java
import com.moon.mediavision.VisionSdk;
import com.moon.mediavision.VisionOptions;

VisionSdk sdk = new VisionSdk(context, VisionSdk.AUTO);
VisionOptions options = VisionOptions.builder()
    .beauty(0.55f).blemishRemoval(0.35f).build();
sdk.configure(options);
// Attach an output Surface and submit camera frames; see demos/android.
// Call sdk.close() when the camera/page is released.
```

The Camera AAR targets API 26+ and includes arm64-v8a, armeabi-v7a and x86. The standalone native core also offers x86_64, which is not a complete Java Camera SDK.

The public demo uses the local repository: `maven { url uri('../../sdk/android/maven') }`. With JDK 17 and Android SDK 35 configured, run `./gradlew :app:assembleDebug` in `demos/android`. All SDK runtime dependencies are declared in the POM; the SDK's proprietary source is not needed.

To upgrade, change the explicit dependency version to an available release. Avoid dynamic `+` versions. This is a GitHub-hosted static Maven repository, not a claim of publication to Maven Central or GitHub Packages. See [publishing and consumption](docs/MAVEN.md).

## iOS integration

Embed and sign `sdk/ios/MediaVisionSDK.xcframework`. For direct C/C++ integration, use `MediaVisionCore.xcframework`. Add `models/ios/mediavision.mvsmodels` to your application resources.

```objective-c
#import <MediaVisionSDK/MVSProcessor.h>

MVSProcessor *sdk = [[MVSProcessor alloc]
    initWithModelPackagePath:packagePath backend:MVS_METAL error:&error];
MvsOptions options = mvs_default_options();
options.beauty = 0.55f;
options.background = MVS_BACKGROUND_BLUR;
[sdk configure:options error:&error];
// Submit CVPixelBuffer frames synchronously or through submitPixelBuffer.
```

iOS 15+; device arm64 and simulator arm64/x86_64 are provided. The demo links binary SDKs only. Device installation requires your own Apple development signing configuration. The distributed unsigned IPA is not directly installable.

## C/C++ integration

Use `include/mvs/sdk.h`, or the lightweight RAII wrapper in `mvs.hpp`, and link the binary for your platform, architecture and toolchain.

```cpp
#include <mvs/sdk.h>

MvsConfig config = mvs_default_config();
MvsHandle engine = nullptr;
if (mvs_create(&config, &engine) == MVS_OK) {
  MvsOptions options = mvs_default_options();
  options.sharpen = 0.3f;
  mvs_set_options(engine, &options);
  // mvs_process(engine, &input, &output);
  mvs_destroy(engine);
}
```

Portrait/face effects require valid analysis. Supply an inference callback with `mvs_set_analyzer`, or provide matching frame analysis to `mvs_process_with_analysis`. Linking the core alone does not create camera capture or inference pipelines.

```bash
cmake -S . -B build/demo -DMEDIAVISION_SDK_ROOT=/path/to/platform/sdk
cmake --build build/demo --config Release
```

See [integration details](docs/INTEGRATION.md) and [platform status](docs/PLATFORMS.md) for runtime dependencies and ABI constraints.

## Validation and performance

Build and runtime status are recorded in `manifest/platforms.json`. Some Windows/Linux binaries are retained from previous delivery builds; cross-compilation does not substitute for target-device testing.

A recent Snapdragon 8 Gen 2 test measured 29.99 FPS on average at 1080×1920 with default effects over 30 seconds, using a **static portrait displayed on a screen**. This is not live-person or sustained thermal acceptance, and does not imply 30 FPS on every flagship device. The iPhone 8 Plus targets of 480p/30 FPS and 720p/25 FPS remain optimization goals.

## Roadmap

Planned additions, in order; none are announced as shipped:

1. Pupil size adjustment
2. Forehead width adjustment
3. Cosmetic contact lenses
4. Virtual sunglasses
5. Nasolabial fold reduction
6. Teeth whitening
7. Dark circle adjustment
8. Hairline adjustment
9. Hair volume adjustment

Ongoing work also covers temporal background stability, hair/face boundaries, makeup and occlusion consistency, moving CPU work to accelerators, device-specific backend selection, sustained benchmarks and platform demo parity. See [the roadmap](docs/ROADMAP.md).

Issues with device details and reproducible steps are welcome. Please avoid uploading unauthorized portraits or credentials. Pull requests may improve the public demos and integration tools; the proprietary core is updated through binary releases.
