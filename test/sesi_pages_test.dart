// Widget test untuk layar sesi: SesiBerjalanPage dan RingkasanSesiPage.
//
// Sesi berjalan digerakkan `FakeBleService` yang dipercepat (§11), jadi sampel
// +1 jam dan +2 jam benar-benar masuk selama test, bukan dipalsukan lewat
// state buatan.
//
// Catatan: selama masih ada hitung mundur berjalan, halaman terus menjadwalkan
// frame, jadi dipakai `pump()` — bukan `pumpAndSettle()`.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/controllers/sesi_makan_controller.dart';
import 'package:asawatch/services/nutrisi_service.dart';
import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/ringkasan_sesi_page.dart';
import 'package:asawatch/sesi_berjalan_page.dart';
import 'package:asawatch/widgets/timeline_sampel.dart';

import 'helpers.dart';

String teksDi(WidgetTester tester, Finder induk) {
  return tester
      .widget<Text>(find.descendant(of: induk, matching: find.byType(Text)))
      .data!;
}

/// Analisis nutrisi yang tidak pernah selesai — mewakili foto yang diambil
/// saat offline.
class _NutrisiTertunda implements NutrisiService {
  @override
  Future<HasilDeteksi> analisis(String fotoPath) => Completer<HasilDeteksi>().future;
}

