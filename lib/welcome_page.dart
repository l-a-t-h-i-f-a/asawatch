import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'dart:math' as math;
import 'login_page.dart';
import 'register_page.dart';
import 'services/auth_service.dart';
import 'repositories/profil_repository.dart';
import 'repositories/sesi_login_repository.dart';
import 'services/kamera_service.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({
    super.key,
    this.auth,
    this.kamera,
    this.sesiLogin,
    this.profil,
  });

  /// Diteruskan apa adanya ke [LoginPage] — halaman ini tidak memakainya
  /// sendiri. Pola yang sama dengan `MenghubungkanPerangkatPage` yang menerima
  /// `izin:` semata-mata untuk meneruskannya.
  final AuthService? auth;

  /// Hanya diteruskan — lihat `MyApp.kamera`.
  final KameraService? kamera;

  /// Hanya diteruskan ke `LoginPage` — lihat `MyApp.sesiLogin`.
  final SesiLoginRepository? sesiLogin;

  /// Hanya diteruskan ke `LoginPage` — lihat `MyApp.profil`.
  final ProfilRepository? profil;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFA),
      body: Stack(
        children: [
          // Background soft waves and leaves
          Positioned.fill(child: CustomPaint(painter: BackgroundPainter())),

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

                          // 2. Jam pada logo AsaWatch, menggantikan mockup
                          //    jam yang dulu digambar tangan.
                          const JamLogo(),

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
                        // Wordmark: AsaWatch
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
                                text: 'Asa',
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
                      ],
                    ),
                  ),
                ),

                // Actions Area
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24.0,
                    vertical: 20.0,
                  ),
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
                                builder: (context) => RegisterPage(
                                  auth: auth,
                                  kamera: kamera,
                                  sesiLogin: sesiLogin,
                                  profil: profil,
                                ),
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
                                builder: (context) => LoginPage(
                                  auth: auth,
                                  kamera: kamera,
                                  sesiLogin: sesiLogin,
                                  profil: profil,
                                ),
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

/// Bagian jam dari logo AsaWatch.
///
/// Berkas logonya adalah kunci lengkap — jam, tulisan "ASAWatch", dan tagline —
/// sedangkan halaman ini sudah menuliskan keduanya sendiri tepat di bawah
/// ilustrasi. Karena itu yang diambil hanya jamnya, lewat `Align` dengan
/// `widthFactor`/`heightFactor` (memotong, bukan mengecilkan), supaya tulisan
/// yang sama tidak muncul dua kali dalam satu layar.
class JamLogo extends StatelessWidget {
  const JamLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return const _Perkalian(
      child: ClipRect(
        child: Align(
          alignment: Alignment(0, -0.85),
          widthFactor: 0.30,
          heightFactor: 0.62,
          child: Image(
            image: ResizeImage(
              // Berkasnya 2816x1536 sementara yang tampil kurang dari 200 px:
              // tanpa diperkecil saat dibaca, seluruh bitmap mentahnya ikut
              // dipegang di memori.
              AssetImage('assets/logo/logo2.jpeg'),
              width: 620,
            ),
            width: 620,
          ),
        ),
      ),
    );
  }
}

/// Menggambar anaknya dengan `BlendMode.multiply` terhadap apa yang sudah ada
/// di belakangnya.
///
/// Logonya JPEG, jadi latarnya putih pekat dan tidak punya alfa. Digambar apa
/// adanya ia menjadi kotak putih yang memotong riak elips di belakang jam.
/// Perkalian membuat putih itu lenyap — putih x latar = latar — sementara warna
/// jamnya sendiri hampir tidak berubah di atas latar yang memang nyaris putih.
class _Perkalian extends SingleChildRenderObjectWidget {
  const _Perkalian({required Widget super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderPerkalian();
}

class _RenderPerkalian extends RenderProxyBox {
  @override
  void paint(PaintingContext context, Offset offset) {
    context.canvas.saveLayer(
      offset & size,
      Paint()..blendMode = BlendMode.multiply,
    );
    super.paint(context, offset);
    context.canvas.restore();
  }
}

// Widget for the floating badges around the watch
class BadgeWidget extends StatelessWidget {
  final IconData icon;
  final bool isSolid;

  const BadgeWidget({super.key, required this.icon, required this.isSolid});

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
            : Border.all(color: const Color(0xFFD0EBE0), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: isSolid ? Colors.white : primaryColor, size: 22),
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

  void _drawLeaf(
    Canvas canvas,
    Offset stemOrigin,
    double length,
    double angle,
  ) {
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
