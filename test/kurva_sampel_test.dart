// Painter data (§7) dan tiga halaman detail metrik yang kini disuapi
// `List<Sampel>`, bukan path bezier hardcoded.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/detak_jantung_detail_page.dart';
import 'package:asawatch/gula_darah_detail_page.dart';
import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/tekanan_darah_detail_page.dart';
import 'package:asawatch/widgets/kurva_sampel.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadMontserrat);

  // Sumbu x pernah dimulai dari lantai `0..7200` — `+2 jam` jadwal produksi
  // yang ditulis sebagai literal. Ia berhenti benar begitu jadwal menjadi data
  // per sesi: sesi jadwal uji yang titik terakhirnya di detik ke-120 digambar
  // pada sumbu selebar dua jam, sehingga keempat titiknya menumpuk di ujung
  // kiri dan seluruh label sumbunya saling menimpa.
  group('Rentang sumbu x', () {
    test('mengikuti jadwal sesi, bukan angka tetap', () {
      const uji = [
        Sampel(index: 0, detikRelatifT0: -25, status: StatusSampel.terisi),
        Sampel(index: 1, detikRelatifT0: 0, status: StatusSampel.terisi),
        Sampel(index: 2, detikRelatifT0: 60, status: StatusSampel.terisi),
        Sampel(index: 3, detikRelatifT0: 120, status: StatusSampel.terisi),
      ];

      expect(rentangDetik(uji), (-25, 120));
    });

    test('jadwal produksi tetap terentang penuh', () {
      expect(rentangDetik(contohSesiSelesai().sampel), (-1500, 7200));
    });

    // Titik yang belum datang tetap memberi lebar sumbunya: sesi yang baru punya
    // dua titik tidak boleh direntangkan memenuhi lebar kartu, karena kurvanya
    // lalu terbaca seolah sudah selesai.
    test('sampel yang masih menunggu ikut memberi lebar', () {
      const belumLengkap = [
        Sampel(index: 0, detikRelatifT0: -1500, status: StatusSampel.terisi),
        Sampel(index: 1, detikRelatifT0: 0, status: StatusSampel.terisi),
        Sampel(index: 2, detikRelatifT0: 3600, status: StatusSampel.menunggu),
        Sampel(index: 3, detikRelatifT0: 7200, status: StatusSampel.menunggu),
      ];

      expect(rentangDetik(belumLengkap), (-1500, 7200));
    });

    test('seluruh titik pada detik yang sama tidak membagi dengan nol', () {
      const kembar = [
        Sampel(index: 0, detikRelatifT0: 0, status: StatusSampel.terisi),
        Sampel(index: 1, detikRelatifT0: 0, status: StatusSampel.terisi),
      ];

      expect(rentangDetik(kembar), (0, 1));
      expect(rentangDetik(const []), (0, 1));
    });
  });

  group('KurvaSampel', () {
    testWidgets('menggambar kurva saat ada sampel terisi', (tester) async {
      final sesi = contohSesiSelesai();
      await pumpHalaman(
        tester,
        Scaffold(
          body: KurvaSampel(
            sampel: sesi.sampel,
            seri: const [seriGulaDarah],
            garisAcuan: sesi.gulaDarahBaseline,
          ),
        ),
      );

      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.text('Belum ada sampel'), findsNothing);
    });

    testWidgets('mengatakan kosong, bukan menggambar garis karangan', (
      tester,
    ) async {
      // Sesi yang keempat titiknya belum satu pun terisi.
      const sampel = [
        Sampel.menunggu(index: 0, detikRelatifT0: -1500),
        Sampel.menunggu(index: 1, detikRelatifT0: 0),
        Sampel.menunggu(index: 2, detikRelatifT0: 3600),
        Sampel.menunggu(index: 3, detikRelatifT0: 7200),
      ];

      await pumpHalaman(
        tester,
        const Scaffold(
          body: KurvaSampel(sampel: sampel, seri: [seriGulaDarah]),
        ),
      );

      expect(find.text('Belum ada sampel'), findsOneWidget);
      expect(find.byType(KurvaSampelPainter), findsNothing);
    });

    testWidgets('seri mengambil metrik yang berbeda dari sampel yang sama', (
      tester,
    ) async {
      final sampel = contohSesiSelesai().sampel;

      expect(seriGulaDarah.ambil(sampel[2]), 140);
      expect(seriDetakJantung.ambil(sampel[2]), 88);
      expect(seriSistolik.ambil(sampel[0]), 116);
      expect(seriDiastolik.ambil(sampel[0]), 76);
      // Sampel yang terlewat tidak punya nilai untuk seri mana pun.
      final terlewat = contohSesiTidakLengkap().sampel[3];
      expect(seriGulaDarah.ambil(terlewat), isNull);
      expect(seriSistolik.ambil(terlewat), isNull);
    });
  });

  group('GulaDarahDetailPage', () {
    testWidgets('menampilkan puncak, delta, dan nilai tiap titik', (
      tester,
    ) async {
      await pumpHalaman(tester, GulaDarahDetailPage(sesi: contohSesiSelesai()));
      await tester.pumpAndSettle();

      // Dua kemunculan: angka besar di kepala halaman dan baris titik +1 jam.
      expect(find.text('140 mg/dL', findRichText: true), findsNWidgets(2));
      expect(find.textContaining('+48 dari baseline'), findsOneWidget);
      expect(find.text('92 mg/dL'), findsOneWidget); // baris baseline
      expect(find.text('Sedang'), findsOneWidget); // kualitas respons
      for (final label in labelTitikSampel) {
        expect(find.text(label), findsOneWidget);
      }
    });

    testWidgets('titik yang terlewat ditulis em dash', (tester) async {
      await pumpHalaman(
        tester,
        GulaDarahDetailPage(sesi: contohSesiTidakLengkap()),
      );
      await tester.pumpAndSettle();

      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('tanpa sesi selesai halaman mengatakannya apa adanya', (
      tester,
    ) async {
      await pumpHalaman(tester, const GulaDarahDetailPage());
      await tester.pumpAndSettle();

      expect(find.text('Belum ada sesi yang selesai'), findsOneWidget);
      expect(find.byType(KurvaSampel), findsNothing);
    });

    testWidgets('tanpa argumen memakai sesi terakhir dari controller', (
      tester,
    ) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHalaman(tester, const GulaDarahDetailPage(), controller: c);
      await tester.pumpAndSettle();

      expect(find.byType(KurvaSampel), findsOneWidget);
      expect(find.textContaining('Camilan'), findsOneWidget);
    });
  });

  group('TekananDarahDetailPage', () {
    testWidgets('menggambar dua seri dan mendaftar nilai per titik', (
      tester,
    ) async {
      await pumpHalaman(
        tester,
        TekananDarahDetailPage(sesi: contohSesiSelesai()),
      );
      await tester.pumpAndSettle();

      final kurva = tester.widget<KurvaSampel>(find.byType(KurvaSampel));
      expect(kurva.seri.length, 2);
      // Kepala halaman memakai baseline, jadi angkanya muncul dua kali.
      expect(find.text('116/76 mmHg', findRichText: true), findsNWidgets(2));
      expect(find.text('119/78 mmHg'), findsOneWidget);
    });
  });

  group('DetakJantungDetailPage', () {
    testWidgets('menampilkan nilai tertinggi sesi ini', (tester) async {
      await pumpHalaman(
        tester,
        DetakJantungDetailPage(sesi: contohSesiSelesai()),
      );
      await tester.pumpAndSettle();

      expect(find.text('88 bpm', findRichText: true), findsNWidgets(2));
      expect(find.textContaining('Tertinggi dari 4 titik'), findsOneWidget);
    });
  });
}
