import 'package:flutter/material.dart';

/// Foto makanan sebuah sesi, dengan sudut membulat dan penampung cadangan.
///
/// Selama Fase UI `fotoPath` masih berupa URL contoh; jalur file kamera nyata
/// baru masuk pada langkah 6 rancangan, jadi belum ada pembacaan `dart:io`
/// di sini (agar build web tetap jalan).
class FotoMakanan extends StatelessWidget {
  const FotoMakanan({
    super.key,
    required this.fotoPath,
    this.lebar,
    this.tinggi,
    this.radius = 16,
  });

  final String fotoPath;
  final double? lebar;
  final double? tinggi;
  final double radius;

  @override
  Widget build(BuildContext context) {
    Widget gambar;
    if (fotoPath.startsWith('http')) {
      gambar = Image.network(
        fotoPath,
        width: lebar,
        height: tinggi,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _penampungCadangan(),
      );
    } else if (fotoPath.startsWith('assets/')) {
      gambar = Image.asset(
        fotoPath,
        width: lebar,
        height: tinggi,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _penampungCadangan(),
      );
    } else {
      gambar = _penampungCadangan();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: gambar,
    );
  }

  Widget _penampungCadangan() {
    return Container(
      width: lebar,
      height: tinggi,
      color: const Color(0xFFE8F8F5),
      alignment: Alignment.center,
      child: const Icon(
        Icons.restaurant_menu,
        color: Color(0xFF0EAD69),
        size: 28,
      ),
    );
  }
}
