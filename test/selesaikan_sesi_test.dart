// Menutup sendiri sesi yang jamnya tidak akan menuntaskan pengukurannya.
//
// Sebelum ini satu-satunya jalan keluar dari `SesiBerjalanPage` adalah
// "Batalkan Sesi", yang menghapus barisnya — sehingga sesi yang jamnya mati di
// tengah jalan memaksa pilihan antara membuang sampel yang sudah terkumpul atau
// menunggu `tenggatSampelTerakhir`, yang jatuh sampai 2,5 jam setelah t0.
//
// Yang diuji di sini adalah pembedaan itu: "Selesaikan" menyimpan,
// "Batalkan" menghapus, dan keduanya tidak boleh tertukar.

import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/controllers/sesi_makan_controller.dart';
import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/sesi_berjalan_page.dart';

import 'helpers.dart';

/// Membawa controller sampai sesi benar-benar berjalan: draft, baseline, lalu
/// tombol **di jam** ditekan — satu-satunya sumber t0.
Future<void> jalankanSesi(
  WidgetTester tester,
  SesiMakanController controller,
) async {
  await controller.mulaiDraft(contohFotoPath);
  await tester.pump(const Duration(milliseconds: 50));
  await tekanTombolJam(tester, controller);
  await tester.pump(const Duration(milliseconds: 50));
}

