import 'package:flutter/material.dart';

class BloodSugarSplinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Wave line path
    final paintLine = Paint()
      ..color = const Color(0xFF0EAD69)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.5)
      ..cubicTo(size.width * 0.15, size.height * 0.48, size.width * 0.22, size.height * 0.52, size.width * 0.33, size.height * 0.45)
      ..cubicTo(size.width * 0.45, size.height * 0.4, size.width * 0.55, size.height * 0.48, size.width * 0.68, size.height * 0.46)
      ..cubicTo(size.width * 0.78, size.height * 0.42, size.width * 0.88, size.height * 0.5, size.width, size.height * 0.48);

    // Gradient below the line
    final pathFill = Path.from(path)
      ..lineTo(size.width, size.height - 20)
      ..lineTo(0, size.height - 20)
      ..close();

    final paintFill = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF0EAD69).withValues(alpha: 0.15),
          const Color(0xFF0EAD69).withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(pathFill, paintFill);
    canvas.drawPath(path, paintLine);

    // Draw active dot at 08:00 (around x = width * 0.33, y = height * 0.45)
    final dotX = size.width * 0.33;
    final dotY = size.height * 0.45;

    final dotOuter = Paint()
      ..color = const Color(0xFFE2F6F0)
      ..style = PaintingStyle.fill;
    final dotInner = Paint()
      ..color = const Color(0xFF0EAD69)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(dotX, dotY), 8, dotOuter);
    canvas.drawCircle(Offset(dotX, dotY), 4, dotInner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GulaDarahDetailPage extends StatelessWidget {
  const GulaDarahDetailPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A34)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Gula Darah',
          style: TextStyle(color: Color(0xFF1E3A34), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today_outlined, color: Color(0xFF1E3A34)),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tabs toggle
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE5EDE9),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildTab('Harian', true),
                  _buildTab('Mingguan', false),
                  _buildTab('Bulanan', false),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Average display row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: const TextSpan(
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A34),
                        ),
                        children: [
                          TextSpan(text: '112'),
                          TextSpan(
                            text: ' mg/dL',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                              color: Color(0xFF6B807B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Text(
                      'Rata-rata Hari Ini',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7E9A94),
                      ),
                    ),
                  ],
                ),
                // Normal Indicator with Water Drop Icon
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2F6F0),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: const [
                      Icon(Icons.water_drop, color: Color(0xFF0EAD69), size: 16),
                      SizedBox(width: 4),
                      Text(
                        'Normal',
                        style: TextStyle(
                          color: Color(0xFF0EAD69),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Chart Box
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Stack(
                children: [
                  // Horizontal Grid
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(4, (index) {
                      return Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: const Color(0xFFE0EDE9).withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  // Spline Line (Slightly flatter spline for Blood Sugar)
                  Positioned.fill(
                    child: CustomPaint(
                      painter: BloodSugarSplinePainter(),
                    ),
                  ),
                  // Active label indicator "08:00"
                  Positioned(
                    left: 92,
                    top: 42,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2F6F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '08:00',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0EAD69),
                        ),
                      ),
                    ),
                  ),
                  // Timeline labels
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('00:00', style: TextStyle(fontSize: 10, color: Color(0xFF90A4AE))),
                        Text('04:00', style: TextStyle(fontSize: 10, color: Color(0xFF90A4AE))),
                        Text('08:00', style: TextStyle(fontSize: 10, color: Color(0xFF90A4AE), fontWeight: FontWeight.bold)),
                        Text('12:00', style: TextStyle(fontSize: 10, color: Color(0xFF90A4AE))),
                        Text('16:00', style: TextStyle(fontSize: 10, color: Color(0xFF90A4AE))),
                        Text('20:00', style: TextStyle(fontSize: 10, color: Color(0xFF90A4AE))),
                        Text('24:00', style: TextStyle(fontSize: 10, color: Color(0xFF90A4AE))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Data Per 2 Jam Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Data per 2 Jam',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A34),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Hari Ini >',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0EAD69),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // List of readings
            _buildTimeReadingItem('08:00', '112 mg/dL', 'Normal'),
            _buildTimeReadingItem('06:00', '105 mg/dL', 'Normal'),
            _buildTimeReadingItem('04:00', '98 mg/dL', 'Normal'),
            _buildTimeReadingItem('02:00', '95 mg/dL', 'Normal'),
            _buildTimeReadingItem('00:00', '92 mg/dL', 'Normal'),
            const SizedBox(height: 24),

            // Normal Range Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE2F6F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Kadar gula darah normal (puasa):',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A34),
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          '70 - 130 mg/dL',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0EAD69),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Water drop icon container
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.water_drop,
                      color: Color(0xFF0EAD69),
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, bool isSelected) {
    return Expanded(
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0EAD69) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF6B807B),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTimeReadingItem(String time, String value, String status) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFF0EAD69),
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                time,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                ),
              ),
            ],
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A34),
            ),
          ),
          Row(
            children: [
              Text(
                status,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF0EAD69),
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 4),
              const Text(
                '💚',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
