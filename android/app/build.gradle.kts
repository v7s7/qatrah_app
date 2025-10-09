plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.qatrah_app"

    // Use explicit SDK levels (good for BLE + modern Play requirements)
    compileSdk = 34

    defaultConfig {
        // TODO: change to your real package id before release
        applicationId = "com.example.qatrah_app"

        // BLE requires >= 21
        minSdk = 21
        targetSdk = 34

        // Keep versioning delegated to Flutter
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // AGP 8.x prefers Java 17
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            // Use your real signing config for Play builds
            signingConfig = signingConfigs.getByName("debug")
            isMinifyEnabled = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug { }
    }
}

flutter {
    source = "../.."
}
