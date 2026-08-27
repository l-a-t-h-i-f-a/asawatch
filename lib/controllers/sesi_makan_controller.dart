import 'dart:async';
import 'dart:io' show File;

import 'package:flutter/foundation.dart';

import '../konfigurasi.dart';
import '../models/jadwal_sesi.dart';
import '../models/sesi_makan.dart';
import '../repositories/sesi_login_repository.dart';
import '../services/sesi_server_service.dart';
import '../repositories/entri_jam_repository.dart';
import '../repositories/kalibrasi_repository.dart';
import '../repositories/sesi_repository.dart';
import '../services/ble_service.dart';
import '../services/nutrisi_service.dart';
import '../services/kamera_service.dart' show jalurFotoTetap;
import '../services/pengingat_titik_ukur.dart';
import '../services/protokol_jam.dart' show GalatJam, buatIdSesi;

/// Satu-satunya state hidup di aplikasi (§12.6), disediakan lewat satu
/// `ChangeNotifierProvider` di atas `MaterialApp`.
///
/// Aturan yang dikunci di sini:
/// - hanya satu sesi aktif pada satu waktu;
/// - notifikasi ~4 kali seumur sesi, bukan tiap detik (hitung mundur ditangani
///   lokal oleh kartunya sendiri);
/// - sampel di-dedup dengan kunci `(sesiId, index)` karena pengiriman jam
///   bersifat at-least-once;
/// - jadwal selalu diturunkan dari `t0` absolut, tidak pernah dari "sisa waktu".
class SesiMakanController extends ChangeNotifier {
  /// [riwayatAwal] adalah riwayat yang **sudah dimuat** oleh pemanggil dari
  /// [repo]; konstruktor ini sengaja tetap sinkron (lihat `SesiRepository`).
  /// [repo] dipakai sebagai tempat menulis. Bila null, sesi tidak disimpan ke
  /// mana pun — itu yang diinginkan sebagian besar test.
  ///
  /// Sesi yang **masih aktif** di dalam [riwayatAwal] dipulihkan sebagai sesi
  /// aktif, bukan dimasukkan ke riwayat (Tahap B). Jadwalnya dihitung ulang dari
  /// `t0` absolut, bukan dari sisa waktu, jadi aplikasi yang mati dua jam tidak
  /// menggeser satu titik ukur pun.
  SesiMakanController({
    required this.ble,
    required this.nutrisi,
    List<SesiMakan> riwayatAwal = const [],
    this.repo,
    this.repoKalibrasi,
    this.repoEntri,
    this.serverSesi,
    this.sesiLogin,
    Kalibrasi? kalibrasiAwal,
    JadwalSesi? jadwal,
    DateTime Function()? jam,
    PengingatTitikUkur? pengingat,
    Future<String> Function(String nama)? jalurFoto,
  }) : jalurFoto = jalurFoto ?? jalurFotoTetap,
       jam = jam ?? DateTime.now,
       pengingat = pengingat ?? const PengingatDiam(),
       jadwal = jadwal ?? jadwalBawaan,
       _riwayat = [
         for (final s in riwayatAwal)
           if (!s.status.sedangAktif) s,
       ],
       _kalibrasiTerakhir = kalibrasiAwal {
    // Satu sesi aktif pada satu waktu tetap berlaku setelah restart: bila basis
    // data entah bagaimana memuat lebih dari satu, yang terbaru yang dipakai dan
    // sisanya ditutup sebagai tidak lengkap — bukan dibiarkan menjadi dua.
    final aktif = [
      for (final s in riwayatAwal)
        if (s.status.sedangAktif) s,
    ]..sort((a, b) => (b.t0 ?? b.waktuFoto).compareTo(a.t0 ?? a.waktuFoto));

    if (aktif.isNotEmpty) {
      _sesiAktif = aktif.first;
      for (final s in aktif.first.sampel) {
        if (s.status != StatusSampel.menunggu) {
          _sampelDiterima.add('${aktif.first.id}#${s.index}');
        }
      }
      for (final basi in aktif.skip(1)) {
        _riwayat.add(basi.salin(status: StatusSesi.tidakLengkap));
      }
    }

    // Diisi sebelum langganan dipasang: pendengarnya membandingkan status baru
    // dengan yang sebelumnya, dan field `late` yang dibaca sebelum terisi akan
    // melempar alih-alih memberi jawaban.
    _statusPerangkat = ble.statusTerakhir;

    _langgananSampel = ble.sampelMasuk.listen(_terimaSampel);
    _langgananT0 = ble.selesaiMakanDitekan.listen(_terimaT0);
    _langgananStatus = ble.statusPerangkat.listen((status) {
      final sebelumnya = _statusPerangkat;
      _statusPerangkat = status;

      // Jam yang **baru** tersambung perlu disiapkan agar tombolnya menyala.
      //
      // Kata "baru" itu menahan sebuah umpan balik tanpa ujung. Jam sungguhan
      // mengirim notifikasi Status setiap kali keadaannya berubah — termasuk
      // saat ia berpindah ke ARMED karena `ARM_SESI` yang baru saja kita kirim.
      // Menyiapkan jam pada **setiap** status berarti: status → ARM_SESI →
      // status → ARM_SESI → … selamanya, dengan radio menulis terus-menerus.
      //
      // Ini tidak terlihat selama hanya ada `FakeBleService`, yang mengirim
      // status hanya saat tersambung, terputus, dan sinkron.
      if (status.tersambung && !sebelumnya.tersambung) {
        // Koneksi baru berarti jam mungkin sudah lupa ARM-nya (ia sempat mati,
        // atau ARM-nya kedaluwarsa 4 jam, §5.1). Siapkan ulang.
        _sesiDiarm = null;
      }
      if (!status.tersambung) {
        _sesiDiarm = null;
        // Jam yang terputus melupakan ARM titiknya juga (ia mungkin sempat
        // mati). Kunci yang tertinggal akan menahan ARM ulang saat ia kembali.
        _titikDiarm = null;
      }

      unawaited(_siapkanJam());
      unawaited(_armTitikBerikutnya());
      notifyListeners();
    });

    if (_sesiAktif != null) {
      unawaited(_siapkanJam()); // sesi draft yang dipulihkan perlu di-ARM lagi
      unawaited(_armTitikBerikutnya());
      _jadwalkanTenggat();
    }
  }

  final BleService ble;
  final NutrisiService nutrisi;

  /// Jadwal titik ukur sesi baru — docs/jadwal-titik-ukur.md.
  ///
  /// Data, bukan literal, sejak protokol v1.3 memindahkan penjadwalan dari
  /// firmware ke sini (§9, §12). Bawaannya [jadwalBawaan], yang mengikuti
  /// `--dart-define=PAKAI_JADWAL_UJI`; test menyuntikkan jadwalnya sendiri.
  ///
  /// **Sesi yang sudah berjalan tidak memakainya.** Jadwal sebuah sesi ikut
  /// tersimpan sebagai `detikRelatifT0` tiap barisnya, jadi sesi yang dipulihkan
  /// dari basis data tetap memakai jadwal yang berlaku saat ia dibuat — bukan
  /// yang berlaku saat aplikasi dibuka. Rakitan uji yang membuka sesi sungguhan
  /// lama tidak boleh memendekkannya jadi dua menit.
  final JadwalSesi jadwal;

  /// Sumber "sekarang" untuk seluruh perhitungan jadwal.
  ///
  /// Disuntikkan, bukan `DateTime.now()` langsung, dan alasannya bukan
  /// kerapian. Sejak protokol v1.3 memindahkan `t0` dan seluruh jadwal titik
  /// ukur ke aplikasi (§5.3), jam dinding ponsel menjadi bahan perhitungan —
  /// dan `tester.pump(Duration)` memajukan timer tanpa memajukan
  /// `DateTime.now()`. Tanpa seam ini, jendela toleransi, hitung mundur, dan
  /// penundaan `ARM_TITIK` adalah tiga hal yang tidak ada satu pun test bisa
  /// memeriksanya.
  final DateTime Function() jam;

  /// Pengingat kapan titik ukur berikutnya jatuh tempo
  /// (docs/jadwal-titik-ukur.md §6).
  ///
  /// Bawaannya [PengingatDiam], bukan yang sungguhan, karena `main()` yang
  /// merakitnya — sama seperti `repo` dan `repoKalibrasi`. Tanpa itu setiap test
  /// yang menyentuh sesi akan mencoba memanggil platform channel notifikasi yang
  /// tidak ada di bawah `flutter_test`.
  final PengingatTitikUkur pengingat;
  final SesiRepository? repo;

  /// Unggahan riwayat ke server. null berarti aplikasi ini memang tidak
  /// mengunggah apa pun — keadaan yang sah, dan yang berlaku di seluruh test.
  final SesiServerService? serverSesi;

  /// Sumber token untuk [serverSesi].
  final SesiLoginRepository? sesiLogin;
  final KalibrasiRepository? repoKalibrasi;

  /// Kotak masuk mentah dari jam. Dipegang di sini **hanya** untuk
  /// [hapusDataLokal] — jalur normalnya milik `BleAsliService`, yang menulis dan
  /// membacanya sendiri. Tanpa rujukan ini, entri milik pengguna sebelumnya
  /// selamat dari pergantian akun dan diputar ulang saat aplikasi start,
  /// membangun kembali sesi yang baru saja dihapus.
  final EntriJamRepository? repoEntri;

  /// Di mana foto hasil unduhan disimpan. Bawaannya folder tetap aplikasi;
  /// disuntikkan oleh test karena `path_provider` tidak punya platform channel
  /// di bawah `flutter_test` — dan tanpa seam ini satu-satunya jalur yang bisa
  /// diuji adalah jalur gagalnya.
  final Future<String> Function(String nama) jalurFoto;

