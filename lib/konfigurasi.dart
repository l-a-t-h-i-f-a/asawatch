/// Sakelar rakitan aplikasi — docs/rencana-produksi.md §4.1.
///
/// Satu-satunya isinya adalah pilihan antara jam sungguhan dan jam palsu.
/// Diperlukan karena `FakeBleService` **tidak pernah dihapus** (§11 aturan 4):
/// ia tulang punggung test, dan satu-satunya cara mendemokan aplikasi ini di
/// perangkat yang jamnya belum ada di tangan.
///
/// ```bash
/// flutter run --dart-define=PAKAI_JAM_PALSU=true
/// ```
///
/// `bool.fromEnvironment` dievaluasi saat kompilasi, jadi build rilis biasa
/// tidak menyeret satu baris pun kode demo ke dalam jalur produksinya.
library;

import 'dart:io';

import 'models/jadwal_sesi.dart';
import 'services/auth_http_service.dart';
import 'services/auth_service.dart';
import 'services/google_masuk_service.dart';
import 'services/izin_ble.dart';
import 'services/kamera_service.dart';
import 'services/layanan_latar.dart';

const bool pakaiJamPalsu = bool.fromEnvironment('PAKAI_JAM_PALSU');

/// Sakelar kedua, dan sengaja **terpisah** dari [pakaiJamPalsu]: jam dan
/// backend adalah dua ketiadaan yang berbeda, dan seseorang bisa punya jam
/// sungguhan di tangan sementara servernya belum ada — persis keadaan hari ini.
///
/// ```bash
/// flutter run --dart-define=PAKAI_AUTH_PALSU=true
/// ```
///
/// **Selama backend AsaWatch belum ada, inilah satu-satunya cara masuk ke
/// aplikasi.** Bawaannya tetap auth sungguhan, karena rakitan rilis yang
/// diam-diam menerima kata sandi apa pun adalah kegagalan yang tidak terlihat
/// sampai terlambat.
const bool pakaiAuthPalsu = bool.fromEnvironment('PAKAI_AUTH_PALSU');

/// Akar alamat API, tanpa garis miring di ujung.
///
/// `String.fromEnvironment` dievaluasi saat kompilasi, jadi alamat pengembangan
/// hanya ada di rakitan yang memintanya:
///
/// ```bash
/// # emulator Android: 10.0.2.2 adalah localhost laptop, bukan localhost emulator
/// flutter run --dart-define=BASIS_URL_API=http://10.0.2.2:8080
/// # HP fisik satu WiFi: IP laptop, dan servernya harus bind ke 0.0.0.0
/// flutter run --dart-define=BASIS_URL_API=http://192.168.1.10:8080
/// ```
///
/// Alamat `http://` polos hanya bisa dihubungi bila `network_security_config`
/// debug mengizinkannya — Android memblokir cleartext sejak versi 9, dan
/// gejalanya mudah disalahartikan sebagai server yang mati.
const String basisUrlApi = String.fromEnvironment(
  'BASIS_URL_API',
  defaultValue: 'https://asawatch.enumatechnology.com',
);

/// Sakelar ketiga: jadwal sesi yang dikecilkan untuk pengujian.
///
/// ```bash
/// flutter run --dart-define=PAKAI_JADWAL_UJI=true
/// ```
///
/// Menguji sesi penuh tidak boleh menuntut menunggu dua jam. Mode ini
/// mengecilkan **jadwalnya** dengan faktor [faktorJadwalUji] dan tidak
/// memalsukan apa pun yang lain: jendela toleransi, tenggat, dan seluruh alur
/// BLE berjalan apa adanya, hanya dengan angka yang dibagi 60. Sesi penuh
/// selesai dalam dua menit.
///
/// **Berbeda dari `FakeBleService(percepatan:)`, dan keduanya boleh dipakai
/// bersamaan.** Yang itu mempercepat perilaku jam palsu; yang ini mengecilkan
/// jadwal sesi. Karena `ARM_TITIK` membawa penundaan yang dihitung aplikasi
/// (protokol §9), firmware tidak perlu tahu apa-apa tentang mode ini — jadi ia
/// bekerja dengan **jam sungguhan**, dan itulah nilai utamanya: integrasi
/// hardware bisa diuji end-to-end berkali-kali dalam satu sore.
///
/// Tiga pengaman menyertainya, dan ketiganya perlu — lihat
/// docs/jadwal-titik-ukur.md §7.1. Yang pertama ada di sini: `bool.fromEnvironment`
/// dievaluasi saat kompilasi, jadi rakitan rilis biasa tidak menyeret satu baris
/// pun jadwal uji.
const bool pakaiJadwalUji = bool.fromEnvironment('PAKAI_JADWAL_UJI');

