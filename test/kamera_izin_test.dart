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
  _KameraBertahap({this.mintaIzin = false});

  /// Penyiapan berikutnya menggantung pada dialog izin, seperti kamera
  /// sungguhan yang meminta izin sebelum `initialize()`.
  bool mintaIzin;

  final List<Completer<void>> percobaan = [];
  bool _siap = false;

  @override
  bool get sedangMintaIzin => mintaIzin && percobaan.any((c) => !c.isCompleted);

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

  testWidgets('izin yang ditolak dijawab layar galat, bukan pemintal', (
    tester,
  ) async {
    final kamera = _KameraBertahap(mintaIzin: true);
    final c = buatControllerUji();
    await pumpHalaman(
      tester,
      DeteksiMakananPage(kamera: kamera),
      controller: c,
    );

    // Dialog izin memindahkan aplikasi ke `inactive` persis seperti masuk latar
    // belakang. Percobaan yang sedang menunggu jawabannya tidak boleh
    // dibatalkan karenanya.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(kamera.percobaan, hasLength(1));

    // Pengguna menekan "Tolak".
    kamera.mintaIzin = false;
    kamera.percobaan.single.completeError(
      const GalatKamera(
        'AsaWatch perlu izin kamera untuk memotret makanan Anda.',
        karenaIzin: true,
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();

    // Jawabannya sampai ke layar — bukan pemintal yang berputar terus.
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Kamera tidak bisa dibuka'), findsOneWidget);
    expect(
      find.text('AsaWatch perlu izin kamera untuk memotret makanan Anda.'),
      findsOneWidget,
    );

    // Dan kembalinya aplikasi ke layar tidak memunculkan dialog itu lagi:
    // hanya tombol "Coba Lagi" yang bertanya ulang.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(kamera.percobaan, hasLength(1));

    await tester.tap(find.text('Coba Lagi'));
    await tester.pump();
    expect(kamera.percobaan, hasLength(2));
  });

  testWidgets('percobaan yang dibatalkan latar belakang tidak meninggalkan '
      'pemintal abadi', (tester) async {
    final kamera = _KameraBertahap();
    final c = buatControllerUji();
    await pumpHalaman(
      tester,
      DeteksiMakananPage(kamera: kamera),
      controller: c,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Aplikasi benar-benar masuk latar belakang selagi kamera dibuka, lalu
    // percobaan itu gagal karena kameranya dicabut — dan tidak ada yang
    // kembali ke layar sesudahnya.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    kamera.percobaan.single.completeError(
      const GalatKamera('Kamera dilepas saat aplikasi ke latar belakang.'),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsNothing);

    // Kembali ke layar: penyiapan dimulai lagi, sekali.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(kamera.percobaan, hasLength(2));
  });
}
