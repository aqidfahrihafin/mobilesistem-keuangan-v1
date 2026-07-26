plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
    id("com.google.gms.google-services")
}

android {
    namespace = "id.pesantren.latee.wali_santri"
    // Pinned above the Flutter default because mobile_scanner requires
    // compiling against SDK 36 specifically.
    compileSdk = maxOf(flutter.compileSdkVersion, 36)
    // Pinned above the Flutter default (flutter.ndkVersion) because
    // flutter_secure_storage and path_provider_android both require this
    // version specifically - see the "Fix this issue by..." build warning.
    ndkVersion = "27.0.12077973"

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        // Required by flutter_local_notifications (foreground push display).
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "id.pesantren.latee.wali_santri"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // mobile_scanner (QR/barcode scanning, for kantin scan-to-pay)
        // requires API 23+ - above Flutter's own default minSdkVersion.
        minSdk = maxOf(flutter.minSdkVersion, 23)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    // Required by flutter_local_notifications (isCoreLibraryDesugaringEnabled above).
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
