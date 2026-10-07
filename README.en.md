# MediaVision · Moon

**A cross-platform SDK for real-time portrait effects**  
Android / iOS / Windows / macOS / Linux · `com.moon.mediavision`

[中文](README.md) | English

MediaVision brings beauty filters, face reshaping, makeup and background effects to mobile and C/C++ applications, including camera previews, video, live streaming and conferencing.

**The released SDK is free for commercial use.**

## Features and plans

“Refining” means the feature is available and its quality or performance is being improved. Planned features follow the order below.

| Area | Feature | Status | Next improvement |
|---|---|---|---|
| Background | Person segmentation | Available | Hair and motion edges |
| Background | Adjustable background blur | Refining | Temporal stability and face boundaries |
| Background | Image background replacement | Available | Occlusion and color blending |
| Background | Mask visualization | Available | Preview and diagnostics |
| Background | Mask smoothing | Available | Stability versus latency |
| Skin | Skin smoothing | Available | Retain skin texture |
| Skin | Blemish removal | Refining | Mobile parity and GPU efficiency |
| Skin | Whitening | Available | Natural tone and regional protection |
| Skin | Natural / cool / rosy / tan presets | Available | Lighting and skin-tone coverage |
| Image | Sharpening | Available | Noise and edge control |
| Reshaping | Eye enlargement | Available | Pose and eye-region protection |
| Reshaping | Head scaling | Refining | Blur boundaries and halos |
| Reshaping | Face slimming | Available | Natural moving contours |
| Reshaping | Nose width | Available | Profile views and local warping |
| Reshaping | Eye spacing | Available | Extreme settings and pose stability |
| Reshaping | Cheekbone adjustment | Refining | Alignment with background boundaries |
| Makeup | Lipstick, colors and intensity | Refining | Lip boundaries and occlusion |
| Makeup | Blush | Available | Placement and natural blending |
| Makeup | Eyebrow darkening | Available | Hair detail and occlusion |
| Accessories | Basic mesh props | Basic | More models and materials |
| Accessories | Headwear | Basic | Pose tracking and occlusion |
| Accessories | Jewelry | Basic | Anchors and temporal stability |
| Diagnostics | Face landmarks | Available | Accuracy and tracking stability |
| Diagnostics | Face mesh overlay | Available | Display efficiency and occlusion |
| Demo | Master toggle / per-effect intensity | Available | Consistent controls |
| Demo | FPS / resolution / camera switching | Available | Sustained performance and preview |
| Input | Images / video / camera | Available | Platform input pipelines |
| Integration | Android / iOS / Windows / macOS / Linux | Distributed | Effect parity across platforms |
| Integration | C / C++ and mobile APIs | Available | Examples and wrappers |
| Integration | Custom effect callbacks | Available | Extension APIs and examples |
| Acceleration | GPU rendering and processing | Available | Fewer copies and less CPU work |
| Acceleration | Inference backends / chipset tuning | In progress | NPU / GPU models and fallbacks |
| Performance | Realtime on older iPhones | Refining | 480p/30 FPS and 720p/25 FPS targets |
| Planned 1 | Pupil size | Planned | Precise pupil-region scaling |
| Planned 2 | Forehead width | Planned | Natural contour and hairline transitions |
| Planned 3 | Colored contact lenses | Planned | Texture fit and eyelid occlusion |
| Planned 4 | Sunglasses | Planned | Pose tracking and realistic occlusion |
| Planned 5 | Nasolabial fold reduction | Planned | Local texture preservation |
| Planned 6 | Teeth whitening | Planned | Tooth isolation and natural brightening |
| Planned 7 | Dark circle reduction | Planned | Blend with surrounding skin |
| Planned 8 | Hairline adjustment | Planned | Natural hair boundaries |
| Planned 9 | Hair volume | Planned | Hair structure and temporal stability |

## Effect comparisons

Looping GIFs play directly below and preserve the original comparison sequence.

| Preview | Preview |
|---|---|
| **Beauty toggle**<br><img src="docs/media/beauty-toggle.gif" width="300" alt="Beauty toggle"> | **Blemish removal**<br><img src="docs/media/blemish-removal.gif" width="300" alt="Blemish removal"> |
| **Eye enlargement**<br><img src="docs/media/eye-enlargement.gif" width="300" alt="Eye enlargement"> | **Face slimming**<br><img src="docs/media/face-slimming.gif" width="300" alt="Face slimming"> |
| **Nose reshaping**<br><img src="docs/media/nose-reshaping.gif" width="300" alt="Nose reshaping"> | **Lipstick**<br><img src="docs/media/lipstick.gif" width="300" alt="Lipstick"> |
| **Eyebrows**<br><img src="docs/media/eyebrows.gif" width="300" alt="Eyebrows"> | **Skin tone**<br><img src="docs/media/skin-tone.gif" width="300" alt="Skin tone"> |

## Android integration

Keep `google()` and `mavenCentral()`, then add:

```groovy
// settings.gradle → dependencyResolutionManagement.repositories
maven { url 'https://raw.githubusercontent.com/qmy1990/MediaVision/main/sdk/android/maven' }

// app/build.gradle
implementation 'com.moon.mediavision:mediavision-sdk:0.4.0'
```

The Java package is `com.moon.mediavision`:

```java
VisionSdk sdk = new VisionSdk(context, VisionSdk.AUTO);
sdk.configure(VisionOptions.builder()
    .beauty(0.55f).blemishRemoval(0.35f).build());
```

See the [Android demo](demos/android) for camera integration and the [integration instructions](docs/MAVEN.md) for complete configuration. Android API 26+.

## iOS / C++ integration

**iOS 15+**: add `sdk/ios/MediaVisionSDK.xcframework` with Embed & Sign, include `models/ios/mediavision.mvsmodels` in app resources, and run the [iOS demo](demos/ios) with your own signing team.

**C / C++**: link the platform binary with public headers from `include/mvs/`. Start with the [C++ example](demos/cli/main.cpp).

See the [integration guide](docs/INTEGRATION.md) and [platform status](docs/PLATFORMS.md) for details.

## Download SDKs and demos

Install [Git LFS](https://git-lfs.com), then download the complete distribution:

```bash
git lfs install
git clone https://github.com/qmy1990/MediaVision.git
```

SDKs are in `sdk/`, demos in `demos/`, and installers in `installers/`. Source ZIP download instructions are in the [integration guide](docs/INTEGRATION.md).