  /// Berapa lama setelah titik terakhir (`t0 + 2 jam`) sebuah sesi berhenti
  /// ditunggu dan ditutup sebagai `tidakLengkap`.
  ///
  /// Bukan nol: sampel yang datang terlambat lewat buffer jam adalah perilaku
  /// normal (§6), dan sesi yang gugur satu detik setelah tenggat akan menolak
  /// data yang sebenarnya sudah terkumpul dengan benar di pergelangan tangan.
  ///
  /// Kini bagian dari [jadwal], supaya mode uji mengecilkannya bersama titiknya
  /// — tenggat 30 menit di atas sesi dua menit akan membuat setiap sesi uji
  /// menggantung setengah jam sesudah titik terakhirnya.
  Duration get tenggatSampelTerakhir => jadwal.tenggatSetelahAkhir;

  StreamSubscription<({String sesiId, Sampel sampel})>? _langgananSampel;
  StreamSubscription<({String sesiId, DateTime t0, bool waktuTidakPasti})>?
  _langgananT0;
  StreamSubscription<StatusPerangkat>? _langgananStatus;

  final List<SesiMakan> _riwayat; // terbaru di depan
  final Set<String> _sampelDiterima = {}; // kunci "sesiId#index"

  SesiMakan? _sesiAktif;
  SesiMakan? _hasilBelumDibaca;
  late StatusPerangkat _statusPerangkat;
  Timer? _tenggat;

  /// Id sesi yang tombolnya sudah dinyalakan di jam pada koneksi yang sedang
  /// berjalan; null berarti belum, atau jam sempat terputus sejak itu.
  ///
  /// Ada semata-mata untuk membuat `_siapkanJam()` idempoten. Tanpa itu setiap
  /// notifikasi status memicu satu `ARM_SESI` baru, dan `ARM_SESI` mengubah
  /// keadaan jam sehingga jam mengirim notifikasi status berikutnya.
  String? _sesiDiarm;

  SesiMakan? get sesiAktif => _sesiAktif;

  String? _galatPenyimpanan;

  /// Pesan bila sesi terakhir gagal ditulis ke penyimpanan; null bila tidak ada
  /// masalah. Ditampilkan Beranda sampai dibuang lewat [buangGalatPenyimpanan].
  String? get galatPenyimpanan => _galatPenyimpanan;

  void buangGalatPenyimpanan() {
    if (_galatPenyimpanan == null) return;
    _galatPenyimpanan = null;
    notifyListeners();
  }

  /// Sesi yang baru selesai dan kartunya masih harus ditampilkan di Beranda
  /// sampai dibuka user (§4.1 wajah C).
  SesiMakan? get hasilBelumDibaca => _hasilBelumDibaca;

  List<SesiMakan> get riwayat => List.unmodifiable(_riwayat);

  StatusPerangkat get statusPerangkat => _statusPerangkat;

  /// Ada sesi mode uji tersimpan — dipakai Profil untuk memunculkan tombol
  /// pembersihannya.
  ///
  /// Sengaja diturunkan dari isi riwayat, bukan dari `pakaiJadwalUji`. Sesi uji
  /// tetap ada di basis data tester lama setelah build ujinya diganti, dan
  /// justru rakitan **tanpa** flag itulah yang paling perlu bisa
  /// membersihkannya.
  bool get adaSesiUji => _riwayat.any((s) => s.sesiUji);

  /// Menghapus seluruh sesi mode uji, berikut sampel dan hasil deteksinya.
  ///
  /// Ada supaya tester bisa membersihkan sendiri tanpa menghapus data aplikasi
  /// — yang juga akan menghapus penyandingan jamnya, dan menyandingkan ulang
  /// adalah alur terpanjang di aplikasi ini.
  Future<void> hapusSesiUji() async {
    final uji = [
      for (final s in _riwayat)
        if (s.sesiUji) s,
    ];
    if (uji.isEmpty) return;

    _riwayat.removeWhere((s) => s.sesiUji);
    if (_hasilBelumDibaca?.sesiUji ?? false) _hasilBelumDibaca = null;
    notifyListeners();

    for (final s in uji) {
      _lupakanKunci(s.id);
      try {
        await repo?.hapus(s.id);
      } catch (e) {
        // Barisnya sudah hilang dari layar; gagal menghapusnya di basis data
        // berarti ia kembali saat aplikasi dibuka lagi. Itu mengganggu, bukan
        // merusak — dan sesi uji memang tidak ikut hitungan apa pun.
        debugPrint('Sesi uji ${s.id} gagal dihapus: $e');
      }
    }
  }

  SesiMakan? get sesiTerakhir => _riwayat.isEmpty ? null : _riwayat.first;

  /// Sesi hari ini, dipakai ringkasan nutrisi harian di Beranda.
  ///
  /// Sesi berwaktu tidak pasti tidak pernah ikut: "hari ini" adalah pertanyaan
  /// tentang jam dinding, dan sesi itu justru yang jam dindingnya tidak diketahui
  /// (docs/protokol-jam.md §4.3). Memasukkannya berarti total nutrisi harian yang
  /// mungkin milik hari lain.
  List<SesiMakan> sesiHariIni({DateTime? sekarang}) {
    final now = sekarang ?? jam();
    final hariIni = DateTime(now.year, now.month, now.day);
    bool samaHari(SesiMakan s) {
      // Sesi uji tidak ikut ringkasan hari ini karena kalorinya bukan kalori
      // siapa pun: `nutrisiHariIni` menjumlahkannya, dan angka itu tampil di
      // Beranda sebagai fakta tentang penggunanya.
      if (s.waktuTidakPasti || s.sesiUji) return false;
      final d = s.t0 ?? s.waktuFoto;
      return !d.isBefore(hariIni) &&
          d.isBefore(hariIni.add(const Duration(days: 1)));
    }

    final aktif = _sesiAktif;
    return [
      if (aktif != null && samaHari(aktif)) aktif,
      ..._riwayat.where(samaHari),
    ];
  }

  /// Total nutrisi hari ini. Sesi yang analisisnya belum selesai dilewati,
  /// bukan ditaksir.
  Nutrisi totalNutrisiHariIni({DateTime? sekarang}) {
    // Bermula dari "tidak diketahui", bukan dari nol: hari yang belum punya
    // satu pun angka gizi harus terbaca sebagai belum diketahui, bukan sebagai
    // nol kalori — yang di Beranda akan tampil sebagai fakta tentang
    // penggunanya.
    var total = Nutrisi.tidakDiketahui;
    for (final s in sesiHariIni(sekarang: sekarang)) {
      final hasil = s.hasil;
      if (hasil != null) total = total + hasil.total;
    }
    return total;
  }

  /// Zat yang total hariannya hanya jumlah parsial.
  ///
  /// Gabungan penanda dari setiap sesi hari ini: satu makanan yang tidak ada di
  /// tabel gizi sudah cukup membuat total sehari menjadi "sekurang-kurangnya".
  Set<ZatGizi> zatTidakLengkapHariIni({DateTime? sekarang}) => {
    for (final s in sesiHariIni(sekarang: sekarang))
      ...?s.hasil?.zatTidakLengkap,
  };

  /// Puncak gula darah beberapa sesi terakhir, urut lama → baru, untuk
  /// sparkline di Beranda.
  List<double> puncakTerakhir({int jumlah = 7}) {
    final nilai = <double>[];
    for (final s in _riwayat) {
      final puncak = s.puncakGulaDarah;
      if (puncak != null) nilai.add(puncak.toDouble());
      if (nilai.length == jumlah) break;
    }
    return nilai.reversed.toList();
  }

  // --- Tenggat sesi -----------------------------------------------------
  //
  // Sampai Tahap B, satu-satunya jalan sebuah sesi berakhir `tidakLengkap`
  // adalah user menekan "akhiri lebih awal". Dengan jam sungguhan itu tidak
  // cukup: jam yang kehabisan baterai, di-reboot, atau sensornya gagal
  // (protokol §9) meninggalkan sesi yang menunggu sampel yang tidak akan pernah
  // datang, dan tidak ada seorang pun yang akan datang menutupnya.

  /// Kapan sesi ini berhenti ditunggu. null bila `t0` belum ada — sesi draft
  /// menunggu tombol jam, dan tombol itu tidak punya tenggat di sisi aplikasi
  /// (jam sendiri yang kedaluwarsa setelah 4 jam, §5.1).
  DateTime? _batasTunggu(SesiMakan sesi) {
    final t0 = sesi.t0;
    if (t0 == null) return null;
    final titikTerakhir = sesi.sampel.last.detikRelatifT0;
    return t0.add(Duration(seconds: titikTerakhir)).add(tenggatSampelTerakhir);
  }

  void _jadwalkanTenggat() {
    _tenggat?.cancel();
    _tenggat = null;

    final sesi = _sesiAktif;
    if (sesi == null) return;
    final batas = _batasTunggu(sesi);
    if (batas == null) return;

    final sisa = batas.difference(jam());
    if (!sisa.isNegative) {
      _tenggat = Timer(sisa, _lewatTenggat);
      return;
    }
    // Sesi yang dipulihkan dari basis data bisa sudah lewat tenggat sejak lama.
    // Ditutup segera, tetapi lewat microtask supaya konstruktor tidak
    // memanggil `notifyListeners()` sebelum ada yang mendengarkan.
    scheduleMicrotask(_lewatTenggat);
  }

  /// Tenggat lewat: yang belum datang dinyatakan terlewat dan sesinya ditutup.
  ///
  /// Sesinya **tidak dibatalkan** — sampel yang sudah masuk tetap data yang sah,
  /// dan `tidakLengkap` justru status yang menyatakan itu.
  void _lewatTenggat() {
    final sesi = _sesiAktif;
    if (sesi == null || sesi.t0 == null) return;
    if (sesi.sampelBerikutnya == null) return; // sudah lengkap
    _selesaikan(_tandaiSisanyaTerlewat(sesi));
  }

