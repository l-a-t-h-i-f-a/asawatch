// Indikator baterai jam: empat kotak tiruan layar jam, tanpa angka.
//
// Yang dipatok di sini adalah janji-janjinya, bukan gambarnya: tidak ada angka
// yang mengaku lebih teliti daripada kalibrasinya, dan merah hanya datang dari
// jam.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/widgets/indikator_baterai.dart';

import 'helpers.dart';

Future<void> _pompa(WidgetTester tester, Widget w) => tester.pumpWidget(
  MaterialApp(
    theme: ThemeData(fontFamily: 'Montserrat'),
    home: Scaffold(body: Center(child: w)),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMontserrat);

  test('empat kotak dengan ambang dan histeresis yang sama dengan jam', () {
    // Tampilan pertama: titik tengah kedua ambang (22/47/72/97).
    expect(IndikatorBaterai.hitungKotak(21), 0);
    expect(IndikatorBaterai.hitungKotak(22), 1);
    expect(IndikatorBaterai.hitungKotak(96), 3);
    expect(IndikatorBaterai.hitungKotak(97), 4);

    // Sesudahnya: naik di 25/50/75/100, turun di bawah 20/45/70/95.
    expect(IndikatorBaterai.hitungKotak(99, 3), 3);
    expect(IndikatorBaterai.hitungKotak(100, 3), 4);
    expect(IndikatorBaterai.hitungKotak(95, 4), 4);
    expect(IndikatorBaterai.hitungKotak(94, 4), 3);
    expect(IndikatorBaterai.hitungKotak(72, 2), 2);
    expect(IndikatorBaterai.hitungKotak(72, 3), 3);
    expect(IndikatorBaterai.hitungKotak(19, 1), 0);
  });

  testWidgets('kotak tidak berkedip saat persen bergoyang di ambang', (
    tester,
  ) async {
    int menyala() =>
        tester.widgetList<Container>(find.byType(Container)).where((c) {
          final d = c.decoration;
          return c.constraints?.maxWidth == 6 &&
              d is BoxDecoration &&
              d.color == IndikatorBaterai.warnaBiasa;
        }).length;

    await _pompa(tester, const IndikatorBaterai(persen: 76));
    expect(menyala(), 3);
    // 74 masih di atas ambang turun 70: tetap tiga, seperti di jam.
    await _pompa(tester, const IndikatorBaterai(persen: 74));
    expect(menyala(), 3);
    await _pompa(tester, const IndikatorBaterai(persen: 69));
    expect(menyala(), 2);
    await _pompa(tester, const IndikatorBaterai(persen: 74));
    expect(menyala(), 2);
  });

  testWidgets('petir hanya selama dicas dan di bawah 100%, seperti di jam', (
    tester,
  ) async {
    await _pompa(tester, const IndikatorBaterai(persen: 60, dicas: true));
    expect(find.byIcon(Icons.bolt_rounded), findsOneWidget);

    await _pompa(tester, const IndikatorBaterai(persen: 100, dicas: true));
    expect(find.byIcon(Icons.bolt_rounded), findsNothing);

    await _pompa(tester, const IndikatorBaterai(persen: 60));
    expect(find.byIcon(Icons.bolt_rounded), findsNothing);
  });

  testWidgets('tidak menulis angka persen sama sekali', (tester) async {
    await _pompa(tester, const IndikatorBaterai(persen: 73));
    expect(find.byType(Text), findsNothing);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('merah saat kotaknya habis atau jam melapor kritis', (
    tester,
  ) async {
    const merah = IndikatorBaterai.warnaHabis;
    // Warna badan baterai: bingkai kotak-kotaknya.
    Color warnaBadan() => tester
        .widgetList<Container>(find.byType(Container))
        .map((c) => c.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((d) => d.border != null)
        .border!
        .top
        .color;

    await _pompa(tester, const IndikatorBaterai(persen: 40));
    expect(warnaBadan(), isNot(merah));

    // Di bawah kotak pertama badan jam kosong dan merah — aplikasi ikut.
    await _pompa(tester, const IndikatorBaterai(persen: 15));
    expect(warnaBadan(), merah);

    await _pompa(tester, const IndikatorBaterai(persen: 40, kritis: true));
    expect(warnaBadan(), merah);

    // Dicas menang: hijau, seperti `batt_gambar`.
    await _pompa(tester, const IndikatorBaterai(persen: 15, dicas: true));
    expect(warnaBadan(), IndikatorBaterai.warnaDicas);
  });

  test('status cas ikut hilang saat jam terputus, seperti baterai', () {
    const tersambung = StatusPerangkat(
      tersambung: true,
      baterai: 60,
      sedangDicas: true,
    );
    expect(tersambung.sedangDicas, isTrue);
    expect(tersambung.salin(tersambung: false).sedangDicas, isFalse);
  });
}
