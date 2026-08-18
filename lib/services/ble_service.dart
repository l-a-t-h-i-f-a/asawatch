import 'dart:async';
import 'dart:math';

import '../models/sesi_makan.dart';
import 'protokol_jam.dart' show GalatJam;

/// Tahap penyambungan yang sedang berjalan — docs/alur-pemasangan-jam.md §4.3.
///
/// Dilaporkan keluar karena ketiganya menuntut hal yang **berbeda** dari
/// pengguna, dan satu indikator "sedang sibuk" untuk ketiganya menyembunyikan
/// satu-satunya tahap yang benar-benar menunggu tindakannya.
enum TahapSambung {
  /// Radio sedang bekerja. Pengguna cukup menunggu.
  menyambung,

  /// Dialog penyandingan milik sistem sedang menunggu dijawab. **Yang ditunggu
  /// jari manusia, bukan radio**, jadi tidak ada batas waktu di sisi aplikasi.
  menyandingkan,

  /// Sudah tersandingkan; handshake dan anchor sedang dikerjakan.
  menyiapkan,
}

/// Sebab kegagalan menyambung yang layak dibedakan di layar.
///
/// Menyeragamkan semuanya menjadi "gagal menyambung, coba lagi" adalah cara
/// tercepat membuat pengguna mengulangi hal yang sama sepuluh kali — terutama
/// [bondBasi], satu-satunya di daftar ini yang **tidak akan pernah pulih**
/// dengan mencoba lagi.
enum HasilSambung {
  berhasil,

  /// Jam tidak menjawab: di luar jangkauan, mati, atau tersambung ke ponsel lain.
  diLuarJangkauan,

  /// Tersambung, tetapi layanan/karakteristiknya bukan milik AsaWatch.
  bukanAsaWatch,

  /// Pengguna menolak, atau menutup, permintaan penyandingan.
  penyandinganDitolak,

  /// Permintaan penyandingan hangus tanpa pernah dijawab — kemungkinan besar
  /// karena ia muncul sebagai notifikasi dan tidak terlihat (§4.4).
  penyandinganTidakDijawab,

  /// Ponsel masih menyimpan kunci penyandingan lama sementara jam sudah tidak
  /// mengenalinya (jam di-reset atau firmware-nya diganti).
  bondBasi,

  /// Versi mayor protokol tidak cocok; pesannya sendiri datang dari jam.
  versiTidakCocok,
}

extension PesanHasilSambung on HasilSambung {
  bool get berhasil => this == HasilSambung.berhasil;

  /// Kalimat siap tampil. Tidak satu pun menyebut istilah teknis — yang perlu
  /// diketahui pengguna adalah **apa langkah berikutnya**, bukan apa yang gagal.
  String pesan(String nama) => switch (this) {
    HasilSambung.berhasil => '',
    HasilSambung.diLuarJangkauan =>
      '$nama belum bisa disambungkan. Dekatkan jam ke ponsel, lalu coba lagi.',
    HasilSambung.bukanAsaWatch =>
      '$nama tidak menjawab seperti jam AsaWatch. Pastikan jam yang dipilih '
          'benar, lalu coba lagi.',
    HasilSambung.penyandinganDitolak =>
      'Penyandingan dibatalkan. Jam perlu disandingkan satu kali agar data '
          'kesehatan Anda terkirim dengan aman.',
    HasilSambung.penyandinganTidakDijawab =>
      'Permintaan penyandingan belum dijawab. Coba lagi, lalu ketuk '
          '"Sandingkan" saat permintaan itu muncul.',
    HasilSambung.bondBasi =>
      '$nama pernah disandingkan dengan data yang sudah tidak berlaku, jadi '
          'ponsel dan jam tidak lagi saling mengenali.',
    HasilSambung.versiTidakCocok =>
      'Versi jam dan versi aplikasi tidak cocok. Perbarui salah satunya, lalu '
          'coba lagi.',
  };

  /// Hanya [bondBasi] yang perlu menghapus penyandingan lama lebih dulu; sisanya
  /// cukup diulang, dan menawarkan penghapusan pada kasus lain justru merusak
  /// pemasangan yang sebenarnya sehat.
  bool get butuhSandingUlang => this == HasilSambung.bondBasi;
}

