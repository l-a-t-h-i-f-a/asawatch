import 'package:flutter/material.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreeToTerms = false;

  // Validation states
  bool _isPasswordLengthValid = false;
  bool _hasLetterAndNumber = false;

  @override
  void initState() {
    super.initState();
    _passwordController.addListener(_validatePassword);
  }

  void _validatePassword() {
    final value = _passwordController.text;
    setState(() {
      _isPasswordLengthValid = value.length >= 8;
      _hasLetterAndNumber = RegExp(r'[a-zA-Z]').hasMatch(value) && RegExp(r'[0-9]').hasMatch(value);
    });
  }

  @override
  void dispose() {
    _passwordController.removeListener(_validatePassword);
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      body: Stack(
        children: [
          // Leafy curves background at the bottom-right corner matching login's custom painter style but flipped
          Positioned.fill(
            child: CustomPaint(
              painter: RegisterBackgroundPainter(),
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
                      const SizedBox(height: 24),

                      // Title
                      const Center(
                        child: Text(
                          'Buat Akun Baru',
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
                          'Lengkapi data di bawah untuk\nmembuat akun baru',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF6B807B),
                            height: 1.4,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Nama Lengkap Label
                      const Text(
                        'Nama Lengkap',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A34),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Nama Lengkap field
                      TextFormField(
                        controller: _nameController,
                        style: const TextStyle(color: Color(0xFF1E3A34)),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Masukkan nama lengkap';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Masukkan nama lengkap',
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

                      // Email Label
                      const Text(
                        'Email',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A34),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Email field
                      TextFormField(
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                        style: const TextStyle(color: Color(0xFF1E3A34)),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Masukkan email';
                          }
                          if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value.trim())) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Masukkan email',
                          hintStyle: const TextStyle(color: Color(0xFF9CB1AC), fontWeight: FontWeight.normal),
                          prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF6B807B)),
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

                      // Nomor HP Label
                      const Text(
                        'Nomor HP',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A34),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Nomor HP field
                      TextFormField(
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        style: const TextStyle(color: Color(0xFF1E3A34)),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Masukkan nomor HP';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Masukkan nomor HP',
                          hintStyle: const TextStyle(color: Color(0xFF9CB1AC), fontWeight: FontWeight.normal),
                          prefixIcon: const Icon(Icons.phone_outlined, color: Color(0xFF6B807B)),
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

                      // Kata Sandi Label
                      const Text(
                        'Kata Sandi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A34),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Kata Sandi field
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(color: Color(0xFF1E3A34)),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Masukkan kata sandi';
                          }
                          if (value.length < 8) {
                            return 'Kata sandi minimal 8 karakter';
                          }
                          if (!RegExp(r'[a-zA-Z]').hasMatch(value) || !RegExp(r'[0-9]').hasMatch(value)) {
                            return 'Kata sandi harus mengandung huruf dan angka';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Buat kata sandi',
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
                      const SizedBox(height: 8),

                      // Password requirement validation indicator
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color: (_isPasswordLengthValid && _hasLetterAndNumber)
                                ? const Color(0xFF0EAD69)
                                : const Color(0xFF9CB1AC),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Minimal 8 karakter dengan huruf dan angka',
                              style: TextStyle(
                                color: (_isPasswordLengthValid && _hasLetterAndNumber)
                                    ? const Color(0xFF1E3A34)
                                    : const Color(0xFF6B807B),
                                fontSize: 12,
                                fontWeight: (_isPasswordLengthValid && _hasLetterAndNumber)
                                    ? FontWeight.w500
                                    : FontWeight.normal,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Konfirmasi Kata Sandi Label
                      const Text(
                        'Konfirmasi Kata Sandi',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A34),
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Konfirmasi Kata Sandi field
                      TextFormField(
                        controller: _confirmPasswordController,
                        obscureText: _obscureConfirmPassword,
                        style: const TextStyle(color: Color(0xFF1E3A34)),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Ulangi kata sandi';
                          }
                          if (value != _passwordController.text) {
                            return 'Kata sandi tidak sama';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Ulangi kata sandi',
                          hintStyle: const TextStyle(color: Color(0xFF9CB1AC), fontWeight: FontWeight.normal),
                          prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF6B807B)),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                              color: const Color(0xFF6B807B),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword = !_obscureConfirmPassword;
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
                      const SizedBox(height: 20),

                      // Terms and conditions checkbox
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 24,
                            height: 24,
                            child: Checkbox(
                              value: _agreeToTerms,
                              activeColor: const Color(0xFF0EAD69),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                              side: const BorderSide(color: Color(0xFFD4E2DE), width: 1.5),
                              onChanged: (val) {
                                setState(() {
                                  _agreeToTerms = val ?? false;
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: RichText(
                              text: const TextSpan(
                                text: 'Saya setuju dengan ',
                                style: TextStyle(
                                  color: Color(0xFF6B807B),
                                  fontSize: 13,
                                  height: 1.4,
                                ),
                                children: [
                                  TextSpan(
                                    text: 'Syarat & Ketentuan',
                                    style: TextStyle(
                                      color: Color(0xFF0EAD69),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  TextSpan(text: ' and '),
                                  TextSpan(
                                    text: 'Kebijakan Privasi',
                                    style: TextStyle(
                                      color: Color(0xFF0EAD69),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),

                      // Daftar Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          onPressed: () {
                            if (_formKey.currentState!.validate()) {
                              if (_agreeToTerms) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Pendaftaran berhasil! Silakan masuk.'),
                                    backgroundColor: Color(0xFF0EAD69),
                                  ),
                                );
                                Navigator.pop(context);
                              } else {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Anda harus menyetujui Syarat & Ketentuan terlebih dahulu.'),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              }
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
                            'Daftar',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Redirection to Login
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'Sudah punya akun? ',
                            style: TextStyle(color: Color(0xFF6B807B), fontSize: 14),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                            },
                            child: const Text(
                              'Masuk di sini',
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
}

class RegisterBackgroundPainter extends CustomPainter {
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

    // 2. Leafy background curve at the bottom-right corner matching login page style
    final paint = Paint()..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(size.width * 0.6, size.height)
      ..cubicTo(size.width * 0.65, size.height * 0.95, size.width * 0.75, size.height * 0.9, size.width * 0.85, size.height * 0.92)
      ..cubicTo(size.width * 0.92, size.height * 0.94, size.width * 0.95, size.height * 0.88, size.width, size.height * 0.82)
      ..close();

    paint.shader = LinearGradient(
      colors: [
        const Color(0xFF8AE8CD).withValues(alpha: 0.3),
        const Color(0xFFD6F5EC).withValues(alpha: 0.05),
      ],
      begin: Alignment.bottomRight,
      end: Alignment.topLeft,
    ).createShader(Rect.fromLTWH(size.width * 0.6, size.height * 0.8, size.width * 0.4, size.height * 0.2));

    canvas.drawPath(path, paint);

    // Decorative tiny green leaf shapes at the bottom right corner
    _drawLeaf(canvas, size.width - 20, size.height - 40, -20, 20, paint);
    _drawLeaf(canvas, size.width - 45, size.height - 18, -55, 16, paint);
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
