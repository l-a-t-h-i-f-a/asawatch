// Analisis (§4.3) dan isi lintas sesi di halaman detail metrik (§4.4).
//
// Perhitungannya diuji langsung lewat AnalisisSesi supaya angkanya terkunci,
// lalu tab-nya diuji sebagai tampilan atas perhitungan itu.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/analisis_tab.dart';
import 'package:asawatch/gula_darah_detail_page.dart';
import 'package:asawatch/kalibrasi_tekanan_darah_page.dart';
import 'package:asawatch/models/analisis_sesi.dart';
import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/tekanan_darah_detail_page.dart';
import 'package:asawatch/widgets/kurva_sampel.dart';
import 'package:asawatch/widgets/sebaran_karbo.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadMontserrat);

  group('AnalisisSesi', () {
    test('satu titik sebaran per sesi yang punya nutrisi dan delta', () {
      final a = AnalisisSesi(contohRiwayatSesi());

      expect(a.titikSebaran.length, 6);
      // Satu sesi keyakinannya 0,45 — ditandai tidak andal.
      expect(a.titikAndal.length, 5);
      expect(a.jumlahDikecualikan, 1);
    });

    test('sesi yang masih berjalan tidak ikut dianalisis', () {
      final a = AnalisisSesi([
        ...contohRiwayatSesi(),
        contohSesiBerjalan(),
      ]);

      expect(a.sesi.length, 6);
    });

    test('tren naik dan korelasinya kuat pada data contoh', () {
      final tren = AnalisisSesi(contohRiwayatSesi()).tren!;

      expect(tren.kemiringan, greaterThan(0));
      expect(tren.korelasi, greaterThan(0.8));
      expect(tren.meyakinkan, isTrue);
    });

    test('tren butuh minimal tiga titik andal', () {
      final dua = contohRiwayatSesi().take(2).toList();

      expect(AnalisisSesi(dua).tren, isNull);
    });

    test('pemicu diurutkan dari kenaikan rata-rata tertinggi', () {
      final pemicu = AnalisisSesi(contohRiwayatSesi()).pemicuTeratas;

      expect(pemicu.first.nama, 'Mie goreng');
      expect(pemicu.first.rataDelta, 76);
      // Sesi berkeyakinan rendah tidak ikut, jadi menunya tidak muncul.
      expect(pemicu.map((p) => p.nama), isNot(contains('Bubur ayam')));
    });

    test('rekap pemulihan menghitung sesi yang kembali ke baseline', () {
      final rekap = AnalisisSesi(contohRiwayatSesi()).rekapPemulihan;

      expect(rekap.total, 6);
      expect(rekap.pulih, 4); // dua sesi lonjakan belum kembali dalam 2 jam
    });

    test('rata-rata puncak dan kenaikan dihitung lintas sesi', () {
      final a = AnalisisSesi(contohRiwayatSesi());

      expect(a.rataPuncak, closeTo(138.6, 0.1));
      expect(a.rataDelta, closeTo(46, 0.1));
    });

    test('perbandingan pemulihan null bila sesi belum cukup', () {
      final tiga = contohRiwayatSesi().take(3).toList();

      expect(AnalisisSesi(tiga).selisihProporsiPemulihan, isNull);
      expect(
        AnalisisSesi(contohRiwayatSesi()).selisihProporsiPemulihan,
        isNotNull,
      );
    });

    test('daftar kosong tidak meledak', () {
      final a = AnalisisSesi(const []);

      expect(a.kosong, isTrue);
      expect(a.tren, isNull);
      expect(a.rataPuncak, isNull);
      expect(a.pemicuTeratas, isEmpty);
      expect(a.rekapPemulihan.total, 0);
    });
  });

  group('AnalisisTab', () {
    testWidgets('menampilkan sebaran, pemicu, dan rekap pemulihan', (
      tester,
    ) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHalaman(tester, const AnalisisTab(), controller: c);
      await tester.pumpAndSettle();

      expect(find.text('Karbohidrat vs Kenaikan Gula Darah'), findsOneWidget);
      expect(find.byType(SebaranKarboGula), findsOneWidget);
      expect(find.textContaining('gula darahmu naik sekitar'), findsOneWidget);
      expect(find.text('Paling Memicu Lonjakan'), findsOneWidget);
      expect(find.text('Mie goreng'), findsOneWidget);
      expect(
        find.textContaining('4 dari 6', findRichText: true),
        findsOneWidget,
      );
      // Titik berkeyakinan rendah dijelaskan, bukan disembunyikan diam-diam.
      expect(find.textContaining('lingkaran kosong'), findsOneWidget);
    });

    testWidgets('toggle Mingguan/Bulanan yang hardcoded sudah hilang', (
      tester,
    ) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHalaman(tester, const AnalisisTab(), controller: c);
      await tester.pumpAndSettle();

      expect(find.text('Mingguan'), findsNothing);
      expect(find.text('Bulanan'), findsNothing);
    });

    testWidgets('tanpa sesi mengatakannya, dan pintu metrik tetap ada', (
      tester,
    ) async {
      await pumpHalaman(tester, const AnalisisTab());
      await tester.pumpAndSettle();

      expect(find.text('Belum ada sesi untuk dianalisis'), findsOneWidget);
      expect(find.text('Telusuri per Metrik'), findsOneWidget);
    });

    testWidgets('menjadi pintu masuk ke halaman detail metrik', (tester) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHalaman(tester, const AnalisisTab(), controller: c);
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Telusuri per Metrik'),
        find.byType(SingleChildScrollView),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Gula Darah'));
      await tester.pumpAndSettle();

      expect(find.byType(GulaDarahDetailPage), findsOneWidget);
    });
  });

  group('Isi lintas sesi di halaman detail', () {
    testWidgets('gula darah menumpuk kurva semua sesi plus rata-rata puncak', (
      tester,
    ) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHalaman(tester, const GulaDarahDetailPage(), controller: c);
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Semua Sesi'),
        find.byType(SingleChildScrollView),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();

      expect(find.byType(KurvaTumpukSesi), findsOneWidget);
      expect(find.textContaining('Rata-rata puncak 139 mg/dL'), findsOneWidget);
    });

    testWidgets('tekanan darah menampilkan tren antar sesi dan kalibrasi', (
      tester,
    ) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHalaman(tester, const TekananDarahDetailPage(), controller: c);
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Tren Antar Sesi'),
        find.byType(SingleChildScrollView),
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sistolik'), findsOneWidget);
      expect(find.text('Diastolik'), findsOneWidget);
      expect(find.text('Kalibrasi Tekanan Darah'), findsOneWidget);
      // Statusnya jujur: belum ada data kalibrasi yang tersimpan.
      expect(find.text('Belum pernah dikalibrasi'), findsOneWidget);

      await tester.tap(find.text('Kalibrasi'));
      await tester.pumpAndSettle();
      expect(find.byType(KalibrasiTekananDarahPage), findsOneWidget);
    });

    testWidgets('kurva tumpuk butuh baseline yang terukur', (tester) async {
      final tanpaBaseline = SesiMakan(
        id: 'x',
        fotoPath: contohFotoPath,
        waktuFoto: DateTime(2026, 8, 8, 12),
        t0: DateTime(2026, 8, 8, 12, 30),
        status: StatusSesi.tidakLengkap,
        hasil: contohHasilMenu(0),
        sampel: const [
          Sampel(index: 0, detikRelatifT0: -1500, status: StatusSampel.terlewat),
          Sampel(
            index: 1,
            detikRelatifT0: 0,
            status: StatusSampel.terisi,
            gulaDarah: 101,
          ),
          Sampel(
            index: 2,
            detikRelatifT0: 3600,
            status: StatusSampel.terisi,
            gulaDarah: 140,
          ),
          Sampel(
            index: 3,
            detikRelatifT0: 7200,
            status: StatusSampel.terisi,
            gulaDarah: 104,
          ),
        ],
      );

      await pumpHalaman(
        tester,
        Scaffold(body: KurvaTumpukSesi(sesi: [tanpaBaseline])),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Belum ada sesi dengan baseline terukur'),
        findsOneWidget,
      );
    });
  });
}
