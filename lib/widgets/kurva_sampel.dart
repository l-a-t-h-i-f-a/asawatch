import 'package:flutter/material.dart';

import '../models/sesi_makan.dart';

/// Font untuk teks yang digambar `CustomPainter`.
///
/// **Wajib disebut di setiap `TextStyle` milik painter.** `TextPainter` tidak
/// mewarisi apa pun dari pohon widget, jadi gaya tanpa `fontFamily` diam-diam
/// memakai font bawaan platform (Roboto di Android) — sementara seluruh sisa
/// aplikasi memakai Montserrat lewat `ThemeData.fontFamily`. Akibatnya setiap
/// label di dalam grafik memakai huruf yang berbeda dari label tepat di
/// sebelahnya, dan itu tidak terlihat di code review maupun di golden test
/// (keduanya jatuh ke font cadangan yang sama).
const String fontPainter = 'Montserrat';

/// Satu garis pada grafik: metrik mana yang diambil dari tiap [Sampel].
///
/// Dipakai untuk menyatukan seluruh grafik data dalam satu painter, sehingga
/// tidak ada lagi path bezier hardcoded di aplikasi (§7).
class SeriMetrik {
  const SeriMetrik({
    required this.label,
    required this.warna,
    required this.ambil,
    this.satuan = '',
    this.isiGradien = false,
    this.rentangMinimum = 20,
  });

  final String label;
  final Color warna;
  final int? Function(Sampel) ambil;
  final String satuan;

  /// Lebar sumbu y terkecil yang masih masuk akal untuk metrik ini.
  ///
  /// Sumbu diskalakan dari datanya, jadi tanpa lantai ini sesi yang angkanya
  /// nyaris rata akan digambar sebagai gelombang dramatis dari selisih 2 mg/dL.
  /// Tetapi lantai yang sama untuk semua metrik salah ke arah sebaliknya: SpO2
  /// sehat bergerak di 95–100, dan memaksakan lebar 20 ke sana meratakan
  /// satu-satunya hal yang ingin dilihat — penurunannya. Karena itu angkanya
  /// milik metriknya, bukan milik painter.
  final int rentangMinimum;

  /// Isi gradien di bawah garis; hanya masuk akal untuk grafik satu garis.
  final bool isiGradien;
}

int? ambilGulaDarah(Sampel s) => s.gulaDarah;
int? ambilDetakJantung(Sampel s) => s.detakJantung;
int? ambilSistolik(Sampel s) => s.sistolik;
int? ambilDiastolik(Sampel s) => s.diastolik;
int? ambilSpo2(Sampel s) => s.spo2;

const SeriMetrik seriGulaDarah = SeriMetrik(
  label: 'Gula darah',
  warna: Color(0xFF0EAD69),
  ambil: ambilGulaDarah,
  satuan: 'mg/dL',
  isiGradien: true,
);

const SeriMetrik seriDetakJantung = SeriMetrik(
  label: 'Detak jantung',
  warna: Color(0xFF0EAD69),
  ambil: ambilDetakJantung,
  satuan: 'bpm',
  isiGradien: true,
);

const SeriMetrik seriSistolik = SeriMetrik(
  label: 'Sistolik',
  warna: Color(0xFF0EAD69),
  ambil: ambilSistolik,
  satuan: 'mmHg',
);

const SeriMetrik seriDiastolik = SeriMetrik(
  label: 'Diastolik',
  warna: Color(0xFF7BE5C4),
  ambil: ambilDiastolik,
  satuan: 'mmHg',
);

/// SpO2 punya rentang wajar yang jauh lebih sempit dari metrik lain: 95–100
/// pada orang sehat, dan turun di bawah 95 sudah berarti sesuatu. `20` akan
/// meratakan seluruh grafiknya menjadi garis lurus.
const SeriMetrik seriSpo2 = SeriMetrik(
  label: 'Oksigen (SpO₂)',
  warna: Color(0xFF0EAD69),
  ambil: ambilSpo2,
  satuan: '%',
  isiGradien: true,
  rentangMinimum: 8,
);

