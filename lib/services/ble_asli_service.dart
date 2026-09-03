/// Jam tangan sungguhan lewat BLE — docs/rencana-produksi.md §4,
/// docs/protokol-jam.md.
///
/// Berkas ini memenuhi kontrak [BleService] yang sudah dipakai seluruh UI sejak
/// Fase UI. Kontraknya tidak berubah bentuknya di sini kecuali satu tambahan
/// yang tidak bisa dihindari (`waktuTidakPasti` pada `selesaiMakanDitekan`,
/// protokol §4.3) — sisanya tetap sama persis, dan `FakeBleService` tetap hidup
/// sebagai satu-satunya cara mendemokan aplikasi tanpa hardware.
///
/// Empat hal yang menjelaskan hampir seluruh isi berkas ini:
///
/// 1. **Jam tidak punya RTC.** Ia hanya mengirim `uptime_s` + `boot_id`, dan
///    aplikasi yang menerjemahkannya lewat *anchor* (§4). Setiap koneksi memasang
///    anchor baru, sebelum perintah apa pun.
/// 2. **Ack menyusul penulisan, bukan mendahuluinya.** Jam menghapus entri begitu
///    di-ack (§6), jadi urutannya `simpan → ack → emit`, tidak pernah lain.
/// 3. **`detikRelatifT0` adalah selisih dua pencacah**, bukan selisih dua waktu
///    kalender (§5.3). Anchor yang meleset menggeser posisi sesi di kalender,
///    tetapi bentuk kurvanya tetap benar — dan bentuk kurva itulah isi seluruh
///    halaman ringkasan.
/// 4. **Putus koneksi bukan kegagalan sesi.** Sampel menunggu di buffer jam dan
///    menyusul saat tersambung lagi; sesi hanya berakhir karena tenggatnya
///    sendiri (`SesiMakanController.tenggatSampelTerakhir`).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/anchor_waktu.dart';
import '../models/sesi_makan.dart';
import '../repositories/anchor_repository.dart';
import '../repositories/entri_jam_repository.dart';
import '../repositories/perangkat_repository.dart';
import 'ble_service.dart';
import 'protokol_jam.dart';

// `GalatJam` pindah ke `protokol_jam.dart` supaya `FakeBleService` bisa
// melemparkannya tanpa menyeret `flutter_blue_plus` ke jalur test. Diekspor
// kembali di sini agar `import 'services/ble_asli_service.dart' show GalatJam`
// yang sudah tersebar di halaman-halaman tetap bekerja.
export 'protokol_jam.dart' show GalatJam;

/// Penyandingan gagal dengan sebab yang sudah diketahui persis, jadi ia tidak
/// perlu ditebak lagi di [BleAsliService.sambungkan].
class _GagalPenyandingan implements Exception {
  const _GagalPenyandingan(this.hasil);
  final HasilSambung hasil;
}

class BleAsliService implements BleService {
  BleAsliService({
    required this.anchorRepo,
    required this.entriRepo,
    required this.perangkatRepo,
  });

  final AnchorRepository anchorRepo;
  final EntriJamRepository entriRepo;
  final PerangkatRepository perangkatRepo;

  final _pengendaliStatus = StreamController<StatusPerangkat>.broadcast();
  final _pengendaliTahap = StreamController<TahapSambung>.broadcast();
  final _pengendaliSampel =
      StreamController<({String sesiId, Sampel sampel})>.broadcast();
  final _pengendaliT0 =
      StreamController<
        ({String sesiId, DateTime t0, bool waktuTidakPasti})
      >.broadcast();

  /// Peristiwa ACK/NAK, dipisahkan dari stream publik karena ia percakapan
  /// internal antara [_kirimPerintah] dan jam, bukan sesuatu yang UI tunggu.
  final _pengendaliBalasan = StreamController<EntriPeristiwa>.broadcast();

  final _pengendaliKemajuan = StreamController<KemajuanUkur>.broadcast();

  /// Penantian [ukurSekarang] yang sedang berjalan, atau null bila tidak ada.
  ///
  /// Ada di level objek, bukan sebagai variabel lokal, karena tiga jalur di
  /// luar fungsi itu harus bisa menghentikannya: paket Status (denyut), event
  /// `UKUR_GAGAL`, dan pemutusan tautan. Ketiganya tahu penantiannya gagal jauh
  /// lebih awal daripada penjaga waktu mana pun.
  _PenantiUkur? _penantiUkur;

  /// Penjaga kabar kemajuan, terpisah dari penjaga penantian: ia hidup juga
  /// saat yang diukur adalah titik sesi, yang tidak punya penanti.
  Timer? _jagaTampilanUkur;
  int? _persenTerakhir;
  DateTime? _persenBerubahPada;

  StatusPerangkat _status = const StatusPerangkat(tersambung: false);

  BluetoothDevice? _perangkat;
  BluetoothCharacteristic? _kontrol;

  /// Karakteristik Status, disimpan agar bisa **dibaca** saat denyutnya
  /// menghilang — lihat [_periksaDenyutHilang].
  BluetoothCharacteristic? _statusKar;
  InfoJam? _info;

  /// Anchor per `boot_id`, di-cache supaya konversi tiap sampel tidak menjadi
  /// satu pembacaan basis data.
  ///
  /// Isinya **dimuat dari basis data**, bukan hanya diisi saat anchor baru
  /// dipasang. Itu bedanya antara memenuhi §4.5 dan sekadar terlihat memenuhinya:
  /// anchor yang tersimpan tetapi tidak pernah dibaca kembali membuat seluruh isi
  /// buffer jam menjadi `waktu_tidak_pasti` setiap kali aplikasi dimulai ulang —
  /// persis kejadian yang dokumen protokol memperingatkannya.
  final Map<int, AnchorWaktu?> _anchor = {};

  /// Anchor yang berlaku untuk [bootId], dari cache lalu dari basis data.
  ///
  /// null berarti boot itu tidak pernah sekali pun tersambung, dan waktunya tidak
  /// akan pernah bisa diketahui siapa pun (§4.3) — bukan error, melainkan
  /// keadaan yang memang punya namanya sendiri.
  Future<AnchorWaktu?> _anchorUntuk(int bootId) async {
    if (_anchor.containsKey(bootId)) return _anchor[bootId];
    try {
      return _anchor[bootId] = await anchorRepo.terbaruUntuk(bootId);
    } catch (e) {
      debugPrint('Anchor boot $bootId tidak terbaca: $e');
      return null; // jangan di-cache: kegagalan baca bukan ketiadaan anchor
    }
  }

  /// `boot_id` + `uptime_s` saat tombol ditekan, per sesi (§5.3). Dimuat ulang
  /// dari kotak masuk saat start — lihat `EntriJamRepository.t0PerSesi`.
  final Map<String, ({int bootId, int uptimeS})> _t0Sesi = {};

  /// `seq` terakhir yang sudah diterima, untuk `SINKRON` (§6 aturan 6).
  int _seqTerakhir = 0;

  final List<StreamSubscription<dynamic>> _langganan = [];
  Timer? _reconnect;
  Duration _backoff = ProtokolJam.backoffAwal;
  bool _dibuang = false;

  // --- Kontrak BleService ------------------------------------------------

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

  /// Memuat keadaan yang bertahan lintas start, lalu mencoba menyambung.
  ///
  /// Dipanggil `main()` sebelum `runApp`, tetapi **tidak ditunggu sampai
  /// tersambung**: menunggu radio BLE berarti layar putih selama beberapa detik
  /// setiap kali aplikasi dibuka, dan setiap permukaan sesi sudah tahu cara
  /// menampilkan jam yang belum tersambung.
  Future<void> mulai() async {
    final tersimpan = await perangkatRepo.muat();
    if (tersimpan != null) {
      // Namanya diketahui sejak sekarang: itulah yang membedakan "belum pernah
      // dipasangkan" dari "dipasangkan tetapi di luar jangkauan".
      _perbaruiStatus(
        _status.salin(tersambung: false, namaPerangkat: tersimpan.nama),
      );
    }

    _t0Sesi.addAll(await entriRepo.t0PerSesi());

    // Entri yang sempat di-ack tetapi sesinya tidak keburu ditulis. Diputar
    // ulang lebih dulu, sebelum apa pun dari udara, supaya urutannya tetap
    // sama seperti saat ia datang.
    await _putarUlangKotakMasuk();

    if (tersimpan != null) unawaited(_sambungkanUlang(tersimpan.id));
  }

  @override
  Stream<PerangkatDitemukan> pindai() {
    // `StreamController`, bukan `async*`: membatalkan langganan harus
    // menghentikan pemindaian **seketika**. Generator `async*` baru berhenti di
    // titik `await` berikutnya, dan radio yang masih memindai setelah halaman
    // ditutup adalah baterai yang habis tanpa alasan.
    late final StreamController<PerangkatDitemukan> pengendali;
    StreamSubscription<List<ScanResult>>? langgananHasil;
    final terlihat = <String>{};

    Future<void> hentikan() async {
      await langgananHasil?.cancel();
      langgananHasil = null;
      try {
        await FlutterBluePlus.stopScan();
      } catch (e) {
        debugPrint('Gagal menghentikan pemindaian: $e');
      }
    }

    pengendali = StreamController<PerangkatDitemukan>(
      onListen: () async {
        langgananHasil = FlutterBluePlus.onScanResults.listen((hasil) {
          for (final r in hasil) {
            final id = r.device.remoteId.str;
            if (!terlihat.add(id)) continue;
            if (!pengendali.isClosed) pengendali.add(_keTemuan(r));
          }
        });

        try {
          // Disaring di level OS, bukan di aplikasi: radio hanya melaporkan
          // perangkat yang mengiklankan service AsaWatch, sehingga paket iklan
          // headset, TV, dan jam tetangga tidak pernah membangunkan proses ini
          // sama sekali. Itu penghematan baterai yang tidak bisa ditiru dengan
          // menyaring di Dart.
          //
          // Konsekuensinya jatuh ke firmware, dan berat: **jam yang tidak
          // mengiklankan service UUID-nya tidak akan pernah terlihat.** Paket
          // iklan legacy hanya 31 byte, sedangkan §2.2 menuntut nama lengkap
          // (~15 byte) + UUID 128-bit (18 byte) + 1 byte versi. Sebagian wajib
          // pindah ke scan response, dan UUID-nya yang harus tetap di paket
          // iklan.
          //
          // Karena itu layar kosong di sini tidak boleh berbunyi "tidak ada
          // perangkat" saja — lihat `_kartuKosong()` di halaman pemindaian.
          await FlutterBluePlus.startScan(
            withServices: [Guid(ProtokolJam.uuidLayanan)],
            timeout: const Duration(seconds: 10),
          );
          await FlutterBluePlus.isScanning.where((s) => !s).first;
        } catch (e) {
          debugPrint('Pemindaian gagal: $e');
        }
        // Stream ditutup di sini, dan penutupan itulah yang dibaca UI sebagai
        // "pemindaian selesai" — halaman pemindaian tidak punya timer sendiri.
        if (!pengendali.isClosed) await pengendali.close();
      },
      onCancel: hentikan,
    );

    return pengendali.stream;
  }

