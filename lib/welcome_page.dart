import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'login_page.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // Background soft waves and leaves
          Positioned.fill(
            child: CustomPaint(
              painter: BackgroundPainter(),
            ),
          ),
          
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Watch and floating badges illustration area
                Expanded(
                  flex: 11,
                  child: Center(
                    child: SizedBox(
                      width: 340,
                      height: 340,
                      child: Stack(
                        alignment: Alignment.center,
                        clipBehavior: Clip.none,
                        children: [
                          // 1. Concentric elliptical ripples under the watch
                          const RipplesWidget(),
                          
                          // 2. Beautifully designed tilted Smartwatch
                          const SmartwatchMockup(),
                          
                          // 3. Floating Badges around the watch
                          // Top-Left Badge (Water drop, outline style)
                          Positioned(
                            left: 30,
                            top: 85,
                            child: const BadgeWidget(
                              icon: Icons.opacity_outlined,
                              isSolid: false,
                            ),
                          ),
                          // Mid-Left Badge (Water drop with ripple, outline style)
                          Positioned(
                            left: 20,
                            top: 175,
                            child: const BadgeWidget(
                              icon: Icons.water_drop_outlined,
                              isSolid: false,
                            ),
                          ),
                          // Top-Right Badge (Heart rate, solid green)
                          Positioned(
                            right: 45,
                            top: 45,
                            child: const BadgeWidget(
                              icon: Icons.favorite_rounded,
                              isSolid: true,
                            ),
                          ),
                          // Mid-Right Badge (Camera/nutrition, outline style)
                          Positioned(
                            right: 20,
                            top: 125,
                            child: const BadgeWidget(
                              icon: Icons.add_a_photo_outlined,
                              isSolid: false,
                            ),
                          ),
                          // Bottom-Right Badge (Cutlery, outline style)
                          Positioned(
                            right: 35,
                            top: 205,
                            child: const BadgeWidget(
                              icon: Icons.restaurant_rounded,
                              isSolid: false,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Welcome / Onboarding Text
                Expanded(
                  flex: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      children: [
                        // App Logo Heart Widget
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.favorite_rounded,
                                color: Color(0xFF1B9C73),
                                size: 40,
                              ),
                              CustomPaint(
                                size: const Size(22, 12),
                                painter: PulseLinePainter(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Title: HealthWatch
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                              fontFamily: 'Montserrat',
                            ),
                            children: [
                              TextSpan(
                                text: 'Health',
                                style: TextStyle(color: Color(0xFF2C3E50)),
                              ),
                              TextSpan(
                                text: 'Watch',
                                style: TextStyle(color: Color(0xFF1B9C73)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        // Subtitle
                        const Text(
                          'Pantau Kesehatanmu, Hidup Lebih Sehat',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        // Page Indicator dots
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Color(0xFF1B9C73),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: const Color(0xFF1B9C73).withValues(alpha: 0.2),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                
                // Actions Area
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    children: [
                      // "Mulai Sekarang" Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1B9C73),
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Mulai Sekarang',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      // "Masuk ke Akun" Button
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const LoginPage(),
                              ),
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                              color: Color(0xFF1B9C73),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          child: const Text(
                            'Masuk ke Akun',
                            style: TextStyle(
                              color: Color(0xFF1B9C73),
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// concentric elliptical ripples under the watch
class RipplesWidget extends StatelessWidget {
  const RipplesWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Transform(
        alignment: Alignment.center,
        transform: Matrix4.identity()
          ..setEntry(3, 2, 0.001)
          ..rotateX(1.15), // tilt back to create 3D ellipse effect
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outermost ripple
            Container(
              width: 270,
              height: 270,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFBBEAD6).withValues(alpha: 0.25),
                  width: 1.5,
                ),
              ),
            ),
            // Middle ripple
            Container(
              width: 210,
              height: 210,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFBBEAD6).withValues(alpha: 0.45),
                  width: 2.0,
                ),
              ),
            ),
            // Innermost ripple
            Container(
              width: 150,
              height: 150,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFBBEAD6).withValues(alpha: 0.7),
                  width: 2.5,
                ),
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE8F8F5).withValues(alpha: 0.5),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// 3D styled smartwatch mockup
class SmartwatchMockup extends StatelessWidget {
  const SmartwatchMockup({super.key});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.22, // Tilted left, about -12 degrees
      child: SizedBox(
        width: 160,
        height: 240,
        child: Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            // Top Watch Band (silicone strap)
            Positioned(
              top: 0,
              child: Container(
                width: 62,
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(24),
                    topRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, -2),
                    ),
                  ],
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF86D5B4), // light curve highlights
                      Color(0xFF5AB693), // sage green
                      Color(0xFF3B9472), // shadow near body
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Bottom Watch Band (silicone strap)
            Positioned(
              bottom: 0,
              child: Container(
                width: 62,
                height: 110,
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  gradient: const LinearGradient(
                    colors: [
                      Color(0xFF3B9472), // shadow near body
                      Color(0xFF5AB693), // sage green
                      Color(0xFF86D5B4), // light curve highlights
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
            // Watch Body/Bezel
            Container(
              width: 148,
              height: 148,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1B9C73).withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 2,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE2E8F0), // metallic highlight
                    Color(0xFF94A3B8), // dark silver
                    Color(0xFFCBD5E1), // medium silver
                    Color(0xFFE2E8F0),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Container(
                width: 136,
                height: 136,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF0F1412), // glossy black screen
                ),
                padding: const EdgeInsets.all(8),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Concentric glowing activity ring
                    SizedBox(
                      width: 112,
                      height: 112,
                      child: CircularProgressIndicator(
                        value: 0.75,
                        strokeWidth: 4,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF1B9C73)),
                        backgroundColor: const Color(0xFF1B9C73).withValues(alpha: 0.12),
                      ),
                    ),
                    // Inner progress indicator accent
                    SizedBox(
                      width: 94,
                      height: 94,
                      child: CircularProgressIndicator(
                        value: 0.45,
                        strokeWidth: 2,
                        valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF7BE5C4)),
                        backgroundColor: Colors.transparent,
                      ),
                    ),
                    // Heartrate indicator (left-mid)
                    Positioned(
                      left: 14,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.favorite_rounded,
                            color: Color(0xFF1B9C73),
                            size: 14,
                          ),
                          const SizedBox(width: 1),
                          Text(
                            '88',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Top Right metric "3"
                    Positioned(
                      top: 22,
                      right: 22,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            '3',
                            style: TextStyle(
                              color: Color(0xFF1B9C73),
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'SEHAT',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 6,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Mid Right metric "9200" steps
                    Positioned(
                      bottom: 44,
                      right: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            '9200',
                            style: TextStyle(
                              color: Color(0xFF1B9C73),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              height: 1.0,
                            ),
                          ),
                          Text(
                            'STEPS',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 6,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Bottom metric "8"
                    Positioned(
                      bottom: 18,
                      left: 46,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.bolt_rounded,
                            color: Color(0xFF1B9C73),
                            size: 12,
                          ),
                          const SizedBox(width: 1),
                          const Text(
                            '8',
                            style: TextStyle(
                              color: Color(0xFF1B9C73),
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Widget for the floating badges around the watch
class BadgeWidget extends StatelessWidget {
  final IconData icon;
  final bool isSolid;

  const BadgeWidget({
    super.key,
    required this.icon,
    required this.isSolid,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF1B9C73);
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: isSolid ? primaryColor : Colors.white,
        shape: BoxShape.circle,
        border: isSolid
            ? null
            : Border.all(
                color: const Color(0xFFD0EBE0),
                width: 1.5,
              ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(
        icon,
        color: isSolid ? Colors.white : primaryColor,
        size: 22,
      ),
    );
  }
}

// Pulse Line Painter for the Heart Logo
class PulseLinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final path = Path();
    path.moveTo(0, size.height / 2);
    path.lineTo(size.width * 0.28, size.height / 2);
    path.lineTo(size.width * 0.42, size.height * 0.1);
    path.lineTo(size.width * 0.58, size.height * 0.9);
    path.lineTo(size.width * 0.72, size.height / 2);
    path.lineTo(size.width, size.height / 2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// Background Painter with soft leaf vectors and soft wavy paths
class BackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Draw soft gradient background waves at the top left and bottom
    final wavePaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE8F5E9), Color(0x00FFFFFF)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.4));
      
    final path = Path();
    path.moveTo(0, 0);
    path.lineTo(size.width, 0);
    path.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.25,
      size.width * 0.3,
      size.height * 0.22,
    );
    path.quadraticBezierTo(
      size.width * 0.05,
      size.height * 0.2,
      0,
      size.height * 0.3,
    );
    path.close();
    canvas.drawPath(path, wavePaint);

    // 2. Draw another subtle wave from top right
    final wavePaintRight = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFFE8F8F5), Color(0x00FFFFFF)],
        begin: Alignment.topRight,
        end: Alignment.bottomLeft,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height * 0.3));

    final pathRight = Path();
    pathRight.moveTo(size.width, 0);
    pathRight.lineTo(size.width * 0.4, 0);
    pathRight.quadraticBezierTo(
      size.width * 0.6,
      size.height * 0.15,
      size.width,
      size.height * 0.25,
    );
    pathRight.close();
    canvas.drawPath(pathRight, wavePaintRight);

    // 3. Draw beautiful green leaves using Bezier paths
    // Leaf 1: Top Left leaf pointing inwards
    _drawLeaf(canvas, const Offset(30, 80), 35, math.pi / 6);
    _drawLeaf(canvas, const Offset(60, 40), 50, math.pi / 4);
    _drawLeaf(canvas, const Offset(110, 30), 25, math.pi / 3);

    // Leaf 2: Top Right leaf pointing down-left
    _drawLeaf(canvas, Offset(size.width - 40, 70), 55, -math.pi / 3);
    _drawLeaf(canvas, Offset(size.width - 80, 50), 30, -math.pi / 4);
    _drawLeaf(canvas, Offset(size.width - 120, 35), 45, -math.pi / 6);
  }

  void _drawLeaf(Canvas canvas, Offset stemOrigin, double length, double angle) {
    canvas.save();
    canvas.translate(stemOrigin.dx, stemOrigin.dy);
    canvas.rotate(angle);

    final leafPaint = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF81C784), Color(0xFF388E3C)],
        begin: Alignment.bottomLeft,
        end: Alignment.topRight,
      ).createShader(Rect.fromLTWH(0, -length / 4, length, length / 2))
      ..style = PaintingStyle.fill;

    final leafPath = Path();
    leafPath.moveTo(0, 0);
    // Draw upper blade
    leafPath.quadraticBezierTo(length * 0.35, -length * 0.3, length, 0);
    // Draw lower blade
    leafPath.quadraticBezierTo(length * 0.35, length * 0.3, 0, 0);
    leafPath.close();

    // Add a shadow to the leaf
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.06)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    canvas.drawPath(leafPath.shift(const Offset(1, 2)), shadowPaint);

    canvas.drawPath(leafPath, leafPaint);

    // Draw main vein
    final veinPaint = Paint()
      ..color = const Color(0xFFAED581).withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawLine(const Offset(0, 0), Offset(length * 0.95, 0), veinPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