/// Rentang sumbu x sebuah kurva sesi, dalam detik relatif t0.
///
/// Dipisah dari painter-nya semata-mata supaya bisa diuji: inilah satu-satunya
/// bagian dari penggambaran kurva yang pernah salah tanpa memberi gejala selain
/// "grafiknya kok begitu".
///
/// Sampel yang masih `menunggu` **ikut dihitung**, dan itu disengaja:
/// `detikRelatifT0` mereka adalah nilai nominal jadwalnya, jadi sesi yang baru
/// punya dua titik tetap digambar pada sumbu selebar jadwal penuhnya alih-alih
/// direntangkan memenuhi lebar kartu. Itu pula yang menggantikan lantai
/// `0..7200` yang dulu ditulis sebagai literal — angka yang berhenti benar
/// begitu jadwal menjadi data per sesi (docs/jadwal-titik-ukur.md §1).
(int, int) rentangDetik(List<Sampel> sampel) {
  if (sampel.isEmpty) return (0, 1);

  var min = sampel.first.detikRelatifT0;
  var max = min;
  for (final s in sampel) {
    if (s.detikRelatifT0 < min) min = s.detikRelatifT0;
    if (s.detikRelatifT0 > max) max = s.detikRelatifT0;
  }
  // Seluruh titik pada detik yang sama akan membuat pembagi skalanya nol.
  return (min, max <= min ? min + 1 : max);
}

/// Grafik satu sesi: 4 titik dalam ~2,5 jam, bukan kurva harian.
///
/// Sumbu x memakai `detikRelatifT0` tiap sampel, jadi jarak antar titik
/// mencerminkan jadwal sebenarnya. Titik yang belum ada tidak digambar, dan
/// segmen yang melompatinya digambar putus-putus — tidak ada nilai yang
/// dikarang (§8).
class KurvaSampel extends StatelessWidget {
  const KurvaSampel({
    super.key,
    required this.sampel,
    required this.seri,
    this.garisAcuan,
    this.labelAcuan,
    this.tinggi = 200,
    this.pesanKosong = 'Belum ada sampel',
  });

  final List<Sampel> sampel;
  final List<SeriMetrik> seri;

  /// Garis putus-putus horizontal, mis. baseline pra-makan.
  final int? garisAcuan;
  final String? labelAcuan;

  final double tinggi;
  final String pesanKosong;

  bool get _adaData =>
      sampel.any((s) => s.terisi && seri.any((m) => m.ambil(s) != null));

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tinggi,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: _adaData
          ? CustomPaint(
              size: Size.infinite,
              painter: KurvaSampelPainter(
                sampel: sampel,
                seri: seri,
                garisAcuan: garisAcuan,
                labelAcuan: labelAcuan,
              ),
            )
          : Center(
              child: Text(
                pesanKosong,
                style: const TextStyle(
                  fontFamily: fontPainter,
                  fontSize: 12,
                  color: Color(0xFF8FA7A1),
                ),
              ),
            ),
    );
  }
}

/// Kurva respons beberapa sesi yang ditumpuk (§4.4).
///
/// Sumbu y adalah **selisih dari baseline masing-masing sesi**, bukan nilai
/// mentah — hanya dengan begitu sesi yang baselinenya berbeda bisa dibandingkan
/// dalam satu gambar. Garis tebal adalah rata-rata per titik.
class KurvaTumpukSesi extends StatelessWidget {
  const KurvaTumpukSesi({
    super.key,
    required this.sesi,
    this.seri = seriGulaDarah,
    this.tinggi = 220,
  });

  final List<SesiMakan> sesi;
  final SeriMetrik seri;
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    final layak = [
      for (final s in sesi)
        if (s.sampel[0].terisi && seri.ambil(s.sampel[0]) != null) s,
    ];

    return Container(
      height: tinggi,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: layak.isEmpty
          ? const Center(
              child: Text(
                'Belum ada sesi dengan baseline terukur',
                style: TextStyle(
                  fontFamily: fontPainter,
                  fontSize: 12,
                  color: Color(0xFF8FA7A1),
                ),
              ),
            )
          : CustomPaint(
              size: Size.infinite,
              painter: KurvaTumpukPainter(sesi: layak, seri: seri),
            ),
    );
  }
}

class KurvaTumpukPainter extends CustomPainter {
  KurvaTumpukPainter({required this.sesi, required this.seri});

  final List<SesiMakan> sesi;
  final SeriMetrik seri;

  static const double _padAtas = 14;
  static const double _padBawah = 22;

