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