/// Kontrak jam tangan (§12.5). Dibuat abstrak agar UI bisa dites tanpa
/// hardware, dan agar `FakeBleService` bisa disuntikkan saat test.
abstract class BleService {
  Stream<StatusPerangkat> get statusPerangkat;
  Stream<({String sesiId, Sampel sampel})> get sampelMasuk;

  /// Tombol "Selesai Makan" **di jam** ditekan — inilah satu-satunya sumber t0.
  ///
  /// `t0` yang dibawa adalah waktu menurut jam tangan, bukan waktu HP:
  /// tombolnya bisa ditekan saat HP tidak tersambung, dan peristiwanya baru
  /// sampai belakangan lewat buffer. Menghitung ulang t0 di HP saat pesannya
  /// tiba akan menggeser seluruh jadwal sesi.
  ///
  /// `waktuTidakPasti` true berarti `t0` adalah **tebakan terbaik, bukan fakta**:
  /// jam tidak punya RTC, dan boot asal peristiwa ini tidak punya anchor yang
  /// bisa menerjemahkan `uptime_s`-nya (docs/protokol-jam.md §4.3). Bentuk
  /// kurvanya tetap benar — ia hanya selisih dua pencacah — tetapi posisinya di
  /// kalender tidak. Sesi seperti itu dikecualikan dari hitungan yang memakai
  /// jam dinding.
  Stream<({String sesiId, DateTime t0, bool waktuTidakPasti})>
  get selesaiMakanDitekan;

  /// Status terakhir yang diketahui, agar UI tidak kosong sebelum stream
  /// mengirim nilai pertamanya.
  StatusPerangkat get statusTerakhir;

  /// Memindai jam di sekitar. Perangkat dikirim satu per satu selagi terlihat,
  /// dan stream-nya ditutup sendiri saat pemindaian selesai — UI memakai
  /// penutupan itu sebagai tanda "selesai", bukan timer sendiri.
  ///
  /// Membatalkan langganan berarti menghentikan pemindaian.
  Stream<PerangkatDitemukan> pindai();

  /// Tahap penyambungan yang sedang berjalan (§4.3 alur-pemasangan-jam).
  ///
  /// Hanya hidup selama [sambungkan] berjalan. UI memakainya untuk mengetahui
  /// **kapan** dialog penyandingan sistem sedang menunggu dijawab — satu-satunya
  /// momen di seluruh alur yang menuntut tindakan pengguna.
  Stream<TahapSambung> get tahapSambung;

  /// Memasangkan jam, melaporkan sebab kegagalannya.
  ///
  /// Sebabnya dibedakan karena tindak lanjutnya berbeda: yang di luar jangkauan
  /// cukup didekatkan, yang penyandingannya ditolak harus disandingkan lagi, dan
  /// yang [HasilSambung.bondBasi] tidak akan pernah berhasil sampai penyandingan
  /// lamanya dihapus.
  Future<HasilSambung> sambungkan(String idPerangkat);

  /// Menghapus penyandingan lama, agar jam bisa disandingkan dari awal.
  ///
  /// Satu-satunya jalan keluar dari [HasilSambung.bondBasi]. Mengembalikan false
  /// bila penghapusan tidak bisa dilakukan dari dalam aplikasi — sebagian versi
  /// Android tidak mengizinkannya — dan pada saat itu yang tersisa bagi pengguna
  /// adalah menghapusnya lewat Pengaturan Bluetooth sistem.
  Future<bool> lupakanPenyandingan(String idPerangkat);

  /// Penjelasan kegagalan sambung terakhir yang datang dari jam sendiri (mis.
  /// ketidakcocokan versi), lebih spesifik daripada [HasilSambung.pesan]. null
  /// berarti tidak ada yang lebih baik untuk dikatakan.
  String? get galatTerakhir;

  /// Memutus jam tanpa melupakan sampel yang masih di buffer-nya.
  Future<void> putuskan();

