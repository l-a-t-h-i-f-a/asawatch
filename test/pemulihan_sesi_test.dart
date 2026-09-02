// Pemulihan sesi yang masih berjalan — docs/rencana-produksi.md §4.3, §7.1.
//
// Ditunda dari Tahap A dengan alasan yang jelas: memulihkan sesi saat itu
// menghasilkan sesi yang **tidak akan pernah selesai**, karena jadwal sampel
// hidup di jam dan `FakeBleService` yang baru dibuat tidak tahu apa-apa
// tentangnya. Dengan jam sungguhan, jadwal itu memang hidup di jam — dan
// buffer-nya yang membuat pemulihan bermakna.
//
// Aturan yang dikunci di sini: jadwal dihitung ulang dari `t0` **absolut**,
// bukan dari sisa waktu. Aplikasi yang mati satu jam tidak boleh menggeser satu
// titik ukur pun.

import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/controllers/sesi_makan_controller.dart';
import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/repositories/sesi_repository.dart';
import 'package:asawatch/services/ble_service.dart';
import 'package:asawatch/services/nutrisi_service.dart';
import 'package:asawatch/services/protokol_jam.dart';

SesiMakanController buatController({
  List<SesiMakan> riwayatAwal = const [],
  SesiRepository? repo,
}) {
  return SesiMakanController(
    ble: FakeBleService(percepatan: 3600, otomatisSelesaiMakan: null),
    nutrisi: const FakeNutrisiService(jeda: Duration.zero),
    riwayatAwal: riwayatAwal,
    repo: repo,
  );
}

/// Sesi yang tombolnya ditekan [menitLalu] menit yang lalu, dengan baseline dan
/// titik "selesai makan" sudah masuk.
SesiMakan sesiBerjalan({
  required int menitLalu,
  String? id,
  StatusSesi status = StatusSesi.berjalan,
}) {
  final t0 = DateTime.now().subtract(Duration(minutes: menitLalu));
  return SesiMakan(
    id: id ?? buatIdSesi(),
    fotoPath: contohFotoPath,
    waktuFoto: t0.subtract(const Duration(minutes: 25)),
    t0: t0,
    status: status,
    sampel: [
      const Sampel(
        index: 0,
        detikRelatifT0: -1500,
        status: StatusSampel.terisi,
        gulaDarah: 92,
      ),
      const Sampel(
        index: 1,
        detikRelatifT0: 0,
        status: StatusSampel.terisi,
        gulaDarah: 98,
      ),
      const Sampel.menunggu(index: 2, detikRelatifT0: 3600),
      const Sampel.menunggu(index: 3, detikRelatifT0: 7200),
    ],
  );
}

void main() {
  test('sesi berjalan dari basis data kembali menjadi sesi aktif', () async {
    final sesi = sesiBerjalan(menitLalu: 40);
    final c = buatController(riwayatAwal: [sesi, ...contohRiwayatSesi()]);
    addTearDown(c.dispose);

    expect(c.sesiAktif, isNotNull);
    expect(c.sesiAktif!.id, sesi.id);
    expect(c.sesiAktif!.status, StatusSesi.berjalan);
    // Dan ia tidak juga muncul di riwayat: satu sesi, satu tempat.
    expect(c.riwayat.any((s) => s.id == sesi.id), isFalse);

    await c.batalkan();
  });

  test('jadwal dihitung ulang dari t0 absolut, bukan dari sisa waktu', () async {
    // Aplikasi mati 40 menit; titik +1 jam tetap jatuh 20 menit lagi, bukan
    // satu jam lagi.
    final sesi = sesiBerjalan(menitLalu: 40);
    final c = buatController(riwayatAwal: [sesi]);
    addTearDown(c.dispose);

    final berikutnya = c.sesiAktif!.jadwalBerikutnya!;
    final sisa = berikutnya.difference(DateTime.now());

    expect(c.sesiAktif!.sampelBerikutnya!.index, 2);
    expect(sisa.inMinutes, closeTo(20, 1));

    await c.batalkan();
  });

  test('sampel yang sudah masuk tidak ditulis ulang oleh duplikat', () async {
    // Jam mengirim at-least-once, dan setelah restart ia tidak tahu apa yang
    // sempat tersimpan. Dedup `(sesiId, index)` harus ikut dipulihkan.
    final sesi = sesiBerjalan(menitLalu: 10);
    final c = buatController(riwayatAwal: [sesi]);
    addTearDown(c.dispose);

    (c.ble as FakeBleService).kirimSampel(
      sesi.id,
      const Sampel(
        index: 1,
        detikRelatifT0: 0,
        status: StatusSampel.terisi,
        gulaDarah: 999, // nilai yang jelas berbeda
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(c.sesiAktif!.sampel[1].gulaDarah, 98);

    await c.batalkan();
  });

  test('sesi yang sudah lewat tenggat ditutup, bukan menunggu selamanya',
      () async {
    // Jam mati atau tidak pernah tersambung lagi: dua jam plus tenggatnya lewat,
    // dan tidak ada seorang pun yang akan datang menutup sesinya.
    final sesi = sesiBerjalan(menitLalu: 60 * 5);
    final c = buatController(riwayatAwal: [sesi]);
    addTearDown(c.dispose);

    await Future<void>.delayed(Duration.zero);

    expect(c.sesiAktif, isNull);
    final ditutup = c.sesiTerakhir!;
    expect(ditutup.id, sesi.id);
    expect(ditutup.status, StatusSesi.tidakLengkap);
    // Sampel yang sudah masuk tetap utuh — sesinya tidak lengkap, bukan gagal.
    expect(ditutup.sampel[1].gulaDarah, 98);
    expect(ditutup.sampel[2].status, StatusSampel.terlewat);
  });

  test('lebih dari satu sesi aktif tersimpan menyisakan tepat satu', () async {
    // Tidak seharusnya terjadi, tetapi basis data bisa berakhir seperti ini
    // setelah crash pada waktu yang tepat. Aturan satu-sesi-aktif tidak boleh
    // patah hanya karena datanya patah.
    final lama = sesiBerjalan(menitLalu: 90, id: buatIdSesi());
    final baru = sesiBerjalan(menitLalu: 10, id: buatIdSesi());
    final c = buatController(riwayatAwal: [lama, baru]);
    addTearDown(c.dispose);

    expect(c.sesiAktif!.id, baru.id);
    expect(c.riwayat.single.id, lama.id);
    expect(c.riwayat.single.status, StatusSesi.tidakLengkap);

    await c.batalkan();
  });

  test('draft yang dipulihkan tetap ditulis, sesi yang dibatalkan dihapus',
      () async {
    final repo = SesiRepositoryMemori();
    final c = buatController(repo: repo);
    addTearDown(c.dispose);

    await c.mulaiDraft(contohFotoPath);
    await Future<void>.delayed(Duration.zero);

    // Draft sudah durabel sejak shutter ditekan: aplikasi yang ditutup sekarang
    // tetap menemukan sesinya.
    final tersimpan = await repo.muatSemua();
    expect(tersimpan.single.status.sedangAktif, isTrue);

    await c.batalkan();
    await Future<void>.delayed(Duration.zero);

    // Dan sesi yang dibatalkan tidak hidup kembali sebagai sesi aktif.
    expect(await repo.muatSemua(), isEmpty);
  });
}
