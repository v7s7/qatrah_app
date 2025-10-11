// android/app/build.gradle.kts  (FIXED)

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.qatrah_app"

    // Explicit SDK levels
    compileSdk = 35

    defaultConfig {
        // TODO: change to your real package id before release
        applicationId = "com.example.qatrah_app"

        minSdk = 21
        targetSdk = 34

        // Delegate versioning to Flutter
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    // AGP 8.x → Java 17
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }
    kotlinOptions {
        jvmTarget = "17"
    }

    buildTypes {
        release {
            // For local installs, sign with debug keystore (replace with your release keystore for production)
            signingConfig = signingConfigs.getByName("debug")

            // Unblock the build: keep both shrinking features OFF
            // (Turn both ON together later if you want smaller APKs)
            isMinifyEnabled = false
            isShrinkResources = false

            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            // defaults are fine
        }
    }
}

flutter {
    source = "../.."
}
