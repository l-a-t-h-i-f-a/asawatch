/// Riwayat sesi di sisi server — docs/rancangan-api-laravel.md §5.2.
///
/// Satu arah dan hanya itu: aplikasi mengunggah, tidak pernah mengunduh.
/// Sinkronisasi dua arah (§7) menuntut aturan konflik, penghapusan yang
/// menular, dan kursor waktu — dan tidak satu pun dari itu dibutuhkan sebelum
/// ada perangkat kedua. Yang dibutuhkan sekarang cuma satu: apa yang terjadi di
/// ponsel bisa dilihat di server.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:http/http.dart' as http;

import '../models/sesi_makan.dart';
import 'auth_service.dart';

abstract class SesiServerService {
  /// Mengunggah satu sesi. `true` bila server menerimanya.
  ///
  /// **Idempoten**, dan itulah yang membuat seluruh rancangan ini sederhana:
  /// `id` sesi adalah UUID buatan aplikasi dan endpoint-nya upsert (§2 aturan
  /// 2), jadi mengirim sesi yang sama dua kali tidak menghasilkan dua baris.
  /// Karena itu tidak ada kolom "sudah terkirim" di basis data lokal —
  /// pengiriman ulang selalu aman, dan keadaan yang tidak perlu disimpan adalah
  /// keadaan yang tidak bisa salah.
  Future<bool> kirim(String token, SesiMakan sesi);
}

class SesiHttpService implements SesiServerService {
  SesiHttpService({
    required this.basisUrl,
    this.onTokenDitolak,
    http.Client? klien,
  }) : _klien = klien ?? http.Client(),
       _klienMilikSendiri = klien == null;

  final String basisUrl;

  /// Dipanggil saat server menjawab 401. Lihat `PenjagaSesi` — dan perhatikan
  /// bahwa seluruh riwayat dikirim ulang setiap kali aplikasi dibuka, jadi satu
  /// token yang basi memicu ini berkali-kali sekaligus; penjaganya yang
  /// menahan agar keluarnya tetap sekali.
  final Future<void> Function()? onTokenDitolak;
  final http.Client _klien;
  final bool _klienMilikSendiri;

  @override
  Future<bool> kirim(String token, SesiMakan sesi) async {
    try {
      final jawaban = await _klien
          .put(
            Uri.parse('$basisUrl/api/v1/sesi/${sesi.id}'),
            headers: {
              'accept': 'application/json',
              'content-type': 'application/json; charset=utf-8',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(badanSesi(sesi)),
          )
          .timeout(AuthService.batasWaktu);
      if (jawaban.statusCode == 401) {
        await onTokenDitolak?.call();
        return false;
      }
      return jawaban.statusCode >= 200 && jawaban.statusCode < 300;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    }
  }

  void dispose() {
    if (_klienMilikSendiri) _klien.close();
  }
}

/// Bentuk JSON satu sesi (§5.2).
///
/// Dipisah dari kelasnya supaya bisa diuji tanpa soket sama sekali — ini bagian
/// yang paling gampang salah diam-diam, dan yang paling mahal kalau salah:
/// server menyimpan apa yang dikirim, dan sampel yang sudah `terisi` di sana
/// bersifat final (§2 aturan 4).
Map<String, dynamic> badanSesi(SesiMakan sesi) => {
  'waktu_foto': _waktu(sesi.waktuFoto),
  't0': sesi.t0 == null ? null : _waktu(sesi.t0!),
  'status': sesi.status.name,
  'waktu_tidak_pasti': sesi.waktuTidakPasti,
  // Sesi uji **ikut dikirim**, bukan disembunyikan. Jalur unggah yang hanya
  // bisa dilatih oleh sesi sungguhan berarti menunggu dua setengah jam untuk
  // setiap percobaan — jalur seperti itu tidak pernah teruji. Yang menjaga
  // angkanya tidak mencemari apa pun adalah tandanya sendiri: server menyimpan
  // dan menampilkannya, tetapi tidak pernah menghitungnya.
  'sesi_uji': sesi.sesiUji,
  'sampel': [
    for (final s in sesi.sampel)
      {
        'index': s.index,
        'detik_relatif_t0': s.detikRelatifT0,
        'status': s.status.name,
        'dari_buffer': s.dariBuffer,
        'gula_darah': s.gulaDarah,
        'detak_jantung': s.detakJantung,
        'sistolik': s.sistolik,
        'diastolik': s.diastolik,
        'spo2': s.spo2,
      },
  ],
  'diperbarui_pada': _waktu(DateTime.now()),
};

/// ISO-8601 **UTC** (§3): aplikasi yang mengirim waktu lokal akan menggeser
/// setiap sesi begitu servernya berada di zona lain.
String _waktu(DateTime waktu) =>
    waktu.toUtc().toIso8601String().replaceFirst('Z', '000Z');

/// Server palsu untuk test — mencatat apa yang dikirim, dan bisa disuruh gagal.
class SesiServerPalsu implements SesiServerService {
  SesiServerPalsu({this.gagal = false});

  bool gagal;
  final List<SesiMakan> diterima = [];

  @override
  Future<bool> kirim(String token, SesiMakan sesi) async {
    if (gagal) return false;
    diterima.add(sesi);
    return true;
  }
}
