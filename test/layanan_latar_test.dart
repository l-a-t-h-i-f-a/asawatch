// Foreground service sesi — docs/rencana-produksi.md §7.1.
//
// Sesi berlangsung ~2,5 jam dan pengguna pasti meninggalkan aplikasi. Tanpa
// service ini Android membunuh prosesnya jauh sebelum titik `+1 jam` jatuh
// tempo, dan proses yang mati tidak bisa mengirim `UKUR`, tidak bisa mengirim
// `ARM_TITIK`, dan tidak bisa menyambung ulang.
//
// Yang diuji di sini adalah **kapan** service menyala dan berhenti, plus isi
// notifikasinya. Tak satu pun dari itu terlihat di layar mana pun, jadi tanpa
// berkas ini satu-satunya cara mengetahuinya adalah menunggu dua jam di depan
// ponsel sungguhan.

import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/jadwal_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/services/ble_service.dart';
import 'package:asawatch/services/layanan_latar.dart';
import 'package:asawatch/services/protokol_jam.dart';
import 'package:asawatch/sesi_berjalan_page.dart';

import 'helpers.dart';

/// Jendela yang benar-benar punya jarak, sama seperti `tombol_ukur_test.dart`:
/// `dibagi(3600)` yang dipakai helper memampatkan jendela `+1 jam` sampai
/// terbuka pada detik ke-0, sehingga "belum waktunya" tidak bisa diamati.
final jadwalUjiTitik = jadwalNormal.dibagi(60);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMontserrat);

  group('Service hidup selama sesi aktif', () {
    testWidgets('tidak menyala sama sekali bila tidak ada sesi', (tester) async {
      final layanan = LayananLatarPalsu();
      final c = buatControllerUji(layanan: layanan);
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      // Notifikasi permanen di luar sesi adalah notifikasi yang akan dimatikan
      // pengguna — dan channel yang dimatikan tetap mati saat titik ukur tiba.
      expect(layanan.jalan, isFalse);
      expect(layanan.catatan, isEmpty);
    });

    testWidgets('menyala sejak draft, sebelum tombol jam ditekan', (
      tester,
    ) async {
      final layanan = LayananLatarPalsu();
      final c = buatControllerUji(layanan: layanan);
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));

      // Draft adalah fase orang sedang makan dengan ponsel di meja: jam harus
      // tetap ter-ARM dan tersambung supaya tombolnya bekerja saat ditekan.
      expect(layanan.jalan, isTrue);
      expect(layanan.catatan.last.$2, contains('Selesai Makan'));

      await hentikanSesi(tester, c);
    });

    testWidgets('berhenti saat sesi dibatalkan', (tester) async {
      final layanan = LayananLatarPalsu();
      final c = buatControllerUji(layanan: layanan);
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));
      expect(layanan.jalan, isTrue);

      await hentikanSesi(tester, c);

      expect(layanan.jalan, isFalse);
      expect(layanan.jumlahHenti, greaterThan(0));
    });

    testWidgets('berhenti saat sesi selesai sendiri', (tester) async {
      final layanan = LayananLatarPalsu();
      final c = buatControllerUji(layanan: layanan);
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));
      await tekanTombolJam(tester, c);
      expect(layanan.jalan, isTrue);

      // Jam palsu dipercepat 3600x: seluruh jadwal sesi lewat dalam dua detik.
      await tester.pump(const Duration(seconds: 3));
      await tester.pump(const Duration(seconds: 1));

      expect(c.sesiAktif, isNull, reason: 'sesi seharusnya sudah selesai');
      expect(
        layanan.jalan,
        isFalse,
        reason: 'notifikasi permanen tanpa sesi tidak punya pemilik',
      );
    });
  });

  group('Isi notifikasi', () {
    testWidgets('menyebut hitung mundur ke titik berikutnya', (tester) async {
      final layanan = LayananLatarPalsu();
      final jam = JamPalsu();
      final c = buatControllerUji(
        percepatan: 3600,
        lewatkan: {2, 3},
        jadwal: jadwalUjiTitik,
        jam: jam.call,
        layanan: layanan,
      );
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));
      await tekanTombolJam(tester, c);
      await tester.pump(const Duration(milliseconds: 50));

      // Jendela `+1 jam` pada jadwal ini terbuka di detik ke-55, jadi masih ada
      // hitung mundur untuk dibaca.
      expect(c.sisaSampaiTitikBerikutnya!.inSeconds, greaterThan(0));
      expect(layanan.catatan.last.$1, 'Sesi makan berjalan');
      expect(layanan.catatan.last.$2, contains('+1 jam'));

      await hentikanSesi(tester, c);
    });

    testWidgets('berubah jadi ajakan memakai jam saat jendelanya terbuka', (
      tester,
    ) async {
      final layanan = LayananLatarPalsu();
      final jam = JamPalsu();
      final c = buatControllerUji(
        percepatan: 3600,
        lewatkan: {2, 3},
        jadwal: jadwalUjiTitik,
        jam: jam.call,
        layanan: layanan,
      );
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));
      await tekanTombolJam(tester, c);
      await majuBersama(tester, jam, const Duration(seconds: 56));

      // Tugas penggunanya menyusut jadi satu hal, dan kalimatnya harus
      // mengatakan hal itu saja: pakai jamnya. Bukan "buka aplikasi" — aplikasi
      // inilah yang mengukur.
      expect(layanan.catatan.last.$1, contains('Saatnya pengukuran'));
      expect(layanan.catatan.last.$2, contains('Pakai jam'));

      await hentikanSesi(tester, c);
    });
  });

  group('Pengukuran otomatis', () {
    testWidgets('mengirim UKUR sendiri saat jendela terbuka, tanpa ditekan', (
      tester,
    ) async {
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
        layanan: LayananLatarPalsu(),
      );
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));
      await tekanTombolJam(tester, c);
      await tester.pump(const Duration(milliseconds: 50));

      // `lewatkan` hanya menahan pengukuran yang dijadwalkan jam palsu;
      // perintah dari aplikasi tetap dilayani, seperti pada jam sungguhan.
      ble.lewatkan.clear();
      ble.permintaanUkur.clear();

      // Tidak ada satu pun ketukan sesudah baris ini.
      await majuBersama(tester, jam, const Duration(seconds: 56));
      await tester.pump(const Duration(seconds: 1));

      expect(
        ble.permintaanUkur.any((p) => p.index == 2),
        isTrue,
        reason: 'titik +1 jam harus diukur tanpa menunggu siapa pun menekan',
      );
      expect(c.sesiAktif!.sampel[2].status, StatusSampel.terisi);

      await hentikanSesi(tester, c);
    });

    testWidgets('mencoba lagi selama titiknya masih kosong', (tester) async {
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
        layanan: LayananLatarPalsu(),
      );
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 50));
      await tekanTombolJam(tester, c);
      await tester.pump(const Duration(milliseconds: 50));

      // `lewatkan` dibiarkan terpasang: jam menolak setiap `UKUR` untuk titik 2,
      // meniru pergelangan yang dingin atau tali yang longgar.
      ble.permintaanUkur.clear();
      await majuBersama(tester, jam, const Duration(seconds: 56));

      // Jendelanya 55–70 detik pada jadwal ini, jadi jedanya (70-55)/5 = 3 detik.
      await majuBersama(tester, jam, const Duration(seconds: 8));

      // Satu pengukuran gagal hari ini berarti titik itu hilang, karena tidak
      // ada yang tahu ia gagal sampai sesinya berakhir. Jendela 15 menit memuat
      // beberapa percobaan dengan longgar.
      expect(
        ble.permintaanUkur.where((p) => p.index == 2).length,
        greaterThan(1),
        reason: 'percobaan ulang adalah keuntungan terbesar otomatisasi',
      );
      expect(c.sesiAktif!.sampel[2].status, StatusSampel.menunggu);

      await hentikanSesi(tester, c);
    });
  });

  group('Backoff sambung ulang', () {
    // Fungsi murni, dipisahkan dari `BleAsliService` justru supaya bagian ini
    // bisa diuji: sisanya menuntut radio dan karena itu memang tidak diuji
    // (CLAUDE.md, "BleAsliService itself has no unit tests").
    test('menanjak dua kali lipat sampai 60 detik pada menit-menit awal', () {
      var d = ProtokolJam.backoffAwal;
      final urutan = <int>[];
      for (var i = 0; i < 8; i++) {
        d = ProtokolJam.backoffBerikutnya(
          sekarang: d,
          sejakGagalPertama: const Duration(minutes: 1),
        );
        urutan.add(d.inSeconds);
      }
      expect(urutan, [2, 4, 8, 16, 32, 60, 60, 60]);
    });

    test('naik ke 5 menit sesudah gagal beruntun sepuluh menit', () {
      // Satu percobaan adalah paging langsung 15 detik dengan radio menyala
      // penuh. Batas 60 detik berarti seperlima waktu dihabiskan memanggil jam
      // yang tidak ada — dulu dihentikan Android yang membunuh prosesnya, yang
      // tidak lagi terjadi begitu foreground service menahannya tetap hidup.
      final d = ProtokolJam.backoffBerikutnya(
        sekarang: ProtokolJam.backoffMaks,
        sejakGagalPertama: const Duration(minutes: 11),
      );
      expect(d, greaterThan(ProtokolJam.backoffMaks));
      expect(d, lessThanOrEqualTo(ProtokolJam.backoffMaksLama));
    });

    test('ambangnya tepat, bukan kira-kira', () {
      Duration pada(Duration sejak) => ProtokolJam.backoffBerikutnya(
        sekarang: ProtokolJam.backoffMaks,
        sejakGagalPertama: sejak,
      );

      // Di ambang, batasnya yang berubah — bukan jedanya yang melompat. Ia
      // tetap menanjak dua kali lipat, hanya saja tidak lagi dipotong di 60
      // detik: 60 → 120 → 240 → 300.
      expect(
        pada(ProtokolJam.ambangBackoffLama),
        greaterThan(ProtokolJam.backoffMaks),
      );
      expect(
        pada(ProtokolJam.ambangBackoffLama - const Duration(seconds: 1)),
        ProtokolJam.backoffMaks,
      );

      // Dan tanjakan itu memang berhenti di batas barunya.
      var d = ProtokolJam.backoffMaks;
      for (var i = 0; i < 6; i++) {
        d = ProtokolJam.backoffBerikutnya(
          sekarang: d,
          sejakGagalPertama: const Duration(minutes: 30),
        );
      }
      expect(d, ProtokolJam.backoffMaksLama);
    });
  });
}
