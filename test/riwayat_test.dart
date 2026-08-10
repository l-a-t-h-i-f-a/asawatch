// Riwayat kini mendaftar sesi, bukan pembacaan per metrik (§4.2), dan
// filternya bergeser ke waktu makan / kualitas respons (§7).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/ringkasan_sesi_page.dart';
import 'package:asawatch/riwayat_tab.dart';
import 'package:asawatch/widgets/foto_makanan.dart';

import 'helpers.dart';

/// Membuka panel filter lalu memilih satu chip.
///
/// Ketukan dibatasi ke isi bottom sheet: label yang sama bisa juga muncul
/// sebagai badge pada entri di belakangnya.
Future<void> pilihFilter(WidgetTester tester, String label) async {
  await tester.tap(find.byIcon(Icons.filter_list_rounded));
  await tester.pumpAndSettle();
  await tester.tap(
    find.descendant(
      of: find.byType(BottomSheet),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadMontserrat);

  group('Daftar sesi', () {
    testWidgets('entri memuat nama, waktu makan, kalori, dan indikator respons', (
      tester,
    ) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHalaman(tester, const RiwayatTab(), controller: c);
      await tester.pumpAndSettle();

      expect(find.text('Riwayat Sesi'), findsOneWidget);
      expect(find.text('6 sesi'), findsOneWidget);
      expect(find.textContaining('430 kcal'), findsOneWidget);
      // Dua sesi berkarbohidrat tinggi, dua sesi yang responsnya landai.
      expect(find.text('Lonjakan'), findsNWidgets(2));
      expect(find.text('Landai'), findsNWidgets(2));
    });

    testWidgets('filter per metrik lama sudah tidak ada', (tester) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHalaman(tester, const RiwayatTab(), controller: c);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.filter_list_rounded));
      await tester.pumpAndSettle();

      expect(find.text('Filter Sesi'), findsOneWidget);
      expect(find.text('Waktu Makan'), findsOneWidget);
      expect(find.text('Kualitas Respons'), findsOneWidget);
      for (final lama in ['Detak Jantung', 'Gula Darah', 'Tekanan Darah']) {
        expect(find.text(lama), findsNothing, reason: 'filter $lama masih ada');
      }
    });

    testWidgets('mengetuk entri membuka ringkasan sesinya', (tester) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHalaman(tester, const RiwayatTab(), controller: c);
      await tester.pumpAndSettle();

      await tester.tap(find.byType(FotoMakanan).first);
      await tester.pumpAndSettle();

      expect(find.byType(RingkasanSesiPage), findsOneWidget);
      expect(find.text('Respons Gula Darah'), findsOneWidget);
    });

    testWidgets('sesi yang belum dianalisis tidak dikarang kalorinya', (
      tester,
    ) async {
      final asli = contohRiwayatSesi().first;
      final tanpaNutrisi = SesiMakan(
        id: asli.id,
        fotoPath: asli.fotoPath,
        waktuFoto: asli.waktuFoto,
        t0: asli.t0,
        status: asli.status,
        sampel: asli.sampel,
      );
      final c = buatControllerUji(riwayatAwal: [tanpaNutrisi]);
      await pumpHalaman(tester, const RiwayatTab(), controller: c);
      await tester.pumpAndSettle();

      expect(find.textContaining('nutrisi —'), findsOneWidget);
      expect(find.textContaining('kcal'), findsNothing);
    });
  });

  group('Filter', () {
    testWidgets('per waktu makan menyisakan sesi yang cocok', (tester) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHalaman(tester, const RiwayatTab(), controller: c);
      await tester.pumpAndSettle();

      await pilihFilter(tester, 'Camilan');

      expect(find.text('1 sesi'), findsOneWidget);
      expect(find.textContaining('Camilan'), findsWidgets);
      expect(find.textContaining('Makan Siang'), findsNothing);
    });

    testWidgets('per kualitas respons menyisakan sesi yang cocok', (
      tester,
    ) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHalaman(tester, const RiwayatTab(), controller: c);
      await tester.pumpAndSettle();

      await pilihFilter(tester, 'Lonjakan');

      expect(find.text('2 sesi'), findsOneWidget);
      // Tiga kemunculan: label filter di header dan badge dua entri tersisa.
      expect(find.text('Lonjakan'), findsNWidgets(3));
      expect(find.text('Landai'), findsNothing);
    });

    testWidgets('kombinasi filter tanpa hasil menawarkan menghapusnya', (
      tester,
    ) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHalaman(tester, const RiwayatTab(), controller: c);
      await tester.pumpAndSettle();

      await pilihFilter(tester, 'Camilan');
      await pilihFilter(tester, 'Lonjakan');

      expect(find.text('Tidak ada sesi untuk filter ini'), findsOneWidget);

      await tester.tap(find.text('Hapus filter'));
      await tester.pumpAndSettle();

      expect(find.text('6 sesi'), findsOneWidget);
    });
  });

  group('Riwayat kosong', () {
    testWidgets('mengatakan belum ada sesi, bukan menampilkan angka palsu', (
      tester,
    ) async {
      await pumpHalaman(tester, const RiwayatTab());
      await tester.pumpAndSettle();

      expect(find.text('Belum ada sesi yang selesai'), findsOneWidget);
      expect(find.text('0 sesi'), findsOneWidget);
    });
  });
}