  /// Melepas pemasangan sepenuhnya: putus, hapus penyandingan di ponsel, dan
  /// lupakan jamnya.
  ///
  /// Berbeda dari [putuskan] dalam hal yang paling penting: setelah ini
  /// **sampel yang masih tertahan di buffer jam tidak akan pernah sampai**,
  /// karena tidak ada lagi yang akan menyambunginya. Karena itu ia harus selalu
  /// dikonfirmasi lebih dulu, dan tidak pernah dipakai sebagai jalan keluar dari
  /// koneksi yang sekadar bermasalah.
  Future<void> lupakanPerangkat();

  /// Menyalakan tombol "Selesai Makan" di jam untuk sesi ini.
  ///
  /// Jam menolak tombolnya selama belum disiapkan, sehingga sesi tidak pernah
  /// dimulai tanpa foto makanan. Mengembalikan false bila jam tidak tersambung
  /// sehingga penyiapannya belum sampai.
  Future<bool> siapkanSesi(String sesiId);

  /// Menekan tombol "Selesai Makan" **milik jam** dari aplikasi
  /// (`MULAI_SESI`, §5.1).
  ///
  /// **Ini bukan aplikasi yang menetapkan t0.** Yang dikirim hanya `sesiId`,
  /// tanpa waktu sama sekali: jam yang membaca pencacahnya sendiri saat perintah
  /// tiba, lalu mengirim `TOMBOL_SELESAI_MAKAN` lewat [selesaiMakanDitekan]
  /// persis seperti kalau tombol fisiknya yang ditekan. Karena itu t0 tetap
  /// berada di garis waktu jam, tetap sebanding dengan `uptime_s` tiap sampel,
  /// dan seluruh model waktu tanpa RTC (§4) tidak tersentuh.
  ///
  /// Kalau aplikasi mengirim jam dindingnya sendiri sebagai t0, jam tidak akan
  /// punya cara membandingkannya dengan `uptime_s` sampelnya, dan `+1 jam` /
  /// `+2 jam` akan dijadwalkan dari titik yang tidak ada di garis waktunya.
  ///
  /// Perintahnya **idempoten**: sesi yang sudah berjalan cukup di-ACK dan
  /// diabaikan. Tautan BLE bisa menelan ACK dan membuat aplikasi mengulang, dan
  /// dua t0 untuk satu sesi jauh lebih buruk daripada satu perintah yang terkirim
  /// dua kali.
  ///
  /// Mengembalikan false bila jam tidak tersambung atau menolak perintahnya —
  /// belum di-ARM (belum ada foto), atau sesinya sudah tidak dikenal.
  Future<bool> mulaiSesi(String sesiId);

  /// Meminta jam mengukur satu titik — dipakai untuk baseline (index 0).
  ///
  /// Mengembalikan false bila jam **menolak atau tidak menerima** permintaannya:
  /// belum di-ARM, tidak tersambung, sensor gagal. Nilainya bukan hiasan —
  /// pemanggil memakainya untuk menandai titik itu `terlewat` seketika, alih-alih
  /// menampilkannya sebagai "menunggu data" selama dua jam untuk pengukuran yang
  /// sudah pasti tidak akan pernah datang.
  Future<bool> mintaUkur(String sesiId, int index); // baseline
  Future<void> batalkanSesi(String sesiId);
  Future<void> sinkronkan(); // tarik buffer jam

  /// Pengukuran sekali jalan **di luar sesi mana pun** (`UKUR_SEKARANG`, §5.1).
  ///
  /// Dua pemakainya: alur kalibrasi tekanan darah, dan pindai kesehatan atas
  /// permintaan pengguna ([PindaiKesehatanPage]). Keduanya perintah yang sama di
  /// kawat — yang berbeda hanya apa yang dilakukan aplikasi terhadap hasilnya.
  ///
  /// Jawabannya datang sebagai paket Sampel ber-`sesiId` 16 byte nol, jadi ia
  /// tidak pernah masuk ke sesi mana pun dan tidak tersimpan di riwayat.
  ///
  /// Melempar [GalatJam] bila jam tidak tersambung, menolak perintahnya, atau
  /// tidak menjawab sama sekali — `pesanPengguna`-nya sudah siap ditampilkan.
  /// Ia melempar alih-alih mengembalikan null karena pemanggilnya selalu sebuah
  /// layar yang sedang menunggu: yang dibutuhkan di sana adalah kalimat sebab,
  /// bukan ketiadaan nilai.
  Future<Sampel> ukurSekarang();

