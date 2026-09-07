// Widget test untuk foto makanan yang bisa dibuka layar penuh.
//
// Yang dijaga di sini bukan tampilannya, melainkan dua batas yang mudah
// hilang saat FotoMakanan dipakai di tempat baru: foto yang tidak ada tidak
// boleh membuka layar hitam kosong, dan jempol yang duduk di dalam kartu yang
// bisa ditekan tidak boleh mencuri ketukan kartunya.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/ringkasan_sesi_page.dart';
import 'package:asawatch/riwayat_tab.dart';
import 'package:asawatch/widgets/foto_makanan.dart';
import 'package:asawatch/widgets/pratinjau_foto_page.dart';

import 'helpers.dart';

void main() {
  setUpAll(loadMontserrat);

  testWidgets('foto di Ringkasan Sesi membuka pratinjau, lalu bisa ditutup', (
    tester,
  ) async {
    await pumpHalaman(tester, RingkasanSesiPage(sesi: contohSesiSelesai()));
    await tester.pumpAndSettle();

    // Fotonya duduk di kartu nutrisi, jauh di bawah lipatan.
    await tester.scrollUntilVisible(find.byType(FotoMakanan).first, 200);
    await tester.tap(find.byType(FotoMakanan).first);
    await tester.pumpAndSettle();

    expect(find.byType(PratinjauFotoPage), findsOneWidget);
    // Foto digambar utuh, bukan dipangkas seperti di kartunya.
    expect(
      tester.widget<Image>(
        find.descendant(
          of: find.byType(PratinjauFotoPage),
          matching: find.byType(Image),
        ),
      ).fit,
      BoxFit.contain,
    );

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();
    expect(find.byType(PratinjauFotoPage), findsNothing);
  });

  testWidgets('foto yang filenya hilang tidak bisa dibuka', (tester) async {
    await pumpHalaman(
      tester,
      const Scaffold(
        body: Center(
          child: FotoMakanan(
            fotoPath: '/tidak/ada/foto.jpg',
            lebar: 150,
            tinggi: 150,
            bisaDibuka: true,
          ),
        ),
      ),
    );
    await tester.pump();

    // Penampung cadangan, bukan gambar — dan menekannya tidak ke mana-mana.
    expect(find.byIcon(Icons.restaurant_menu), findsOneWidget);
    await tester.tap(find.byType(FotoMakanan));
    await tester.pumpAndSettle();
    expect(find.byType(PratinjauFotoPage), findsNothing);
  });

  testWidgets('jempol di Riwayat tetap membuka sesinya, bukan fotonya', (
    tester,
  ) async {
    final c = buatControllerUji(riwayatAwal: [contohSesiSelesai()]);
    await pumpHalaman(tester, const Scaffold(body: RiwayatTab()), controller: c);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(FotoMakanan).first);
    await tester.pumpAndSettle();

    expect(find.byType(PratinjauFotoPage), findsNothing);
    expect(find.byType(RingkasanSesiPage), findsOneWidget);
  });
}
