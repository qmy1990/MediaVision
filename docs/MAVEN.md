# Maven 发布与引用 / Maven publishing and consumption

SDK 坐标：`com.moon.mediavision:mediavision-sdk:0.4.0`。Java 包：`com.moon.mediavision`。SDK 核心源码不参与本仓库的构建。

## JitPack

JitPack 配置已完成，远程发布正在验证；当前可使用下方已验证的 SDK 仓库。

```groovy
// settings.gradle → dependencyResolutionManagement.repositories
maven { url 'https://jitpack.io' }

// app/build.gradle
implementation 'com.github.qmy1990:MediaVision:0.4.0'
```

JitPack 坐标不改变 Java 包名：仍使用 `import com.moon.mediavision.*`。同时保留 `google()`、`mavenCentral()` 以解析运行依赖。

仓库根目录 `jitpack.yml` 使用 JDK 17，调用 `tools/publish_jitpack.sh`，将预编译 AAR 与依赖 POM 发布到构建环境的本地 Maven。该流程只需随 Git 提交的 AAR，不需要下载所有 LFS 模型或编译核心 SDK。维护者参考 [JitPack 官方构建文档](https://docs.jitpack.io/building/)。

## App 引用

在 `settings.gradle` 中：

```groovy
dependencyResolutionManagement {
  repositories {
    google()
    mavenCentral()
    maven {
      url 'https://raw.githubusercontent.com/qmy1990/MediaVision/main/sdk/android/maven'
      content { includeGroup 'com.moon.mediavision' }
    }
  }
}
```

模块 `build.gradle` 中：

```groovy
dependencies {
  implementation 'com.moon.mediavision:mediavision-sdk:0.4.0'
}
```

Kotlin DSL 等价写法：

```kotlin
maven {
  url = uri("https://raw.githubusercontent.com/qmy1990/MediaVision/main/sdk/android/maven")
  content { includeGroup("com.moon.mediavision") }
}
// app/build.gradle.kts
implementation("com.moon.mediavision:mediavision-sdk:0.4.0")
```

本地离线 SDK 仓库：`maven { url uri('/path/to/MediaVision/sdk/android/maven') }`。第一次解析 MediaPipe/LiteRT/QNN 等第三方依赖仍可能需要联网；本 SDK Maven 目录不是完整 Android 工具链或全部第三方缓存。

The repository URL above can be used without GitHub credentials for a public repository. The POM declares runtime dependencies. Pin the SDK version; upgrading means selecting another published immutable version. This repository is a static Maven repository on GitHub, not Maven Central or GitHub Packages.

## 版本与文件

```text
sdk/android/maven/com/moon/mediavision/mediavision-sdk/
  maven-metadata.xml
  0.4.0/
    mediavision-sdk-0.4.0.aar
    mediavision-sdk-0.4.0.pom
    ... checksums
```

Maven 路径内的 AAR 使用普通 Git 文件而非 LFS，确保远程 Maven URL 返回真正的 ZIP/AAR，而不是 LFS 指针。大型安装包、其他 SDK 二进制和模型仍使用 LFS。

## 使用 maven-publish 发布预编译 AAR

维护者可以仅凭预编译 AAR 运行公共发布工程，不需要 SDK 源码：

```bash
# 在仓库根目录执行；Gradle Wrapper 来自 Android Demo。
demos/android/gradlew -p publisher publishSdkPublicationToDistributionRepository \
  -PsdkVersion=0.4.0 \
  -PsdkAar=/absolute/path/to/precompiled.aar
```

Windows：`demos\android\gradlew.bat -p publisher ...`。要求 JDK 17 和联网可用的 Gradle Wrapper。默认 AAR 使用已分发版本，默认目标为本仓库 `sdk/android/maven`。`-PpublishDirectory=/path/to/staging-maven` 可指定独立目标。任务先将 AAR 复制到构建暂存目录，再生成 AAR/POM/版本元数据，避免输入与输出路径相同时损坏 AAR；同时声明与本版 SDK 匹配的第三方依赖。

发布完成后，核对 AAR 的 API、依赖和平台版本，重新生成分发清单，再提交 Maven 新版本目录并推送 GitHub。**不要用不兼容的新文件覆盖已有版本号。** 如果以后更换 SDK 的依赖版本，必须同步更新 `publisher/build.gradle` 的依赖列表。公开仓库不提供编译私有核心的任务。

For maintainers, the `publisher` Gradle project uses `maven-publish` with an existing AAR. It publishes binary artifacts and dependency metadata only, without source or shader jars. Upload the resulting new version directory to GitHub after verification. Keep already published versions immutable.

Maven Central / GitHub Packages 的发布需要额外账号、命名空间验证或访问令牌；本次没有配置这些服务，也没有把账号令牌写入仓库。
