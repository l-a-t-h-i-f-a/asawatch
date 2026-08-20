// Unggahan riwayat sesi ke server (docs/rancangan-api-laravel.md §5.2).
//
// Satu arah: aplikasi mengunggah, tidak pernah mengunduh. Yang diuji di sini
// adalah kapan ia mengirim, apa yang ikut terbawa, dan apa yang terjadi kalau
// gagal — bukan HTTP-nya.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/services/ble_service.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/repositories/sesi_login_repository.dart';
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
  group('Kapan sesi dikirim', () {
    test('sesi yang berakhir langsung diunggah', () async {
      final server = SesiServerPalsu();
      final c = buatControllerUji(serverSesi: server, sesiLogin: _masuk());
      addTearDown(c.dispose);

      await c.mulaiDraft('/tmp/foto.jpg');
      (c.ble as FakeBleService).tekanSelesaiMakan();
      await Future<void>.delayed(Duration.zero);
      await c.akhiriLebihAwal();
      await Future<void>.delayed(Duration.zero);

      expect(server.diterima.single.id, c.riwayat.single.id);
    });

    test('gagal mengunggah tidak menjatuhkan sesinya', () async {
      final server = SesiServerPalsu(gagal: true);
      final c = buatControllerUji(serverSesi: server, sesiLogin: _masuk());
      addTearDown(c.dispose);

      await c.mulaiDraft('/tmp/foto.jpg');
      (c.ble as FakeBleService).tekanSelesaiMakan();
      await Future<void>.delayed(Duration.zero);
      await c.akhiriLebihAwal();
      await Future<void>.delayed(Duration.zero);

      // Datanya tetap di ponsel, dan akan dikirim lagi saat aplikasi dibuka
      // berikutnya — tidak ada yang hilang, jadi tidak ada yang perlu
      // dikeluhkan ke pengguna.
      expect(server.diterima, isEmpty);
      expect(c.riwayat, hasLength(1));
      expect(c.galatPenyimpanan, isNull);
    });

    test('tanpa token, tidak ada yang dikirim', () async {
      final server = SesiServerPalsu();
      final c = buatControllerUji(
        serverSesi: server,
        sesiLogin: SesiLoginRepositoryMemori(), // belum masuk
      );
      addTearDown(c.dispose);

      await c.mulaiDraft('/tmp/foto.jpg');
      (c.ble as FakeBleService).tekanSelesaiMakan();
      await Future<void>.delayed(Duration.zero);
      await c.akhiriLebihAwal();
      await c.kirimRiwayatKeServer();

      expect(server.diterima, isEmpty);
    });

    test('kirimRiwayatKeServer mengirim ulang seluruh riwayat', () async {
      final server = SesiServerPalsu(gagal: true);
      final c = buatControllerUji(serverSesi: server, sesiLogin: _masuk());
      addTearDown(c.dispose);

      await c.mulaiDraft('/tmp/foto.jpg');
      (c.ble as FakeBleService).tekanSelesaiMakan();
      await Future<void>.delayed(Duration.zero);
      await c.akhiriLebihAwal();
      await Future<void>.delayed(Duration.zero);
      expect(server.diterima, isEmpty);

      // Jaringan kembali; percobaan ulang tidak menuntut catatan apa pun,
      // karena PUT-nya idempoten terhadap UUID buatan aplikasi.
      server.gagal = false;
      await c.kirimRiwayatKeServer();

      expect(server.diterima, hasLength(1));
    });
  });

  group('Bentuk yang dikirim', () {
    test('sesi uji ikut naik, lengkap dengan tandanya', () {
      final sesi = SesiMakan(
        id: 'a1',
        fotoPath: '/tmp/f.jpg',
        waktuFoto: DateTime.utc(2026, 8, 20, 4, 12, 31),
        t0: DateTime.utc(2026, 8, 20, 4, 22, 10),
        status: StatusSesi.selesai,
        sesiUji: true,
        sampel: const [
          Sampel(
            index: 0,
            detikRelatifT0: -580,
            status: StatusSampel.terisi,
            gulaDarah: 96,
            detakJantung: 74,
            sistolik: 118,
            diastolik: 76,
            spo2: 98,
          ),
          Sampel(index: 1, detikRelatifT0: 0, status: StatusSampel.menunggu),
        ],
      );

      final badan = badanSesi(sesi);

      // Tandanya yang menjaga angka sesi dua menit tidak ikut dihitung di
      // server; menyembunyikan sesinya sendiri justru membuat jalur unggah ini
      // tak pernah terlatih.
      expect(badan['sesi_uji'], isTrue);
      expect(badan['status'], 'selesai');
      // UTC, bukan waktu lokal: server di zona lain akan menggeser setiap sesi.
      expect(badan['waktu_foto'], '2026-08-20T04:12:31.000000Z');
      expect(badan['t0'], '2026-08-20T04:22:10.000000Z');

      final sampel = badan['sampel'] as List;
      expect(sampel, hasLength(2));
      expect(sampel[0]['index'], 0);
      expect(sampel[0]['gula_darah'], 96);
      expect(sampel[1]['status'], 'menunggu');
      // Gagal diukur dikirim sebagai null — 0 adalah nilai yang berarti.
      expect(sampel[1]['gula_darah'], isNull);

      // Harus tetap bisa di-encode: satu objek DateTime yang lolos akan
      // melempar tepat saat dikirim, bukan saat dibangun.
      expect(() => jsonEncode(badan), returnsNormally);
    });

    test('sesi tanpa t0 mengirim null, bukan dilewati', () {
      final badan = badanSesi(
        SesiMakan(
          id: 'a2',
          fotoPath: '/tmp/f.jpg',
          waktuFoto: DateTime.utc(2026, 8, 20, 4, 12, 31),
          status: StatusSesi.draft,
          sampel: const [],
        ),
      );

      expect(badan.containsKey('t0'), isTrue);
      expect(badan['t0'], isNull);
    });
  });
}
