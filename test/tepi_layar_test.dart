// Bilah navigasi sistem menumpang di atas aplikasi — sejak Android 15 itu
// dipaksakan, tidak bisa dimatikan. Yang diuji di sini bukan "ada SafeArea",
// melainkan akibatnya: tidak ada satu pun bagian yang bisa disentuh berada di
// bawah bilah itu, dan latarnya tetap membentang sampai tepi layar.
//
// Kegagalannya tidak terlihat di emulator tanpa bilah navigasi, dan tidak
// terlihat di test lain karena viewport bawaan `flutter_test` tidak punya
// padding sama sekali.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/main.dart';
import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/pemindaian_perangkat_page.dart';
import 'package:asawatch/services/izin_ble.dart';

import 'helpers.dart';

/// Tinggi bilah navigasi tiga tombol Android, dalam piksel logis.
const double tinggiBilahSistem = 48;

/// Tinggi layar uji, mengikuti `pakaiLayarPonsel`.
const double tinggiLayar = 915;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadMontserrat);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  /// Memasang bilah navigasi sistem pada viewport test.
  void pakaiBilahSistem(WidgetTester tester) {
    tester.view.padding = const FakeViewPadding(bottom: tinggiBilahSistem);
    tester.view.viewPadding = const FakeViewPadding(bottom: tinggiBilahSistem);
    addTearDown(tester.view.reset);
  }

  group('Bilah navigasi sistem', () {
    testWidgets('label tab tidak tertimbun bilah navigasi ponsel', (
      tester,
    ) async {
      pakaiBilahSistem(tester);
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const MyHomePage(title: 'AsaWatch'),
        controller: c,
      );
      await tester.pumpAndSettle();

      const batas = tinggiLayar - tinggiBilahSistem;
      for (final label in ['Beranda', 'Riwayat', 'Analisis', 'Profil']) {
        expect(
          tester.getBottomLeft(find.text(label)).dy,
          lessThanOrEqualTo(batas),
          reason: '"$label" masuk ke wilayah bilah navigasi ponsel',
        );
      }
    });

    testWidgets('putih bilah navigasi tetap sampai tepi bawah layar', (
      tester,
    ) async {
      pakaiBilahSistem(tester);
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        const MyHomePage(title: 'AsaWatch'),
        controller: c,
      );
      await tester.pumpAndSettle();

      // Isinya naik, latarnya tidak: menaikkan keduanya menyisakan pita
      // berwarna latar halaman di bawah bilah aplikasi, yang justru lebih
      // terlihat salah daripada masalah aslinya.
      final kotak = tester.getRect(
        find
            .ancestor(
              of: find.text('Beranda'),
              matching: find.byType(Container),
            )
            .last,
      );
      expect(kotak.bottom, tinggiLayar);
      expect(kotak.height, 80 + tinggiBilahSistem);
    });

    testWidgets('tombol halaman yang didorong ikut naik di atas bilah', (
      tester,
    ) async {
      pakaiBilahSistem(tester);
      final c = buatControllerUji(status: contohPerangkatBelumDipasangkan);
      await pumpHalaman(
        tester,
        const PemindaianPerangkatPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );
      await tester.pumpAndSettle();

      // Halaman yang didorong tidak punya bilah navigasi aplikasi, jadi
      // isinya sendiri yang harus berhenti sebelum bilah sistem.
      final tombol = find.text('Pindai Ulang');
      expect(tombol, findsOneWidget);
      expect(
        tester.getBottomLeft(tombol).dy,
        lessThanOrEqualTo(tinggiLayar - tinggiBilahSistem),
      );
    });
  });
}
