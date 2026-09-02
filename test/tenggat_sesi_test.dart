// Tenggat sesi vs pengukuran yang sedang berjalan.
//
// `tenggatSampelTerakhir` ada untuk jam yang mati: tanpa itu sesi menunggu
// selamanya. Tetapi ia jatuh pada waktu jam dinding, sementara pengukuran
// sungguhan memakan puluhan detik — dan pada jadwal uji yang dimampatkan 60x,
// seluruh sesi hanya berdurasi dua menit. Tenggat yang menutup sesi tepat pada
// detik jam sedang mengukur membuang pengukuran yang beberapa detik lagi
// selesai, dan sampelnya lalu tiba ke sesi yang sudah tidak aktif — hilang
// tanpa satu pun gejala di layar.
//
// Yang menahan tenggat harus BUKTI, bukan asumsi: `jamSedangMengukur()`
// membaca karakteristik Status, jadi jam yang mati menjawab false dan
// tenggatnya berjalan seperti biasa.

import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/jadwal_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/services/ble_service.dart';
import 'package:asawatch/sesi_berjalan_page.dart';

import 'helpers.dart';

/// t0 yang membuat tenggat sesi (jadwal uji: 120 dtk + 30 dtk) sudah lewat.
final _t0Basi = DateTime.now().subtract(const Duration(minutes: 10));

void main() {
  setUpAll(loadMontserrat);

  testWidgets('tenggat ditunda selagi jam terbukti sedang mengukur', (
    tester,
  ) async {
    final ble = FakeBleService(
      percepatan: 3600,
      lewatkan: {0, 1, 2, 3},
      otomatisSelesaiMakan: null,
    );
    final c = buatControllerUji(ble: ble, jadwal: jadwalNormal.dibagi(60));
    await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

    // Jamnya sedang mengukur titik terakhir tepat saat tenggatnya jatuh.
    ble.sedangMengukurTitik = true;

    await c.mulaiDraft(contohFotoPath);
    await tester.pump();
    await tekanTombolJam(tester, c, waktu: _t0Basi);
    await tester.pump();

    expect(
      c.sesiAktif,
      isNotNull,
      reason: 'sesi ditutup padahal jamnya sedang mengukur',
    );

    // Penundaannya berulang selama jawabannya masih "ya" — bukan sekali lalu
    // menyerah, karena satu pengukuran bisa berjalan sampai lima menit.
    await tester.pump(const Duration(seconds: 31));
    await tester.pump(const Duration(seconds: 31));
    expect(c.sesiAktif, isNotNull);

    // Pengukurannya berakhir. Tidak ada lagi yang menahan tenggat.
    ble.sedangMengukurTitik = false;
    await tester.pump(const Duration(seconds: 31));

    expect(c.sesiAktif, isNull);
    expect(c.sesiTerakhir!.status, StatusSesi.tidakLengkap);
  });

  testWidgets('jam yang tidak bisa ditanya tidak menahan tenggat', (
    tester,
  ) async {
    // Jam mati atau di luar jangkauan menjawab false — inilah keadaan yang
    // tenggatnya memang dirancang untuk menutup, dan penundaan di atas tidak
    // boleh menyentuhnya.
    final ble = FakeBleService(
      percepatan: 3600,
      lewatkan: {0, 1, 2, 3},
      otomatisSelesaiMakan: null,
    );
    final c = buatControllerUji(ble: ble, jadwal: jadwalNormal.dibagi(60));
    await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

    await c.mulaiDraft(contohFotoPath);
    await tester.pump();
    await tekanTombolJam(tester, c, waktu: _t0Basi);
    await tester.pump();

    expect(c.sesiAktif, isNull);
    expect(c.sesiTerakhir!.status, StatusSesi.tidakLengkap);
  });

  testWidgets('penundaan punya ujung: jam yang bit0-nya macet tidak menahan '
      'sesi tanpa batas', (tester) async {
    // Firmware yang lupa mencabut bit0 (bug, bukan pengukuran) akan menjawab
    // "sedang mengukur" selamanya. Batas 12 x 30 detik melampaui batas keras
    // pengukuran di firmware (5 menit), jadi pengukuran yang sah tidak pernah
    // menyentuhnya — sedangkan bit yang macet tetap kehabisan jatah.
    final ble = FakeBleService(
      percepatan: 3600,
      lewatkan: {0, 1, 2, 3},
      otomatisSelesaiMakan: null,
    );
    final c = buatControllerUji(ble: ble, jadwal: jadwalNormal.dibagi(60));
    await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

    ble.sedangMengukurTitik = true; // dan tidak pernah dimatikan

    await c.mulaiDraft(contohFotoPath);
    await tester.pump();
    await tekanTombolJam(tester, c, waktu: _t0Basi);
    await tester.pump();
    expect(c.sesiAktif, isNotNull);

    for (var i = 0; i < 13; i++) {
      await tester.pump(const Duration(seconds: 31));
    }

    expect(c.sesiAktif, isNull);
    expect(c.sesiTerakhir!.status, StatusSesi.tidakLengkap);
  });
}
