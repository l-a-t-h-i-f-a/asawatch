// Token yang ditolak server (401) harus melempar pengguna ke halaman masuk.
//
// Sebelum ini 401 hanya membuat permintaan yang bersangkutan gagal: unggahan
// sesi berhenti diam-diam dan profil tidak pernah tersegarkan, sementara
// aplikasi tetap menampilkan dirinya "sudah masuk". Tidak ada satu pun gejala
// yang bisa ditindaklanjuti — itu persis yang terjadi pada perangkat Titan
// setelah database backend dibersihkan.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/repositories/profil_repository.dart';
import 'package:asawatch/repositories/sesi_login_repository.dart';
import 'package:asawatch/services/auth_service.dart';
import 'package:asawatch/services/penjaga_sesi.dart';
import 'package:asawatch/services/profil_server_service.dart';
import 'package:asawatch/services/sesi_server_service.dart';
import 'package:asawatch/welcome_page.dart';

import 'helpers.dart';

SesiLoginRepositoryMemori _masuk() => SesiLoginRepositoryMemori(
  SesiLogin(
    token: '4|token-basi',
    kedaluwarsa: DateTime.now().add(const Duration(days: 30)),
  ),
);

http.Response _tolak(_) => http.Response(
  jsonEncode({
    'galat': {
      'kode': 'tidak_terautentikasi',
      'pesan': 'Sesi tidak valid, silakan masuk kembali.',
    },
  }),
  401,
);

void main() {
  setUpAll(loadMontserrat);

  group('Layanan melaporkan 401', () {
    test('profil: ambil dan kirim keduanya melapor', () async {
      var jumlah = 0;
      final layanan = ProfilHttpService(
        basisUrl: 'http://uji.lokal:8080',
        onTokenDitolak: () async => jumlah++,
        klien: MockClient((req) async => _tolak(req)),
      );
      addTearDown(layanan.dispose);

      expect(await layanan.ambil('t'), isNull);
      expect(await layanan.kirim('t', Profil.kosong), isFalse);
      expect(jumlah, 2);
    });

    test('sesi: unggahan yang ditolak melapor', () async {
      var jumlah = 0;
      final layanan = SesiHttpService(
        basisUrl: 'http://uji.lokal:8080',
        onTokenDitolak: () async => jumlah++,
        klien: MockClient((req) async => _tolak(req)),
      );
      addTearDown(layanan.dispose);

      final sesi = SesiMakan(
        id: 'a1',
        fotoPath: '/tmp/f.jpg',
        waktuFoto: DateTime.now(),
        status: StatusSesi.selesai,
        sampel: const [],
      );

      expect(await layanan.kirim('t', sesi), isFalse);
      expect(jumlah, 1);
    });

    test('galat lain tidak dianggap token basi', () async {
      var jumlah = 0;
      final layanan = ProfilHttpService(
        basisUrl: 'http://uji.lokal:8080',
        onTokenDitolak: () async => jumlah++,
        klien: MockClient((_) async => http.Response('rusak', 500)),
      );
      addTearDown(layanan.dispose);

      // Server yang sedang rusak bukan alasan mengeluarkan orang dari akunnya.
      expect(await layanan.ambil('t'), isNull);
      expect(jumlah, 0);
    });
  });

  group('PenjagaSesi', () {
    testWidgets('menghapus token, menjelaskan sebabnya, lalu ke sambutan', (
      tester,
    ) async {
      pakaiLayarPonsel(tester);
      final penyimpanan = _masuk();
      final navigatorKey = GlobalKey<NavigatorState>();
      final messengerKey = GlobalKey<ScaffoldMessengerState>();
      final penjaga = PenjagaSesi(
        sesiLogin: penyimpanan,
        navigatorKey: navigatorKey,
        messengerKey: messengerKey,
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          scaffoldMessengerKey: messengerKey,
          theme: ThemeData(fontFamily: 'Montserrat', useMaterial3: true),
          routes: {'/welcome': (_) => const WelcomePage()},
          home: const Scaffold(body: Text('Beranda pura-pura')),
        ),
      );

      await penjaga.tokenDitolak();
      await tester.pumpAndSettle();

      expect(await penyimpanan.muat(), isNull);
      expect(find.byType(WelcomePage), findsOneWidget);
      // Terlempar keluar tanpa sebab terbaca sebagai aplikasi yang rusak.
      expect(
        find.text('Sesi Anda sudah berakhir. Silakan masuk lagi.'),
        findsOneWidget,
      );
    });

    testWidgets('sepuluh penolakan sekaligus tetap satu kali keluar', (
      tester,
    ) async {
      pakaiLayarPonsel(tester);
      final penyimpanan = _masuk();
      final navigatorKey = GlobalKey<NavigatorState>();
      final penjaga = PenjagaSesi(
        sesiLogin: penyimpanan,
        navigatorKey: navigatorKey,
      );

      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          theme: ThemeData(fontFamily: 'Montserrat', useMaterial3: true),
          routes: {'/welcome': (_) => const WelcomePage()},
          home: const Scaffold(body: Text('Beranda pura-pura')),
        ),
      );

      // Keadaan normal, bukan buatan: seluruh riwayat dikirim ulang setiap kali
      // aplikasi dibuka, jadi satu token basi ditolak sekali per sesi.
      await Future.wait([for (var i = 0; i < 10; i++) penjaga.tokenDitolak()]);
      await tester.pumpAndSettle();

      expect(penyimpanan.jumlahHapus, 1);
      expect(find.byType(WelcomePage), findsOneWidget);
    });
  });
}
