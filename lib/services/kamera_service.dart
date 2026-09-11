import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';

import '../models/contoh_sesi.dart';

/// Kontrak kamera deteksi makanan — satu-satunya bagian alur foto yang menuntut
/// perangkat keras, dan karena itu satu-satunya yang perlu seam.
///
/// Perannya sama persis dengan `BleService`: yang sungguhan
/// ([KameraAsliService]) dipakai aplikasi, yang palsu ([KameraPalsuService])
/// adalah tulang punggung test — `flutter_test` tidak punya kanal platform
/// untuk `camera`, jadi tanpa yang palsu tidak satu pun test halaman deteksi
/// bisa menekan rana.
///
/// Yang **tidak** ada di sini: analisis gizinya. Foto sudah sungguhan, angka
/// nutrisinya masih dari `FakeNutrisiService` — dua ketiadaan yang berbeda dan
/// sengaja tidak digabung.
abstract class KameraService {
  /// Menyalakan kamera belakang. Melempar [GalatKamera] bila gagal.
  Future<void> siapkan();

  /// Apakah dialog izin sistem sedang terbuka menunggu jawaban.
  ///
  /// Halaman perlu tahu ini karena dialog izin **juga** memindahkan aplikasi ke
  /// `inactive`, persis seperti masuk latar belakang — padahal aplikasinya
  /// masih di depan mata, kameranya belum sempat dibuka, dan yang ditunggu
  /// justru jawaban dialog itu. Halaman yang memperlakukannya sebagai masuk
  /// latar belakang akan membuang jawabannya sendiri dan bertanya lagi, yang
  /// dari sisi pengguna adalah dialog yang muncul terus tanpa ujung.
  bool get sedangMintaIzin;

  /// Melepas kamera. Wajib dipanggil saat halaman ditutup **dan** saat aplikasi
  /// masuk latar belakang: Android mencabut paksa kamera dari aplikasi yang
  /// tidak terlihat, dan pratinjau yang tidak dilepas kembali sebagai layar
  /// hitam.
  Future<void> lepas();

  bool get siap;

  /// Apakah kamera ini punya lampu kilat. Kamera depan dan sebagian emulator
  /// tidak punya, dan tombol yang tidak melakukan apa-apa lebih buruk daripada
  /// tombol yang tidak ada.
  bool get punyaLampu;

  bool get lampuMenyala;

  Future<void> gantiLampu();

  /// Pratinjau langsung. Hanya boleh dipanggil bila [siap].
  Widget pratinjau();

  /// Mengambil foto dan mengembalikan **jalur file tetap**, bukan jalur
  /// sementara: foto ini dirujuk sesi selamanya di Riwayat, sedangkan folder
  /// cache tempat `camera` menaruh hasilnya boleh dihapus sistem kapan saja.
  Future<String> ambilFoto();

  /// Mengambil foto yang sudah ada dari galeri. Mengembalikan null bila
  /// pengguna membatalkan.
  Future<String?> pilihDariGaleri();
}

/// Kegagalan kamera yang sudah diterjemahkan menjadi kalimat untuk pengguna.
///
/// [izinDitolak] dipisahkan karena hanya kasus itu yang jalan keluarnya bukan
/// "coba lagi" melainkan membuka pengaturan aplikasi.
///
/// [karenaIzin] lebih luas: ia menandai **setiap** kegagalan yang sebabnya
/// izin, termasuk penolakan sekali yang masih bisa ditanyakan lagi. Halaman
/// memakainya untuk satu keputusan yang tidak bisa diambil dari [izinDitolak]:
/// sesudah kegagalan izin, kembalinya aplikasi ke layar **tidak** boleh
/// memunculkan dialog izin lagi dengan sendirinya. Setiap kegagalan izin yang
/// permanen tentu juga kegagalan karena izin, jadi bawaannya mengikuti
/// [izinDitolak].
class GalatKamera implements Exception {
  const GalatKamera(this.pesan, {this.izinDitolak = false, bool? karenaIzin})
    : karenaIzin = karenaIzin ?? izinDitolak;

