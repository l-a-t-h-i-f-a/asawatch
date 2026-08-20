import 'dart:io';

import 'package:flutter/material.dart';

/// Foto makanan sebuah sesi, dengan sudut membulat dan penampung cadangan.
///
/// `fotoPath` punya tiga bentuk dan ketiganya hidup berdampingan: jalur file
/// dari kamera sungguhan (bentuk normal sejak kamera dipasang), URL contoh
/// (sesi lama dan data uji), dan jalur aset. Foto yang filenya sudah hilang —
/// pengguna membersihkan penyimpanan, aplikasi dipasang ulang — jatuh ke
/// penampung cadangan, tidak pernah ke layar galat: sesinya sendiri masih utuh.
///
/// `dart:io` di sini mengunci widget ini ke platform non-web, yang tidak
/// menambah batasan baru: sejak sesi pindah ke SQLite, web memang sudah tidak
/// bisa dijalankan.
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
    } else if (File(fotoPath).existsSync()) {
      gambar = Image.file(
        File(fotoPath),
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
