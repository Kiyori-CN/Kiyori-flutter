plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.kiyori.flutter"
    compileSdk = 37
    buildToolsVersion = "37.0.0"
    ndkVersion = "30.0.16248370"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        applicationId = "com.kiyori.flutter"
        minSdk = 24
        targetSdk = 37
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName

        // JNI 依赖可能包含更多 ABI；必须与本次 Flutter/Rust 目标一致，避免假报支持。
        // 分 ABI 构建由 Flutter 的 splits 配置过滤，不能同时设置 ndk.abiFilters。
        if (providers.gradleProperty("split-per-abi").orNull != "true") {
            providers.gradleProperty("target-platform").orNull?.let { platforms ->
                val platformAbis = mapOf(
                    "android-arm" to "armeabi-v7a",
                    "android-arm64" to "arm64-v8a",
                    "android-x64" to "x86_64",
                )
                ndk.abiFilters.clear()
                ndk.abiFilters.addAll(platforms.split(",").map { platform ->
                    requireNotNull(platformAbis[platform]) { "Unsupported target-platform: $platform" }
                })
            }
        }
    }

    buildTypes {
        release {
            // 正式签名在发布阶段接入；禁止用 Debug key 冒充 Release 签名。
            signingConfig = null
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
