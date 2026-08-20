// Beranda punya tiga wajah sesuai status sesi (§4.1). Test ini mengunci
// ketiganya sekaligus memastikan dashboard vital "sekarang" benar-benar hilang
// (§7).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/beranda_tab.dart';
import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/widgets/timeline_sampel.dart';
import 'package:asawatch/widgets/tombol_sinkron.dart';

import 'helpers.dart';

// BerandaTab tidak punya Scaffold sendiri — di aplikasi ia hidup di dalam
// Scaffold milik MyHomePage. Dipompa telanjang, teksnya kehilangan fontFamily
// tema (DefaultTextStyle di luar Material tidak membawanya) dan layout phone
// melaporkan overflow palsu. Karena itu setiap test di sini membungkusnya.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadMontserrat);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Wajah A — idle', () {
    testWidgets('menampilkan ringkasan hari ini, sesi terakhir, dan puncak', (
      tester,
    ) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHalaman(tester, const Scaffold(body: BerandaTab()), controller: c);
      await tester.pumpAndSettle();

      expect(find.text('Ringkasan Hari Ini'), findsOneWidget);
      expect(find.text('Sesi Terakhir'), findsOneWidget);
      expect(find.text('Puncak Gula Darah'), findsOneWidget);
      expect(find.textContaining('Jam tersambung'), findsOneWidget);

      // Yang ditampilkan hanya yang benar-benar diketahui: jumlah hari ini,
      // tanpa penyebut. `TargetHarian.bawaan` dihapus — 2000 kcal tidak pernah
      // dipilih siapa pun, dan sebuah bar yang mengukur terhadapnya menggambar
      // pecahan yang tidak berarti apa-apa.
      expect(find.text('kcal hari ini'), findsOneWidget);
      expect(find.textContaining('/ 2000'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
    });

    // Ajakan memfoto dulu hanya muncul pada instalasi yang riwayatnya kosong,
    // jadi ia hilang selamanya setelah sesi pertama — padahal petunjuk memulai
    // sesi dibutuhkan tiap pagi.
    testWidgets('hari yang belum ada sesinya mengajak memotret', (tester) async {
      final c = buatControllerUji(
        riwayatAwal: contohRiwayatSesi(
          sekarang: DateTime.now().subtract(const Duration(days: 3)),
        ),
      );
      await pumpHalaman(
        tester,
        const Scaffold(body: BerandaTab()),
        controller: c,
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum ada sesi hari ini'), findsOneWidget);
      expect(find.textContaining('tombol kamera'), findsOneWidget);
      // Riwayatnya tetap ada, jadi kartu sesi terakhir tidak ikut hilang.
      expect(find.text('Sesi Terakhir'), findsOneWidget);
    });

    testWidgets('tidak lagi menampilkan kartu vital "sekarang"', (tester) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHalaman(tester, const Scaffold(body: BerandaTab()), controller: c);
      await tester.pumpAndSettle();

      for (final judul in [
        'Detak Jantung',
        'Tekanan Darah',
        'Ringkasan Kesehatan',
        'Tren Kesehatan (Per 2 Jam)',
        'Watch Terhubung',
      ]) {
        expect(find.text(judul), findsNothing, reason: '$judul masih ada');
      }
    });

    testWidgets('tanpa riwayat menawarkan memulai sesi, bukan angka kosong', (
      tester,
    ) async {
      await pumpHalaman(tester, const Scaffold(body: BerandaTab()));
      await tester.pumpAndSettle();

      expect(find.text('Belum ada sesi hari ini'), findsOneWidget);
      expect(find.text('belum ada sesi'), findsOneWidget); // penghitung sesi
      // Satu ajakan saja: kartu kosong "Sesi Terakhir" yang dulu berdiri di
      // bawahnya mengatakan hal yang sama untuk kedua kalinya.
      expect(find.text('Sesi Terakhir'), findsNothing);
      // Satu titik bukan tren: sparkline tidak digambar.
      expect(find.text('Puncak Gula Darah'), findsNothing);
    });
  });

  group('Wajah B — sesi berjalan', () {
    testWidgets('timeline empat titik menggantikan isi idle', (tester) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHalaman(tester, const Scaffold(body: BerandaTab()), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));
      await tekanTombolJam(tester, c);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Sesi Kamu'), findsOneWidget);
      expect(find.text('Baseline'), findsOneWidget);
      expect(find.text('+1 jam'), findsOneWidget);
      expect(find.text('+2 jam'), findsOneWidget);
      expect(find.text('Buka Sesi'), findsOneWidget);

      // Isi wajah idle menyingkir selama sesi berjalan.
      expect(find.text('Ringkasan Hari Ini'), findsNothing);
      expect(find.text('Sesi Terakhir'), findsNothing);

      await hentikanSesi(tester, c);
    });

    // Hierarki wajah B: hitung mundur ke titik berikutnya adalah satu-satunya
    // hal di kartu ini yang berubah tiap detik dan satu-satunya yang menentukan
    // kapan pengguna harus bertindak. Sebelum redesain ia 14 px di ujung salah
    // satu dari empat baris seragam.
    testWidgets('hitung mundur titik berikutnya jadi angka terbesar kartu', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const Scaffold(body: BerandaTab()),
        controller: c,
      );

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));
      // Draft belum punya hero: yang ditunggu sebuah tombol, bukan waktu.
      expect(find.text('TITIK BERIKUTNYA'), findsNothing);

      await tekanTombolJam(tester, c);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('TITIK BERIKUTNYA'), findsOneWidget);

      double terbesar(Finder f) => tester
          .widgetList<Text>(f)
          .map((t) => t.style?.fontSize ?? 0)
          .fold<double>(0, (a, b) => a > b ? a : b);

      // Dua HitungMundur dirender: hero di atas dan baris timeline-nya. Yang
      // dijaga di sini yang hero — dan bahwa tidak ada teks lain di halaman ini
      // yang menandinginya.
      final hitungMundur = terbesar(
        find.descendant(
          of: find.byType(HitungMundur),
          matching: find.byType(Text),
        ),
      );

      expect(hitungMundur, greaterThanOrEqualTo(30));
      expect(terbesar(find.byType(Text)), hitungMundur);

      await hentikanSesi(tester, c);
    });

    testWidgets('draft menawarkan tombol mulai, dan jamnya yang menetapkan t0', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(tester, const Scaffold(body: BerandaTab()), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Selesai makan? Tekan tombol di jam'), findsOneWidget);
      expect(find.text('Saya Sudah Selesai Makan'), findsOneWidget);
      expect(c.sesiAktif!.t0, isNull);

      await tester.tap(find.text('Saya Sudah Selesai Makan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(c.sesiAktif!.t0, isNotNull);

      await hentikanSesi(tester, c);
    });
  });

  group('Wajah C — sesi baru selesai', () {
    testWidgets('kartu hasil bertahan sampai dibuka user', (tester) async {
      final c = buatControllerUji(percepatan: 3600);
      await pumpHalaman(tester, const Scaffold(body: BerandaTab()), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));
      await tekanTombolJam(tester, c);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pump(const Duration(seconds: 1)); // sampel +1 jam
      await tester.pump(const Duration(seconds: 1)); // sampel +2 jam
      await tester.pumpAndSettle();

      expect(find.text('Sesi baru selesai'), findsOneWidget);
      // Ringkasan harian tetap tampil di bawah kartu hasil.
      expect(find.text('Ringkasan Hari Ini'), findsOneWidget);

      await tester.tap(find.text('Sesi baru selesai'));
      await tester.pumpAndSettle();

      expect(find.text('Ringkasan Sesi'), findsOneWidget);
      expect(c.hasilBelumDibaca, isNull);
    });
  });

  // Tombol sinkron bercerita tentang buffer sebuah jam. Tanpa jam yang pernah
  // dipasangkan tidak ada buffer, dan tombol yang tidak bisa berarti apa-apa
  // lebih baik tidak ada daripada ada tapi mati.
  group('Tombol sinkron di baris status', () {
    testWidgets('disembunyikan saat belum ada jam yang dipasangkan', (
      tester,
    ) async {
      final c = buatControllerUji(status: contohPerangkatBelumDipasangkan);
      await pumpHalaman(
        tester,
        const Scaffold(body: BerandaTab()),
        controller: c,
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sync_rounded), findsNothing);
      // Dan barisnya tidak berbohong soal "terputus" — yang ini tidak akan
      // menyambung sendiri.
      expect(find.textContaining('Belum ada jam'), findsOneWidget);
    });

    testWidgets('tetap ada tapi mati saat jam tersandingkan namun terputus', (
      tester,
    ) async {
      final c = buatControllerUji(status: contohPerangkatTerputus);
      await pumpHalaman(
        tester,
        const Scaffold(body: BerandaTab()),
        controller: c,
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
      final tombol = tester.widget<IconButton>(
        find.ancestor(
          of: find.byIcon(Icons.sync_rounded),
          matching: find.byType(IconButton),
        ),
      );
      expect(tombol.onPressed, isNull);
    });

    testWidgets('berputar selagi menyinkronkan, lalu menjadi centang', (
      tester,
    ) async {
      final c = buatControllerUji(status: contohPerangkatTersambung);
      await pumpHalaman(
        tester,
        const Scaffold(body: BerandaTab()),
        controller: c,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.sync_rounded));
      await tester.pump();

      // Fase berjalan: ikonnya berputar dan tombolnya tidak bisa ditekan lagi.
      final berputar = tester.widget<RotationTransition>(
        find.descendant(
          of: find.byType(TombolSinkron),
          matching: find.byType(RotationTransition),
        ),
      );
      final awal = berputar.turns.value;
      await tester.pump(const Duration(milliseconds: 300));
      expect(berputar.turns.value, isNot(awal));

      // Lantai waktu satu putaran penuh: perintahnya sendiri selesai seketika,
      // tetapi umpan baliknya harus sempat terlihat.
      await tester.pump(const Duration(milliseconds: 700));
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      expect(find.byIcon(Icons.sync_rounded), findsNothing);

      // Lalu kembali diam supaya bisa ditekan lagi.
      await tester.pump(const Duration(milliseconds: 1700));
      expect(find.byIcon(Icons.sync_rounded), findsOneWidget);
    });
  });
}
