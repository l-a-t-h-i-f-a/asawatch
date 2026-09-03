// Kotak masuk entri jam — docs/protokol-jam.md §6.
//
// Yang diuji di sini bukan "baris masuk lalu keluar", melainkan aturan yang
// membuat tabel ini ada sama sekali: entri baru boleh dilupakan **setelah**
// sesinya durabel, dan yang belum durabel harus bisa diputar ulang.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/repositories/basis_data.dart';
import 'package:asawatch/repositories/entri_jam_repository.dart';
import 'package:asawatch/repositories/sesi_repository_drift.dart';
import 'package:asawatch/services/protokol_jam.dart';

const _sesiId = '00112233-4455-6677-8899-aabbccddeeff';

EntriSampel _sampel({
  int seq = 1,
  String sesiId = _sesiId,
  int index = 2,
  int bootId = 7,
  int uptimeS = 20000,
  bool dariBuffer = false,
  bool waktuTidakPasti = false,
  int? gulaDarah = 142,
}) => EntriSampel(
  seq: seq,
  sesiId: sesiId,
  index: index,
  bootId: bootId,
  uptimeS: uptimeS,
  dariBuffer: dariBuffer,
  waktuTidakPasti: waktuTidakPasti,
  gulaDarah: gulaDarah,
  detakJantung: 88,
  sistolik: 118,
  diastolik: 76,
  spo2: 97,
);

EntriPeristiwa _peristiwa({
  int seq = 2,
  JenisPeristiwa jenis = JenisPeristiwa.tombolSelesaiMakan,
  String? sesiId = _sesiId,
  int bootId = 7,
  int uptimeS = 18000,
  int payload = 0,
}) => EntriPeristiwa(
  seq: seq,
  jenis: jenis,
  sesiId: sesiId,
  bootId: bootId,
  uptimeS: uptimeS,
  dariBuffer: false,
  waktuTidakPasti: false,
  payload: payload,
);