  final String pesan;
  final bool izinDitolak;
  final bool karenaIzin;

  @override
  String toString() => 'GalatKamera: $pesan';
}

/// Kamera sungguhan di atas paket `camera`.
class KameraAsliService implements KameraService {
  CameraController? _kendali;
  final _pemilih = ImagePicker();
  bool _lampu = false;

  /// Antrean satu jalur untuk **semua** operasi yang menyentuh kamera.
  ///
  /// Pada pemasangan baru urutannya seperti ini: halaman membuka kamera →
  /// dialog izin muncul → halaman berpindah ke latar dan melepas kamera →
  /// pengguna menekan "Izinkan" → halaman kembali dan membuka kamera lagi.
  /// Ketiga operasi itu berangkat sebelum yang sebelumnya selesai.
  ///
  /// Yang terjadi tanpa antrean ini, dan ketiganya sudah terlihat di perangkat:
  /// dua `CameraController` berebut satu kamera; dua permintaan izin
  /// berbarengan, yang oleh `permission_handler` dijawab "ditolak" untuk yang
  /// belakangan; dan pelepasan yang menyelesaikan tugasnya **sesudah**
  /// pembukaan berikutnya, sehingga yang tersisa di layar adalah pratinjau dari
  /// kamera yang sudah ditutup. Semuanya berakhir sama: "Kamera tidak bisa
  /// dibuka" pada perangkat yang izinnya baru saja diberikan.
  ///
  /// Antrean menjamin urutannya persis seperti yang diminta halaman, satu per
  /// satu, tanpa halaman perlu tahu apa pun tentang itu.
  Future<void> _antrean = Future<void>.value();

  Future<void> _giliran(Future<void> Function() aksi) {
    // Galat satu operasi tidak boleh menghentikan antreannya: kamera yang gagal
    // dibuka sekali harus tetap bisa dilepas dan dibuka lagi.
    final berikutnya = _antrean.then((_) => aksi(), onError: (_) => aksi());
    _antrean = berikutnya.catchError((_) {});
    return berikutnya;
  }

  bool _mintaIzin = false;

  @override
  bool get sedangMintaIzin => _mintaIzin;

  @override
  bool get siap => _kendali?.value.isInitialized ?? false;

  @override
  bool get punyaLampu =>
      _kendali?.description.lensDirection == CameraLensDirection.back;

  @override
  bool get lampuMenyala => _lampu;

  @override
  Future<void> siapkan() => _giliran(_siapkanSekali);

