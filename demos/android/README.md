# Android Demo

Open this directory in Android Studio. The `:sdk` module points to `../../platforms/android` and is reusable separately.

Run `../../tools/build_android.ps1` on the configured Windows host, or `gradlew assembleDebug` after running the dependency preparation script. Current API 29+ camera path: Camera2 ImageReader → AHardwareBuffer/Vulkan import → small GPU analysis image → person and face model workers → native Vulkan effects → SurfaceView. Processing runs off the UI thread, and each displayed image uses analysis from its exact retained camera timestamp.

UI exposes beauty, enhance, prop, headwear, jewelry, beauty strength, and independent background blur/mask/replace items. SDK also accepts a caller-supplied background Bitmap and mesh.

Background blur is the first item in the bottom effect list, with the same
on/off switch and 0–100 slider as the beauty controls. Mask and background replacement are independent final items in the bottom list.
Selecting one turns off the other background effects. Zero/off restores the original background;
enabling restores the previous nonzero strength. Both mobile demos map strength
to `round(24 * 1.2 * strength / 100)` pixels (minimum 1 when active): the default
83 keeps the previous radius 24, and 100 uses radius 29. The integer SDK radius
rounds the requested 28.8-pixel maximum. Other beauty strengths are independent.

Tests: `gradlew :sdk:connectedDebugAndroidTest` requires a booted device/emulator. They run real MediaPipe inference on a bundled portrait and test CPU and Vulkan effects separately. See root `docs/VALIDATION.md` for the actual verification status.

SM8850 performance diagnosis and live measurements are documented in
[`ANDROID_SM8850_PERFORMANCE.md`](../../docs/ANDROID_SM8850_PERFORMANCE.md).
The renderer retains valid scaled `SUBOPTIMAL` presents; the measured SM8850
path starts next-frame inference before rendering the previous paired frame.


## 2026-10-06 紧凑界面

顶部使用 40dp 单行控制栏，只显示实际帧率与分辨率，旁边依次为美颜总开关、相机切换、分辨率、关键点、网格按钮。底部保留背景虚化强度滑杆（0–100，100 对应原强度的1.2倍），取消背景模式菜单，Mask 和换背景为列表末尾的独立开关项。三种背景效果互斥，重新开启虚化可恢复之前的强度。Android 功能项之间固定留5dp间隔，iOS为5pt。

预览上边缘紧接顶部40dp/pt控制栏下边缘，画面按比例适配并顶部对齐，不在控制栏与相机画面之间保留居中产生的空白。底部功能栏继续叠加在预览上。