  SesiMakan _tandaiSisanyaTerlewat(SesiMakan sesi) {
    final sampel = [
      for (final s in sesi.sampel)
        s.status == StatusSampel.menunggu
            ? Sampel(
                index: s.index,
                detikRelatifT0: s.detikRelatifT0,
                status: StatusSampel.terlewat,
              )
            : s,
    ];
    return sesi.salin(sampel: sampel, status: StatusSesi.tidakLengkap);
  }

  // --- Siklus sesi ------------------------------------------------------

  /// Shutter kamera ditekan: sesi draft dibuat, baseline pra-makan diminta ke
  /// jam, dan analisis nutrisi berjalan di belakang.
  Future<void> mulaiDraft(String fotoPath) async {
    if (_sesiAktif != null) {
      throw StateError(
        'Masih ada sesi aktif. Akhiri sesi berjalan lebih dulu (§6).',
      );
    }

    final sekarang = jam();
    // UUID, bukan stempel waktu: protokol membawa `sesiId` sebagai 16 byte biner
    // (§5.1), jadi id harus bisa bolak-balik utuh ke sana.
    final id = buatIdSesi();
    _sesiAktif = SesiMakan(
      id: id,
      fotoPath: fotoPath,
      waktuFoto: sekarang,
      status: StatusSesi.draft,
      sampel: [
        for (final t in jadwal.titik)
          Sampel.menunggu(index: t.index, detikRelatifT0: t.detikNominal),
      ],
      // Ditandai di sini, saat sesinya lahir, karena inilah satu-satunya saat
      // fakta ini masih diketahui. Sesudah tersimpan, sesi dua menit tidak bisa
      // dibedakan dengan pasti dari sesi sungguhan yang semua titiknya
      // terlewat.
      sesiUji: jadwal.uji,
    );
    // Ditulis sejak draft, bukan menunggu sesi berakhir: foto sudah diambil dan
    // baseline sudah diminta ke jam, jadi aplikasi yang ditutup sekarang tetap
    // harus menemukan sesinya saat dibuka lagi.
    _simpanAktif();
    notifyListeners();

    // **ARM dulu, baru minta baseline.** Urutannya tidak boleh dibalik: jam
    // hanya melayani `UKUR` index 0 dalam status ARMED (§9), dan selama ia masih
    // IDLE permintaan baseline ditolak diam-diam. Akibatnya tidak terlihat
    // sampai sesi berakhir — ketiga titik lain masuk dengan benar, lalu sesinya
    // menggantung karena baseline tidak pernah datang, dan baru tertutup
    // `tidakLengkap` setengah jam setelah titik terakhir.
    //
    // Tombol "Selesai Makan" di jam juga baru menyala setelah ARM: jam yang
    // menetapkan t0, tetapi hanya untuk sesi yang sudah punya makanannya.
    await _siapkanJam();
    if (!await ble.mintaUkur(id, 0)) _tandaiBaselineTerlewat(id);
    unawaited(_analisisNutrisi(id, fotoPath));
  }

  /// Jam menolak mengukur baseline, jadi titik itu tidak akan pernah terisi.
  ///
  /// Ditandai `terlewat` sekarang, bukan dibiarkan `menunggu` sampai tenggat.
  /// Bedanya bukan kosmetik: titik yang "menunggu data" menjanjikan sesuatu yang
  /// sudah pasti tidak datang, menahan sesi tetap berjalan setengah jam setelah
  /// titik terakhir, dan menyembunyikan sebabnya. Yang `terlewat` mengatakannya
  /// seketika — dan sesinya bisa selesai begitu ketiga titik lain masuk.
  void _tandaiBaselineTerlewat(String sesiId) {
    final sesi = _sesiAktif;
    if (sesi == null || sesi.id != sesiId) return;
    if (sesi.sampel[0].status != StatusSampel.menunggu) return;

    final sampel = [...sesi.sampel];
    sampel[0] = Sampel(
      index: 0,
      detikRelatifT0: sampel[0].detikRelatifT0,
      status: StatusSampel.terlewat,
    );
    _sesiAktif = sesi.salin(sampel: sampel);
    _simpanAktif();
    notifyListeners();
  }

  final Set<String> _sedangAnalisis = {};

  /// Analisis berjalan di latar belakang dan bisa selesai **setelah** controller
  /// dibuang — layar sesi ditutup, atau test berakhir. Memberi tahu pendengar
  /// sesudah itu melempar, jadi keadaannya harus ditanyakan lebih dulu.
  bool _dibuang = false;

  /// Apakah analisis gizi untuk [sesiId] sedang berjalan **sekarang**.
  ///
  /// Ini yang memisahkan dua keadaan yang sama-sama terlihat sebagai
  /// `hasil == null` tetapi berbeda artinya: "tunggu sebentar" dan "tidak akan
  /// pernah ada". Yang kedua terjadi pada sesi yang analisisnya gagal, dan pada
  /// sesi yang diunduh dari server — dan menggambar keduanya sebagai spinner
  /// berarti menjanjikan sesuatu yang tidak datang, selamanya.
  ///
  /// Sengaja hanya di memori: sesudah aplikasi ditutup tidak ada permintaan yang
  /// masih berjalan, jadi jawabannya memang false.
  bool sedangMenganalisis(String sesiId) => _sedangAnalisis.contains(sesiId);

  Future<void> _analisisNutrisi(String sesiId, String fotoPath) async {
    _sedangAnalisis.add(sesiId);
    if (!_dibuang) notifyListeners();
    try {
      final hasil = await _mintaHasil(sesiId, fotoPath);
      if (hasil == null) return; // dibiarkan kosong, dan UI mengatakannya
      _terapkanHasil(sesiId, hasil);
    } catch (_) {
      // Analisis gagal bukan alasan sesi gagal: t0 tetap akurat, sampelnya
      // tetap masuk, dan yang hilang hanya angka gizinya.
    } finally {
      _sedangAnalisis.remove(sesiId);
      if (!_dibuang) notifyListeners();
    }
  }

  /// Menempelkan hasil analisis ke sesinya — **di mana pun sesi itu berada**.
  ///
  /// Analisis bisa selesai setelah sesinya berakhir: jadwal uji menutup sesi
  /// dalam dua menit, dan analisis sungguhan bisa makan puluhan detik. Sebelum
  /// ini hasilnya hanya diterapkan bila sesi masih aktif, sehingga angka gizi
  /// yang sudah selesai dihitung dibuang begitu saja — dan gejalanya di layar
  /// tidak bisa dibedakan dari analisis yang gagal.
  ///
  /// Sesi yang **dibatalkan** memang tidak ditemukan di mana pun, dan itu
  /// benar: barisnya sudah dihapus.
  void _terapkanHasil(String sesiId, HasilDeteksi hasil) {
    final aktif = _sesiAktif;
    if (aktif != null && aktif.id == sesiId) {
      _sesiAktif = aktif.salin(hasil: hasil);
      _simpanAktif();
      return;
    }

    final i = _riwayat.indexWhere((s) => s.id == sesiId);
    if (i < 0) return;
    final diperbarui = _riwayat[i].salin(hasil: hasil);
    _riwayat[i] = diperbarui;
    if (_hasilBelumDibaca?.id == sesiId) _hasilBelumDibaca = diperbarui;
    unawaited(_simpan(diperbarui));
  }

  /// Dari mana angka gizinya datang.
  ///
  /// **Server bila ada akun, [nutrisi] bila tidak.** Fotonya harus ada di
  /// server sebelum bisa dianalisis di sana, dan itu menuntut sesinya lebih
  /// dulu ada — jadi urutannya: sesi draft diunggah, fotonya menyusul, baru
  /// analisis diminta. Ketiganya boleh gagal tanpa menjatuhkan apa pun: sesi
  /// tetap berjalan di ponsel, dan yang hilang cuma angka gizinya.
  ///
  /// Tanpa token, jalur ini tidak bisa ditempuh sama sekali — dan aplikasi
  /// harus tetap utuh tanpa akun (§2 aturan 3), jadi ia jatuh ke [nutrisi],
  /// yang selama belum ada layanan deteksi sungguhan berarti angka contoh.
  Future<HasilDeteksi?> _mintaHasil(String sesiId, String fotoPath) async {
    final server = serverSesi;
    final token = (await sesiLogin?.muat())?.token;
    if (server == null || token == null) return nutrisi.analisis(fotoPath);

    final sesi = _cariSesi(sesiId);
    if (sesi == null) return null;

    // Sesi draft-nya dulu: endpoint foto menolak sesi yang belum ada di server.
    if (!await server.kirim(token, sesi)) return null;
    if (!await server.kirimFoto(token, sesiId, fotoPath)) return null;
    return server.mintaAnalisis(token, sesiId);
  }

  /// Menyalakan tombol "Selesai Makan" di jam untuk sesi draft yang sedang
  /// ditunggu, lalu menyesuaikan statusnya.
  ///
  /// Dipanggil saat draft dibuat dan setiap kali jam tersambung kembali:
  /// selama jam belum tersambung, penyiapannya tidak pernah sampai dan sesi
  /// berdiri di `menungguPerangkat`.
  /// Titik yang sedang ditunggu pengukurannya, atau null bila tidak ada.
  ///
  /// Hanya titik berjendela — baseline dan t0 dipicu peristiwa, bukan jadwal.
  TitikJadwal? get titikBerikutnya {
    final sesi = _sesiAktif;
    if (sesi == null || sesi.t0 == null) return null;
    final menunggu = [
      for (final t in sesi.jadwal.titik)
        if (t.berjendela &&
            sesi.sampel.any(
              (s) => s.index == t.index && s.status == StatusSampel.menunggu,
            ))
          t,
    ]..sort((a, b) => a.detikNominal.compareTo(b.detikNominal));
    return menunggu.isEmpty ? null : menunggu.first;
  }

  /// Berapa lama lagi sampai [titikBerikutnya] boleh diukur. Nol atau negatif
  /// berarti jendelanya sudah terbuka.
  Duration? get sisaSampaiTitikBerikutnya {
    final titik = titikBerikutnya;
    final t0 = _sesiAktif?.t0;
    if (titik == null || t0 == null) return null;
    return Duration(seconds: titik.jendelaAwal!) - jam().difference(t0);
  }