  Future<void> _siapkanSekali() async {
    // Diperiksa **di dalam** antrean, bukan sebelum masuk: keadaan kamera bisa
    // berubah selagi menunggu giliran.
    if (siap) return;

    // **Izin diminta di sini, bukan dibiarkan dipicu oleh `initialize()`.**
    //
    // Kalau dibiarkan, dialog sistem muncul di tengah-tengah inisialisasi:
    // aplikasi berpindah ke `inactive`, kamera dilepas oleh penanganan daur
    // hidup, dan `initialize()` yang masih menggantung itu gagal — sesudah
    // pengguna menekan "Izinkan". Yang tersisa di layar adalah pesan "kamera
    // tidak bisa dibuka" pada perangkat yang izinnya baru saja diberikan.
    //
    // Dengan urutan ini, saat `initialize()` dipanggil izinnya sudah pasti ada,
    // dan tidak ada dialog yang bisa menyela.
    _mintaIzin = true;
    final PermissionStatus izin;
    try {
      izin = await Permission.camera.request();
    } finally {
      _mintaIzin = false;
    }
    if (!izin.isGranted) {
      throw GalatKamera(
        izin.isPermanentlyDenied
            ? 'AsaWatch belum diizinkan memakai kamera. Buka Pengaturan '
                  'aplikasi, lalu nyalakan izin Kamera.'
            : 'AsaWatch perlu izin kamera untuk memotret makanan Anda.',
        // Hanya yang permanen yang butuh Pengaturan; yang baru ditolak sekali
        // masih bisa ditanya lagi oleh tombol "Coba Lagi" — tetapi hanya oleh
        // tombol itu, tidak oleh aplikasi yang sekadar kembali ke layar.
        izinDitolak: izin.isPermanentlyDenied,
        karenaIzin: true,
      );
    }

    try {
      final daftar = await availableCameras();
      if (daftar.isEmpty) {
        throw const GalatKamera('Perangkat ini tidak punya kamera.');
      }
      // Kamera belakang; kalau tidak ada, apa pun yang ada — sebuah tablet
      // berkamera depan saja masih bisa memotret piring.
      final pilihan = daftar.firstWhere(
        (k) => k.lensDirection == CameraLensDirection.back,
        orElse: () => daftar.first,
      );
      final kendali = CameraController(
        pilihan,
        // Cukup untuk melihat isi piring, dan jauh lebih ringan daripada
        // resolusi penuh: fotonya disimpan permanen di ponsel pengguna.
        ResolutionPreset.high,
        enableAudio: false,
      );
      await kendali.initialize();
      await kendali.setFlashMode(FlashMode.off);
      _kendali = kendali;
      _lampu = false;
    } on CameraException catch (e) {
      await lepas();
      throw _terjemahkan(e);
    }
  }

  @override
  Future<void> lepas() => _giliran(() async {
    final kendali = _kendali;
    _kendali = null;
    _lampu = false;
    await kendali?.dispose();
  });

  @override
  Widget pratinjau() {
    final kendali = _kendali!;
    return Center(
      child: Builder(
        builder: (context) => AspectRatio(
          aspectRatio: rasioPratinjau(
            kendali.value.previewSize,
            MediaQuery.orientationOf(context),
          ),
          child: CameraPreview(kendali),
        ),
      ),
    );
  }

  @override
  Future<void> gantiLampu() async {
    final kendali = _kendali;
    if (kendali == null || !punyaLampu) return;
    final nyala = !_lampu;
    try {
      await kendali.setFlashMode(nyala ? FlashMode.torch : FlashMode.off);
      _lampu = nyala;
    } on CameraException {
      // Lampu yang menolak menyala bukan alasan menggagalkan pemotretan.
      _lampu = false;
    }
  }

  @override
  Future<String> ambilFoto() async {
    final kendali = _kendali;
    if (kendali == null || !siap) {
      throw const GalatKamera('Kamera belum siap.');
    }
    try {
      final berkas = await kendali.takePicture();
      return _simpanTetap(berkas);
    } on CameraException catch (e) {
      throw _terjemahkan(e);
    }
  }

  @override
  Future<String?> pilihDariGaleri() async {
    try {
      final berkas = await _pemilih.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1600,
      );
      if (berkas == null) return null;
      return _simpanTetap(berkas);
    } on PlatformException catch (e) {
      throw GalatKamera(
        'Galeri tidak bisa dibuka (${e.code}).',
        izinDitolak: e.code == 'photo_access_denied',
      );
    }
  }

  GalatKamera _terjemahkan(CameraException e) {
    return switch (e.code) {
      'CameraAccessDenied' ||
      'CameraAccessDeniedWithoutPrompt' ||
      'CameraAccessRestricted' => const GalatKamera(
        'AsaWatch belum diizinkan memakai kamera. Buka Pengaturan aplikasi, '
        'lalu nyalakan izin Kamera.',
        izinDitolak: true,
      ),
      _ => GalatKamera('Kamera tidak bisa dibuka (${e.code}).'),
    };
  }
}

