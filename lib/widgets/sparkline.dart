import 'package:flutter/material.dart';

class MiniSparklinePainter extends CustomPainter {
  final List<Color> colors;
  MiniSparklinePainter({required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.7)
      ..quadraticBezierTo(size.width * 0.2, size.height * 0.6, size.width * 0.35, size.height * 0.4)
      ..quadraticBezierTo(size.width * 0.5, size.height * 0.2, size.width * 0.65, size.height * 0.65)
      ..quadraticBezierTo(size.width * 0.8, size.height * 0.8, size.width, size.height * 0.3);

    paint.shader = LinearGradient(
      colors: colors,
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
