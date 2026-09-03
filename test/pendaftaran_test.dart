// Pendaftaran akun (docs/rancangan-api-laravel.md §4 `daftar`).
//
// Sebelum ini halaman pendaftaran hanya memvalidasi form lalu menampilkan
// "Pendaftaran berhasil! Silakan masuk." tanpa satu pun permintaan ke server —
// kalimat yang tidak pernah benar. Yang diuji di sini adalah bahwa akunnya
// sungguh dibuat, tokennya disimpan, dan kegagalannya berbicara.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/beranda_tab.dart';
import 'package:asawatch/register_page.dart';
import 'package:asawatch/repositories/profil_repository.dart';
import 'package:asawatch/repositories/sesi_login_repository.dart';
import 'package:asawatch/services/auth_http_service.dart';
import 'package:asawatch/services/auth_service.dart';
import 'package:asawatch/services/kamera_service.dart';

import 'helpers.dart';

Future<SesiLoginRepositoryMemori> _pumpDaftar(
  WidgetTester tester, {
  required AuthService auth,
}) async {
  pakaiLayarPonsel(tester);
  SharedPreferences.setMockInitialValues({});

  final c = buatControllerUji();
  addTearDown(c.dispose);
  final penyimpanan = SesiLoginRepositoryMemori();

  await tester.pumpWidget(
    ChangeNotifierProvider.value(
      value: c,
      child: MaterialApp(
        theme: ThemeData(fontFamily: 'Montserrat', useMaterial3: true),
        home: RegisterPage(
          auth: auth,
          kamera: KameraPalsuService(),
          sesiLogin: penyimpanan,
          profil: const ProfilRepository(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return penyimpanan;
}

Future<void> _isiFormulir(WidgetTester tester) async {
  final kolom = find.byType(TextFormField);
  await tester.enterText(kolom.at(0), 'Rara Baru');
  await tester.enterText(kolom.at(1), 'rara.baru@email.com');
  await tester.enterText(kolom.at(2), 'rahasia123');
  await tester.enterText(kolom.at(3), 'rahasia123');
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadMontserrat);

  group('Halaman pendaftaran', () {
    testWidgets(
      'mendaftar membuat akun, menyimpan token, lalu membuka Beranda',
      (tester) async {
        final auth = FakeAuthService();
        addTearDown(auth.dispose);
        final penyimpanan = await _pumpDaftar(tester, auth: auth);

        await _isiFormulir(tester);
        await tester.tap(find.widgetWithText(ElevatedButton, 'Daftar'));
        await tester.pumpAndSettle();

        // Akunnya sungguh dibuat — dan bisa dipakai masuk, seperti di server.
        expect(auth.akunBaru.single.identifier, 'rara.baru@email.com');
        // Server sudah memberi token pada balasan pendaftaran (§4), jadi tidak
        // ada langkah "silakan masuk" lagi.
        expect((await penyimpanan.muat())?.token, isNotEmpty);
        expect(find.byType(BerandaTab), findsOneWidget);
      },
    );

    testWidgets('email yang sudah terdaftar dijelaskan, bukan didiamkan', (
      tester,
    ) async {
      // Akun demo sudah memakai email ini.
      final auth = FakeAuthService(paksa: const EmailSudahDipakai());
      addTearDown(auth.dispose);
      final penyimpanan = await _pumpDaftar(tester, auth: auth);

      await _isiFormulir(tester);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Daftar'));
      await tester.pumpAndSettle();

      expect(find.textContaining('sudah terdaftar'), findsOneWidget);
      expect(find.byType(BerandaTab), findsNothing);
      expect(await penyimpanan.muat(), isNull);
      // Tidak ada tombol "Coba Lagi" untuk ini: mengulang hal yang sama persis
      // tidak akan pernah berhasil.
      expect(const EmailSudahDipakai().bisaDiulang, isFalse);
    });
  });

  group('AuthHttpService.daftar', () {
    test('mengirim ke /api/v1/auth/daftar dengan nama field kontrak', () async {
      late http.Request terkirim;
      final layanan = AuthHttpService(
        basisUrl: 'http://uji.lokal:8080',
        klien: MockClient((req) async {
          terkirim = req;
          return http.Response(
            jsonEncode({
              'data': {
                'token': '1|token-baru',
                'profil': {'nama': 'Rara Baru'},
              },
            }),
            201, // pembuatan; `wasRecentlyCreated` di Laravel
          );
        }),
      );
      addTearDown(layanan.dispose);

      final hasil = await layanan.daftar(
        nama: ' Rara Baru ',
        email: ' rara@email.com ',
        kataSandi: 'rahasia123',
      );

      expect(
        terkirim.url.toString(),
        'http://uji.lokal:8080/api/v1/auth/daftar',
      );
      final badan = jsonDecode(terkirim.body) as Map<String, dynamic>;
      expect(badan['nama'], 'Rara Baru');
      expect(badan['email'], 'rara@email.com');
      expect(badan['kata_sandi'], 'rahasia123');
      expect(badan['nama_perangkat'], isNotEmpty);

      // 201 tetap sukses: Laravel membalas 201 saat barisnya baru dibuat.
      expect(hasil, isA<MasukBerhasil>());
      expect((hasil as MasukBerhasil).sesi.nama, 'Rara Baru');
      expect(hasil.sesi.email, 'rara@email.com');
    });

    test(
      '422 yang menyebut field email berarti email sudah terdaftar',
      () async {
        final layanan = AuthHttpService(
          basisUrl: 'http://uji.lokal:8080',
          klien: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'galat': {
                  'kode': 'validasi_gagal',
                  'pesan': 'Email sudah digunakan.',
                  'detail': {
                    'email': ['Email sudah digunakan.'],
                  },
                },
              }),
              422,
            ),
          ),
        );
        addTearDown(layanan.dispose);

        // Server tidak punya kode khusus untuk ini; yang membedakan adalah
        // `detail`-nya. Bentuk email sudah divalidasi di layar sebelum dikirim,
        // jadi keluhan server tentang field itu praktis hanya punya satu arti.
        expect(
          await layanan.daftar(
            nama: 'Rara',
            email: 'sudah@ada.com',
            kataSandi: 'rahasia123',
          ),
          isA<EmailSudahDipakai>(),
        );
      },
    );

    // Yang penting bukan varian mana yang keluar, melainkan bahwa ia **bukan**
    // EmailSudahDipakai — kalimat "email sudah terdaftar" untuk kata sandi yang
    // terlalu pendek mengirim orang mengganti sesuatu yang sudah benar.
    test(
      '422 pada field lain tidak dibaca sebagai email sudah terdaftar',
      () async {
        final layanan = AuthHttpService(
          basisUrl: 'http://uji.lokal:8080',
          klien: MockClient(
            (_) async => http.Response(
              jsonEncode({
                'galat': {
                  'kode': 'validasi_gagal',
                  'pesan': 'Kata sandi minimal 8 karakter.',
                  'detail': {
                    'kata_sandi': ['Kata sandi minimal 8 karakter.'],
                  },
                },
              }),
              422,
            ),
          ),
        );
        addTearDown(layanan.dispose);

        expect(
          await layanan.daftar(nama: 'Rara', email: 'a@b.c', kataSandi: '123'),
          isA<KredensialSalah>(),
        );
      },
    );
  });
}
