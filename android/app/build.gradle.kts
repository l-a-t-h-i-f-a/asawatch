plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.asawatch.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17

        // Dituntut `flutter_local_notifications`, yang memakai `java.time` untuk
        // menjadwalkan pengingat titik ukur (docs/jadwal-titik-ukur.md §6).
        // API itu baru ada di Android 8, sedangkan minSdk di sini 24 — jadi
        // tanpa desugaring, build gagal di `checkDebugAarMetadata` sebelum
        // sempat menyentuh kode Dart mana pun.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        // Diganti dari `com.example.asawatch` pada 2026-09-03. Nilai ini
        // adalah identitas aplikasi di perangkat: menggantinya membuat
        // Android memperlakukannya sebagai aplikasi lain, jadi APK lama
        // harus dicopot dan seluruh data lokal penguji (sesi, foto, token)
        // ikut hilang. Jangan diubah lagi setelah ada pengguna.
        //
        // Ia juga separuh dari kunci pendaftaran Google Sign-In (package
        // name + sidik jari SHA-1): mengubahnya berarti mendaftar ulang di
        // Google Cloud Console, kalau tidak sign-in gagal dengan
        // `ApiException: 10` yang tidak menyebut sertifikat sama sekali.
        applicationId = "com.asawatch.app"
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

dependencies {
    // Pasangan wajib `isCoreLibraryDesugaringEnabled` di atas. Versinya tidak
    // ikut `flutter.*` karena Flutter tidak mengelolanya; naikkan hanya bila
    // ada alasan, dan periksa build-nya — pustaka ini ikut ke dalam APK.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
