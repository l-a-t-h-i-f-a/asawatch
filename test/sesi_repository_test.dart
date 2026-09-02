// Test untuk seam penyimpanan (rencana-produksi.md §3.1, Tahap A1).
//
// Yang diuji di sini adalah kontraknya, bukan basis datanya: sesi yang berakhir
// sampai ke repository, sesi yang dibatalkan tidak, dan kegagalan menulis tidak
// menjatuhkan sesi yang datanya sudah benar. Tahap A2 mengganti implementasinya
// dan berkas ini harus tetap hijau tanpa diubah.

import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/controllers/sesi_makan_controller.dart';
import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/repositories/sesi_repository.dart';
import 'package:asawatch/services/ble_service.dart';
import 'package:asawatch/services/nutrisi_service.dart';

SesiMakanController buatController({SesiRepository? repo}) {
  return SesiMakanController(
    ble: FakeBleService(percepatan: 3600, otomatisSelesaiMakan: null),
    nutrisi: const FakeNutrisiService(jeda: Duration.zero),
    repo: repo,
  );
}

/// Menjalankan satu sesi sampai berakhir. `akhiriLebihAwal()` dipilih karena ia
/// menutup sesi tanpa menunggu jadwal sampel — jalur `_selesaikan()`-nya sama.
Future<void> jalankanSatuSesi(SesiMakanController c) async {
  await c.mulaiDraft(contohFotoPath);
  (c.ble as FakeBleService).tekanSelesaiMakan();
  await Future<void>.delayed(Duration.zero);
  await c.akhiriLebihAwal();
  await Future<void>.delayed(Duration.zero); // penulisan tidak ditunggu
}

class _RepoGagal implements SesiRepository {
  @override
  Future<List<SesiMakan>> muatSemua() async => const [];

  @override
  Future<DateTime> simpan(SesiMakan sesi) async => throw StateError('disk penuh');

  @override
  Future<void> hapusSemua() async {}

  @override
  Future<void> hapus(String sesiId) async {}

  @override
  Future<void> nisankan(String sesiId) async {}

  @override
  Future<List<String>> ambilNisan() async => const [];
}

void main() {
  group('SesiRepositoryMemori', () {
    test('mengembalikan riwayat awal apa adanya', () async {
      final seed = contohRiwayatSesi();
      final repo = SesiRepositoryMemori(awal: seed);

      expect((await repo.muatSemua()).map((s) => s.id), seed.map((s) => s.id));
    });

    test('tidak ikut berubah saat daftar sumbernya diubah', () async {
      final seed = contohRiwayatSesi();
      final repo = SesiRepositoryMemori(awal: seed);
      seed.clear();

      expect(await repo.muatSemua(), isNotEmpty);
    });

    test('menyimpan sesi baru di depan, terbaru dulu', () async {
      final repo = SesiRepositoryMemori(awal: contohRiwayatSesi());
      final sebelum = (await repo.muatSemua()).length;
      final contoh = contohRiwayatSesi().first;
      final baru = SesiMakan(
        id: 'sesi-baru',
        fotoPath: contoh.fotoPath,
        waktuFoto: contoh.waktuFoto,
        t0: contoh.t0,
        status: StatusSesi.selesai,
        hasil: contoh.hasil,
        sampel: contoh.sampel,
      );

      await repo.simpan(baru);
      final sesudah = await repo.muatSemua();

      expect(sesudah.length, sebelum + 1);
      expect(sesudah.first.id, 'sesi-baru');
    });

    test('menyimpan id yang sama menimpa, bukan menggandakan', () async {
      // Pengiriman jam at-least-once berarti satu sesi bisa ditulis dua kali.
      final repo = SesiRepositoryMemori(awal: contohRiwayatSesi());
      final sebelum = await repo.muatSemua();
      final sesi = sebelum.first;

      await repo.simpan(sesi.salin(status: StatusSesi.tidakLengkap));
      final sesudah = await repo.muatSemua();

      expect(sesudah.length, sebelum.length);
      expect(
        sesudah.firstWhere((s) => s.id == sesi.id).status,
        StatusSesi.tidakLengkap,
      );
    });
  });

  group('Controller menulis ke repository', () {
    test('sesi yang berakhir ikut tersimpan', () async {
      final repo = SesiRepositoryMemori();
      final c = buatController(repo: repo);
      addTearDown(c.dispose);

      await jalankanSatuSesi(c);

      final tersimpan = await repo.muatSemua();
      expect(tersimpan.length, 1);
      expect(tersimpan.first.id, c.sesiTerakhir!.id);
      expect(tersimpan.first.status, StatusSesi.tidakLengkap);
    });

    test('sesi yang dibatalkan tidak tersimpan', () async {
      final repo = SesiRepositoryMemori();
      final c = buatController(repo: repo);
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath);
      (c.ble as FakeBleService).tekanSelesaiMakan();
      await Future<void>.delayed(Duration.zero);
      await c.batalkan();
      await Future<void>.delayed(Duration.zero);

      expect(await repo.muatSemua(), isEmpty);
    });

    test('tanpa repository, sesi tetap masuk riwayat di memori', () async {
      // Perilaku sebelum seam ini ada, dan perilaku sebagian besar test.
      final c = buatController();
      addTearDown(c.dispose);

      await jalankanSatuSesi(c);

      expect(c.riwayat.length, 1);
    });

    test('gagal menyimpan tidak menjatuhkan sesi yang sudah benar', () async {
      final c = buatController(repo: _RepoGagal());
      addTearDown(c.dispose);

      await jalankanSatuSesi(c);

      // Datanya sudah lengkap di memori; kegagalan menulis bukan alasan
      // menghilangkannya dari layar.
      expect(c.riwayat.length, 1);
      expect(c.hasilBelumDibaca, isNotNull);
    });
  });
}
