// Dua tombol untuk satu titik ukur — docs/jadwal-titik-ukur.md §9.
//
// Sejak protokol v1.3, jam tidak lagi menjadwalkan titik ukurnya sendiri: ia
// tidak bertahan lebih dari ~50 menit menyala sementara sesi berdurasi lebih
// dari dua jam, jadi ia dimatikan di antara pengukuran. Yang menggantikan
// penjadwal itu adalah dua tombol — satu di aplikasi, satu di jam — dan berkas
// ini menguji bahwa keduanya bermuara di tempat yang sama.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/controllers/sesi_makan_controller.dart';
import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/jadwal_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/services/ble_service.dart';
import 'package:asawatch/beranda_tab.dart';
import 'package:asawatch/sesi_berjalan_page.dart';

import 'package:asawatch/services/pengingat_titik_ukur.dart';

import 'helpers.dart';

/// Mencatat apa yang dijadwalkan, tanpa menyentuh platform channel.
class PengingatPencatat implements PengingatTitikUkur {
  final List<({DateTime t0, List<int> index})> panggilan = [];
  int dibatalkan = 0;

  @override
  Future<void> jadwalkan({
    required DateTime t0,
    required List<TitikJadwal> titik,
    required DateTime sekarang,
  }) async {
    panggilan.add((t0: t0, index: titik.map((t) => t.index).toList()));
  }

  @override
  Future<void> batalkanSemua() async => dibatalkan++;
}

/// Jadwal yang jendelanya benar-benar punya jarak, supaya "belum waktunya"
/// bisa diamati. `jadwalNormal.dibagi(3600)` yang dipakai helper memampatkan
/// jendela `+1 jam` sampai terbuka pada detik ke-0.
final jadwalUjiTitik = jadwalNormal.dibagi(60);