  /// Mengukur titik sesi berikutnya dari aplikasi (`UKUR`, protokol §5.1).
  ///
  /// Pasangan tombol fisik di jam, bukan penggantinya — keduanya mengirim
  /// perintah yang sama dan hasilnya masuk lewat jalur yang sama. Yang membuat
  /// keduanya perlu ada: jam dimatikan di antara titik ukur, dan orang yang
  /// menyalakannya kembali belum tentu sedang memegang ponselnya.
  ///
  /// Rangkap dari dua tombol tidak perlu ditangani di sini — dedup
  /// `(sesiId, index)` di [_terimaSampel] sudah membuangnya diam-diam, dan
  /// memang tidak boleh ada balapan yang terlihat pengguna.
  ///
  /// Mengembalikan pesan galat, atau null bila perintahnya terkirim. Yang
  /// ditunggu sesudahnya adalah sampelnya sendiri: layar tidak boleh menyatakan
  /// titik itu terisi sebelum jamnya menjawab.
  Future<String?> ukurTitikSekarang() async {
    final sesi = _sesiAktif;
    final titik = titikBerikutnya;
    if (sesi == null || titik == null) return null;

    if (!_statusPerangkat.tersambung) {
      return _statusPerangkat.namaPerangkat == null
          ? 'Belum ada jam yang tersandingkan.'
          : 'Jam belum tersambung. Nyalakan jam dan dekatkan ke ponsel, lalu '
                'coba lagi.';
    }

    // Terlalu cepat ditahan, bukan ditandai: titik ini belum lewat dan masih
    // bisa diukur dengan benar sebentar lagi (docs/jadwal-titik-ukur.md §3).
    final sisa = sisaSampaiTitikBerikutnya;
    if (sisa != null && sisa.inSeconds > 0) {
      return 'Titik ${titik.label} belum waktunya diukur.';
    }

    if (!await ble.mintaUkur(sesi.id, titik.index)) {
      return 'Jam tidak menerima perintahnya. Pastikan jam menyala dan '
          'terpakai rapat di pergelangan, lalu coba lagi.';
    }
    return null;
  }

  /// Menyiapkan tombol ukur **fisik** jam untuk titik berikutnya yang belum
  /// terisi (`ARM_TITIK`, protokol §5.1 v1.3).
  ///
  /// **Dikirim hanya saat titiknya sudah jatuh tempo.** Rancangan pertama v1.3
  /// menaruh penundaannya di kawat (`detik_tunda`) supaya jam menyalakan
  /// tombolnya sendiri saat jendela terbuka; itu dibuang karena penundaan
  /// tersebut tidak pernah selamat melewati pemutusan daya, dan pemutusan daya
  /// adalah keadaan normal di v1.3. Perintah ini sama-sama butuh koneksi seperti
  /// `UKUR`, jadi tidak ada yang hilang dengan mengirimnya belakangan — dan
  /// batas awal jendela toleransi (docs/jadwal-titik-ukur.md §3) jadi ditegakkan
  /// di sini, sebagai keputusan penjadwalan, bukan sebagai mekanisme di kawat
  /// yang harus tetap benar melintasi mati-hidup.
  ///
  /// Selebihnya ditulis pada **setiap koneksi** selama titiknya jatuh tempo,
  /// seperti `ANCHOR_WAKTU`: murah, idempoten, dan melewatkannya sekali berarti
  /// tombol fisiknya padam justru saat ia paling dibutuhkan.
  Future<void> _armTitikBerikutnya() async {
    final sesi = _sesiAktif;
    final t0 = sesi?.t0;
    if (sesi == null || t0 == null) return;
    if (!sesi.status.sedangAktif || !_statusPerangkat.tersambung) return;

    final titik = titikBerikutnya;
    if (titik == null) {
      _titikDiarm = null;
      return;
    }

    // Pengingat ikut disegarkan di sini, bukan di tempat terpisah: keduanya
    // menjawab pertanyaan yang sama persis — titik mana yang sedang ditunggu
    // dan kapan — dan memisahkannya berarti dua jawaban yang bisa berselisih.
    unawaited(
      pengingat.jadwalkan(
        t0: t0,
        titik: [
          for (final t in sesi.jadwal.titik)
            if (t.berjendela &&
                sesi.sampel.any(
                  (s) =>
                      s.index == t.index && s.status == StatusSampel.menunggu,
                ))
              t,
        ],
        sekarang: jam(),
      ),
    );

    final sisa = sisaSampaiTitikBerikutnya ?? Duration.zero;
    if (sisa.inSeconds > 0) {
      // Belum waktunya. Tombol jam dibiarkan padam — itu yang menahan
      // pengukuran terlalu cepat — dan ARM-nya dijadwalkan untuk saat
      // jendelanya terbuka.
      _jadwalkanArmTitik(sisa);
      return;
    }

    if (_titikDiarm == '${sesi.id}#${titik.index}') return;
    if (await ble.armTitik(sesi.id, titik.index)) {
      _titikDiarm = '${sesi.id}#${titik.index}';
    }
  }

  /// Kunci `sesiId#index` terakhir yang berhasil di-ARM.
  ///
  /// Menahan penulisan berulang untuk titik yang sama, dengan alasan yang sama
  /// seperti [_sesiDiarm]: `ARM_TITIK` mengubah keadaan jam, dan keadaan yang
  /// berubah memicu notifikasi status berikutnya.
  String? _titikDiarm;

  Timer? _timerArm;

  /// Membangunkan [_armTitikBerikutnya] saat jendela titik berikutnya terbuka.
  ///
  /// Diperlukan sejak penundaannya tidak lagi dititipkan ke jam: tanpa timer ini
  /// tidak ada apa pun yang terjadi antara t0 dan titik pertama, jadi tombol
  /// fisik jam tidak akan pernah menyala kecuali kebetulan ada notifikasi status
  /// yang lewat.
  ///
  /// Hanya berumur selama proses aplikasi hidup — dan itu memang cukup, karena
  /// `ARM_TITIK` juga menuntut koneksi BLE yang sama-sama mati bersama proses.
  /// Yang menjaga pengguna saat aplikasi tertutup adalah notifikasi terjadwal
  /// (docs/jadwal-titik-ukur.md §6), bukan timer ini.
  void _jadwalkanArmTitik(Duration sisa) {
    _timerArm?.cancel();
    _timerArm = Timer(sisa, () {
      _timerArm = null;
      unawaited(_armTitikBerikutnya());
    });
  }

  Future<void> _siapkanJam() async {
    final sesi = _sesiAktif;
    if (sesi == null || sesi.t0 != null) return;
    if (!sesi.status.sedangAktif) return;

    // Sudah di-ARM untuk sesi ini pada koneksi ini — jangan kirim lagi.
    //
    // Penjaga kedua, di samping yang ada di pendengar status. Dua-duanya perlu:
    // yang di sana menahan umpan balik status → ARM → status, yang di sini
    // menahan setiap pemanggil lain yang kebetulan memanggil dua kali. Perintah
    // yang dikirim ulang tanpa alasan bukan sekadar boros — ia mengubah keadaan
    // jam, dan keadaan yang berubah memicu notifikasi berikutnya.
    if (_sesiDiarm == sesi.id) return;

    final siap = await ble.siapkanSesi(sesi.id);
    if (siap) _sesiDiarm = sesi.id;
    final status = siap ? StatusSesi.draft : StatusSesi.menungguPerangkat;

    final terkini = _sesiAktif;
    if (terkini == null || terkini.id != sesi.id || terkini.t0 != null) return;
    if (terkini.status == status) return;

    _sesiAktif = terkini.salin(status: status);
    _simpanAktif();
    notifyListeners();
  }

  /// Tombol "Selesai Makan" di jam ditekan — satu-satunya jalan sebuah sesi
  /// mendapatkan t0.
  ///
  /// `pesan.t0` adalah waktu menurut jam tangan dan dipakai apa adanya: kalau
  /// tombolnya ditekan saat HP tidak tersambung, pesannya baru sampai
  /// belakangan, dan menghitung ulang t0 di sini akan menggeser seluruh
  /// jadwal sesi (§8).
  void _terimaT0(({String sesiId, DateTime t0, bool waktuTidakPasti}) pesan) {
    final sesi = _sesiAktif;
    // Tombol untuk sesi yang sudah dibatalkan/diganti tidak menghidupkannya
    // kembali.
    if (sesi == null || sesi.id != pesan.sesiId || sesi.t0 != null) return;

    // Baseline diukur sebelum makan; jaraknya ke t0 baru diketahui sekarang.
    final detikBaseline = sesi.waktuFoto.difference(pesan.t0).inSeconds;
    // Hanya baseline yang bergeser; sisanya apa adanya. Ditulis sebagai
    // pemetaan, bukan empat baris, karena jumlah titik tidak lagi tetap sejak
    // jadwal menjadi data (docs/jadwal-titik-ukur.md §1).
    final sampel = [
      for (final s in sesi.sampel)
        if (s.index == 0) _geser(s, detikBaseline) else s,
    ];

    _sesiAktif = sesi.salin(
      t0: pesan.t0,
      sampel: sampel,
      status: StatusSesi.berjalan,
      waktuTidakPasti: pesan.waktuTidakPasti,
    );
    // Sejak t0 ada, sesi ini punya tenggat: sampel terakhir dijadwalkan dua jam
    // sesudahnya, dan sesudah itu tidak ada lagi yang ditunggu.
    _jadwalkanTenggat();
    // Sejak t0 ada, titik ukur punya waktu — dan tombol fisik jam bisa
    // disiapkan untuk yang pertama.
    unawaited(_armTitikBerikutnya());
    _simpanAktif();
    notifyListeners();
  }