  static PerangkatDitemukan _keTemuan(ScanResult r) {
    final layanan = r.advertisementData.serviceUuids.map(
      (g) => g.str.toLowerCase(),
    );
    final punyaLayanan = layanan.contains(ProtokolJam.uuidLayanan);
    final nama = r.advertisementData.advName.isNotEmpty
        ? r.advertisementData.advName
        : r.device.platformName;

    return PerangkatDitemukan(
      id: r.device.remoteId.str,
      nama: nama.isEmpty ? 'Perangkat tanpa nama' : nama,
      kekuatanSinyal: r.rssi,
      // Dengan penyaringan di level OS, ini seharusnya selalu true. Tetap
      // dihitung, bukan di-hardcode: bila suatu hari filternya dilonggarkan —
      // atau OS mengembalikan hasil yang tidak sepenuhnya cocok — perangkat yang
      // tidak akan pernah menjawab handshake tetap tidak boleh bisa dipilih.
      didukung: punyaLayanan,
    );
  }

  @override
  Stream<TahapSambung> get tahapSambung => _pengendaliTahap.stream;

  void _tahap(TahapSambung tahap) {
    if (!_pengendaliTahap.isClosed) _pengendaliTahap.add(tahap);
  }

  @override
  Future<HasilSambung> sambungkan(String idPerangkat) async {
    _galatTerakhir = null;
    try {
      await _sambungkan(idPerangkat, simpanPasangan: true);
      return HasilSambung.berhasil;
    } on GalatVersiJam catch (e) {
      // Versi mayor yang tidak cocok bukan "coba lagi" — ia butuh pembaruan.
      // Pesannya sudah berbahasa Indonesia dan sudah menyebut sisi mana yang
      // harus diperbarui.
      _galatTerakhir = e.pesanPengguna;
      await _putuskanDiam();
      return HasilSambung.versiTidakCocok;
    } on _GagalPenyandingan catch (e) {
      await _putuskanDiam();
      return e.hasil;
    } on GalatJam catch (e) {
      debugPrint('Gagal menyambung ke $idPerangkat: $e');
      await _putuskanDiam();
      return HasilSambung.bukanAsaWatch;
    } catch (e) {
      debugPrint('Gagal menyambung ke $idPerangkat: $e');
      // Sudah tersandingkan tetapi tetap gagal sebelum handshake selesai
      // adalah tanda khas kunci basi: jam di-reset atau firmware-nya diganti,
      // sehingga enkripsinya putus justru setelah tautannya terbentuk.
      //
      // Ini **tebakan**, bukan kepastian — jam yang menjauh di detik yang salah
      // terlihat serupa. Karena itu pesannya (§5) menawarkan "Coba lagi" sebagai
      // tindakan utama dan penghapusan penyandingan hanya sebagai jalan kedua:
      // tebakan yang salah tidak boleh merusak pemasangan yang sebenarnya sehat.
      final basi = _bondSebelumnya && !_handshakeSelesai;
      await _putuskanDiam();
      return basi ? HasilSambung.bondBasi : HasilSambung.diLuarJangkauan;
    }
  }

  @override
  Future<bool> lupakanPenyandingan(String idPerangkat) async {
    try {
      await BluetoothDevice.fromId(idPerangkat).removeBond();
      return true;
    } catch (e) {
      // Sebagian versi Android menolak penghapusan bond dari aplikasi. Yang
      // tersisa bagi pengguna adalah Pengaturan Bluetooth sistem, dan UI harus
      // mengatakannya — bukan menampilkan tombol yang diam-diam tidak bekerja.
      debugPrint('Gagal menghapus penyandingan $idPerangkat: $e');
      return false;
    }
  }

  /// Alasan kegagalan sambung terakhir yang layak dibaca pengguna, null bila
  /// kegagalannya biasa saja (di luar jangkauan, jam mati).
  @override
  String? get galatTerakhir => _galatTerakhir;
  String? _galatTerakhir;

  /// Keadaan satu percobaan sambung, dipakai untuk membedakan kunci basi dari
  /// jam yang sekadar menjauh. Di-reset di awal tiap [_sambungkan].
  ///
  /// [_bondSebelumnya] sengaja hanya true bila ponsel **sudah** tersandingkan
  /// saat percobaan ini dimulai. Bond yang baru saja dibuat tidak mungkin basi,
  /// jadi memasukkannya ke sini akan mengubah setiap kegagalan pemasangan
  /// pertama menjadi saran menghapus penyandingan yang baru saja dibuat.
  bool _bondSebelumnya = false;
  bool _handshakeSelesai = false;

  /// Menyandingkan jam **secara eksplisit**, sebelum operasi berenkripsi apa pun.
  ///
  /// Android sebenarnya menyandingkan sendiri begitu karakteristik terenkripsi
  /// pertama disentuh — dan justru itu masalahnya. Penyandingan implisit itu
  /// menyelinap ke tengah `discoverServices()` atau tulis pertama, yang punya
  /// timeout ketat, padahal yang sedang ditunggu adalah **pengguna menemukan dan
  /// menekan tombol di dialog sistem**. Aplikasi menyerah lebih dulu dan
  /// melaporkan "tidak dapat disambungkan" untuk penyandingan yang beberapa
  /// detik kemudian berhasil — lalu percobaan kedua mulus, karena bond-nya
  /// sudah terbentuk (docs/alur-pemasangan-jam.md §1).
  ///
  /// Dipanggil di sini, satu-satunya momen yang menunggu manusia berdiri
  /// sendiri: ia punya keadaan UI-nya sendiri, dan **tidak dibatasi waktu dari
  /// sisi aplikasi**.
  Future<void> _sandingkan(BluetoothDevice perangkat) async {
    // Bond yang bisa dikendalikan aplikasi hanya ada di Android; di iOS
    // CoreBluetooth mengurusnya sendiri dan `createBond` melempar `android-only`.
    if (defaultTargetPlatform != TargetPlatform.android) return;

    if (await perangkat.bondState.first == BluetoothBondState.bonded) {
      _bondSebelumnya = true;
      return;
    }

    _tahap(TahapSambung.menyandingkan);
    try {
      // Batas waktunya milik sistem (bawaan 90 detik), bukan milik aplikasi.
      // Aplikasi tidak boleh menyerah lebih awal daripada dialognya sendiri:
      // pengguna lansia mungkin harus menarik panel notifikasi lebih dulu (§4.4).
      await perangkat.createBond();
    } on FlutterBluePlusException catch (e) {
      // Hangus tanpa dijawab dan ditolak adalah dua hal berbeda, dan tindak
      // lanjutnya juga berbeda — yang pertama perlu diberi tahu di mana
      // dialognya, yang kedua perlu diberi tahu kenapa penyandingan diperlukan.
      throw _GagalPenyandingan(
        e.code == FbpErrorCode.timeout.index
            ? HasilSambung.penyandinganTidakDijawab
            : HasilSambung.penyandinganDitolak,
      );
    }
  }

  /// Apakah jam yang masih dicatat aplikasi sudah tidak tersandingkan lagi di
  /// ponsel ini.
  ///
  /// Ragu diperlakukan sebagai "masih tersandingkan": pembacaan bond yang gagal
  /// bukan bukti bahwa penyandingannya hilang, dan menghentikan sambung ulang
  /// karena tebakan akan membuat jam yang sehat terlihat lepas.
  Future<bool> _kehilanganPenyandingan(String idPerangkat) async {
    if (defaultTargetPlatform != TargetPlatform.android) return false;
    try {
      final bond = await BluetoothDevice.fromId(idPerangkat).bondState.first;
      return bond != BluetoothBondState.bonded;
    } catch (e) {
      debugPrint('Keadaan penyandingan $idPerangkat tidak terbaca: $e');
      return false;
    }
  }

  /// Mencatat MTU hasil negosiasi, satu baris per koneksi.
  ///
  /// `connect(mtu: …)` hanya **meminta**; yang menentukan adalah negosiasi
  /// radio, dan hasilnya tidak pernah dilaporkan ke mana pun. Kalau ia tetap 23
  /// (bawaan ATT), muatan notifikasi maksimum hanya 20 byte — dan sisi jam
  /// memotong setiap paket yang lebih panjang **tanpa error dan tanpa log**
  /// (NimBLE `ble_att_truncate_to_mtu`, bertipe `void`). Sampel 31 byte dan
  /// Peristiwa 26 byte sama-sama tiba terpotong, `notify()` di jam tetap
  /// melapor sukses, dan tidak ada satu pun lapisan di antaranya yang
  /// mengeluh. Gejalanya di layar bukan galat melainkan sinkronisasi yang
  /// berjalan sampai 100% tanpa satu pun sampel masuk.
  ///
  /// **Tidak membatalkan koneksi.** Jam yang tersambung dengan MTU kecil tetap
  /// mengirim Status dan baterai, dan halaman perangkatnya tetap satu-satunya
  /// tempat pengguna bisa memutus atau menyandingkan ulang. Sejak paket
  /// kependekan berhenti di-ACK ([_buangPaketRusak]), koneksi seperti ini tidak
  /// lagi merusak apa pun — entrinya menunggu di buffer jam sampai tautannya
  /// benar. Menolak menyambung hanya akan menutup satu-satunya layar yang bisa
  /// menjelaskan keadaannya.
  void _catatMtu(BluetoothDevice perangkat) {
    final int mtu;
    try {
      mtu = perangkat.mtuNow;
    } catch (e) {
      debugPrint('MTU tidak terbaca: $e');
      return;
    }

    if (mtu >= ProtokolJam.mtuMinimum) {
      debugPrint('MTU $mtu (diminta ${ProtokolJam.mtuDiminta}).');
      return;
    }

    debugPrint(
      'MTU $mtu, di bawah minimum ${ProtokolJam.mtuMinimum} '
      '(diminta ${ProtokolJam.mtuDiminta}). '
      'Muatan notifikasi hanya ${mtu - 3} byte, sedangkan Sampel butuh '
      '${ProtokolJam.panjangSampel} dan Peristiwa ${ProtokolJam.panjangPeristiwa}. '
      'Jam akan memotong keduanya tanpa memberi tahu, jadi tidak akan ada sampel '
      'yang masuk sampai MTU dinaikkan.',
    );
  }

