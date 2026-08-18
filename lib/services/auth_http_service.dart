/// Implementasi [AuthService] di atas HTTP.
///
/// Seluruh isinya adalah satu penerjemahan: permintaan Dart menjadi byte, lalu
/// jawaban server menjadi [HasilMasuk]. Tidak ada keputusan tampilan di sini,
/// dan tidak ada pula pengetahuan tentang layar mana yang memanggilnya.
///
/// **[klien] disuntikkan lewat konstruktor, bukan dipanggil sebagai
/// `http.post()`.** Itu satu-satunya alasan berkas ini bisa diuji tanpa server:
/// `MockClient` dari `package:http/testing.dart` menggantikan soketnya saja,
/// sehingga penyusunan URL, header, encoding body, pembacaan JSON, dan
/// pemetaan kode status yang dijalankan test adalah yang sungguhan — bukan
/// tiruannya. Memanggil fungsi tingkat-atas `http.post()` akan menghapus seam
/// itu dan menyisakan satu-satunya cara menguji: sebuah server yang menyala.
///
/// Yang tetap **tidak** bisa dibuktikan di sini, dan hanya bisa dibuktikan
/// sekali dengan server sungguhan: bahwa Android mengizinkan koneksinya
/// (cleartext HTTP diblokir sejak Android 9), bahwa TLS-nya sah, dan bahwa
/// bentuk JSON yang diasumsikan di bawah memang bentuk yang dikirim server.
/// Test hanya membuktikan kode ini benar terhadap JSON yang ditulis test itu
/// sendiri — ia mengabadikan asumsinya, tidak memvalidasinya.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import 'auth_service.dart';

class AuthHttpService implements AuthService {
  AuthHttpService({required this.basisUrl, http.Client? klien})
    : _klien = klien ?? http.Client(),
      _klienMilikSendiri = klien == null;

  /// Akar alamat API, tanpa garis miring di ujung — mis.
  /// `https://api.asawatch.id`. Diambil dari `konfigurasi.dart` agar alamat
  /// pengembangan tidak pernah ikut terbawa ke rakitan rilis.
  final String basisUrl;

  final http.Client _klien;

  /// Klien yang dibuat sendiri harus ditutup sendiri; klien yang disuntikkan
  /// milik pemanggil, dan menutupnya di sini akan mematikan `MockClient` yang
  /// mungkin masih dipakai test berikutnya.
  final bool _klienMilikSendiri;

  @override
  Future<HasilMasuk> masuk({
    required String identifier,
    required String kataSandi,
  }) async {
    try {
      final jawaban = await _klien
          .post(
            Uri.parse('$basisUrl/auth/login'),
            headers: const {
              'content-type': 'application/json; charset=utf-8',
              'accept': 'application/json',
            },
            // Sandi hanya pernah ada di badan permintaan. Menaruhnya di query
            // string akan menuliskannya ke log akses server dan riwayat proxy.
            body: jsonEncode({
              'identifier': identifier.trim(),
              'password': kataSandi,
            }),
          )
          .timeout(AuthService.batasWaktu);

      return _baca(jawaban);
    } on TimeoutException {
      return const WaktuHabis();
    } on SocketException {
      // Nama host tidak terpecahkan, rute tidak ada, koneksi ditolak: semuanya
      // berarti permintaannya tidak pernah sampai ke aplikasi mana pun.
      return const TidakAdaJaringan();
    } on http.ClientException {
      return const TidakAdaJaringan();
    }
  }

  HasilMasuk _baca(http.Response jawaban) {
    if (jawaban.statusCode == 401 || jawaban.statusCode == 403) {
      return const KredensialSalah();
    }
    if (jawaban.statusCode != 200) {
      // Termasuk 4xx lain: sebuah 400 karena bentuk permintaan salah adalah bug
      // aplikasi, dan menyuruh pengguna memeriksa kata sandinya untuk itu
      // adalah menyalahkan orang yang tidak melakukan kesalahan apa pun.
      return const ServerBermasalah();
    }

    // Badan jawaban yang tidak sesuai janji diperlakukan sama dengan server
    // rusak, bukan dilempar keluar: sebuah pengecualian di sini akan muncul di
    // layar sebagai galat merah, bukan sebagai kalimat yang bisa ditindaklanjuti.
    try {
      final isi = jsonDecode(jawaban.body);
      if (isi is! Map<String, dynamic>) return const ServerBermasalah();

      final token = isi['access_token'];
      final tokenSegar = isi['refresh_token'];
      if (token is! String || token.isEmpty) return const ServerBermasalah();
      if (tokenSegar is! String) return const ServerBermasalah();

      // `expires_in` dalam detik, dijumlahkan sekali di sini — lihat
      // `SesiLogin.kedaluwarsa`. Nilai yang hilang dianggap satu jam, angka
      // yang lazim dan cukup pendek untuk tidak berbahaya bila salah.
      final detik = isi['expires_in'];
      final berlaku = Duration(seconds: detik is int ? detik : 3600);

      final pengguna = isi['user'];
      final nama = pengguna is Map && pengguna['name'] is String
          ? pengguna['name'] as String
          : '';
      final email = pengguna is Map && pengguna['email'] is String
          ? pengguna['email'] as String
          : '';

      return MasukBerhasil(
        SesiLogin(
          token: token,
          tokenSegar: tokenSegar,
          kedaluwarsa: DateTime.now().add(berlaku),
          nama: nama,
          email: email,
        ),
      );
    } on FormatException {
      return const ServerBermasalah();
    }
  }

  @override
  void dispose() {
    if (_klienMilikSendiri) _klien.close();
  }
}