Future<void> jalankan(WidgetTester tester, SesiMakanController c) async {
  await c.mulaiDraft(contohFotoPath);
  await tester.pump(const Duration(milliseconds: 50));
  await tekanTombolJam(tester, c);
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMontserrat);

  group('Tombol ukur di aplikasi', () {
    testWidgets('tidak muncul sebelum t0 ada', (tester) async {
      final c = buatControllerUji();
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));

      // Sebelum tombol jam ditekan tidak ada titik ukur yang punya waktu, jadi
      // tombol yang mengukurnya hanya akan mengundang ketukan yang tidak
      // menghasilkan apa-apa.
      expect(c.titikBerikutnya, isNull);
      expect(find.textContaining('Ukur '), findsNothing);

      await hentikanSesi(tester, c);
    });

    testWidgets('sebelum jendela terbuka: hitung mundur, tombol mati', (
      tester,
    ) async {
      final jam = JamPalsu();
      final c = buatControllerUji(
        percepatan: 3600,
        lewatkan: {2, 3},
        jadwal: jadwalUjiTitik,
        jam: jam.call,
      );
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankan(tester, c);

      expect(c.titikBerikutnya!.index, 2);
      expect(c.sisaSampaiTitikBerikutnya!.inSeconds, greaterThan(0));

      // Terlalu cepat **ditahan**, bukan ditandai: titiknya belum lewat dan
      // masih bisa diukur dengan benar sebentar lagi (§3).
      final galat = await c.ukurTitikSekarang();
      expect(galat, contains('belum waktunya'));
      expect(c.sesiAktif!.sampel[2].status, StatusSampel.menunggu);

      await hentikanSesi(tester, c);
    });

    testWidgets('di dalam jendela tombolnya mengukur dan titiknya terisi', (
      tester,
    ) async {
      final ble = FakeBleService(
        percepatan: 3600,
        lewatkan: {2, 3},
        otomatisSelesaiMakan: null,
      );
      final jam = JamPalsu();
      final c = buatControllerUji(ble: ble, jadwal: jadwalUjiTitik, jam: jam.call);
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankan(tester, c);

      // Melewati batas awal jendela (+55 detik pada jadwal ini).
      await majuBersama(tester, jam, const Duration(seconds: 56));
      expect(c.sisaSampaiTitikBerikutnya!.inSeconds, lessThanOrEqualTo(0));

      // `lewatkan` hanya menahan pengukuran yang dijadwalkan jam; perintah dari
      // aplikasi tetap dilayani jam sungguhan, jadi di sini dibuka lagi.
      ble.lewatkan.clear();
      expect(await c.ukurTitikSekarang(), isNull);
      await tester.pump(const Duration(seconds: 1));

      expect(c.sesiAktif!.sampel[2].status, StatusSampel.terisi);

      await hentikanSesi(tester, c);
    });

    // Titik ukur diminta lewat notifikasi, jadi tombolnya harus ada di layar
    // yang dibuka pertama kali dan bukan hanya satu ketukan lebih dalam. Sebelum
    // t0 kartu Beranda tetap milik PetunjukTombolJam.
    testWidgets('juga muncul di Beranda selama sesi berjalan', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final ble = FakeBleService(
        percepatan: 3600,
        lewatkan: {2, 3},
        otomatisSelesaiMakan: null,
      );
      final jam = JamPalsu();
      final c = buatControllerUji(ble: ble, jadwal: jadwalUjiTitik, jam: jam.call);
      await pumpHalaman(
        tester,
        const Scaffold(body: BerandaTab()),
        controller: c,
      );
      await jalankan(tester, c);

      await majuBersama(tester, jam, const Duration(seconds: 56));
      expect(find.text('Ukur +1 jam Sekarang'), findsOneWidget);

      // Tetap berdampingan dengan pintu ke halaman sesi, bukan menggantikannya.
      expect(find.text('Buka Sesi'), findsOneWidget);

      // Dan ia berdiri **di atas** timeline dan kartu foto, bukan di dasar
      // kartu. Hitung mundur di baris teratas yang tombolnya ada di bawah
      // lipatan layar memaksa pembacanya menebak bahwa ada yang harus ditekan,
      // lalu mencarinya.
      final tombol = tester.getTopLeft(find.text('Ukur +1 jam Sekarang')).dy;
      expect(tombol, lessThan(tester.getTopLeft(find.text('Baseline')).dy));
      expect(tombol, lessThan(tester.getTopLeft(find.text('Buka Sesi')).dy));
      // Terlihat tanpa menggulir pada ponsel 412x915.
      expect(tombol, lessThan(915));

      await hentikanSesi(tester, c);
    });

    testWidgets('jam yang terputus menjelaskan sebabnya, bukan diam', (
      tester,
    ) async {
      final ble = FakeBleService(
        percepatan: 3600,
        lewatkan: {2, 3},
        otomatisSelesaiMakan: null,
      );
      final jam = JamPalsu();
      final c = buatControllerUji(ble: ble, jadwal: jadwalUjiTitik, jam: jam.call);
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankan(tester, c);
      await majuBersama(tester, jam, const Duration(seconds: 56));

      await ble.putuskan();
      await tester.pump();

      final galat = await c.ukurTitikSekarang();
      expect(galat, isNotNull);
      expect(galat, contains('Nyalakan jam'));

      await hentikanSesi(tester, c);
    });

    testWidgets('baseline yang sedang diukur ikut dikabarkan', (tester) async {
      // Baseline diminta tepat saat rana kamera ditekan, jadi ia berjalan
      // sebelum sesinya punya t0 — dan karena itu sebelum `PetunjukTombolUkur`
      // ada di layar sama sekali. Ia satu-satunya pengukuran yang terjadi tanpa
      // diminta pengguna, sehingga jam yang bekerja diam-diam paling mudah
      // terbaca sebagai jam yang tidak melakukan apa-apa.
      final ble = FakeBleService(
        percepatan: 60, // pengukuran palsu ~330 ms
        otomatisSelesaiMakan: null,
      );
      final c = buatControllerUji(ble: ble, jadwal: jadwalUjiTitik);
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 120));

      expect(c.sesiAktif!.t0, isNull, reason: 'masih draft, belum ada t0');
      expect(find.textContaining('mengukur baseline'), findsOneWidget);

      // Tombol "Selesai Makan" **tidak** ikut mati: firmware sengaja tidak
      // memeriksa `s_ukur_aktif` saat tombolnya ditekan (§9), dan orang yang
      // selesai makan tidak boleh menunggu sensor.
      final tombol = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.textContaining('Selesai Makan'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(tombol.onPressed, isNotNull);

      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('mengukur baseline'), findsNothing);

      await hentikanSesi(tester, c);
    });

    testWidgets('selama jam mengukur, kartunya menampilkan kemajuannya', (
      tester,
    ) async {
      // Sebelum ini, satu-satunya perubahan di layar adalah "Mengukur…" yang
      // hidup sampai ACK — sepersekian detik — lalu tombolnya menyala lagi
      // sementara jamnya masih bekerja puluhan detik. Denyutnya sudah datang
      // sejak §5.5 v1.4; yang kurang hanya yang memancarkannya, karena titik
      // ukur sesi tidak punya penantian di aplikasi seperti `ukurSekarang()`.
      final ble = FakeBleService(
        percepatan: 60, // pengukuran palsu ~330 ms: cukup untuk dilihat
        lewatkan: {2, 3},
        otomatisSelesaiMakan: null,
      );
      final jam = JamPalsu();
      final c = buatControllerUji(
        ble: ble,
        jadwal: jadwalUjiTitik,
        jam: jam.call,
      );
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 500));
      await tekanTombolJam(tester, c);
      await tester.pump(const Duration(milliseconds: 500));

      await majuBersama(tester, jam, const Duration(seconds: 56));
      ble.lewatkan.clear();

      await tester.tap(find.textContaining('Ukur '));
      await tester.pump(const Duration(milliseconds: 120));

      // Kemajuannya datang dari jam, bukan dari hitungan layar.
      expect(c.kemajuanUkur, isNotNull);
      // Persennya ada di label tombolnya sendiri — halaman ini penuh angka
      // ber-% lain (baterai, SpO2), jadi yang dicari adalah label itu.
      expect(find.textContaining(RegExp(r'Jam mengukur… \d+%')), findsOneWidget);
      expect(find.textContaining('Perkiraan sisa'), findsWidgets);

      // Tombolnya tetap mati selama jam bekerja — bukan menyala kembali
      // beberapa milidetik setelah ACK.
      final tombol = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.textContaining('Jam mengukur…'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(tombol.onPressed, isNull);

      await tester.pump(const Duration(milliseconds: 400));
      expect(c.kemajuanUkur, isNull);

      await hentikanSesi(tester, c);
    });

    testWidgets('baterai kritis mematikan tombol sebelum perintahnya dikirim', (
      tester,
    ) async {
      // Di bawah 10% jam men-`NAK` setiap `UKUR` (§5.5 bit2, §7 kode 0x06).
      // Tombol yang tetap menyala mengundang tekanan berulang yang semuanya
      // ditolak — dan sebabnya baru terbaca sesudah orangnya menekan.
      final ble = FakeBleService(
        percepatan: 3600,
        lewatkan: {2, 3},
        otomatisSelesaiMakan: null,
        status: const StatusPerangkat(
          tersambung: true,
          baterai: 7,
          namaPerangkat: 'AsaWatch X1',
          bateraiKritis: true,
        ),
      );
      final jam = JamPalsu();
      final c = buatControllerUji(
        ble: ble,
        jadwal: jadwalUjiTitik,
        jam: jam.call,
      );
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankan(tester, c);
      await majuBersama(tester, jam, const Duration(seconds: 56));

      // Jendelanya sudah terbuka — yang menahan hanyalah baterainya.
      expect(c.sisaSampaiTitikBerikutnya!.inSeconds, lessThanOrEqualTo(0));

      final tombol = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.textContaining('Ukur '),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(tombol.onPressed, isNull);
      expect(find.textContaining('menolak mengukur'), findsWidgets);
      // Bukan "belum tersambung": jamnya tersambung dan justru sedang
      // melaporkan keadaannya.
      expect(find.text('Jam belum tersambung'), findsNothing);

      final galat = await c.ukurTitikSekarang();
      expect(galat, contains('10%'));
      expect(c.sesiAktif!.sampel[2].status, StatusSampel.menunggu);

      await hentikanSesi(tester, c);
    });
  });

  group('Tombol ukur di jam (ARM_TITIK)', () {
    testWidgets('belum di-ARM selama jendelanya belum terbuka', (
      tester,
    ) async {
      final ble = FakeBleService(
        percepatan: 3600,
        lewatkan: {2, 3},
        otomatisSelesaiMakan: null,
      );
      final jam = JamPalsu();
      final c = buatControllerUji(ble: ble, jadwal: jadwalUjiTitik, jam: jam.call);
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankan(tester, c);

      // Sejak `detik_tunda` dibuang dari kawat, penjaga "jangan diukur terlalu
      // cepat" ada sepenuhnya di sisi aplikasi: perintahnya belum dikirim sama
      // sekali, jadi tidak ada yang bisa salah di jam.
      expect(ble.titikDiarm, isNull);
      expect(ble.tombolUkurMenyala, isFalse);


      await hentikanSesi(tester, c);
    });

    testWidgets('tombolnya padam sampai penundaannya lewat', (tester) async {
      final ble = FakeBleService(
        percepatan: 3600,
        lewatkan: {2, 3},
        otomatisSelesaiMakan: null,
      );
      final jam = JamPalsu();
      final c = buatControllerUji(ble: ble, jadwal: jadwalUjiTitik, jam: jam.call);
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankan(tester, c);

      // Inilah yang menegakkan batas awal jendela toleransi (§3.2): pengukuran
      // yang terlalu cepat tidak ditolak sesudah terjadi — ia tidak terjadi.
      expect(ble.tombolUkurMenyala, isFalse);
      expect(ble.tekanTombolUkur(), isFalse);

      await majuBersama(tester, jam, const Duration(seconds: 56));
      expect(ble.tombolUkurMenyala, isTrue);

      await hentikanSesi(tester, c);
    });

    // §9: `UKUR` untuk titik yang sedang ter-ARM memadamkan tombolnya. Tanpa
    // ini, jalur yang paling lazim — notifikasi berbunyi di ponsel yang sedang
    // dipegang, pengguna mengukur dari aplikasi — meninggalkan tombol jam
    // menyala untuk titik yang sudah terisi. Pengguna yang tidak yakin
    // pengukurannya berhasil akan menekannya juga.
    testWidgets('mengukur dari aplikasi memadamkan tombol jam', (tester) async {
      final ble = FakeBleService(
        percepatan: 3600,
        lewatkan: {2, 3},
        otomatisSelesaiMakan: null,
      );
      final jam = JamPalsu();
      final c = buatControllerUji(ble: ble, jadwal: jadwalUjiTitik, jam: jam.call);
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankan(tester, c);
      await majuBersama(tester, jam, const Duration(seconds: 56));

      expect(ble.tombolUkurMenyala, isTrue);

      ble.lewatkan.clear();
      expect(await c.ukurTitikSekarang(), isNull);
      await tester.pump(const Duration(seconds: 1));

      // Tombol menyala yang tidak menghasilkan apa-apa adalah kebohongan di
      // layar jam: ia berarti "ada yang menunggu ditekan", dan setelah titiknya
      // terukur tidak ada.
      expect(ble.tombolUkurMenyala, isFalse);
      expect(ble.tekanTombolUkur(), isFalse);

      await hentikanSesi(tester, c);
    });

    testWidgets('ditekan di jam mengisi titik yang sama', (tester) async {
      final ble = FakeBleService(
        percepatan: 3600,
        lewatkan: {2, 3},
        otomatisSelesaiMakan: null,
      );
      final jam = JamPalsu();
      final c = buatControllerUji(ble: ble, jadwal: jadwalUjiTitik, jam: jam.call);
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankan(tester, c);
      await majuBersama(tester, jam, const Duration(seconds: 56));

      expect(ble.tekanTombolUkur(), isTrue);
      await tester.pump(const Duration(milliseconds: 100));

      expect(c.sesiAktif!.sampel[2].status, StatusSampel.terisi);

      await hentikanSesi(tester, c);
    });

    testWidgets('padam sendiri setelah satu tekan', (tester) async {
      final ble = FakeBleService(
        percepatan: 3600,
        lewatkan: {2, 3},
        otomatisSelesaiMakan: null,
      );
      final jam = JamPalsu();
      final c = buatControllerUji(ble: ble, jadwal: jadwalUjiTitik, jam: jam.call);
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankan(tester, c);
      await majuBersama(tester, jam, const Duration(seconds: 56));

      expect(ble.tekanTombolUkur(), isTrue);
      // Tekanan kedua tidak boleh mengisi titik berikutnya dengan angka yang
      // diambil satu jam terlalu awal — dan titik yang sudah terisi tidak bisa
      // diperbaiki.
      expect(ble.tekanTombolUkur(), isFalse);

      // Sampelnya diproses dulu: kalau tidak, `batalkan()` membersihkan timer
      // jam palsu **sebelum** sampel itu sampai, lalu titik berikutnya di-ARM
      // sesudahnya dan meninggalkan timer menggantung.
      await tester.pump(const Duration(milliseconds: 100));
      await hentikanSesi(tester, c);
    });
  });

  group('Pengingat titik ukur', () {
    testWidgets('dijadwalkan begitu t0 ada, hanya untuk titik yang menunggu', (
      tester,
    ) async {
      final pengingat = PengingatPencatat();
      final jam = JamPalsu();
      final c = buatControllerUji(
        percepatan: 3600,
        lewatkan: {2, 3},
        jadwal: jadwalUjiTitik,
        jam: jam.call,
        pengingat: pengingat,
      );
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankan(tester, c);

      expect(pengingat.panggilan, isNotEmpty);
      // Baseline dan t0 tidak ikut: keduanya dipicu peristiwa, bukan jadwal,
      // jadi tidak ada apa pun untuk diingatkan.
      expect(pengingat.panggilan.last.index, [2, 3]);
      expect(pengingat.panggilan.last.t0, c.sesiAktif!.t0);

      await hentikanSesi(tester, c);
    });

    testWidgets('titik yang sudah terisi tidak diingatkan lagi', (tester) async {
      final pengingat = PengingatPencatat();
      final ble = FakeBleService(
        percepatan: 3600,
        lewatkan: {2, 3},
        otomatisSelesaiMakan: null,
      );
      final jam = JamPalsu();
      final c = buatControllerUji(
        ble: ble,
        jadwal: jadwalUjiTitik,
        jam: jam.call,
        pengingat: pengingat,
      );
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankan(tester, c);
      await majuBersama(tester, jam, const Duration(seconds: 56));

      ble.tekanTombolUkur();
      await tester.pump(const Duration(milliseconds: 100));

      // Pengingat yang menyuruh mengukur sesuatu yang sudah diukur adalah
      // pengingat yang membuat orang berhenti mempercayai pengingat.
      expect(pengingat.panggilan.last.index, [3]);

      await hentikanSesi(tester, c);
    });

    testWidgets('sesi yang dibatalkan menghapus pengingatnya', (tester) async {
      final pengingat = PengingatPencatat();
      final jam = JamPalsu();
      final c = buatControllerUji(
        percepatan: 3600,
        lewatkan: {2, 3},
        jadwal: jadwalUjiTitik,
        jam: jam.call,
        pengingat: pengingat,
      );
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await jalankan(tester, c);

      final sebelum = pengingat.dibatalkan;
      await hentikanSesi(tester, c);

      // Kalau tidak, ponsel akan berbunyi satu jam lagi menyuruh mengukur sesi
      // yang sudah tidak ada.
      expect(pengingat.dibatalkan, greaterThan(sebelum));
    });
  });

  testWidgets('dua tombol untuk satu titik hanya menghasilkan satu sampel', (
    tester,
  ) async {
    final ble = FakeBleService(
      percepatan: 3600,
      lewatkan: {2, 3},
      otomatisSelesaiMakan: null,
    );
    final jam = JamPalsu();
    final c = buatControllerUji(ble: ble, jadwal: jadwalUjiTitik, jam: jam.call);
    await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
    await jalankan(tester, c);
    await majuBersama(tester, jam, const Duration(seconds: 56));

    ble.lewatkan.clear();
    expect(ble.tekanTombolUkur(), isTrue);
    await c.ukurTitikSekarang();
    await tester.pump(const Duration(seconds: 1));

    // Dedup `(sesiId, index)` membuang yang kedua diam-diam. Tidak boleh ada
    // balapan yang terlihat pengguna.
    expect(c.sesiAktif!.sampel[2].status, StatusSampel.terisi);
    expect(c.sesiAktif!.sampel[3].status, StatusSampel.menunggu);

    await hentikanSesi(tester, c);
  });
}
