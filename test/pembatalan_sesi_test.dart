// Sesi yang dibatalkan pengguna — dan apa yang terjadi padanya di server
// (docs/rancangan-api-laravel.md §5.2 `DELETE /sesi/{id}`, §7 `dihapus_pada`).
//
// Draft-nya sudah terunggah sejak rana ditekan, jadi pembatalan yang hanya
// berlaku di ponsel meninggalkan sesi yang tak pernah selesai di server. Yang
// diuji di sini adalah batu nisannya: kapan ia dibuat, kapan ia mati, dan apa
// yang dijaga selama ia hidup.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/repositories/sesi_login_repository.dart';
import 'package:asawatch/repositories/sesi_repository.dart';
import 'package:asawatch/services/auth_service.dart';
import 'package:asawatch/services/sesi_server_service.dart';

import 'helpers.dart';

SesiLoginRepositoryMemori _masuk() => SesiLoginRepositoryMemori(
  SesiLogin(
    token: '4|token-uji',
    kedaluwarsa: DateTime.now().add(const Duration(days: 30)),
  ),
);

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('asawatch_batal');
  });

  tearDown(() => dir.delete(recursive: true));

  Future<File> fotoContoh() async {
    final berkas = File('${dir.path}/foto.jpg');
    await berkas.writeAsBytes(const [1, 2, 3], flush: true);
    return berkas;
  }

  group('Pembatalan sesi', () {
    test('dengan akun: barisnya jadi nisan, lalu dihapus setelah diakui '
        'server', () async {
      final server = SesiServerPalsu();
      final repo = SesiRepositoryMemori();
      final c = buatControllerUji(
        repo: repo,
        serverSesi: server,
        sesiLogin: _masuk(),
      );
      addTearDown(c.dispose);

      await c.mulaiDraft((await fotoContoh()).path);
      final id = c.sesiAktif!.id;
      await c.batalkan();
      await Future<void>.delayed(Duration.zero);

      // Penghapusannya sampai ke server, dan nisannya tidak tinggal lebih lama
      // dari tugasnya.
      expect(server.dihapus, [id]);
      expect(await repo.ambilNisan(), isEmpty);
      expect(await repo.muatSemua(), isEmpty);
      expect(c.riwayat, isEmpty);
      expect(c.sesiAktif, isNull);
    });

    test('fotonya ikut dibuang, bukan hanya barisnya', () async {
      final berkas = await fotoContoh();
      final c = buatControllerUji(
        repo: SesiRepositoryMemori(),
        serverSesi: SesiServerPalsu(),
        sesiLogin: _masuk(),
      );
      addTearDown(c.dispose);

      await c.mulaiDraft(berkas.path);
      await c.batalkan();
      await Future<void>.delayed(Duration.zero);

      // Piring yang tidak jadi dimakan siapa pun tidak perlu tinggal di
      // penyimpanan ponsel — dan nisan hanya menyimpan id, bukan isi.
      expect(berkas.existsSync(), isFalse);
    });

    test('server gagal: nisannya bertahan dan tersapu lagi nanti', () async {
      final server = SesiServerPalsu(gagal: true);
      final repo = SesiRepositoryMemori();
      final c = buatControllerUji(
        repo: repo,
        serverSesi: server,
        sesiLogin: _masuk(),
      );
      addTearDown(c.dispose);

      await c.mulaiDraft((await fotoContoh()).path);
      final id = c.sesiAktif!.id;
      await c.batalkan();
      await Future<void>.delayed(Duration.zero);

      // Gagal berarti ditunda, bukan dilupakan: tanpa nisan yang bertahan, sesi
      // yang dibatalkan saat tidak ada sinyal hidup selamanya di server.
      expect(server.dihapus, isEmpty);
      expect(await repo.ambilNisan(), [id]);
      // Dan ia tetap tidak terlihat di ponsel selama menunggu.
      expect(await repo.muatSemua(), isEmpty);

      server.gagal = false;
      await c.kirimRiwayatKeServer();

      expect(server.dihapus, [id]);
      expect(await repo.ambilNisan(), isEmpty);
    });

    test('tanpa akun: dihapus tuntas, tidak menumpuk sebagai nisan', () async {
      final repo = SesiRepositoryMemori();
      final c = buatControllerUji(
        repo: repo,
        serverSesi: SesiServerPalsu(),
        sesiLogin: SesiLoginRepositoryMemori(), // belum masuk
      );
      addTearDown(c.dispose);

      await c.mulaiDraft((await fotoContoh()).path);
      await c.batalkan();
      await Future<void>.delayed(Duration.zero);

      // Tidak ada server yang perlu diberi tahu, jadi nisannya tidak akan
      // pernah bisa mati — karena itu ia tidak dibuat sejak awal.
      expect(await repo.ambilNisan(), isEmpty);
      expect(await repo.muatSemua(), isEmpty);
    });

    test('sesi yang dibatalkan tidak ditarik kembali oleh unduhan', () async {
      final server = SesiServerPalsu();
      final repo = SesiRepositoryMemori();
      final c = buatControllerUji(
        repo: repo,
        serverSesi: server,
        sesiLogin: _masuk(),
      );
      addTearDown(c.dispose);

      await c.mulaiDraft((await fotoContoh()).path);
      final id = c.sesiAktif!.id;
      await c.batalkan();
      await Future<void>.delayed(Duration.zero);

      // Draft-nya memang sempat sampai ke sana — itulah yang membuat nisan
      // diperlukan sama sekali.
      expect(server.diterima.map((s) => s.id), contains(id));

      // Urutan yang dijaga: penghapusan berangkat sebelum unduhan, jadi server
      // sudah tidak menawarkan sesi itu lagi saat riwayat ditarik.
      await c.kirimRiwayatKeServer();
      await c.unduhRiwayatDariServer();

      expect(await server.ambilSemua('4|token-uji'), isEmpty);
      expect(c.riwayat.map((s) => s.id), isNot(contains(id)));
      expect(c.riwayat, isEmpty);
    });
  });
}
