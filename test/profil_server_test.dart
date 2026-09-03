// Profil yang disamakan dengan server (docs/rancangan-api-laravel.md §5.1).
//
// Yang diuji di sini adalah keputusannya, bukan HTTP-nya: siapa yang menang
// saat dua sisi berbeda, apa yang tetap tinggal di ponsel, dan kalimat apa yang
// dilihat pengguna saat simpanannya belum sampai ke server.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/informasi_pribadi_page.dart';
import 'package:asawatch/repositories/profil_repository.dart';
import 'package:asawatch/repositories/sesi_login_repository.dart';
import 'package:asawatch/services/auth_service.dart';
import 'package:asawatch/services/profil_server_service.dart';

import 'helpers.dart';

Profil _profil({String nama = 'Rara', String tinggi = '162'}) => Profil(
  nama: nama,
  tanggalLahir: '1998-04-17',
  jenisKelamin: 'Perempuan',
  tinggi: tinggi,
  berat: '54.5',
  golonganDarah: 'O',
  email: 'rara@email.com',
);

SesiLoginRepositoryMemori _sesiMasuk() => SesiLoginRepositoryMemori(
  SesiLogin(
    token: '4|token-uji',
    kedaluwarsa: DateTime.now().add(const Duration(days: 30)),
  ),
);

