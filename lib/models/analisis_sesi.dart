import 'dart:math';

import 'sesi_makan.dart';

/// Di bawah keyakinan ini, estimasi porsi dianggap terlalu goyah untuk ikut
/// membentuk korelasi — kecuali user sudah mengoreksinya sendiri (§4.3).
const double ambangKeyakinan = 0.6;

/// Satu sesi sebagai satu titik pada sebaran karbohidrat vs kenaikan gula.
class TitikSebaran {
  const TitikSebaran({
    required this.sesi,
    required this.karbohidrat,
    required this.delta,
    required this.andal,
  });

  final SesiMakan sesi;
  final double karbohidrat; // gram
  final int delta; // kenaikan puncak dari baseline, mg/dL

  /// Estimasi porsinya cukup dipercaya untuk ikut menghitung tren.
  final bool andal;
}

/// Garis tren linear sederhana (kuadrat terkecil) beserta kekuatannya.
class GarisTren {
  const GarisTren({
    required this.kemiringan,
    required this.potongan,
    required this.korelasi,
  });

  final double kemiringan; // mg/dL per gram karbohidrat
  final double potongan;
  final double korelasi; // Pearson r, -1..1

  double nilaiPada(double karbohidrat) => potongan + kemiringan * karbohidrat;

  /// Seberapa layak garis ini disebut hubungan, bukan kebetulan.
  bool get meyakinkan => korelasi.abs() >= 0.5;
}

/// Makanan yang paling sering muncul di sesi berkenaikan tinggi.
class PemicuMakanan {
  const PemicuMakanan({
    required this.nama,
    required this.jumlahSesi,
    required this.rataDelta,
    required this.rataKarbohidrat,
  });

  final String nama;
  final int jumlahSesi;
  final double rataDelta;
  final double rataKarbohidrat;
}

/// Perhitungan lintas sesi untuk tab Analisis dan halaman detail metrik.
///
/// Semuanya dihitung dari daftar sesi yang diberikan — tidak ada angka
/// hardcoded dan tidak ada state tersimpan.
class AnalisisSesi {
  AnalisisSesi(List<SesiMakan> sesi)
    : sesi = [
        // Sesi yang masih berjalan belum punya kesimpulan apa pun.
        //
        // Sesi berwaktu tidak pasti juga tidak ikut (docs/protokol-jam.md §4.3).
        // Bentuk kurvanya benar, tetapi seluruh isi kelas ini adalah pertanyaan
        // "membaik atau tidak" — dan itu pertanyaan tentang urutan waktu.
        // Sesi yang posisinya di kalender tidak diketahui akan menyisip di
        // tempat yang salah dan mengubah kesimpulannya.
        for (final s in sesi)
          if (!s.status.sedangAktif && !s.waktuTidakPasti) s,
      ];

  final List<SesiMakan> sesi;

  bool get kosong => sesi.isEmpty;

  /// Sesi urut lama → baru; dipakai untuk semua pertanyaan "membaik atau
  /// tidak".
  List<SesiMakan> get urutWaktu {
    final daftar = [...sesi];
    daftar.sort((a, b) {
      final wa = a.t0 ?? a.waktuFoto;
      final wb = b.t0 ?? b.waktuFoto;
      return wa.compareTo(wb);
    });
    return daftar;
  }

  List<TitikSebaran> get titikSebaran {
    final titik = <TitikSebaran>[];
    for (final s in sesi) {
      final hasil = s.hasil;
      final delta = s.deltaPuncak;
      if (hasil == null || delta == null) continue;
      titik.add(
        TitikSebaran(
          sesi: s,
          karbohidrat: hasil.total.karbohidrat,
          delta: delta,
          andal: hasil.dikoreksiUser || hasil.keyakinan >= ambangKeyakinan,
        ),
      );
    }
    return titik;
  }

  List<TitikSebaran> get titikAndal =>
      titikSebaran.where((t) => t.andal).toList();

  int get jumlahDikecualikan => titikSebaran.length - titikAndal.length;