  @override
  void paint(Canvas canvas, Size size) {
    // Tiap sesi diringkas menjadi titik (detikRelatifT0, delta dari baseline).
    final garis = <List<({int index, int x, double y})>>[];
    // Sama seperti pada kurva satu sesi: rentangnya dari data, bukan dari
    // jadwal produksi yang ditulis sebagai literal.
    var xMin = 0, xMax = 0;
    var adaX = false;
    var yMin = 0.0, yMax = 0.0;

    for (final s in sesi) {
      final dasar = seri.ambil(s.sampel[0]);
      if (dasar == null) continue;
      final titik = <({int index, int x, double y})>[];
      for (final sampel in s.sampel) {
        final v = sampel.terisi ? seri.ambil(sampel) : null;
        if (v == null) continue;
        final delta = (v - dasar).toDouble();
        titik.add((index: sampel.index, x: sampel.detikRelatifT0, y: delta));
        if (!adaX) {
          xMin = xMax = sampel.detikRelatifT0;
          adaX = true;
        }
        if (sampel.detikRelatifT0 < xMin) xMin = sampel.detikRelatifT0;
        if (sampel.detikRelatifT0 > xMax) xMax = sampel.detikRelatifT0;
        if (delta < yMin) yMin = delta;
        if (delta > yMax) yMax = delta;
      }
      if (titik.length >= 2) garis.add(titik);
    }
    if (garis.isEmpty) return;
    if (xMax <= xMin) xMax = xMin + 1;

    yMax = yMax + 12;
    yMin = yMin - 12;

    final area = Rect.fromLTRB(
      0,
      _padAtas,
      size.width,
      size.height - _padBawah,
    );
    double xDari(int detik) =>
        area.left + (detik - xMin) / (xMax - xMin) * area.width;
    double yDari(double delta) =>
        area.bottom - (delta - yMin) / (yMax - yMin) * area.height;

    // Garis nol = baseline tiap sesi.
    final y0 = yDari(0);
    canvas.drawLine(
      Offset(area.left, y0),
      Offset(area.right, y0),
      Paint()
        ..color = const Color(0xFF9CB1AC)
        ..strokeWidth = 1,
    );
    _teks(
      canvas,
      'baseline',
      Offset(area.left, y0 + 2),
      const TextStyle(
        fontFamily: fontPainter,
        fontSize: 9,
        color: Color(0xFF9CB1AC),
      ),
    );

    final paintTipis = Paint()
      ..color = seri.warna.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round;

    for (final titik in garis) {
      final path = Path()..moveTo(xDari(titik.first.x), yDari(titik.first.y));
      for (var i = 1; i < titik.length; i++) {
        _sambung(
          path,
          Offset(xDari(titik[i - 1].x), yDari(titik[i - 1].y)),
          Offset(xDari(titik[i].x), yDari(titik[i].y)),
        );
      }
      canvas.drawPath(path, paintTipis);
    }

    // Rata-rata per titik pengukuran.
    final rata = <({int index, int x, double y})>[];
    for (var index = 0; index < 4; index++) {
      final nilai = <double>[];
      final posisi = <int>[];
      for (final titik in garis) {
        for (final t in titik) {
          if (t.index != index) continue;
          nilai.add(t.y);
          posisi.add(t.x);
        }
      }
      if (nilai.isEmpty) continue;
      rata.add((
        index: index,
        x: (posisi.reduce((a, b) => a + b) / posisi.length).round(),
        y: nilai.reduce((a, b) => a + b) / nilai.length,
      ));
    }

    if (rata.length >= 2) {
      final path = Path()..moveTo(xDari(rata.first.x), yDari(rata.first.y));
      for (var i = 1; i < rata.length; i++) {
        _sambung(
          path,
          Offset(xDari(rata[i - 1].x), yDari(rata[i - 1].y)),
          Offset(xDari(rata[i].x), yDari(rata[i].y)),
        );
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = seri.warna
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      for (final t in rata) {
        final pusat = Offset(xDari(t.x), yDari(t.y));
        canvas.drawCircle(pusat, 6, Paint()..color = const Color(0xFFE2F6F0));
        canvas.drawCircle(pusat, 3, Paint()..color = seri.warna);
        _teks(
          canvas,
          '${t.y >= 0 ? '+' : ''}${t.y.round()}',
          Offset(pusat.dx, pusat.dy - 22),
          const TextStyle(
            fontFamily: fontPainter,
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
          pusatDiX: true,
          batasKanan: size.width,
        );
      }
    }

    // Label sumbu x hanya untuk titik yang benar-benar punya data.
    for (final t in rata) {
      _teks(
        canvas,
        labelTitikSampel[t.index],
        Offset(xDari(t.x), size.height - _padBawah + 4),
        const TextStyle(
          fontFamily: fontPainter,
          fontSize: 9,
          color: Color(0xFF6B807B),
        ),
        pusatDiX: true,
        batasKanan: size.width,
      );
    }
  }

  void _sambung(Path path, Offset a, Offset b) {
    final dx = (b.dx - a.dx) * 0.4;
    path.cubicTo(a.dx + dx, a.dy, b.dx - dx, b.dy, b.dx, b.dy);
  }

  void _teks(
    Canvas canvas,
    String teks,
    Offset posisi,
    TextStyle gaya, {
    bool pusatDiX = false,
    double? batasKanan,
  }) {
    final pelukis = TextPainter(
      text: TextSpan(text: teks, style: gaya),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = pusatDiX ? posisi.dx - pelukis.width / 2 : posisi.dx;
    if (batasKanan != null) {
      dx = dx.clamp(0.0, (batasKanan - pelukis.width).clamp(0.0, batasKanan));
    }
    pelukis.paint(canvas, Offset(dx, posisi.dy));
  }

  @override
  bool shouldRepaint(covariant KurvaTumpukPainter oldDelegate) =>
      oldDelegate.sesi != sesi || oldDelegate.seri != seri;
}

class KurvaSampelPainter extends CustomPainter {
  KurvaSampelPainter({
    required this.sampel,
    required this.seri,
    this.garisAcuan,
    this.labelAcuan,
  });

  final List<Sampel> sampel;
  final List<SeriMetrik> seri;
  final int? garisAcuan;
  final String? labelAcuan;

  /// Cukup untuk **dua baris** label sumbu x: yang berdesakan turun satu baris,
  /// dan titik yang terlewat menulis namanya di atas tanda `—`.
  static const double _padBawah = 32;

  static const TextStyle _gayaAcuan = TextStyle(
    fontFamily: fontPainter,
    fontSize: 9,
    color: Color(0xFF9CB1AC),
  );

  /// Lebar teks sebelum digambar, untuk memutuskan tata letaknya.
  double _ukur(String teks, TextStyle gaya) => (TextPainter(
    text: TextSpan(text: teks, style: gaya),
    textDirection: TextDirection.ltr,
  )..layout()).width;

  @override
  void paint(Canvas canvas, Size size) {
    // Sumbu x mengikuti jadwal sebenarnya, termasuk baseline yang negatif.
    //
    // Rentangnya diturunkan **seluruhnya** dari sampel yang ada, tidak lagi
    // dimulai dari 0..7200. Angka 7200 itu adalah `+2 jam` jadwal produksi yang
    // ditulis sebagai literal, dan ia bertahan sebagai lantai: begitu jadwalnya
    // menjadi data per sesi (docs/jadwal-titik-ukur.md §1), sesi yang titik
    // terakhirnya jatuh pada detik ke-120 — jadwal uji `PAKAI_JADWAL_UJI` —
    // digambar pada sumbu selebar dua jam, sehingga keempat titiknya menumpuk
    // di 1,7% pertama lebar kurva dan seluruh label sumbunya saling menimpa.
    //
    // Sampel yang masih `menunggu` ikut dihitung, dan itu yang menggantikan
    // fungsi lantai tadi: `detikRelatifT0` mereka adalah nilai nominal dari
    // jadwal, jadi sesi yang baru punya dua titik tetap digambar pada sumbu
    // selebar jadwal penuhnya, bukan direntangkan memenuhi lebar kartu.
    final (xMin, xMax) = rentangDetik(sampel);

    var nilaiMin = garisAcuan ?? 1 << 30, nilaiMax = garisAcuan ?? -(1 << 30);
    for (final s in sampel) {
      if (!s.terisi) continue;
      for (final m in seri) {
        final v = m.ambil(s);
        if (v == null) continue;
        if (v < nilaiMin) nilaiMin = v;
        if (v > nilaiMax) nilaiMax = v;
      }
    }
    // Lantai rentang milik metriknya (lihat `SeriMetrik.rentangMinimum`); bila
    // beberapa garis berbagi satu sumbu, yang terlebar yang menang.
    var rentangMinimum = 0;
    for (final m in seri) {
      if (m.rentangMinimum > rentangMinimum) rentangMinimum = m.rentangMinimum;
    }
    if (nilaiMax - nilaiMin < rentangMinimum) {
      final pad = (rentangMinimum / 2).ceil();
      nilaiMin -= pad;
      nilaiMax += pad;
    } else {
      nilaiMin -= 12;
      nilaiMax += 12;
    }

    // Ruang untuk legenda hanya disisakan bila garisnya lebih dari satu.
    final padAtas = seri.length > 1 ? 30.0 : 26.0;
    final area = Rect.fromLTRB(0, padAtas, size.width, size.height - _padBawah);
    double xDari(int detik) =>
        area.left + (detik - xMin) / (xMax - xMin) * area.width;
    double yDari(num nilai) =>
        area.bottom - (nilai - nilaiMin) / (nilaiMax - nilaiMin) * area.height;

    final paintGrid = Paint()
      ..color = const Color(0xFFE0EDE9).withValues(alpha: 0.6)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = area.top + area.height * i / 3;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), paintGrid);
    }

    final acuan = garisAcuan;
    if (acuan != null) {
      final y = yDari(acuan);
      _pathPutus(
        canvas,
        Path()
          ..moveTo(area.left, y)
          ..lineTo(area.right, y),
        Paint()
          ..color = const Color(0xFF9CB1AC)
          ..strokeWidth = 1.2,
      );
      // Ditempel di **kanan**, bukan kiri. Titik paling awal sebuah sesi selalu
      // baseline, jadi ia duduk di ujung kiri bersama label nilainya sendiri —
      // dan "baseline" di sana menimpanya persis.
      //
      // Angkanya sengaja tidak ikut: garis putus-putus ini menunjukkan **di
      // mana**, sementara berapanya sudah berdiri sebagai kotak nilai
      // "Baseline" di atas kurva yang sama.
      final teksAcuan = labelAcuan ?? 'baseline';
      _teks(
        canvas,
        teksAcuan,
        Offset(area.right - _ukur(teksAcuan, _gayaAcuan), y - 14),
        _gayaAcuan,
      );
    }

    for (final m in seri) {
      final titik = <_Titik>[];
      for (final s in sampel) {
        final v = s.terisi ? m.ambil(s) : null;
        if (v == null) continue;
        titik.add(
          _Titik(s.index, Offset(xDari(s.detikRelatifT0), yDari(v)), v),
        );
      }
      _gambarSeri(
        canvas,
        size,
        area,
        m,
        titik,
        tampilkanNilai: seri.length == 1,
      );
    }

    // Label sumbu x memakai nama titik pengukuran, bukan jam harian.
    //
    // **Yang berdesakan turun satu baris.** Sumbu x memakai `detikRelatifT0`
    // supaya jaraknya mencerminkan jadwal sebenarnya, dan justru itu yang
    // membuat dua titik pertama berdempetan: baseline diukur beberapa menit
    // sebelum t0, sementara dua titik berikutnya berjarak satu dan dua jam.
    // "Baseline" dan "Selesai makan" karena itu saling menimpa di ujung kiri —
    // terbaca sebagai satu kata rusak. Membuang salah satunya berarti membuang
    // titik yang justru paling berarti, jadi keduanya tetap ditulis, hanya tidak
    // sebaris.
    final kananBaris = <double>[-1e9, -1e9];
    for (final s in sampel) {
      final adaNilai = s.terisi && seri.any((m) => m.ambil(s) != null);
      final teks = adaNilai ? s.label : '${s.label}\n—';
      final gaya = TextStyle(
        fontFamily: fontPainter,
        fontSize: 9,
        color: adaNilai ? const Color(0xFF6B807B) : const Color(0xFF9CB1AC),
      );

      final lebar = _ukur(teks, gaya);
      final kiri = (xDari(s.detikRelatifT0) - lebar / 2).clamp(
        0.0,
        (size.width - lebar).clamp(0.0, size.width),
      );
      // Kedua baris diperiksa, bukan hanya yang pertama. Versi lama menaruh
      // apa pun yang tidak muat di baris 0 ke baris 1 tanpa menanyakan apakah
      // baris 1 masih kosong, jadi tiga label yang berdesakan menghasilkan dua
      // di antaranya saling menimpa — persis tumpukan yang sama, hanya turun
      // satu baris. Bila keduanya penuh, dipilih yang ujung kanannya paling
      // kiri: tumpang tindihnya tidak bisa dihindari, tapi bisa diperkecil.
      final int baris;
      if (kiri >= kananBaris[0] + 6) {
        baris = 0;
      } else if (kiri >= kananBaris[1] + 6) {
        baris = 1;
      } else {
        baris = kananBaris[0] <= kananBaris[1] ? 0 : 1;
      }
      kananBaris[baris] = kiri + lebar;

      _teks(
        canvas,
        teks,
        Offset(
          xDari(s.detikRelatifT0),
          size.height - _padBawah + 4 + baris * 11,
        ),
        gaya,
        pusatDiX: true,
        batasKanan: size.width,
      );
    }

    if (seri.length > 1) _gambarLegenda(canvas, size);
  }

