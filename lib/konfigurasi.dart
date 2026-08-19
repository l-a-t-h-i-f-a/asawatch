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

import 'models/jadwal_sesi.dart';
import 'services/auth_http_service.dart';
import 'services/auth_service.dart';
import 'services/izin_ble.dart';

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
  defaultValue: 'https://api.asawatch.id',
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
final JadwalSesi jadwalBawaan = pakaiJadwalUji ? jadwalUji : jadwalNormal;

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
    : AuthHttpService(basisUrl: basisUrlApi);

/// Izin yang dipakai alur pemindaian.
///
/// Jam palsu tidak menyentuh radio sama sekali, jadi memintanya izin Bluetooth
/// hanya menghasilkan dialog yang tidak berhubungan dengan apa pun yang akan
/// terjadi berikutnya.
const IzinBle izinBleBawaan = pakaiJamPalsu
    ? IzinBleSelaluBoleh()
    : IzinBlePermissionHandler();
