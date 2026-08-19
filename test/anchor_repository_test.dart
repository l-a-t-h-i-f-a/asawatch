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
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/repositories/basis_data.dart';
import 'package:asawatch/repositories/kalibrasi_repository.dart';
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

  group('Migrasi skema', () {
    // Jalur `onUpgrade` yang tidak pernah dijalankan satu test pun adalah jalur
    // yang akan patah di perangkat pengguna — dan ia baru patah setelah aplikasi
    // terpasang, saat data yang hilang adalah data sungguhan.
    //
    // Basis data versi lama dibuat dengan cara **menurunkan** yang sekarang:
    // tabel dan kolom yang lahir belakangan dibuang, lalu `user_version`
    // dikembalikan. Itu memakai satu asumsi yang layak disebut: turunan itu
    // harus benar-benar menyerupai skema lamanya.

    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('asawatch_migrasi');
    });

    tearDown(() => dir.delete(recursive: true));

    // [setelahTurun] menulis baris bergaya versi lama selagi skemanya masih
    // berbentuk lama — begitu `BasisData` dibuka lagi, migrasinya langsung
    // jalan dan bentuk itu tidak bisa ditulis lagi.
    Future<File> siapkanBerkasVersi(
      int versi,
      SesiMakan sesi, {
      Future<void> Function(BasisData db)? setelahTurun,
    }) async {
      final berkas = File('${dir.path}/sesi.sqlite');
      final db = BasisData(NativeDatabase(berkas));
      await SesiRepositoryDrift(db).simpan(sesi);

      if (versi < 5) {
        await db.customStatement('ALTER TABLE tabel_sesi DROP COLUMN sesi_uji');
      }
      if (versi < 4) {
        await db.customStatement('DROP TABLE tabel_putaran_kalibrasi');
        await db.customStatement('ALTER TABLE tabel_kalibrasi DROP COLUMN sisi');
        // Skema v3 menyimpan angkanya langsung di baris kalibrasi.
        await db.customStatement(
          'ALTER TABLE tabel_kalibrasi ADD COLUMN sistolik_referensi INTEGER NOT NULL DEFAULT 0',
        );
        await db.customStatement(
          'ALTER TABLE tabel_kalibrasi ADD COLUMN diastolik_referensi INTEGER NOT NULL DEFAULT 0',
        );
        await db.customStatement(
          'ALTER TABLE tabel_kalibrasi ADD COLUMN sistolik_jam INTEGER NOT NULL DEFAULT 0',
        );
        await db.customStatement(
          'ALTER TABLE tabel_kalibrasi ADD COLUMN diastolik_jam INTEGER NOT NULL DEFAULT 0',
        );
      }
      if (versi < 3) {
        await db.customStatement('DROP TABLE tabel_entri_jam');
        await db.customStatement('DROP TABLE tabel_kalibrasi');
        await db.customStatement(
          'ALTER TABLE tabel_sesi DROP COLUMN waktu_tidak_pasti',
        );
      }
      if (versi < 2) {
        await db.customStatement('DROP TABLE tabel_anchor_waktu');
      }
      await setelahTurun?.call(db);
      await db.customStatement('PRAGMA user_version = $versi');
      await db.close();
      return berkas;
    }

    test('basis data v1 naik ke v5 tanpa kehilangan sesi', () async {
      final sesi = contohRiwayatSesi().first;
      final berkas = await siapkanBerkasVersi(1, sesi);

      final db = BasisData(NativeDatabase(berkas));
      addTearDown(db.close);

      // Kedua langkah migrasi harus benar-benar berjalan berurutan, bukan
      // dilompati: pemasangan yang lama tidak dibuka melewati beberapa versi
      // sekaligus.
      final anchor = AnchorRepositoryDrift(db);
      await anchor.simpan(
        AnchorWaktu(bootId: 1, uptimeS: 10, epoch: DateTime(2026, 8, 10, 8)),
      );
      expect((await anchor.terbaruUntuk(1))!.uptimeS, 10);

      final riwayat = await SesiRepositoryDrift(db).muatSemua();
      expect(riwayat.single.id, sesi.id);
      expect(riwayat.single.puncakGulaDarah, sesi.puncakGulaDarah);
      // Kolom yang lahir di v3 punya nilai bawaan yang benar untuk baris lama:
      // sesi yang direkam sebelum Tahap B jelas bukan sesi berwaktu tidak pasti.
      expect(riwayat.single.waktuTidakPasti, isFalse);
      // Sama untuk kolom yang lahir di v5: sesi yang direkam sebelum mode uji
      // ada jelas bukan sesi uji, dan menandainya begitu akan menyembunyikannya
      // dari Analisis tanpa ada yang meminta.
      expect(riwayat.single.sesiUji, isFalse);
    });

    // Penjaga `PRAGMA table_info` di langkah v4 → v5 **belum** benar-benar
    // terpakai hari ini: `tabel_sesi` tidak pernah dibuat ulang oleh
    // `createTable` di langkah mana pun, jadi tidak ada jalur yang tiba di sini
    // dengan kolomnya sudah ada. Ia dipasang karena langkah berikutnya yang
    // membuat ulang tabel itu akan membuatnya perlu, dan karena kegagalannya
    // tidak sopan: `addColumn` di atas kolom yang sudah ada menggagalkan
    // seluruh pembukaan basis data, dan yang terlihat pengguna adalah
    // `AplikasiGagalMulai`. Yang diuji di sini adalah langkahnya sendiri.
    test('basis data v4 naik ke v5 dan sesi uji bisa ditulis', () async {
      final sesi = contohRiwayatSesi().first;
      final berkas = await siapkanBerkasVersi(4, sesi);

      final db = BasisData(NativeDatabase(berkas));
      addTearDown(db.close);

      final repo = SesiRepositoryDrift(db);
      await repo.simpan(
        sesi.salin(status: StatusSesi.selesai, sesiUji: true),
      );

      final riwayat = await repo.muatSemua();
      expect(riwayat.single.sesiUji, isTrue);
    });

    test('basis data v2 naik ke v5 dan bisa menyimpan kalibrasi', () async {
      final sesi = contohRiwayatSesi().first;
      final berkas = await siapkanBerkasVersi(2, sesi);

      final db = BasisData(NativeDatabase(berkas));
      addTearDown(db.close);

      final kalibrasi = KalibrasiRepositoryDrift(db);
      await kalibrasi.simpan(
        Kalibrasi(
          waktu: DateTime(2026, 8, 11, 9),
          sisi: SisiPergelangan.kanan,
          putaran: const [
            PutaranKalibrasi(
              sistolikReferensi: 120,
              diastolikReferensi: 80,
              sistolikJam: 127,
              diastolikJam: 84,
            ),
            PutaranKalibrasi(
              sistolikReferensi: 122,
              diastolikReferensi: 81,
              sistolikJam: 128,
              diastolikJam: 84,
            ),
            PutaranKalibrasi(
              sistolikReferensi: 118,
              diastolikReferensi: 79,
              sistolikJam: 126,
              diastolikJam: 83,
            ),
          ],
        ),
      );

      final termuat = (await kalibrasi.terbaru())!;
      expect(termuat.putaran.length, 3);
      expect(termuat.offsetSistolik, -7); // median dari -7, -6, -8
      expect(termuat.sisi, SisiPergelangan.kanan);
      expect((await SesiRepositoryDrift(db).muatSemua()).single.id, sesi.id);
    });

    // Kalibrasi yang dibuat sebelum metode tiga putaran tidak boleh menguap:
    // jam masih memakai offsetnya, jadi aplikasi yang tiba-tiba menganggap
    // dirinya "belum pernah dikalibrasi" akan berbohong tentang keadaan jam.
    test('kalibrasi satu putaran dari v3 selamat menyeberang ke v5', () async {
      final sesi = contohRiwayatSesi().first;
      final berkas = await siapkanBerkasVersi(
        3,
        sesi,
        setelahTurun: (db) => db.customStatement(
          'INSERT INTO tabel_kalibrasi (waktu, sistolik_referensi, '
          'diastolik_referensi, sistolik_jam, diastolik_jam) '
          'VALUES (?, ?, ?, ?, ?)',
          [
            DateTime.utc(2026, 8, 11, 9).microsecondsSinceEpoch,
            120,
            80,
            127,
            84,
          ],
        ),
      );

      final db = BasisData(NativeDatabase(berkas));
      addTearDown(db.close);

      final termuat = (await KalibrasiRepositoryDrift(db).terbaru())!;
      expect(termuat.putaran.length, 1);
      expect(termuat.offsetSistolik, -7);
      expect(termuat.offsetDiastolik, -4);
      // Satu putaran selalu "konsisten" dengan dirinya sendiri — sebarannya 0.
      expect(termuat.konsisten, isTrue);
      expect(termuat.sisi, SisiPergelangan.kiri);
    });
  });
}
