import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/sesi_makan_controller.dart';

/// Tombol "Sinkronkan" beserta umpan baliknya.
///
/// Menarik buffer jam adalah satu-satunya tindakan di layar yang tidak
/// mengubah apa pun di layar seketika — tanpa animasi, tombol yang ditekan
/// terlihat persis seperti tombol yang tidak ditekan, dan tekanan kedua dan
/// ketiga adalah kelanjutan yang wajar dari keraguan itu. Untuk pengguna lansia
/// yang jadi premis docs/alur-pemasangan-jam.md, itu bukan hal kecil.
///
/// Karena itu ada lantai waktu satu putaran penuh: perintahnya sendiri selesai
/// dalam hitungan milidetik, dan kilatan yang terlalu singkat untuk dilihat
/// sama saja dengan tidak ada umpan balik.
///
/// Dua wujud, satu perilaku. Yang berlabel dipakai di kartu status halaman
/// Menghubungkan Perangkat; yang [ringkas] hanya ikon, untuk baris status
/// sempit di Beranda. Keduanya berbagi fase dan lantai waktu yang sama supaya
/// menekan sinkron terasa sama di mana pun ia ditekan.
///
/// **Pemanggil yang memutuskan tombol ini ada atau tidak.** Tanpa jam yang
/// pernah dipasangkan tidak ada apa pun untuk disinkronkan, jadi tombolnya
/// tidak ditampilkan sama sekali — lihat `StatusPerangkat.belumDipasangkan`.
class TombolSinkron extends StatefulWidget {
  const TombolSinkron({super.key, required this.aktif, this.ringkas = false});

  /// Jam tersambung. Bila false tombol tetap tampil tetapi mati — buffer-nya
  /// nyata dan menunggu, hanya tautannya yang belum ada.
  final bool aktif;

  /// Tampil sebagai ikon saja, tanpa label dan tanpa latar tombol.
  final bool ringkas;

  @override
  State<TombolSinkron> createState() => _TombolSinkronState();
}

enum _FaseSinkron { diam, berjalan, selesai }

class _TombolSinkronState extends State<TombolSinkron>
    with SingleTickerProviderStateMixin {
  static const Duration _satuPutaran = Duration(milliseconds: 900);

  late final AnimationController _putaran = AnimationController(
    vsync: this,
    duration: _satuPutaran,
  );
  _FaseSinkron _fase = _FaseSinkron.diam;
  Timer? _jedaSelesai;

  @override
  void dispose() {
    _jedaSelesai?.cancel();
    _putaran.dispose();
    super.dispose();
  }

  Future<void> _jalankan() async {
    final controller = context.read<SesiMakanController>();

    setState(() => _fase = _FaseSinkron.berjalan);
    _putaran.repeat();

    // Perintahnya dan lantai waktunya berjalan berdampingan: yang menentukan
    // adalah mana yang lebih lama, bukan urutannya.
    await Future.wait([
      controller.sinkronkan(),
      Future<void>.delayed(_satuPutaran),
    ]);
    if (!mounted) return;

    _putaran.stop();
    _putaran.value = 0;
    setState(() => _fase = _FaseSinkron.selesai);

    _jedaSelesai?.cancel();
    _jedaSelesai = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _fase = _FaseSinkron.diam);
    });
  }

  @override
  Widget build(BuildContext context) {
    final berjalan = _fase == _FaseSinkron.berjalan;
    final selesai = _fase == _FaseSinkron.selesai;
    final bisaDitekan = widget.aktif && !berjalan;

    // "Terkirim", bukan "Tersinkron": yang selesai adalah permintaannya.
    // Sampel yang tertahan di buffer datang beberapa saat kemudian lewat
    // notifikasi (protokol §6), dan mengaku selesai lebih awal akan jadi
    // kebohongan kecil yang persis terlihat saat angkanya belum berubah.
    final label = berjalan
        ? 'Menyinkronkan'
        : selesai
        ? 'Terkirim'
        : 'Sinkronkan';

    Widget ikon(double ukuran) => selesai
        ? Icon(Icons.check_rounded, size: ukuran)
        : RotationTransition(
            turns: _putaran,
            child: Icon(Icons.sync_rounded, size: ukuran),
          );

    if (widget.ringkas) {
      return IconButton(
        onPressed: bisaDitekan ? _jalankan : null,
        tooltip: label,
        color: const Color(0xFF0EAD69),
        // Mati bukan berarti hilang: jam yang terputus tetap punya buffer,
        // hanya tautannya yang belum ada.
        disabledColor: const Color(0xFF9CB1AC),
        icon: ikon(24),
      );
    }

    return ElevatedButton.icon(
      onPressed: bisaDitekan ? _jalankan : null,
      icon: ikon(14),
      label: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF0EAD69),
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