/// Membawa controller sampai sesi berjalan: draft dibuat, baseline masuk,
/// lalu t0 ditetapkan.
Future<void> jalankanSesi(
  WidgetTester tester,
  SesiMakanController controller,
) async {
  await controller.mulaiDraft(contohFotoPath);
  await tester.pump(const Duration(milliseconds: 50)); // baseline masuk
  await tekanTombolJam(tester, controller);
  await tester.pump(const Duration(milliseconds: 50)); // sampel t0 masuk
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadMontserrat);

  group('SesiBerjalanPage', () {
    testWidgets('draft menunggu tombol di jam, bukan tombol di app', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Siap dimulai'), findsOneWidget);
      expect(find.text('Tekan tombol Selesai Makan di jam'), findsOneWidget);
      // Baseline sudah terukur, tiga titik lain belum.
      expect(find.text('—'), findsNWidgets(3));

      // t0 hanya lahir dari jam.
      expect(c.sesiAktif!.t0, isNull);
      await tekanTombolJam(tester, c);
      expect(c.sesiAktif!.t0, isNotNull);

      await hentikanSesi(tester, c);
    });

    testWidgets('jam terputus: petunjuknya jujur, sesi tidak dipaksa mulai', (
      tester,
    ) async {
      final c = buatControllerUji(
        status: const StatusPerangkat(tersambung: false),
      );
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Jam belum tersambung'), findsWidgets);
      expect(c.sesiAktif!.status, StatusSesi.menungguPerangkat);
      expect(c.sesiAktif!.t0, isNull);

      await hentikanSesi(tester, c);
    });

    testWidgets('sesi berjalan menampilkan empat titik dan status jam', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankanSesi(tester, c);

      for (final label in labelTitikSampel) {
        expect(find.text(label), findsOneWidget, reason: 'titik $label hilang');
      }
      expect(find.text('Sesi berjalan'), findsOneWidget);
      expect(find.textContaining('Jam tersambung'), findsOneWidget);

      // Dua titik terakhir belum ada datanya: satu dihitung mundur, satu lagi
      // em dash. Tidak ada nilai lama yang dipakai ulang.
      expect(find.byType(HitungMundur), findsOneWidget);
      expect(find.text('—'), findsOneWidget);

      await hentikanSesi(tester, c);
    });

    testWidgets('sampel +1 jam dan +2 jam masuk lalu sesi berakhir', (
      tester,
    ) async {
      // percepatan 3600: jeda 1 jam menjadi 1 detik waktu test.
      final c = buatControllerUji(percepatan: 3600);
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankanSesi(tester, c);

      await tester.pump(const Duration(seconds: 1)); // sampel +1 jam
      expect(c.sesiAktif!.sampel[2].terisi, isTrue);

      await tester.pump(const Duration(seconds: 1)); // sampel +2 jam
      expect(c.sesiAktif, isNull);
      expect(c.sesiTerakhir!.status, StatusSesi.selesai);

      // Halaman tidak ditinggal kosong: isinya berganti jadi pintu ke hasil.
      expect(find.text('Sesi sudah berakhir'), findsOneWidget);
      expect(find.text('Lihat Ringkasan'), findsOneWidget);
    });

    testWidgets('sampel yang tidak pernah datang membuat sesi tidak lengkap', (
      tester,
    ) async {
      final c = buatControllerUji(percepatan: 3600, lewatkan: {3});
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankanSesi(tester, c);

      await tester.pump(const Duration(seconds: 3));

      // Sampel +2 jam tidak datang: sesi tetap berjalan dan statusnya masih
      // "menunggu", bukan gagal (§8).
      expect(c.sesiAktif, isNotNull);
      expect(c.sesiAktif!.sampel[3].status, StatusSampel.menunggu);

      await c.akhiriLebihAwal();
      await tester.pump();
      expect(c.sesiTerakhir!.status, StatusSesi.tidakLengkap);
    });

    testWidgets('nutrisi yang belum dianalisis tidak dikarang', (tester) async {
      // Foto bisa diambil saat offline dan analisisnya menyusul; itu kondisi
      // normal, bukan error (§12.3).
      final c = buatControllerUji(nutrisi: _NutrisiTertunda());
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump();

      expect(find.text('Menganalisis…'), findsOneWidget);

      await hentikanSesi(tester, c);
    });

    testWidgets('membatalkan sesi butuh konfirmasi lalu menutup halaman', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankanSesi(tester, c);

      await tester.tap(find.text('Batalkan Sesi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Batalkan sesi ini?'), findsOneWidget);

      // Memilih lanjut tidak membatalkan apa pun.
      await tester.tap(find.text('Lanjutkan Sesi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(c.sesiAktif, isNotNull);

      await tester.tap(find.text('Batalkan Sesi'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Batalkan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(c.sesiAktif, isNull);
      // Sesi yang dibatalkan tidak masuk riwayat.
      expect(c.riwayat, isEmpty);
    });
  });

  group('HitungMundur', () {
    testWidgets('berdetak dari target absolut lalu berhenti saat lewat', (
      tester,
    ) async {
      var jam = DateTime(2026, 8, 8, 12, 0);
      final target = jam.add(const Duration(seconds: 90));

      await pumpHalaman(
        tester,
        Scaffold(body: HitungMundur(target: target, sekarang: () => jam)),
      );

      final mundur = find.byType(HitungMundur);
      expect(teksDi(tester, mundur), '01:30');

      jam = jam.add(const Duration(seconds: 31));
      await tester.pump(const Duration(seconds: 1));
      expect(teksDi(tester, mundur), '00:59');

      // Setelah jadwalnya lewat, yang ditunggu adalah data dari jam tangan,
      // bukan waktu — hitung mundur berhenti, bukan jadi negatif.
      jam = target.add(const Duration(seconds: 5));
      await tester.pump(const Duration(seconds: 1));
      expect(teksDi(tester, mundur), 'menunggu data');

      // Timer sudah dibatalkan, jadi halaman bisa tenang lagi.
      await tester.pumpAndSettle();
    });
  });

  group('RingkasanSesiPage', () {
    /// Detail tiap titik dilipat secara default; ini membukanya.
    Future<void> bukaDetailTitik(WidgetTester tester) async {
      await tester.dragUntilVisible(
        find.text('Lihat'),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.tap(find.text('Lihat'));
      await tester.pumpAndSettle();
    }

    testWidgets('verdict, puncak, delta, dan pemulihan ditampilkan', (
      tester,
    ) async {
      await pumpHalaman(tester, RingkasanSesiPage(sesi: contohSesiSelesai()));
      await tester.pumpAndSettle();

      expect(
        find.text('puncak +48 mg/dL · normal dalam 2 jam'),
        findsOneWidget,
      );
      // Detail tiap titik masih terlipat, jadi puncak baru muncul sekali.
      expect(find.text('140'), findsOneWidget);
      expect(find.text('+48'), findsOneWidget);
      expect(find.text('2 jam'), findsOneWidget);
      // Lencana kualitas respons yang sama dengan yang dipakai di Riwayat.
      expect(find.text(KualitasRespons.sedang.label), findsOneWidget);

      await bukaDetailTitik(tester);
      // Setelah dibuka: kotak nilai dan kartu titik +1 jam.
      expect(find.text('140'), findsNWidgets(2));
      // Sampel yang datang telat tetap ditandai asalnya.
      expect(find.textContaining('dari buffer'), findsOneWidget);
    });

    testWidgets('karbohidrat dikaitkan langsung dengan lonjakannya', (
      tester,
    ) async {
      await pumpHalaman(tester, RingkasanSesiPage(sesi: contohSesiSelesai()));
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.textContaining('karbohidrat → puncak'),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      expect(
        find.textContaining('karbohidrat → puncak +48 mg/dL'),
        findsOneWidget,
      );
    });

    testWidgets('sampel terlewat menulis em dash di seluruh metriknya', (
      tester,
    ) async {
      await pumpHalaman(
        tester,
        RingkasanSesiPage(sesi: contohSesiTidakLengkap()),
      );
      await tester.pumpAndSettle();

      // Terlipat: hanya kotak "Pemulihan" yang belum punya nilai.
      expect(find.text('—'), findsOneWidget);
      expect(find.text('belum kembali'), findsOneWidget);
      expect(find.textContaining('+63 mg/dL'), findsWidgets);

      await bukaDetailTitik(tester);
      // Ditambah empat metrik pada kartu +2 jam yang terlewat.
      expect(find.text('—'), findsNWidgets(5));
      expect(find.textContaining('terlewat'), findsWidgets);
    });

    testWidgets('sesi yang masih berjalan tidak berpura-pura punya hasil', (
      tester,
    ) async {
      await pumpHalaman(tester, RingkasanSesiPage(sesi: contohSesiBerjalan()));
      await tester.pump();

      // Tidak ada angka besar yang disimpulkan; yang ada status, hitung
      // mundur titik berikutnya, dan jalan kembali ke layar sesi berjalan.
      expect(find.text('Sesi berjalan'), findsOneWidget);
      expect(find.byType(HitungMundur), findsOneWidget);
      expect(find.text('Buka Sesi Berjalan'), findsOneWidget);
      expect(find.text(KualitasRespons.belumLengkap.label), findsOneWidget);
    });

    testWidgets('nutrisi enam makro ikut ditampilkan', (tester) async {
      await pumpHalaman(tester, RingkasanSesiPage(sesi: contohSesiSelesai()));
      await tester.pumpAndSettle();

      await tester.dragUntilVisible(
        find.text('Nutrisi Sesi Ini'),
        find.byType(SingleChildScrollView),
        const Offset(0, -200),
      );
      await tester.pumpAndSettle();

      for (final label in [
        'Kalori',
        'Karbohidrat',
        'Protein',
        'Lemak',
        'Gula Total',
        'Serat',
      ]) {
        expect(find.text(label), findsOneWidget, reason: 'nutrisi $label');
      }
      expect(find.textContaining('Keyakinan deteksi 82%'), findsOneWidget);
    });
  });
}
