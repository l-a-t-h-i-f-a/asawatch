// Metrik selain gula darah: apakah ia terlihat selama sesi berjalan, apakah
// kurvanya digambar, dan apakah metrik yang jamnya tidak punya benar-benar
// hilang alih-alih menjadi `—`.
//
// Yang terakhir adalah kewajiban §3 protokol, dan bedanya bukan kosmetik: `—`
// berarti "diukur tetapi gagal", kalimat yang mengundang orang merapatkan tali
// jam dan mencoba lagi untuk sensor yang memang tidak ada di alatnya.

import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/ringkasan_sesi_page.dart';
import 'package:asawatch/services/ble_service.dart';
import 'package:asawatch/sesi_berjalan_page.dart';
import 'package:asawatch/widgets/kurva_sampel.dart';

import 'helpers.dart';

/// Sesi selesai dengan keempat metrik terisi, untuk halaman ringkasan.
SesiMakan _sesiLengkap() => contohRiwayatSesi().first;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadMontserrat);

  group('Metrik selama sesi berjalan', () {
    testWidgets('titik yang sudah terisi menampilkan detak, tekanan, dan SpO₂', (
      tester,
    ) async {
      // Sebelum ini timeline hanya menampilkan gula darah, sehingga ketiga
      // metrik lain — yang sudah diukur di setiap titik sejak awal — baru
      // terlihat setelah seluruh sesi selesai.
      final c = buatControllerUji();
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));
      await tekanTombolJam(tester, c);
      await tester.pump(const Duration(milliseconds: 50));

      final baseline = c.sesiAktif!.sampel[0];
      expect(baseline.terisi, isTrue, reason: 'baseline harus sudah masuk');

      expect(
        find.textContaining('${baseline.detakJantung} bpm'),
        findsWidgets,
      );
      expect(find.textContaining('SpO₂ ${baseline.spo2}%'), findsWidgets);
      expect(
        find.textContaining('${baseline.tekananDarah} mmHg'),
        findsWidgets,
      );

      await hentikanSesi(tester, c);
    });

    testWidgets('barisnya milik sampel yang terisi, bukan seluruh timeline', (
      tester,
    ) async {
      // Sesudah shutter, hanya baseline yang terisi — tiga titik lain masih
      // menunggu. Metriknya karena itu harus muncul **tepat sekali**: baris yang
      // digambar untuk setiap titik akan membawa angka baseline ke titik yang
      // datanya belum ada sama sekali.
      final c = buatControllerUji();
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));

      expect(c.sesiAktif!.sampel[0].terisi, isTrue);
      expect(find.textContaining('bpm'), findsOneWidget);
      expect(find.textContaining('SpO₂'), findsOneWidget);
      // Tiga titik yang menunggu tetap `—` seperti sebelumnya.
      expect(find.text('—'), findsNWidgets(3));

      await c.batalkan();
      await tester.pump();
    });

    testWidgets('jam tanpa SpO₂ tidak menampilkannya sama sekali', (
      tester,
    ) async {
      final c = buatControllerUji(
        ble: FakeBleService(
          percepatan: 3600,
          otomatisSelesaiMakan: null,
          kemampuan: const KemampuanPerangkat(
            gulaDarah: true,
            tekananDarah: true,
            spo2: false,
          ),
        ),
      );
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));
      await tekanTombolJam(tester, c);
      await tester.pump(const Duration(milliseconds: 50));

      // Metrik lain tetap ada; hanya SpO₂ yang hilang — dan hilang, bukan `—`.
      expect(find.textContaining('bpm'), findsWidgets);
      expect(find.textContaining('SpO₂'), findsNothing);

      await hentikanSesi(tester, c);
    });
  });

  group('Kurva SpO₂ di ringkasan sesi', () {
    testWidgets('digambar saat jam punya sensornya dan ada angkanya', (
      tester,
    ) async {
      await pumpHalaman(tester, RingkasanSesiPage(sesi: _sesiLengkap()));
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Oksigen Darah'), findsOneWidget);
      // Keterangannya menyebut yang **terendah**, bukan yang terakhir: pada SpO₂
      // justru titik terendah yang berarti sesuatu.
      expect(find.textContaining('Terendah'), findsOneWidget);

      final kurva = tester
          .widgetList<KurvaSampel>(find.byType(KurvaSampel))
          .where((k) => k.seri.contains(seriSpo2));
      expect(kurva, hasLength(1));
    });

    testWidgets('tidak ada bagiannya bila jam tidak punya sensornya', (
      tester,
    ) async {
      final c = buatControllerUji(
        ble: FakeBleService(
          percepatan: 3600,
          otomatisSelesaiMakan: null,
          kemampuan: const KemampuanPerangkat(
            gulaDarah: true,
            tekananDarah: true,
            spo2: false,
          ),
        ),
      );
      await pumpHalaman(
        tester,
        RingkasanSesiPage(sesi: _sesiLengkap()),
        controller: c,
      );
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Oksigen Darah'), findsNothing);
    });
  });

  group('Kemampuan jam (§3)', () {
    test('rentang sumbu SpO₂ jauh lebih sempit daripada metrik lain', () {
      // 95–100 adalah rentang wajar SpO₂. Lantai 20 milik metrik lain akan
      // meratakan seluruh grafiknya menjadi garis lurus, sehingga penurunan —
      // satu-satunya hal yang ingin dilihat — tidak terlihat.
      expect(seriSpo2.rentangMinimum, lessThan(seriGulaDarah.rentangMinimum));
    });

    test('kemampuan yang belum diketahui berarti semua metrik boleh tampil',
        () {
      // Menyembunyikan angka yang sudah ada di basis data karena kita belum
      // sempat bertanya ke jam adalah kerugian yang pasti.
      const belumTahu = StatusPerangkat(tersambung: false);
      expect(belumTahu.kemampuan, isNull);
      expect(belumTahu.metrikTampil, KemampuanPerangkat.semua);
    });

    test('kemampuan tidak hilang saat jam terputus, tidak seperti baterai', () {
      // Baterai menua tiap menit; jam tidak menumbuhkan sensor SpO₂ selagi di
      // luar jangkauan. Layar yang menyembunyikan metrik hanya selagi tersambung
      // berubah-ubah tanpa ada yang berubah.
      const tersambung = StatusPerangkat(
        tersambung: true,
        baterai: 80,
        namaPerangkat: 'AsaWatch X1',
        kemampuan: KemampuanPerangkat(
          gulaDarah: true,
          tekananDarah: true,
          spo2: false,
        ),
      );

      final terputus = tersambung.salin(tersambung: false);

      expect(terputus.baterai, isNull);
      expect(terputus.metrikTampil.spo2, isFalse);
    });

    test('jam palsu meneruskan kemampuannya lewat StatusPerangkat', () {
      // Jalur yang sama dipakai jam sungguhan dari byte 11 handshake.
      final ble = FakeBleService(
        otomatisSelesaiMakan: null,
        kemampuan: const KemampuanPerangkat(
          gulaDarah: true,
          tekananDarah: false,
          spo2: false,
        ),
      );
      addTearDown(ble.dispose);

      expect(ble.statusTerakhir.metrikTampil.tekananDarah, isFalse);
      expect(ble.statusTerakhir.metrikTampil.gulaDarah, isTrue);
    });
  });
}
