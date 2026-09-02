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
  ///
  /// **Mengembalikan stempel `diperbaruiPada` yang baru saja ditulis**, dan
  /// pemanggil wajib menempelkannya ke salinan sesi yang dipegangnya di memori.
  /// Bukan kerapian: stempel inilah yang dikirim sebagai `diperbarui_pada`
  /// (§7.1), dan sesi yang tidak pernah menerimanya kembali akan selamanya
  /// mengirim stempel bawaan `waktuFoto` — lebih tua daripada `updated_at` yang
  /// ditulis server saat draft-nya diunggah, sehingga **setiap** kiriman
  /// berikutnya untuk sesi itu ditolak `409 konflik_versi`. Gejalanya di layar
  /// nol: sesi tampak lengkap di ponsel dan berhenti di keadaan draft di
  /// server.
  Future<DateTime> simpan(SesiMakan sesi);

  /// Menghapus satu sesi berikut seluruh anaknya, tanpa sisa.
  ///
  /// Dua pemanggil, dan keduanya sudah selesai berurusan dengan sesi itu: sesi
  /// yang dibatalkan pada ponsel yang **belum pernah masuk** (tidak ada server
  /// yang perlu diberi tahu, jadi nisannya tidak ada gunanya), dan nisan yang
  /// sudah diakui server. Riwayat tidak pernah dihapus dari sini.
  Future<void> hapus(String sesiId);

  /// Mengubah satu sesi menjadi **batu nisan**: isinya dibuang, idnya tinggal.
  ///
  /// Untuk sesi yang dibatalkan user pada ponsel yang punya akun. Draft-nya
  /// sudah terunggah sejak rana ditekan, jadi menghapus barisnya begitu saja
  /// membuat sesi itu hidup selamanya di server sebagai draft yang tak pernah
  /// selesai — terlihat di dashboard, dan ikut terunduh ke perangkat kedua.
  /// Nisan inilah yang nanti dikirim sebagai `dihapus_pada` (§7).
  ///
  /// Yang dibuang di sini: sampel, hasil gizi, item makanan. Berkas fotonya
  /// dibuang pemanggil — repository tidak menyentuh berkas. Yang tersisa satu
  /// baris berisi id dan waktu, dan baris itu **tidak pernah muncul di**
  /// [muatSemua]: penyaringannya di SQL, bukan di pemanggil, supaya satu
  /// pemanggil yang lupa menyaring tidak bisa menghidupkan lagi sesi yang sudah
  /// dibatalkan.
  Future<void> nisankan(String sesiId);

  /// Id sesi yang penghapusannya belum sampai ke server.
  ///
  /// Satu-satunya pembaca baris bernisan. Dipanggil tiap `kirimRiwayatKeServer`
  /// — nisan yang gagal terkirim ikut tersapu lagi pada pembukaan berikutnya,
  /// dan itulah percobaan ulangnya. Tidak perlu kolom "sudah terkirim":
  /// penghapusan idempoten, jadi mengirimnya dua kali tidak berakibat apa pun,
  /// sedangkan tanda yang meleset sekali akan meninggalkan sesi hantu selamanya.
  Future<List<String>> ambilNisan();

  /// Membuang **seluruh** riwayat beserta anaknya.
  ///
  /// Satu pemanggil saja, dan sengaja: pergantian akun di ponsel yang sama
  /// (`SesiMakanController.hapusDataLokal`). Riwayat sesi melekat pada satu
  /// orang — apa yang ia makan dan bagaimana gula darahnya menjawab — jadi
  /// membiarkannya berarti pengguna baru melihat makanan orang lain, dan
  /// `kirimRiwayatKeServer()` sesudah masuk akan mengunggahnya ke akun yang
  /// bukan pemiliknya. Bukan galat yang terlihat: di server data itu tampak
  /// sah.
  Future<void> hapusSemua();
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

  /// Id sesi yang sudah dinisankan. Sengaja daftar id saja: yang tersisa dari
  /// sebuah nisan memang hanya idnya.
  final List<String> _nisan = [];

  @override
  Future<List<SesiMakan>> muatSemua() async => List.unmodifiable(_riwayat);

  @override
  Future<DateTime> simpan(SesiMakan sesi) async {
    // Menstempel seperti implementasi drift-nya, dan itu wajib: kalau yang di
    // memori tidak menstempel, seluruh test yang memakainya menguji aturan
    // "yang terbaru menang" pada sesi yang stempelnya tidak pernah bergerak.
    final stempel = DateTime.now();
    final berstempel = sesi.salin(diperbaruiPada: stempel);
    final adaSebelumnya = _riwayat.indexWhere((s) => s.id == sesi.id);
    if (adaSebelumnya >= 0) {
      _riwayat[adaSebelumnya] = berstempel;
    } else {
      _riwayat.insert(0, berstempel);
    }
    return stempel;
  }

  @override
  Future<void> hapus(String sesiId) async {
    _riwayat.removeWhere((s) => s.id == sesiId);
    _nisan.remove(sesiId);
  }

  @override
  Future<void> nisankan(String sesiId) async {
    _riwayat.removeWhere((s) => s.id == sesiId);
    _nisan.add(sesiId);
  }

  @override
  Future<List<String>> ambilNisan() async => List.unmodifiable(_nisan);

  @override
  Future<void> hapusSemua() async {
    _riwayat.clear();
    // Ikut terbuang, sama seperti di SQLite: nisan milik akun lama tidak bisa
    // lagi dikirim dengan token akun yang baru masuk.
    _nisan.clear();
  }
}
