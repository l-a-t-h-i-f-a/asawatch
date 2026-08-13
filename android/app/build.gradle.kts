plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.asawatch"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.asawatch"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        // Dibiarkan mengikuti Flutter, yang saat ini memberi **24** — sudah di
        // atas 23, batas tempat izin runtime mulai ada, dan seluruh alur
        // pemasangan jam bergantung pada izin runtime (rencana-produksi.md §4.4).
        //
        // Jangan menuliskannya sebagai angka di sini: `flutter build` menjalankan
        // migrasi "Upgrading build.gradle.kts" yang menulis ulang baris ini
        // menjadi `flutter.minSdkVersion` setiap kali. Angka yang ditulis tangan
        // akan hilang diam-diam pada build berikutnya.
        minSdk = flutter.minSdkVersion
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

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
