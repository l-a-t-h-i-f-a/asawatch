// Pindai kesehatan atas permintaan — perintah `UKUR_SEKARANG` (protokol §5.1)
// yang kini bisa ditekan pengguna sendiri, bukan hanya oleh alur kalibrasi.
//
// Yang diuji di sini adalah hal-hal yang tidak bisa dilihat dari kode: bahwa
// jalur gagalnya benar-benar sampai ke layar dengan kalimatnya, bahwa metrik
// yang tidak terbaca tidak menyamar jadi angka, dan bahwa hasilnya tidak
// diam-diam masuk riwayat sesi makan.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/pindai_kesehatan_page.dart';
import 'package:asawatch/services/ble_service.dart';
import 'package:asawatch/services/izin_ble.dart';
import 'package:asawatch/services/protokol_jam.dart' show GalatJam;

import 'helpers.dart';

/// Jam palsu selalu dipercepat 3600x, jadi `ukurSekarang` yang "30 detik"
/// selesai dalam ~8 ms waktu test. Satu pompa 100 ms cukup untuk melewatinya
/// dengan lapang.
const _selesaiMengukur = Duration(milliseconds: 100);

void main() {
  setUpAll(loadMontserrat);

  group('Persiapan', () {
    testWidgets('menerangkan cara duduk sebelum ada tombol yang ditekan', (
      tester,
    ) async {
      await pumpHalaman(
        tester,
        const PindaiKesehatanPage(izin: IzinBleSelaluBoleh()),
      );

      expect(find.text('Mulai Pindai'), findsOneWidget);
      expect(find.textContaining('Duduk tenang dulu 5 menit'), findsOneWidget);
      expect(find.textContaining('Jangan bicara selama pengukuran'),
          findsOneWidget);
      // Peringatan "bukan alat diagnosis" tidak boleh hilang dari layar ini.
      expect(find.textContaining('bukan alat diagnosis'), findsOneWidget);
    });

    testWidgets('jam terputus mematikan tombol dan menyebutkan sebabnya', (
      tester,
    ) async {
      final c = buatControllerUji(
        status: const StatusPerangkat(
          tersambung: false,
          namaPerangkat: 'AsaWatch X1',
        ),
      );

      await pumpHalaman(
        tester,
        const PindaiKesehatanPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );

      expect(find.text('Jam belum tersambung'), findsOneWidget);
      expect(
        find.textContaining('sambungannya kembali sendiri'),
        findsOneWidget,
      );
      // Jam yang sekadar terputus tidak boleh ditawari pemasangan ulang.
      expect(find.text('Pasangkan Jam'), findsNothing);

      final tombol = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Mulai Pindai'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(tombol.onPressed, isNull);
    });

    testWidgets('jam yang belum pernah dipasangkan menawarkan pemasangan', (
      tester,
    ) async {
      final c = buatControllerUji(status: StatusPerangkat.kosong);

      await pumpHalaman(
        tester,
        const PindaiKesehatanPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );

      expect(find.text('Belum ada jam'), findsOneWidget);
      expect(find.text('Pasangkan Jam'), findsOneWidget);
    });
  });

  group('Pengukuran', () {
    testWidgets('menunggu dengan detik berjalan, lalu menampilkan angkanya', (
      tester,
    ) async {
      final ble = FakeBleService(
        percepatan: 3600,
        otomatisSelesaiMakan: null,
        // Angka dipatok lewat benih supaya yang diperiksa adalah nilai yang
        // benar-benar datang dari jam, bukan sekadar "ada teks".
        benih: 7,
      );
      final c = buatControllerUji(ble: ble);

      await pumpHalaman(
        tester,
        const PindaiKesehatanPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );

      await tester.tap(find.text('Mulai Pindai'));
      await tester.pump();

      // Layar menunggu: apa yang sedang terjadi, dan apa yang harus dilakukan.
      expect(find.text('Jam mulai membaca'), findsOneWidget);
      expect(find.text('0 dtk'), findsOneWidget);
      expect(find.text('Berhenti Menunggu'), findsOneWidget);

      await tester.pump(_selesaiMengukur);

      expect(find.text('Pindai selesai'), findsOneWidget);
      expect(find.text('Gula Darah'), findsOneWidget);
      expect(find.text('Detak Jantung'), findsOneWidget);
      expect(find.text('Tekanan Darah'), findsOneWidget);
      expect(find.text('Oksigen (SpO₂)'), findsOneWidget);
      expect(find.text('Tidak terbaca'), findsNothing);

      final sampel = c.pindaiTerakhir!.sampel;
      expect(find.text('${sampel.gulaDarah}'), findsOneWidget);
      expect(find.text(sampel.tekananDarah!), findsOneWidget);
    });

    testWidgets('hasilnya tidak ikut masuk riwayat sesi makan', (tester) async {
      final c = buatControllerUji();

      await pumpHalaman(
        tester,
        const PindaiKesehatanPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );

      await tester.tap(find.text('Mulai Pindai'));
      await tester.pump(_selesaiMengukur);

      expect(c.pindaiTerakhir, isNotNull);
      // Pindai lepas bukan sesi: tanpa t0 dan tanpa tiga titik pembanding, ia
      // akan mencemari setiap hitungan di AnalisisSesi.
      expect(c.riwayat, isEmpty);
      expect(c.sesiAktif, isNull);
      expect(
        find.textContaining('tidak disimpan ke Riwayat'),
        findsOneWidget,
      );
    });

    testWidgets('metrik yang gagal ditulis "Tidak terbaca", bukan angka', (
      tester,
    ) async {
      final ble = FakeBleService(
        percepatan: 3600,
        otomatisSelesaiMakan: null,
        metrikGagal: const {'tekanan', 'spo2'},
      );
      final c = buatControllerUji(ble: ble);

      await pumpHalaman(
        tester,
        const PindaiKesehatanPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );

      await tester.tap(find.text('Mulai Pindai'));
      await tester.pump(_selesaiMengukur);

      expect(find.text('Tidak terbaca'), findsNWidgets(2));
      expect(find.textContaining('Sebagian metrik tidak terbaca'),
          findsOneWidget);
      // Sentinel 0 milik kawat dan tidak pernah boleh sampai ke layar (§5.2).
      expect(find.text('0'), findsNothing);
    });

    testWidgets('semua metrik gagal diberi sebab dan langkah berikutnya', (
      tester,
    ) async {
      final ble = FakeBleService(
        percepatan: 3600,
        otomatisSelesaiMakan: null,
        metrikGagal: const {'gula', 'detak', 'tekanan', 'spo2'},
      );
      final c = buatControllerUji(ble: ble);

      await pumpHalaman(
        tester,
        const PindaiKesehatanPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );

      await tester.tap(find.text('Mulai Pindai'));
      await tester.pump(_selesaiMengukur);

      expect(find.text('Tidak ada yang terbaca'), findsOneWidget);
      expect(find.textContaining('Rapatkan tali jam'), findsOneWidget);
    });

    testWidgets('jam yang menolak menampilkan kalimatnya, bukan hasil kosong', (
      tester,
    ) async {
      final ble = FakeBleService(
        percepatan: 3600,
        otomatisSelesaiMakan: null,
        galatUkurSekarang: 'Baterai jam terlalu rendah untuk mengukur.',
      );
      final c = buatControllerUji(ble: ble);

      await pumpHalaman(
        tester,
        const PindaiKesehatanPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );

      await tester.tap(find.text('Mulai Pindai'));
      await tester.pump(_selesaiMengukur);

      expect(
        find.text('Baterai jam terlalu rendah untuk mengukur.'),
        findsOneWidget,
      );
      // Kembali ke persiapan, dengan tombolnya siap ditekan lagi.
      expect(find.text('Mulai Pindai'), findsOneWidget);
      expect(c.pindaiTerakhir, isNull);
    });
  });

  group('Kalibrasi tekanan darah', () {
    testWidgets('angka tekanan darah tanpa kalibrasi dikatakan belum dikoreksi',
        (tester) async {
      final c = buatControllerUji();

      await pumpHalaman(
        tester,
        const PindaiKesehatanPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );

      await tester.tap(find.text('Mulai Pindai'));
      await tester.pump(_selesaiMengukur);

      expect(
        find.textContaining('belum pernah dikalibrasi dengan tensimeter'),
        findsOneWidget,
      );
    });
  });

  group('Guard di controller', () {
    test('jam terputus ditolak sebelum perintah dikirim', () async {
      final c = buatControllerUji(
        status: const StatusPerangkat(
          tersambung: false,
          namaPerangkat: 'AsaWatch X1',
        ),
      );
      addTearDown(c.dispose);

      await expectLater(
        c.pindaiKesehatan(),
        throwsA(
          isA<GalatJam>().having(
            (e) => e.pesanPengguna,
            'pesanPengguna',
            contains('Dekatkan jam'),
          ),
        ),
      );
    });

    test('jam yang belum dipasangkan minta dipasangkan, bukan didekatkan',
        () async {
      final c = buatControllerUji(status: StatusPerangkat.kosong);
      addTearDown(c.dispose);

      await expectLater(
        c.pindaiKesehatan(),
        throwsA(
          isA<GalatJam>().having(
            (e) => e.pesanPengguna,
            'pesanPengguna',
            contains('Pasangkan jam'),
          ),
        ),
      );
    });

    test('hanya satu pindai berjalan pada satu waktu', () async {
      final c = buatControllerUji();
      addTearDown(c.dispose);

      final pertama = c.pindaiKesehatan();
      // Perintah kedua yang menyusul akan menunggu jawaban yang sama dan
      // mencurinya dari yang pertama; jam sungguhan pun menjawabnya NAK
      // `sedangMengukur` (§7 kode 0x05).
      await expectLater(c.pindaiKesehatan(), throwsA(isA<GalatJam>()));

      await pertama;
      expect(c.pindaiTerakhir, isNotNull);
      expect(c.sedangMemindai, isFalse);
    });
  });
}