/// Jadwal yang dipakai sesi baru. Padanan [izinBleBawaan] dan [buatAuthBawaan]:
/// satu titik yang menentukan, supaya tidak ada layar yang memilih sendiri.
///
/// `final`, bukan `const`, dan itu disengaja. Versi const menuntut jadwal uji
/// ditulis ulang sebagai daftar literal kedua — persis dua daftar yang harus
/// dijaga sebanding, yang [JadwalSesi.dibagi] ada untuk mencegahnya. Yang
/// dijaga oleh kompilasi tetap dijaga: [pakaiJadwalUji] const, jadi tidak ada
/// rakitan rilis yang bisa **berperilaku** memakai jadwal uji. Yang ikut
/// terbawa hanyalah satu struktur data empat elemen.
final JadwalSesi jadwalBawaan = pakaiJadwalUji
    ? jadwalNormal.dibagi(faktorJadwalUjiTerpakai)
    : jadwalNormal;

/// Seberapa jauh jadwal uji dimampatkan. Bawaannya [faktorJadwalUji] (60).
///
/// **Bisa diturunkan karena 60 lahir dari jam palsu, bukan dari jam sungguhan.**
/// Dengan `FakeBleService` jawaban datang seketika, jadi titik `+1 jam` yang
/// jatuh pada detik ke-60 dengan jendela 55–70 detik masuk akal. Pengukuran
/// sungguhan memakan puluhan detik — lantainya saja `UKUR_MIN_MS` 10 detik, dan
/// nadi yang sulit bisa membuatnya jauh lebih lama — sehingga pengukuran yang
/// dimulai tepat waktu selesai **setelah** jendelanya tutup, dan titik
/// berikutnya jatuh tempo selagi yang sekarang masih berjalan. Yang terlihat di
/// layar: sesi berakhir sebelum jamnya sempat menjawab.
///
/// 12 adalah angka yang masuk akal untuk perangkat keras (`+1 jam` menjadi 5
/// menit, jendelanya 4,6–5,8 menit, sesi penuh 10 menit) — cukup lapang untuk
/// satu pengukuran sungguhan, masih jauh lebih cepat daripada 2,5 jam.
///
/// `int.fromEnvironment` juga dievaluasi saat kompilasi, jadi pengaman yang
/// sama seperti [pakaiJadwalUji] tetap berlaku.
const int faktorJadwalUjiTerpakai = int.fromEnvironment(
  'FAKTOR_JADWAL_UJI',
  defaultValue: faktorJadwalUji,
);

/// **Client ID Web** dari Google Cloud Console — bukan yang Android.
///
/// ```bash
/// flutter run --dart-define=ID_KLIEN_GOOGLE=1234-abcd.apps.googleusercontent.com
/// ```
///
/// Nilai ini **bukan rahasia**: ia ikut ke dalam setiap APK dan memang
/// dirancang untuk terbaca. Yang menjaga akun bukan kerahasiaannya melainkan
/// pasangan package name + SHA-1 di sisi Google, dan verifikasi `aud` di sisi
/// Laravel. Karena itu ia boleh berada di sini dan boleh ikut git.
///
/// Yang **tidak** boleh: mengisinya dengan client ID Android. Google tidak
/// menganggapnya galat — pemilih akun tetap muncul — tetapi ID token-nya datang
/// kosong, sehingga tidak ada apa pun untuk dikirim ke server dan layarnya
/// hanya diam. Lihat `GoogleGagal.idTokenKosong`.
///
/// Kosong berarti tombol Google tidak ditawarkan sama sekali. Itu bawaannya,
/// dan disengaja: tombol yang pasti gagal lebih buruk daripada tombol yang
/// tidak ada.
const String idKlienGoogle = String.fromEnvironment(
  'ID_KLIEN_GOOGLE',
  defaultValue:
      '409100365490-jg0nbsk5dch08upih5opav80jgcf16kt.apps.googleusercontent.com',
);

