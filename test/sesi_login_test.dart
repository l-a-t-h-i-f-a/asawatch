// Tetap masuk setelah aplikasi ditutup: penyimpanan token, gerbang sesi di
// `main()`, dan tombol keluar.
//
// Yang diuji di sini bukan HTTP-nya (itu di auth_http_service_test.dart),
// melainkan keputusan yang menempel padanya: layar mana yang dibuka lebih dulu,
// kapan token ditulis, dan apa yang terjadi saat pengguna keluar.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/beranda_tab.dart';
import 'package:asawatch/main.dart';
import 'package:asawatch/repositories/profil_repository.dart';
import 'package:asawatch/repositories/sesi_login_repository.dart';
import 'package:asawatch/services/profil_server_service.dart';
import 'package:asawatch/services/auth_service.dart';
import 'package:asawatch/services/kamera_service.dart';
import 'package:asawatch/welcome_page.dart';

import 'helpers.dart';

SesiLogin _sesi({Duration sisa = const Duration(days: 30)}) => SesiLogin(
  token: '4|token-uji',
  kedaluwarsa: DateTime.now().add(sisa),
  nama: 'Uji Kontrak',
  email: 'uji.kontrak@asawatch.test',
);

Future<SesiLoginRepositoryMemori> _pump(
  WidgetTester tester, {
  SesiLogin? sesiAwal,
  FakeAuthService? auth,
  ProfilRepository profil = const ProfilRepository(),
}) async {
  pakaiLayarPonsel(tester);
  SharedPreferences.setMockInitialValues({});

  final c = buatControllerUji();
  addTearDown(c.dispose);
  final a = auth ?? FakeAuthService();
  addTearDown(a.dispose);
  final penyimpanan = SesiLoginRepositoryMemori(sesiAwal);

  await tester.pumpWidget(
    MyApp(
      controller: c,
      auth: a,
      kamera: KameraPalsuService(),
      sesiLogin: penyimpanan,
      sesiAwal: sesiAwal,
      profil: profil,
    ),
  );
  await tester.pumpAndSettle();
  return penyimpanan;
}

