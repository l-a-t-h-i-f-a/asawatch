// Widget tests for the AsaWatch shell: welcome -> login -> home tabs.
//
// The app has no backend, so these cover the parts that actually hold logic:
// route wiring, form validation gating navigation, the bottom-nav index-2
// carve-out, and the SharedPreferences-backed profile name.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/main.dart';
import 'package:asawatch/welcome_page.dart';
import 'package:asawatch/login_page.dart';
import 'package:asawatch/deteksi_makanan_page.dart';

/// Pumps [MyApp] on a phone-sized surface. The layouts are designed for a
/// narrow viewport and overflow on the 800x600 test default.
Future<void> pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const MyApp());
  await tester.pumpAndSettle();
}

/// Walks welcome -> login and fills in valid credentials -> home.
Future<void> pumpHome(WidgetTester tester) async {
  await pumpApp(tester);

  await tester.tap(find.text('Mulai Sekarang'));
  await tester.pumpAndSettle();

  await tester.enterText(find.byType(TextFormField).at(0), 'lathifa21@email.com');
  await tester.enterText(find.byType(TextFormField).at(1), 'rahasia123');

  await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
  await tester.pumpAndSettle();
}

/// Registers the bundled Montserrat faces with the test binding.
///
/// Without this the test harness substitutes its own fixed-width fallback font,
/// whose glyphs are far wider than Montserrat's, and the phone-width layouts
/// report spurious RenderFlex overflows.
Future<void> loadMontserrat() async {
  const faces = [
    'assets/fonts/Montserrat-Regular.ttf',
    'assets/fonts/Montserrat-Medium.ttf',
    'assets/fonts/Montserrat-SemiBold.ttf',
    'assets/fonts/Montserrat-Bold.ttf',
  ];

  final loader = FontLoader('Montserrat');
  for (final path in faces) {
    final bytes = await File(path).readAsBytes();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
  }
  await loader.load();
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

    testWidgets('"Mulai Sekarang" opens the login page', (tester) async {
      await pumpApp(tester);

      await tester.tap(find.text('Mulai Sekarang'));
      await tester.pumpAndSettle();

      expect(find.byType(LoginPage), findsOneWidget);
    });
  });

  group('LoginPage', () {
    testWidgets('empty fields fail validation and block navigation', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('Mulai Sekarang'));
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

      expect(find.text('Riwayat Kesehatan'), findsNothing);

      await tester.tap(find.text('Riwayat'));
      await tester.pumpAndSettle();

      expect(find.text('Riwayat Kesehatan'), findsOneWidget);
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
  });

  group('Profile persistence', () {
    testWidgets('Beranda greets the name stored in SharedPreferences', (tester) async {
      SharedPreferences.setMockInitialValues({'user_name': 'Rara'});

      await pumpHome(tester);

      expect(find.text('Halo, Rara'), findsOneWidget);
    });

    testWidgets('Beranda falls back to the demo name when nothing is stored', (tester) async {
      await pumpHome(tester);

      expect(find.text('Halo, Lathifa'), findsOneWidget);
    });
  });
}
