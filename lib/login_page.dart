import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:asawatch/controllers/sesi_makan_controller.dart';
import 'package:asawatch/register_page.dart';
import 'package:asawatch/konfigurasi.dart';
import 'package:asawatch/services/auth_service.dart';
import 'package:asawatch/repositories/profil_repository.dart';
import 'package:asawatch/repositories/sesi_login_repository.dart';
import 'package:asawatch/services/kamera_service.dart';
import 'package:asawatch/main.dart'; // To navigate to MyHomePage

class LoginPage extends StatefulWidget {
  const LoginPage({
    super.key,
    this.auth,
    this.kamera,
    this.sesiLogin,
    this.profil,
  });

  /// Auth yang dipakai halaman ini. null berarti rakit yang bawaan.
  ///
  /// Pola yang sama dengan `izin:` pada `PemindaianPerangkatPage`: bawaannya
  /// adalah yang sungguhan, dan test menyuntikkan [FakeAuthService] karena
  /// `flutter_test` tidak punya jaringan — sebuah permintaan HTTP di dalam test
  /// tidak gagal dengan jelas, ia hanya menggantung sampai batas waktu.
  final AuthService? auth;

  /// Hanya diteruskan ke `MyHomePage` — lihat `MyApp.kamera`.
  final KameraService? kamera;

  /// Tempat bukti masuk disimpan setelah berhasil — lihat `MyApp.sesiLogin`.
  final SesiLoginRepository? sesiLogin;

  /// Profil ditarik sekali di sini, sebelum shell dibuka — lihat
  /// `MyApp.profil`.
  final ProfilRepository? profil;

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  late final AuthService _auth = widget.auth ?? buatAuthBawaan();

  /// Auth yang dirakit sendiri harus dibuang sendiri; yang disuntikkan milik
  /// pemanggil — membuangnya di sini akan mematikan tiruan yang masih dipakai
  /// test berikutnya.
  late final bool _authMilikSendiri = widget.auth == null;

  /// Sedang menunggu jawaban. Mengunci tombol, karena dua permintaan masuk yang
  /// berjalan bersamaan menghasilkan dua token dan satu di antaranya langsung
  /// yatim.
  bool _sedangMasuk = false;