  /// Mengirim koefisien kalibrasi ke jam.
  Future<void> kirimKalibrasi(Kalibrasi kalibrasi);

  void dispose();
}

/// Perilaku penyandingan yang ditirukan [FakeBleService].
enum PenyandinganPalsu {
  /// Jam sudah tersandingkan — tahap `menyandingkan` dilewati sama sekali.
  /// Bawaan, supaya test yang tidak sedang menguji pemasangan tetap ringkas.
  tidakPerlu,

  /// Dialog muncul dan dijawab "Sandingkan".
  dijawab,

  /// Dialog muncul dan dibiarkan sampai hangus.
  tidakDijawab,

  /// Dialog muncul dan ditolak.
  ditolak,

  /// Ponsel masih menyimpan kunci lama. Pulih setelah [BleService.lupakanPenyandingan].
  bondBasi,
}

/// Jam palsu untuk Fase UI dan test.
///
/// [percepatan] memampatkan jadwal: dengan 360, jeda 1 jam menjadi 10 detik,
/// sehingga sesi berjalan sampai selesai bisa diamati (dan diuji) tanpa
/// menunggu dua jam sungguhan.
///
/// [lewatkan] berisi index sampel yang sengaja tidak pernah dikirim, untuk
/// menguji sesi yang berakhir `tidakLengkap`.
///
/// [otomatisSelesaiMakan] mensimulasikan user menekan tombol di jam sekian
/// detik (waktu nyata, ikut dipercepat) setelah foto diambil. Selama Fase UI
/// tidak ada jam sungguhan untuk ditekan, jadi tanpa ini demo aplikasi buntu
/// di status draft. Test mematikannya dan menekan sendiri lewat
/// [tekanSelesaiMakan] agar deterministik.
///
/// [penyandingan] memodelkan dialog penyandingan sistem, termasuk yang **tidak
/// pernah dijawab** dan yang **kuncinya sudah basi**. Keduanya tidak bisa
/// dipesan pada jam sungguhan, sementara justru merekalah jalur yang paling
/// membingungkan pengguna — jadi tanpa tiruan di sini, seluruh copy
/// docs/alur-pemasangan-jam.md §5 tidak pernah bisa dilihat sebelum ada
/// perangkat keras di tangan.
class FakeBleService implements BleService {
  FakeBleService({
    this.percepatan = 360,
    this.lewatkan = const {},
    this.otomatisSelesaiMakan = 600,
    this.penyandingan = PenyandinganPalsu.tidakPerlu,
    this.galatUkurSekarang,
    this.metrikGagal = const {},
    KemampuanPerangkat kemampuan = KemampuanPerangkat.semua,
    StatusPerangkat? status,
    int benih = 7,
  }) : _status =
           (status ??
                   const StatusPerangkat(
                     tersambung: true,
                     baterai: 68,
                     namaPerangkat: 'AsaWatch X1',
                   ))
               .salin(kemampuan: kemampuan),
       _acak = Random(benih);

  final int percepatan;
  final Set<int> lewatkan;
  final int? otomatisSelesaiMakan;
  final PenyandinganPalsu penyandingan;

  /// Bila diisi, [ukurSekarang] selalu gagal dengan kalimat ini.
  ///
  /// Jam sungguhan tidak bisa dipesan untuk gagal, sementara justru jalur
  /// gagalnya yang paling perlu dilihat sebelum ada perangkat keras: baterai
  /// habis, sensor tidak membaca, jam tidak menjawab.
  final String? galatUkurSekarang;