/// Apakah alur masuk Google ditawarkan pada rakitan ini.
bool get pakaiGoogle => idKlienGoogle.isNotEmpty || pakaiAuthPalsu;

/// Auth yang dipakai alur masuk.
///
/// Padanan [izinBleBawaan] di bawah: satu titik yang menentukan implementasi
/// mana yang dirakit, supaya tidak ada halaman yang memilih sendiri.
AuthService buatAuthBawaan() => pakaiAuthPalsu
    ? FakeAuthService(
        // Jeda yang terasa: tanpa ini keadaan "sedang masuk" lewat dalam satu
        // frame dan tombol terkuncinya tidak pernah sempat terlihat saat demo.
        jeda: const Duration(milliseconds: 900),
      )
    : AuthHttpService(
        basisUrl: basisUrlApi,
        google: idKlienGoogle.isEmpty
            ? null
            : GoogleMasukAsli(idKlienWeb: idKlienGoogle),
      );

/// Sakelar keempat: kamera palsu.
///
/// ```bash
/// flutter run --dart-define=PAKAI_KAMERA_PALSU=true
/// ```
///
/// Alasannya sama sekali berbeda dengan [pakaiJamPalsu], walau bentuknya sama.
/// Bukan karena perangkat kerasnya tidak ada — hampir setiap ponsel punya
/// kamera — melainkan karena ada keadaan di mana membuka kamera menghalangi hal
/// yang sedang diuji: emulator tanpa kamera, perangkat yang izin kameranya
/// sengaja ditolak, atau sekadar tidak ingin memotret piring berkali-kali
/// hanya untuk sampai ke layar sesi.
///
/// Yang dimatikan **hanya kameranya**. Sesi tetap lahir, foto tetap punya
/// jalur, kartu gizi tetap muncul, dan seluruh alur BLE berjalan apa adanya.
const bool pakaiKameraPalsu = bool.fromEnvironment('PAKAI_KAMERA_PALSU');

/// Kamera yang dipakai halaman deteksi makanan.
KameraService buatKameraBawaan() =>
    pakaiKameraPalsu ? KameraPalsuService() : KameraAsliService();

/// Izin yang dipakai alur pemindaian.
///
/// Jam palsu tidak menyentuh radio sama sekali, jadi memintanya izin Bluetooth
/// hanya menghasilkan dialog yang tidak berhubungan dengan apa pun yang akan
/// terjadi berikutnya.
const IzinBle izinBleBawaan = pakaiJamPalsu
    ? IzinBleSelaluBoleh()
    : IzinBlePermissionHandler();

/// Foreground service yang menjaga sesi tetap hidup — lihat [LayananLatar].
///
/// Android saja. Bukan karena iOS tidak diurus, melainkan karena iOS memang
/// tidak punya padanannya: prosesnya tidak bisa dipertahankan dua jam dengan
/// cara apa pun, dan yang menggantikannya di sana sudah ada — buffer jam plus
/// `BleAsliService.kembaliKeDepan()` saat aplikasi kembali ke depan
/// (rencana-produksi.md §7.1). Di bawah `flutter_test` [Platform.isAndroid]
/// bernilai true, tetapi kanal platformnya tidak ada — karena itu test tetap
/// menyuntikkan [LayananLatarDiam] sendiri lewat controller.
LayananLatar buatLayananLatarBawaan() =>
    Platform.isAndroid ? LayananLatarAndroid() : const LayananLatarDiam();