  /// Menekan tombol "Selesai Makan" dari aplikasi.
  ///
  /// Pasangan tombol fisik di jam, bukan penggantinya — keduanya bermuara ke
  /// jalur yang sama persis. Aplikasi **tidak** menetapkan `t0`: ia mengirim
  /// `MULAI_SESI` (protokol §5.1), dan sesi baru benar-benar dimulai saat
  /// `TOMBOL_SELESAI_MAKAN` dari jam sampai ke [_terimaT0]. Itulah sebabnya
  /// metode ini tidak menyentuh `_sesiAktif` sama sekali.
  ///
  /// Perbedaan itu bukan formalitas. `t0` harus berada di garis waktu yang sama
  /// dengan `uptime_s` tiap sampel (§5.3); `t0` versi jam dinding HP tidak bisa
  /// dibandingkan dengan apa pun yang dikirim jam, dan `+1 jam` / `+2 jam` akan
  /// dijadwalkan dari titik yang tidak ada di garis waktu jam.
  ///
  /// Mengembalikan false bila perintahnya tidak jadi dikirim atau ditolak jam.
  /// **Layar tidak berubah pada saat itu juga** meski berhasil — yang ditunggu
  /// adalah balasan jam, dan menampilkan sesi sudah berjalan sebelum jamnya
  /// setuju akan berbohong tepat pada detik yang paling menentukan.
  Future<bool> mulaiSesiDariApp() async {
    final sesi = _sesiAktif;
    if (sesi == null) return false;
    if (sesi.t0 != null) return false; // sudah berjalan
    if (!_statusPerangkat.tersambung) return false;

    // Jam menolak `MULAI_SESI` selama belum di-ARM — aturan yang sama yang
    // menjamin tidak ada sesi tanpa foto makanan (§5.1). Kalau ARM sebelumnya
    // belum sampai (jam baru tersambung), kirim lebih dulu.
    if (_sesiDiarm != sesi.id) await _siapkanJam();

    return ble.mulaiSesi(sesi.id);
  }

  /// `detikRelatifT0` yang benar-benar disimpan untuk sampel yang baru masuk.
  ///
  /// **Ini yang berubah di protokol v1.3 (§5.3), dan perubahannya halus.**
  /// Sampai v1.2 nilai ini selalu dipaksa ke jadwal nominal titiknya: label di
  /// layar menjanjikan "+1 jam", bukan "+1 jam 40 detik", dan penundaan
  /// berskala detik tidak perlu terlihat. Alasan itu **berbalik pada skala
  /// menit** — sejak jam dimatikan di antara titik dan pengukurannya dipicu
  /// manusia yang bisa terlambat, memaksa nilai ke slot yang rapi berhenti
  /// merapikan label dan mulai memalsukan sumbu x. Ambangnya ada di
  /// [TitikJadwal.ambangNormalisasiDetik].
  ///
  /// Dari mana angka mentahnya diambil bergantung pada satu hal:
  ///
  /// - **Sampel yang datang dari buffer jam** membawa waktunya sendiri, yang
  ///   diterjemahkan `BleAsliService` lewat anchor boot-nya (§4.2). Ia diukur
  ///   entah kapan sebelum tiba di sini — memakai jam dinding sekarang akan
  ///   mencatat kapan **ponselnya tersambung**, bukan kapan pengukurannya
  ///   terjadi, dan itu bisa meleset berjam-jam.
  /// - **Sampel yang tiba langsung** diukur pada detik ini, atas perintah
  ///   aplikasi yang memang harus tersambung untuk mengirimkannya. Jam dinding
  ///   ponsel karena itu adalah sumber yang paling tepat yang ada.
  int _detikRelatifT0(SesiMakan sesi, Sampel masuk) {
    final titik = sesi.jadwal.titik.where((t) => t.index == masuk.index);
    final nominal = titik.isEmpty
        ? masuk.detikRelatifT0
        : titik.first.detikNominal;

    final t0 = sesi.t0;
    final terukur = (masuk.dariBuffer || t0 == null)
        ? masuk.detikRelatifT0
        : jam().difference(t0).inSeconds;

    if (titik.isEmpty) return terukur;
    return titik.first.normalkan(terukur) == nominal ? nominal : terukur;
  }

  Sampel _geser(Sampel s, int detikRelatifT0) => Sampel(
    index: s.index,
    detikRelatifT0: detikRelatifT0,
    status: s.status,
    dariBuffer: s.dariBuffer,
    gulaDarah: s.gulaDarah,
    detakJantung: s.detakJantung,
    sistolik: s.sistolik,
    diastolik: s.diastolik,
    spo2: s.spo2,
  );

  /// Sesi dibatalkan user: tidak masuk riwayat dan tidak dihitung di analisis.
  Future<void> batalkan() async {
    final sesi = _sesiAktif;
    if (sesi == null) return;

    await ble.batalkanSesi(sesi.id);
    unawaited(pengingat.batalkanSemua());
    _lupakanKunci(sesi.id);
    _sesiDiarm = null;
    _titikDiarm = null;
    _timerArm?.cancel();
    _timerArm = null;
    _tenggat?.cancel();
    _tenggat = null;
    _sesiAktif = null;
    // Draft-nya sudah tertulis sejak shutter ditekan, jadi membatalkan berarti
    // menghapus — bukan sekadar melupakan. Tanpa ini sesi yang dibatalkan hidup
    // kembali sebagai sesi aktif saat aplikasi dibuka lagi.
    unawaited(_hapus(sesi.id));
    notifyListeners();
  }

  Future<void> _hapus(String sesiId) async {
    try {
      await repo?.hapus(sesiId);
    } catch (e) {
      // Sesi yatim di basis data jauh lebih ringan akibatnya daripada sesi yang
      // gagal disimpan: ia hanya muncul lagi sekali, lalu lewat tenggat.
      debugPrint('Gagal menghapus sesi $sesiId: $e');
    }
  }

  /// Mengakhiri sesi berjalan lebih awal. Sampel yang belum masuk ditandai
  /// terlewat, jadi sesinya `tidakLengkap`, bukan gagal — bedanya dengan
  /// [batalkan] adalah nasib datanya: di sini sampel yang sudah masuk tetap
  /// tersimpan dan tetap dihitung, di sana barisnya dihapus.
  ///
  /// Dua pemanggil, dua maksud. Yang lama: user memotret makanan baru padahal
  /// sesi lama belum kelar (§6). Yang kedua: user menutup sendiri sesi yang
  /// jamnya tidak akan pernah menuntaskan pengukurannya — baterai habis, sensor
  /// gagal, jam tidak kembali tersambung. Tanpa yang kedua, satu-satunya jalan
  /// keluar adalah membatalkan (membuang data yang sudah terkumpul) atau
  /// menunggu [tenggatSampelTerakhir], yang jatuh sampai 2,5 jam setelah t0.
  ///
  /// Memanggil `batalkanSesi()` ke jam, jadi sampel yang masih tertahan di
  /// buffer jam tidak akan masuk lagi ke sesi ini. Karena itu pemanggil dari UI
  /// wajib mengonfirmasinya lebih dulu.
  Future<void> akhiriLebihAwal() async {
    final sesi = _sesiAktif;
    if (sesi == null) return;

    await ble.batalkanSesi(sesi.id);
    _selesaikan(_tandaiSisanyaTerlewat(sesi));
  }

  /// User mengoreksi nama atau porsi hasil deteksi (§4.5).
  ///
  /// Momen paling akurat untuk ini adalah sebelum sesi dimulai — piringnya
  /// masih di depan mata — tetapi koreksi tetap diterima selama sesi masih
  /// aktif, karena angka karbohidrat inilah yang nanti dikorelasikan dengan
  /// respons glukosa.
  void koreksiHasil(List<ItemMakanan> makanan) {
    final sesi = _sesiAktif;
    final hasil = sesi?.hasil;
    if (sesi == null || hasil == null) return;

    _sesiAktif = sesi.salin(hasil: hasil.dikoreksi(makanan));
    _simpanAktif();
    notifyListeners();
  }

  /// Kartu hasil di Beranda sudah dibuka user, jadi boleh hilang (§4.1 C).
  void tandaiHasilDibaca() {
    if (_hasilBelumDibaca == null) return;
    _hasilBelumDibaca = null;
    notifyListeners();
  }

  Future<void> sinkronkan() => ble.sinkronkan();

  // --- Pemasangan jam ----------------------------------------------------
  //
  // Ketiganya cuma meneruskan ke `ble`; perubahan statusnya kembali lewat
  // stream `statusPerangkat` yang sudah didengarkan di konstruktor, jadi tidak
  // ada `notifyListeners()` di sini — dan jam yang baru tersambung otomatis
  // disiapkan ulang oleh listener itu.

  Stream<PerangkatDitemukan> pindaiPerangkat() => ble.pindai();

  /// Tahap penyambungan yang sedang berjalan, diteruskan apa adanya dari jam.
  Stream<TahapSambung> get tahapSambung => ble.tahapSambung;

  Future<HasilSambung> sambungkanPerangkat(String idPerangkat) =>
      ble.sambungkan(idPerangkat);

  Future<bool> lupakanPenyandingan(String idPerangkat) =>
      ble.lupakanPenyandingan(idPerangkat);

  /// Melepas pemasangan jam sepenuhnya.
  ///
  /// Sesi yang sedang berjalan **tidak ikut dibatalkan**: sampel yang sudah
  /// masuk tetap data yang sah, dan sesinya berakhir lewat tenggatnya sendiri
  /// seperti sesi mana pun yang kehilangan jamnya. Yang harus dikatakan UI lebih
  /// dulu adalah bahwa sisa sampelnya tidak akan pernah datang.
  Future<void> lupakanPerangkat() => ble.lupakanPerangkat();

  /// Penjelasan kegagalan sambung yang datang dari jam sendiri, bila ada.
  String? get galatSambungTerakhir => ble.galatTerakhir;

  Future<void> putuskanPerangkat() => ble.putuskan();

