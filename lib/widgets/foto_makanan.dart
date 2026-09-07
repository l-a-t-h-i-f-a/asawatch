import 'dart:io';

import 'package:flutter/material.dart';

import 'pratinjau_foto_page.dart';

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
    this.bisaDibuka = false,
    this.tandaPerbesar = true,
    this.judulPratinjau,
  });

  final String fotoPath;
  final double? lebar;
  final double? tinggi;
  final double radius;

  /// Ketuk untuk membuka [PratinjauFotoPage].
  ///
  /// Bawaannya mati, dan itu disengaja: di Riwayat, di kartu "Sesi Terakhir",
  /// dan di kartu "Sesi baru selesai", foto ini duduk **di dalam** kartu yang
  /// sendirinya bisa ditekan untuk membuka Ringkasan Sesi. Menyalakannya di
  /// sana berarti satu-satunya bagian kartu yang paling menarik jari justru
  /// tidak mengerjakan apa yang dikerjakan seluruh sisa kartu.
  final bool bisaDibuka;

  /// Tanda kaca pembesar di pojok foto, penanda bahwa foto bisa ditekan.
  ///
  /// Tanpa tanda ini fiturnya ada tetapi tidak pernah ditemukan — tidak ada
  /// yang menduga sebuah foto di dalam kartu bisa ditekan. Pada jempol 56–64 px
  /// tandanya justru menutupi piringnya, jadi di sana ia dimatikan.
  final bool tandaPerbesar;

  /// Nama makanan yang ditulis di bawah foto layar penuh, kalau ada.
  final String? judulPratinjau;

  /// Gambar untuk sebuah `fotoPath`, atau null kalau tidak ada yang bisa
  /// digambar (jalur kosong, atau berkas yang sudah terhapus).
  ///
  /// Satu-satunya tempat ketiga bentuk `fotoPath` dibaca — kartu dan layar
  /// penuh memakai objek yang sama, jadi keduanya juga berbagi cache gambar.
  static ImageProvider? penyediaFoto(String fotoPath) {
    if (fotoPath.isEmpty) return null;
    if (fotoPath.startsWith('http')) return NetworkImage(fotoPath);
    if (fotoPath.startsWith('assets/')) return AssetImage(fotoPath);
    if (File(fotoPath).existsSync()) return FileImage(File(fotoPath));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final penyedia = penyediaFoto(fotoPath);

    final Widget gambar = penyedia == null
        ? _penampungCadangan()
        : Image(
            image: penyedia,
            width: lebar,
            height: tinggi,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _penampungCadangan(),
          );

    final bool bisaDitekan = bisaDibuka && penyedia != null;

    final Widget kotak = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: bisaDitekan && tandaPerbesar
          ? Stack(
              children: [
                gambar,
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.zoom_out_map_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ],
            )
          : gambar,
    );

    // Penampung cadangan tidak pernah bisa dibuka: layar hitam kosong bukan
    // jawaban atas ketukan, dan foto yang hilang tidak akan kembali.
    if (!bisaDitekan) return kotak;

    return Semantics(
      button: true,
      label: 'Lihat foto makanan',
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                PratinjauFotoPage(penyedia: penyedia, judul: judulPratinjau),
          ),
        ),
        child: kotak,
      ),
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
