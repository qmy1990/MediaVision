# 0.4.6 分发验证 / Distribution validation

发布日期：2026-11-21。SDK0.4.6，效果C ABI11。

新增瞳孔大小调节，整体调整虹膜与中心瞳孔，保持眼睛轮廓。Demo0–100、50原状，API0–1、0.5原状，SDK内部最大半径变化±16.8%。Android/iOS/鸿蒙Demo及Windows/macOS/Linux C/C++接口同步。

发布前核对所有平台SDK、公开头文件、Demo及安装包版本与校验值，保留历史Maven版本。iOS和鸿蒙安装包需自行签名。各平台构建、接口和分发结果在发布完成后记录；交叉编译不代表所有机型已运行验收。

功能本地验证：55张图片、3段视频共360帧，16项C/C++回归；中性值及原有美瞳/眼神光/人中效果保持一致，6组眼部区域优化与完整渲染像素差0。此为固定图片/视频验证，没有新增手机帧率结论。

## JitPack

坐标：`com.github.qmy1990:MediaVision:0.4.6`。发布后核对远程POM、AAR与公开Android Demo的依赖解析。

## English

SDK0.4.6 adds iris and pupil size adjustment across all six platforms, reusing the existing models and GPU eye-region rendering. Public headers, binaries, demos and installers are updated together. Fixed-image/video validation does not imply runtime acceptance on every device. iOS and HarmonyOS installers require the integrator’s signing credentials. Release and remote artifact checks are recorded below once completed.

## 发布包检查 / Package verification

| 平台 | 0.4.6检查结果 |
|---|---|
| Android | 四ABI AAR及原生SDK；公开Demo Debug/Release构建通过；APK/AAR库一致，16KB对齐、Debug签名通过 |
| iOS | 真机arm64及双架构模拟器Core/SDK XCFramework；公开Demo两端编译通过，IPA版本0.4.6、编译号10 |
| HarmonyOS | API20+双架构共享/静态SDK、HAR、公开相机Demo及HAP编译通过；模型和库加载段匹配，API19拒绝 |
| Windows/Linux/macOS | 18组共享/静态SDK及公开C++消费者构建通过；Intel Mac示例运行通过 |
| 接口与效果 | C ABI11及原有结构保持不变；16项原生回归通过；发布库与已验收缩放算法18组图片对照像素完全一致 |

All platform SDKs and binary-only demo consumers build successfully. Release version is0.4.6, app build10, effect ABI11. The new library preserves the accepted ±16.8% maximum radius change, with exact pixel parity in18 representative photo/profile comparisons. No new phone runtime test is claimed.
