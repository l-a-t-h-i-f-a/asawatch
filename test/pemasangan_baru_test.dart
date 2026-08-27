// Keadaan pemasangan baru (rencana-produksi.md §3.3, Tahap A4).
//
// Sampai A3 setiap layar selalu punya data: basis data kosong disemai
// `contohRiwayatSesi()` dan profil kosong dijawab identitas demo. Keduanya
// sudah dihapus, jadi jalur "benar-benar kosong" kini bisa dan harus diuji —
// inilah yang dilihat setiap pengguna baru pada detik pertama.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/analisis_tab.dart';
import 'package:asawatch/beranda_tab.dart';
import 'package:asawatch/detak_jantung_detail_page.dart';
import 'package:asawatch/gula_darah_detail_page.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/profil_tab.dart';
import 'package:asawatch/repositories/sesi_repository.dart';
import 'package:asawatch/riwayat_tab.dart';
import 'package:asawatch/tekanan_darah_detail_page.dart';

import 'helpers.dart';

class _RepoGagalMenyimpan implements SesiRepository {
  @override
  Future<List<SesiMakan>> muatSemua() async => const [];

  @override
  Future<DateTime> simpan(SesiMakan sesi) async => throw StateError('disk penuh');

  @override
  Future<void> hapusSemua() async {}

  @override
  Future<void> hapus(String sesiId) async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadMontserrat);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Tanpa satu pun sesi', () {
    testWidgets('Beranda mengajak memotret, bukan menampilkan kartu kosong', (
      tester,
    ) async {
      await pumpHalaman(tester, const Scaffold(body: BerandaTab()));
      await tester.pump();

      expect(find.text('Belum ada sesi hari ini'), findsOneWidget);
      expect(find.textContaining('tombol kamera'), findsOneWidget);
    });

    testWidgets('Beranda menyapa tanpa nama', (tester) async {
      await pumpHalaman(tester, const Scaffold(body: BerandaTab()));
      await tester.pump();

      expect(find.text('Halo'), findsOneWidget);
    });

    testWidgets('Riwayat mengatakan belum ada sesi', (tester) async {
      await pumpHalaman(tester, const RiwayatTab());
      await tester.pump();

      expect(find.text('Belum ada sesi yang selesai'), findsOneWidget);
    });

    testWidgets('Analisis tidak menggambar tren dari nol titik', (
      tester,
    ) async {
      await pumpHalaman(tester, const AnalisisTab());
      await tester.pump();

      expect(find.text('Belum ada sesi untuk dianalisis'), findsOneWidget);
    });

    testWidgets('ketiga halaman detail metrik tidak jatuh tanpa sesi', (
      tester,
    ) async {
      // Ketiganya default ke sesi terakhir controller, yang kini bisa null.
      for (final halaman in <Widget>[
        const GulaDarahDetailPage(),
        const DetakJantungDetailPage(),
        const TekananDarahDetailPage(),
      ]) {
        await pumpHalaman(tester, halaman);
        await tester.pump();

        expect(tester.takeException(), isNull);
      }
    });
  });

  group('Profil belum diisi', () {
    testWidgets('menampilkan ajakan melengkapi, bukan identitas orang lain', (
      tester,
    ) async {
      await pumpHalaman(tester, const ProfilTab());
      await tester.pumpAndSettle();

      expect(find.text('Belum ada nama'), findsOneWidget);
      expect(find.textContaining('Lengkapi'), findsOneWidget);
      expect(find.textContaining('Lathifa'), findsNothing);
      expect(find.textContaining('@'), findsNothing);
    });

    testWidgets('menampilkan data yang sudah tersimpan', (tester) async {
      SharedPreferences.setMockInitialValues({
        'user_name': 'Rara',
        'user_email': 'rara@contoh.id',
      });

      await pumpHalaman(tester, const ProfilTab());
      await tester.pumpAndSettle();

      expect(find.text('Rara'), findsOneWidget);
      expect(find.text('rara@contoh.id'), findsOneWidget);
      expect(find.textContaining('Lengkapi'), findsNothing);
    });
  });

  group('Gagal menyimpan sesi', () {
    testWidgets('Beranda memperingatkan, tidak diam saja', (tester) async {
      // Sesinya ada di layar sekarang dan akan hilang saat aplikasi ditutup.
      // Sebelum A4 kegagalan ini hanya menjadi satu baris debugPrint.
      // pumpHalaman yang mendaftarkan dispose-nya; menambahkannya di sini
      // membuat controller dibuang dua kali.
      final c = buatControllerUji(repo: _RepoGagalMenyimpan());

      await pumpHalaman(
        tester,
        const Scaffold(body: BerandaTab()),
        controller: c,
      );

      await c.mulaiDraft('foto.jpg');
      await tekanTombolJam(tester, c);
      await c.akhiriLebihAwal();
      await tester.pump();

      expect(find.textContaining('gagal disimpan'), findsOneWidget);

      c.buangGalatPenyimpanan();
      await tester.pump();
      expect(find.textContaining('gagal disimpan'), findsNothing);
    });
  });
}
