import 'package:flutter/material.dart';

import '../models/analisis_sesi.dart';

/// Sebaran karbohidrat terdeteksi vs kenaikan gula darah — satu titik per sesi
/// (§4.3). Ini pertanyaan terkuat yang bisa dijawab aplikasi, dan datanya nyata
/// karena tiap makan difoto.
///
/// Sesi yang keyakinan deteksinya rendah digambar sebagai lingkaran kosong dan
/// tidak ikut membentuk garis tren, agar estimasi porsi yang meleset tidak
/// mencemari korelasi.
class SebaranKarboGula extends StatelessWidget {
  const SebaranKarboGula({
    super.key,
    required this.titik,
    this.tren,
    this.tinggi = 220,
  });

  final List<TitikSebaran> titik;
  final GarisTren? tren;
  final double tinggi;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: tinggi,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
      ),
      padding: const EdgeInsets.fromLTRB(12, 16, 16, 12),
      child: titik.length < 2
          ? const Center(
              child: Text(
                'Butuh minimal dua sesi untuk melihat hubungannya',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Color(0xFF8FA7A1)),
              ),
            )
          : CustomPaint(
              size: Size.infinite,
              painter: SebaranKarboPainter(titik: titik, tren: tren),
            ),
    );
  }
}

class SebaranKarboPainter extends CustomPainter {
  SebaranKarboPainter({required this.titik, this.tren});

  final List<TitikSebaran> titik;
  final GarisTren? tren;

  static const double _padKiri = 30;
  static const double _padBawah = 26;
  static const double _padAtas = 8;

  @override
  void paint(Canvas canvas, Size size) {
    var xMax = 0.0, yMax = 0.0, yMin = 0.0;
    for (final t in titik) {
      if (t.karbohidrat > xMax) xMax = t.karbohidrat;
      if (t.delta > yMax) yMax = t.delta.toDouble();
      if (t.delta < yMin) yMin = t.delta.toDouble();
    }
    xMax = (xMax * 1.15).ceilToDouble();
    yMax = (yMax * 1.2).ceilToDouble();
    if (xMax <= 0) xMax = 10;
    if (yMax <= 0) yMax = 10;

    final area = Rect.fromLTRB(
      _padKiri,
      _padAtas,
      size.width,
      size.height - _padBawah,
    );
    double xDari(double karbo) => area.left + karbo / xMax * area.width;
    double yDari(double delta) =>
        area.bottom - (delta - yMin) / (yMax - yMin) * area.height;

    // Garis bantu + label sumbu y (mg/dL).
    final paintGrid = Paint()
      ..color = const Color(0xFFE0EDE9).withValues(alpha: 0.7)
      ..strokeWidth = 1;
    for (var i = 0; i <= 3; i++) {
      final y = area.top + area.height * i / 3;
      canvas.drawLine(Offset(area.left, y), Offset(area.right, y), paintGrid);
      final nilai = yMax - (yMax - yMin) * i / 3;
      _teks(
        canvas,
        '+${nilai.round()}',
        Offset(0, y - 6),
        const TextStyle(fontSize: 9, color: Color(0xFF9CB1AC)),
      );
    }

    // Label sumbu x (gram karbohidrat).
    for (var i = 0; i <= 2; i++) {
      final karbo = xMax * i / 2;
      _teks(
        canvas,
        '${karbo.round()} g',
        Offset(xDari(karbo), size.height - _padBawah + 4),
        const TextStyle(fontSize: 9, color: Color(0xFF9CB1AC)),
        pusatDiX: true,
        batasKanan: size.width,
      );
    }
    _teks(
      canvas,
      'karbohidrat →',
      Offset(area.right, size.height - 12),
      const TextStyle(fontSize: 9, color: Color(0xFF9CB1AC)),
      rataKanan: true,
    );

    // Garis tren digambar sebelum titik agar tidak menutupinya.
    final t = tren;
    if (t != null) {
      final paintTren = Paint()
        ..color = const Color(0xFF0EAD69).withValues(alpha: 0.5)
        ..strokeWidth = 2;
      canvas.drawLine(
        Offset(xDari(0), yDari(t.nilaiPada(0))),
        Offset(xDari(xMax), yDari(t.nilaiPada(xMax))),
        paintTren,
      );
    }

    for (final p in titik) {
      final pusat = Offset(xDari(p.karbohidrat), yDari(p.delta.toDouble()));
      if (p.andal) {
        canvas.drawCircle(
          pusat,
          5,
          Paint()..color = const Color(0xFF0EAD69),
        );
      } else {
        // Keyakinan rendah: lingkaran kosong, tidak ikut garis tren.
        canvas.drawCircle(
          pusat,
          5,
          Paint()
            ..color = const Color(0xFF9CB1AC)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
  }

  void _teks(
    Canvas canvas,
    String teks,
    Offset posisi,
    TextStyle gaya, {
    bool pusatDiX = false,
    bool rataKanan = false,
    double? batasKanan,
  }) {
    final pelukis = TextPainter(
      text: TextSpan(text: teks, style: gaya),
      textDirection: TextDirection.ltr,
    )..layout();
    var dx = posisi.dx;
    if (pusatDiX) dx -= pelukis.width / 2;
    if (rataKanan) dx -= pelukis.width;
    if (batasKanan != null) {
      dx = dx.clamp(0.0, (batasKanan - pelukis.width).clamp(0.0, batasKanan));
    }
    pelukis.paint(canvas, Offset(dx, posisi.dy));
  }

  @override
  bool shouldRepaint(covariant SebaranKarboPainter oldDelegate) =>
      oldDelegate.titik != titik || oldDelegate.tren != tren;
}
