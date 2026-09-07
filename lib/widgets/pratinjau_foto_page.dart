import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/gaya_sistem.dart';

/// Foto makanan satu sesi, sebesar layar, bisa digeser dan diperbesar.
///
/// Alasannya ada: di setiap kartu, foto piring itu berukuran 52–150 px dan
/// dipangkas `BoxFit.cover`, jadi separuh piringnya memang tidak terlihat.
/// Padahal seluruh angka nutrisi adalah perkiraan **dari foto itu** — porsi
/// yang jelas meleset baru kelihatan meleset kalau piringnya bisa dilihat utuh.
///
/// Halaman ini tidak pernah dibuka sendiri: [FotoMakanan] dengan
/// `bisaDibuka: true` yang mendorongnya, dan hanya ketika fotonya benar-benar
/// ada — menekan penampung cadangan tidak membuka layar hitam kosong.
class PratinjauFotoPage extends StatefulWidget {
  const PratinjauFotoPage({super.key, required this.penyedia, this.judul});

  /// Gambar yang sama persis dengan yang dipakai kartu asalnya, dibangun
  /// sekali oleh [FotoMakanan.penyediaFoto] agar bentuk `fotoPath` (berkas,
  /// URL, aset) tidak dibaca di dua tempat.
  final ImageProvider penyedia;

  /// Nama makanan, kalau ada. Sekadar penanda sesi mana yang sedang dilihat.
  final String? judul;

  @override
  State<PratinjauFotoPage> createState() => _PratinjauFotoPageState();
}

class _PratinjauFotoPageState extends State<PratinjauFotoPage> {
  final TransformationController _transformasi = TransformationController();

  /// Titik ketukan terakhir, untuk memperbesar tepat di tempat yang ditekan.
  Offset? _titikKetuk;

  static const double _skalaPerbesar = 2.5;

  @override
  void dispose() {
    _transformasi.dispose();
    super.dispose();
  }

  /// Ketuk dua kali: perbesar ke titik yang diketuk, atau kembali ke utuh.
  ///
  /// Mencubit dua jari tetap bisa, tetapi bagi tangan yang tidak lagi luwes
  /// ketukan ganda jauh lebih mudah — dan ini satu-satunya jalan kembali ke
  /// ukuran utuh tanpa harus mencubit terbalik dengan tepat.
  void _ketukGanda() {
    final sudahDiperbesar = _transformasi.value.getMaxScaleOnAxis() > 1.01;
    if (sudahDiperbesar) {
      _transformasi.value = Matrix4.identity();
      return;
    }
    final titik = _titikKetuk ?? Offset.zero;
    // Perbesar *terhadap titik yang diketuk*: skala di diagonal, lalu geser
    // sebanyak pergeseran yang ditimbulkan skala itu pada titik tersebut.
    const s = _skalaPerbesar;
    _transformasi.value = Matrix4.identity()
      ..setEntry(0, 0, s)
      ..setEntry(1, 1, s)
      ..setEntry(0, 3, -titik.dx * (s - 1))
      ..setEntry(1, 3, -titik.dy * (s - 1));
  }

  @override
  Widget build(BuildContext context) {
    final judul = widget.judul;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: gayaSistemGelap,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GestureDetector(
              onDoubleTapDown: (rincian) =>
                  _titikKetuk = rincian.localPosition,
              onDoubleTap: _ketukGanda,
              child: InteractiveViewer(
                transformationController: _transformasi,
                minScale: 1,
                maxScale: 5,
                child: Image(
                  image: widget.penyedia,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) => const Center(
                    child: Text(
                      'Foto tidak bisa dibuka',
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ),
                ),
              ),
            ),

            // Tombol tutup: satu-satunya jalan keluar yang pasti. Menutup lewat
            // ketukan biasa tidak dipakai karena ketukan itu juga yang dipakai
            // untuk menggeser foto yang sedang diperbesar.
            Positioned(
              top: MediaQuery.paddingOf(context).top + 8,
              left: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.45),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),

            if (judul != null && judul.isNotEmpty)
              Positioned(
                bottom: MediaQuery.paddingOf(context).bottom + 20,
                left: 24,
                right: 24,
                child: Text(
                  judul,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    shadows: [Shadow(color: Colors.black, blurRadius: 8)],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
