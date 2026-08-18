// Langkah 6 (kartu deteksi yang bisa diedit, §4.5) dan langkah 7 (kalibrasi
// tekanan darah & status perangkat, §4.7 dan §5).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/beranda_tab.dart';
import 'package:asawatch/deteksi_makanan_page.dart';
import 'package:asawatch/kalibrasi_tekanan_darah_page.dart';
import 'package:asawatch/menghubungkan_perangkat_page.dart';
import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/pemindaian_perangkat_page.dart';
import 'package:asawatch/profil_tab.dart';
import 'package:asawatch/services/izin_ble.dart';

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

    test(
      'hasil yang dikoreksi menghitung ulang total dan menandai dirinya',
      () {
        final hasil = contohHasilMenu(2);
        final dikoreksi = hasil.dikoreksi([
          hasil.makanan.first.salin(
            estimasiGram: hasil.makanan.first.estimasiGram / 2,
          ),
        ]);

        expect(dikoreksi.dikoreksiUser, isTrue);
        expect(dikoreksi.total.karbohidrat, closeTo(22.5, 0.01));
        expect(dikoreksi.total.kalori, closeTo(215, 0.01));
      },
    );

    test(
      'sesi yang dikoreksi user tetap masuk analisis meski keyakinan rendah',
      () {
        final ragu = contohHasilMenu(3, keyakinan: 0.45);

        expect(ragu.keyakinan, lessThan(0.6));
        expect(ragu.dikoreksiUser, isFalse);
        expect(ragu.dikoreksi(ragu.makanan).dikoreksiUser, isTrue);
      },
    );
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
      await tester.enterText(
        find.byKey(const Key('porsi')),
        'setengah centong',
      );
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

    testWidgets('kartu hasil menawarkan dua cara memulai sesi', (tester) async {
      final c = buatControllerUji();
      await pumpHalaman(tester, const DeteksiMakananPage(), controller: c);

      await tester.tap(find.byIcon(Icons.photo_camera_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Tombol di jam tetap disebut — ia satu-satunya yang bekerja saat ponsel
      // tidak dipegang — dan tombol di app ada di sebelahnya.
      expect(find.text('Selesai makan? Tekan tombol di jam'), findsOneWidget);
      expect(find.text('Saya Sudah Selesai Makan'), findsOneWidget);
      expect(c.sesiAktif!.t0, isNull);

      // Jalur jam tetap utuh dan tidak berubah.
      await tekanTombolJam(tester, c);
      expect(c.sesiAktif!.t0, isNotNull);
      expect(c.sesiAktif!.status, StatusSesi.berjalan);

      // Setelah sinyal jam sampai, kartunya tidak boleh berbalik bilang jamnya
      // putus: sesi justru sedang berjalan dan sampelnya ditulis. Tombolnya
      // ikut hilang — tidak ada lagi yang bisa dilakukannya.
      await tester.pump();
      expect(find.text('Jam belum tersambung'), findsNothing);
      expect(find.text('Sesi sudah dimulai'), findsOneWidget);
      expect(find.text('Saya Sudah Selesai Makan'), findsNothing);

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

  // Metode kalibrasinya mengikuti alat sejenis (Samsung Health Monitor):
  // tiga putaran tensimeter → jam, jeda wajib di antaranya, dan koreksi
  // diambil dari nilai tengah. Yang dikunci di sini adalah aturan-aturan yang
  // membuat metode itu berarti sesuatu.
  group('Model kalibrasi', () {
    PutaranKalibrasi putaran(int refSis, int refDia, int jamSis, int jamDia) =>
        PutaranKalibrasi(
          sistolikReferensi: refSis,
          diastolikReferensi: refDia,
          sistolikJam: jamSis,
          diastolikJam: jamDia,
        );

    test('koreksi diambil dari median, bukan rata-rata', () {
      // Putaran kedua kacau (mansetnya kendur). Rata-rata akan terseret
      // olehnya; median tidak.
      final k = Kalibrasi(
        waktu: DateTime(2026, 8, 14),
        sisi: SisiPergelangan.kiri,
        putaran: [
          putaran(124, 82, 120, 78),
          putaran(124, 82, 90, 60),
          putaran(124, 82, 121, 79),
        ],
      );

      expect(k.offsetSistolik, 4); // median dari 4, 34, 3
      expect(k.offsetDiastolik, 4); // median dari 4, 22, 3
    });

    test('sebaran yang terlalu jauh menjadikannya tidak konsisten', () {
      final rapat = Kalibrasi(
        waktu: DateTime(2026, 8, 14),
        sisi: SisiPergelangan.kiri,
        putaran: [
          putaran(124, 82, 120, 78),
          putaran(126, 83, 121, 78),
          putaran(123, 81, 120, 77),
        ],
      );
      expect(rapat.konsisten, isTrue);

      final berantakan = Kalibrasi(
        waktu: DateTime(2026, 8, 14),
        sisi: SisiPergelangan.kiri,
        putaran: [
          putaran(124, 82, 120, 78),
          putaran(160, 110, 121, 79),
          putaran(123, 81, 120, 77),
        ],
      );
      expect(berantakan.konsisten, isFalse);
      expect(
        berantakan.sebaranSistolik,
        greaterThan(Kalibrasi.sebaranMaksimum),
      );
    });

    test('masa berlakunya empat minggu dan dihitung dari waktu kalibrasi', () {
      final k = Kalibrasi.tunggal(
        waktu: DateTime(2026, 8, 1, 10),
        sistolikReferensi: 124,
        diastolikReferensi: 82,
        sistolikJam: 120,
        diastolikJam: 78,
      );

      expect(k.berlakuSampai, DateTime(2026, 8, 29, 10));
      expect(k.kedaluwarsaPada(DateTime(2026, 8, 28)), isFalse);
      expect(k.sisaHariPada(DateTime(2026, 8, 28, 10)), 1);
      expect(k.kedaluwarsaPada(DateTime(2026, 8, 29, 10)), isTrue);
      expect(k.sisaHariPada(DateTime(2026, 9, 10)), 0);
    });

    test('angka tensimeter yang mustahil ditolak sebelum jam mengukur', () {
      // Kolom tertukar — kesalahan yang paling mudah dilakukan, dan yang
      // paling mahal karena koreksinya bertahan sebulan.
      expect(
        galatReferensiTensimeter(sistolik: 82, diastolik: 124),
        contains('Sistolik harus lebih besar'),
      );
      expect(galatReferensiTensimeter(sistolik: 12, diastolik: 8), isNotNull);
      expect(galatReferensiTensimeter(sistolik: 124, diastolik: 82), isNull);
      // Belum lengkap bukan berarti salah.
      expect(galatReferensiTensimeter(sistolik: 124), isNull);
    });
  });

  group('KalibrasiTekananDarahPage', () {
    // Jam palsu berbenih tetap: 121/77, 119/82, lalu 118/75.
    Future<void> mulaiKalibrasi(WidgetTester tester) async {
      await tester.tap(find.text('Tangan kiri'));
      await tester.pump();
      // Halaman persiapan lebih panjang dari satu layar ponsel.
      await tester.ensureVisible(find.text('Mulai Kalibrasi'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mulai Kalibrasi'));
      await tester.pump();
    }

    Future<void> jalankanPutaran(
      WidgetTester tester, {
      int sistolik = 124,
      int diastolik = 82,
    }) async {
      // Jam dulu — bersamaan dengan manset di lengan seberang — baru angkanya
      // ditulis, karena angka tensimeter memang baru ada setelah keduanya
      // selesai.
      await tester.tap(find.text('Mulai Ukur Bersamaan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byKey(const Key('sistolik')), '$sistolik');
      await tester.enterText(find.byKey(const Key('diastolik')), '$diastolik');
      await tester.pump();
      await tester.tap(find.textContaining('Simpan'));
      await tester.pump();
    }

    Future<void> lewatiJeda(WidgetTester tester) async {
      await tester.pump(Kalibrasi.jedaAntarPutaran);
      await tester.tap(find.textContaining('Mulai Putaran'));
      await tester.pump();
    }

    testWidgets('persiapan dulu: pergelangan harus dipilih sebelum mulai', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const KalibrasiTekananDarahPage(),
        controller: c,
      );

      final mulai = find.widgetWithText(ElevatedButton, 'Mulai Kalibrasi');
      expect(tester.widget<ElevatedButton>(mulai).onPressed, isNull);
      // Peringatannya bukan tautan halus — ia ada di layar pertama.
      expect(find.textContaining('bukan alat diagnosis'), findsOneWidget);

      await tester.tap(find.text('Tangan kanan'));
      await tester.pump();
      expect(tester.widget<ElevatedButton>(mulai).onPressed, isNotNull);
    });

    testWidgets('manset di lengan seberang, dan itu dikatakan di layar', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const KalibrasiTekananDarahPage(),
        controller: c,
      );

      await tester.tap(find.text('Tangan kiri'));
      await tester.pump();
      expect(find.textContaining('Manset di lengan kanan'), findsWidgets);

      await tester.tap(find.text('Tangan kanan'));
      await tester.pump();
      expect(find.textContaining('Manset di lengan kiri'), findsWidgets);
    });

    testWidgets('angka jam disembunyikan sampai hasil tensimeter ditulis', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const KalibrasiTekananDarahPage(),
        controller: c,
      );
      await mulaiKalibrasi(tester);

      // Kolom tensimeter belum bisa diisi sebelum jam mengukur: pasangannya
      // harus sezaman, dan angka yang ditulis lebih dulu bukan pasangan.
      expect(
        tester.widget<TextField>(find.byKey(const Key('sistolik'))).enabled,
        isFalse,
      );

      await tester.tap(find.text('Mulai Ukur Bersamaan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Jam sudah selesai, tetapi angkanya tidak boleh terlihat di mana pun —
      // melihatnya lebih dulu membuat orang "membetulkan" angka yang diketik.
      expect(find.text('Jam sudah selesai mengukur'), findsOneWidget);
      expect(find.textContaining('121/77'), findsNothing);
      expect(
        tester.widget<TextField>(find.byKey(const Key('sistolik'))).enabled,
        isTrue,
      );

      await tester.enterText(find.byKey(const Key('sistolik')), '124');
      await tester.enterText(find.byKey(const Key('diastolik')), '82');
      await tester.pump();

      // Baru sekarang tirainya dibuka, lengkap dengan selisihnya.
      expect(find.textContaining('121/77'), findsOneWidget);
      expect(find.textContaining('+3/+5'), findsOneWidget);
    });

    testWidgets('angka tensimeter yang mustahil menghalangi penyimpanan', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const KalibrasiTekananDarahPage(),
        controller: c,
      );
      await mulaiKalibrasi(tester);

      await tester.tap(find.text('Mulai Ukur Bersamaan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byKey(const Key('sistolik')), '82');
      await tester.enterText(find.byKey(const Key('diastolik')), '124');
      await tester.pump();

      expect(find.textContaining('Sistolik harus lebih besar'), findsOneWidget);
      final simpan = find.widgetWithText(ElevatedButton, 'Simpan Putaran 1');
      expect(tester.widget<ElevatedButton>(simpan).onPressed, isNull);
    });

    testWidgets('mengukur ulang membuang angka tensimeter yang tidak sezaman', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const KalibrasiTekananDarahPage(),
        controller: c,
      );
      await mulaiKalibrasi(tester);

      await tester.tap(find.text('Mulai Ukur Bersamaan'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.enterText(find.byKey(const Key('sistolik')), '124');
      await tester.enterText(find.byKey(const Key('diastolik')), '82');
      await tester.pump();

      await tester.tap(find.text('Ukur Ulang'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Angka lama itu pasangan pengukuran yang sudah dibuang.
      expect(
        tester
            .widget<TextField>(find.byKey(const Key('sistolik')))
            .controller!
            .text,
        isEmpty,
      );
    });

    testWidgets('jeda antar putaran benar-benar harus ditunggu', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const KalibrasiTekananDarahPage(),
        controller: c,
      );
      await mulaiKalibrasi(tester);
      await jalankanPutaran(tester);

      final lanjut = find.widgetWithText(ElevatedButton, 'Mulai Putaran 2');
      expect(tester.widget<ElevatedButton>(lanjut).onPressed, isNull);
      expect(find.textContaining('membaca lebih tinggi'), findsOneWidget);

      await tester.pump(const Duration(seconds: 30));
      expect(tester.widget<ElevatedButton>(lanjut).onPressed, isNull);

      await tester.pump(const Duration(seconds: 30));
      expect(tester.widget<ElevatedButton>(lanjut).onPressed, isNotNull);
    });

    testWidgets('tiga putaran, koreksinya median, lalu dikirim ke jam', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const KalibrasiTekananDarahPage(),
        controller: c,
      );
      await mulaiKalibrasi(tester);

      await jalankanPutaran(tester);
      await lewatiJeda(tester);
      await jalankanPutaran(tester);
      await lewatiJeda(tester);
      await jalankanPutaran(tester);

      // Selisih jam: 124-121=3, 124-119=5, 124-118=6 → median 5.
      expect(find.text('Koreksi +5/+5 mmHg'), findsOneWidget);

      await tester.tap(find.text('Kirim ke Jam'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final kalibrasi = c.kalibrasiTerakhir!;
      expect(kalibrasi.putaran.length, Kalibrasi.jumlahPutaran);
      expect(kalibrasi.offsetSistolik, 5);
      expect(kalibrasi.sisi, SisiPergelangan.kiri);
      expect(c.kalibrasiKedaluwarsa, isFalse);
    });

    testWidgets('putaran yang saling bertentangan tidak boleh dikirim', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const KalibrasiTekananDarahPage(),
        controller: c,
      );
      await mulaiKalibrasi(tester);

      await jalankanPutaran(tester);
      await lewatiJeda(tester);
      // Putaran kedua jauh berbeda — misalnya user baru saja berjalan.
      await jalankanPutaran(tester, sistolik: 165, diastolik: 110);
      await lewatiJeda(tester);
      await jalankanPutaran(tester);

      expect(find.text('Hasilnya belum bisa dipakai'), findsOneWidget);
      expect(
        find.textContaining('Selisih antar putaran terlalu jauh'),
        findsOneWidget,
      );
      // Tidak ada jalan mengirimnya; yang ditawarkan hanya mengulang.
      expect(find.text('Kirim ke Jam'), findsNothing);
      expect(find.text('Ulangi Kalibrasi'), findsOneWidget);
      expect(c.kalibrasiTerakhir, isNull);
    });
  });

  group('Status perangkat', () {
    testWidgets('jam terputus tidak menampilkan baterai sama sekali', (
      tester,
    ) async {
      // Fixture-nya sengaja masih membawa `baterai: 41` — yang diuji justru
      // bahwa angka itu tidak sampai ke layar. Baterai hanya terbaca selagi
      // tautan hidup, jadi angka milik jam yang sudah lepas cuma menua.
      final c = buatControllerUji(status: contohPerangkatTerputus);
      await pumpHalaman(
        tester,
        const MenghubungkanPerangkatPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );
      await tester.pumpAndSettle();

      expect(find.text('Jam Terputus'), findsOneWidget);
      expect(find.text('41%'), findsNothing);
      expect(find.text('Baterai'), findsNothing);
      expect(find.text('Data belum diambil'), findsOneWidget);
      expect(find.text('menunggu jam didekatkan'), findsOneWidget);
      expect(find.text('Belum pernah sinkron'), findsOneWidget);
    });

    testWidgets('jam tersambung menampilkan baterai', (tester) async {
      final c = buatControllerUji(status: contohPerangkatTersambung);
      await pumpHalaman(
        tester,
        const MenghubungkanPerangkatPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );
      await tester.pumpAndSettle();

      expect(find.text('Baterai'), findsOneWidget);
      expect(find.text('68%'), findsOneWidget);
      // Buffer ditarik otomatis di tiap koneksi, jadi nol adalah keadaan
      // normal — dan petak yang seumur pemakaian menampilkan nol bukan kabar
      // baik, melainkan angka yang mengundang pertanyaan apakah ada yang
      // rusak. Yang menenangkan sudah ada di atasnya: "Sinkron terakhir …".
      expect(find.text('Data belum diambil'), findsNothing);
      expect(find.textContaining('tertunda'), findsNothing);
    });

    testWidgets('baris status menyebut data, bukan "sampel"', (tester) async {
      // Jam terputus dengan 2 data tertahan: kalimatnya harus mengatakan
      // bahwa data itu menunggu di jam, bukan memakai kosakata protokol.
      final c = buatControllerUji(status: contohPerangkatTerputus);
      await pumpHalaman(
        tester,
        const Scaffold(body: BerandaTab()),
        controller: c,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('2 data menunggu di jam'), findsOneWidget);
      expect(find.textContaining('sampel'), findsNothing);
    });

    testWidgets('menyinkronkan memperbarui waktu sinkron terakhir', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const MenghubungkanPerangkatPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sinkronkan'));
      await tester.pump();

      // Perintah BLE-nya selesai dalam hitungan milidetik dan tidak mengubah
      // apa pun di layar, jadi tombolnya sendiri yang harus mengaku sedang
      // bekerja — kalau tidak, tekanan kedua dan ketiga cuma soal waktu.
      expect(find.text('Menyinkronkan'), findsOneWidget);
      expect(find.text('Belum pernah sinkron'), findsNothing);
      expect(find.textContaining('Sinkron terakhir'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump();
      expect(find.text('Terkirim'), findsOneWidget);

      // Lalu kembali seperti semula, siap ditekan lagi.
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
      expect(find.text('Sinkronkan'), findsOneWidget);
    });

    testWidgets('tekanan kedua saat sinkronisasi berjalan diabaikan', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const MenghubungkanPerangkatPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Sinkronkan'));
      await tester.pump();

      final tombol = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Menyinkronkan'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(tombol.onPressed, isNull);

      // Habiskan animasi dan jeda "Terkirim" supaya tidak ada timer tersisa.
      await tester.pump(const Duration(milliseconds: 900));
      await tester.pump(const Duration(milliseconds: 1600));
      await tester.pump();
    });

    testWidgets('jam yang putus tidak bisa disinkronkan', (tester) async {
      final c = buatControllerUji(status: contohPerangkatTerputus);
      await pumpHalaman(
        tester,
        const MenghubungkanPerangkatPage(izin: IzinBleSelaluBoleh()),
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
        const MenghubungkanPerangkatPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );
      await tester.pumpAndSettle();

      expect(find.text('Belum Ada Jam'), findsOneWidget);
      expect(find.text('Belum ada perangkat dipasangkan'), findsOneWidget);
      expect(find.text('Pindai & Sambungkan'), findsOneWidget);
      expect(find.text('Putuskan'), findsNothing);

      // Semuanya milik sebuah jam, dan jamnya tidak ada. Tombol mati akan
      // berarti "nanti bisa", padahal yang dibutuhkan lebih dulu adalah
      // memasang jam.
      expect(find.text('Sinkronkan'), findsNothing);
      expect(find.text('Sampel tertunda'), findsNothing);
      expect(find.text('Belum pernah sinkron'), findsNothing);
    });

    testWidgets(
      'jam yang dipasangkan tetapi putus tetap bisa menunggu sinkron',
      (tester) async {
        // Kebalikan dari kasus di atas: jamnya ada, buffer-nya nyata, jadi
        // tombolnya tetap tampil — mati sekarang, hidup sendiri begitu
        // tersambung lagi.
        final c = buatControllerUji(status: contohPerangkatTerputus);
        await pumpHalaman(
          tester,
          const MenghubungkanPerangkatPage(izin: IzinBleSelaluBoleh()),
          controller: c,
        );
        await tester.pumpAndSettle();

        expect(find.text('Sinkronkan'), findsOneWidget);
        expect(find.text('Data belum diambil'), findsOneWidget);
        expect(
          tester
              .widget<ElevatedButton>(
                find.ancestor(
                  of: find.text('Sinkronkan'),
                  matching: find.byType(ElevatedButton),
                ),
              )
              .onPressed,
          isNull,
        );
      },
    );

    testWidgets('jam yang sudah dipasangkan menawarkan ganti dan putus', (
      tester,
    ) async {
      final c = buatControllerUji(status: contohPerangkatTersambung);
      await pumpHalaman(
        tester,
        const MenghubungkanPerangkatPage(izin: IzinBleSelaluBoleh()),
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
        const MenghubungkanPerangkatPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pindai & Sambungkan'));
      await tester.pumpAndSettle();

      expect(find.byType(PemindaianPerangkatPage), findsOneWidget);
      expect(find.text('AsaWatch X1'), findsOneWidget);
      expect(find.text('AsaWatch S2'), findsOneWidget);
      // Perangkat asing ada di udara (lihat katalog `FakeBleService`) tetapi
      // disaring service UUID di level OS, jadi ia tidak pernah sampai ke
      // aplikasi sama sekali.
      expect(find.text('Perangkat BLE tidak dikenal'), findsNothing);
      expect(find.text('2 perangkat ditemukan'), findsOneWidget);

      await tester.tap(find.text('AsaWatch X1'));
      await tester.pumpAndSettle();

      // Kembali ke halaman status dengan jam yang sudah tersambung.
      expect(find.byType(PemindaianPerangkatPage), findsNothing);
      expect(find.text('Jam Tersambung'), findsOneWidget);
      expect(c.statusPerangkat.namaPerangkat, 'AsaWatch X1');
      expect(find.text('Tersambung ke AsaWatch X1'), findsOneWidget);
    });

    testWidgets('perangkat non-AsaWatch tidak pernah sampai ke daftar', (
      tester,
    ) async {
      // Penyaringan service UUID dilakukan di level OS (protokol §2.2), jadi
      // yang diuji bukan lagi "tidak bisa dipilih" melainkan "tidak pernah ada".
      // Katalog `FakeBleService` tetap memuat perangkat asing itu supaya
      // penyaringannya benar-benar terlihat sedang menyaring sesuatu.
      final c = buatControllerUji(status: contohPerangkatBelumDipasangkan);
      await pumpHalaman(
        tester,
        const PemindaianPerangkatPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );
      await tester.pumpAndSettle();

      expect(find.text('Perangkat BLE tidak dikenal'), findsNothing);
      expect(find.text('Tidak didukung aplikasi ini'), findsNothing);
      expect(c.statusPerangkat.tersambung, isFalse);
    });

    testWidgets('halaman menjelaskan bahwa hanya AsaWatch yang dicari', (
      tester,
    ) async {
      // Kompensasi atas hilangnya bukti murah bahwa radionya bekerja: sebelum
      // penyaringan ini ada, headset tetangga yang ikut muncul sudah cukup
      // menjadi bukti. Sekarang halamannya harus mengatakannya sendiri, atau
      // daftar kosong akan terbaca sebagai aplikasi yang rusak.
      final c = buatControllerUji(status: contohPerangkatBelumDipasangkan);
      await pumpHalaman(
        tester,
        const PemindaianPerangkatPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Hanya jam AsaWatch yang dicari'),
        findsOneWidget,
      );
    });

    testWidgets('izin ditolak permanen menawarkan Pengaturan, bukan spinner', (
      tester,
    ) async {
      // rencana-produksi.md §4.4. Pemindaian tanpa izin di Android tidak
      // melempar apa pun — ia hanya tidak menemukan apa-apa, dan layar yang
      // diam terbaca persis seperti jam yang mati.
      final c = buatControllerUji(status: contohPerangkatBelumDipasangkan);
      await pumpHalaman(
        tester,
        PemindaianPerangkatPage(izin: _IzinPalsu(HasilIzinBle.ditolakPermanen)),
        controller: c,
      );
      await tester.pumpAndSettle();

      expect(find.text('Buka Pengaturan'), findsOneWidget);
      expect(find.text('AsaWatch X1'), findsNothing);
      expect(find.text('Tidak ada perangkat ditemukan'), findsNothing);
    });

    testWidgets('izin ditolak sekali menawarkan coba lagi', (tester) async {
      final c = buatControllerUji(status: contohPerangkatBelumDipasangkan);
      await pumpHalaman(
        tester,
        PemindaianPerangkatPage(izin: _IzinPalsu(HasilIzinBle.ditolak)),
        controller: c,
      );
      await tester.pumpAndSettle();

      // Penolakan sekali masih bisa dibalik tanpa meninggalkan aplikasi, jadi
      // tombol Pengaturan di sini justru menyesatkan.
      expect(find.text('Coba Lagi'), findsOneWidget);
      expect(find.text('Buka Pengaturan'), findsNothing);
    });

    testWidgets('bluetooth mati dijelaskan sebagai bluetooth mati', (
      tester,
    ) async {
      final c = buatControllerUji(status: contohPerangkatBelumDipasangkan);
      await pumpHalaman(
        tester,
        // Platform tanpa `ACTION_REQUEST_ENABLE`, yaitu iOS.
        PemindaianPerangkatPage(izin: _IzinPalsu(HasilIzinBle.bluetoothMati)),
        controller: c,
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('Nyalakan Bluetooth'), findsOneWidget);
      expect(find.text('Buka Pengaturan'), findsNothing);
      // Tombolnya tidak ditawarkan di tempat yang tidak bisa memenuhinya;
      // yang ada di layar hanya kalimat pada kartunya.
      expect(
        find.widgetWithText(ElevatedButton, 'Nyalakan Bluetooth'),
        findsNothing,
      );
    });

    testWidgets('bluetooth mati bisa dinyalakan dari dalam aplikasi', (
      tester,
    ) async {
      final izin = _IzinPalsu(HasilIzinBle.bluetoothMati, bisaMenyalakan: true);
      final c = buatControllerUji(status: contohPerangkatBelumDipasangkan);
      await pumpHalaman(
        tester,
        PemindaianPerangkatPage(izin: izin),
        controller: c,
      );
      await tester.pumpAndSettle();

      await tester.tap(
        find.widgetWithText(ElevatedButton, 'Nyalakan Bluetooth'),
      );
      await tester.pumpAndSettle();

      expect(izin.jumlahNyalakan, 1);
      // Menyalakan saja tidak cukup: pemindaian harus jalan lagi sendiri,
      // karena pengguna sudah menekan "Pindai" sekali dan tidak seharusnya
      // diminta menekannya lagi.
      expect(find.text('AsaWatch X1'), findsOneWidget);
      expect(find.textContaining('Bluetooth ponsel sedang mati'), findsNothing);
    });

    testWidgets(
      'menolak dialog sistem tidak memindai dan tidak menutup kartu',
      (tester) async {
        final izin = _IzinPalsu(
          HasilIzinBle.bluetoothMati,
          bisaMenyalakan: true,
          hasilNyalakan: HasilNyalakanBluetooth.ditolakPengguna,
        );
        final c = buatControllerUji(status: contohPerangkatBelumDipasangkan);
        await pumpHalaman(
          tester,
          PemindaianPerangkatPage(izin: izin),
          controller: c,
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.widgetWithText(ElevatedButton, 'Nyalakan Bluetooth'),
        );
        await tester.pumpAndSettle();

        expect(find.text('AsaWatch X1'), findsNothing);
        expect(
          find.textContaining('Bluetooth ponsel sedang mati'),
          findsOneWidget,
        );
        expect(
          find.text('Bluetooth masih mati. Nyalakan untuk mencari jam.'),
          findsOneWidget,
        );
        // Tombolnya kembali bisa ditekan: menolak sekali bukan jalan buntu.
        final tombol = tester.widget<ElevatedButton>(
          find.widgetWithText(ElevatedButton, 'Nyalakan Bluetooth'),
        );
        expect(tombol.onPressed, isNotNull);
      },
    );
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

/// Izin dengan hasil yang sudah ditentukan — satu-satunya cara menguji ketiga
/// jalan buntu izin tanpa saluran platform.
///
/// [bisaMenyalakan] meniru perbedaan platform, bukan sekadar saklar uji: hanya
/// Android yang punya `ACTION_REQUEST_ENABLE`, jadi tombol "Nyalakan Bluetooth"
/// memang harus hilang di tempat lain.
class _IzinPalsu implements IzinBle {
  _IzinPalsu(
    this.hasil, {
    this.bisaMenyalakan = false,
    this.hasilNyalakan = HasilNyalakanBluetooth.menyala,
  });

  HasilIzinBle hasil;
  final bool bisaMenyalakan;
  final HasilNyalakanBluetooth hasilNyalakan;

  /// Berapa kali dialog sistem diminta. Membuktikan tombol yang terkunci
  /// benar-benar tidak mengirim permintaan kedua — yang tidak terlihat di layar.
  int jumlahNyalakan = 0;

  @override
  Future<HasilIzinBle> minta() async => hasil;

  @override
  bool get bisaMenyalakanBluetooth => bisaMenyalakan;

  @override
  Future<HasilNyalakanBluetooth> nyalakanBluetooth() async {
    jumlahNyalakan++;
    // Radio yang menyala mengubah jawaban `minta()` berikutnya; tanpa itu
    // pemindaian ulang akan menabrak kartu izin yang sama lagi.
    if (hasilNyalakan == HasilNyalakanBluetooth.menyala) {
      hasil = HasilIzinBle.diberikan;
    }
    return hasilNyalakan;
  }

  @override
  Future<bool> bukaPengaturan() async => true;
}
