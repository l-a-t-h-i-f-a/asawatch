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

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'auth_service.dart';
import 'google_masuk_service.dart';

class AuthHttpService implements AuthService {
  AuthHttpService({
    required this.basisUrl,
    this.namaPerangkat = 'AsaWatch Android',
    http.Client? klien,
    this.google,
  }) : _klien = klien ?? http.Client(),
       _klienMilikSendiri = klien == null;

  /// Akar alamat API, tanpa garis miring di ujung — mis.
  /// `https://asawatch.enumatechnology.com`. Diambil dari `konfigurasi.dart`
  /// agar alamat pengembangan tidak pernah ikut terbawa ke rakitan rilis.
  final String basisUrl;

  /// Label token di sisi server (`nama_perangkat`, §4). Sanctum menyimpannya
  /// per token, dan itulah yang membuat "keluar dari perangkat lain" bisa
  /// menyebut perangkat mana. Sekarang masih tetap; begitu ada `device_info`,
  /// isilah dengan merek dan tipe ponselnya.
  final String namaPerangkat;

  final http.Client _klien;

  /// Klien yang dibuat sendiri harus ditutup sendiri; klien yang disuntikkan
  /// milik pemanggil, dan menutupnya di sini akan mematikan `MockClient` yang
  /// mungkin masih dipakai test berikutnya.
  final bool _klienMilikSendiri;

  /// Seam ke `google_sign_in`, disuntikkan dengan alasan yang sama seperti
  /// [_klien]: ia satu-satunya bagian yang menuntut Play Services dan akun
  /// sungguhan, sehingga tanpa penyuntikan ini seluruh alur Google hanya bisa
  /// diuji di perangkat.
  ///
  /// Boleh null — aplikasi harus tetap utuh tanpa Google, dan rakitan yang
  /// belum punya client ID tidak boleh gagal dirakit.
  final GoogleMasukService? google;

  /// Email dari permintaan terakhir — lihat [_bacaSukses].
  String _emailTerakhir = '';

  @override
  Future<HasilMasuk> masukDenganGoogle() async {
    final google = this.google;
    if (google == null) {
      debugPrint(
        'AuthHttpService: masuk Google diminta tanpa GoogleMasukService.',
      );
      return const ServerBermasalah();
    }

    final dariGoogle = await google.masuk();
    switch (dariGoogle) {
      case GoogleDibatalkan():
        return const DibatalkanPengguna();
      case GoogleGagal(:final catatan):
        // Sebuah log, bukan sebuah layar. Kalimat di [catatan] menyebut SHA-1
        // dan client ID — kata-kata yang tidak berarti apa pun bagi pengguna,
        // sementara yang perlu ia tahu hanyalah bahwa ini bukan salahnya.
        debugPrint('Masuk Google gagal: $catatan');
        return const ServerBermasalah();
      case GoogleBerhasil(:final idToken, :final email):
        _emailTerakhir = email;
        return _tukarIdToken(idToken);
    }
  }

  /// Menukar ID token Google menjadi token Sanctum (§4 `google`).
  ///
  /// Yang dikirim adalah **ID token**, dan server wajib memverifikasinya ke
  /// Google — tanda tangan, `aud`, dan `exp`. Aplikasi tidak memeriksa apa pun
  /// dari isinya: apa pun yang dikirim ponsel bisa dikarang, jadi satu-satunya
  /// pemeriksaan yang berarti terjadi di sisi server.
  Future<HasilMasuk> _tukarIdToken(String idToken) async {
    try {
      final jawaban = await _klien
          .post(
            Uri.parse('$basisUrl/api/v1/auth/google'),
            headers: const {
              'content-type': 'application/json; charset=utf-8',
              'accept': 'application/json',
            },
            body: jsonEncode({
              'id_token': idToken,
              'nama_perangkat': namaPerangkat,
            }),
          )
          .timeout(AuthService.batasWaktu);

      // 201 saat akunnya baru dibuat, 200 saat sudah ada — yang menentukan
      // kelas 2xx-nya, sama seperti pada `daftar`.
      if (jawaban.statusCode >= 200 && jawaban.statusCode < 300) {
        return _bacaSukses(jawaban.body);
      }
      // Sengaja **tidak** lewat [_bacaGagal]: di sini 401 berarti ID token
      // ditolak Google, bukan kata sandi yang salah, dan menyuruh pengguna
      // memeriksa kredensial yang tidak pernah ia ketik adalah jalan buntu.
      debugPrint(
        'Masuk Google ditolak server: ${jawaban.statusCode} '
        '${jawaban.body.substring(0, jawaban.body.length.clamp(0, 200))}',
      );
      return const ServerBermasalah();
    } on TimeoutException {
      return const WaktuHabis();
    } on SocketException {
      return const TidakAdaJaringan();
    } on http.ClientException {
      return const TidakAdaJaringan();
    }
  }

