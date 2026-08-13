import 'package:flutter/material.dart';

import '../models/sesi_makan.dart';

/// Petunjuk bahwa t0 ditetapkan dari **jam**, bukan dari aplikasi (§6).
///
/// Menggantikan tombol "Selesai Makan & Pantau" yang dulu ada di tiga tempat
/// (kartu hasil kamera, Sesi Berjalan, kartu sesi di Beranda). Karena app tidak
/// lagi punya kuasa memulai sesi, yang bisa dilakukannya hanya memberi tahu apa
/// yang sedang ditunggu — dan jujur menyebut kalau jamnya belum tersambung
/// sehingga tombolnya belum menyala.
class PetunjukTombolJam extends StatelessWidget {
  const PetunjukTombolJam({
    super.key,
    required this.status,
    required this.perangkat,
  });

  final StatusSesi status;
  final StatusPerangkat perangkat;

  @override
  Widget build(BuildContext context) {
    // Tiga keadaan, bukan dua. Kalau tombol jamnya sudah ditekan, sesi sudah
    // berjalan — mengulang "jam belum tersambung" di sana adalah kebohongan:
    // sinyalnya justru baru saja sampai, dan sampel sedang ditulis.
    final sudahMulai = status != StatusSesi.draft &&
        status != StatusSesi.menungguPerangkat;
    final siap = status == StatusSesi.draft && perangkat.tersambung;
    final hijau = siap || sudahMulai;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hijau ? const Color(0xFFE2F6F0) : const Color(0xFFE2EBE8),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            sudahMulai
                ? Icons.check_circle_rounded
                : (siap ? Icons.watch_rounded : Icons.watch_off_rounded),
            size: 18,
            color: hijau ? const Color(0xFF0EAD69) : const Color(0xFF6B807B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sudahMulai
                      ? 'Tombol jam sudah ditekan'
                      : (siap
                            ? 'Tekan tombol Selesai Makan di jam'
                            : 'Jam belum tersambung'),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: hijau
                        ? const Color(0xFF0EAD69)
                        : const Color(0xFF6B807B),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  sudahMulai
                      ? 'Sesi sudah berjalan memakai waktu jam. Pantau '
                            'perkembangannya di layar Sesi Berjalan.'
                      : (siap
                            ? 'Sesi dimulai begitu tombolnya ditekan, memakai '
                                  'waktu jam — bukan waktu HP.'
                            : 'Tombol Selesai Makan di jam baru menyala '
                                  'setelah jam tersambung. Fotonya tetap '
                                  'tersimpan.'),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B807B),
                    height: 1.35,
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