  /// **[kemampuan] berbeda dari [metrikGagal], dan bedanya adalah seluruh
  /// gunanya.** `metrikGagal` adalah sensor yang **ada tetapi gagal membaca** —
  /// UI menulis "Tidak terbaca". `kemampuan` adalah sensor yang **memang tidak
  /// ada di alat itu** — UI menyembunyikan metriknya sama sekali (protokol §3).
  /// Menyamakan keduanya menyuruh pengguna merapatkan tali jam untuk sensor yang
  /// tidak pernah dipasang. Diteruskan lewat `StatusPerangkat.kemampuan` persis
  /// seperti jam sungguhan meneruskannya dari byte 11 handshake.
  ///
  /// Nama metrik yang sengaja tidak terbaca pada [ukurSekarang] — `'gula'`,
  /// `'detak'`, `'tekanan'`, `'spo2'`.
  ///
  /// Protokol menyatakan metrik gagal dengan sentinel 0 → null (§5.2), dan
  /// halaman pindai memperlakukannya berbeda dari angka yang ada. Tanpa ini,
  /// perbedaan itu tidak pernah terlihat.
  final Set<String> metrikGagal;

  final Random _acak;

  /// Keadaan penyandingan yang **berjalan**, terpisah dari [penyandingan] yang
  /// menyatakan keadaan awal: `bondBasi` harus bisa pulih setelah penyandingan
  /// lamanya dihapus, dan penyandingan yang sudah berhasil tidak diminta lagi
  /// pada penyambungan berikutnya — persis seperti bond sungguhan.
  late PenyandinganPalsu _penyandingan = penyandingan;

  StatusPerangkat _status;
  final _pengendaliStatus = StreamController<StatusPerangkat>.broadcast();
  final _pengendaliTahap = StreamController<TahapSambung>.broadcast();
  final _pengendaliSampel =
      StreamController<({String sesiId, Sampel sampel})>.broadcast();
  final _pengendaliT0 =
      StreamController<
        ({String sesiId, DateTime t0, bool waktuTidakPasti})
      >.broadcast();
  final _timer = <Timer>[];

  /// Sesi yang tombol "Selesai Makan"-nya sedang menyala di jam. null berarti
  /// jam menolak tombolnya — belum ada foto makanan.
  String? _sesiSiap;
  bool _sudahDitekan = false;

  int? _gulaBaseline;

  @override
  Stream<StatusPerangkat> get statusPerangkat => _pengendaliStatus.stream;

  @override
  Stream<({String sesiId, Sampel sampel})> get sampelMasuk =>
      _pengendaliSampel.stream;

  @override
  Stream<({String sesiId, DateTime t0, bool waktuTidakPasti})>
  get selesaiMakanDitekan => _pengendaliT0.stream;

  @override
  StatusPerangkat get statusTerakhir => _status;

  Duration _jeda(int detikNyata) =>
      Duration(milliseconds: (detikNyata * 1000 / percepatan).round());

  @override
  Future<bool> siapkanSesi(String sesiId) async {
    if (!_status.tersambung) return false;
    _sesiSiap = sesiId;
    _sudahDitekan = false;

    final otomatis = otomatisSelesaiMakan;
    if (otomatis != null) {
      _timer.add(Timer(_jeda(otomatis), tekanSelesaiMakan));
    }
    return true;
  }

  /// Tombol fisik di jam ditekan.
  ///
  /// Ditolak diam-diam bila jam belum disiapkan (belum ada foto) atau sudah
  /// pernah ditekan untuk sesi ini — dua hal yang di jam sungguhan diurus
  /// firmware, bukan aplikasi.
  /// [waktuTidakPasti] mensimulasikan boot jam yang tidak pernah punya anchor
  /// (protokol §4.3) — keadaan yang di jam sungguhan tidak bisa dipesan, tetapi
  /// tetap harus punya jalur yang benar di aplikasi.
  bool tekanSelesaiMakan({DateTime? waktu, bool waktuTidakPasti = false}) {
    final sesiId = _sesiSiap;
    if (sesiId == null || _sudahDitekan) return false;
    _sudahDitekan = true;

    final t0 = waktu ?? DateTime.now();
    if (!_pengendaliT0.isClosed) {
      _pengendaliT0.add((
        sesiId: sesiId,
        t0: t0,
        waktuTidakPasti: waktuTidakPasti,
      ));
    }

    // Sejak tombolnya ditekan, jam sendiri yang menjadwalkan sisa sampelnya.
    for (final index in const [1, 2, 3]) {
      if (lewatkan.contains(index)) continue;
      final detik = switch (index) {
        1 => 0,
        2 => 3600,
        _ => 7200,
      };
      _timer.add(
        Timer(_jeda(index == 1 ? 20 : detik), () {
          _kirim(sesiId, _buatSampel(index, detik));
        }),
      );
    }
    return true;
  }

