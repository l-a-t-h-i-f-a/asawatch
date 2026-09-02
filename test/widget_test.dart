// Widget tests for the AsaWatch shell: welcome -> login -> home tabs.
//
// The app has no backend, so these cover the parts that actually hold logic:
// route wiring, form validation gating navigation, the bottom-nav index-2
// carve-out, and the SharedPreferences-backed profile name.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemChrome;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/controllers/sesi_makan_controller.dart';
import 'package:asawatch/main.dart';
import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/sesi_berjalan_page.dart';
import 'package:asawatch/welcome_page.dart';
import 'package:asawatch/login_page.dart';
import 'package:asawatch/register_page.dart';
import 'package:asawatch/deteksi_makanan_page.dart';
import 'package:asawatch/repositories/profil_repository.dart';
import 'package:asawatch/repositories/sesi_login_repository.dart';
import 'package:asawatch/services/auth_service.dart';
import 'package:asawatch/services/kamera_service.dart';
import 'package:asawatch/utils/gaya_sistem.dart';

import 'helpers.dart';

/// Pumps [MyApp] on a phone-sized surface. The layouts are designed for a
/// narrow viewport and overflow on the 800x600 test default.
///
/// Controller-nya disuntikkan agar jam palsu bisa dikendalikan dan riwayatnya
/// tidak bergantung pada data bawaan aplikasi (§11).
///
/// [auth] wajib disuntikkan dengan alasan yang sama seperti `izin:` pada alur
/// pemindaian: bawaan `MyApp` adalah `AuthHttpService`, dan sebuah permintaan
/// HTTP di dalam `flutter_test` tidak gagal dengan jelas — ia menggantung
/// sampai batas waktunya habis.
Future<void> pumpApp(
  WidgetTester tester, {
  SesiMakanController? controller,
  AuthService? auth,
}) async {
  pakaiLayarPonsel(tester);

  final c = controller ?? buatControllerUji(riwayatAwal: contohRiwayatSesi());
  addTearDown(c.dispose);

  final a = auth ?? FakeAuthService();
  addTearDown(a.dispose);

  await tester.pumpWidget(
    MyApp(
      controller: c,
      auth: a,
      kamera: KameraPalsuService(),
      // Yang sungguhan menyentuh Keystore Android, yang tidak ada di bawah
      // `flutter_test`.
      sesiLogin: SesiLoginRepositoryMemori(),
      // Bentuk tanpa server: bawaan `MyApp` merakit `ProfilHttpService` ke
      // alamat produksi, dan sebuah permintaan HTTP di dalam test tidak gagal
      // dengan jelas.
      profil: const ProfilRepository(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Walks welcome -> login and fills in valid credentials -> home.
Future<void> pumpHome(WidgetTester tester, {SesiMakanController? controller}) async {
  await pumpApp(tester, controller: controller);

  await tester.tap(find.text('Masuk ke Akun'));
  await tester.pumpAndSettle();

  // Akun demo `FakeAuthService`. Sejak `terimaSemua` bawaannya false, kredensial
  // yang dipakai di sini harus benar-benar cocok — auth palsu tidak lagi
  // meloloskan apa pun yang tidak kosong.
  final akun = FakeAuthService.akunDemo.first;
  await tester.enterText(find.byType(TextFormField).at(0), akun.identifier);
  await tester.enterText(find.byType(TextFormField).at(1), akun.kataSandi);

  await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadMontserrat);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('WelcomePage', () {
    testWidgets('is the initial route and offers both entry points', (tester) async {
      await pumpApp(tester);

      expect(find.byType(WelcomePage), findsOneWidget);
      expect(find.text('Pantau Kesehatanmu, Hidup Lebih Sehat'), findsOneWidget);
      expect(find.text('Mulai Sekarang'), findsOneWidget);
      expect(find.text('Masuk ke Akun'), findsOneWidget);
    });

    // Kedua tombol dulu membuka halaman yang sama; "Mulai Sekarang" kini
    // mengikuti teksnya dan membuka pendaftaran.
    testWidgets('"Mulai Sekarang" opens the register page', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Mulai Sekarang'));
      await tester.pumpAndSettle();

      expect(find.byType(RegisterPage), findsOneWidget);
      expect(find.byType(LoginPage), findsNothing);
    });

    testWidgets('"Masuk ke Akun" opens the login page', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Masuk ke Akun'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
    });
  });

  group('LoginPage', () {
    testWidgets('empty fields fail validation and block navigation', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Masuk ke Akun'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(MyHomePage), findsNothing);
      // Error text duplicates the hint text, so both copies are on screen.
      expect(find.text('Masukkan email atau nomor HP'), findsNWidgets(2));
      expect(find.text('Masukkan kata sandi'), findsNWidgets(2));
    });

    testWidgets('a valid form replaces login with the home shell', (tester) async {
      await pumpHome(tester);

      expect(find.byType(MyHomePage), findsOneWidget);
      // pushReplacement: login must be gone, not stacked underneath.
      expect(find.byType(LoginPage), findsNothing);
    });
  });

  group('Home shell', () {
    testWidgets('renders the four switchable tabs', (tester) async {
      await pumpHome(tester);

      for (final label in ['Beranda', 'Riwayat', 'Analisis', 'Profil']) {
        expect(find.text(label), findsOneWidget, reason: 'missing nav item $label');
      }
    });

    testWidgets('tapping a nav item switches the visible tab', (tester) async {
      await pumpHome(tester);

      expect(find.text('Riwayat Sesi'), findsNothing);

      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();

      expect(find.text('Riwayat Sesi'), findsOneWidget);
    });

    testWidgets('the centre camera button pushes food detection, not a tab', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.byIcon(Icons.photo_camera_rounded));
      await tester.pumpAndSettle();

      expect(find.byType(DeteksiMakananPage), findsOneWidget);

      // Popping returns to the tab that was showing before, not a blank slot.
      // The page rolls its own IconButton instead of a Material BackButton, so
      // tester.pageBack() cannot find it.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(DeteksiMakananPage), findsNothing);
      expect(find.text('Beranda'), findsOneWidget);
    });

    // Layar kamera adalah satu-satunya layar gelap, dan ia memasang gayanya
    // sendiri lewat AnnotatedRegion. Yang dulu tidak terjadi adalah
    // pengembaliannya: Flutter mencari anotasi teratas di pohon dan, kalau tidak
    // menemukan satu pun, membiarkan gaya terakhir yang terlanjur dikirim ke
    // sistem — sehingga bilah navigasi tetap hitam dan ikon bilah status tetap
    // putih di atas seluruh halaman terang sampai aplikasi dijalankan ulang.
    testWidgets('bilah sistem kembali terang setelah keluar dari kamera', (
      tester,
    ) async {
      await pumpHome(tester);
      expect(SystemChrome.latestStyle, gayaSistemTerang);

      await tester.tap(find.byIcon(Icons.photo_camera_rounded));
      await tester.pumpAndSettle();
      expect(SystemChrome.latestStyle, gayaSistemGelap);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(SystemChrome.latestStyle, gayaSistemTerang);
    });

    testWidgets('makna tombol tengah berubah mengikuti status sesi', (tester) async {
      final c = buatControllerUji(riwayatAwal: contohRiwayatSesi());
      await pumpHome(tester, controller: c);

      // Idle: tombol membuka kamera, dan shutter membuat sesi draft yang
      // kartunya bisa dikoreksi sebelum sesi dimulai (§4.5).
      await tester.tap(find.byIcon(Icons.photo_camera_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.photo_camera_rounded).last);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(c.sesiAktif!.status, StatusSesi.draft);
      expect(find.text('Hasil Analisis'), findsOneWidget);

      // Kembali ke shell tanpa menutup draft.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.byType(DeteksiMakananPage), findsNothing);

      // Draft: tombol yang sama membuka halaman sesi — app tidak lagi punya
      // aksi "selesai makan", karena tombolnya ada di jam (§6). Ikon piring
      // juga dipakai judul kartu sesi di Beranda, jadi yang diketuk adalah
      // yang terakhir — bottom nav digambar sesudah isi tab.
      await tester.tap(find.byIcon(Icons.restaurant_rounded).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SesiBerjalanPage), findsOneWidget);
      expect(c.sesiAktif!.t0, isNull);

      // Tombol di jam ditekan: barulah sesi berjalan.
      await tekanTombolJam(tester, c);
      await tester.pump(const Duration(milliseconds: 50));
      expect(c.sesiAktif!.status, StatusSesi.berjalan);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Sesi berjalan: tombol tetap membuka halaman sesi, bukan kamera.
      await tester.tap(find.byIcon(Icons.timelapse_rounded).last);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.byType(SesiBerjalanPage), findsOneWidget);

      await hentikanSesi(tester, c);
    });

    testWidgets('index 2 tetap mendorong halaman, tidak pernah pindah tab', (tester) async {
      await pumpHome(tester);

      await tester.tap(find.text('Analisis'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.photo_camera_rounded));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();

      // Tab yang aktif sebelum tombol tengah ditekan tetap yang tampil.
      expect(find.byType(DeteksiMakananPage), findsNothing);
      expect(find.text('Ringkasan Hari Ini'), findsNothing);
    });
  });

  group('Profile persistence', () {
    testWidgets('Beranda greets the name stored in SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({'user_name': 'Rara'});

      await pumpHome(tester);

      expect(find.text('Halo, Rara'), findsOneWidget);
    });

    testWidgets('Beranda greets without a name when nothing is stored', (tester) async {
      // Tidak ada lagi identitas bawaan: menyapa pengguna baru dengan nama
      // orang lain adalah kebohongan kecil yang tidak dibayar apa pun.
      await pumpHome(tester);

      expect(find.text('Halo'), findsOneWidget);
      expect(find.textContaining('Lathifa'), findsNothing);
    });
  });
}
