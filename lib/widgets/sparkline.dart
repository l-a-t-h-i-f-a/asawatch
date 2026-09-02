import 'package:flutter/material.dart';

/// Sparkline mini yang **digambar dari data**, bukan dari path bezier tetap.
///
/// Pemakaian nyatanya adalah puncak gula darah beberapa sesi terakhir di
/// Beranda (§4.1). Kurang dari dua nilai tidak digambar sama sekali — satu
/// titik bukan tren, dan mengarangnya melanggar §8.
class MiniSparklinePainter extends CustomPainter {
  MiniSparklinePainter({required this.colors, required this.nilai});

  final List<Color> colors;
  final List<double> nilai;

  @override
  void paint(Canvas canvas, Size size) {
    if (nilai.length < 2) return;

    var min = nilai.first, max = nilai.first;
    for (final v in nilai) {
      if (v < min) min = v;
      if (v > max) max = v;
    }
    final rentang = (max - min).abs() < 0.001 ? 1.0 : max - min;

    final titik = <Offset>[
      for (var i = 0; i < nilai.length; i++)
        Offset(
          size.width * i / (nilai.length - 1),
          size.height - (nilai[i] - min) / rentang * (size.height - 4) - 2,
        ),
    ];

    final path = Path()..moveTo(titik.first.dx, titik.first.dy);
    for (var i = 1; i < titik.length; i++) {
      final a = titik[i - 1], b = titik[i];
      final dx = (b.dx - a.dx) * 0.4;
      path.cubicTo(a.dx + dx, a.dy, b.dx - dx, b.dy, b.dx, b.dy);
    }

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        colors: colors,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);

    // Titik terakhir ditegaskan: itu sesi paling baru.
    canvas.drawCircle(titik.last, 2.5, Paint()..color = colors.first);
  }

  @override
  bool shouldRepaint(covariant MiniSparklinePainter oldDelegate) =>
      oldDelegate.nilai != nilai || oldDelegate.colors != colors;
}