  /// Kegagalan terakhir yang masih ditampilkan, null bila belum ada.
  ///
  /// Disimpan sebagai [HasilMasuk] utuh, bukan sebagai String, supaya halaman
  /// ini tidak ikut memutuskan kalimatnya — dan supaya "boleh diulang atau
  /// tidak" datang dari kontraknya, bukan dari tebakan di sini.
  HasilMasuk? _galat;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    if (_authMilikSendiri) _auth.dispose();
    super.dispose();
  }

  Future<void> _masuk() async {
    if (_sedangMasuk) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _sedangMasuk = true;
      _galat = null;
    });

    final hasil = await _auth.masuk(
      identifier: _identifierController.text,
      kataSandi: _passwordController.text,
    );

    // Permintaan bisa lebih lama daripada halamannya: pengguna boleh menekan
    // tombol kembali selagi menunggu.
    if (!mounted) return;

    if (hasil is MasukBerhasil) {
      // Disimpan **sebelum** berpindah halaman: aplikasi yang ditutup tepat
      // setelah masuk harus tetap ditemukan dalam keadaan masuk.
      await widget.sesiLogin?.simpan(hasil.sesi);

      // Ditarik **sebelum** shell dibuka, bukan sesudah. Beranda memuat namanya
      // saat itu juga, dan pada pemasangan baru salinan lokalnya masih kosong —
      // tanpa ini pengguna disambut "Halo" tanpa nama dan Profil tampak belum
      // diisi, padahal akunnya punya semua data itu. Kegagalannya tidak
      // menghalangi: `muatSegar` mengembalikan salinan lokal apa adanya saat
      // tanpa jaringan.
      final sinkron = await widget.profil?.sinkronSetelahMasuk(
        hasil.sesi.email,
      );
      if (!mounted) return;

      // Riwayat yang terkumpul sebelum masuk ikut naik sekarang — sebelum ini
      // tidak ada token, jadi tidak ada satu pun sesi yang bisa dikirim.
      final controller = context.read<SesiMakanController>();

      // **Ponsel ini milik orang lain sebelumnya: buang dulu, baru kirim.**
      // Urutannya menentukan, dan membaliknya bukan sekadar tampilan yang
      // janggal — riwayat sesi pemilik sebelumnya akan terunggah ke akun yang
      // baru saja masuk, dan di server ia tidak bisa dibedakan lagi dari sesi
      // milik pemiliknya sendiri.
      final bersih = (sinkron?.gantiAkun ?? false)
          ? controller.hapusDataLokal()
          : Future<void>.value();
      unawaited(
        bersih
            .then((_) => controller.kirimRiwayatKeServer())
            .then((_) => controller.unduhRiwayatDariServer()),
      );

      // `pushAndRemoveUntil`, bukan `pushReplacement`: yang diganti hanya
      // halaman login, sedangkan halaman sambutan tetap tertinggal di bawahnya.
      // Akibatnya tombol kembali di Beranda memunculkan lagi layar sambutan —
      // yang dibaca pengguna sebagai keluar dari akun, padahal ia masih masuk.
      // Dengan tumpukan dikosongkan, kembali di Beranda berarti keluar dari
      // aplikasi, sama seperti aplikasi lain.
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
      _sedangMasuk = false;
      _galat = hasil;
    });
  }

  /// Menghapus pesan galat begitu isian disentuh.
  ///
  /// Terutama demi [KredensialSalah]: pesan yang menyuruh "periksa kembali"
  /// tetapi bertahan di layar selagi pengguna memperbaiki ketikannya terbaca
  /// seolah perbaikannya pun ditolak.
  void _bersihkanGalat() {
    if (_galat != null) setState(() => _galat = null);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      body: Stack(
        children: [
          // Custom Leafy Background Painter
          Positioned.fill(
            child: CustomPaint(painter: LoginBackgroundPainter()),
          ),
          SafeArea(
            // Sejak tombol masuk pihak ketiga hilang, isi halaman lebih pendek
            // dari layar. `minHeight` + `IntrinsicHeight` membuat kolomnya
            // setinggi layar supaya `Spacer` di bawah punya sisa ruang untuk
            // dibagi — tanpa itu kolom hanya setinggi isinya dan `Spacer`
            // tidak berarti apa-apa. Halaman tetap bisa digulir waktu papan
            // ketik naik atau kartu galat muncul.
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
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
                                      color: Colors.black.withValues(
                                        alpha: 0.04,
                                      ),
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
                              'Email',
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
                              enabled: !_sedangMasuk,
                              onChanged: (_) => _bersihkanGalat(),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Masukkan email';
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
                              enabled: !_sedangMasuk,
                              onChanged: (_) => _bersihkanGalat(),
                              onFieldSubmitted: (_) => _masuk(),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Masukkan kata sandi';
                                }
                                return null;
                              },
                              decoration: InputDecoration(
                                hintText: 'Masukkan kata sandi',
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
                            const SizedBox(height: 12),

                            // Forgot password
                            Align(
                              alignment: Alignment.centerRight,
                              child: GestureDetector(
                                onTap: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Fitur Lupa kata sandi belum tersedia.',
                                      ),
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
                            const SizedBox(height: 24),

                            // Pesan kegagalan — di atas tombol, bukan SnackBar.
                            // Kegagalan masuk menuntut pengguna mengubah sesuatu di
                            // formulir ini, dan toast yang hilang sendiri setelah
                            // empat detik meninggalkannya tanpa petunjuk apa pun.
                            if (_galat case final galat?) _buildGalat(galat),

                            // Masuk Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                // null saat menunggu: menonaktifkan tombolnya, bukan
                                // sekadar mengabaikan ketukan, supaya keadaan "sedang
                                // bekerja" terlihat dan bukan hanya diketahui.
                                onPressed: _sedangMasuk ? null : _masuk,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF0EAD69),
                                  foregroundColor: Colors.white,
                                  disabledBackgroundColor: const Color(
                                    0xFF0EAD69,
                                  ),
                                  disabledForegroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28),
                                  ),
                                  elevation: 0,
                                ),
                                child: _sedangMasuk
                                    ? const SizedBox(
                                        width: 22,
                                        height: 22,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation(
                                            Colors.white,
                                          ),
                                        ),
                                      )
                                    : const Text(
                                        'Masuk',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                              ),
                            ),
                            const SizedBox(height: 32),
                            // Sisa ruang layar jatuh ke sini, jadi tautan daftar
                            // duduk di dasar halaman alih-alih menggantung di
                            // tengah. Tinggi minimumnya 0, sehingga di layar pendek
                            // susunannya kembali seperti semula dan halaman digulir.
                            const Spacer(),

                            // Sign-up link
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Belum punya akun? ',
                                  style: TextStyle(
                                    color: Color(0xFF6B807B),
                                    fontSize: 14,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) => RegisterPage(
                                          auth: widget.auth,
                                          kamera: widget.kamera,
                                          sesiLogin: widget.sesiLogin,
                                          profil: widget.profil,
                                        ),
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
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Kartu penjelasan kegagalan.
  ///
  /// Kalimatnya datang dari `PesanHasilMasuk.pesan`, dan ada-tidaknya tombol
  /// "Coba Lagi" dari `bisaDiulang` — keduanya milik kontrak, bukan halaman
  /// ini. `KredensialSalah` sengaja tidak mendapat tombol itu: mengulang
  /// permintaan yang sama persis pasti gagal lagi, dan menawarkannya
  /// menyiratkan bahwa yang diketik pengguna sudah benar.
  Widget _buildGalat(HasilMasuk galat) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 20,
            color: Colors.redAccent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  galat.pesan,
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFF1E3A34),
                  ),
                ),
                if (galat.bisaDiulang) ...[
                  const SizedBox(height: 6),
                  GestureDetector(
                    onTap: _masuk,
                    child: const Text(
                      'Coba Lagi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0EAD69),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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

    // 2. Organic leafy curve at the bottom left corner matching the mockups
    final paint = Paint()..style = PaintingStyle.fill;
    final path = Path()
      ..moveTo(0, size.height)
      ..lineTo(size.width * 0.4, size.height)
      ..cubicTo(
        size.width * 0.35,
        size.height * 0.95,
        size.width * 0.25,
        size.height * 0.9,
        size.width * 0.15,
        size.height * 0.92,
      )
      ..cubicTo(
        size.width * 0.08,
        size.height * 0.94,
        size.width * 0.05,
        size.height * 0.88,
        0,
        size.height * 0.82,
      )
      ..close();

    paint.shader =
        LinearGradient(
          colors: [
            const Color(0xFF8AE8CD).withValues(alpha: 0.3),
            const Color(0xFFD6F5EC).withValues(alpha: 0.05),
          ],
          begin: Alignment.bottomLeft,
          end: Alignment.topRight,
        ).createShader(
          Rect.fromLTWH(
            0,
            size.height * 0.8,
            size.width * 0.4,
            size.height * 0.2,
          ),
        );

    canvas.drawPath(path, paint);

    // Decorative tiny green leaf shapes at the bottom left corner
    _drawLeaf(canvas, 20, size.height - 40, 20, 20, paint);
    _drawLeaf(canvas, 45, size.height - 18, 55, 16, paint);
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
