// Alur penyandingan jam — docs/alur-pemasangan-jam.md §4.3–§5.
//
// Yang diuji di sini bukan radio, melainkan **apa yang dilihat pengguna saat
// penyandingan sedang menunggu dijawab** — satu-satunya momen di seluruh alur
// pemasangan yang menuntut tindakannya. Jalur-jalur itu tidak bisa dipesan pada
// jam sungguhan (dialog yang dibiarkan hangus, kunci yang basi), jadi
// `FakeBleService.penyandingan` yang menirukannya; tanpa itu seluruh copy di
// dokumen tersebut baru terlihat pertama kali di tangan pengguna.

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/controllers/sesi_makan_controller.dart';
import 'package:asawatch/menghubungkan_perangkat_page.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/pemindaian_perangkat_page.dart';
import 'package:asawatch/services/ble_service.dart';
import 'package:asawatch/services/izin_ble.dart';

import 'helpers.dart';

/// Jam palsu berkecepatan nyata: jeda di dalamnya harus **lebih lama** daripada
/// `jedaPetunjukNotifikasi` (8 detik), dan percepatan 3600 yang biasa dipakai
/// test lain akan memampatkan seluruh penyandingan menjadi sepersekian detik —
/// di situ tidak ada yang bisa diamati.
SesiMakanController _controller(PenyandinganPalsu penyandingan) {
  return buatControllerUji(
    ble: FakeBleService(
      percepatan: 1,
      otomatisSelesaiMakan: null,
      penyandingan: penyandingan,
    ),
  );
}

