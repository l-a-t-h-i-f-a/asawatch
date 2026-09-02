/// Profil di sisi server — docs/rancangan-api-laravel.md §5.1.
///
/// Dipisah dari [ProfilRepository] karena keduanya menjawab pertanyaan yang
/// berbeda: repository menjawab "apa yang diketahui ponsel ini", layanan ini
/// menjawab "apa yang diketahui akun". Aplikasi harus tetap berjalan penuh
/// tanpa yang kedua (§2 aturan 3), jadi ia selalu boleh null.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../repositories/profil_repository.dart';
import 'auth_service.dart';

abstract class ProfilServerService {
  /// Profil milik pemegang [token], atau null bila tidak bisa diambil.
  ///
  /// **Kegagalan dikembalikan sebagai null, tidak dilempar.** Halaman profil
  /// harus tetap terbuka saat sedang tanpa sinyal — yang tampil adalah salinan
  /// lokalnya, dan itu bukan keadaan galat.
  Future<ProfilServer?> ambil(String token);

  /// Mengirim [profil]. `true` bila server menerimanya.
  Future<bool> kirim(String token, Profil profil);
}

/// Profil dari server beserta stempel waktunya.
///
/// Stempelnya ikut dibawa karena itulah satu-satunya bahan untuk memutuskan
/// siapa yang lebih baru saat dua sisi berbeda (§7.1 aturan 2).
class ProfilServer {
  const ProfilServer({required this.profil, required this.diperbaruiPada});

  final Profil profil;
  final DateTime? diperbaruiPada;
}

class ProfilHttpService implements ProfilServerService {
  ProfilHttpService({
    required this.basisUrl,
    this.onTokenDitolak,
    http.Client? klien,
  }) : _klien = klien ?? http.Client(),
       _klienMilikSendiri = klien == null;

  final String basisUrl;

  /// Dipanggil saat server menjawab 401 — token yang dipakai sudah tidak
  /// berlaku. Lihat `PenjagaSesi`.
  final Future<void> Function()? onTokenDitolak;
  final http.Client _klien;
  final bool _klienMilikSendiri;

  Uri get _alamat => Uri.parse('$basisUrl/api/v1/profil');

  Map<String, String> _kepala(String token) => {
    'accept': 'application/json',
    'content-type': 'application/json; charset=utf-8',
    'authorization': 'Bearer $token',
  };

  @override
  Future<ProfilServer?> ambil(String token) async {
    try {
      final jawaban = await _klien
          .get(_alamat, headers: _kepala(token))
          .timeout(AuthService.batasWaktu);
      if (jawaban.statusCode == 401) {
        await onTokenDitolak?.call();
        return null;
      }
      if (jawaban.statusCode != 200) return null;

      final isi = jsonDecode(jawaban.body);
      if (isi is! Map<String, dynamic>) return null;
      final data = isi['data'];
      if (data is! Map) return null;

      return ProfilServer(
        profil: _keProfil(data),
        diperbaruiPada: DateTime.tryParse(
          data['diperbarui_pada'] as String? ?? '',
        ),
      );
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } on http.ClientException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<bool> kirim(String token, Profil profil) async {
    try {
      final jawaban = await _klien
          .put(
            _alamat,
            headers: _kepala(token),
            body: jsonEncode(_keJson(profil)),
          )
          .timeout(AuthService.batasWaktu);
      if (jawaban.statusCode == 401) {
        await onTokenDitolak?.call();
        return false;
      }
      // Backend membalas 201 saat barisnya memang baru dibuat dan 200 saat
      // hanya diperbarui; yang menentukan kelas 2xx-nya, bukan angka persisnya.
      return jawaban.statusCode >= 200 && jawaban.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  /// JSON → [Profil]. `email` dan `telepon` tidak ada di §5.1, jadi keduanya
  /// **tidak pernah ditimpa** oleh jawaban server — lihat `ProfilRepository`.
  static Profil _keProfil(Map data) => Profil(
    nama: data['nama'] as String? ?? '',
    tanggalLahir: data['tanggal_lahir'] as String? ?? '',
    jenisKelamin: _jenisKelaminKeApp(data['jenis_kelamin'] as String?),
    tinggi: _angkaKeTeks(data['tinggi_cm']),
    berat: _angkaKeTeks(data['berat_kg']),
    golonganDarah: data['golongan_darah'] as String? ?? '',
    email: '',
    telepon: '',
  );

  static Map<String, dynamic> _keJson(Profil p) => {
    'nama': _atauNull(p.nama),
    'tanggal_lahir': _atauNull(p.tanggalLahir),
    'jenis_kelamin': _jenisKelaminKeServer(p.jenisKelamin),
    'golongan_darah': _atauNull(p.golonganDarah),
    'tinggi_cm': num.tryParse(p.tinggi),
    'berat_kg': num.tryParse(p.berat),
  };

  /// Kosong dikirim sebagai null, bukan sebagai `""`.
  ///
  /// §5.1 menyatakan semua field boleh null dan hanya *bentuknya* yang
  /// divalidasi; sebuah `""` untuk tanggal lahir akan ditolak validator format
  /// tanggal, padahal artinya sama-sama "belum diisi".
  static String? _atauNull(String nilai) => nilai.isEmpty ? null : nilai;

  static String _angkaKeTeks(Object? nilai) {
    if (nilai == null) return '';
    if (nilai is num) {
      // 162.0 ditulis sebagai "162": angka bulat yang tampil dengan koma nol
      // terbaca sebagai presisi yang tidak pernah diukur.
      return nilai == nilai.roundToDouble()
          ? nilai.round().toString()
          : nilai.toString();
    }
    return nilai.toString();
  }

  /// Aplikasi memakai label tampilan (`Laki-laki`), server memakai nilai enum
  /// (`laki-laki`). Pemetaannya ada di sini, satu tempat, karena label itu juga
  /// yang harus cocok dengan `items` pada dropdown — nilai yang tidak ada di
  /// `items` membuat `DropdownButtonFormField` melempar.
  static String _jenisKelaminKeApp(String? nilai) => switch (nilai) {
    'laki-laki' => 'Laki-laki',
    'perempuan' => 'Perempuan',
    _ => '',
  };

  static String? _jenisKelaminKeServer(String nilai) => switch (nilai) {
    'Laki-laki' => 'laki-laki',
    'Perempuan' => 'perempuan',
    _ => null,
  };

  void dispose() {
    if (_klienMilikSendiri) _klien.close();
  }
}

/// Server palsu untuk test — padanan `FakeBleService`/`KameraPalsuService`.
class ProfilServerPalsu implements ProfilServerService {
  ProfilServerPalsu({
    this.tersimpan,
    this.diperbaruiPada,
    this.gagalKirim = false,
  });

  Profil? tersimpan;
  DateTime? diperbaruiPada;

  /// Memesan kegagalan pengiriman — satu-satunya cara menguji jalur "tersimpan
  /// di ponsel tetapi belum sampai ke server" tanpa mencabut jaringan.
  bool gagalKirim;

  final List<Profil> dikirim = [];

  @override
  Future<ProfilServer?> ambil(String token) async {
    final p = tersimpan;
    if (p == null) return null;
    return ProfilServer(profil: p, diperbaruiPada: diperbaruiPada);
  }

  @override
  Future<bool> kirim(String token, Profil profil) async {
    if (gagalKirim) return false;
    dikirim.add(profil);
    tersimpan = profil;
    diperbaruiPada = DateTime.now();
    return true;
  }
}
