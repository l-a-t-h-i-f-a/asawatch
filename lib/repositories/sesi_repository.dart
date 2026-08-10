/// Tempat riwayat sesi disimpan — lihat docs/rencana-produksi.md §3.1.
///
/// Kontrak ini sengaja dibuat lebih dulu dan lebih dangkal daripada yang
/// dibutuhkan basis data sungguhan (Tahap A2). Gunanya satu: memindahkan
/// `contohRiwayatSesi()` ke belakang sebuah seam, supaya mengganti sumber data
/// nanti tidak menyentuh `SesiMakanController` sama sekali.
library;

import '../models/sesi_makan.dart';

abstract class SesiRepository {
  /// Seluruh riwayat, terbaru di depan.
  ///
  /// Dipanggil **satu kali saat aplikasi start**, oleh composition root, dan
  /// hasilnya disuntikkan ke controller lewat `riwayatAwal`. Controller sendiri
  /// tidak pernah memanggil ini: konstruktornya sinkron, dan membuatnya
  /// asinkron akan memaksa setiap permukaan sesi menumbuhkan status "sedang
  /// memuat" demi pembacaan yang berlangsung milidetik.
  Future<List<SesiMakan>> muatSemua();

  /// Menyimpan satu sesi yang sudah berakhir.
  ///
  /// Dipanggil tepat sekali per sesi, saat sesi masuk riwayat. Sesi yang masih
  /// aktif belum ikut disimpan — pemulihan sesi berjalan setelah aplikasi
  /// ditutup adalah pekerjaan tersendiri (rencana-produksi.md §7.1), bukan
  /// bagian dari seam ini.
  Future<void> simpan(SesiMakan sesi);
}

/// Riwayat yang hidup di memori saja.
///
/// Dua peran, keduanya permanen:
/// - **Sekarang**: implementasi produksi sementara, diisi `contohRiwayatSesi()`,
///   sehingga perilaku aplikasi persis seperti sebelum seam ini ada.
/// - **Setelah Tahap A2**: repository untuk test, sejajar dengan
///   `FakeBleService`. Jangan dihapus saat basis data masuk.
class SesiRepositoryMemori implements SesiRepository {
  SesiRepositoryMemori({List<SesiMakan> awal = const []})
    : _riwayat = List.of(awal);

  final List<SesiMakan> _riwayat;

  @override
  Future<List<SesiMakan>> muatSemua() async => List.unmodifiable(_riwayat);

  @override
  Future<void> simpan(SesiMakan sesi) async {
    final adaSebelumnya = _riwayat.indexWhere((s) => s.id == sesi.id);
    if (adaSebelumnya >= 0) {
      _riwayat[adaSebelumnya] = sesi;
    } else {
      _riwayat.insert(0, sesi);
    }
  }
}