/// Membuka halaman pemindaian sampai jam muncul di daftar, lalu mengetuknya.
Future<SesiMakanController> _sampaiMenyandingkan(
  WidgetTester tester,
  PenyandinganPalsu penyandingan,
) async {
  final c = _controller(penyandingan);
  await pumpHalaman(
    tester,
    const PemindaianPerangkatPage(izin: IzinBleSelaluBoleh()),
    controller: c,
  );

  await tester.pump(); // izin selesai, pemindaian mulai
  await tester.pump(const Duration(seconds: 3)); // AsaWatch X1 terlihat

  await tester.tap(find.text('AsaWatch X1'));
  await tester.pump(); // tahap `menyambung` terkirim
  await tester.pump(const Duration(seconds: 4)); // masuk `menyandingkan`
  return c;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadMontserrat);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('Tahap penyandingan', () {
    testWidgets('meminta satu ketukan, dan mengatakan tidak ada kode', (
      tester,
    ) async {
      await _sampaiMenyandingkan(tester, PenyandinganPalsu.tidakDijawab);

      expect(
        find.textContaining('Ketuk "Sandingkan"'),
        findsOneWidget,
        reason: 'kata di aplikasi harus sama dengan tombol di dialog sistem',
      );
      // Pengguna yang terbiasa menyandingkan speaker akan mencari-cari "0000"
      // dan menyangka dirinya salah langkah bila ini tidak dikatakan.
      expect(find.textContaining('Tidak ada kode atau PIN'), findsOneWidget);

      await tester.pump(const Duration(seconds: 130));
    });

    testWidgets('mengambil alih halaman, daftar tidak lagi bisa diketuk', (
      tester,
    ) async {
      await _sampaiMenyandingkan(tester, PenyandinganPalsu.tidakDijawab);

      // Satu layar, satu tindakan: tidak ada jam lain untuk dipilih dan tidak
      // ada "Pindai Ulang" untuk ditekan tepat saat sistem sedang menunggu.
      expect(find.text('Pindai Ulang'), findsNothing);
      expect(find.text('AsaWatch S2'), findsNothing);
      expect(find.text('Batal'), findsOneWidget);

      await tester.pump(const Duration(seconds: 130));
    });

    testWidgets('petunjuk notifikasi baru muncul setelah lama tak dijawab', (
      tester,
    ) async {
      await _sampaiMenyandingkan(tester, PenyandinganPalsu.tidakDijawab);

      // Petunjuk yang muncul saat semuanya berjalan baik justru menimbulkan
      // ragu, jadi pengguna yang menjawab dengan normal tidak boleh melihatnya.
      expect(find.textContaining('Usap layar dari atas'), findsNothing);

      await tester.pump(const Duration(seconds: 9));
      expect(find.textContaining('Usap layar dari atas'), findsOneWidget);

      await tester.pump(const Duration(seconds: 130));
    });
  });

  group('Kegagalan penyandingan', () {
    testWidgets('yang ditolak menjelaskan kenapa penyandingan diperlukan', (
      tester,
    ) async {
      await _sampaiMenyandingkan(tester, PenyandinganPalsu.ditolak);
      await tester.pump(const Duration(seconds: 6));

      expect(find.textContaining('Penyandingan dibatalkan'), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
      // Penolakan bukan kunci basi: menawarkan penghapusan penyandingan di sini
      // hanya merusak pemasangan yang sebenarnya sehat.
      expect(find.text('Sandingkan ulang jam ini'), findsNothing);
    });

    testWidgets('yang tidak dijawab menunjuk ke permintaannya, bukan menyerah', (
      tester,
    ) async {
      await _sampaiMenyandingkan(tester, PenyandinganPalsu.tidakDijawab);
      await tester.pump(const Duration(seconds: 130));

      expect(
        find.textContaining('belum dijawab'),
        findsOneWidget,
        reason: 'sebabnya berbeda dari ditolak, jadi kalimatnya juga berbeda',
      );
      expect(find.text('Coba Lagi'), findsOneWidget);
    });

    testWidgets('kunci basi menawarkan sanding ulang sebagai jalan kedua', (
      tester,
    ) async {
      await _sampaiMenyandingkan(tester, PenyandinganPalsu.bondBasi);
      await tester.pump(const Duration(seconds: 6));

      expect(find.textContaining('tidak lagi saling mengenali'), findsOneWidget);
      // Urutannya penting: dugaan kunci basi bisa salah, jadi tindakan yang
      // tidak merusak apa pun tetap yang utama.
      expect(find.text('Coba Lagi'), findsOneWidget);
      expect(find.text('Sandingkan ulang jam ini'), findsOneWidget);
    });

    testWidgets('sanding ulang menghapus kunci lama lalu berhasil menyambung', (
      tester,
    ) async {
      final c = await _sampaiMenyandingkan(tester, PenyandinganPalsu.bondBasi);
      await tester.pump(const Duration(seconds: 6));

      await tester.tap(find.text('Sandingkan ulang jam ini'));
      await tester.pump(); // penghapusan bond
      await tester.pump(const Duration(seconds: 12)); // sambung + sanding ulang

      expect(c.statusPerangkat.tersambung, isTrue);
      expect(c.statusPerangkat.namaPerangkat, 'AsaWatch X1');
    });
  });

  group('Melepas pemasangan', () {
    /// Jam yang sudah dipasangkan dan tersambung, siap dilepas.
    Future<SesiMakanController> bukaStatus(WidgetTester tester) async {
      final c = buatControllerUji(
        ble: FakeBleService(
          percepatan: 1,
          otomatisSelesaiMakan: null,
          status: const StatusPerangkat(
            tersambung: true,
            baterai: 68,
            sampelTertunda: 3,
            namaPerangkat: 'AsaWatch X1',
          ),
        ),
      );
      await pumpHalaman(
        tester,
        const MenghubungkanPerangkatPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );
      await tester.pump();
      return c;
    }

    testWidgets('dikonfirmasi dulu, dan menyebut data yang akan hilang', (
      tester,
    ) async {
      await bukaStatus(tester);

      await tester.tap(find.text('Lupakan Jam Ini'));
      await tester.pumpAndSettle();

      expect(find.text('Lupakan AsaWatch X1?'), findsOneWidget);
      // Angkanya disebut apa adanya: "beberapa data akan hilang" tidak cukup
      // untuk memutuskan.
      expect(find.textContaining('3 data'), findsOneWidget);
      expect(find.textContaining('Riwayat yang sudah tersimpan'), findsOneWidget);
    });

    testWidgets('batal tidak melepas apa pun', (tester) async {
      final c = await bukaStatus(tester);

      await tester.tap(find.text('Lupakan Jam Ini'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();

      expect(c.statusPerangkat.namaPerangkat, 'AsaWatch X1');
      expect(c.statusPerangkat.belumDipasangkan, isFalse);
    });

    testWidgets('setelah dilupakan, jam kembali seperti belum pernah ada', (
      tester,
    ) async {
      final c = await bukaStatus(tester);

      await tester.tap(find.text('Lupakan Jam Ini'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lupakan'));
      await tester.pumpAndSettle();

      // Namanya ikut hilang — justru itulah yang membedakan "belum pernah
      // dipasangkan" dari "dipasangkan tetapi di luar jangkauan".
      expect(c.statusPerangkat.belumDipasangkan, isTrue);
      expect(c.statusPerangkat.tersambung, isFalse);
      expect(find.text('Belum Ada Jam'), findsOneWidget);
    });
  });

  group('Penyandingan yang hilang di luar aplikasi', () {
    testWidgets('dikatakan sebabnya, dan mengajak menyandingkan bukan menyambung', (
      tester,
    ) async {
      final c = buatControllerUji(
        ble: FakeBleService(
          percepatan: 1,
          otomatisSelesaiMakan: null,
          // Keadaan yang dilaporkan `BleAsliService` saat jam masih dicatat
          // aplikasi tetapi ponsel sudah tidak menyandingkannya.
          status: const StatusPerangkat(
            tersambung: false,
            namaPerangkat: 'AsaWatch X1',
            penyandinganHilang: true,
          ),
        ),
      );
      await pumpHalaman(
        tester,
        const MenghubungkanPerangkatPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );
      await tester.pump();

      expect(find.text('Jam Tidak Tersandingkan'), findsOneWidget);
      expect(find.text('Dihapus dari Bluetooth ponsel'), findsOneWidget);
      // "Sambungkan Ulang" akan berbohong: menyambung saja tidak akan pernah
      // berhasil sampai jamnya disandingkan lagi.
      expect(find.text('Sandingkan Ulang'), findsOneWidget);
      expect(find.text('Sambungkan Ulang'), findsNothing);
    });
  });

  group('Langkah pemasangan', () {
    testWidgets('menyebut penyandingan sebagai langkahnya sendiri', (
      tester,
    ) async {
      await pumpHalaman(
        tester,
        const MenghubungkanPerangkatPage(izin: IzinBleSelaluBoleh()),
      );
      await tester.pump();

      // Sebelumnya penyandingan tersembunyi di dalam "tunggu hingga proses
      // koneksi selesai", dan itulah langkah yang paling sering menghentikan
      // pemasangan tanpa penjelasan.
      expect(find.textContaining('ketuk "Sandingkan"'), findsOneWidget);
      expect(find.textContaining('hanya dilakukan sekali'), findsOneWidget);
    });
  });
}
