import 'package:flutter/material.dart';
import 'package:asawatch/register_page.dart';
import 'package:asawatch/main.dart'; // To navigate to MyHomePage

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      body: Stack(
        children: [
          // Custom Leafy Background Painter
          Positioned.fill(
            child: CustomPaint(
              painter: LoginBackgroundPainter(),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      // Back Button
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A34)),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(height: 20),

                      // Heartbeat Logo in Card with pulse line
                      Center(
                        child: Container(
                          width: 84,
                          height: 84,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 16,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              const Icon(
                                Icons.favorite_rounded,
                                size: 50,
                                color: Color(0xFF0EAD69),
                              ),
                              CustomPaint(
                                size: const Size(28, 15),
                                painter: PulseLinePainter(),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Welcome title
                      const Center(
                        child: Text(
                          'Selamat Datang Kembali!',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A34),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtitle
                      const Center(
                        child: Text(
                          'Masuk untuk melanjutkan\nperjalanan sehatmu',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B807B),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Identifier Label
                      const Text(
                        'Email atau Nomor HP',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A34),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Identifier Input field
                      TextFormField(
                        controller: _identifierController,
                        style: const TextStyle(color: Color(0xFF1E3A34)),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Masukkan email atau nomor HP';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Masukkan email atau nomor HP',
                          hintStyle: const TextStyle(color: Color(0xFF9CB1AC), fontWeight: FontWeight.normal),
                          prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF6B807B)),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF0EAD69), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2EBE8), width: 1.5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Password Label
                      const Text(
                        'Kata Sandi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A34),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Password Input field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Color(0xFF1E3A34)),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Masukkan kata sandi';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Masukkan kata sandi',
                          hintStyle: const TextStyle(color: Color(0xFF9CB1AC), fontWeight: FontWeight.normal),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6B807B)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF6B807B),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFF0EAD69), width: 1.5),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Color(0xFFE2EBE8), width: 1.5),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Forgot password
                      Align(
                        alignment: Alignment.centerRight,
                        child: GestureDetector(
                          onTap: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Fitur Lupa kata sandi belum tersedia.'),
                                backgroundColor: Color(0xFF0EAD69),
                              ),
                            );
                          },
                          child: const Text(
                            'Lupa kata sandi?',
                            style: TextStyle(
                              color: Color(0xFF0EAD69),
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Masuk Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const MyHomePage(title: 'HealthWatch Home'),
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0EAD69),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          child: const Text(
                            'Masuk',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Divider 'atau masuk dengan'
                      Row(
                        children: [
                          const Expanded(child: Divider(color: Color(0xFFD4E2DE), thickness: 1)),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16.0),
                            child: Text(
                              'atau masuk dengan',
                              style: TextStyle(
                                color: const Color(0xFF6B807B).withValues(alpha: 0.8),
                                fontSize: 13,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider(color: Color(0xFFD4E2DE), thickness: 1)),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Social Login Icons (Google, Apple, Phone)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildSocialButton(
                            child: CustomPaint(
                              size: const Size(24, 24),
                              painter: GoogleLogoPainter(),
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Masuk dengan Google belum tersedia.')),
                              );
                            },
                          ),
                          const SizedBox(width: 20),
                          _buildSocialButton(
                            child: const Icon(
                              Icons.apple,
                              size: 28,
                              color: Colors.black,
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Masuk dengan Apple belum tersedia.')),
                              );
                            },
                          ),
                          const SizedBox(width: 20),
                          _buildSocialButton(
                            child: const Icon(
                              Icons.phone_rounded,
                              size: 24,
                              color: Color(0xFF0EAD69),
                            ),
                            onTap: () {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Masuk dengan Nomor HP belum tersedia.')),
                              );
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Sign-up link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Belum punya akun? ',
                            style: TextStyle(color: Color(0xFF6B807B), fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => const RegisterPage(),
                                ),
                              );
                            },
                            child: const Text(
                              'Daftar sekarang',
                              style: TextStyle(
                                color: Color(0xFF0EAD69),
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialButton({required Widget child, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 54,
        height: 54,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(child: child),
      ),
    );
  }
}

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

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double w = size.width;
    final double h = size.height;
    final double r = w / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.24
      ..strokeCap = StrokeCap.square;

    final center = Offset(w / 2, h / 2);
    final rect = Rect.fromCircle(center: center, radius: r - paint.strokeWidth / 2);

    // Red: Top segment
    paint.color = const Color(0xFFEA4335);
    canvas.drawArc(rect, -2.356, 1.571, false, paint);

    // Yellow: Left segment
    paint.color = const Color(0xFFFBBC05);
    canvas.drawArc(rect, -3.927, 1.571, false, paint);

    // Green: Bottom segment
    paint.color = const Color(0xFF34A853);
    canvas.drawArc(rect, 0.785, 1.571, false, paint);

    // Blue: Right segment
    paint.color = const Color(0xFF4285F4);
    canvas.drawArc(rect, -0.785, 1.25, false, paint);

    // Horizontal bar
    final barPaint = Paint()
      ..color = const Color(0xFF4285F4)
      ..style = PaintingStyle.fill;
    
    final barHeight = paint.strokeWidth;
    canvas.drawRect(
      Rect.fromLTWH(
        center.dx,
        center.dy - barHeight / 2,
        r,
        barHeight,
      ),
      barPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoginBackgroundPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // 1. Top-left soft gradient wave
    final topWavePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF8AE8CD).withValues(alpha: 0.25),
          const Color(0xFFF4FAF7).withValues(alpha: 0.0),
        ],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromLTWH(0, 0, size.width * 0.6, size.height * 0.25));

    final topPath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.6, 0)
      ..quadraticBezierTo(size.width * 0.4, size.height * 0.12, size.width * 0.15, size.height * 0.1)
      ..quadraticBezierTo(size.width * 0.05, size.height * 0.09, 0, size.height * 0.16)
      ..close();
    canvas.drawPath(topPath, topWavePaint);

    // 2. Organic leafy curve at the bottom left corner matching the mockups
    final paint = Paint()..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.4, size.height)
      ..cubicTo(size.width * 0.35, size.height * 0.95, size.width * 0.25, size.height * 0.9, size.width * 0.15, size.height * 0.92)
      ..cubicTo(size.width * 0.08, size.height * 0.94, size.width * 0.05, size.height * 0.88, 0, size.height * 0.82)
      ..close();

    paint.shader = LinearGradient(
      colors: [
        const Color(0xFF8AE8CD).withValues(alpha: 0.3),
        const Color(0xFFD6F5EC).withValues(alpha: 0.05),
      ],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
    ).createShader(Rect.fromLTWH(0, size.height * 0.8, size.width * 0.4, size.height * 0.2));

    canvas.drawPath(path, paint);

    // Decorative tiny green leaf shapes at the bottom left corner
    _drawLeaf(canvas, 20, size.height - 40, 20, 20, paint);
    _drawLeaf(canvas, 45, size.height - 18, 55, 16, paint);
  }

  void _drawLeaf(Canvas canvas, double cx, double cy, double rotationDegrees, double size, Paint paint) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotationDegrees * 3.14159 / 180);
    
    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size * 0.5, -size * 0.8, size, -size);
    path.quadraticBezierTo(size * 0.8, -size * 0.2, 0, 0);
    
    paint.shader = const LinearGradient(
      colors: [
        Color(0xFF55CCAA),
        Color(0xFF7DE6C7),
      ],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
    ).createShader(Rect.fromLTWH(0, -size, size, size));
    
    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