  // --- Kalibrasi tekanan darah (§5, §4.7) --------------------------------

  Kalibrasi? _kalibrasiTerakhir;

  /// Kalibrasi terakhir yang berhasil dikirim ke jam; null berarti belum
  /// pernah dikalibrasi dari HP ini. Dimuat dari basis data saat aplikasi start
  /// (Tahap B): jam menyimpan offsetnya di flash dan terus memakainya, jadi
  /// aplikasi yang lupa akan berbohong tentang keadaan jamnya sendiri.
  Kalibrasi? get kalibrasiTerakhir => _kalibrasiTerakhir;

  /// Kalibrasi terakhir sudah lewat masa berlakunya (`Kalibrasi.masaBerlaku`).
  ///
  /// Jam **tetap** memakai offset lamanya — ia tidak tahu apa-apa soal tanggal
  /// (protokol §4: tidak ada RTC di sana), jadi kedaluwarsa adalah penilaian
  /// aplikasi, bukan perubahan perilaku alat. Karena itu yang benar adalah
  /// mengatakannya, bukan diam: angkanya masih keluar, hanya tidak lagi bisa
  /// dipertanggungjawabkan.
  bool get kalibrasiKedaluwarsa =>
      _kalibrasiTerakhir?.kedaluwarsaPada(jam()) ?? false;

  /// Sisa hari masa berlaku kalibrasi, null bila belum pernah dikalibrasi.
  int? get sisaHariKalibrasi => _kalibrasiTerakhir?.sisaHariPada(jam());

  /// Meminta jam mengukur bersamaan dengan tensimeter.
  Future<Sampel> ukurUntukKalibrasi() => ble.ukurSekarang();

  // --- Pindai kesehatan atas permintaan ----------------------------------

  HasilPindai? _pindaiTerakhir;

  /// Hasil pindai kesehatan terakhir di sesi aplikasi ini, atau null bila belum
  /// pernah memindai sejak aplikasi dibuka.
  ///
  /// **Sengaja hanya di memori.** Riwayat aplikasi ini berisi sesi makan
  /// (docs/rancangan-ui-sesi-makan.md), dan satu pembacaan lepas tanpa makanan,
  /// tanpa `t0`, dan tanpa tiga titik pembanding bukan sesi — menyimpannya ke
  /// tabel yang sama akan mencemari setiap hitungan di `AnalisisSesi`. Yang
  /// dibelinya di sini cuma satu hal, dan memang cuma itu yang dibutuhkan:
  /// pengguna yang menutup halaman lalu membukanya lagi tidak kehilangan angka
  /// yang baru saja dilihatnya. Halaman pindai mengatakan apa adanya bahwa
  /// hasilnya tidak masuk riwayat.
  HasilPindai? get pindaiTerakhir => _pindaiTerakhir;

  /// Sedang menunggu jawaban jam atas sebuah pindai.
  ///
  /// Di controller, bukan di halaman, karena satu perintah `UKUR_SEKARANG` boleh
  /// jalan pada satu waktu: jam menjawab NAK `sedangMengukur` untuk yang kedua,
  /// dan dua halaman yang saling menunggu jawaban yang sama akan saling
  /// mencuri sampelnya.
  bool get sedangMemindai => _sedangMemindai;
  bool _sedangMemindai = false;

  /// Pindai kesehatan sekali jalan, di luar sesi makan mana pun.
  ///
  /// Perintahnya sama dengan yang dipakai kalibrasi (`UKUR_SEKARANG`, §5.1);
  /// yang berbeda hanya nasib hasilnya. Melempar [GalatJam] dengan kalimat siap
  /// tampil bila jam tidak tersambung, menolak, atau tidak menjawab.
  Future<HasilPindai> pindaiKesehatan() async {
    // Diperiksa di sini, bukan hanya di layer BLE, supaya jawabannya sama
    // apakah jamnya palsu atau sungguhan — dan supaya kalimatnya menyebut
    // keadaan yang **berbeda**: jam yang belum pernah dipasangkan menuntut
    // pemindaian perangkat, bukan mendekatkan jam.
    final p = statusPerangkat;
    if (p.belumDipasangkan) {
      throw const GalatJam(
        'Belum ada jam yang dipasangkan. Pasangkan jam AsaWatch lebih dulu.',
      );
    }
    if (!p.tersambung) {
      throw const GalatJam(
        'Jam belum tersambung. Dekatkan jam ke ponsel, lalu coba lagi.',
      );
    }
    if (_sedangMemindai) {
      throw const GalatJam('Pengukuran sebelumnya masih berjalan.');
    }

    _sedangMemindai = true;
    notifyListeners();
    try {
      final sampel = await ble.ukurSekarang();
      final hasil = HasilPindai(waktu: jam(), sampel: sampel);
      _pindaiTerakhir = hasil;
      return hasil;
    } finally {
      _sedangMemindai = false;
      notifyListeners();
    }
  }

  /// Membuang hasil pindai terakhir dari layar.
  void buangPindaiTerakhir() {
    if (_pindaiTerakhir == null) return;
    _pindaiTerakhir = null;
    notifyListeners();
  }

  /// Menghitung koefisien dari selisih tensimeter vs jam, lalu mengirimkannya.
  ///
  /// Ditulis ke basis data **setelah** jam menerimanya, bukan sebelum: kalibrasi
  /// yang tercatat di HP tetapi tidak pernah sampai ke jam adalah angka yang
  /// menjanjikan koreksi yang tidak terjadi.
  Future<void> simpanKalibrasi(Kalibrasi kalibrasi) async {
    await ble.kirimKalibrasi(kalibrasi);
    _kalibrasiTerakhir = kalibrasi;
    try {
      await repoKalibrasi?.simpan(kalibrasi);
    } catch (e) {
      debugPrint('Gagal menyimpan kalibrasi: $e');
    }
    notifyListeners();
  }

  // --- Sampel masuk -----------------------------------------------------

  void _terimaSampel(({String sesiId, Sampel sampel}) pesan) {
    final sesi = _sesiAktif;
    if (sesi == null || sesi.id != pesan.sesiId) {
      // Dicatat, bukan dibuang diam-diam. Sampel yang tidak cocok memang tidak
      // ada tempatnya di sini — ia bisa milik sesi yang sudah ditutup, atau
      // jawaban `UKUR_SEKARANG` yang ber-`sesiId` nol — tetapi kalau titik ukur
      // yang benar-benar ditunggu ternyata jatuh ke sini, satu-satunya gejalanya
      // adalah titik yang tetap kosong. Itu terlalu mahal untuk didiamkan.
      debugPrint(
        'Sampel index ${pesan.sampel.index} untuk sesi ${pesan.sesiId} '
        'diabaikan: sesi aktif ${sesi?.id ?? "tidak ada"}.',
      );
      return;
    }

    // Pengiriman jam at-least-once: sampel yang sama bisa datang dua kali.
    final kunci = '${pesan.sesiId}#${pesan.sampel.index}';
    if (!_sampelDiterima.add(kunci)) return;

    final sampel = [...sesi.sampel];
    final masuk = pesan.sampel;
    sampel[masuk.index] = masuk.index == 0 && sesi.t0 == null
        ? masuk // jarak baseline ke t0 dihitung nanti di _terimaT0
        : _geser(masuk, _detikRelatifT0(sesi, masuk));

    final diperbarui = sesi.salin(sampel: sampel);
    final tuntas = sampel.every((s) => s.status != StatusSampel.menunggu);

    if (tuntas && diperbarui.t0 != null) {
      _selesaikan(
        diperbarui.salin(
          status: diperbarui.adaSampelTerlewat
              ? StatusSesi.tidakLengkap
              : StatusSesi.selesai,
        ),
      );
      return;
    }

    // Sampel yang masuk setelah t0 juga menandakan jam sudah nyambung. Selama
    // t0 belum ada, status `menungguPerangkat` justru harus bertahan: yang
    // ditunggu adalah tombol di jam, bukan sampel.
    _sesiAktif =
        diperbarui.status == StatusSesi.menungguPerangkat &&
            diperbarui.t0 != null
        ? diperbarui.salin(status: StatusSesi.berjalan)
        : diperbarui;
    _simpanAktif();
    // Titik ini sudah terisi; yang berikutnya perlu tombolnya sendiri.
    unawaited(_armTitikBerikutnya());
    notifyListeners();
  }

  void _selesaikan(SesiMakan sesi) {
    _tenggat?.cancel();
    _tenggat = null;
    _sesiDiarm = null;
    _titikDiarm = null;
    _timerArm?.cancel();
    _timerArm = null;
    _riwayat.insert(0, sesi);
    _sesiAktif = null;
    _hasilBelumDibaca = sesi;
    _lupakanKunci(sesi.id);

    // Sesi yang berakhir harus **melepas ARM tombol ukur di jam**, bukan
    // meninggalkannya menyala.
    //
    // Sejak `ARM_TITIK` ada (protokol §5.1 v1.3), tombol fisik jam bisa
    // tertinggal ter-ARM untuk titik yang sudah tidak akan pernah diminta lagi.
    // Ditekan sesudah itu, jam akan mengirim sampel untuk sesi yang sudah
    // ditutup — yang di aplikasi tidak jatuh ke mana-mana, tetapi di jam
    // menyalakan sensor tanpa ada yang memintanya, pada perangkat yang tidak
    // bertahan lima puluh menit.
    unawaited(ble.batalkanSesi(sesi.id));
    unawaited(pengingat.batalkanSemua());
    // **Simpan dulu, baru kirim, dan berurutan.** Dua `unawaited` yang berlomba
    // adalah bagaimana sesi ini dulu naik ke server dengan `diperbarui_pada`
    // bawaan `waktuFoto`: unggahannya berangkat sebelum penulisan lokal sempat
    // menstempelnya, dan server menolaknya 409 karena stempel itu lebih tua
    // daripada `updated_at` yang ia tulis sendiri saat draft-nya diunggah.
    unawaited(_simpanLaluKirim(sesi));
    notifyListeners();
  }

