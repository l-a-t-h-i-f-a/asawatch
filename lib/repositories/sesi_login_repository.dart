import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../services/auth_service.dart';

/// Penyimpanan bukti masuk di perangkat.
///
/// Dipisahkan menjadi kontrak dengan alasan yang sama seperti `SesiRepository`:
/// yang sungguhan menyentuh Keystore Android — sesuatu yang tidak ada di bawah
/// `flutter_test` — sementara keputusan "apakah pengguna sudah masuk" harus
/// tetap bisa diuji.
///
/// **Sengaja bukan `SharedPreferences`.** Token ini membuka data kesehatan
/// seseorang, dan preferences di Android hanyalah berkas XML polos di direktori
/// aplikasi; di perangkat yang di-root ia terbaca begitu saja.
abstract class SesiLoginRepository {
  /// Sesi yang tersimpan, atau null bila belum pernah masuk.
  ///
  /// Sesi yang sudah kedaluwarsa **dihapus dan dikembalikan sebagai null** —
  /// bukan dikembalikan apa adanya. Token mati yang dibiarkan tersimpan hanya
  /// akan dipakai sekali lagi, ditolak server, lalu memaksa pengguna menebak
  /// apa yang salah.
  Future<SesiLogin?> muat();

  Future<void> simpan(SesiLogin sesi);

  Future<void> hapus();
}

/// Implementasi produksi: EncryptedSharedPreferences lewat Keystore.
class SesiLoginRepositoryAman implements SesiLoginRepository {
  SesiLoginRepositoryAman({FlutterSecureStorage? penyimpanan})
    : _penyimpanan =
          penyimpanan ??
          const FlutterSecureStorage(
            // Jetpack Security, bukan skema enkripsi bawaan paketnya. Ditetapkan
            // **sekarang**, sebelum ada satu pun pengguna: menggantinya belakangan
            // membuat token yang sudah tersimpan tidak terbaca lagi, dan gejalanya
            // adalah seluruh pengguna terlempar ke halaman masuk setelah satu
            // pembaruan aplikasi.
            aOptions: AndroidOptions(encryptedSharedPreferences: true),
          );

  static const _kunci = 'sesi_login';

  final FlutterSecureStorage _penyimpanan;

  @override
  Future<SesiLogin?> muat() async {
    final mentah = await _penyimpanan.read(key: _kunci);
    if (mentah == null) return null;

    final sesi = _dariJson(mentah);
    // Isi yang tidak terbaca diperlakukan sama dengan tidak ada: satu-satunya
    // jalan keluarnya adalah masuk lagi, dan melempar dari sini akan
    // menggagalkan `main()` sebelum satu pun layar sempat tampil.
    if (sesi == null) {
      await hapus();
      return null;
    }
    if (!sesi.masihBerlaku) {
      await hapus();
      return null;
    }
    return sesi;
  }

  @override
  Future<void> simpan(SesiLogin sesi) => _penyimpanan.write(
    key: _kunci,
    value: jsonEncode({
      'token': sesi.token,
      'kedaluwarsa': sesi.kedaluwarsa.toIso8601String(),
      'nama': sesi.nama,
      'email': sesi.email,
    }),
  );

  @override
  Future<void> hapus() => _penyimpanan.delete(key: _kunci);

  static SesiLogin? _dariJson(String mentah) {
    try {
      final isi = jsonDecode(mentah);
      if (isi is! Map<String, dynamic>) return null;
      final token = isi['token'];
      final kedaluwarsa = DateTime.tryParse(
        isi['kedaluwarsa'] as String? ?? '',
      );
      if (token is! String || token.isEmpty || kedaluwarsa == null) return null;
      return SesiLogin(
        token: token,
        kedaluwarsa: kedaluwarsa,
        nama: isi['nama'] as String? ?? '',
        email: isi['email'] as String? ?? '',
      );
    } on FormatException {
      return null;
    }
  }
}

/// Penyimpanan di memori — tulang punggung test, sama seperti
/// `SesiRepositoryMemori`. Aturan kedaluwarsanya sengaja sama persis dengan
/// yang sungguhan, karena aturan itulah yang diuji.
class SesiLoginRepositoryMemori implements SesiLoginRepository {
  SesiLoginRepositoryMemori([this._sesi]);

  SesiLogin? _sesi;

  /// Berapa kali [hapus] dipanggil — dipakai test untuk membuktikan bahwa
  /// keluar benar-benar membuang token, yang tidak terlihat dari layar.
  int jumlahHapus = 0;

  @override
  Future<SesiLogin?> muat() async {
    final sesi = _sesi;
    if (sesi != null && !sesi.masihBerlaku) {
      await hapus();
      return null;
    }
    return sesi;
  }

  @override
  Future<void> simpan(SesiLogin sesi) async => _sesi = sesi;

  @override
  Future<void> hapus() async {
    jumlahHapus++;
    _sesi = null;
  }
}
