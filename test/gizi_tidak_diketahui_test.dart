// "Tidak diketahui" dibedakan dari "nol".
//
// Sumber angkanya adalah tabel TKPI lewat layanan deteksi, dan tabel itu tidak
// punya kolom gula sama sekali, kosong pada serat untuk ratusan bahan, dan tidak
// mengenal setiap masakan yang difoto orang. Sebelum perubahan ini semua
// ketiadaan itu menjadi 0 — angka yang tampak pasti, pada aplikasi yang justru
// mengukur gula darah.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/services/sesi_server_service.dart';
import 'package:asawatch/widgets/ringkasan_nutrisi.dart';

import 'helpers.dart';

/// Balasan sungguhan dari backend saat makanannya tidak ada di TKPI.
Map<String, dynamic> _jsonSesi({
  Object? kalori = 459,
  List<String> zatTidakLengkap = const ['gula_total'],
}) => {
  'id': 'x1',
  'waktu_foto': '2026-08-23T08:00:00.000000Z',
  'status': 'selesai',
  'sampel': [
    {'index': 0, 'detik_relatif_t0': 0, 'status': 'terisi', 'gula_darah': 96},
  ],
  'hasil': {
    'indeks_glikemik_perkiraan': null,
    'keyakinan': null,
    'dikoreksi_user': false,
    'zat_tidak_lengkap': zatTidakLengkap,
    'total': {
      'kalori': kalori,
      'karbohidrat': 24,
      'protein': 33.9,
      'lemak': 25.2,
      'gula_total': null,
      'serat': 4.2,
    },
    'makanan': [
      {
        'urutan': 0,
        'nama': 'rujak cingur',
        'porsi': '1 piring sedang',
        'estimasi_gram': 300,
        'nutrisi': {
          'kalori': kalori,
          'karbohidrat': 24,
          'protein': 33.9,
          'lemak': 25.2,
          'gula_total': null,
          'serat': 4.2,
        },
      },
      {
        'urutan': 1,
        'nama': 'telur rebus',
        'porsi': '1 butir',
        'estimasi_gram': 55,
        'nutrisi': {
          'kalori': null,
          'karbohidrat': null,
          'protein': null,
          'lemak': null,
          'gula_total': null,
          'serat': null,
        },
      },
    ],
  },
};

void main() {
  setUpAll(loadMontserrat);

  group('Membaca balasan server', () {
    test('null tetap null, bukan menjadi nol atau "sedang"', () {
      final hasil = sesiDariJson(_jsonSesi())!.hasil!;

      // Sebelumnya: "sedang" dan 0.0 — taksiran yang tidak pernah dibuat
      // siapa pun, tampil sebagai fakta.
      expect(hasil.indeksGlikemikPerkiraan, isNull);
      expect(hasil.keyakinan, isNull);
      expect(hasil.total.gulaTotal, isNull);
      expect(hasil.total.kalori, 459);
    });

    test('makanan tanpa data tetap tampil, tanpa angka', () {
      final hasil = sesiDariJson(_jsonSesi())!.hasil!;
      final telur = hasil.makanan[1];

      // Pengguna memang memakannya; menyembunyikannya membuat kartu tidak cocok
      // dengan piring yang dilihatnya.
      expect(telur.nama, 'telur rebus');
      expect(telur.estimasiGram, 55);
      expect(telur.nutrisi.zatTidakDiketahui, ZatGizi.values.toSet());
    });

    test('zat_tidak_lengkap terbaca sebagai penanda total parsial', () {
      final hasil = sesiDariJson(
        _jsonSesi(zatTidakLengkap: ['karbohidrat', 'gula_total']),
      )!.hasil!;

      expect(hasil.zatTidakLengkap, {ZatGizi.karbohidrat, ZatGizi.gulaTotal});
      expect(hasil.pasti(ZatGizi.karbohidrat), isFalse);
      expect(hasil.pasti(ZatGizi.kalori), isTrue);
    });
  });

  group('Aritmetika yang jujur', () {
    test('tidak diketahui + tidak diketahui tetap tidak diketahui', () {
      expect((Nutrisi.tidakDiketahui + Nutrisi.tidakDiketahui).kalori, isNull);
    });

    test('tidak diketahui + angka menjadi angka itu', () {
      const seratus = Nutrisi(
        kalori: 100,
        karbohidrat: 10,
        protein: 5,
        lemak: 2,
        gulaTotal: 1,
        serat: 3,
      );
      expect((Nutrisi.tidakDiketahui + seratus).kalori, 100);
    });

    test('menskalakan yang tidak diketahui tidak menghasilkan nol', () {
      // Setengah dari entah berapa tetap entah berapa — kalau jadi 0, koreksi
      // porsi akan terasa seperti menghapus makanannya.
      expect((Nutrisi.tidakDiketahui * 0.5).kalori, isNull);
    });
  });

  group('Yang dilihat pengguna', () {
    Future<void> pump(WidgetTester tester, HasilDeteksi hasil) async {
      pakaiLayarPonsel(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(fontFamily: 'Montserrat', useMaterial3: true),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: RingkasanNutrisi(hasil: hasil),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('gula yang tidak diketahui tampil "—", bukan "0"', (
      tester,
    ) async {
      await pump(tester, sesiDariJson(_jsonSesi())!.hasil!);

      // Angkanya digambar lewat RichText (angka + satuan dalam satu baris),
      // jadi finder-nya harus ikut menelusuri span.
      expect(find.text('—', findRichText: true), findsWidgets);
      expect(find.textContaining('Sebagian makanan belum ada'), findsOneWidget);
    });

    testWidgets('total parsial ditandai ≥, bukan disajikan sebagai pasti', (
      tester,
    ) async {
      await pump(
        tester,
        sesiDariJson(_jsonSesi(zatTidakLengkap: ['kalori']))!.hasil!,
      );

      // findRichText mencocokkan seluruh isi RichText-nya, termasuk satuan.
      expect(find.text('≥ 459 kcal', findRichText: true), findsOneWidget);
    });

    testWidgets('parsial yang angkanya nol berarti belum ada angka sama sekali', (
      tester,
    ) async {
      // Ini keadaan yang dilihat Titan di lapangan: "ayam kecap" terdeteksi
      // benar, tetapi tidak ada padanannya di TKPI, jadi seluruh totalnya 0 dan
      // keenam zat ditandai tidak lengkap. "0 kcal" di sini bukan "tanpa
      // kalori", melainkan "belum ada satu pun angka".
      await pump(
        tester,
        sesiDariJson(
          _jsonSesi(
            kalori: 0,
            zatTidakLengkap: const [
              'kalori',
              'karbohidrat',
              'protein',
              'lemak',
              'gula_total',
              'serat',
            ],
          ),
        )!.hasil!,
      );

      expect(find.text('≥ 0 kcal', findRichText: true), findsNothing);
      expect(find.text('0 kcal', findRichText: true), findsNothing);
      expect(find.textContaining('belum bisa dihitung'), findsOneWidget);
    });
  });
}