  /// Menulis sesi yang berakhir, lalu mengunggah **hasil tulisannya** — bukan
  /// salinan yang dipegang pemanggil, yang stempelnya masih dari sebelum
  /// penulisan ini.
  Future<void> _simpanLaluKirim(SesiMakan sesi) async {
    final tersimpan = await _simpan(sesi);
    await _kirimKeServer(tersimpan ?? sesi);
  }

  /// Menulis sesi yang sudah berakhir ke penyimpanan.
  ///
  /// Sengaja tidak ditunggu: sesi sudah masuk `_riwayat` di memori, dan menahan
  /// `notifyListeners()` demi I/O akan menunda tampilnya kartu hasil di Beranda.
  /// Kegagalan menulis tidak menjatuhkan sesi yang datanya sudah benar, tetapi
  /// **harus terlihat**: sesi itu ada di layar sekarang dan akan hilang setelah
  /// aplikasi ditutup, dan hanya pengguna yang bisa memutuskan apa artinya.
  /// Menulis sesi yang **masih berjalan**.
  ///
  /// Ini yang membuat aplikasi boleh mati di tengah sesi: konstruktor
  /// memulihkan sesi aktif dari basis data, dan jadwalnya dihitung ulang dari
  /// `t0` absolut. Ia juga yang menutup lingkaran ack protokol §6 — entri mentah
  /// yang sudah di-ack ke jam ditandai "diproses" tepat saat sesinya durabel
  /// (lihat `SesiRepositoryDrift.simpan`).
  void _simpanAktif() {
    final sesi = _sesiAktif;
    if (sesi != null) unawaited(_simpan(sesi));
  }

  /// Menulis satu sesi, lalu **menempelkan stempel hasil tulisan itu** ke
  /// salinan yang hidup di memori. Mengembalikan sesi yang sudah berstempel,
  /// atau null bila penulisannya gagal.
  ///
  /// Bagian kedua itu yang dulu tidak ada, dan akibatnya hanya terlihat di
  /// server: repository menstempel barisnya, objek di memori tidak pernah
  /// menerima stempelnya, dan `badanSesi` jatuh ke `waktuFoto` seumur hidup
  /// sesi itu — lebih tua daripada `updated_at` yang server tulis saat draft
  /// diunggah, jadi setiap kiriman berikutnya ditolak `409 konflik_versi`.
  Future<SesiMakan?> _simpan(SesiMakan sesi) async {
    final tujuan = repo;
    if (tujuan == null) return sesi;
    try {
      return _terapkanStempel(sesi, await tujuan.simpan(sesi));
    } catch (e) {
      debugPrint('Gagal menyimpan sesi ${sesi.id}: $e');
      _galatPenyimpanan =
          'Sesi terakhir gagal disimpan dan akan hilang saat aplikasi ditutup.';
      notifyListeners();
      return null;
    }
  }

  /// Menempelkan [stempel] ke salinan sesi di memori, **di mana pun ia berada**
  /// — alasannya sama dengan [_terapkanHasil]: penulisan berjalan asinkron dan
  /// sesinya bisa sudah pindah dari `_sesiAktif` ke `_riwayat` sebelum
  /// penulisan itu selesai.
  ///
  /// Yang ditempel hanya stempelnya, bukan seluruh objek [sesi] — objek itu
  /// adalah keadaan pada saat penulisan dimulai, dan sampel yang masuk selagi
  /// tulisan berjalan tidak boleh ikut terhapus. Tidak ada `notifyListeners()`:
  /// stempel tidak tampil di layar mana pun.
  SesiMakan _terapkanStempel(SesiMakan sesi, DateTime stempel) {
    final aktif = _sesiAktif;
    if (aktif != null && aktif.id == sesi.id) {
      return _sesiAktif = aktif.salin(diperbaruiPada: stempel);
    }

    final i = _riwayat.indexWhere((s) => s.id == sesi.id);
    if (i < 0) return sesi.salin(diperbaruiPada: stempel);

    final diperbarui = _riwayat[i].salin(diperbaruiPada: stempel);
    _riwayat[i] = diperbarui;
    if (_hasilBelumDibaca?.id == sesi.id) _hasilBelumDibaca = diperbarui;
    return diperbarui;
  }

  SesiMakan? _cariSesi(String sesiId) {
    final aktif = _sesiAktif;
    if (aktif != null && aktif.id == sesiId) return aktif;
    return _riwayat.where((s) => s.id == sesiId).firstOrNull;
  }

  /// Mengunggah satu sesi yang sudah berakhir.
  ///
  /// Diam-diam, dan kegagalannya tidak diperlihatkan: berbeda dengan
  /// [galatPenyimpanan], gagal mengunggah **tidak menghilangkan apa pun** —
  /// datanya tetap di ponsel dan akan dikirim lagi pada pembukaan aplikasi
  /// berikutnya. Memunculkan peringatan untuk sesuatu yang memperbaiki dirinya
  /// sendiri hanya mengajari pengguna mengabaikan peringatan.
  Future<void> _kirimKeServer(SesiMakan sesi) async {
    final server = serverSesi;
    if (server == null) return;
    final token = (await sesiLogin?.muat())?.token;
    if (token == null) return;

    final berhasil = await server.kirim(token, sesi);
    if (!berhasil) debugPrint('Sesi ${sesi.id} belum sampai ke server.');
  }

  /// Membuang seluruh data lokal yang melekat pada satu orang.
  ///
  /// Dipanggil dari alur masuk, dan **hanya** ketika akunnya berbeda dari
  /// pemilik data yang tercatat di ponsel ini — pasangan
  /// `ProfilRepository.sinkronSetelahMasuk`, yang melakukan hal yang sama untuk
  /// profil. Satu ponsel dipakai dua orang bukan keadaan aneh: satu keluarga,
  /// satu perangkat pinjaman, satu ponsel demo.
  ///
  /// Yang dibuang: riwayat sesi (beserta sampel, hasil gizi, dan itemnya),
  /// kalibrasi tekanan darah, kotak masuk mentah jam, dan seluruh salinan yang
  /// masih dipegang di memori. Yang **tidak**: penyandingan jam dan anchor
  /// waktunya — itu milik perangkat kerasnya, bukan orangnya, dan menyuruh
  /// pengguna lansia menyandingkan ulang setiap berganti akun adalah biaya yang
  /// tidak dibayar oleh apa pun.
  ///
  /// **Harus selesai sebelum [kirimRiwayatKeServer]**, dan urutan itulah
  /// alasannya ada: unggahan yang berangkat lebih dulu akan menaruh sesi milik
  /// orang sebelumnya ke akun yang baru masuk, di mana ia tampak sah dan tidak
  /// bisa dibedakan lagi dari sesi pemiliknya.
  Future<void> hapusDataLokal() async {
    // Sesi yang sedang berjalan ikut hilang, dan jam harus tahu — kalau tidak,
    // tombol ukurnya tetap menyala untuk sesi yang sudah tidak ada dan
    // sampelnya akan tiba tanpa induk.
    final aktif = _sesiAktif;
    if (aktif != null) unawaited(ble.batalkanSesi(aktif.id));
    unawaited(pengingat.batalkanSemua());

    // Berkas fotonya ikut, dan ini bukan kerapian melainkan bagian dari
    // maksudnya. Menghapus barisnya saja meninggalkan foto makanan pemilik
    // sebelumnya utuh di `<documents>/foto_makanan/` — tidak lagi terhubung ke
    // sesi mana pun, tetapi tetap ada di penyimpanan ponsel yang sekarang
    // dipakai orang lain. Dikumpulkan **sebelum** daftarnya dikosongkan, karena
    // sesudah itu tidak ada lagi yang tahu jalur mana yang milik siapa.
    await _hapusBerkasFoto([
      for (final s in [..._riwayat, ?aktif]) s.fotoPath,
    ]);

    _tenggat?.cancel();
    _tenggat = null;
    _timerArm?.cancel();
    _timerArm = null;
    _sesiDiarm = null;
    _titikDiarm = null;
    _sesiAktif = null;
    _riwayat.clear();
    _hasilBelumDibaca = null;
    _sampelDiterima.clear();
    _sedangAnalisis.clear();
    _pindaiTerakhir = null;
    _kalibrasiTerakhir = null;
    _galatPenyimpanan = null;

    await repo?.hapusSemua();
    await repoKalibrasi?.hapusSemua();
    await repoEntri?.hapusSemua();

    notifyListeners();
  }

  /// Membuang berkas foto milik sesi yang sedang dihapus.
  ///
  /// Kegagalan tiap berkas ditelan sendiri-sendiri: satu berkas yang tidak bisa
  /// dihapus tidak boleh menghentikan pembersihan berkas berikutnya, dan tidak
  /// boleh menggagalkan penghapusan basis datanya — data yang tertinggal di
  /// SQLite jauh lebih terlihat daripada satu berkas yatim.
  Future<void> _hapusBerkasFoto(List<String> jalur) async {
    for (final j in jalur) {
      if (j.isEmpty) continue;
      try {
        final berkas = File(j);
        if (berkas.existsSync()) await berkas.delete();
      } catch (e) {
        debugPrint('Gagal menghapus foto $j: $e');
      }
    }
  }

