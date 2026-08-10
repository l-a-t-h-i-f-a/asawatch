import 'dart:async';
import 'dart:math';

import '../models/sesi_makan.dart';

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
  Stream<({String sesiId, DateTime t0})> get selesaiMakanDitekan;

  /// Status terakhir yang diketahui, agar UI tidak kosong sebelum stream
  /// mengirim nilai pertamanya.
  StatusPerangkat get statusTerakhir;

  /// Memindai jam di sekitar. Perangkat dikirim satu per satu selagi terlihat,
  /// dan stream-nya ditutup sendiri saat pemindaian selesai — UI memakai
  /// penutupan itu sebagai tanda "selesai", bukan timer sendiri.
  ///
  /// Membatalkan langganan berarti menghentikan pemindaian.
  Stream<PerangkatDitemukan> pindai();

  /// Memasangkan jam. Mengembalikan false bila gagal (di luar jangkauan atau
  /// perangkatnya bukan AsaWatch).
  Future<bool> sambungkan(String idPerangkat);

  /// Memutus jam tanpa melupakan sampel yang masih di buffer-nya.
  Future<void> putuskan();

  /// Menyalakan tombol "Selesai Makan" di jam untuk sesi ini.
  ///
  /// Jam menolak tombolnya selama belum disiapkan, sehingga sesi tidak pernah
  /// dimulai tanpa foto makanan. Mengembalikan false bila jam tidak tersambung
  /// sehingga penyiapannya belum sampai.
  Future<bool> siapkanSesi(String sesiId);

  Future<void> mintaUkur(String sesiId, int index); // baseline
  Future<void> batalkanSesi(String sesiId);
  Future<void> sinkronkan(); // tarik buffer jam

  /// Pengukuran sekali jalan di luar sesi, dipakai alur kalibrasi (§5).
  Future<Sampel> ukurSekarang();

  /// Mengirim koefisien kalibrasi ke jam.
  Future<void> kirimKalibrasi(Kalibrasi kalibrasi);

  void dispose();
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
class FakeBleService implements BleService {
  FakeBleService({
    this.percepatan = 360,
    this.lewatkan = const {},
    this.otomatisSelesaiMakan = 600,
    StatusPerangkat? status,
    int benih = 7,
  }) : _status =
           status ??
           const StatusPerangkat(
             tersambung: true,
             baterai: 68,
             namaPerangkat: 'AsaWatch X1',
           ),
       _acak = Random(benih);

  final int percepatan;
  final Set<int> lewatkan;
  final int? otomatisSelesaiMakan;
  final Random _acak;

  StatusPerangkat _status;
  final _pengendaliStatus = StreamController<StatusPerangkat>.broadcast();
  final _pengendaliSampel =
      StreamController<({String sesiId, Sampel sampel})>.broadcast();
  final _pengendaliT0 =
      StreamController<({String sesiId, DateTime t0})>.broadcast();
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
  Stream<({String sesiId, DateTime t0})> get selesaiMakanDitekan =>
      _pengendaliT0.stream;

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
  bool tekanSelesaiMakan({DateTime? waktu}) {
    final sesiId = _sesiSiap;
    if (sesiId == null || _sudahDitekan) return false;
    _sudahDitekan = true;

    final t0 = waktu ?? DateTime.now();
    if (!_pengendaliT0.isClosed) _pengendaliT0.add((sesiId: sesiId, t0: t0));

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
  Future<void> mintaUkur(String sesiId, int index) async {
    if (lewatkan.contains(index)) return;
    // Pengukuran atas permintaan tetap butuh waktu di jam sungguhan.
    _timer.add(
      Timer(_jeda(20), () {
        _kirim(sesiId, _buatSampel(index, index == 0 ? -1500 : 0));
      }),
    );
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
    await Future<void>.delayed(_jeda(30));
    return _buatSampel(1, 0);
  }

  @override
  Future<void> kirimKalibrasi(Kalibrasi kalibrasi) async {
    await Future<void>.delayed(_jeda(10));
  }

  /// Katalog jam palsu yang "terlihat" saat memindai. Perangkat asing ikut
  /// masuk daftar supaya UI-nya harus benar-benar menangani yang tak didukung.
  static const _katalog = <PerangkatDitemukan>[
    PerangkatDitemukan(id: 'AW-X1-0A73', nama: 'AsaWatch X1', kekuatanSinyal: -48),
    PerangkatDitemukan(id: 'AW-S2-19C4', nama: 'AsaWatch S2', kekuatanSinyal: -74),
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

    pengendali = StreamController<PerangkatDitemukan>(
      onListen: () {
        // Jeda antar-temuan ikut dipercepat, jadi test tidak menunggu detik
        // nyata.
        for (var i = 0; i < _katalog.length; i++) {
          timers.add(
            Timer(_jeda(2 * (i + 1)), () {
              if (!pengendali.isClosed) pengendali.add(_katalog[i]);
            }),
          );
        }
        timers.add(
          Timer(_jeda(2 * (_katalog.length + 1)), () {
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
  Future<bool> sambungkan(String idPerangkat) async {
    await Future<void>.delayed(_jeda(3));

    final cocok = _katalog.where((p) => p.id == idPerangkat && p.didukung);
    if (cocok.isEmpty) return false;
    final perangkat = cocok.first;

    _perbaruiStatus(
      StatusPerangkat(
        tersambung: true,
        baterai: _status.baterai ?? 68,
        sampelTertunda: _status.sampelTertunda,
        sinkronTerakhir: _status.sinkronTerakhir,
        namaPerangkat: perangkat.nama,
      ),
    );
    return true;
  }

  @override
  Future<void> putuskan() async {
    // Namanya sengaja dipertahankan: jam yang diputus tetap jam yang sudah
    // dipasangkan, dan sampelnya menumpuk di buffer sampai tersambung lagi.
    _perbaruiStatus(_status.salin(tersambung: false));
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

  Sampel _buatSampel(int index, int detikRelatifT0) {
    final dasar = _gulaBaseline ??= 88 + _acak.nextInt(10);
    final gula = switch (index) {
      0 => dasar,
      1 => dasar + 4 + _acak.nextInt(8),
      2 => dasar + 38 + _acak.nextInt(20),
      _ => dasar + 2 + _acak.nextInt(12),
    };
    return Sampel(
      index: index,
      detikRelatifT0: detikRelatifT0,
      status: StatusSampel.terisi,
      dariBuffer: !_status.tersambung,
      gulaDarah: gula,
      detakJantung: 70 + _acak.nextInt(20),
      sistolik: 112 + _acak.nextInt(14),
      diastolik: 74 + _acak.nextInt(9),
      spo2: 96 + _acak.nextInt(3),
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
    _pengendaliSampel.close();
    _pengendaliT0.close();
  }
}
