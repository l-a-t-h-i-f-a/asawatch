import 'package:flutter/material.dart';

/// Judul satu bagian layar: ikon bulat, judul, keterangan opsional, dan aksi
/// di kanan.
///
/// Sebelumnya tiap layar menulis sendiri `Text` 16 px bold warna 0xFF1E3A34
/// berulang-ulang; disatukan di sini supaya jarak, ukuran, dan warnanya sama
/// di semua tempat — dan supaya tiap bagian punya ikon tanpa menyalin kode.
class JudulBagian extends StatelessWidget {
  const JudulBagian({
    super.key,
    required this.ikon,
    required this.judul,
    this.keterangan,
    this.aksi,
  });

  final IconData ikon;
  final String judul;

  /// Baris kecil di bawah judul, mis. "6 sesi · satu titik per sesi".
  final String? keterangan;

  /// Widget di ujung kanan, mis. tombol filter.
  final Widget? aksi;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: Color(0xFFE2F6F0),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(ikon, size: 16, color: const Color(0xFF0EAD69)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  judul,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A34),
                  ),
                ),
                if (keterangan != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    keterangan!,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF7E9A94),
                    ),
                  ),
                ],
              ],
            ),
          ),
          ?aksi,
        ],
      ),
    );
  }
}
