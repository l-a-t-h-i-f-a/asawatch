import 'package:flutter/material.dart';

import '../models/sesi_makan.dart';
import '../utils/ikon.dart';
import '../utils/warna_respons.dart';

/// Lencana kecil "Landai / Sedang / Lonjakan / Belum lengkap".
///
/// Dipakai daftar Riwayat dan kepala Ringkasan Sesi supaya sesi yang sama
/// terbaca sama di kedua tempat.
class LencanaKualitas extends StatelessWidget {
  const LencanaKualitas({
    super.key,
    required this.kualitas,
    this.ukuranTeks = 10,
  });

  final KualitasRespons kualitas;
  final double ukuranTeks;

  @override
  Widget build(BuildContext context) {
    final warna = warnaKualitas(kualitas);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: warna.latar,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ikonKualitasRespons(kualitas),
            size: ukuranTeks + 1,
            color: warna.teks,
          ),
          const SizedBox(width: 4),
          Text(
            kualitas.label,
            style: TextStyle(
              fontSize: ukuranTeks,
              fontWeight: FontWeight.bold,
              color: warna.teks,
            ),
          ),
        ],
      ),
    );
  }
}