  @override
  Future<HasilMasuk> masuk({
    required String identifier,
    required String kataSandi,
  }) async {
    _emailTerakhir = identifier.trim();
    try {
      final jawaban = await _klien
          .post(
            Uri.parse('$basisUrl/api/v1/auth/masuk'),
            headers: const {
              'content-type': 'application/json; charset=utf-8',
              'accept': 'application/json',
            },
            // Sandi hanya pernah ada di badan permintaan. Menaruhnya di query
            // string akan menuliskannya ke log akses server dan riwayat proxy.
            body: jsonEncode({
              'email': identifier.trim(),
              'kata_sandi': kataSandi,
              'nama_perangkat': namaPerangkat,
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
    if (jawaban.statusCode == 200) return _bacaSukses(jawaban.body);
    return _bacaGagal(jawaban);
  }

  /// Bentuk sukses menurut §3.1 dan §4: `{"data": {"token": ..., "profil": ...}}`.
  ///
  /// Badan jawaban yang tidak sesuai janji diperlakukan sama dengan server
  /// rusak, bukan dilempar keluar: sebuah pengecualian di sini akan muncul di
  /// layar sebagai galat merah, bukan sebagai kalimat yang bisa ditindaklanjuti.
  HasilMasuk _bacaSukses(String badan) {
    try {
      final isi = jsonDecode(badan);
      if (isi is! Map<String, dynamic>) return const ServerBermasalah();

      final data = isi['data'];
      if (data is! Map) return const ServerBermasalah();

      final token = data['token'];
      if (token is! String || token.isEmpty) return const ServerBermasalah();

      // Nama diambil dari `profil`; `masuk` tidak mengembalikan email sama
      // sekali (§4), jadi yang dipakai adalah email yang barusan dikirim —
      // satu-satunya yang pasti benar, karena dengan itulah token ini terbit.
      final profil = data['profil'];
      final nama = profil is Map && profil['nama'] is String
          ? profil['nama'] as String
          : '';

      return MasukBerhasil(
        SesiLogin(
          token: token,
          kedaluwarsa: DateTime.now().add(SesiLogin.masaBerlakuToken),
          nama: nama,
          email: _emailTerakhir,
        ),
      );
    } on FormatException {
      return const ServerBermasalah();
    }
  }

  /// Selain 200, dan di sini `galat.kode` didahulukan atas kode status HTTP.
  ///
  /// Alasannya konkret, bukan kehati-hatian abstrak: backend hari ini membalas
  /// **422 `validasi_gagal`** untuk kata sandi yang salah, bukan 401 seperti
  /// yang seharusnya. Kalau aplikasi hanya membaca status, orang yang salah
  /// mengetik sandinya akan diberi tahu bahwa *servernya* rusak — lalu menunggu
  /// sesuatu yang tidak akan pernah membaik. Membaca `kode` membuat pesan yang
  /// benar tetap muncul, baik sebelum maupun sesudah backend diperbaiki.
  ///
  /// `validasi_gagal` dipetakan ke [KredensialSalah] karena pada endpoint ini
  /// keduanya berarti hal yang sama bagi pengguna: yang dia ketik belum
  /// diterima, dan yang harus berubah adalah isian formulirnya.
  HasilMasuk _bacaGagal(http.Response jawaban) {
    final kode = _kodeGalat(jawaban.body);
    if (kode != null) {
      return switch (kode) {
        'tidak_terautentikasi' ||
        'kredensial_salah' ||
        'validasi_gagal' => const KredensialSalah(),
        _ => const ServerBermasalah(),
      };
    }

    if (jawaban.statusCode == 401 || jawaban.statusCode == 403) {
      return const KredensialSalah();
    }
    // Termasuk 4xx lain: sebuah 400 karena bentuk permintaan salah adalah bug
    // aplikasi, dan menyuruh pengguna memeriksa kata sandinya untuk itu adalah
    // menyalahkan orang yang tidak melakukan kesalahan apa pun.
    return const ServerBermasalah();
  }

  String? _kodeGalat(String badan) {
    try {
      final isi = jsonDecode(badan);
      if (isi is! Map<String, dynamic>) return null;
      final galat = isi['galat'];
      if (galat is! Map) return null;
      final kode = galat['kode'];
      return kode is String && kode.isNotEmpty ? kode : null;
    } on FormatException {
      // Portal WiFi yang menjawab dengan HTML-nya sendiri, misalnya.
      return null;
    }
  }

  @override
  Future<HasilMasuk> daftar({
    required String nama,
    required String email,
    required String kataSandi,
  }) async {
    _emailTerakhir = email.trim();
    try {
      final jawaban = await _klien
          .post(
            Uri.parse('$basisUrl/api/v1/auth/daftar'),
            headers: const {
              'content-type': 'application/json; charset=utf-8',
              'accept': 'application/json',
            },
            body: jsonEncode({
              'nama': nama.trim(),
              'email': email.trim(),
              'kata_sandi': kataSandi,
              'nama_perangkat': namaPerangkat,
            }),
          )
          .timeout(AuthService.batasWaktu);

      // 201 pada pembuatan, 200 pada pembaruan — yang menentukan kelas 2xx-nya,
      // bukan angka persisnya.
      if (jawaban.statusCode >= 200 && jawaban.statusCode < 300) {
        return _bacaSukses(jawaban.body);
      }
      return _bacaGagalDaftar(jawaban);
    } on TimeoutException {
      return const WaktuHabis();
    } on SocketException {
      return const TidakAdaJaringan();
    } on http.ClientException {
      return const TidakAdaJaringan();
    }
  }

  /// Kegagalan pendaftaran. Bedanya dengan [_bacaGagal] hanya satu, dan itu
  /// yang paling sering terjadi: **validasi yang menyebut field `email` berarti
  /// emailnya sudah terdaftar.**
  ///
  /// Bentuknya sendiri masih `validasi_gagal` — server tidak punya kode khusus
  /// untuknya — jadi yang membedakan adalah `detail`-nya. Bentuk email sudah
  /// divalidasi di layar sebelum permintaan dikirim, jadi keluhan server
  /// tentang field itu praktis hanya punya satu arti. Salah menebaknya pun
  /// tidak berbahaya: pesan yang tampil tetap menunjuk ke field email, yang
  /// memang field yang bermasalah.
  HasilMasuk _bacaGagalDaftar(http.Response jawaban) {
    final detail = _detailGalat(jawaban.body);
    if (detail != null && detail.containsKey('email')) {
      return const EmailSudahDipakai();
    }
    return _bacaGagal(jawaban);
  }

  Map<String, dynamic>? _detailGalat(String badan) {
    try {
      final isi = jsonDecode(badan);
      if (isi is! Map<String, dynamic>) return null;
      final galat = isi['galat'];
      if (galat is! Map) return null;
      final detail = galat['detail'];
      return detail is Map<String, dynamic> ? detail : null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<void> keluar(String token) async {
    try {
      await _klien
          .post(
            Uri.parse('$basisUrl/api/v1/auth/keluar'),
            headers: {
              'accept': 'application/json',
              'authorization': 'Bearer $token',
            },
          )
          .timeout(AuthService.batasWaktu);
    } catch (_) {
      // Sengaja ditelan, termasuk 401 yang tidak dilihat sama sekali: token
      // yang sudah tidak sah di server sudah tercabut dengan sendirinya, dan
      // keluar tanpa sinyal tetap harus berhasil di sisi ponsel.
    }
    // Melepas akun Google juga, dan **setelah** pencabutan token, bukan
    // sebagai gantinya: tanpa ini ketukan "Masuk dengan Google" berikutnya
    // langsung masuk kembali ke akun yang sama tanpa memunculkan pemilih akun,
    // yang di ponsel bersama terbaca sebagai keluar yang tidak bekerja.
    await google?.keluar();
  }

  @override
  void dispose() {
    if (_klienMilikSendiri) _klien.close();
  }
}
