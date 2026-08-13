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

  /// Menyimpan satu sesi, berakhir maupun **masih berjalan** (Tahap B).
  ///
  /// Dipanggil berkali-kali seumur sesi: saat draft dibuat, saat jam mengirim
  /// t0, dan pada tiap sampel yang masuk. Sesi yang sudah ada ditimpa. Itulah
  /// yang membuat aplikasi boleh mati di tengah sesi tanpa kehilangan apa pun,
  /// dan yang menutup lingkaran ack protokol §6.
  Future<void> simpan(SesiMakan sesi);

  /// Menghapus satu sesi berikut seluruh anaknya.
  ///
  /// Hanya untuk sesi yang **dibatalkan user**: ia sudah pernah ditulis sebagai
  /// draft, dan sesi yang tidak jadi dijalani tidak boleh muncul kembali sebagai
  /// sesi aktif saat aplikasi dibuka lagi. Riwayat tidak pernah dihapus dari
  /// sini.
  Future<void> hapus(String sesiId);
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

  @override
  Future<void> hapus(String sesiId) async {
    _riwayat.removeWhere((s) => s.id == sesiId);
  }
}
