import 'package:flutter/material.dart';

/// Pengganti foto piring pada kartu sesi puasa.
///
/// Sesi puasa tidak punya foto. `FotoMakanan` dengan jalur kosong akan
/// menggambar penampung "foto tidak tersedia", yang terbaca sebagai foto yang
/// hilang — padahal memang tidak pernah ada yang dipotret. Ikon ini mengatakan
/// jenis sesinya, di slot yang sama dan dengan ukuran yang sama.
class IkonPuasa extends StatelessWidget {
  const IkonPuasa({super.key, this.ukuran = 56});

  final double ukuran;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: ukuran,
      height: ukuran,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8F5),
        borderRadius: BorderRadius.circular(ukuran * 0.28),
      ),
      child: Icon(
        Icons.nightlight_round,
        color: const Color(0xFF0EAD69),
        size: ukuran * 0.45,
      ),
    );
  }
}
