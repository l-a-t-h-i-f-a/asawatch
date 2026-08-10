// Test untuk anchor waktu (docs/protokol-jam.md §4, Tahap A3).
//
// Dua hal yang diuji di sini, dan keduanya belum punya pemanggil di aplikasi:
// rumus konversi uptime → waktu nyata, dan penyimpanannya. Rumus itu adalah
// satu-satunya bagian Tahap B yang murni dan bisa diuji tanpa hardware, jadi
// ia dikunci sekarang — bukan nanti di tengah kode BLE.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/models/anchor_waktu.dart';
import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/repositories/anchor_repository.dart';
import 'package:asawatch/repositories/basis_data.dart';
import 'package:asawatch/repositories/sesi_repository_drift.dart';

void main() {
  group('Konversi waktu', () {
    // Jam menyala pukul 08:00 menurut HP, saat itu uptime-nya 3600 detik.
    final anchor = AnchorWaktu(
      bootId: 7,
      uptimeS: 3600,
      epoch: DateTime(2026, 8, 10, 8),
    );

    test('peristiwa sesudah anchor', () {
      expect(anchor.keWaktu(3600 + 120), DateTime(2026, 8, 10, 8, 2));
    });

    test('peristiwa sebelum anchor tetap terterjemahkan', () {
      // Inti dari §4.2: tombol jam ditekan pukul 07:00, jauh sebelum HP
      // tersambung, dan satu anchor di akhir tetap cukup menerjemahkannya.
      expect(anchor.keWaktu(0), DateTime(2026, 8, 10, 7));
    });

    test('anchor tepat pada uptime yang sama memberi waktu anchor', () {
      expect(anchor.keWaktu(3600), anchor.epoch);
    });

    test('hanya berlaku untuk boot yang sama', () {
      // uptime dari boot lain tidak sebanding: di antaranya ada jeda mati yang
      // panjangnya tidak diketahui siapa pun.
      expect(anchor.berlakuUntuk(7), isTrue);
      expect(anchor.berlakuUntuk(8), isFalse);
    });
  });

  group('Penyimpanan anchor', () {
    late BasisData db;
    late AnchorRepositoryDrift repo;

    setUp(() {
      db = BasisData(NativeDatabase.memory());
      repo = AnchorRepositoryDrift(db);
    });

    tearDown(() => db.close());

    test('boot yang tidak pernah tersambung tidak punya anchor', () async {
      // Ini keadaan `waktu_tidak_pasti` di protokol §4.3, bukan error.
      expect(await repo.terbaruUntuk(7), isNull);
    });

    test('menyimpan lalu membaca kembali', () async {
      final anchor = AnchorWaktu(
        bootId: 7,
        uptimeS: 3600,
        epoch: DateTime(2026, 8, 10, 8),
      );
      await repo.simpan(anchor);

      final kembali = await repo.terbaruUntuk(7);

      expect(kembali!.bootId, 7);
      expect(kembali.uptimeS, 3600);
      expect(kembali.epoch, anchor.epoch);
    });

    test('terbaru dipilih berdasarkan uptime, bukan urutan penyimpanan',
        () async {
      // Jam HP bisa mundur (koreksi NTP, user mengubah waktu) tanpa uptime ikut
      // mundur, jadi uptime-lah yang menentukan mana yang terbaru.
      await repo.simpan(
        AnchorWaktu(bootId: 7, uptimeS: 7200, epoch: DateTime(2026, 8, 10, 9)),
      );
      await repo.simpan(
        AnchorWaktu(bootId: 7, uptimeS: 3600, epoch: DateTime(2026, 8, 10, 8)),
      );

      expect((await repo.terbaruUntuk(7))!.uptimeS, 7200);
    });

    test('anchor tiap boot terpisah', () async {
      await repo.simpan(
        AnchorWaktu(bootId: 7, uptimeS: 100, epoch: DateTime(2026, 8, 10, 8)),
      );
      await repo.simpan(
        AnchorWaktu(bootId: 8, uptimeS: 50, epoch: DateTime(2026, 8, 11, 8)),
      );

      expect((await repo.terbaruUntuk(7))!.uptimeS, 100);
      expect((await repo.terbaruUntuk(8))!.uptimeS, 50);
    });

    test('beberapa anchor per boot disimpan, bukan saling menimpa', () async {
      // Koreksi drift (§4.4) butuh dua titik dalam satu boot. Belum dipakai,
      // tetapi tempatnya harus ada sejak sekarang.
      await repo.simpan(
        AnchorWaktu(bootId: 7, uptimeS: 100, epoch: DateTime(2026, 8, 10, 8)),
      );
      await repo.simpan(
        AnchorWaktu(bootId: 7, uptimeS: 200, epoch: DateTime(2026, 8, 10, 9)),
      );

      final semua = await repo.semuaUntuk(7);
      expect(semua.length, 2);
      expect(semua.map((a) => a.uptimeS), [100, 200]);
    });

    test('anchor pada uptime yang sama ditimpa, bukan digandakan', () async {
      await repo.simpan(
        AnchorWaktu(bootId: 7, uptimeS: 100, epoch: DateTime(2026, 8, 10, 8)),
      );
      await repo.simpan(
        AnchorWaktu(bootId: 7, uptimeS: 100, epoch: DateTime(2026, 8, 10, 9)),
      );

      final semua = await repo.semuaUntuk(7);
      expect(semua.length, 1);
      expect(semua.single.epoch, DateTime(2026, 8, 10, 9));
    });
  });

  group('Migrasi skema v1 → v2', () {
    test('basis data v1 naik ke v2 tanpa kehilangan sesi', () async {
      // Perangkat yang sudah memakai skema v1 (Tahap A2) harus bisa dibuka oleh
      // aplikasi v2. Jalur `onUpgrade` yang tidak pernah dijalankan satu test
      // pun adalah jalur yang akan patah di perangkat pengguna.
      final dir = await Directory.systemTemp.createTemp('asawatch_migrasi');
      addTearDown(() => dir.delete(recursive: true));
      final berkas = File('${dir.path}/sesi.sqlite');

      // Membuat basis data v1 dengan cara menurunkan yang v2: tabel anchor
      // dibuang dan penanda versinya dikembalikan ke 1.
      final sesi = contohRiwayatSesi().first;
      final dbV1 = BasisData(NativeDatabase(berkas));
      await SesiRepositoryDrift(dbV1).simpan(sesi);
      await dbV1.customStatement('DROP TABLE tabel_anchor_waktu');
      await dbV1.customStatement('PRAGMA user_version = 1');
      await dbV1.close();

      // Membuka dengan skema v2 harus menjalankan migrasinya.
      final dbV2 = BasisData(NativeDatabase(berkas));
      addTearDown(dbV2.close);

      final anchor = AnchorRepositoryDrift(dbV2);
      await anchor.simpan(
        AnchorWaktu(bootId: 1, uptimeS: 10, epoch: DateTime(2026, 8, 10, 8)),
      );

      expect((await anchor.terbaruUntuk(1))!.uptimeS, 10);
      // Dan sesi yang sudah ada sebelum migrasi tetap utuh.
      final riwayat = await SesiRepositoryDrift(dbV2).muatSemua();
      expect(riwayat.single.id, sesi.id);
      expect(riwayat.single.puncakGulaDarah, sesi.puncakGulaDarah);
    });
  });
}
