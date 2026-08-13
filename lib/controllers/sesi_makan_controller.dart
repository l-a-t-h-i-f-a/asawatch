import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/sesi_makan.dart';
import '../repositories/kalibrasi_repository.dart';
import '../repositories/sesi_repository.dart';
import '../services/ble_service.dart';
import '../services/nutrisi_service.dart';
import '../services/protokol_jam.dart' show buatIdSesi;

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
    Kalibrasi? kalibrasiAwal,
  }) : _riwayat = [
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
      if (!status.tersambung) _sesiDiarm = null;

      unawaited(_siapkanJam());
      notifyListeners();
    });

    if (_sesiAktif != null) {
      unawaited(_siapkanJam()); // sesi draft yang dipulihkan perlu di-ARM lagi
      _jadwalkanTenggat();
    }
  }

  final BleService ble;
  final NutrisiService nutrisi;
  final SesiRepository? repo;
  final KalibrasiRepository? repoKalibrasi;

  /// Berapa lama setelah titik terakhir (`t0 + 2 jam`) sebuah sesi berhenti
  /// ditunggu dan ditutup sebagai `tidakLengkap`.
  ///
  /// Bukan nol: sampel yang datang terlambat lewat buffer jam adalah perilaku
  /// normal (§6), dan sesi yang gugur satu detik setelah tenggat akan menolak
  /// data yang sebenarnya sudah terkumpul dengan benar di pergelangan tangan.
  static const Duration tenggatSampelTerakhir = Duration(minutes: 30);

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

  SesiMakan? get sesiTerakhir => _riwayat.isEmpty ? null : _riwayat.first;

  /// Sesi hari ini, dipakai ringkasan nutrisi harian di Beranda.
  ///
  /// Sesi berwaktu tidak pasti tidak pernah ikut: "hari ini" adalah pertanyaan
  /// tentang jam dinding, dan sesi itu justru yang jam dindingnya tidak diketahui
  /// (docs/protokol-jam.md §4.3). Memasukkannya berarti total nutrisi harian yang
  /// mungkin milik hari lain.
  List<SesiMakan> sesiHariIni({DateTime? sekarang}) {
    final now = sekarang ?? DateTime.now();
    final hariIni = DateTime(now.year, now.month, now.day);
    bool samaHari(SesiMakan s) {
      if (s.waktuTidakPasti) return false;
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
    var total = Nutrisi.kosong;
    for (final s in sesiHariIni(sekarang: sekarang)) {
      final hasil = s.hasil;
      if (hasil != null) total = total + hasil.total;
    }
    return total;
  }

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
    return t0
        .add(Duration(seconds: titikTerakhir))
        .add(tenggatSampelTerakhir);
  }

  void _jadwalkanTenggat() {
    _tenggat?.cancel();
    _tenggat = null;

    final sesi = _sesiAktif;
    if (sesi == null) return;
    final batas = _batasTunggu(sesi);
    if (batas == null) return;

    final sisa = batas.difference(DateTime.now());
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

    final sekarang = DateTime.now();
    // UUID, bukan stempel waktu: protokol membawa `sesiId` sebagai 16 byte biner
    // (§5.1), jadi id harus bisa bolak-balik utuh ke sana.
    final id = buatIdSesi();
    _sesiAktif = SesiMakan(
      id: id,
      fotoPath: fotoPath,
      waktuFoto: sekarang,
      status: StatusSesi.draft,
      sampel: const [
        Sampel.menunggu(index: 0, detikRelatifT0: 0),
        Sampel.menunggu(index: 1, detikRelatifT0: 0),
        Sampel.menunggu(index: 2, detikRelatifT0: 3600),
        Sampel.menunggu(index: 3, detikRelatifT0: 7200),
      ],
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

  Future<void> _analisisNutrisi(String sesiId, String fotoPath) async {
    try {
      final hasil = await nutrisi.analisis(fotoPath);
      final sesi = _sesiAktif;
      if (sesi == null || sesi.id != sesiId) return; // sesi sudah berganti
      _sesiAktif = sesi.salin(hasil: hasil);
      _simpanAktif();
      notifyListeners();
    } catch (_) {
      // Analisis gagal bukan alasan sesi gagal: t0 tetap akurat dan UI tetap
      // menampilkan slot nutrisi kosong.
    }
  }

  /// Menyalakan tombol "Selesai Makan" di jam untuk sesi draft yang sedang
  /// ditunggu, lalu menyesuaikan statusnya.
  ///
  /// Dipanggil saat draft dibuat dan setiap kali jam tersambung kembali:
  /// selama jam belum tersambung, penyiapannya tidak pernah sampai dan sesi
  /// berdiri di `menungguPerangkat`.
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
    final sampel = [
      _geser(sesi.sampel[0], detikBaseline),
      sesi.sampel[1],
      sesi.sampel[2],
      sesi.sampel[3],
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
    _simpanAktif();
    notifyListeners();
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
    _lupakanKunci(sesi.id);
    _sesiDiarm = null;
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

  /// Mengakhiri sesi berjalan lebih awal — dipakai saat user mau memotret
  /// makanan baru padahal sesi lama belum kelar (§6). Sampel yang belum masuk
  /// ditandai terlewat, jadi sesinya `tidakLengkap`, bukan gagal.
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

  Future<bool> sambungkanPerangkat(String idPerangkat) =>
      ble.sambungkan(idPerangkat);

  Future<void> putuskanPerangkat() => ble.putuskan();

  // --- Kalibrasi tekanan darah (§5, §4.7) --------------------------------

  Kalibrasi? _kalibrasiTerakhir;

  /// Kalibrasi terakhir yang berhasil dikirim ke jam; null berarti belum
  /// pernah dikalibrasi dari HP ini. Dimuat dari basis data saat aplikasi start
  /// (Tahap B): jam menyimpan offsetnya di flash dan terus memakainya, jadi
  /// aplikasi yang lupa akan berbohong tentang keadaan jamnya sendiri.
  Kalibrasi? get kalibrasiTerakhir => _kalibrasiTerakhir;

  /// Meminta jam mengukur bersamaan dengan tensimeter.
  Future<Sampel> ukurUntukKalibrasi() => ble.ukurSekarang();

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
    if (sesi == null || sesi.id != pesan.sesiId) return;

    // Pengiriman jam at-least-once: sampel yang sama bisa datang dua kali.
    final kunci = '${pesan.sesiId}#${pesan.sampel.index}';
    if (!_sampelDiterima.add(kunci)) return;

    final sampel = [...sesi.sampel];
    final masuk = pesan.sampel;
    sampel[masuk.index] = masuk.index == 0 && sesi.t0 == null
        ? masuk // jarak baseline ke t0 dihitung nanti di _terimaT0
        : _geser(masuk, sampel[masuk.index].detikRelatifT0);

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
    notifyListeners();
  }

  void _selesaikan(SesiMakan sesi) {
    _tenggat?.cancel();
    _tenggat = null;
    _sesiDiarm = null;
    _riwayat.insert(0, sesi);
    _sesiAktif = null;
    _hasilBelumDibaca = sesi;
    _lupakanKunci(sesi.id);
    unawaited(_simpan(sesi));
    notifyListeners();
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

  Future<void> _simpan(SesiMakan sesi) async {
    final tujuan = repo;
    if (tujuan == null) return;
    try {
      await tujuan.simpan(sesi);
    } catch (e) {
      debugPrint('Gagal menyimpan sesi ${sesi.id}: $e');
      _galatPenyimpanan =
          'Sesi terakhir gagal disimpan dan akan hilang saat aplikasi ditutup.';
      notifyListeners();
    }
  }

  void _lupakanKunci(String sesiId) {
    _sampelDiterima.removeWhere((k) => k.startsWith('$sesiId#'));
  }

  /// Controller memiliki servicenya: sekali dibuang, jam palsu ikut berhenti
  /// dan tidak menyisakan timer yang masih menunggu.
  @override
  void dispose() {
    _tenggat?.cancel();
    _langgananSampel?.cancel();
    _langgananT0?.cancel();
    _langgananStatus?.cancel();
    ble.dispose();
    super.dispose();
  }
}
