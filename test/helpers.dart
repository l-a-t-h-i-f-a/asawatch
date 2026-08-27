// Alat bantu bersama untuk seluruh widget test.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:asawatch/controllers/sesi_makan_controller.dart';
import 'package:asawatch/models/jadwal_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/repositories/entri_jam_repository.dart';
import 'package:asawatch/repositories/kalibrasi_repository.dart';
import 'package:asawatch/repositories/sesi_repository.dart';
import 'package:asawatch/repositories/sesi_login_repository.dart';
import 'package:asawatch/services/ble_service.dart';
import 'package:asawatch/services/sesi_server_service.dart';
import 'package:asawatch/services/nutrisi_service.dart';
import 'package:asawatch/services/pengingat_titik_ukur.dart';

/// Registers the bundled Montserrat faces with the test binding.
///
/// Without this the test harness substitutes its own fixed-width fallback font,
/// whose glyphs are far wider than Montserrat's, and the phone-width layouts
/// report spurious RenderFlex overflows.
Future<void> loadMontserrat() async {
  const faces = [
    'assets/fonts/Montserrat-Regular.ttf',
    'assets/fonts/Montserrat-Medium.ttf',
    'assets/fonts/Montserrat-SemiBold.ttf',
    'assets/fonts/Montserrat-Bold.ttf',
  ];

  final loader = FontLoader('Montserrat');
  for (final path in faces) {
    final bytes = await File(path).readAsBytes();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
}

/// Jam dinding palsu yang bergerak hanya bila disuruh.
///
/// `tester.pump(Duration)` memajukan timer tetapi **tidak** memajukan
/// `DateTime.now()`. Sejak protokol v1.3 menaruh jadwal titik ukur di sisi
/// aplikasi, jam dinding ikut menjadi bahan perhitungan — jendela toleransi,
/// hitung mundur, dan penundaan `ARM_TITIK` semuanya membacanya. Tanpa jam yang
/// bisa dimajukan bersama `pump`, tidak satu pun dari ketiganya bisa diuji.
class JamPalsu {
  /// Bermula dari waktu **sungguhan**, bukan tanggal tetap.
  ///
  /// `FakeBleService` menstempel `t0`-nya dengan `DateTime.now()` yang asli, dan
  /// jam palsu yang bermula di tanggal lain akan membuat selisih keduanya
  /// terhitung berbulan-bulan — sesi tertutup oleh tenggatnya sendiri sebelum
  /// test sempat menyentuh apa pun.
  JamPalsu([DateTime? mulai]) : _sekarang = mulai ?? DateTime.now();

  DateTime _sekarang;

  DateTime call() => _sekarang;

  void maju(Duration d) => _sekarang = _sekarang.add(d);
}

/// Memajukan jam palsu **dan** timer sekaligus, supaya keduanya tidak pernah
/// berselisih di tengah test.
Future<void> majuBersama(
  WidgetTester tester,
  JamPalsu jam,
  Duration d,
) async {
  jam.maju(d);
  await tester.pump(d);
}

/// Sets the phone-sized surface the layouts assume (412x915). The 800x600
/// test default is not what these pages are designed for.
void pakaiLayarPonsel(WidgetTester tester) {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

/// Controller sesi untuk test, memakai jam palsu yang dipercepat (§11).
///
/// [percepatan] 3600 membuat jeda 1 jam menjadi 1 detik waktu test, sehingga
/// sesi berjalan sampai selesai bisa dipompa secara deterministik. [lewatkan]
/// mensimulasikan sampel yang tidak pernah datang.
/// Tombol "Selesai Makan" di jam tidak pernah ditekan sendiri di test
/// (`otomatisSelesaiMakan: null`) — pemicunya selalu eksplisit lewat
/// [tekanTombolJam], supaya waktunya deterministik.
SesiMakanController buatControllerUji({
  int percepatan = 3600,
  Set<int> lewatkan = const {},
  List<SesiMakan> riwayatAwal = const [],
  StatusPerangkat? status,
  FakeBleService? ble,
  NutrisiService? nutrisi,
  SesiRepository? repo,
  KalibrasiRepository? repoKalibrasi,
  EntriJamRepository? repoEntri,
  Kalibrasi? kalibrasiAwal,
  JadwalSesi? jadwal,
  DateTime Function()? jam,
  PengingatTitikUkur? pengingat,
  Future<String> Function(String nama)? jalurFoto,
  SesiServerService? serverSesi,
  SesiLoginRepository? sesiLogin,
}) {
  return SesiMakanController(
    ble:
        ble ??
        FakeBleService(
          percepatan: percepatan,
          lewatkan: lewatkan,
          status: status,
          otomatisSelesaiMakan: null,
        ),
    nutrisi: nutrisi ?? const FakeNutrisiService(jeda: Duration.zero),
    riwayatAwal: riwayatAwal,
    // Dibiarkan null kecuali test memang menguji penyimpanannya: sesi yang
    // selesai cukup hidup di memori controller seperti sebelumnya.
    repo: repo,
    repoKalibrasi: repoKalibrasi,
    repoEntri: repoEntri,
    kalibrasiAwal: kalibrasiAwal,
    serverSesi: serverSesi,
    sesiLogin: sesiLogin,
    // Jadwal ikut dimampatkan dengan faktor yang sama seperti jam palsunya.
    //
    // Ini bukan kenyamanan melainkan syarat kebenaran sejak protokol v1.3.
    // `detikRelatifT0` kini diturunkan dari jam dinding (§5.3), sedangkan
    // `percepatan` memampatkan jadwal jam palsu tanpa memampatkan jam dinding.
    // Membiarkan keduanya berbeda berarti sampel "+1 jam" yang tiba satu detik
    // setelah t0 tercatat pada detik ke-1 dan ditandai telat — test yang
    // mensimulasikan hal yang tidak mungkin terjadi di dunia nyata.
    jadwal: jadwal ?? jadwalNormal.dibagi(percepatan),
    jam: jam,
    pengingat: pengingat,
    jalurFoto: jalurFoto,
  );
}

/// Menekan tombol "Selesai Makan" **di jam** — satu-satunya jalan sebuah sesi
/// mendapatkan t0 (§6). Aplikasi tidak punya aksi yang setara.
Future<void> tekanTombolJam(
  WidgetTester tester,
  SesiMakanController c, {
  DateTime? waktu,
}) async {
  (c.ble as FakeBleService).tekanSelesaiMakan(waktu: waktu);
  await tester.pump(); // pesan t0 dari jam sampai ke controller
}

/// Menutup sesi yang masih berjalan di akhir test.
///
/// `flutter_test` memeriksa timer yang menggantung sebelum tearDown sempat
/// jalan, jadi sesi yang belum kelar harus dibereskan di dalam badan test.
/// `batalkan()` sekaligus membatalkan jadwal sampel di jam palsu.
Future<void> hentikanSesi(WidgetTester tester, SesiMakanController c) async {
  await c.batalkan();
  await tester.pump();
}

/// Pumps a single page inside the app's real theme, on a phone-sized surface.
///
/// Selalu menyediakan [SesiMakanController] karena permukaan sesi makan
/// membacanya lewat provider (§12.7).
///
/// Does not settle: pages with a running countdown keep scheduling frames, so
/// callers decide between `pump()` and `pumpAndSettle()`.
Future<void> pumpHalaman(
  WidgetTester tester,
  Widget halaman, {
  SesiMakanController? controller,
}) async {
  pakaiLayarPonsel(tester);

  final c = controller ?? buatControllerUji();
  addTearDown(c.dispose);

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF0EAD69),
            primary: const Color(0xFF0EAD69),
            secondary: const Color(0xFF7BE5C4),
          ),
          fontFamily: 'Montserrat',
          useMaterial3: true,
        ),
        home: halaman,
      ),
    ),
  );
  await tester.pump();
}
