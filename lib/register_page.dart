import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:asawatch/controllers/sesi_makan_controller.dart';
import 'package:asawatch/konfigurasi.dart';
import 'package:asawatch/main.dart';
import 'package:asawatch/repositories/profil_repository.dart';
import 'package:asawatch/repositories/sesi_login_repository.dart';
import 'package:asawatch/services/auth_service.dart';
import 'package:asawatch/services/kamera_service.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({
    super.key,
    this.auth,
    this.kamera,
    this.sesiLogin,
    this.profil,
  });

  /// Sama seperti pada `LoginPage`: bawaannya auth sungguhan, dan sebuah
  /// permintaan HTTP di bawah `flutter_test` tidak gagal dengan jelas — ia
  /// menggantung sampai batas waktunya habis.
  final AuthService? auth;

  /// Diteruskan ke `MyHomePage` setelah mendaftar berhasil.
  final KameraService? kamera;

  /// Tempat bukti masuk disimpan. Pendaftaran yang berhasil **sudah membawa
  /// token** (§4), jadi orang baru tidak perlu mengetik ulang kredensialnya.
  final SesiLoginRepository? sesiLogin;

  /// Profil ditarik sekali sesudah akun jadi, sebelum shell dibuka.
  final ProfilRepository? profil;

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late final AuthService _auth = widget.auth ?? buatAuthBawaan();
  late final bool _authMilikSendiri = widget.auth == null;

  bool _sedangDaftar = false;

  /// Kegagalan terakhir, ditampilkan di atas tombol. Null berarti belum ada.
  HasilMasuk? _galat;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

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
      _hasLetterAndNumber =
          RegExp(r'[a-zA-Z]').hasMatch(value) &&
          RegExp(r'[0-9]').hasMatch(value);
    });
  }

  /// Mendaftar sungguhan ke server.
  ///
  /// Sebelum ini halaman ini hanya memvalidasi form lalu menampilkan
  /// "Pendaftaran berhasil! Silakan masuk." — kalimat yang tidak pernah benar,
  /// karena tidak ada satu pun permintaan yang dikirim dan akunnya tidak pernah
  /// ada. Orang yang mempercayainya akan menemukan kegagalan itu satu layar
  /// kemudian, saat mencoba masuk.
  Future<void> _daftar() async {
    if (_sedangDaftar) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _sedangDaftar = true;
      _galat = null;
    });

    final hasil = await _auth.daftar(
      nama: _nameController.text,
      email: _emailController.text,
      kataSandi: _passwordController.text,
    );

    // Permintaan bisa lebih lama daripada halamannya: pengguna boleh menekan
    // tombol kembali selagi menunggu.
    if (!mounted) return;

    if (hasil is MasukBerhasil) {
      // Persis alur masuk: token disimpan sebelum berpindah, profil ditarik
      // sebelum shell dibuka (kalau tidak, Beranda menyapa tanpa nama), dan
      // seluruh tumpukan dibuang supaya tombol kembali di Beranda keluar dari
      // aplikasi, bukan memunculkan lagi formulir pendaftaran.
      await widget.sesiLogin?.simpan(hasil.sesi);
      final sinkron = await widget.profil?.sinkronSetelahMasuk(
        hasil.sesi.email,
      );
      if (!mounted) return;
      final controller = context.read<SesiMakanController>();
      // Sama seperti alur masuk, dan justru lebih sering terjadi di sini: akun
      // yang baru dibuat pasti berbeda dari pemilik data sebelumnya, jadi
      // ponsel yang pernah dipakai orang lain akan mengunggah riwayat orang itu
      // ke akun yang baru lahir.
      final bersih = (sinkron?.gantiAkun ?? false)
          ? controller.hapusDataLokal()
          : Future<void>.value();
      unawaited(
        bersih
            .then((_) => controller.kirimRiwayatKeServer())
            .then((_) => controller.unduhRiwayatDariServer()),
      );

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => MyHomePage(
            title: 'AsaWatch',
            kamera: widget.kamera,
            auth: _auth,
            sesiLogin: widget.sesiLogin,
            profil: widget.profil,
          ),
        ),
        (rute) => false,
      );
      return;
    }

    setState(() {
      _sedangDaftar = false;
      _galat = hasil;
    });
  }

  @override
  void dispose() {
    if (_authMilikSendiri) _auth.dispose();
    _passwordController.removeListener(_validatePassword);
    _nameController.dispose();
    _emailController.dispose();
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
            child: CustomPaint(painter: RegisterBackgroundPainter()),
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
                        icon: const Icon(
                          Icons.arrow_back,
                          color: Color(0xFF1E3A34),
                        ),
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
                          hintStyle: const TextStyle(
                            color: Color(0xFF9CB1AC),
                            fontWeight: FontWeight.normal,
                          ),
                          prefixIcon: const Icon(
                            Icons.person_outline_rounded,
                            color: Color(0xFF6B807B),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF0EAD69),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2EBE8),
                              width: 1.5,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.5,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.5,
                            ),
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
                          if (!RegExp(
                            r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                          ).hasMatch(value.trim())) {
                            return 'Format email tidak valid';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Masukkan email',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9CB1AC),
                            fontWeight: FontWeight.normal,
                          ),
                          prefixIcon: const Icon(
                            Icons.email_outlined,
                            color: Color(0xFF6B807B),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF0EAD69),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2EBE8),
                              width: 1.5,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.5,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.5,
                            ),
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
                          if (!RegExp(r'[a-zA-Z]').hasMatch(value) ||
                              !RegExp(r'[0-9]').hasMatch(value)) {
                            return 'Kata sandi harus mengandung huruf dan angka';
                          }
                          return null;
                        },
                        decoration: InputDecoration(
                          hintText: 'Buat kata sandi',
                          hintStyle: const TextStyle(
                            color: Color(0xFF9CB1AC),
                            fontWeight: FontWeight.normal,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: Color(0xFF6B807B),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
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
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF0EAD69),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2EBE8),
                              width: 1.5,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.5,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Password requirement validation indicator
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            color:
                                (_isPasswordLengthValid && _hasLetterAndNumber)
                                ? const Color(0xFF0EAD69)
                                : const Color(0xFF9CB1AC),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Minimal 8 karakter dengan huruf dan angka',
                              style: TextStyle(
                                color:
                                    (_isPasswordLengthValid &&
                                        _hasLetterAndNumber)
                                    ? const Color(0xFF1E3A34)
                                    : const Color(0xFF6B807B),
                                fontSize: 12,
                                fontWeight:
                                    (_isPasswordLengthValid &&
                                        _hasLetterAndNumber)
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
                          hintStyle: const TextStyle(
                            color: Color(0xFF9CB1AC),
                            fontWeight: FontWeight.normal,
                          ),
                          prefixIcon: const Icon(
                            Icons.lock_outline_rounded,
                            color: Color(0xFF6B807B),
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscureConfirmPassword
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                              color: const Color(0xFF6B807B),
                            ),
                            onPressed: () {
                              setState(() {
                                _obscureConfirmPassword =
                                    !_obscureConfirmPassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFF0EAD69),
                              width: 1.5,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Color(0xFFE2EBE8),
                              width: 1.5,
                            ),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.5,
                            ),
                          ),
                          focusedErrorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Kegagalan pendaftaran, satu kalimat di atas tombol.
                      //
                      // Bukan SnackBar: kalimatnya menerangkan apa yang harus
                      // diubah pada formulir yang sedang dipandang, dan sebuah
                      // toast yang hilang sendiri setelah beberapa detik
                      // meninggalkan orang dengan formulir yang sama tanpa
                      // petunjuk apa pun.
                      if (_galat != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFDECEA),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFFF5C6C2)),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 18,
                                color: Colors.redAccent,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _galat!.pesan,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF1E3A34),
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Daftar Button
                      SizedBox(
                        width: double.infinity,
                        height: 54,
                        child: ElevatedButton(
                          // Dikunci selama permintaan berjalan. Dua permintaan
                          // yang berjalan bersamaan terlihat persis sama dengan
                          // satu di layar, dan yang kedua akan ditolak sebagai
                          // email yang sudah terdaftar — oleh pendaftaran
                          // pertama milik orang itu sendiri.
                          onPressed: _sedangDaftar ? null : _daftar,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0EAD69),
                            foregroundColor: Colors.white,
                            disabledBackgroundColor: const Color(0xFF9CB1AC),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(28),
                            ),
                            elevation: 0,
                          ),
                          child: _sedangDaftar
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.4,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text(
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
                            style: TextStyle(
                              color: Color(0xFF6B807B),
                              fontSize: 14,
                            ),
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
      ..quadraticBezierTo(
        size.width * 0.4,
        size.height * 0.12,
        size.width * 0.15,
        size.height * 0.1,
      )
      ..quadraticBezierTo(
        size.width * 0.05,
        size.height * 0.09,
        0,
        size.height * 0.16,
      )
      ..close();
    canvas.drawPath(topPath, topWavePaint);

    // 2. Leafy background curve at the bottom-right corner matching login page style
    final paint = Paint()..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(size.width, size.height)
      ..lineTo(size.width * 0.6, size.height)
      ..cubicTo(
        size.width * 0.65,
        size.height * 0.95,
        size.width * 0.75,
        size.height * 0.9,
        size.width * 0.85,
        size.height * 0.92,
      )
      ..cubicTo(
        size.width * 0.92,
        size.height * 0.94,
        size.width * 0.95,
        size.height * 0.88,
        size.width,
        size.height * 0.82,
      )
      ..close();

    paint.shader =
        LinearGradient(
          colors: [
            const Color(0xFF8AE8CD).withValues(alpha: 0.3),
            const Color(0xFFD6F5EC).withValues(alpha: 0.05),
          ],
          begin: Alignment.bottomRight,
          end: Alignment.topLeft,
        ).createShader(
          Rect.fromLTWH(
            size.width * 0.6,
            size.height * 0.8,
            size.width * 0.4,
            size.height * 0.2,
          ),
        );

    canvas.drawPath(path, paint);

    // Decorative tiny green leaf shapes at the bottom right corner
    _drawLeaf(canvas, size.width - 20, size.height - 40, -20, 20, paint);
    _drawLeaf(canvas, size.width - 45, size.height - 18, -55, 16, paint);
  }

  void _drawLeaf(
    Canvas canvas,
    double cx,
    double cy,
    double rotationDegrees,
    double size,
    Paint paint,
  ) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(rotationDegrees * 3.14159 / 180);

    final path = Path();
    path.moveTo(0, 0);
    path.quadraticBezierTo(size * 0.5, -size * 0.8, size, -size);
    path.quadraticBezierTo(size * 0.8, -size * 0.2, 0, 0);

    paint.shader = const LinearGradient(
      colors: [Color(0xFF55CCAA), Color(0xFF7DE6C7)],
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
    ).createShader(Rect.fromLTWH(0, -size, size, size));

    canvas.drawPath(path, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