  @override
  Future<bool> mulaiSesi(String sesiId) async {
    // Meniru jam sungguhan: perintah ini **tidak** membawa waktu, dan yang
    // menetapkan t0 tetap [tekanSelesaiMakan] — tombol jam itu sendiri. Yang
    // dilakukan aplikasi hanya menekannya dari jauh.
    if (!_status.tersambung) return false;
    if (_sesiSiap != sesiId) return false; // jam belum di-ARM untuk sesi ini

    // Idempoten, seperti yang dijanjikan kontraknya: sesi yang sudah berjalan
    // di-ACK dan diabaikan, bukan diberi t0 kedua.
    if (_sudahDitekan) return true;

    return tekanSelesaiMakan();
  }

  @override
  Future<bool> mintaUkur(String sesiId, int index) async {
    // Jam sungguhan menolak `UKUR` selama belum di-ARM (§9), dan jam yang
    // terputus tidak menerimanya sama sekali. Jam palsu meniru keduanya supaya
    // jalur "baseline tidak akan pernah datang" benar-benar terlewati di test.
    if (!_status.tersambung || _sesiSiap != sesiId) return false;
    if (lewatkan.contains(index)) return false;

    // Pengukuran atas permintaan tetap butuh waktu di jam sungguhan.
    _timer.add(
      Timer(_jeda(20), () {
        _kirim(sesiId, _buatSampel(index, index == 0 ? -1500 : 0));
      }),
    );
    return true;
  }

  @override
  Future<void> batalkanSesi(String sesiId) async {
    _bersihkanTimer();
    _sesiSiap = null;
    _sudahDitekan = false;
    _gulaBaseline = null;
  }

  @override
  Future<Sampel> ukurSekarang() async {
    // Jam sungguhan menolak perintah ini saat terputus, dan halaman pindai
    // menampilkan sebabnya apa adanya. Tanpa tiruan di sini jalur itu tidak
    // pernah terlewati sebelum ada perangkat keras.
    if (!_status.tersambung) {
      throw const GalatJam(
        'Jam tidak tersambung, jadi pengukuran belum bisa dimulai.',
      );
    }
    if (galatUkurSekarang != null) {
      await Future<void>.delayed(_jeda(30));
      throw GalatJam(galatUkurSekarang!);
    }

    await Future<void>.delayed(_jeda(30));
    // Pengukuran di luar sesi tidak punya t0 dan tidak punya urutan titik ukur;
    // `index` 1 hanya mengikuti bentuk paketnya (§5.1), bukan posisi di jadwal.
    return _buatSampel(1, 0, gagal: metrikGagal);
  }

  @override
  Future<void> kirimKalibrasi(Kalibrasi kalibrasi) async {
    await Future<void>.delayed(_jeda(10));
  }

  /// Katalog perangkat yang "ada di sekitar" saat memindai.
  ///
  /// Perangkat asing tetap ada di sini meskipun tidak pernah sampai ke
  /// pemanggil: ia mewakili udara yang sebenarnya, dan penyaringannya di
  /// [pindai] adalah tiruan dari filter yang sama di level OS pada
  /// `BleAsliService`. Menghapusnya dari katalog akan membuat penyaringan itu
  /// tidak terlihat sedang menyaring apa pun.
  static const _katalog = <PerangkatDitemukan>[
    PerangkatDitemukan(
      id: 'AW-X1-0A73',
      nama: 'AsaWatch X1',
      kekuatanSinyal: -48,
    ),
    PerangkatDitemukan(
      id: 'AW-S2-19C4',
      nama: 'AsaWatch S2',
      kekuatanSinyal: -74,
    ),
    PerangkatDitemukan(
      id: 'BT-4F21',
      nama: 'Perangkat BLE tidak dikenal',
      kekuatanSinyal: -88,
      didukung: false,
    ),
  ];

