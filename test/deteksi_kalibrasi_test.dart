// Langkah 6 (kartu deteksi yang bisa diedit, §4.5) dan langkah 7 (kalibrasi
// tekanan darah & status perangkat, §4.7 dan §5).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/deteksi_makanan_page.dart';
import 'package:asawatch/kalibrasi_tekanan_darah_page.dart';
import 'package:asawatch/menghubungkan_perangkat_page.dart';
import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/pemindaian_perangkat_page.dart';
import 'package:asawatch/profil_tab.dart';

import 'helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadMontserrat);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Koreksi porsi pada model', () {
    test('mengubah berat ikut menskalakan nutrisinya', () {
      final asli = contohHasilMenu(2).makanan.first; // 320 g, 45 g karbo
      final setengah = asli.salin(
        porsi: 'setengah piring',
        estimasiGram: asli.estimasiGram / 2,
      );

      expect(setengah.porsi, 'setengah piring');
      expect(setengah.nutrisi.karbohidrat, closeTo(22.5, 0.01));
      expect(setengah.nutrisi.kalori, closeTo(215, 0.01));
      // Nama tidak ikut berubah bila tidak dikoreksi.
      expect(setengah.nama, asli.nama);
    });

    test('hasil yang dikoreksi menghitung ulang total dan menandai dirinya', () {
      final hasil = contohHasilMenu(2);
      final dikoreksi = hasil.dikoreksi([
        hasil.makanan.first.salin(estimasiGram: hasil.makanan.first.estimasiGram / 2),
      ]);

      expect(dikoreksi.dikoreksiUser, isTrue);
      expect(dikoreksi.total.karbohidrat, closeTo(22.5, 0.01));
      expect(dikoreksi.total.kalori, closeTo(215, 0.01));
    });

    test('sesi yang dikoreksi user tetap masuk analisis meski keyakinan rendah', () {
      final ragu = contohHasilMenu(3, keyakinan: 0.45);

      expect(ragu.keyakinan, lessThan(0.6));
      expect(ragu.dikoreksiUser, isFalse);
      expect(ragu.dikoreksi(ragu.makanan).dikoreksiUser, isTrue);
    });
  });

  group('DeteksiMakananPage', () {
    testWidgets('shutter memunculkan kartu hasil yang bisa dikoreksi', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(tester, const DeteksiMakananPage(), controller: c);

      await tester.tap(find.byIcon(Icons.photo_camera_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(c.sesiAktif!.status, StatusSesi.draft);
      expect(find.text('Hasil Analisis'), findsOneWidget);
      expect(find.text('Nasi merah'), findsOneWidget);
      expect(find.text('Koreksi'), findsNWidgets(3));

      await hentikanSesi(tester, c);
    });

    testWidgets('mengoreksi porsi mengubah angka nutrisi sesi', (tester) async {
      final c = buatControllerUji();
      await pumpHalaman(tester, const DeteksiMakananPage(), controller: c);

      await tester.tap(find.byIcon(Icons.photo_camera_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final sebelum = c.sesiAktif!.hasil!.total.karbohidrat;

      await tester.tap(find.text('Koreksi').first);
      await tester.pumpAndSettle();

      expect(find.text('Koreksi Makanan'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('porsi')), 'setengah centong');
      await tester.tap(find.text('½×'));
      await tester.pump();

      expect(find.textContaining('Menjadi'), findsOneWidget);

      await tester.tap(find.text('Simpan Koreksi'));
      await tester.pumpAndSettle();

      final hasil = c.sesiAktif!.hasil!;
      expect(hasil.total.karbohidrat, lessThan(sebelum));
      expect(hasil.makanan.first.porsi, 'setengah centong');
      // Koreksi user membuat sesi ini tetap layak diplot di Analisis.
      expect(hasil.dikoreksiUser, isTrue);

      await hentikanSesi(tester, c);
    });

    testWidgets('kartu hasil menunjuk ke tombol di jam, bukan tombol sendiri', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(tester, const DeteksiMakananPage(), controller: c);

      await tester.tap(find.byIcon(Icons.photo_camera_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Tekan tombol Selesai Makan di jam'), findsOneWidget);
      expect(c.sesiAktif!.t0, isNull);

      // Sesi baru mulai saat tombol di jam ditekan.
      await tekanTombolJam(tester, c);
      expect(c.sesiAktif!.t0, isNotNull);
      expect(c.sesiAktif!.status, StatusSesi.berjalan);

      await hentikanSesi(tester, c);
    });

    testWidgets('"Ambil ulang foto" membuang draft dan kembali ke kamera', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(tester, const DeteksiMakananPage(), controller: c);

      await tester.tap(find.byIcon(Icons.photo_camera_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Ambil ulang foto'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(c.sesiAktif, isNull);
      expect(c.riwayat, isEmpty); // dibatalkan, bukan disimpan
      expect(find.text('Hasil Analisis'), findsNothing);
    });
  });

  group('KalibrasiTekananDarahPage', () {
    testWidgets('urutannya dikunci: tensimeter dulu, baru jam mengukur', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const KalibrasiTekananDarahPage(),
        controller: c,
      );

      final tombolUkur = find.widgetWithText(OutlinedButton, 'Ukur Sekarang');
      expect(tester.widget<OutlinedButton>(tombolUkur).onPressed, isNull);
      expect(
        find.textContaining('Isi hasil tensimeter lebih dulu'),
        findsOneWidget,
      );

      await tester.enterText(find.byKey(const Key('sistolik')), '124');
      await tester.enterText(find.byKey(const Key('diastolik')), '82');
      await tester.pump();

      expect(tester.widget<OutlinedButton>(tombolUkur).onPressed, isNotNull);
    });

    testWidgets('koefisien dihitung dari selisih lalu dikirim ke jam', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const KalibrasiTekananDarahPage(),
        controller: c,
      );

      await tester.enterText(find.byKey(const Key('sistolik')), '124');
      await tester.enterText(find.byKey(const Key('diastolik')), '82');
      await tester.pump();

      // Sebelum jam mengukur, koefisiennya belum ada.
      expect(find.text('Koreksi —'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Kirim ke Jam'),
            )
            .onPressed,
        isNull,
      );

      await tester.tap(find.text('Ukur Sekarang'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.tap(find.text('Kirim ke Jam'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final kalibrasi = c.kalibrasiTerakhir!;
      expect(kalibrasi.sistolikReferensi, 124);
      expect(kalibrasi.diastolikReferensi, 82);
      expect(
        kalibrasi.offsetSistolik,
        124 - kalibrasi.sistolikJam,
      );
      expect(kalibrasi.ringkasanOffset, contains('mmHg'));
    });
  });

  group('Status perangkat', () {
    testWidgets('menampilkan baterai dan sampel tertunda apa adanya', (
      tester,
    ) async {
      final c = buatControllerUji(status: contohPerangkatTerputus);
      await pumpHalaman(
        tester,
        const MenghubungkanPerangkatPage(),
        controller: c,
      );
      await tester.pumpAndSettle();

      expect(find.text('Jam Terputus'), findsOneWidget);
      expect(find.text('41%'), findsOneWidget);
      expect(find.text('Sampel tertunda'), findsOneWidget);
      expect(find.text('menunggu disinkronkan'), findsOneWidget);
      expect(find.text('Belum pernah sinkron'), findsOneWidget);
    });

    testWidgets('menyinkronkan memperbarui waktu sinkron terakhir', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const MenghubungkanPerangkatPage(),
        controller: c,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sinkronkan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('Belum pernah sinkron'), findsNothing);
      expect(find.textContaining('Sinkron terakhir'), findsOneWidget);
    });

    testWidgets('jam yang putus tidak bisa disinkronkan', (tester) async {
      final c = buatControllerUji(status: contohPerangkatTerputus);
      await pumpHalaman(
        tester,
        const MenghubungkanPerangkatPage(),
        controller: c,
      );
      await tester.pumpAndSettle();

      final tombol = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Sinkronkan'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(tombol.onPressed, isNull);
    });
  });

  group('Pemasangan perangkat', () {
    testWidgets('menawarkan pemindaian saat belum ada jam dipasangkan', (
      tester,
    ) async {
      final c = buatControllerUji(status: contohPerangkatBelumDipasangkan);
      await pumpHalaman(
        tester,
        const MenghubungkanPerangkatPage(),
        controller: c,
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Jam'), findsOneWidget);
      expect(find.text('Belum ada perangkat dipasangkan'), findsOneWidget);
      expect(find.text('Pindai & Sambungkan'), findsOneWidget);
      expect(find.text('Putuskan'), findsNothing);
    });

    testWidgets('jam yang sudah dipasangkan menawarkan ganti dan putus', (
      tester,
    ) async {
      final c = buatControllerUji(status: contohPerangkatTersambung);
      await pumpHalaman(
        tester,
        const MenghubungkanPerangkatPage(),
        controller: c,
      );
      await tester.pumpAndSettle();

      expect(find.text('AsaWatch X1'), findsOneWidget);
      expect(find.text('Ganti Perangkat'), findsOneWidget);

      await tester.tap(find.text('Putuskan'));
      await tester.pumpAndSettle();

      expect(find.text('Jam Terputus'), findsOneWidget);
      // Namanya tetap: jam yang diputus bukan jam yang dilupakan.
      expect(find.text('AsaWatch X1'), findsOneWidget);
      expect(find.text('Sambungkan Ulang'), findsOneWidget);
    });

    testWidgets('memindai lalu menyambungkan memperbarui status', (
      tester,
    ) async {
      final c = buatControllerUji(status: contohPerangkatBelumDipasangkan);
      await pumpHalaman(
        tester,
        const MenghubungkanPerangkatPage(),
        controller: c,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pindai & Sambungkan'));
      await tester.pumpAndSettle();

      expect(find.byType(PemindaianPerangkatPage), findsOneWidget);
      expect(find.text('AsaWatch X1'), findsOneWidget);
      expect(find.text('AsaWatch S2'), findsOneWidget);
      // Perangkat asing ikut terlihat, tetapi tidak bisa dipilih.
      expect(find.text('Tidak didukung aplikasi ini'), findsOneWidget);
      expect(find.text('3 perangkat ditemukan'), findsOneWidget);

      await tester.tap(find.text('AsaWatch X1'));
      await tester.pumpAndSettle();

      // Kembali ke halaman status dengan jam yang sudah tersambung.
      expect(find.byType(PemindaianPerangkatPage), findsNothing);
      expect(find.text('Jam Tersambung'), findsOneWidget);
      expect(c.statusPerangkat.namaPerangkat, 'AsaWatch X1');
      expect(find.text('Tersambung ke AsaWatch X1'), findsOneWidget);
    });

    testWidgets('perangkat tak didukung tidak bisa disambungkan', (
      tester,
    ) async {
      final c = buatControllerUji(status: contohPerangkatBelumDipasangkan);
      await pumpHalaman(tester, const PemindaianPerangkatPage(), controller: c);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Perangkat BLE tidak dikenal'));
      await tester.pumpAndSettle();

      expect(find.byType(PemindaianPerangkatPage), findsOneWidget);
      expect(c.statusPerangkat.tersambung, isFalse);
    });
  });

  group('Profil', () {
    testWidgets('menautkan status perangkat dan kalibrasi', (tester) async {
      await pumpHalaman(tester, const ProfilTab());
      await tester.pumpAndSettle();

      expect(find.text('Status Perangkat'), findsOneWidget);
      expect(find.text('Kalibrasi Tekanan Darah'), findsOneWidget);

      await tester.tap(find.text('Kalibrasi Tekanan Darah'));
      await tester.pumpAndSettle();

      expect(find.byType(KalibrasiTekananDarahPage), findsOneWidget);
    });
  });
}