void main() {
  late BasisData db;
  late EntriJamRepositoryDrift repo;
  late SesiRepositoryDrift sesiRepo;

  setUp(() {
    db = BasisData(NativeDatabase.memory());
    repo = EntriJamRepositoryDrift(db);
    sesiRepo = SesiRepositoryDrift(db);
  });

  tearDown(() => db.close());

  /// Sesi dengan id protokol yang sah, supaya entri di atas benar-benar
  /// menempel padanya.
  SesiMakan sesiUji({StatusSesi status = StatusSesi.berjalan}) {
    final asli = contohRiwayatSesi().first;
    return SesiMakan(
      id: _sesiId,
      fotoPath: asli.fotoPath,
      waktuFoto: asli.waktuFoto,
      t0: asli.t0,
      status: status,
      sampel: asli.sampel,
    );
  }

  test('entri sampel bolak-balik utuh, termasuk metrik yang gagal', () async {
    await repo.simpan(_sampel(gulaDarah: null));

    final kembali = (await repo.belumDiproses()).single as EntriSampel;

    expect(kembali.seq, 1);
    expect(kembali.sesiId, _sesiId);
    expect(kembali.index, 2);
    expect(kembali.bootId, 7);
    expect(kembali.uptimeS, 20000);
    // Metrik yang gagal tetap null, bukan berubah menjadi sentinel 0 lagi.
    expect(kembali.gulaDarah, isNull);
    expect(kembali.detakJantung, 88);
  });

  test('entri peristiwa bolak-balik utuh', () async {
    await repo.simpan(_peristiwa());

    final kembali = (await repo.belumDiproses()).single as EntriPeristiwa;

    expect(kembali.jenis, JenisPeristiwa.tombolSelesaiMakan);
    expect(kembali.sesiId, _sesiId);
    expect(kembali.uptimeS, 18000);
  });

  test('entri yang diputar ulang ditandai dariBuffer', () async {
    // Entri yang keluar dari basis data, menurut definisi, datang terlambat —
    // dan UI memang membedakan sampel yang menyusul dari yang realtime.
    await repo.simpan(_sampel(dariBuffer: false));
    expect((await repo.belumDiproses()).single.dariBuffer, isTrue);
  });

  test('entri tanpa sesi tidak pernah menunggu diproses', () async {
    // BOOT dan BUFFER_PENUH tidak akan pernah ikut tertulis di dalam sebuah
    // sesi, jadi menunggunya berarti menumpuk baris selamanya.
    await repo.simpan(_peristiwa(jenis: JenisPeristiwa.boot, sesiId: null));
    expect(await repo.belumDiproses(), isEmpty);
  });

  test('menyimpan sesinya menandai entrinya diproses', () async {
    await repo.simpan(_peristiwa());
    await repo.simpan(_sampel());
    expect((await repo.belumDiproses()).length, 2);

    await sesiRepo.simpan(sesiUji());

    // Inilah lingkaran §6 yang tertutup: entri boleh dilupakan tepat saat
    // sesinya durabel, tidak sedetik lebih awal.
    expect(await repo.belumDiproses(), isEmpty);
  });

  test('entri sesi lain tidak ikut tertandai', () async {
    const lain = 'ffffffff-0000-4000-8000-000000000001';
    await repo.simpan(_sampel(sesiId: lain));
    await repo.simpan(_sampel(seq: 2));

    await sesiRepo.simpan(sesiUji());

    final tersisa = (await repo.belumDiproses()).single as EntriSampel;
    expect(tersisa.sesiId, lain);
  });

  test(
    'sesi yang dibatalkan tidak meninggalkan entri yang diputar selamanya',
    () async {
      await repo.simpan(_sampel());
      await sesiRepo.simpan(sesiUji(status: StatusSesi.draft));
      await repo.simpan(_sampel(seq: 5, index: 3));

      await sesiRepo.hapus(_sesiId);

      expect(await repo.belumDiproses(), isEmpty);
    },
  );

  test('sampel jawaban UKUR_SEKARANG tidak diputar ulang selamanya', () async {
    // Jawaban `UKUR_SEKARANG` (§5.1) datang sebagai paket Sampel dengan sesiId
    // 16 byte nol, karena ia memang terjadi di luar sesi mana pun. Tidak akan
    // pernah ada sesi yang menandainya selesai, jadi kalau ia dihitung sebagai
    // entri yang menunggu, ia akan diputar ulang setiap kali aplikasi start.
    await repo.simpan(_sampel(sesiId: uuidSesiKosong, index: 0));

    expect(await repo.belumDiproses(), isEmpty);
  });

  test('urutan pemutaran ulang mengikuti urutan datangnya', () async {
    // Sampel tidak boleh mendahului peristiwa yang memberi sesinya t0: tanpa
    // t0, `detikRelatifT0` sampel itu tidak bisa dihitung.
    await repo.simpan(_peristiwa(seq: 9));
    await repo.simpan(_sampel(seq: 10));

    final tertunda = await repo.belumDiproses();
    expect(tertunda.first, isA<EntriPeristiwa>());
    expect(tertunda.last, isA<EntriSampel>());
  });

  test('t0PerSesi memberi boot_id dan uptime tombol, bukan waktunya', () async {
    await repo.simpan(_peristiwa(bootId: 12, uptimeS: 4321));
    await sesiRepo.simpan(sesiUji()); // sudah diproses pun tetap terbaca

    final t0 = await repo.t0PerSesi();

    expect(t0[_sesiId]!.bootId, 12);
    expect(t0[_sesiId]!.uptimeS, 4321);
  });

  test(
    'pangkas menyisakan yang terbaru dan tidak menyentuh yang tertunda',
    () async {
      for (var i = 1; i <= 5; i++) {
        await repo.simpan(
          _peristiwa(seq: i, jenis: JenisPeristiwa.boot, sesiId: null),
        );
      }
      await repo.simpan(_sampel(seq: 6)); // masih menunggu sesinya

      await repo.pangkas(simpanTerakhir: 2);

      final tersisa = await db.select(db.tabelEntriJam).get();
      expect(tersisa.where((b) => b.diproses).length, 2);
      // Yang belum diproses tetap ada: satu-satunya salinannya ada di sini, karena
      // jam sudah menghapus miliknya begitu di-ack.
      expect(tersisa.where((b) => !b.diproses).length, 1);
    },
  );
}