  @override
  Stream<PerangkatDitemukan> pindai() {
    // Sengaja memakai timer, bukan `async*`: membatalkan langganan harus
    // langsung menghentikan pemindaian. Generator `async*` baru berhenti di
    // titik `await` berikutnya, sehingga timer-nya menggantung sampai jeda
    // terakhir habis — di test itu terbaca sebagai timer yang belum selesai.
    final timers = <Timer>[];
    late final StreamController<PerangkatDitemukan> pengendali;

    // Hanya AsaWatch yang keluar, meniru filter service UUID di level OS yang
    // dipakai `BleAsliService`. Perangkat lain memang ada di udara — ia hanya
    // tidak pernah sampai ke aplikasi.
    final terlihat = [
      for (final p in _katalog)
        if (p.didukung) p,
    ];

    pengendali = StreamController<PerangkatDitemukan>(
      onListen: () {
        // Jeda antar-temuan ikut dipercepat, jadi test tidak menunggu detik
        // nyata.
        for (var i = 0; i < terlihat.length; i++) {
          timers.add(
            Timer(_jeda(2 * (i + 1)), () {
              if (!pengendali.isClosed) pengendali.add(terlihat[i]);
            }),
          );
        }
        timers.add(
          Timer(_jeda(2 * (terlihat.length + 1)), () {
            if (!pengendali.isClosed) pengendali.close();
          }),
        );
      },
      onCancel: () {
        for (final t in timers) {
          t.cancel();
        }
      },
    );
    return pengendali.stream;
  }

  @override
  Stream<TahapSambung> get tahapSambung => _pengendaliTahap.stream;

  @override
  String? get galatTerakhir => null;

  void _tahap(TahapSambung tahap) {
    if (!_pengendaliTahap.isClosed) _pengendaliTahap.add(tahap);
  }

  @override
  Future<HasilSambung> sambungkan(String idPerangkat) async {
    _tahap(TahapSambung.menyambung);
    await Future<void>.delayed(_jeda(3));

    final cocok = _katalog.where((p) => p.id == idPerangkat && p.didukung);
    if (cocok.isEmpty) return HasilSambung.diLuarJangkauan;
    final perangkat = cocok.first;

    if (_penyandingan != PenyandinganPalsu.tidakPerlu) {
      _tahap(TahapSambung.menyandingkan);
      // Jedanya ikut dipercepat, tetapi urutannya nyata: keadaan
      // `menyandingkan` selalu sempat terlihat sebelum hasilnya diketahui.
      // Tanpa itu, layar §4.3 yang paling penting justru tidak pernah terpakai.
      await Future<void>.delayed(_jeda(5));
      switch (_penyandingan) {
        case PenyandinganPalsu.ditolak:
          return HasilSambung.penyandinganDitolak;
        case PenyandinganPalsu.tidakDijawab:
          // Dialog yang hangus sendiri, bukan yang dijawab. Jedanya panjang
          // supaya petunjuk panel notifikasi (§4.4) sempat muncul lebih dulu.
          await Future<void>.delayed(_jeda(120));
          return HasilSambung.penyandinganTidakDijawab;
        case PenyandinganPalsu.bondBasi:
          return HasilSambung.bondBasi;
        case PenyandinganPalsu.dijawab:
          // Tersandingkan; penyambungan berikutnya tidak menanyakannya lagi.
          _penyandingan = PenyandinganPalsu.tidakPerlu;
        case PenyandinganPalsu.tidakPerlu:
          break;
      }
    }

    _tahap(TahapSambung.menyiapkan);
    await Future<void>.delayed(_jeda(2));

    _perbaruiStatus(
      StatusPerangkat(
        tersambung: true,
        baterai: _status.baterai ?? 68,
        sampelTertunda: _status.sampelTertunda,
        sinkronTerakhir: _status.sinkronTerakhir,
        namaPerangkat: perangkat.nama,
      ),
    );
    return HasilSambung.berhasil;
  }

