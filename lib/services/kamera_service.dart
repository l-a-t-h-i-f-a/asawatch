import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:image_picker/image_picker.dart';
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
class GalatKamera implements Exception {
  const GalatKamera(this.pesan, {this.izinDitolak = false});

  final String pesan;
  final bool izinDitolak;

  @override
  String toString() => 'GalatKamera: $pesan';
}

/// Kamera sungguhan di atas paket `camera`.
class KameraAsliService implements KameraService {
  CameraController? _kendali;
  final _pemilih = ImagePicker();
  bool _lampu = false;

  @override
  bool get siap => _kendali?.value.isInitialized ?? false;

  @override
  bool get punyaLampu =>
      _kendali?.description.lensDirection == CameraLensDirection.back;

  @override
  bool get lampuMenyala => _lampu;

  @override
  Future<void> siapkan() async {
    if (siap) return;
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
  Future<void> lepas() async {
    final kendali = _kendali;
    _kendali = null;
    await kendali?.dispose();
  }

  @override
  Widget pratinjau() => CameraPreview(_kendali!);

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

/// Menyalin [berkas] ke folder dokumen aplikasi dan mengembalikan jalurnya.
Future<String> _simpanTetap(XFile berkas) async {
  final dokumen = await getApplicationDocumentsDirectory();
  final folder = Directory('${dokumen.path}/foto_makanan');
  if (!folder.existsSync()) folder.createSync(recursive: true);
  final nama = 'makan_${DateTime.now().millisecondsSinceEpoch}.jpg';
  final tujuan = '${folder.path}/$nama';
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