  Future<void> _sambungkan(
    String idPerangkat, {
    required bool simpanPasangan,
  }) async {
    await _putuskanDiam();
    _bondSebelumnya = false;
    _handshakeSelesai = false;

    final perangkat = BluetoothDevice.fromId(idPerangkat);
    _perangkat = perangkat;

    _tahap(TahapSambung.menyambung);

    // MTU diminta saat menyambung, bukan sesudahnya: sampel butuh 31 byte utuh
    // dalam satu notifikasi (§8), dan notifikasi pertama bisa datang sebelum
    // permintaan terpisah sempat selesai. Di iOS parameter ini diabaikan —
    // CoreBluetooth menegosiasikannya sendiri.
    await perangkat.connect(
      timeout: const Duration(seconds: 15),
      mtu: ProtokolJam.mtuDiminta,
    );

    await _sandingkan(perangkat);
    _catatMtu(perangkat);

    _tahap(TahapSambung.menyiapkan);
    final layanan = await perangkat.discoverServices();
    final asawatch = layanan.where(
      (s) => s.uuid.str.toLowerCase() == ProtokolJam.uuidLayanan,
    );
    if (asawatch.isEmpty) {
      throw const GalatJam('Perangkat ini bukan jam AsaWatch.');
    }

    BluetoothCharacteristic? cari(String uuid) {
      for (final c in asawatch.first.characteristics) {
        if (c.uuid.str.toLowerCase() == uuid) return c;
      }
      return null;
    }

    final info = cari(ProtokolJam.uuidInfo);
    final kontrol = cari(ProtokolJam.uuidKontrol);
    final peristiwa = cari(ProtokolJam.uuidPeristiwa);
    final sampel = cari(ProtokolJam.uuidSampel);
    final status = cari(ProtokolJam.uuidStatus);
    if (info == null ||
        kontrol == null ||
        peristiwa == null ||
        sampel == null ||
        status == null) {
      throw const GalatJam('Firmware jam tidak lengkap. Perbarui firmware.');
    }
    _kontrol = kontrol;

    // Handshake dibaca **sebelum operasi lain apa pun** (§3): versi mayor yang
    // tidak cocok berarti byte berikutnya akan salah dibaca, bukan sekadar
    // fitur yang hilang.
    final infoJam = bacaInfo(await info.read());
    infoJam.periksaVersi();
    _info = infoJam;
    // Kemampuan diketahui sejak byte pertama handshake, jadi ia dipasang di sini
    // — sebelum satu pun sampel bisa datang. UI yang menyembunyikan metrik baru
    // setelah sampel pertama tiba akan sempat menampilkan `—` untuk sensor yang
    // memang tidak ada, dan itu persis yang §3 larang.
    _perbaruiStatus(_status.salin(kemampuan: _keKemampuan(infoJam.kemampuan)));
    // Sejak titik ini tautannya terbukti terenkripsi dan dipahami kedua sisi,
    // jadi kegagalan sesudahnya bukan lagi soal kunci penyandingan yang basi.
    _handshakeSelesai = true;
    // Dicatat karena `uptime_s` hanya dibaca sekali per koneksi: anchor yang
    // dipasang beberapa ratus milidetik kemudian harus tahu berapa lama sudah
    // berlalu sejak angka itu benar.
    _waktuBacaInfo = DateTime.now();

    // Langganan dipasang sebelum anchor dikirim: balasan ACK-nya datang lewat
    // karakteristik Peristiwa, bukan lewat write response (§5.1).
    await _langganiNotifikasi(perangkat, layanan, peristiwa, sampel, status);

    // Setiap koneksi memasang anchor, sebelum perintah lain (§4.2). Murah,
    // idempoten, dan melewatkannya sekali bisa membuat satu sesi penuh
    // kehilangan waktunya.
    //
    // **Kegagalannya tidak membatalkan koneksi.** Ini pernah salah dan akibatnya
    // besar: `_pasangAnchor` yang melempar membuat `_sambungkan` melempar, status
    // tidak pernah menjadi tersambung, dan penyambung ulang mencobanya lagi —
    // selamanya, setiap kali membayar connect + discover + tiga percobaan tulis.
    // Yang terlihat di logcat adalah `writeCharacteristic` berulang tanpa henti.
    //
    // Jam yang tersambung tanpa anchor tetap berguna: entrinya masuk dengan
    // `waktu_tidak_pasti`, dan seluruh aplikasi sudah tahu cara memperlakukan itu
    // (§4.3). Keadaan terdegradasi jauh lebih baik daripada tidak tersambung sama
    // sekali — apalagi kalau harganya adalah lingkaran sambung ulang tanpa ujung.
    try {
      await _pasangAnchor(infoJam.bootId);
    } catch (e) {
      debugPrint(
        'ANCHOR_WAKTU gagal, koneksi tetap dilanjutkan: $e\n'
        'Entri dari boot ${infoJam.bootId} akan masuk sebagai waktu_tidak_pasti.',
      );
    }

    // **Penyimpanan yang gagal tidak membatalkan koneksi** — alasannya sama
    // persis dengan `_pasangAnchor` di atas, dan itulah kenapa keduanya harus
    // dijaga: radio yang sehat tidak boleh dinyatakan gagal karena disk.
    //
    // Tanpa penjagaan ini, `SharedPreferences` yang melempar membuat
    // `_sambungkan` melempar setelah **seluruh handshake berhasil**, lalu
    // `_sambungkanUlang` menangkapnya sebagai gangguan sesaat dan mengulang
    // semuanya: connect → discover → baca Info → setNotify ×3 → baca Status →
    // ulang, selamanya. Bentuk lingkaran itu tidak menyebut disk sama sekali di
    // logcat, jadi ia terbaca seperti masalah radio.
    var nama = perangkat.platformName.isEmpty
        ? 'AsaWatch'
        : perangkat.platformName;
    try {
      if (simpanPasangan) {
        await perangkatRepo.simpan(
          PerangkatTersimpan(id: idPerangkat, nama: nama),
        );
      }
      nama = (await perangkatRepo.muat())?.nama ?? nama;
    } catch (e) {
      // Keadaan terdegradasi: jamnya tersambung dan berfungsi penuh, hanya
      // namanya tidak diingat lintas start. Nama dari iklan dipakai sebagai
      // gantinya supaya UI tetap punya sesuatu yang benar untuk ditampilkan.
      debugPrint('Pasangan jam gagal disimpan/dibaca, koneksi dilanjutkan: $e');
    }

    _backoff = ProtokolJam.backoffAwal;
    _perbaruiStatus(
      _status.salin(
        tersambung: true,
        namaPerangkat: nama,
        // Tautan yang terbentuk membuktikan penyandingannya ada lagi, jadi
        // peringatan "tidak tersandingkan" tidak boleh tertinggal di layar.
        penyandinganHilang: false,
      ),
    );

    // Buffer jam ditarik pada setiap koneksi — di sinilah sampel yang terkumpul
    // selagi HP jauh benar-benar masuk (§6 aturan 3).
    await sinkronkan();
  }

  Future<void> _langganiNotifikasi(
    BluetoothDevice perangkat,
    List<BluetoothService> layanan,
    BluetoothCharacteristic peristiwa,
    BluetoothCharacteristic sampel,
    BluetoothCharacteristic status,
  ) async {
    await peristiwa.setNotifyValue(true);
    await sampel.setNotifyValue(true);
    await status.setNotifyValue(true);
    _statusKar = status;

    _pantau(
      peristiwa.onValueReceived.listen(
        (data) => unawaited(_terimaPeristiwa(data)),
      ),
    );
    _pantau(
      sampel.onValueReceived.listen((data) => unawaited(_terimaSampel(data))),
    );
    _pantau(status.onValueReceived.listen(_terimaStatus));

    // Baterai memakai Battery Service standar, bukan karakteristik kustom
    // (§2.1). Kalau jamnya tidak menyediakannya, statusnya tetap terisi dari
    // §5.5 — jadi tidak ada yang perlu digagalkan di sini.
    unawaited(_langganiBaterai(layanan));

    _pantau(
      perangkat.connectionState.listen((keadaan) {
        if (keadaan == BluetoothConnectionState.disconnected) {
          _tanganiPutus();
        }
      }),
    );

    // Status dibaca sekali di awal supaya UI tidak menunggu notifikasi pertama.
    try {
      _terimaStatus(await status.read());
    } catch (e) {
      debugPrint('Gagal membaca status jam: $e');
    }
  }