Future<void> ketuk(WidgetTester tester, String teks) async {
  // Digulir ke tampak lebih dulu: sejak `PetunjukTombolUkur` ikut dirender,
  // kedua tombol jalan keluar jatuh di bawah lipatan layar 412x915. `tap` pada
  // widget di luar viewport tidak gagal — ia mengetuk titik yang salah dan
  // hanya meninggalkan peringatan, sehingga test yang lulus pun tidak
  // membuktikan apa-apa.
  await tester.ensureVisible(find.text(teks));
  await tester.pump();
  await tester.tap(find.text(teks));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300)); // dialog terbuka
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadMontserrat);

  testWidgets('sesi yang belum punya t0 tidak menawarkan "Selesaikan Sesi"', (
    tester,
  ) async {
    final c = buatControllerUji();
    await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

    await c.mulaiDraft(contohFotoPath);
    await tester.pump(const Duration(milliseconds: 50));

    // Sesi yang tombol jamnya belum ditekan bukan sesi yang belum selesai,
    // melainkan sesi yang belum mulai — tidak ada momen makan untuk direkam.
    expect(find.text('Selesaikan Sesi'), findsNothing);
    expect(find.text('Batalkan Sesi'), findsOneWidget);

    await hentikanSesi(tester, c);
  });

  testWidgets('sesi berjalan menawarkan keduanya', (tester) async {
    final c = buatControllerUji();
    await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
    await jalankanSesi(tester, c);

    expect(find.text('Selesaikan Sesi'), findsOneWidget);
    expect(find.text('Batalkan Sesi'), findsOneWidget);

    await hentikanSesi(tester, c);
  });

  testWidgets('"Lanjutkan Sesi" membiarkan sesinya berjalan', (tester) async {
    final c = buatControllerUji();
    await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
    await jalankanSesi(tester, c);

    await ketuk(tester, 'Selesaikan Sesi');
    expect(find.text('Selesaikan sesi ini?'), findsOneWidget);

    await ketuk(tester, 'Lanjutkan Sesi');

    // Konfirmasi yang dibatalkan tidak boleh meninggalkan jejak apa pun.
    expect(c.sesiAktif, isNotNull);
    expect(c.sesiAktif!.status, StatusSesi.berjalan);
    expect(c.riwayat, isEmpty);

    await hentikanSesi(tester, c);
  });

  testWidgets('menyelesaikan menyimpan sesi sebagai tidak lengkap', (
    tester,
  ) async {
    final c = buatControllerUji();
    await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
    await jalankanSesi(tester, c);

    final masukSebelum = c.sesiAktif!.sampel
        .where((s) => s.status == StatusSampel.terisi)
        .length;
    expect(masukSebelum, greaterThan(0), reason: 'baseline + t0 sudah masuk');

    await ketuk(tester, 'Selesaikan Sesi');
    await ketuk(tester, 'Selesaikan');

    expect(c.sesiAktif, isNull);
    expect(c.riwayat, hasLength(1));

    final sesi = c.riwayat.first;
    expect(sesi.status, StatusSesi.tidakLengkap);

    // Inti pembedaannya: sampel yang sudah masuk **tetap ada**, dan yang belum
    // datang ditandai terlewat — bukan dibuang bersama sesinya.
    expect(
      sesi.sampel.where((s) => s.status == StatusSampel.terisi).length,
      masukSebelum,
    );
    expect(
      sesi.sampel.where((s) => s.status == StatusSampel.menunggu),
      isEmpty,
      reason: 'tidak boleh ada titik yang menggantung selamanya',
    );
    expect(
      sesi.sampel.where((s) => s.status == StatusSampel.terlewat),
      isNotEmpty,
    );
  });

  testWidgets('membatalkan menghapus sesinya, tidak menyimpannya', (
    tester,
  ) async {
    final c = buatControllerUji();
    await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
    await jalankanSesi(tester, c);

    await ketuk(tester, 'Batalkan Sesi');
    await ketuk(tester, 'Batalkan');

    // Kontrasnya dengan test di atas adalah seluruh alasan kedua tombol ini
    // ada: keduanya mengakhiri sesi, hanya satu yang menyimpan datanya.
    expect(c.sesiAktif, isNull);
    expect(c.riwayat, isEmpty);
  });

  testWidgets('konfirmasi menyebut berapa pengukuran yang sudah masuk', (
    tester,
  ) async {
    final c = buatControllerUji();
    await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
    await jalankanSesi(tester, c);

    await ketuk(tester, 'Selesaikan Sesi');

    // Angka inilah yang menentukan apakah keputusannya benar, dan ia tidak
    // terbaca dari tombolnya.
    final masuk = c.sesiAktif!.sampel
        .where((s) => s.status == StatusSampel.terisi)
        .length;
    expect(
      find.textContaining('$masuk dari ${c.sesiAktif!.sampel.length}'),
      findsOneWidget,
    );

    // Konsekuensi yang tidak boleh disembunyikan: sampel di buffer jam tidak
    // akan masuk lagi setelah ini.
    expect(find.textContaining('tidak akan masuk lagi'), findsOneWidget);

    await ketuk(tester, 'Lanjutkan Sesi');
    await hentikanSesi(tester, c);
  });

  testWidgets('sesi tanpa satu pun pengukuran tetap bisa diselesaikan', (
    tester,
  ) async {
    // `lewatkan` mencegah setiap sampel pernah datang — jam yang tombolnya
    // sempat ditekan lalu mati, atau sensornya gagal seluruhnya.
    final c = buatControllerUji(lewatkan: const {0, 1, 2, 3});
    await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
    await jalankanSesi(tester, c);

    expect(
      c.sesiAktif!.sampel.where((s) => s.status == StatusSampel.terisi),
      isEmpty,
    );

    await ketuk(tester, 'Selesaikan Sesi');

    // Kalimatnya berbeda karena keadaannya berbeda: tidak ada yang bisa
    // disebut "sudah masuk", dan yang disimpan adalah catatan bahwa makan ini
    // pernah terjadi.
    expect(
      find.textContaining('Belum ada satu pun pengukuran yang masuk'),
      findsOneWidget,
    );

    await ketuk(tester, 'Selesaikan');

    expect(c.sesiAktif, isNull);
    expect(c.riwayat, hasLength(1));
    expect(c.riwayat.first.status, StatusSesi.tidakLengkap);
  });
}
