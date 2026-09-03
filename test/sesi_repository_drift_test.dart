// Test untuk SesiRepositoryDrift (rencana-produksi.md §3.1, Tahap A2).
//
// Yang dikejar di sini bukan "query-nya jalan", melainkan **kesetiaan
// round-trip**: sesi yang keluar dari basis data harus identik dengan yang
// masuk, sampai ke field terakhir. Data yang berubah diam-diam saat disimpan
// adalah kelas bug yang paling sulit dilacak — gejalanya baru muncul setelah
// restart, jauh dari penyebabnya.
//
// Basis datanya in-memory (`NativeDatabase.memory()`), jadi test ini tidak
// menyentuh disk dan tidak butuh Flutter binding.

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/repositories/basis_data.dart';
import 'package:asawatch/repositories/sesi_repository_drift.dart';

/// Sesi dengan lebih dari satu item makanan — `contohHasilDeteksi()` punya
/// tiga, sedangkan sesi di `contohRiwayatSesi()` masing-masing hanya satu.
/// Dipakai untuk menguji urutan item dan penulisan ulang setelah dikoreksi.
SesiMakan sesiTigaMakanan() {
  final dasar = contohRiwayatSesi().first;
  return SesiMakan(
    id: 'sesi-tiga-makanan',
    fotoPath: dasar.fotoPath,
    waktuFoto: dasar.waktuFoto,
    t0: dasar.t0,
    status: dasar.status,
    sampel: dasar.sampel,
    hasil: contohHasilDeteksi(),
  );
}

