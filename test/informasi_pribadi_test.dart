// Jenis input di Informasi Pribadi.
//
// Sebelumnya seluruh field adalah teks bebas: tanggal lahir bisa diisi apa pun,
// tinggi dan berat menyimpan satuannya ikut diketik, dan tidak ada satu pun
// validasi bentuk. Test ini mengunci perilaku barunya, termasuk pembacaan nilai
// lama yang formatnya masih gaya lama.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/informasi_pribadi_page.dart';
import 'package:asawatch/repositories/profil_repository.dart';

import 'helpers.dart';

/// Memompa halaman sebagai rute yang **didorong**, bukan sebagai `home`.
///
/// Halaman ini memanggil `Navigator.pop(true)` setelah menyimpan; kalau ia
/// menjadi rute pertama, tidak ada yang bisa dituju saat pop.
Future<void> pumpHalamanDidorong(WidgetTester tester) async {
  pakaiLayarPonsel(tester);

  await tester.pumpWidget(
    MaterialApp(
      theme: ThemeData(fontFamily: 'Montserrat', useMaterial3: true),
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<bool>(
                  builder: (_) => const InformasiPribadiPage(),
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
}

Future<void> tapSimpan(WidgetTester tester) async {
  await tester.tap(find.text('Simpan'));
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadMontserrat);

  group('Memuat nilai tersimpan', () {
    testWidgets('satuan pada nilai lama dilepas dari field angka', (
      tester,
    ) async {
      // Nilai gaya lama: satuannya ikut tersimpan sebagai teks.
      SharedPreferences.setMockInitialValues({
        'user_height': '160 cm',
        'user_weight': '52 kg',
      });

      await pumpHalamanDidorong(tester);

      expect(find.widgetWithText(TextFormField, '160'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, '52'), findsOneWidget);
      // Satuannya kini hiasan field, jadi tetap terlihat — tetapi bukan lagi
      // bagian dari apa yang diketik dan disimpan.
      expect(find.text('cm'), findsOneWidget);
      expect(find.text('kg'), findsOneWidget);
    });

    testWidgets('tanggal ISO ditampilkan dalam bahasa Indonesia', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({'user_dob': '2004-05-21'});

      await pumpHalamanDidorong(tester);

      expect(find.text('21 Mei 2004'), findsOneWidget);
    });

    testWidgets('tanggal gaya lama yang tidak bisa diurai jadi belum dipilih', (
      tester,
    ) async {
      // "21 Mei 2004" tidak bisa diurai kembali menjadi tanggal — justru itu
      // alasan formatnya diganti. Pengguna memilih ulang sekali.
      SharedPreferences.setMockInitialValues({'user_dob': '21 Mei 2004'});

      await pumpHalamanDidorong(tester);

      expect(find.text('Belum dipilih'), findsWidgets);
    });
  });

  group('Validasi bentuk', () {
    testWidgets('profil kosong boleh disimpan', (tester) async {
      // Sebelum A4 setiap field wajib diisi, dan itu tidak terasa karena nilai
      // demo mengisi semuanya. Tanpa nilai demo, aturan itu menjadi jebakan.
      SharedPreferences.setMockInitialValues({});

      await pumpHalamanDidorong(tester);
      await tapSimpan(tester);

      expect(find.textContaining('tidak boleh kosong'), findsNothing);
      expect(find.textContaining('harus berupa angka'), findsNothing);
    });

    testWidgets('tinggi di luar rentang wajar ditolak', (tester) async {
      SharedPreferences.setMockInitialValues({});

      await pumpHalamanDidorong(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, '').at(1), // Tinggi Badan
        '999',
      );
      await tapSimpan(tester);

      expect(find.textContaining('Tinggi wajar antara'), findsOneWidget);
    });

    testWidgets('email tanpa bentuk yang benar ditolak', (tester) async {
      SharedPreferences.setMockInitialValues({'user_email': 'rara'});

      await pumpHalamanDidorong(tester);
      await tapSimpan(tester);

      expect(find.text('Format email belum benar'), findsOneWidget);
    });

    testWidgets('email yang benar lolos', (tester) async {
      SharedPreferences.setMockInitialValues({'user_email': 'rara@contoh.id'});

      await pumpHalamanDidorong(tester);
      await tapSimpan(tester);

      expect(find.textContaining('belum benar'), findsNothing);
    });
  });

  group('Menyimpan', () {
    testWidgets('tinggi tersimpan tanpa satuan', (tester) async {
      SharedPreferences.setMockInitialValues({'user_height': '160 cm'});

      await pumpHalamanDidorong(tester);
      await tapSimpan(tester);

      final profil = await const ProfilRepository().muat();
      expect(profil.tinggi, '160');
    });

    testWidgets('tanggal lahir tersimpan sebagai ISO, bukan teks', (
      tester,
    ) async {
      // ISO adalah bentuk yang bisa diurai kembali; usia dihitung darinya.
      SharedPreferences.setMockInitialValues({'user_dob': '2004-05-21'});

      await pumpHalamanDidorong(tester);
      await tapSimpan(tester);

      final profil = await const ProfilRepository().muat();
      expect(profil.tanggalLahir, '2004-05-21');
    });

    testWidgets('memilih tanggal lewat pemilih, bukan mengetik', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});

      await pumpHalamanDidorong(tester);
      await tester.tap(find.text('Belum dipilih').first);
      await tester.pumpAndSettle();

      expect(find.byType(DatePickerDialog), findsOneWidget);

      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsNothing);
    });
  });
}