  /// Garis tren dari titik yang andal saja. null bila datanya belum cukup.
  GarisTren? get tren {
    final titik = titikAndal;
    if (titik.length < 3) return null;

    final n = titik.length;
    final x = titik.map((t) => t.karbohidrat).toList();
    final y = titik.map((t) => t.delta.toDouble()).toList();
    final rataX = x.reduce((a, b) => a + b) / n;
    final rataY = y.reduce((a, b) => a + b) / n;

    var sxy = 0.0, sxx = 0.0, syy = 0.0;
    for (var i = 0; i < n; i++) {
      final dx = x[i] - rataX, dy = y[i] - rataY;
      sxy += dx * dy;
      sxx += dx * dx;
      syy += dy * dy;
    }
    if (sxx == 0 || syy == 0) return null;

    final kemiringan = sxy / sxx;
    return GarisTren(
      kemiringan: kemiringan,
      potongan: rataY - kemiringan * rataX,
      korelasi: sxy / sqrt(sxx * syy),
    );
  }

  /// Rata-rata puncak gula darah seluruh sesi — dipakai halaman detail gula
  /// darah (§4.4).
  double? get rataPuncak {
    final nilai = [
      for (final s in sesi)
        if (s.puncakGulaDarah != null) s.puncakGulaDarah!,
    ];
    if (nilai.isEmpty) return null;
    return nilai.reduce((a, b) => a + b) / nilai.length;
  }

  double? get rataDelta {
    final nilai = [
      for (final s in sesi)
        if (s.deltaPuncak != null) s.deltaPuncak!,
    ];
    if (nilai.isEmpty) return null;
    return nilai.reduce((a, b) => a + b) / nilai.length;
  }

  /// Makanan diurutkan dari rata-rata kenaikan tertinggi.
  ///
  /// Sesi berkeyakinan rendah tidak ikut, dengan alasan yang sama seperti pada
  /// garis tren: porsinya belum tentu benar.
  List<PemicuMakanan> get pemicuTeratas {
    final kumpulan = <String, List<TitikSebaran>>{};
    for (final t in titikAndal) {
      for (final m in t.sesi.hasil!.makanan) {
        kumpulan.putIfAbsent(m.nama, () => []).add(t);
      }
    }

    final hasil = [
      for (final entri in kumpulan.entries)
        PemicuMakanan(
          nama: entri.key,
          jumlahSesi: entri.value.length,
          rataDelta:
              entri.value.map((t) => t.delta).reduce((a, b) => a + b) /
              entri.value.length,
          rataKarbohidrat:
              entri.value.map((t) => t.karbohidrat).reduce((a, b) => a + b) /
              entri.value.length,
        ),
    ];
    hasil.sort((a, b) => b.rataDelta.compareTo(a.rataDelta));
    return hasil;
  }

  /// Berapa sesi yang gula darahnya kembali ke sekitar baseline dalam 2 jam.
  ({int pulih, int total}) get rekapPemulihan {
    var pulih = 0, total = 0;
    for (final s in sesi) {
      if (s.deltaPuncak == null) continue;
      total++;
      if (s.waktuPemulihan != null) pulih++;
    }
    return (pulih: pulih, total: total);
  }

  /// Apakah pemulihan membaik dari waktu ke waktu (§4.3).
  ///
  /// Dengan hanya 4 titik per sesi, "waktu pemulihan" cuma bisa bernilai 1
  /// jam, 2 jam, atau belum kembali — jadi yang dibandingkan adalah proporsi
  /// sesi yang kembali ke baseline, paruh terbaru melawan paruh sebelumnya.
  /// null berarti datanya belum cukup untuk dibandingkan.
  double? get selisihProporsiPemulihan {
    final layak = urutWaktu.where((s) => s.deltaPuncak != null).toList();
    if (layak.length < 4) return null;

    final tengah = layak.length ~/ 2;
    final lama = layak.sublist(0, tengah);
    final baru = layak.sublist(tengah);

    double proporsi(List<SesiMakan> daftar) =>
        daftar.where((s) => s.waktuPemulihan != null).length / daftar.length;

    return proporsi(baru) - proporsi(lama);
  }
}
