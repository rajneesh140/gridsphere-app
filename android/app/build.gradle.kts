plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

import java.util.Properties
import java.io.FileInputStream

val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

// Safely check if the file exists AND contains all required release keys
val hasReleaseKeystore = keystorePropertiesFile.exists() &&
    keystoreProperties["keyAlias"] != null &&
    keystoreProperties["keyPassword"] != null &&
    keystoreProperties["storeFile"] != null &&
    keystoreProperties["storePassword"] != null

android {
    namespace = "in.gridsphere.grid_sphere_app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "29.0.13846066"

    compileOptions {
        // 1. Enable Core Library Desugaring (Kotlin DSL Syntax)
        isCoreLibraryDesugaringEnabled = true

        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        // FIX: Changed from VERSION_11 to VERSION_1_8 to match compileOptions
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "in.gridsphere.grid_sphere_app"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        // Only configure the release keystore if all properties were successfully loaded
        if (hasReleaseKeystore) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // FIX: Disable minification to prevent R8 from stripping necessary plugin code
            isMinifyEnabled = false
            isShrinkResources = false

            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = if (hasReleaseKeystore) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}

// 2. Add the dependency block for the desugar library
dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.4")
}