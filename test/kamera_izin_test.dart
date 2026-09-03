// Dialog izin kamera dan daur hidup halaman.
//
// Bug yang ditemukan di perangkat: pada pemasangan baru, sesudah pengguna
// menekan "Izinkan", halaman tetap menampilkan "Kamera tidak bisa dibuka".
// Sebabnya balapan waktu — dialog izin membuat aplikasi berpindah ke `inactive`
// (kamera dilepas) lalu `resumed` (kamera disiapkan lagi) selagi penyiapan
// pertama masih menggantung, dan kegagalan penyiapan pertama tiba **setelah**
// keberhasilan yang kedua.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/deteksi_makanan_page.dart';
import 'package:asawatch/services/kamera_service.dart';

import 'helpers.dart';

/// Kamera yang penyiapannya bisa dikendalikan satu per satu.
class _KameraBertahap implements KameraService {
  final List<Completer<void>> percobaan = [];
  bool _siap = false;

  @override
  Future<void> siapkan() {
    final c = Completer<void>();
    percobaan.add(c);
    return c.future.then((_) => _siap = true);
  }

  @override
  Future<void> lepas() async => _siap = false;

  @override
  bool get siap => _siap;

  @override
  bool get punyaLampu => true;

  @override
  bool get lampuMenyala => false;

  @override
  Future<void> gantiLampu() async {}

  @override
  Widget pratinjau() => const ColoredBox(color: Colors.black);

  @override
  Future<String> ambilFoto() async => '/tmp/foto.jpg';

  @override
  Future<String?> pilihDariGaleri() async => null;
}

void main() {
  setUpAll(loadMontserrat);

  testWidgets('izin yang baru disetujui tidak berakhir di layar galat', (
    tester,
  ) async {
    final kamera = _KameraBertahap();
    final c = buatControllerUji();
    await pumpHalaman(
      tester,
      DeteksiMakananPage(kamera: kamera),
      controller: c,
    );

    expect(kamera.percobaan, hasLength(1));

    // Dialog izin sistem muncul di atas aplikasi: halaman berpindah ke
    // inactive, lalu kembali setelah pengguna menekan "Izinkan".
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    expect(kamera.percobaan, hasLength(2));

    // Percobaan kedua berhasil — izinnya sudah ada.
    kamera.percobaan[1].complete();
    await tester.pump();

    // Percobaan pertama baru gagal sesudahnya, karena kameranya dilepas saat
    // aplikasi berpindah ke latar. Kegagalan yang sudah kedaluwarsa itu tidak
    // boleh menyentuh layar.
    kamera.percobaan[0].completeError(
      const GalatKamera('Kamera dilepas saat aplikasi ke latar belakang.'),
    );
    await tester.pump();

    expect(find.text('Kamera tidak bisa dibuka'), findsNothing);
    // Rana kembali tersedia: kameranya memang hidup.
    expect(find.byIcon(Icons.photo_camera_rounded), findsOneWidget);
  });

  testWidgets('kegagalan penyiapan terakhir tetap tampil apa adanya', (
    tester,
  ) async {
    final kamera = _KameraBertahap();
    final c = buatControllerUji();
    await pumpHalaman(
      tester,
      DeteksiMakananPage(kamera: kamera),
      controller: c,
    );

    kamera.percobaan.single.completeError(
      const GalatKamera('Perangkat ini tidak punya kamera.'),
    );
    await tester.pump();

    // Penjaga generasi tidak boleh sampai menelan kegagalan yang sungguhan.
    expect(find.text('Kamera tidak bisa dibuka'), findsOneWidget);
    expect(find.text('Coba Lagi'), findsOneWidget);
  });
}