void main() {
  late BasisData db;
  late SesiRepositoryDrift repo;

  setUp(() {
    db = BasisData(NativeDatabase.memory());
    repo = SesiRepositoryDrift(db);
  });

  tearDown(() => db.close());

  /// Membandingkan dua sesi field demi field.
  ///
  /// Model-model ini tidak mengimplementasikan `==`, jadi `expect(a, b)` hanya
  /// akan membandingkan identitas dan lolos secara palsu.
  void samaPersis(SesiMakan hasil, SesiMakan asli) {
    expect(hasil.id, asli.id);
    expect(hasil.fotoPath, asli.fotoPath);
    expect(hasil.waktuFoto, asli.waktuFoto);
    expect(hasil.t0, asli.t0);
    expect(hasil.status, asli.status);

    expect(hasil.sampel.length, 4);
    for (var i = 0; i < 4; i++) {
      final a = asli.sampel[i];
      final b = hasil.sampel[i];
      expect(b.index, a.index, reason: 'sampel[$i].index');
      expect(b.detikRelatifT0, a.detikRelatifT0, reason: 'sampel[$i].detik');
      expect(b.status, a.status, reason: 'sampel[$i].status');
      expect(b.dariBuffer, a.dariBuffer, reason: 'sampel[$i].dariBuffer');
      expect(b.gulaDarah, a.gulaDarah, reason: 'sampel[$i].gulaDarah');
      expect(b.detakJantung, a.detakJantung, reason: 'sampel[$i].detak');
      expect(b.sistolik, a.sistolik, reason: 'sampel[$i].sistolik');
      expect(b.diastolik, a.diastolik, reason: 'sampel[$i].diastolik');
      expect(b.spo2, a.spo2, reason: 'sampel[$i].spo2');
    }

    final ha = asli.hasil;
    final hb = hasil.hasil;
    if (ha == null) {
      expect(hb, isNull);
      return;
    }
    expect(hb, isNotNull);
    expect(hb!.indeksGlikemikPerkiraan, ha.indeksGlikemikPerkiraan);
    expect(hb.keyakinan, ha.keyakinan);
    expect(hb.dikoreksiUser, ha.dikoreksiUser);
    expect(hb.total.kalori, ha.total.kalori);
    expect(hb.total.karbohidrat, ha.total.karbohidrat);
    expect(hb.total.protein, ha.total.protein);
    expect(hb.total.lemak, ha.total.lemak);
    expect(hb.total.gulaTotal, ha.total.gulaTotal);
    expect(hb.total.serat, ha.total.serat);

    expect(hb.makanan.length, ha.makanan.length);
    for (var i = 0; i < ha.makanan.length; i++) {
      expect(hb.makanan[i].nama, ha.makanan[i].nama);
      expect(hb.makanan[i].porsi, ha.makanan[i].porsi);
      expect(hb.makanan[i].estimasiGram, ha.makanan[i].estimasiGram);
      expect(hb.makanan[i].nutrisi.kalori, ha.makanan[i].nutrisi.kalori);
      expect(
        hb.makanan[i].nutrisi.karbohidrat,
        ha.makanan[i].nutrisi.karbohidrat,
      );
      expect(hb.makanan[i].nutrisi.serat, ha.makanan[i].nutrisi.serat);
    }
  }

  group('Round-trip', () {
    test('seluruh riwayat contoh kembali utuh', () async {
      final asli = contohRiwayatSesi();
      for (final s in asli) {
        await repo.simpan(s);
      }

      final hasil = await repo.muatSemua();

      expect(hasil.length, asli.length);
      final perId = {for (final s in hasil) s.id: s};
      for (final s in asli) {
        samaPersis(perId[s.id]!, s);
      }
    });

    test('sesi tanpa hasil deteksi kembali tanpa hasil deteksi', () async {
      // `hasil == null` adalah keadaan normal (analisis belum selesai), bukan
      // error, jadi ia harus bertahan melewati penyimpanan.
      final contoh = contohRiwayatSesi().first;
      final tanpa = SesiMakan(
        id: 'tanpa-hasil',
        fotoPath: contoh.fotoPath,
        waktuFoto: contoh.waktuFoto,
        t0: contoh.t0,
        status: contoh.status,
        sampel: contoh.sampel,
      );

      await repo.simpan(tanpa);

      samaPersis((await repo.muatSemua()).single, tanpa);
    });

    test(
      'metrik yang gagal diukur tetap null, tidak berubah jadi nol',
      () async {
        // Sentinel 0 milik protokol BLE; di sini nol berarti "terukur nol".
        final contoh = contohRiwayatSesi().first;
        final sesi = contoh.salin(
          sampel: [
            const Sampel(
              index: 0,
              detikRelatifT0: -600,
              status: StatusSampel.terisi,
              gulaDarah: 95,
              // detakJantung, sistolik, diastolik, spo2 sengaja tidak diisi
            ),
            contoh.sampel[1],
            contoh.sampel[2],
            const Sampel(
              index: 3,
              detikRelatifT0: 7200,
              status: StatusSampel.terlewat,
            ),
          ],
        );

        await repo.simpan(sesi);
        final kembali = (await repo.muatSemua()).single;

        expect(kembali.sampel[0].gulaDarah, 95);
        expect(kembali.sampel[0].detakJantung, isNull);
        expect(kembali.sampel[0].spo2, isNull);
        expect(kembali.sampel[3].status, StatusSampel.terlewat);
        expect(kembali.sampel[3].gulaDarah, isNull);
      },
    );

    test('urutan item makanan bertahan', () async {
      // ringkasanNama merangkai nama sesuai urutan; judul kartu yang berubah
      // antar restart akan terbaca sebagai bug.
      final asli = sesiTigaMakanan();
      expect(asli.hasil!.makanan.length, greaterThan(1));

      await repo.simpan(asli);
      final kembali = (await repo.muatSemua()).single;

      expect(kembali.hasil!.ringkasanNama, asli.hasil!.ringkasanNama);
    });

    test('nilai turunan ikut benar setelah dimuat ulang', () async {
      // Verdict dan kawan-kawannya tidak punya kolom — ia dihitung dari sampel.
      // Kalau sampelnya setia, turunannya ikut setia dengan sendirinya.
      final asli = contohRiwayatSesi().first;

      await repo.simpan(asli);
      final kembali = (await repo.muatSemua()).single;

      expect(kembali.puncakGulaDarah, asli.puncakGulaDarah);
      expect(kembali.kualitasRespons, asli.kualitasRespons);
      expect(kembali.waktuMakan, asli.waktuMakan);
    });
  });

  group('Kontrak repository', () {
    test('kosong saat pertama kali dibuka', () async {
      expect(await repo.muatSemua(), isEmpty);
    });

    test('terbaru di depan, diurutkan SQL bukan urutan penyisipan', () async {
      final asli = contohRiwayatSesi();
      // Disimpan dari yang paling lama supaya urutan penyisipan justru terbalik
      // dari yang diharapkan.
      for (final s in asli.reversed) {
        await repo.simpan(s);
      }

      final hasil = await repo.muatSemua();
      final kunci = hasil.map((s) => (s.t0 ?? s.waktuFoto)).toList();

      expect(hasil.map((s) => s.id), asli.map((s) => s.id));
      for (var i = 1; i < kunci.length; i++) {
        expect(kunci[i].isAfter(kunci[i - 1]), isFalse);
      }
    });

    test('menyimpan id yang sama menimpa, bukan menggandakan', () async {
      final asli = contohRiwayatSesi().first;
      await repo.simpan(asli);
      await repo.simpan(asli.salin(status: StatusSesi.tidakLengkap));

      final hasil = await repo.muatSemua();
      expect(hasil.length, 1);
      expect(hasil.single.status, StatusSesi.tidakLengkap);
    });

    test('menimpa tidak meninggalkan item makanan yang sudah dihapus', () async {
      // Koreksi user bisa menghapus item; menambal alih-alih menulis ulang akan
      // menyisakan makanan hantu yang ikut dijumlahkan.
      final asli = sesiTigaMakanan();
      await repo.simpan(asli);

      final dikoreksi = asli.salin(
        hasil: asli.hasil!.dikoreksi([asli.hasil!.makanan.first]),
      );
      await repo.simpan(dikoreksi);

      final hasil = (await repo.muatSemua()).single;
      expect(hasil.hasil!.makanan.length, 1);
      expect(hasil.hasil!.dikoreksiUser, isTrue);
      expect(hasil.hasil!.total.kalori, dikoreksi.hasil!.total.kalori);
    });

    test('data bertahan setelah basis data ditutup dan dibuka lagi', () async {
      // Inti dari seluruh Tahap A. Memakai berkas sungguhan, bukan memori:
      // basis data in-memory ikut hilang saat ditutup, jadi ia tidak bisa
      // membuktikan apa pun tentang ketahanan data.
      final dir = await Directory.systemTemp.createTemp('asawatch_uji');
      addTearDown(() => dir.delete(recursive: true));
      final berkas = File('${dir.path}/sesi.sqlite');

      final asli = contohRiwayatSesi().first;
      final dbTulis = BasisData(NativeDatabase(berkas));
      await SesiRepositoryDrift(dbTulis).simpan(asli);
      await dbTulis.close();

      final dbBaca = BasisData(NativeDatabase(berkas));
      addTearDown(dbBaca.close);
      final kembali = await SesiRepositoryDrift(dbBaca).muatSemua();

      expect(kembali.length, 1);
      samaPersis(kembali.single, asli);
    });
  });

  group('Ketahanan skema', () {
    test(
      'sampel yang hilang dari basis data diisi kembali sebagai menunggu',
      () async {
        // Hanya mungkin bila basis datanya rusak atau disunting tangan. Yang
        // penting: aplikasi tidak boleh jatuh saat start karena sampel[2] hilang.
        final asli = contohRiwayatSesi().first;
        await repo.simpan(asli);
        await (db.delete(db.tabelSampel)..where((t) => t.index.equals(2))).go();

        final kembali = (await repo.muatSemua()).single;

        expect(kembali.sampel.length, 4);
        expect(kembali.sampel[2].status, StatusSampel.menunggu);
        expect(kembali.sampel[2].detikRelatifT0, 3600);
      },
    );

    test('menghapus sesi ikut menghapus anak-anaknya', () async {
      final asli = contohRiwayatSesi().first;
      await repo.simpan(asli);

      await (db.delete(db.tabelSesi)..where((t) => t.id.equals(asli.id))).go();

      expect(await db.select(db.tabelSampel).get(), isEmpty);
      expect(await db.select(db.tabelItemMakanan).get(), isEmpty);
      expect(await db.select(db.tabelHasilDeteksi).get(), isEmpty);
    });
  });
}