  /// Mengunggah **seluruh** riwayat yang sudah berakhir.
  ///
  /// Dipanggil saat aplikasi dibuka dan sesudah masuk. Tidak ada daftar
  /// "belum terkirim" yang disimpan, dan itu disengaja: `PUT /sesi/{id}`
  /// idempoten terhadap UUID buatan aplikasi (§2 aturan 2), jadi mengirim ulang
  /// yang sudah ada di server tidak menghasilkan apa-apa selain satu permintaan
  /// yang terbuang. Keadaan yang tidak perlu disimpan adalah keadaan yang tidak
  /// bisa salah — dan sebuah tanda "sudah terkirim" yang meleset justru akan
  /// menyembunyikan sesi selamanya.
  ///
  /// Berurutan, bukan serentak: sepuluh sesi yang dikirim bersamaan di jaringan
  /// seluler saling memperlambat, dan tidak ada yang menunggu hasilnya.
  Future<void> kirimRiwayatKeServer() async {
    final server = serverSesi;
    if (server == null) return;
    final token = (await sesiLogin?.muat())?.token;
    if (token == null) return;

    // **Siapa yang fotonya belum sampai ditanyakan ke server, bukan ditebak.**
    //
    // Sebelum ini penandanya adalah "sesi ini sudah punya angka gizi", dengan
    // alasan bahwa `_mintaHasil` mengirim foto lebih dulu baru meminta analisis.
    // Itu benar hanya bila ada token saat rana ditekan. Tanpa token angka
    // gizinya datang dari [nutrisi] lokal, `hasil` terisi, fotonya tidak pernah
    // diunggah — dan percobaan ulang melewatinya selamanya. Setiap sesi yang
    // difoto sebelum pengguna masuk kehilangan piringnya secara permanen.
    //
    // Jawabannya tidak disimpan sebagai kolom "sudah terkirim", dengan alasan
    // yang sama seperti sesinya sendiri (§2 aturan 2): keadaan yang tidak
    // disimpan tidak bisa salah, sedangkan tanda yang meleset sekali akan
    // menyembunyikan foto itu selamanya. Harganya satu permintaan JSON per
    // pembukaan aplikasi.
    //
    // Gagal bertanya jatuh ke perilaku lama, bukan ke salah satu ujung: mengirim
    // ulang **semua** foto berarti puluhan megabyte di jaringan seluler, dan
    // tidak mengirim satu pun berarti sesi yang memang tertinggal tidak pernah
    // dicoba lagi.
    final diServer = await server.ambilSemua(token);
    final tanpaFotoDiServer = diServer == null
        ? null
        : {
            for (final u in diServer)
              if (u.urlFoto == null) u.sesi.id,
          };
    final urlFotoDiServer = {
      for (final u in diServer ?? const <SesiUnduhan>[])
        if (u.urlFoto != null) u.sesi.id: u.urlFoto!,
    };

    for (final sesi in List<SesiMakan>.from(_riwayat)) {
      await server.kirim(token, sesi);

      // Berkasnya harus masih ada di ponsel ini — sesi hasil unduhan yang
      // gagal mengambil fotonya tidak punya apa pun untuk dikirim balik.
      //
      // Arah sebaliknya justru harus dicoba lagi di sini: sesi yang server
      // punya fotonya tetapi ponsel ini tidak. [unduhRiwayatDariServer] hanya
      // mengunduh foto sesi yang **baru**, dan aturan "sesi yang sudah ada
      // tidak pernah ditimpa" berarti satu unduhan yang gagal — jaringan putus,
      // atau 401 karena token belum ikut dikirim — membuat piring itu hilang
      // selamanya, sampai pasang ulang berikutnya.
      if (sesi.fotoPath.isEmpty) {
        final url = urlFotoDiServer[sesi.id];
        if (url != null) await _unduhFotoKeSesi(server, token, sesi, url);
        continue;
      }
      final perlu = tanpaFotoDiServer?.contains(sesi.id) ?? sesi.hasil == null;
      if (!perlu) continue;

      if (!await server.kirimFoto(token, sesi.id, sesi.fotoPath)) continue;
      // Angka gizinya hanya diminta bila memang belum ada: foto yang menyusul
      // untuk sesi yang sudah punya hasil tidak perlu dianalisis ulang.
      if (sesi.hasil != null) continue;
      final hasil = await server.mintaAnalisis(token, sesi.id);
      if (hasil != null) {
        _terapkanHasil(sesi.id, hasil);
        if (!_dibuang) notifyListeners();
      }
    }
  }

  /// Menarik riwayat dari server dan menambahkan yang belum ada di sini.
  ///
  /// Inilah yang membuat pemasangan ulang, penggantian ponsel, dan ponsel kedua
  /// tidak lagi berarti riwayat yang hilang — sampai sebelum ini sinkronisasinya
  /// satu arah: aplikasi mengunggah, tidak pernah mengunduh.
  ///
  /// Tiga aturan, dan ketiganya menjaga hal yang sama — data di ponsel ini tidak
  /// boleh rusak karena sesuatu yang datang dari jaringan:
  ///
  /// 1. **Sesi yang sudah ada di sini tidak pernah ditimpa.** Ponsel yang
  ///    merekamnya tahu lebih banyak daripada server (fotonya saja hanya ada di
  ///    sini), dan menimpanya berarti menukar yang lengkap dengan yang ringkas.
  /// 2. **Sesi yang masih berjalan di server dilewati.** Satu sesi aktif pada
  ///    satu waktu (§6) adalah aturan seluruh aplikasi; menarik sesi berjalan
  ///    milik perangkat lain akan membuat dua-duanya aktif.
  /// 3. **Gagal menarik bukan berarti kosong.** [SesiServerService.ambilSemua]
  ///    mengembalikan null saat tidak tahu, dan null tidak pernah menghapus apa
  ///    pun. Daftar kosong yang sungguhan pun hanya berarti "tidak ada yang
  ///    ditambahkan".
  Future<void> unduhRiwayatDariServer() async {
    final server = serverSesi;
    if (server == null) return;
    final token = (await sesiLogin?.muat())?.token;
    if (token == null) return;

    final dariServer = await server.ambilSemua(token);
    if (dariServer == null) return;

    final idLokal = {
      ..._riwayat.map((s) => s.id),
      if (_sesiAktif != null) _sesiAktif!.id,
    };
    final baru = [
      for (final unduhan in dariServer)
        if (!idLokal.contains(unduhan.sesi.id) &&
            !unduhan.sesi.status.sedangAktif)
          unduhan,
    ];
    if (baru.isEmpty) return;

    // Yang masuk riwayat adalah hasil tulisannya, bukan objek yang baru diunduh:
    // menulisnya ke sini **adalah** perubahan lokal, dan tanpa stempelnya sesi
    // hasil unduhan akan mengirim ulang dirinya dengan stempel bawaan
    // `waktuFoto` selamanya — 409 di setiap pembukaan aplikasi.
    for (final unduhan in baru) {
      final sesi = await _denganFotoUnduhan(server, token, unduhan);
      _riwayat.add(await _simpan(sesi) ?? sesi);
    }
    // Riwayat dipakai apa adanya oleh layar: yang terbaru di atas.
    _riwayat.sort(
      (a, b) => (b.t0 ?? b.waktuFoto).compareTo(a.t0 ?? a.waktuFoto),
    );
    notifyListeners();
  }

  /// Mengunduh foto sesi hasil unduhan ke penyimpanan tetap, lalu mengembalikan
  /// sesi dengan `fotoPath` yang menunjuk ke sana.
  ///
  /// Sampai sekarang sesi hasil unduhan selalu punya `fotoPath` kosong, jadi
  /// piringnya hilang di perangkat kedua, sesudah pasang ulang, dan sesudah
  /// ganti akun — padahal server menyimpannya dan web menampilkannya. Yang
  /// diunduh adalah **berkasnya**, bukan alamatnya: URL §5.2 bertanda tangan dan
  /// kedaluwarsa satu jam, jadi menyimpan URL itu berarti jalur mati esok pagi.
  ///
  /// Gagal mengunduh tidak menjatuhkan sesinya: `fotoPath` tetap kosong dan
  /// `FotoMakanan` menjatuhkannya ke penampung cadangan, persis seperti
  /// sebelumnya. Sesi dengan angka dan kurva yang utuh jauh lebih berharga
  /// daripada tidak ada sesi sama sekali.
  Future<SesiMakan> _denganFotoUnduhan(
    SesiServerService server,
    String token,
    SesiUnduhan unduhan,
  ) async {
    final url = unduhan.urlFoto;
    if (url == null) return unduhan.sesi;

    final tujuan = await _unduhFoto(server, token, unduhan.sesi.id, url);
    return tujuan == null ? unduhan.sesi : unduhan.sesi.salin(fotoPath: tujuan);
  }

  /// Mengunduh foto satu sesi yang **sudah ada** di riwayat, lalu menyimpan
  /// jalurnya. Diam saja bila gagal: sesi tanpa piring tetap sesi yang utuh.
  Future<void> _unduhFotoKeSesi(
    SesiServerService server,
    String token,
    SesiMakan sesi,
    String url,
  ) async {
    final tujuan = await _unduhFoto(server, token, sesi.id, url);
    if (tujuan == null) return;

    final i = _riwayat.indexWhere((s) => s.id == sesi.id);
    if (i < 0) return;
    final diperbarui = _riwayat[i].salin(fotoPath: tujuan);
    _riwayat[i] = diperbarui;
    await _simpan(diperbarui);
    if (!_dibuang) notifyListeners();
  }

  /// Jalur berkas hasil unduhan, atau null bila tidak sampai.
  Future<String?> _unduhFoto(
    SesiServerService server,
    String token,
    String sesiId,
    String url,
  ) async {
    try {
      final tujuan = await jalurFoto('unduh_$sesiId.jpg');
      if (await server.unduhFoto(token, url, tujuan)) return tujuan;
    } catch (e) {
      debugPrint('Gagal mengunduh foto sesi $sesiId: $e');
    }
    return null;
  }

  void _lupakanKunci(String sesiId) {
    _sampelDiterima.removeWhere((k) => k.startsWith('$sesiId#'));
  }

  /// Controller memiliki servicenya: sekali dibuang, jam palsu ikut berhenti
  /// dan tidak menyisakan timer yang masih menunggu.
  @override
  void dispose() {
    _dibuang = true;
    _tenggat?.cancel();
    _timerArm?.cancel();
    _langgananSampel?.cancel();
    _langgananT0?.cancel();
    _langgananStatus?.cancel();
    ble.dispose();
    super.dispose();
  }
}