void main() {
  setUpAll(loadMontserrat);

  group('Gerbang sesi', () {
    testWidgets('token tersimpan membuka beranda, bukan halaman sambutan', (
      tester,
    ) async {
      await _pump(tester, sesiAwal: _sesi());

      expect(find.byType(BerandaTab), findsOneWidget);
      // Tidak boleh ada satu frame pun yang menampilkan sambutan kepada orang
      // yang sudah masuk — karena itu sesinya dibaca di `main()`, sebelum
      // `runApp`, bukan di dalam sebuah layar pemuatan.
      expect(find.byType(WelcomePage), findsNothing);
    });

    testWidgets('tanpa token tetap mulai dari halaman sambutan', (tester) async {
      await _pump(tester);

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.byType(BerandaTab), findsNothing);
    });

    test('sesi kedaluwarsa dibuang saat dimuat, bukan dipakai sekali lagi', () async {
      final penyimpanan = SesiLoginRepositoryMemori(
        _sesi(sisa: const Duration(seconds: -1)),
      );

      // Token mati yang dikembalikan apa adanya hanya akan dipakai sekali,
      // ditolak server, lalu menyisakan pengguna menebak apa yang salah.
      expect(await penyimpanan.muat(), isNull);
      expect(penyimpanan.jumlahHapus, 1);
    });
  });

  group('Masuk dan keluar', () {
    testWidgets('masuk yang berhasil menyimpan sesinya', (tester) async {
      final penyimpanan = await _pump(tester);

      await tester.tap(find.text('Masuk ke Akun'));
      await tester.pumpAndSettle();

      final akun = FakeAuthService.akunDemo.first;
      await tester.enterText(find.byType(TextField).at(0), akun.identifier);
      await tester.enterText(find.byType(TextField).at(1), akun.kataSandi);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(find.byType(BerandaTab), findsOneWidget);
      final tersimpan = await penyimpanan.muat();
      expect(tersimpan, isNotNull);
      expect(tersimpan!.token, isNotEmpty);
    });

    // Bug yang ditemukan di perangkat: pada pemasangan baru, salinan lokal
    // profil masih kosong, dan profil hanya ditarik saat halaman Informasi
    // Pribadi dibuka — sehingga Beranda menyapa tanpa nama dan Profil tampak
    // belum diisi, padahal akunnya punya semuanya.
    testWidgets('masuk langsung mengisi nama dari akun, bukan menunggu '
        'halaman profil dibuka', (tester) async {
      final server = ProfilServerPalsu(
        tersimpan: Profil.kosong.salin(nama: 'Uji Kontrak', tinggi: '168'),
        diperbaruiPada: DateTime.now(),
      );

      await _pump(
        tester,
        profil: ProfilRepository(
          server: server,
          sesiLogin: SesiLoginRepositoryMemori(
            SesiLogin(
              token: '4|token-uji',
              kedaluwarsa: DateTime.now().add(const Duration(days: 30)),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Masuk ke Akun'));
      await tester.pumpAndSettle();
      final akun = FakeAuthService.akunDemo.first;
      await tester.enterText(find.byType(TextField).at(0), akun.identifier);
      await tester.enterText(find.byType(TextField).at(1), akun.kataSandi);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(find.text('Halo, Uji Kontrak'), findsOneWidget);
    });

    testWidgets('kembali di Beranda keluar dari aplikasi, bukan ke sambutan', (
      tester,
    ) async {
      await _pump(tester);

      await tester.tap(find.text('Masuk ke Akun'));
      await tester.pumpAndSettle();
      final akun = FakeAuthService.akunDemo.first;
      await tester.enterText(find.byType(TextField).at(0), akun.identifier);
      await tester.enterText(find.byType(TextField).at(1), akun.kataSandi);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      // Halaman sambutan tidak boleh tertinggal di bawah Beranda: tombol
      // kembali yang memunculkannya lagi dibaca pengguna sebagai keluar dari
      // akun, padahal ia masih masuk.
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      expect(navigator.canPop(), isFalse);
    });

    testWidgets('kembali dari tab lain mengembalikan ke Beranda dulu', (
      tester,
    ) async {
      await _pump(tester, sesiAwal: _sesi());

      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();
      expect(find.text('Riwayat Sesi'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();

      // Keluar dari aplikasi saat sedang membuka Riwayat adalah kejutan, bukan
      // jalan keluar yang diminta.
      expect(find.byType(BerandaTab), findsOneWidget);
      expect(find.text('Riwayat Sesi'), findsNothing);
    });

    testWidgets('keluar mencabut token di server lalu menghapusnya di sini', (
      tester,
    ) async {
      final auth = FakeAuthService();
      final penyimpanan = await _pump(tester, sesiAwal: _sesi(), auth: auth);

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();

      // Keluar selalu ditanya dulu: tombolnya duduk tepat di bawah menu yang
      // sering disentuh, dan masuk kembali menuntut mengetik sandi lagi.
      expect(find.text('Keluar dari akun?'), findsOneWidget);
      await tester.tap(find.widgetWithText(TextButton, 'Keluar'));
      await tester.pumpAndSettle();

      // Token Sanctum berumur 30 hari: keluar yang hanya menghapus salinan di
      // ponsel meninggalkan kunci yang masih sah selama itu.
      expect(auth.tokenDicabut, ['4|token-uji']);
      expect(await penyimpanan.muat(), isNull);
      expect(find.byType(WelcomePage), findsOneWidget);
    });

    testWidgets('membatalkan dialog keluar tidak menyentuh apa pun', (
      tester,
    ) async {
      final auth = FakeAuthService();
      final penyimpanan = await _pump(tester, sesiAwal: _sesi(), auth: auth);

      await tester.tap(find.text('Profil'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Keluar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Batal'));
      await tester.pumpAndSettle();

      expect(auth.tokenDicabut, isEmpty);
      expect(await penyimpanan.muat(), isNotNull);
      expect(find.byType(WelcomePage), findsNothing);
    });
  });
}
