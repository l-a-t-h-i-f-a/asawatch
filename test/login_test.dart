// Halaman login terhadap auth palsu — lima kondisi, tanpa satu pun soket.
//
// Inilah alasan `FakeAuthService` ada. Tiga dari kondisi di bawah
// (`TidakAdaJaringan`, `ServerBermasalah`, `WaktuHabis`) tidak bisa diminta
// dari server sungguhan tanpa merusak servernya atau mencabut WiFi, padahal
// justru merekalah yang paling sering dilihat pengguna di lapangan.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/login_page.dart';
import 'package:asawatch/main.dart';
import 'package:asawatch/services/auth_service.dart';

import 'helpers.dart';

Future<FakeAuthService> pumpLogin(
  WidgetTester tester, {
  HasilMasuk? paksa,
  Duration jeda = Duration.zero,
}) async {
  final auth = FakeAuthService(paksa: paksa, jeda: jeda);
  addTearDown(auth.dispose);
  await pumpHalaman(tester, LoginPage(auth: auth));
  return auth;
}

/// Mengisi formulir dengan akun demo dan menekan "Masuk".
///
/// Kredensialnya sengaja yang benar: yang sedang diuji adalah jawaban dari
/// auth, bukan validasi bentuk isian — dan sejak `terimaSemua` bawaannya false,
/// kombinasi asal-asalan akan ditolak sebelum sampai ke sana.
Future<void> isiDanMasuk(WidgetTester tester) async {
  final akun = FakeAuthService.akunDemo.first;
  await tester.enterText(find.byType(TextFormField).at(0), akun.identifier);
  await tester.enterText(find.byType(TextFormField).at(1), akun.kataSandi);
  await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadMontserrat);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('masuk yang berhasil menggantikan login dengan shell', (
    tester,
  ) async {
    await pumpLogin(tester);

    await isiDanMasuk(tester);
    await tester.pumpAndSettle();

    expect(find.byType(MyHomePage), findsOneWidget);
    // pushReplacement: login harus hilang, bukan menumpuk di bawahnya.
    expect(find.byType(LoginPage), findsNothing);
  });

  testWidgets('kata sandi yang salah ditolak tanpa perlu dipesan', (
    tester,
  ) async {
    await pumpLogin(tester);

    // Tanpa `paksa:` sama sekali — inilah gunanya `terimaSemua` bawaannya
    // false: auth palsu yang meloloskan apa pun tidak pernah melewati jalur ini
    // dengan sendirinya, dan jalur inilah yang paling sering ditemui pengguna.
    await tester.enterText(
      find.byType(TextFormField).at(0),
      FakeAuthService.akunDemo.first.identifier,
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'sandi-salah');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
    await tester.pumpAndSettle();

    expect(find.text(const KredensialSalah().pesan), findsOneWidget);
    expect(find.byType(MyHomePage), findsNothing);
  });

  group('kegagalan punya kalimatnya masing-masing', () {
    testWidgets('kredensial salah: pesannya sendiri, tanpa "Coba Lagi"', (
      tester,
    ) async {
      await pumpLogin(tester, paksa: const KredensialSalah());

      await isiDanMasuk(tester);
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(MyHomePage), findsNothing);
      expect(find.text(const KredensialSalah().pesan), findsOneWidget);

      // Satu-satunya kegagalan yang tidak menawarkan pengulangan: permintaan
      // yang sama persis pasti gagal lagi, dan tombolnya akan menyiratkan
      // bahwa yang diketik pengguna sudah benar.
      expect(find.text('Coba Lagi'), findsNothing);
    });

    testWidgets('tidak ada jaringan: pesannya sendiri, dengan "Coba Lagi"', (
      tester,
    ) async {
      await pumpLogin(tester, paksa: const TidakAdaJaringan());

      await isiDanMasuk(tester);
      await tester.pumpAndSettle();

      expect(find.text(const TidakAdaJaringan().pesan), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);
    });

    testWidgets('server bermasalah tidak menyalahkan pengguna', (tester) async {
      await pumpLogin(tester, paksa: const ServerBermasalah());

      await isiDanMasuk(tester);
      await tester.pumpAndSettle();

      expect(find.text(const ServerBermasalah().pesan), findsOneWidget);
      expect(find.text('Coba Lagi'), findsOneWidget);

      // Kalimatnya tidak boleh menyuruh memeriksa kata sandi: yang rusak
      // adalah servernya, dan meragukan sandi yang sudah benar adalah jalan
      // buntu yang bisa berlangsung lama. Diperiksa pada kalimatnya sendiri,
      // bukan pada seluruh layar — halaman ini memang memuat label "Kata Sandi"
      // dan tautan "Lupa kata sandi?".
      expect(const ServerBermasalah().pesan, isNot(contains('kata sandi')));
    });

    testWidgets('waktu habis punya kalimat terpisah dari tanpa jaringan', (
      tester,
    ) async {
      await pumpLogin(tester, paksa: const WaktuHabis());

      await isiDanMasuk(tester);
      await tester.pumpAndSettle();

      expect(find.text(const WaktuHabis().pesan), findsOneWidget);
      expect(find.text(const TidakAdaJaringan().pesan), findsNothing);
    });

    testWidgets('"Coba Lagi" benar-benar mengulang permintaannya', (
      tester,
    ) async {
      final auth = await pumpLogin(tester, paksa: const ServerBermasalah());

      await isiDanMasuk(tester);
      await tester.pumpAndSettle();
      expect(auth.jumlahPanggilan, 1);

      await tester.tap(find.text('Coba Lagi'));
      await tester.pumpAndSettle();

      expect(auth.jumlahPanggilan, 2);
    });
  });

  group('keadaan sedang menunggu', () {
    testWidgets('tombol terkunci dan permintaan kedua tidak pernah terkirim', (
      tester,
    ) async {
      final auth = await pumpLogin(
        tester,
        paksa: const KredensialSalah(),
        jeda: const Duration(milliseconds: 400),
      );

      await isiDanMasuk(tester);
      await tester.pump(const Duration(milliseconds: 50));

      // Tombolnya dinonaktifkan, bukan sekadar mengabaikan ketukan, supaya
      // keadaan "sedang bekerja" terlihat dan bukan hanya diketahui.
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      final tombol = tester.widget<ElevatedButton>(
        find.byType(ElevatedButton).first,
      );
      expect(tombol.onPressed, isNull);

      // Dua permintaan masuk yang berjalan bersamaan menghasilkan dua token,
      // dan salah satunya langsung yatim. Dari layar keduanya terlihat persis
      // sama dengan satu, jadi hitungannya yang membuktikan.
      await tester.tap(find.byType(ElevatedButton).first);
      await tester.pump(const Duration(milliseconds: 50));
      expect(auth.jumlahPanggilan, 1);

      await tester.pumpAndSettle();
      expect(auth.jumlahPanggilan, 1);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  testWidgets('pesan galat hilang begitu isian disentuh', (tester) async {
    await pumpLogin(tester, paksa: const KredensialSalah());

    await isiDanMasuk(tester);
    await tester.pumpAndSettle();
    expect(find.text(const KredensialSalah().pesan), findsOneWidget);

    // Pesan yang menyuruh "periksa kembali" tetapi bertahan selagi pengguna
    // memperbaiki ketikannya terbaca seolah perbaikannya pun ditolak.
    await tester.enterText(find.byType(TextFormField).at(1), 'rahasia-baru');
    await tester.pump();

    expect(find.text(const KredensialSalah().pesan), findsNothing);
  });

  testWidgets('isian kosong ditolak sebelum auth pernah dipanggil', (
    tester,
  ) async {
    final auth = await pumpLogin(tester);

    await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
    await tester.pumpAndSettle();

    // Validasi bentuk tetap di depan: sebuah permintaan jaringan untuk
    // formulir yang jelas-jelas kosong hanya menukar jawaban seketika dengan
    // jawaban yang lambat.
    expect(auth.jumlahPanggilan, 0);
    expect(find.byType(MyHomePage), findsNothing);
  });
}