  void _gambarSeri(
    Canvas canvas,
    Size size,
    Rect area,
    SeriMetrik m,
    List<_Titik> titik, {
    required bool tampilkanNilai,
  }) {
    if (titik.isEmpty) return;

    final paintGaris = Paint()
      ..color = m.warna
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    if (m.isiGradien && titik.length >= 2) {
      final isi = Path()..moveTo(titik.first.posisi.dx, titik.first.posisi.dy);
      for (var i = 1; i < titik.length; i++) {
        _sambung(isi, titik[i - 1].posisi, titik[i].posisi);
      }
      isi
        ..lineTo(titik.last.posisi.dx, area.bottom)
        ..lineTo(titik.first.posisi.dx, area.bottom)
        ..close();
      canvas.drawPath(
        isi,
        Paint()
          ..shader = LinearGradient(
            colors: [
              m.warna.withValues(alpha: 0.15),
              m.warna.withValues(alpha: 0.0),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
      );
    }

    // Segmen penuh bila dua titik berurutan; putus-putus bila melompati sampel
    // yang terlewat atau masih ditunggu.
    for (var i = 1; i < titik.length; i++) {
      final a = titik[i - 1], b = titik[i];
      final segmen = Path()..moveTo(a.posisi.dx, a.posisi.dy);
      _sambung(segmen, a.posisi, b.posisi);
      if (b.index - a.index == 1) {
        canvas.drawPath(segmen, paintGaris);
      } else {
        _pathPutus(canvas, segmen, paintGaris);
      }
    }

    for (final t in titik) {
      canvas.drawCircle(t.posisi, 7, Paint()..color = const Color(0xFFE2F6F0));
      canvas.drawCircle(t.posisi, 3.5, Paint()..color = m.warna);
      if (!tampilkanNilai) continue;
      _teks(
        canvas,
        '${t.nilai}',
        Offset(t.posisi.dx, t.posisi.dy - 24),
        const TextStyle(
          fontFamily: fontPainter,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E3A34),
        ),
        pusatDiX: true,
        batasKanan: size.width,
      );
    }
  }

  void _gambarLegenda(Canvas canvas, Size size) {
    var dx = 0.0;
    for (final m in seri) {
      canvas.drawCircle(Offset(dx + 4, 6), 4, Paint()..color = m.warna);
      final pelukis = _teks(
        canvas,
        m.label,
        Offset(dx + 12, 0),
        const TextStyle(
          fontFamily: fontPainter,
          fontSize: 9,
          color: Color(0xFF6B807B),
        ),
      );
      dx += 12 + pelukis + 14;
    }
  }

  /// Kurva halus antar dua titik: kontrol digeser horizontal agar tidak
  /// menembus di luar rentang nilai kedua ujungnya.
  void _sambung(Path path, Offset a, Offset b) {
    final dx = (b.dx - a.dx) * 0.4;
    path.cubicTo(a.dx + dx, a.dy, b.dx - dx, b.dy, b.dx, b.dy);
  }

  void _pathPutus(Canvas canvas, Path path, Paint paint) {
    const panjang = 5.0, jeda = 4.0;
    for (final metrik in path.computeMetrics()) {
      var jarak = 0.0;
      while (jarak < metrik.length) {
        final akhir = (jarak + panjang).clamp(0.0, metrik.length);
        canvas.drawPath(metrik.extractPath(jarak, akhir), paint);
        jarak = akhir + jeda;
      }
    }
  }

  double _teks(
    Canvas canvas,
    String teks,
    Offset posisi,
    TextStyle gaya, {
    bool pusatDiX = false,
    double? batasKanan,
  }) {
    final pelukis = TextPainter(
      text: TextSpan(text: teks, style: gaya),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = pusatDiX ? posisi.dx - pelukis.width / 2 : posisi.dx;
    if (batasKanan != null) {
      dx = dx.clamp(0.0, (batasKanan - pelukis.width).clamp(0.0, batasKanan));
    }
    pelukis.paint(canvas, Offset(dx, posisi.dy));
    return pelukis.width;
  }

  @override
  bool shouldRepaint(covariant KurvaSampelPainter oldDelegate) =>
      oldDelegate.sampel != sampel ||
      oldDelegate.seri != seri ||
      oldDelegate.garisAcuan != garisAcuan;
}

class _Titik {
  const _Titik(this.index, this.posisi, this.nilai);
  final int index;
  final Offset posisi;
  final int nilai;
}