void main() {
  setUpAll(loadMontserrat);

  group('Siapa yang menang', () {
    test('server yang lebih baru menimpa salinan lokal', () async {
      SharedPreferences.setMockInitialValues({});
      // Lokal disunting lebih dulu, tetapi stempelnya lebih tua.
      await const ProfilRepository().simpan(_profil(nama: 'Rara Lama'));

      final server = ProfilServerPalsu(
        tersimpan: _profil(nama: 'Rara Server', tinggi: '170'),
        diperbaruiPada: DateTime.now().add(const Duration(seconds: 5)),
      );
      final repo = ProfilRepository(server: server, sesiLogin: _sesiMasuk());

      final hasil = await repo.muatSegar();

      expect(hasil.nama, 'Rara Server');
      expect(hasil.tinggi, '170');
      // Yang tersimpan lokal ikut diperbarui, bukan hanya yang dikembalikan.
      expect((await const ProfilRepository().muat()).nama, 'Rara Server');
    });

    test('email lokal tidak pernah ditimpa server', () async {
      SharedPreferences.setMockInitialValues({});
      await const ProfilRepository().simpan(_profil());

      // §5.1 tidak punya field ini sama sekali, jadi jawaban server selalu
      // membawanya kosong.
      final server = ProfilServerPalsu(
        tersimpan: _profil(nama: 'Rara Server').salin(email: ''),
        diperbaruiPada: DateTime.now().add(const Duration(seconds: 5)),
      );
      final repo = ProfilRepository(server: server, sesiLogin: _sesiMasuk());

      final hasil = await repo.muatSegar();

      expect(hasil.nama, 'Rara Server');
      expect(hasil.email, 'rara@email.com');
    });

    test('lokal yang lebih baru justru didorong ke server', () async {
      SharedPreferences.setMockInitialValues({});
      final server = ProfilServerPalsu(
        tersimpan: _profil(nama: 'Rara Server'),
        diperbaruiPada: DateTime.now().subtract(const Duration(days: 1)),
        // Disunting saat tanpa sinyal: tersimpan di ponsel, tidak sampai ke
        // server.
        gagalKirim: true,
      );
      final repo = ProfilRepository(server: server, sesiLogin: _sesiMasuk());
      await repo.simpan(_profil(nama: 'Rara Baru'));

      server.gagalKirim = false; // jaringan kembali
      final hasil = await repo.muatSegar();

      // Suntingan yang dibuat saat tanpa sinyal tetap sampai pada pembukaan
      // halaman berikutnya — itulah gunanya dorongan ini.
      expect(hasil.nama, 'Rara Baru');
      expect(server.dikirim.single.nama, 'Rara Baru');
    });

    test('tanpa token, server tidak pernah disentuh', () async {
      SharedPreferences.setMockInitialValues({});
      final server = ProfilServerPalsu(
        tersimpan: _profil(nama: 'Rara Server'),
        diperbaruiPada: DateTime.now(),
      );
      final repo = ProfilRepository(
        server: server,
        sesiLogin: SesiLoginRepositoryMemori(), // belum masuk
      );
      await const ProfilRepository().simpan(_profil(nama: 'Rara Lokal'));

      expect((await repo.muatSegar()).nama, 'Rara Lokal');
      expect(server.dikirim, isEmpty);
    });
  });

  group('Satu ponsel, dua pengguna', () {
    test('akun yang berbeda membuang profil pengguna sebelumnya', () async {
      SharedPreferences.setMockInitialValues({});
      final server = ProfilServerPalsu(
        tersimpan: Profil.kosong.salin(nama: 'Budi'),
        diperbaruiPada: DateTime.now(),
      );
      final repo = ProfilRepository(server: server, sesiLogin: _sesiMasuk());

      await repo.sinkronSetelahMasuk('rara@email.com');
      await repo.simpan(_profil()); // Rara mengisi profilnya

      // Akun lain, isi server lain.
      server.tersimpan = Profil.kosong.salin(nama: 'Budi');
      server.diperbaruiPada = DateTime.now().add(const Duration(seconds: 5));

      final sesudah = await repo.sinkronSetelahMasuk('budi@email.com');

      // Email tidak ada di §5.1, jadi penyamaan dengan server tidak akan
      // pernah membersihkannya sendiri — kalau tidak dibuang di sini, Budi
      // melihat alamat Rara. Nilainya di bawah justru buktinya: email akun
      // hanya diisikan bila yang tersimpan kosong, jadi 'budi@email.com'
      // hanya mungkin muncul kalau penghapusan lokal benar-benar berjalan.
      expect(sesudah.profil.nama, 'Budi');
      expect(sesudah.profil.email, 'budi@email.com');
      // Dilaporkan ke pemanggil, bukan berhenti di sini: riwayat sesi dan
      // kalibrasi juga milik satu orang, dan hanya alur masuk yang bisa
      // membuangnya.
      expect(sesudah.gantiAkun, isTrue);
    });

    test('akun yang sama mempertahankan isian lokalnya', () async {
      SharedPreferences.setMockInitialValues({});
      final server = ProfilServerPalsu(
        tersimpan: Profil.kosong.salin(nama: 'Rara'),
        diperbaruiPada: DateTime.now().subtract(const Duration(days: 1)),
      );
      final repo = ProfilRepository(server: server, sesiLogin: _sesiMasuk());

      await repo.sinkronSetelahMasuk('rara@email.com');
      await repo.simpan(_profil(nama: 'Rara'));

      final sesudah = await repo.sinkronSetelahMasuk('rara@email.com');

      expect(sesudah.profil.email, 'rara@email.com');
      expect(sesudah.profil.tinggi, '162');
      expect(sesudah.gantiAkun, isFalse);
    });
  });

  group('Menyimpan', () {
    test('gagal kirim tetap tersimpan di ponsel', () async {
      SharedPreferences.setMockInitialValues({});
      final server = ProfilServerPalsu(gagalKirim: true);
      final repo = ProfilRepository(server: server, sesiLogin: _sesiMasuk());

      final status = await repo.simpan(_profil(nama: 'Rara Offline'));

      expect(status, StatusSimpanProfil.lokalSaja);
      expect((await repo.muat()).nama, 'Rara Offline');
    });

    testWidgets('yang belum sampai ke server tidak diakui "berhasil disimpan"', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      pakaiLayarPonsel(tester);
      final repo = ProfilRepository(
        server: ProfilServerPalsu(gagalKirim: true),
        sesiLogin: _sesiMasuk(),
      );

      // Didorong sebagai rute kedua, bukan `home:`. Halaman ini menutup
      // dirinya sendiri setelah menyimpan, dan rute pertama tidak punya apa pun
      // untuk dituju saat pop.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Montserrat', useMaterial3: true),
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<bool>(
                      builder: (_) => InformasiPribadiPage(profil: repo),
                    ),
                  ),
                  child: const Text('buka'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('buka'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).first, 'Rara');
      await tester.tap(find.text('Simpan'));
      await tester.pumpAndSettle();

      // Mengaku "berhasil disimpan" untuk sesuatu yang belum sampai ke akun
      // membuat orang mengira datanya aman, lalu kehilangannya saat ganti HP.
      expect(find.textContaining('Tersimpan di ponsel ini'), findsOneWidget);
      expect(find.text('Perubahan berhasil disimpan!'), findsNothing);
    });
  });

  group('Bentuk JSON', () {
    test('field kosong dikirim sebagai null, bukan string kosong', () async {
      late http.Request terkirim;
      final layanan = ProfilHttpService(
        basisUrl: 'http://uji.lokal:8080',
        klien: MockClient((req) async {
          terkirim = req;
          return http.Response('{"data":{}}', 200);
        }),
      );

      await layanan.kirim('t', Profil.kosong);

      final badan = jsonDecode(terkirim.body) as Map<String, dynamic>;
      expect(terkirim.url.toString(), 'http://uji.lokal:8080/api/v1/profil');
      // `""` akan ditolak validator format tanggal, padahal artinya sama
      // dengan "belum diisi".
      expect(badan['tanggal_lahir'], isNull);
      expect(badan['jenis_kelamin'], isNull);
      expect(badan['tinggi_cm'], isNull);
      layanan.dispose();
    });

    test('jenis kelamin diterjemahkan dua arah', () async {
      late http.Request terkirim;
      final layanan = ProfilHttpService(
        basisUrl: 'http://uji.lokal:8080',
        klien: MockClient((req) async {
          terkirim = req;
          return http.Response(
            jsonEncode({
              'data': {
                'nama': 'Rara',
                'jenis_kelamin': 'perempuan',
                'tinggi_cm': 162,
                'berat_kg': 54.5,
                'diperbarui_pada': '2026-08-20T05:48:25.000000Z',
              },
            }),
            200,
          );
        }),
      );

      await layanan.kirim('t', _profil());
      expect((jsonDecode(terkirim.body) as Map)['jenis_kelamin'], 'perempuan');

      final dariServer = await layanan.ambil('t');
      // Label tampilan, bukan nilai enum: nilai yang tidak ada di `items`
      // membuat DropdownButtonFormField melempar.
      expect(dariServer!.profil.jenisKelamin, 'Perempuan');
      // 162.0 yang tampil sebagai "162.0" terbaca sebagai presisi yang tidak
      // pernah diukur.
      expect(dariServer.profil.tinggi, '162');
      expect(dariServer.profil.berat, '54.5');
      layanan.dispose();
    });
  });
}