/// Jalur tetap untuk sebuah berkas foto, foldernya dibuat bila belum ada.
///
/// Publik karena dua pihak menaruh foto di folder yang sama: rana kamera, dan
/// unduhan riwayat dari server (`SesiMakanController.unduhRiwayatDariServer`).
/// Dua folder yang harus dijaga sebanding pada akhirnya akan berselisih, dan
/// `hapusDataLokal` hanya membersihkan satu di antaranya.
Future<String> jalurFotoTetap(String nama) async {
  final dokumen = await getApplicationDocumentsDirectory();
  final folder = Directory('${dokumen.path}/foto_makanan');
  if (!folder.existsSync()) folder.createSync(recursive: true);
  return '${folder.path}/$nama';
}

/// Rasio lebar/tinggi yang benar untuk menggambar pratinjau.
///
/// **Tanpa ini pratinjaunya gepeng.** `CameraPreview` menggambar apa pun yang
/// diberikan induknya; kalau induknya seluruh layar (rasio ~9:19,5) sementara
/// sensornya 4:3 atau 16:9, gambarnya diregangkan — wajah memanjang, piring
/// jadi lonjong. Yang direkam tidak ikut gepeng, karena itu berasal dari sensor
/// dan bukan dari yang tampil, sehingga cacatnya hanya terlihat saat membidik.
///
/// [previewSize] selalu dilaporkan dalam orientasi **lanskap** oleh paket
/// `camera`, apa pun posisi ponselnya — itulah sumber kekeliruan yang lazim.
/// Jadi pada layar potret, kedua sisinya harus ditukar.
///
/// Ukuran yang belum diketahui (null, sebelum inisialisasi selesai) jatuh ke
/// 3:4 potret — rasio kamera ponsel yang paling umum, dan hanya terpakai
/// beberapa frame.
double rasioPratinjau(Size? previewSize, Orientation orientasi) {
  if (previewSize == null || previewSize.shortestSide <= 0) {
    return orientasi == Orientation.portrait ? 3 / 4 : 4 / 3;
  }
  final panjang = previewSize.longestSide;
  final pendek = previewSize.shortestSide;
  return orientasi == Orientation.portrait
      ? pendek / panjang
      : panjang / pendek;
}

/// Menyalin [berkas] ke folder dokumen aplikasi dan mengembalikan jalurnya.
Future<String> _simpanTetap(XFile berkas) async {
  final tujuan = await jalurFotoTetap(
    'makan_${DateTime.now().millisecondsSinceEpoch}.jpg',
  );
  await berkas.saveTo(tujuan);
  return tujuan;
}

/// Kamera palsu: pratinjaunya sebuah kotak, dan fotonya jalur contoh.
///
/// Dipakai test dan demo di perangkat tanpa kamera. Tidak pernah dihapus,
/// dengan alasan yang sama seperti `FakeBleService`.
class KameraPalsuService implements KameraService {
  KameraPalsuService({this.jalurFoto = contohFotoPath, this.galat});

  final String jalurFoto;

  /// Kegagalan yang dipesan di muka — satu-satunya cara mencapai layar galat,
  /// karena kamera sungguhan tidak bisa disuruh gagal.
  final GalatKamera? galat;

  bool _siap = false;
  bool _lampu = false;

  @override
  bool get siap => _siap;

  @override
  bool get sedangMintaIzin => false;

  @override
  bool get punyaLampu => true;

  @override
  bool get lampuMenyala => _lampu;

  @override
  Future<void> siapkan() async {
    if (galat != null) throw galat!;
    _siap = true;
  }

  @override
  Future<void> lepas() async => _siap = false;

  @override
  Future<void> gantiLampu() async => _lampu = !_lampu;

  @override
  Widget pratinjau() => const ColoredBox(
    color: Color(0xFF1E3A34),
    child: Center(
      child: Icon(Icons.restaurant_menu, color: Colors.white, size: 80),
    ),
  );

  @override
  Future<String> ambilFoto() async => jalurFoto;

  @override
  Future<String?> pilihDariGaleri() async => jalurFoto;
}