  @override
  Future<bool> lupakanPenyandingan(String idPerangkat) async {
    // Kunci lama dibuang, jadi percobaan berikutnya menyandingkan dari awal —
    // dan kali ini berhasil, seperti jam sungguhan yang penyandingan basinya
    // sudah dihapus dari ponsel.
    if (_penyandingan == PenyandinganPalsu.bondBasi) {
      _penyandingan = PenyandinganPalsu.dijawab;
    }
    return true;
  }

  @override
  Future<void> putuskan() async {
    // Namanya sengaja dipertahankan: jam yang diputus tetap jam yang sudah
    // dipasangkan, dan sampelnya menumpuk di buffer sampai tersambung lagi.
    _perbaruiStatus(_status.salin(tersambung: false));
  }

  @override
  Future<void> lupakanPerangkat() async {
    _bersihkanTimer();
    _sesiSiap = null;
    _sudahDitekan = false;
    // Kembali ke keadaan "belum pernah dipasangkan" seutuhnya — termasuk
    // namanya, yang justru itulah pembedanya dari sekadar terputus.
    _penyandingan = penyandingan == PenyandinganPalsu.tidakPerlu
        ? PenyandinganPalsu.tidakPerlu
        : PenyandinganPalsu.dijawab;
    _perbaruiStatus(StatusPerangkat.kosong);
  }

  @override
  Future<void> sinkronkan() async {
    // Buffer jam ikut terkuras, tetapi identitas jamnya tetap.
    _perbaruiStatus(
      _status.salin(sampelTertunda: 0, sinkronTerakhir: DateTime.now()),
    );
  }

  /// Dipakai test/demo untuk mensimulasikan jam yang putus atau menyimpan
  /// sampel di buffer.
  void perbaruiStatus(StatusPerangkat status) => _perbaruiStatus(status);

  /// Mengirim satu sampel apa adanya — dipakai test untuk mengatur waktu dan
  /// jumlah pengiriman sendiri, termasuk pengiriman ganda yang harus di-dedup.
  void kirimSampel(String sesiId, Sampel sampel) => _kirim(sesiId, sampel);

  void _perbaruiStatus(StatusPerangkat status) {
    _status = status;
    if (!_pengendaliStatus.isClosed) _pengendaliStatus.add(status);
  }

  void _kirim(String sesiId, Sampel sampel) {
    if (!_pengendaliSampel.isClosed) {
      _pengendaliSampel.add((sesiId: sesiId, sampel: sampel));
    }
  }

  Sampel _buatSampel(
    int index,
    int detikRelatifT0, {
    Set<String> gagal = const {},
  }) {
    final dasar = _gulaBaseline ??= 88 + _acak.nextInt(10);
    final gula = switch (index) {
      0 => dasar,
      1 => dasar + 4 + _acak.nextInt(8),
      2 => dasar + 38 + _acak.nextInt(20),
      _ => dasar + 2 + _acak.nextInt(12),
    };
    // Metrik yang "gagal diukur" adalah null, bukan 0: sentinel 0 milik kawat
    // dan tidak pernah boleh sampai ke UI (§5.2).
    return Sampel(
      index: index,
      detikRelatifT0: detikRelatifT0,
      status: StatusSampel.terisi,
      dariBuffer: !_status.tersambung,
      gulaDarah: gagal.contains('gula') ? null : gula,
      detakJantung: gagal.contains('detak') ? null : 70 + _acak.nextInt(20),
      sistolik: gagal.contains('tekanan') ? null : 112 + _acak.nextInt(14),
      diastolik: gagal.contains('tekanan') ? null : 74 + _acak.nextInt(9),
      spo2: gagal.contains('spo2') ? null : 96 + _acak.nextInt(3),
    );
  }

  void _bersihkanTimer() {
    for (final t in _timer) {
      t.cancel();
    }
    _timer.clear();
  }

  @override
  void dispose() {
    _bersihkanTimer();
    _pengendaliStatus.close();
    _pengendaliTahap.close();
    _pengendaliSampel.close();
    _pengendaliT0.close();
  }
}