  /// Dilanggankan dari daftar layanan yang **sudah** ditemukan, bukan dari
  /// penemuan kedua.
  ///
  /// `discoverServices()` yang dipanggil lagi di sini bukan sekadar boros: ia
  /// berjalan tanpa ditunggu, jadi ia berlomba dengan `status.read()` yang
  /// dijalankan pemanggilnya pada saat yang sama. Penemuan layanan yang
  /// bertabrakan dengan operasi GATT lain adalah sumber kegagalan yang khas di
  /// Android, dan gejalanya jatuh di tempat yang salah — koneksi yang putus
  /// beberapa saat setelah handshake yang kelihatannya mulus.
  Future<void> _langganiBaterai(List<BluetoothService> layanan) async {
    try {
      for (final s in layanan) {
        if (s.uuid.str.toLowerCase() != ProtokolJam.uuidLayananBaterai) {
          continue;
        }
        for (final c in s.characteristics) {
          if (c.uuid.str.toLowerCase() != ProtokolJam.uuidLevelBaterai) {
            continue;
          }
          _perbaruiStatus(_status.salin(baterai: (await c.read()).firstOrNull));
          if (c.properties.notify) {
            await c.setNotifyValue(true);
            _pantau(
              c.onValueReceived.listen((data) {
                if (data.isNotEmpty) {
                  _perbaruiStatus(_status.salin(baterai: data.first));
                }
              }),
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Battery Service tidak terbaca: $e');
    }
  }

  @override
  Future<void> putuskan() async {
    // Pemasangannya **tidak** dilupakan: jam yang diputus tetap jam yang sudah
    // dipasangkan, dan sampelnya menumpuk di buffer sampai tersambung lagi.
    _reconnect?.cancel();
    _reconnect = null;
    await _putuskanDiam();
    _perbaruiStatus(_status.salin(tersambung: false));
  }

  @override
  Future<void> lupakanPerangkat() async {
    _reconnect?.cancel();
    _reconnect = null;

    // Urutannya: putus dulu, baru hapus bond. `removeBond` pada perangkat yang
    // masih tersambung meninggalkan tautan terenkripsi dengan kunci yang sudah
    // tidak ada di kedua sisi.
    final id = _perangkat?.remoteId.str ?? (await perangkatRepo.muat())?.id;
    await _putuskanDiam();
    if (id != null) await lupakanPenyandingan(id);

    // Dilupakan **setelah** bond-nya hilang, bukan sebelum: kalau aplikasi
    // berhenti di tengah, yang tertinggal adalah jam yang masih dikenal
    // aplikasi tetapi tidak tersandingkan — dan keadaan itu sudah punya
    // penanganannya sendiri (`penyandinganHilang`). Kebalikannya tidak: bond
    // yatim yang tidak dikenal aplikasi mana pun tidak akan pernah dibersihkan.
    try {
      await perangkatRepo.lupakan();
    } catch (e) {
      debugPrint('Gagal melupakan pasangan: $e');
    }

    _info = null;
    _kontrol = null;
    _backoff = ProtokolJam.backoffAwal;
    _perbaruiStatus(StatusPerangkat.kosong);
  }

  @override
  Future<bool> siapkanSesi(String sesiId) async {
    // Sesi dari sebelum Tahap B memakai id yang tidak muat di 16 byte. Semuanya
    // sudah berakhir; yang perlu dilakukan hanya tidak mencoba mengirimnya.
    if (!idSesiValid(sesiId)) return false;
    if (!_status.tersambung) return false;

    try {
      await _kirimPerintah(tulisArmSesi(sesiId));
      return true;
    } catch (e) {
      debugPrint('ARM_SESI gagal: $e');
      return false;
    }
  }

  @override
  Future<bool> mulaiSesi(String sesiId) async {
    if (!idSesiValid(sesiId)) return false;
    if (!_status.tersambung) return false;

    try {
      // Tidak ada waktu di dalam paketnya, dan tidak ada `t0` yang dikembalikan
      // di sini. Yang menjadikan sesi berjalan adalah `TOMBOL_SELESAI_MAKAN`
      // yang menyusul lewat karakteristik Peristiwa — jalur yang sama persis
      // dengan tombol fisiknya, sampai ke penulisan kotak masuk dan ack-nya.
      // Menyingkatnya di sini akan menghasilkan sesi yang t0-nya tidak pernah
      // tersimpan dan tidak selamat dari restart.
      await _kirimPerintah(tulisMulaiSesi(sesiId));
      return true;
    } catch (e) {
      debugPrint('MULAI_SESI gagal: $e');
      return false;
    }
  }

  @override
  Future<bool> armTitik(String sesiId, int index) async {
    if (!idSesiValid(sesiId) || !_status.tersambung) return false;
    try {
      await _kirimPerintah(tulisArmTitik(sesiId, index));
      return true;
    } catch (e) {
      // Tidak fatal, dan sengaja tidak dilaporkan ke UI: yang gagal hanyalah
      // tombol **fisik** jam untuk titik ini. Tombol di aplikasi tetap bekerja,
      // dan perintah ini ditulis ulang di setiap koneksi berikutnya — seperti
      // `ANCHOR_WAKTU`, ia murah dan idempoten.
      debugPrint('ARM_TITIK index $index gagal: $e');
      return false;
    }
  }

  @override
  Future<bool> mintaUkur(String sesiId, int index) async {
    if (!idSesiValid(sesiId) || !_status.tersambung) return false;
    try {
      await _kirimPerintah(tulisUkur(sesiId, index));
      return true;
    } catch (e) {
      // Baseline yang gagal diminta bukan sesi yang gagal — titik itu berakhir
      // `terlewat` dan sesinya `tidakLengkap`. Yang penting: kegagalannya
      // **dilaporkan**, bukan hanya dicatat di log. NAK `0x03` yang ditelan diam
      // membuat titiknya tampil "menunggu data" selama dua jam untuk pengukuran
      // yang sudah pasti tidak akan datang.
      debugPrint('UKUR index $index gagal: $e');
      return false;
    }
  }

  @override
  Future<void> batalkanSesi(String sesiId) async {
    _t0Sesi.remove(sesiId);
    if (!idSesiValid(sesiId) || !_status.tersambung) return;
    try {
      await _kirimPerintah(tulisBatalSesi(sesiId));
    } catch (e) {
      debugPrint('BATAL_SESI gagal: $e');
    }
  }

  @override
  Future<void> sinkronkan() async {
    if (!_status.tersambung) return;
    try {
      await _kirimPerintah(tulisSinkron(_seqTerakhir));
      _perbaruiStatus(_status.salin(sinkronTerakhir: DateTime.now()));
    } catch (e) {
      debugPrint('SINKRON gagal: $e');
    }
  }

  @override
  Stream<KemajuanUkur> get kemajuanUkur => _pengendaliKemajuan.stream;

  @override
  Future<Sampel> ukurSekarang() async {
    if (!_status.tersambung) {
      throw const GalatJam(
        'Jam tidak tersambung, jadi pengukuran belum bisa dimulai.',
      );
    }

    // Pengukuran satu kali di luar sesi — kalibrasi tekanan darah dan pindai
    // kesehatan atas permintaan. Jawabannya datang lewat karakteristik Sampel
    // seperti yang lain, jadi yang ditunggu di sini adalah notifikasi
    // berikutnya.
    //
    // **Yang ditunggu adalah sampel ber-`sesiId` nol, bukan sampel apa pun**
    // (§5.1). Perintah ini boleh dikirim kapan saja, termasuk selagi sebuah
    // sesi berjalan dan selagi buffer jam sedang terkuras, jadi sampel
    // berikutnya di stream ini bisa saja milik sesi yang sama sekali lain.
    // Menyerahkannya sebagai hasil pindai akan menampilkan angka dari satu jam
    // yang lalu sebagai "hasil barusan" — salah tanpa satu pun gejala.
    //
    // **Penantiannya dijaga oleh denyut, bukan oleh satu tenggat.** Dulu di
    // sini ada `timeout(60 detik)` tunggal, dan angka itu tidak pernah cocok
    // dengan apa pun: firmware menunggu 90 detik tanpa kulit menempel dan 5
    // menit sebagai batas keras (`UKUR_TANPA_KONTAK_MS`, `UKUR_BATAS_KERAS_MS`),
    // jadi setiap nadi yang sulit ditemukan — pergelangan dingin, tali agak
    // longgar, hal yang lazim pada pengguna lansia — dilaporkan sebagai jam
    // yang tidak menjawab, tepat ketika jam sedang bekerja. Sampelnya datang
    // beberapa detik kemudian dan dibuang tanpa jejak.
    //
    // Yang menggantikannya adalah §5.5 v1.4: jam mengirim paket Status tiap dua
    // detik selama mengukur, membawa kemajuan yang dihitungnya sendiri. Selama
    // denyut itu datang, tidak ada alasan menghentikan penantian; begitu ia
    // berhenti, tidak ada gunanya menunggu lebih lama. Empat sebab lain
    // menghentikannya lebih cepat lagi, masing-masing dengan kalimatnya sendiri
    // ([PesanUkur]) — jam yang tidak pernah mulai, tautan yang putus,
    // `UKUR_GAGAL`, dan jam yang selesai tetapi hasilnya tidak sampai.
    if (_penantiUkur != null) {
      throw const GalatJam('Pengukuran sebelumnya masih berjalan.');
    }

    final penanti = _PenantiUkur();
    _penantiUkur = penanti;

    // Langganan dipasang **sebelum** perintahnya dikirim: sampelnya boleh
    // datang secepat apa pun, dan yang lewat sebelum kita mendengarkan hilang
    // tanpa jejak — alasan yang sama dengan pemasangan langganan ACK di
    // [_kirimPerintah].
    penanti.langganan = _pengendaliSampel.stream
        .where((e) => !sesiIdNyata(e.sesiId))
        .listen((e) => penanti.selesaikan(e.sampel));

    try {
      // Sampai jam berdenyut, yang dijaga adalah "apakah pengukurannya mulai".
      penanti.aturJaga(ProtokolJam.tenggatMulaiUkur, PesanUkur.tidakMulai);
      // Langit-langit terpisah dari penjaga denyut, dan tidak pernah disetel
      // ulang: penjaga denyut menjaga dari jam yang diam, ini dari jam yang
      // berdenyut selamanya.
      penanti.langit = Timer(
        ProtokolJam.batasUkur,
        () => penanti.gagalkan(const GalatJam(PesanUkur.terlaluLama)),
      );

      await _kirimPerintah(tulisUkurSekarang());
      return await penanti.masaDepan;
    } finally {
      penanti.bersihkan();
      _penantiUkur = null;
      // Kabar kemajuan **tidak** dipadamkan di sini, dan itu disengaja sejak ia
      // berhenti menumpang pada penanti: penantian yang berakhir bukan berarti
      // jamnya berhenti mengukur. Layar yang menyerah menunggu boleh berhenti
      // menampilkannya, tetapi kartu sesi yang lain masih berhak tahu jamnya
      // sedang bekerja. Yang memadamkannya adalah bit0 yang padam atau
      // denyutnya yang berhenti — keduanya di [_kabarkanUkur].
    }
  }

  /// Denyut Status selama [ukurSekarang] berjalan (§5.5 v1.4).
  ///
  /// Dipanggil dari [_terimaStatus] untuk setiap paket Status yang tiba —
  /// termasuk yang tiba karena hal lain berubah, yang justru berguna: setiap
  /// paket adalah bukti tautan masih hidup.
  /// Meneruskan kemajuan ke [kemajuanUkur] — **untuk setiap pengukuran, bukan
  /// hanya yang sedang ditunggu sebuah layar.**
  ///
  /// Ini terpisah dari [_denyutUkur] karena keduanya menjawab pertanyaan yang
  /// berbeda: yang itu menjaga sebuah penantian, yang ini mengabarkan keadaan
  /// jam. Titik ukur sesi (`UKUR`) tidak punya penantian sama sekali —
  /// perintahnya dikirim, sampelnya datang entah kapan — sehingga selama kabar
  /// ini menumpang pada penanti, satu-satunya pengukuran yang paling lama
  /// ditunggui orang justru tidak menampilkan apa pun. Yang terlihat di layar
  /// hanyalah "Mengukur…" yang membeku sejak ACK sampai sampelnya tiba.
  ///
  /// Denyutnya sendiri sudah datang sejak dulu (§5.5 v1.4); yang kurang hanya
  /// yang memancarkannya.
  void _kabarkanUkur(StatusJam s) {
    if (_pengendaliKemajuan.isClosed) return;

    if (!s.sedangMengukur) {
      _jagaTampilanUkur?.cancel();
      _jagaTampilanUkur = null;
      _persenTerakhir = null;
      _persenBerubahPada = null;
      _pengendaliKemajuan.add(KemajuanUkur.diam);
      return;
    }

    // Satu baris yang membedakan "jam tidak berdenyut" dari "denyutnya sampai
    // tetapi aplikasi menghitungnya salah" — dua kemungkinan yang di layar
    // menghasilkan kalimat yang sama persis.
    debugPrint(
      'Denyut ukur: persen=${s.ukurPersen} sisa=${s.ukurSisaDetik} '
      '(paket ${s.punyaKemajuan ? "10" : "8"} byte)',
    );

    final sekarang = DateTime.now();
    if (s.ukurPersen != _persenTerakhir) {
      _persenTerakhir = s.ukurPersen;
      _persenBerubahPada = sekarang;
    }
    // Persen yang tidak bergerak sementara denyutnya tetap datang adalah jam
    // yang hidup dan sedang kesulitan menemukan nadi — keadaan sah dengan
    // tindak lanjutnya sendiri, bukan kegagalan.
    final macet =
        _persenBerubahPada != null &&
        sekarang.difference(_persenBerubahPada!) >= KemajuanUkur.ambangMacet;

    _pengendaliKemajuan.add(
      KemajuanUkur(
        sedangMengukur: true,
        persen: s.ukurPersen,
        sisaDetik: s.ukurSisaDetik,
        macet: macet,
      ),
    );

    // Tanpa penanti, tidak ada yang akan memadamkan kabar ini bila jamnya mati
    // di tengah pengukuran — dan "jam sedang mengukur" yang menyala selamanya
    // adalah persis kebohongan yang seluruh §5.6 ada untuk mencegahnya.
    _jagaTampilanUkur?.cancel();
    _jagaTampilanUkur = Timer(
      ProtokolJam.denyutUkurBasi,
      () => unawaited(_periksaTampilanUkur()),
    );
  }

  /// Denyut tampilan berhenti: tanya sekali, seperti [_periksaDenyutHilang].
  Future<void> _periksaTampilanUkur() async {
    final kar = _statusKar;
    if (kar != null && _status.tersambung) {
      try {
        // Lewat jalur biasa: bila jamnya masih mengukur, kabarnya terbit lagi
        // dan penjaganya dipasang ulang di sana.
        _terimaStatus(await kar.read());
        return;
      } catch (e) {
        debugPrint('Status tidak terbaca saat kabar ukur berhenti: $e');
      }
    }
    if (!_pengendaliKemajuan.isClosed) {
      _pengendaliKemajuan.add(KemajuanUkur.diam);
    }
  }

  void _denyutUkur(StatusJam s) {
    final penanti = _penantiUkur;
    if (penanti == null) return;

    if (s.sedangMengukur) {
      penanti.pernahMengukur = true;

      // **Diam bukan bukti mati — dan itu berlaku untuk kedua versi
      // firmware.** Saat penjaga ini habis, yang dilakukan bukan menyerah
      // melainkan BERTANYA: satu pembacaan karakteristik Status. Notifikasi
      // bisa hilang di udara, tertahan interval koneksi, atau tidak pernah
      // dikirim sama sekali oleh firmware ≤ v1.3 yang memang tidak berdenyut —
      // sementara pembacaan yang berhasil membuktikan dua hal sekaligus:
      // tautannya hidup, dan jamnya masih mengukur.
      //
      // Karena itu kedua versi firmware melewati jalur yang sama. Yang
      // membedakan hanya sumber kabarnya: v1.4 dijawab denyut yang datang
      // sendiri, v1.3 dijawab pembacaan tiap delapan detik. Menyerah tanpa
      // bertanya lebih dulu adalah kesalahan yang sama dengan tenggat 60 detik
      // yang digantikan seluruh bagian ini.
      penanti.aturJagaPeriksa(ProtokolJam.denyutUkurBasi, _periksaDenyutHilang);
      return;
    }

    // Jam berhenti mengukur. Sampelnya belum tentu terlambat: firmware
    // mengirim paket Status ini di dalam `ukur_selesai()`, sementara paket
    // Sampel-nya berangkat lewat ring buffer setelahnya — jadi urutan yang
    // normal justru "status dulu, sampel menyusul". Yang dipasang di sini
    // karena itu tenggat pendek, bukan kegagalan seketika.
    if (penanti.pernahMengukur) {
      penanti.aturJaga(
        ProtokolJam.tenggatHasilUkur,
        PesanUkur.hasilTidakSampai,
      );
    }
  }

  @override
  Future<bool> jamSedangMengukur() async {
    final kar = _statusKar;
    if (kar == null || !_status.tersambung) return false;
    try {
      return bacaStatus(await kar.read()).sedangMengukur;
    } catch (e) {
      // Jam yang tidak bisa ditanya tidak boleh menahan apa pun. Ini dipakai
      // untuk menunda tenggat sesi, dan tenggat itu ada justru untuk jam yang
      // mati — menjawab true saat pembacaannya gagal akan membuat sesi
      // menggantung persis pada keadaan yang tenggatnya dirancang untuk
      // menutup.
      debugPrint('Status tidak terbaca saat tenggat sesi: $e');
      return false;
    }
  }

  /// Denyutnya tidak datang — tanya langsung sebelum menyerah.
  ///
  /// Karakteristik Status bersifat Read **dan** Notify (§5.5), dan firmware
  /// menyegarkannya di `onRead`. Satu pembacaan karena itu menjawab pertanyaan
  /// yang sebenarnya: bukan "apakah ada paket yang datang", melainkan "apakah
  /// jamnya masih mengukur". Jawaban yang gagal — tautan sudah tidak ada —
  /// adalah satu-satunya yang mengakhiri penantian di sini.
  Future<void> _periksaDenyutHilang() async {
    final penanti = _penantiUkur;
    if (penanti == null) return;

    final kar = _statusKar;
    if (kar == null) {
      penanti.gagalkan(const GalatJam(PesanUkur.denyutBerhenti));
      return;
    }

    try {
      final data = await kar.read();
      if (_penantiUkur != penanti) return; // sudah selesai selagi menunggu
      // Lewat jalur yang sama dengan notifikasi: bila jamnya masih mengukur,
      // penjaganya disetel ulang di sana dan kemajuannya ikut sampai ke layar;
      // bila bit0-nya sudah padam, yang dipasang adalah tenggat pendek untuk
      // sampel yang menyusul, bukan kegagalan seketika.
      _terimaStatus(data);
    } catch (e) {
      debugPrint('Status tidak terbaca saat denyut hilang: $e');
      penanti.gagalkan(const GalatJam(PesanUkur.denyutBerhenti));
    }
  }

  /// Menghentikan penantian [ukurSekarang] yang sedang berjalan, kalau ada.
  void _gagalkanUkur(GalatJam galat) => _penantiUkur?.gagalkan(galat);

  /// Bitfield `kemampuan` handshake → bentuk yang dimengerti UI (§3).
  ///
  /// Detak jantung tidak punya bit dan karena itu tidak ikut dipetakan; §3
  /// memang tidak menyediakan satu, dan mengarangnya di sini akan membuat
  /// aplikasi menyembunyikan metrik atas dasar bit yang tidak pernah dikirim
  /// firmware mana pun.
  static KemampuanPerangkat _keKemampuan(KemampuanJam k) => KemampuanPerangkat(
    gulaDarah: k.gulaDarah,
    tekananDarah: k.tekananDarah,
    spo2: k.spo2,
  );

  @override
  Future<void> kirimKalibrasi(Kalibrasi kalibrasi) async {
    await _kirimPerintah(
      tulisSetKalibrasi(
        offsetSistolik: kalibrasi.offsetSistolik,
        offsetDiastolik: kalibrasi.offsetDiastolik,
      ),
    );
  }

  @override
  void dispose() {
    _dibuang = true;
    _reconnect?.cancel();
    for (final l in _langganan) {
      unawaited(l.cancel());
    }
    _langganan.clear();
    unawaited(_perangkat?.disconnect());
    _pengendaliStatus.close();
    _pengendaliTahap.close();
    _pengendaliSampel.close();
    _pengendaliT0.close();
    _pengendaliBalasan.close();
    _penantiUkur?.gagalkan(const GalatJam(PesanUkur.terputus));
    _jagaTampilanUkur?.cancel();
    _pengendaliKemajuan.close();
  }

  // --- Perintah ----------------------------------------------------------

  /// Menulis satu perintah dan menunggu `ACK`-nya.
  ///
  /// Balasan datang lewat karakteristik Peristiwa, bukan lewat write response
  /// (§5.1): beberapa perintah butuh waktu, dan write response hanya berarti
  /// "byte-nya sampai".
  ///
  /// Retry mengikuti tabel §7 apa adanya — `KodeGalatJam.bolehRetry` yang
  /// memutuskan, bukan berkas ini. Kode yang dilarang diulang memang tidak akan
  /// membaik dengan diulang: opcode tak dikenal adalah bug versi, baterai rendah
  /// adalah baterai rendah.
  Future<void> _kirimPerintah(Uint8List perintah) async {
    final opcode = perintah.first;

    for (var percobaan = 1; ; percobaan++) {
      // Langganan dipasang **sebelum** write, bukan sesudah: jam boleh menjawab
      // secepat apa pun, dan ACK yang datang sebelum kita mulai mendengarkan
      // akan hilang tanpa jejak — lalu perintahnya diulang tiga kali padahal
      // yang pertama sudah berhasil.
      final balasan = _pengendaliBalasan.stream
          .firstWhere(
            // ACK harus membawa opcode yang sama; NAK diterima apa adanya karena
            // ia membawa kode error di payload-nya, bukan opcode asal (§5.4).
            (e) =>
                (e.jenis == JenisPeristiwa.ack && e.payload == opcode) ||
                e.jenis == JenisPeristiwa.nak,
          )
          .timeout(
            ProtokolJam.timeoutTulis,
            onTimeout: () => throw TimeoutException(
              '${Opcode.nama(opcode)} tidak dijawab jam',
            ),
          );
      // Setiap jalur keluar di bawah **wajib** melewati `balasan`, termasuk yang
      // gagal. Future yang ditinggalkan akan menyelesaikan dirinya dengan
      // TimeoutException lima detik kemudian tanpa ada yang menangkapnya, dan
      // itu muncul sebagai galat tak tertangani yang sama sekali tidak
      // menyerupai penyebabnya.
      unawaited(balasan.catchError((_) => _balasanDibuang));

      // Bila write ini melempar (GATT error, koneksi putus), galatnya keluar
      // dari fungsi dan `balasan` ditinggalkan — yang aman justru karena
      // penangkap di atas sudah terpasang.
      await _tulisPerintah(perintah);

      try {
        final e = await balasan;
        if (e.jenis == JenisPeristiwa.ack) return;

        final kode = e.kodeGalat;
        if (kode == null || !kode.bolehRetry) {
          throw GalatJam(kode?.pesan ?? 'Jam menolak perintah.', kode: kode);
        }
        if (percobaan >= ProtokolJam.maksPercobaan) {
          throw GalatJam(kode.pesan, kode: kode);
        }

        // `boot_id` tidak cocok berarti jam menyala ulang di tengah perintah:
        // anchor lama sudah menunjuk garis waktu yang salah, jadi ia dipasang
        // ulang sebelum perintahnya diulang (§7 kode 0x09).
        if (kode == KodeGalatJam.bootIdTidakCocok) {
          await _perbaruiInfoDanAnchor();
        }
        await Future<void>.delayed(kode.jedaRetry);
      } on TimeoutException {
        debugPrint(
          '${Opcode.nama(opcode)} tidak dijawab jam '
          '(percobaan $percobaan/${ProtokolJam.maksPercobaan}). '
          'Firmware sudah mengirim ACK lewat karakteristik Peristiwa?',
        );
        if (percobaan >= ProtokolJam.maksPercobaan) rethrow;
      }
    }
  }

  /// Nilai buangan untuk `catchError` di atas — hanya ada supaya galatnya
  /// terhitung tertangani, tidak pernah dibaca siapa pun.
  static const EntriPeristiwa _balasanDibuang = EntriPeristiwa(
    seq: 0,
    jenis: JenisPeristiwa.nak,
    sesiId: null,
    bootId: 0,
    uptimeS: 0,
    dariBuffer: false,
    waktuTidakPasti: false,
    payload: 0,
  );

  /// Menulis satu perintah tanpa menunggu balasan apa pun.
  ///
  /// Dipakai langsung hanya oleh `ACK_EVENT`, yang memang tidak di-ack jam.
  Future<void> _tulisPerintah(Uint8List perintah) async {
    final kontrol = _kontrol;
    if (kontrol == null) throw const GalatJam('Jam tidak tersambung.');
    await kontrol.write(perintah, timeout: ProtokolJam.timeoutTulis.inSeconds);
  }

  Future<void> _perbaruiInfoDanAnchor() async {
    final perangkat = _perangkat;
    if (perangkat == null) return;
    for (final s in await perangkat.discoverServices()) {
      if (s.uuid.str.toLowerCase() != ProtokolJam.uuidLayanan) continue;
      for (final c in s.characteristics) {
        if (c.uuid.str.toLowerCase() != ProtokolJam.uuidInfo) continue;
        final info = bacaInfo(await c.read());
        info.periksaVersi();
        _info = info;
        // Jam yang menyala ulang bisa saja membawa firmware yang berbeda; baca
        // ulang kemampuannya di sini juga, jangan hanya di handshake pertama.
        _perbaruiStatus(_status.salin(kemampuan: _keKemampuan(info.kemampuan)));
        await _pasangAnchor(info.bootId);
      }
    }
  }

  /// Menulis `ANCHOR_WAKTU` lalu menyimpannya di sisi aplikasi.
  ///
  /// Disimpan **setelah** jam meng-ack: anchor yang tercatat di HP tetapi tidak
  /// pernah sampai ke jam akan menerjemahkan entri yang jamnya sendiri tandai
  /// `waktu_tidak_pasti`.
  Future<void> _pasangAnchor(int bootId) async {
    final sekarang = DateTime.now();
    await _kirimPerintah(tulisAnchorWaktu(epoch: sekarang, bootId: bootId));

    // `uptime_s` jam pada momen ini tidak dikirim balik; yang dipakai adalah
    // yang baru saja dibaca di handshake, ditambah selisih waktu HP sejak
    // membacanya. Untuk skala protokol ini (jadwal berjam-jam, §4.4) selisih
    // sepersekian detik tidak berarti apa-apa.
    final info = _info;
    final uptime = info == null
        ? 0
        : info.uptimeS + sekarang.difference(_waktuBacaInfo).inSeconds;

    final anchor = AnchorWaktu(
      bootId: bootId,
      uptimeS: uptime,
      epoch: sekarang,
    );
    await anchorRepo.simpan(anchor);
    _anchor[bootId] = anchor;
  }

  DateTime _waktuBacaInfo = DateTime.now();

  // --- Entri masuk -------------------------------------------------------

  Future<void> _terimaSampel(List<int> data) async {
    final EntriSampel entri;
    try {
      entri = bacaSampel(data);
    } on GalatProtokol catch (e) {
      await _buangPaketRusak(
        'sampel',
        data,
        e,
        panjangMinimum: ProtokolJam.panjangSampel,
      );
      return;
    }

    await _simpanLaluAck(entri);
    _emitSampel(entri);
  }

  /// Entri yang **tidak akan pernah bisa dibaca** — tetap di-ack lalu dibuang.
  ///
  /// Ini satu-satunya tempat aturan §6 ("ack hanya setelah tersimpan") sengaja
  /// dilanggar, dan alasannya justru aturan itu sendiri. Kegagalan decode bersifat
  /// tetap: byte yang sama akan gagal dibaca dengan cara yang sama selamanya.
  /// Menahan ack berarti jam menyimpannya seumur hidup, mengirimnya ulang pada
  /// setiap sinkronisasi, dan satu dari 64 slot buffer hilang permanen — sampai
  /// cukup banyak terkumpul dan entri yang **sah** mulai terbuang.
  ///
  /// Bedakan dari kegagalan **menyimpan** (basis data penuh, terkunci), yang
  /// bersifat sesaat dan karena itu tetap tidak boleh di-ack: entri itu masih
  /// punya harapan diproses pada percobaan berikutnya.
  ///
  /// Byte mentahnya dicatat sebelum dibuang. Setelah kejadiannya lewat, hanya itu
  /// buktinya (§9.2 rencana produksi).
  Future<void> _buangPaketRusak(
    String nama,
    List<int> data,
    GalatProtokol galat, {
    required int panjangMinimum,
  }) async {
    debugPrint('${galat.pesan} ${ringkasPaket(nama, data)}');
    if (data.isEmpty) return;

    // **Paket yang kependekan tidak dibuang.** Panjang paket bukan properti isi
    // paket, ia properti tautannya: paket sependek ini belum pernah benar-benar
    // dibaca, jadi tidak ada apa pun tentang isinya yang bisa disebut rusak.
    // Penyebabnya hampir selalu MTU yang terlalu kecil (lihat [_catatMtu]), dan
    // itu sembuh dengan sendirinya begitu tautannya benar — berbeda dari byte
    // yang memang cacat, yang akan gagal dibaca dengan cara yang sama selamanya.
    //
    // Karena itu justru **§6 yang ditegakkan di sini, bukan dilanggar**: tanpa
    // ack, jam menahan entrinya dan mengirimnya lagi pada sinkronisasi
    // berikutnya. Meng-ack-nya berarti jam menghapusnya dari ring buffer yang
    // 64 slot itu — satu-satunya salinan yang ada — dan sampelnya hilang di
    // kedua sisi tanpa satu pun galat muncul di layar. Gejalanya persis
    // sinkronisasi yang naik sampai 100% lalu tidak membawa apa-apa.
    if (data.length < panjangMinimum) {
      debugPrint(
        'Paket $nama hanya ${data.length} dari $panjangMinimum byte. Tidak '
        'di-ACK: entrinya ditinggal di buffer jam supaya bisa diambil lagi '
        'setelah MTU cukup.',
      );
      return;
    }

    // `seq` ada di offset 0 pada paket Sampel maupun Peristiwa, jadi ia tetap
    // terbaca meski sisa paketnya tidak.
    final seq = data.first;
    if (seq == 0) return; // bukan entri buffer (§6 aturan 1)

    try {
      await _tulisPerintah(tulisAckEvent(seq));
      // Entri rusak pun keluar dari buffer jam begitu di-ack, jadi angkanya
      // ikut turun. Ia hilang tanpa pernah menjadi sampel — itu memang yang
      // terjadi, dan menahannya di hitungan hanya membuat angka yang tidak
      // akan pernah turun.
      _kurangiTertunda();
    } catch (e) {
      debugPrint('ACK paket rusak seq $seq gagal: $e');
    }
  }

  Future<void> _terimaPeristiwa(List<int> data) async {
    final EntriPeristiwa entri;
    try {
      entri = bacaPeristiwa(data);
    } on GalatProtokol catch (e) {
      await _buangPaketRusak(
        'peristiwa',
        data,
        e,
        panjangMinimum: ProtokolJam.panjangPeristiwa,
      );
      return;
    }

    // ACK/NAK adalah percakapan, bukan riwayat: ia tidak masuk ring buffer di
    // jam dan tidak perlu disimpan di sini.
    if (entri.jenis == JenisPeristiwa.ack ||
        entri.jenis == JenisPeristiwa.nak) {
      if (!_pengendaliBalasan.isClosed) _pengendaliBalasan.add(entri);
      return;
    }

    await _simpanLaluAck(entri);
    await _tanganiPeristiwa(entri);
  }

  /// Urutan yang tidak boleh dibalik (§6): simpan dulu, baru ack.
  Future<void> _simpanLaluAck(EntriJam entri) async {
    try {
      await entriRepo.simpan(entri);
    } catch (e) {
      // Gagal menulis berarti **tidak** meng-ack. Entrinya tetap di buffer jam
      // dan akan dikirim lagi; kehilangan satu putaran jauh lebih ringan
      // daripada menyuruh jam melupakan data yang tidak pernah tersimpan.
      debugPrint('Gagal menyimpan entri seq ${entri.seq}: $e');
      return;
    }

    _seqTerakhir = entri.seq;
    try {
      // **Tanpa menunggu ACK.** `ACK_EVENT` adalah satu-satunya perintah yang
      // tidak di-ack jam (§5.1), dan itu bukan pengecualian yang malas: meng-ack
      // sebuah ack adalah regresi tak berujung, dan menunggunya menambah satu
      // perjalanan pulang-pergi untuk **setiap** entri yang masuk.
      //
      // Yang menggantikan jaminannya sudah ada: ack yang hilang di udara berarti
      // jam mengirim entrinya lagi, dan duplikat memang perilaku normal (§1
      // aturan 5). Dedup `(sesiId, index)` di controller yang menanganinya —
      // jangan menambahkan dedup kedua di sini.
      await _tulisPerintah(tulisAckEvent(entri.seq));
      _kurangiTertunda();
    } catch (e) {
      // Ack yang gagal ditulis berarti entrinya **masih** di buffer jam, jadi
      // angka tertundanya juga tidak boleh turun.
      debugPrint('ACK seq ${entri.seq} gagal: $e');
    }
  }

  /// Satu entri keluar dari buffer jam.
  ///
  /// `sampel_tertunda` (§5.5) berarti "entri yang belum di-ack", dan **aplikasi
  /// inilah yang meng-ack** — jadi aplikasi sudah tahu angkanya turun tanpa
  /// perlu diberitahu jam. Tanpa pengurangan ini angkanya hanya berubah saat
  /// paket Status berikutnya kebetulan datang, dan protokol tidak pernah
  /// menjanjikan jam mengirim satu setelah buffernya terkuras. Akibatnya "3
  /// sampel tertunda" tetap terpampang setelah ketiga sampelnya benar-benar
  /// masuk, tersimpan, dan tampil di layar sesi — persis keadaan yang membuat
  /// tombol Sinkronkan terlihat tidak bekerja.
  ///
  /// Paket Status tetap yang berkuasa: [_terimaStatus] menimpa angka ini apa
  /// adanya begitu jam mengabarkan yang sebenarnya. Yang di sini hanya menjaga
  /// layar tetap jujur di antara dua kabar itu.
  void _kurangiTertunda() {
    final tersisa = _status.sampelTertunda;
    if (tersisa <= 0) return;
    _perbaruiStatus(_status.salin(sampelTertunda: tersisa - 1));
  }

  Future<void> _tanganiPeristiwa(EntriPeristiwa entri) async {
    switch (entri.jenis) {
      case JenisPeristiwa.tombolSelesaiMakan:
        final sesiId = entri.sesiId;
        if (sesiId == null) return;
        _t0Sesi[sesiId] = (bootId: entri.bootId, uptimeS: entri.uptimeS);

        final waktu = await _keWaktu(entri);
        if (!_pengendaliT0.isClosed) {
          _pengendaliT0.add((
            sesiId: sesiId,
            t0: waktu.waktu,
            waktuTidakPasti: waktu.tidakPasti,
          ));
        }

      case JenisPeristiwa.boot:
        // Garis waktu baru: anchor lama tidak berlaku lagi, dan entri lama yang
        // masih di buffer membawa `boot_id`-nya sendiri (§6 aturan 7).
        await _perbaruiInfoDanAnchor();
        await sinkronkan();

      case JenisPeristiwa.bufferPenuh:
        debugPrint(
          'Buffer jam penuh — entri tertua dibuang sebelum sempat diterima.',
        );

      case JenisPeristiwa.sesiKedaluwarsa:
      case JenisPeristiwa.sesiDibatalkanJam:
      case JenisPeristiwa.ukurGagal:
        // Ketiganya berarti sampel yang ditunggu tidak akan datang. Sesi tidak
        // dibatalkan dari sini: ia berakhir lewat tenggatnya sendiri di
        // controller, dengan sampel yang sudah masuk tetap utuh.
        debugPrint(
          'Jam melaporkan ${entri.jenis.name} (payload ${entri.payload})',
        );
        // Kecuali satu: `UKUR_GAGAL` ber-`sesiId` nol adalah jawaban atas
        // `UKUR_SEKARANG` yang sedang ditunggu sebuah layar (§5.1). Membiarkan
        // penjaga waktunya yang menemukan berarti orang itu menatap layar
        // selama delapan detik lagi untuk kabar yang sudah tiba — dan dengan
        // kalimat yang salah, karena jamnya menjawab, bukan diam. Yang
        // ber-`sesiId` sungguhan adalah titik ukur sesi: bukan urusan penanti
        // ini, dan menghentikannya akan menjatuhkan pindai kesehatan yang
        // kebetulan berjalan bersamaan.
        if (entri.jenis == JenisPeristiwa.ukurGagal &&
            !sesiIdNyata(entri.sesiId)) {
          _gagalkanUkur(const GalatJam(PesanUkur.jamMenyerah));
        }

      case JenisPeristiwa.ack:
      case JenisPeristiwa.nak:
        break; // sudah ditangani sebelum sampai ke sini
    }
  }

  void _emitSampel(EntriSampel entri) {
    final t0 = _t0Sesi[entri.sesiId];

    // **Sampel dengan `boot_id` berbeda TIDAK dibuang** (§5.3, v1.3).
    //
    // Sampai v1.2 ia dibuang, dan alasannya masuk akal saat itu: jam yang
    // menyala ulang di tengah sesi telah kehilangan garis waktunya. v1.3
    // mencabutnya karena jam sekarang **dirancang** untuk dimatikan di antara
    // titik ukur — `boot_id` yang berbeda adalah keadaan normal, bukan gejala
    // kerusakan. Yang menentukan sampel ini milik siapa adalah `sesiId` dan
    // `index`, bukan garis waktu pencacahnya.
    //
    // Aturan lama itu membuang **setiap** titik setelah yang pertama, diam-diam,
    // dengan satu baris debugPrint sebagai satu-satunya jejak.
    final bootSama = t0 != null && t0.bootId == entri.bootId;

    // Selisih dua pencacah hanya sah di dalam satu boot. Di luar itu angkanya
    // tidak berarti apa-apa, dan **0 bukan tebakan melainkan penanda**:
    // `SesiMakanController._detikRelatifT0` menghitung ulang nilai yang benar
    // dari jam dindingnya sendiri untuk sampel yang tiba langsung, dan untuk
    // sampel dari buffer ia memakai nilai ini apa adanya — yang untuk lintas
    // boot berarti titik itu jatuh di slot jadwalnya. Itu penyederhanaan yang
    // diterima: yang menentukan posisi x sebuah titik adalah `index`-nya (§5.3),
    // dan menormalkannya ke slot persis yang dilakukan `_geser` sejak awal.
    //
    // Baseline tetap gratis di dalam satu boot: ia diukur sebelum tombol
    // ditekan, jadi selisihnya negatif dengan sendirinya.
    final detikRelatifT0 = bootSama ? entri.uptimeS - t0.uptimeS : 0;

    final sampel = Sampel(
      index: entri.index,
      detikRelatifT0: detikRelatifT0,
      status: StatusSampel.terisi,
      dariBuffer: entri.dariBuffer,
      gulaDarah: entri.gulaDarah,
      detakJantung: entri.detakJantung,
      sistolik: entri.sistolik,
      diastolik: entri.diastolik,
      spo2: entri.spo2,
    );

    if (!_pengendaliSampel.isClosed) {
      _pengendaliSampel.add((sesiId: entri.sesiId, sampel: sampel));
    }
  }

  void _terimaStatus(List<int> data) {
    final StatusJam s;
    try {
      s = bacaStatus(data);
    } on GalatProtokol catch (e) {
      debugPrint('${e.pesan} ${ringkasPaket('status', data)}');
      return;
    }

    _perbaruiStatus(
      _status.salin(
        tersambung: true,
        baterai: s.baterai,
        sampelTertunda: s.sampelTertunda,
        bateraiKritis: s.bateraiKritis,
      ),
    );

    _kabarkanUkur(s);
    _denyutUkur(s);
  }

  /// Menerjemahkan `uptime_s` sebuah entri menjadi waktu nyata (§4.2).
  ///
  /// `tidakPasti` true bila boot asal entri tidak punya anchor sama sekali — jam
  /// menandainya sendiri, dan aplikasi juga bisa menyimpulkannya dari anchor yang
  /// tidak ada. Keduanya digabung: cukup satu yang menyatakan tidak tahu.
  Future<({DateTime waktu, bool tidakPasti})> _keWaktu(EntriJam entri) async {
    final anchor = await _anchorUntuk(entri.bootId);
    if (anchor != null) {
      return (
        waktu: anchor.keWaktu(entri.uptimeS),
        tidakPasti: entri.waktuTidakPasti,
      );
    }

    // Tanpa anchor untuk boot itu, tidak ada di dunia ini yang tahu kapan
    // peristiwanya terjadi (§4.3). Waktu sekarang dipakai sebagai penempatan
    // sementara, dan `tidakPasti` yang memberitahu seluruh aplikasi untuk tidak
    // mempercayainya.
    return (waktu: DateTime.now(), tidakPasti: true);
  }

  Future<void> _putarUlangKotakMasuk() async {
    final List<EntriJam> tertunda;
    try {
      tertunda = await entriRepo.belumDiproses();
    } catch (e) {
      debugPrint('Kotak masuk tidak terbaca: $e');
      return;
    }
    if (tertunda.isEmpty) return;

    debugPrint('Memutar ulang ${tertunda.length} entri yang belum diproses.');
    for (final entri in tertunda) {
      switch (entri) {
        case EntriPeristiwa():
          // Anchor-nya sudah lama dipakai saat entri ini pertama datang, jadi
          // yang dimuat ulang di sini adalah t0-nya, bukan waktunya.
          final sesiId = entri.sesiId;
          if (entri.jenis == JenisPeristiwa.tombolSelesaiMakan &&
              sesiId != null) {
            _t0Sesi[sesiId] = (bootId: entri.bootId, uptimeS: entri.uptimeS);
            final waktu = await _keWaktu(entri);
            if (!_pengendaliT0.isClosed) {
              _pengendaliT0.add((
                sesiId: sesiId,
                t0: waktu.waktu,
                waktuTidakPasti: waktu.tidakPasti,
              ));
            }
          }
        case EntriSampel():
          _emitSampel(entri);
      }
    }
  }

  // --- Koneksi -----------------------------------------------------------

  void _tanganiPutus() {
    if (_dibuang) return;
    _kontrol = null;
    _statusKar = null;
    _perbaruiStatus(_status.salin(tersambung: false));

    // Penantian pengukuran diakhiri di sini, dengan sebabnya yang sudah pasti.
    // Tanpa ini ia hidup sampai penjaga denyutnya habis, lalu berkata "jam
    // berhenti mengabari" — benar secara harfiah, dan menyesatkan: yang perlu
    // dilakukan adalah mendekatkan jam, bukan merapatkan talinya.
    _gagalkanUkur(const GalatJam(PesanUkur.terputus));
    _jagaTampilanUkur?.cancel();
    _jagaTampilanUkur = null;
    if (!_pengendaliKemajuan.isClosed) {
      // Jam yang lepas tidak bisa lagi dikabarkan sedang mengukur: buktinya
      // sudah tidak ada, dan itu satu-satunya alasan kabar ini boleh terbit.
      _pengendaliKemajuan.add(KemajuanUkur.diam);
    }

    // Sesi yang sedang berjalan **tidak** dibatalkan: sampelnya menunggu di
    // buffer jam dan menyusul saat tersambung lagi (§6). Yang perlu dilakukan
    // hanya kembali.
    unawaited(
      perangkatRepo.muat().then((p) {
        if (p != null) _jadwalkanSambungUlang(p.id);
      }),
    );
  }

  void _jadwalkanSambungUlang(String idPerangkat) {
    if (_dibuang || _status.tersambung) return;
    _reconnect?.cancel();
    _reconnect = Timer(
      _backoff,
      () => unawaited(_sambungkanUlang(idPerangkat)),
    );

    // Backoff 1s → 2s → 4s → … → maks 60s (§8). Radio yang mencoba tiap detik
    // selama jam ditinggal di rumah adalah baterai yang habis sebelum sore.
    final berikutnya = _backoff * 2;
    _backoff = berikutnya > ProtokolJam.backoffMaks
        ? ProtokolJam.backoffMaks
        : berikutnya;
  }

  Future<void> _sambungkanUlang(String idPerangkat) async {
    if (_dibuang) return;

    // **Penyandingan tidak pernah dimulai dari latar belakang.**
    //
    // Kalau user menghapus jam dari Pengaturan Bluetooth sistem — atau jamnya
    // di-reset — bond-nya hilang sementara aplikasi masih mengingatnya.
    // Menyambung lagi pada keadaan itu akan memunculkan dialog penyandingan
    // sistem entah kapan saja: saat user sedang menelepon, sedang di aplikasi
    // lain, tanpa ia sedang memasang apa pun. Permintaan seperti itu mustahil
    // dimengerti, dan yang paling mungkin dilakukan user adalah menolaknya.
    //
    // Jadi lingkaran sambung ulang berhenti di sini dan menyerahkannya ke UI,
    // yang akan memintanya kembali lewat alur pemasangan yang punya
    // penjelasannya (docs/alur-pemasangan-jam.md §4.5).
    if (await _kehilanganPenyandingan(idPerangkat)) {
      _reconnect?.cancel();
      _reconnect = null;
      _perbaruiStatus(
        _status.salin(tersambung: false, penyandinganHilang: true),
      );
      return;
    }

    try {
      await _sambungkan(idPerangkat, simpanPasangan: false);
    } on GalatVersiJam catch (e) {
      // Versi mayor yang tidak cocok **tidak akan membaik dengan diulang**.
      // Firmware tidak berubah karena kita menyambung lagi, jadi mengulanginya
      // hanya menghasilkan lingkaran seumur hidup aplikasi: connect, baca
      // handshake, tolak, putus, ulangi — setiap menit, selamanya.
      //
      // Berhenti di sini, dan simpan alasannya supaya UI bisa mengatakannya.
      _galatTerakhir = e.pesanPengguna;
      debugPrint('Berhenti menyambung ulang: ${e.pesanPengguna}');
      await _putuskanDiam();
      _perbaruiStatus(_status.salin(tersambung: false));
    } on GalatJam catch (e) {
      // Sama: "bukan jam AsaWatch" dan "firmware tidak lengkap" adalah keadaan
      // tetap milik perangkat itu, bukan gangguan sesaat.
      _galatTerakhir = e.pesanPengguna;
      debugPrint('Berhenti menyambung ulang: ${e.pesanPengguna}');
      await _putuskanDiam();
      _perbaruiStatus(_status.salin(tersambung: false));
    } catch (e) {
      // Sisanya — di luar jangkauan, jam mati, radio sibuk — memang sesaat dan
      // memang layak diulang. Backoff-nya berhenti tumbuh di 60 detik (§8),
      // jadi satu percobaan per menit sampai jamnya kembali.
      debugPrint('Sambung ulang gagal: $e');
      _jadwalkanSambungUlang(idPerangkat);
    }
  }

  /// Dipanggil saat aplikasi kembali ke depan (`AppLifecycleState.resumed`).
  ///
  /// iOS tidak bisa menjaga proses hidup selama dua jam sesi, jadi buffer jam +
  /// panggilan ini adalah satu-satunya jalan sampel yang terkumpul selama itu
  /// masuk (rencana-produksi.md §7.1).
  Future<void> kembaliKeDepan() async {
    if (_status.tersambung) {
      await sinkronkan();
      return;
    }
    final tersimpan = await perangkatRepo.muat();
    if (tersimpan == null) return;
    _backoff = ProtokolJam.backoffAwal;
    await _sambungkanUlang(tersimpan.id);
  }

  Future<void> _putuskanDiam() async {
    for (final l in _langganan) {
      unawaited(l.cancel());
    }
    _langganan.clear();
    _kontrol = null;
    try {
      await _perangkat?.disconnect();
    } catch (e) {
      debugPrint('Gagal memutus: $e');
    }
  }

  void _pantau(StreamSubscription<dynamic> langganan) =>
      _langganan.add(langganan);

  void _perbaruiStatus(StatusPerangkat status) {
    _status = status;
    if (!_pengendaliStatus.isClosed) _pengendaliStatus.add(status);
  }
}

/// Satu penantian [BleAsliService.ukurSekarang] yang sedang berjalan.
///
/// Ada sebagai kelas, bukan sebagai kumpulan variabel lokal di dalam
/// `ukurSekarang`, karena tiga jalur di luar fungsi itu — paket Status,
/// `UKUR_GAGAL`, dan pemutusan tautan — harus bisa mengakhirinya. Ketiganya
/// tahu jawabannya jauh lebih awal daripada penjaga waktu mana pun, dan itulah
/// bedanya dengan satu `timeout()` yang menampung semua sebab dengan satu
/// kalimat.
class _PenantiUkur {
  final _selesai = Completer<Sampel>();

  StreamSubscription<({String sesiId, Sampel sampel})>? langganan;

  /// Penjaga yang disetel ulang setiap ada kabar baru dari jam.
  Timer? _jaga;

  /// Langit-langit yang **tidak pernah** disetel ulang.
  Timer? langit;

  /// Jam pernah melaporkan dirinya sedang mengukur. Membedakan "belum mulai"
  /// dari "sudah selesai tetapi hasilnya belum sampai" — dua keadaan yang
  /// sama-sama sunyi di stream Sampel.
  bool pernahMengukur = false;

  Future<Sampel> get masaDepan => _selesai.future;

  void aturJaga(Duration tenggat, String pesan) {
    _jaga?.cancel();
    _jaga = Timer(tenggat, () => gagalkan(GalatJam(pesan)));
  }

  /// Penjaga yang, saat habis, **memeriksa** alih-alih menggagalkan.
  ///
  /// [periksa] bertanggung jawab menyetel penjaga berikutnya (bila jamnya masih
  /// hidup) atau menggagalkan penantian ini. Ia dibungkus `catchError` karena
  /// ia berjalan dari sebuah timer: galat yang lolos dari sana tidak punya
  /// siapa pun yang menangkapnya dan muncul jauh dari sebabnya.
  void aturJagaPeriksa(Duration tenggat, Future<void> Function() periksa) {
    _jaga?.cancel();
    _jaga = Timer(tenggat, () {
      unawaited(
        periksa().catchError(
          (Object e) => gagalkan(const GalatJam(PesanUkur.denyutBerhenti)),
        ),
      );
    });
  }

  void selesaikan(Sampel sampel) {
    if (_selesai.isCompleted) return;
    _selesai.complete(sampel);
  }

  void gagalkan(GalatJam galat) {
    if (_selesai.isCompleted) return;
    _selesai.completeError(galat);
  }

  void bersihkan() {
    _jaga?.cancel();
    langit?.cancel();
    unawaited(langganan?.cancel());
  }
}
