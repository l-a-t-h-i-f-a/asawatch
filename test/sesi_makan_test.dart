// Test untuk nilai turunan model sesi makan (docs/rancangan-ui-sesi-makan.md
// §12.3). Semuanya dihitung, tidak disimpan, jadi di sinilah aturan "puncak,
// delta, pemulihan, verdict" dikunci.

import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';

SesiMakan sesiDengan(List<Sampel> sampel, {StatusSesi? status}) {
  final t0 = DateTime(2026, 8, 8, 12, 0);
  return SesiMakan(
    id: 'uji',
    fotoPath: contohFotoPath,
    waktuFoto: t0.subtract(const Duration(minutes: 20)),
    t0: t0,
    status: status ?? StatusSesi.selesai,
    sampel: sampel,
  );
}

Sampel terisi(int index, int detik, int gula) => Sampel(
  index: index,
  detikRelatifT0: detik,
  status: StatusSampel.terisi,
  gulaDarah: gula,
);

void main() {
  group('Nilai turunan sesi', () {
    test('puncak mengabaikan baseline dan delta dihitung darinya', () {
      final sesi = contohSesiSelesai();

      expect(sesi.gulaDarahBaseline, 92);
      expect(sesi.puncakGulaDarah, 140);
      expect(sesi.sampelPuncak!.index, 2);
      expect(sesi.deltaPuncak, 48);
    });

    test('baseline lebih tinggi dari sampel lain tidak jadi puncak', () {
      final sesi = sesiDengan([
        terisi(0, -1500, 130),
        terisi(1, 0, 120),
        terisi(2, 3600, 118),
        terisi(3, 7200, 115),
      ]);

      expect(sesi.puncakGulaDarah, 120);
      expect(sesi.deltaPuncak, -10);
    });

    test('pemulihan diukur pada titik pertama setelah puncak yang kembali', () {
      expect(contohSesiSelesai().waktuPemulihan, const Duration(hours: 2));
    });

    test('belum kembali ke baseline menghasilkan pemulihan null', () {
      final sesi = sesiDengan([
        terisi(0, -1500, 92),
        terisi(1, 0, 98),
        terisi(2, 3600, 160),
        terisi(3, 7200, 145),
      ]);

      expect(sesi.waktuPemulihan, isNull);
      expect(sesi.verdict, contains('belum kembali ke baseline'));
    });

    test('baseline yang belum terisi membuat delta null, bukan 0', () {
      final sesi = sesiDengan([
        const Sampel.menunggu(index: 0, detikRelatifT0: -1500),
        terisi(1, 0, 98),
        terisi(2, 3600, 140),
        terisi(3, 7200, 99),
      ]);

      expect(sesi.baseline, isNull);
      expect(sesi.gulaDarahBaseline, isNull);
      expect(sesi.deltaPuncak, isNull);
      expect(sesi.waktuPemulihan, isNull);
      expect(sesi.verdict, contains('belum cukup'));
    });

    test('sampel berikutnya adalah titik menunggu paling awal', () {
      final sesi = contohSesiBerjalan();

      expect(sesi.sampelBerikutnya!.index, 2);
      expect(
        sesi.jadwalBerikutnya,
        sesi.t0!.add(const Duration(seconds: 3600)),
      );
      expect(sesi.sampelTerisi.length, 2);
    });

    test('sesi selesai tanpa titik menunggu tidak punya sampel berikutnya', () {
      expect(contohSesiSelesai().sampelBerikutnya, isNull);
    });

    test('sampel terlewat ditandai di verdict', () {
      final sesi = contohSesiTidakLengkap();

      expect(sesi.adaSampelTerlewat, isTrue);
      expect(sesi.verdict, contains('ada sampel terlewat'));
      expect(sesi.verdict, contains('+63 mg/dL'));
    });

    test('verdict sesi berjalan tidak menyimpulkan apa pun', () {
      expect(contohSesiBerjalan().verdict, contains('masih berjalan'));
      expect(StatusSesi.berjalan.sedangAktif, isTrue);
      expect(StatusSesi.selesai.sedangAktif, isFalse);
    });

    test('waktu ukur diturunkan dari t0, tidak disimpan', () {
      final sesi = contohSesiSelesai();
      final t0 = sesi.t0!;

      expect(sesi.sampel[0].waktuUkur(t0), t0.subtract(const Duration(seconds: 1500)));
      expect(sesi.sampel[3].waktuUkur(t0), t0.add(const Duration(hours: 2)));
    });

    test('tekanan darah null bila salah satu sisinya tidak terukur', () {
      expect(contohSesiSelesai().sampel[0].tekananDarah, '116/76');
      expect(
        const Sampel(
          index: 2,
          detikRelatifT0: 3600,
          status: StatusSampel.terisi,
          sistolik: 120,
        ).tekananDarah,
        isNull,
      );
    });
  });

  group('Nutrisi', () {
    test('total contoh cocok dengan angka yang sudah tampil hari ini', () {
      final total = contohHasilDeteksi().total;

      expect(total.kalori, 430);
      expect(total.karbohidrat, 45);
      expect(total.protein, 28);
      expect(total.lemak, 15);
      expect(total.gulaTotal, greaterThan(0));
      expect(total.serat, greaterThan(0));
    });

    test('penjumlahan nutrisi menjumlah seluruh enam field', () {
      const a = Nutrisi(
        kalori: 100,
        karbohidrat: 10,
        protein: 5,
        lemak: 2,
        gulaTotal: 1,
        serat: 3,
      );
      final hasil = a + a;

      expect(hasil.kalori, 200);
      expect(hasil.karbohidrat, 20);
      expect(hasil.protein, 10);
      expect(hasil.lemak, 4);
      expect(hasil.gulaTotal, 2);
      expect(hasil.serat, 6);
    });
  });
}
