import 'package:flutter/material.dart';

import '../models/sesi_makan.dart';

/// Kemajuan pengukuran jam, cukup besar untuk dibaca dari jarak lengan.
///
/// Menggantikan tombol ukur **selama jam bekerja**, bukan duduk di sampingnya.
/// Sebelumnya satu-satunya tanda adalah spinner 18 px dan "Jam mengukur… 42%"
/// di dalam tombol yang padam, ditambah keterangan 11 px — padahal pengukuran
/// adalah bagian sesi yang paling lama ditatap orang (puluhan detik, kadang
/// menit), dan satu-satunya saat ia harus berbuat sesuatu: mendiamkan tangan,
/// atau merapatkan jam. Tombol yang mati tidak punya apa-apa untuk dikatakan
/// selama itu, jadi tempatnya diberikan ke kabar yang sedang berlangsung.
///
/// Semua angkanya milik jam (§5.5 v1.4): persen dan sisa detik datang di denyut
/// Status, dan [KemajuanUkur.macet] disimpulkan dari persen yang tidak bergerak.
/// Tidak ada hitung mundur buatan layar — yang mengakhiri pengukuran adalah
/// kecukupan data, jadi sisa waktunya boleh memanjang dan layar tidak boleh
/// menjanjikan detik yang tidak dijanjikan jam.
class KartuKemajuanUkur extends StatelessWidget {
  const KartuKemajuanUkur({
    super.key,
    required this.kemajuan,
    required this.namaTitik,
    this.ringkas = false,
  });

  final KemajuanUkur kemajuan;

  /// Label titik yang diukur ("+1 jam", "baseline").
  final String namaTitik;

  /// Tanpa label dan tanpa angka persen besar.
  ///
  /// Dipakai di kartu sesi Beranda, yang hero-nya sudah berganti menjadi persen
  /// ini selama jam mengukur. Menulis angka yang sama dua kali dalam jarak 16
  /// piksel melanggar "satu angka, satu tempat", dan angka kedua yang lebih
  /// kecil hanya membuat mata ragu mana yang dibaca.
  final bool ringkas;

  static const _hijau = Color(0xFF0EAD69);
  static const _jingga = Color(0xFFB4761E);

  String? get _kalimatSisa {
    final sisa = kemajuan.sisaDetik;
    if (kemajuan.macet || sisa == null) return null;
    if (sisa >= 255) return 'lebih dari 4 menit lagi';
    if (sisa <= 0) return 'hampir selesai';
    return '± $sisa detik lagi';
  }

  @override
  Widget build(BuildContext context) {
    final macet = kemajuan.macet;
    final warna = macet ? _jingga : _hijau;
    final persen = kemajuan.persen;
    final sisa = _kalimatSisa;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: macet ? const Color(0xFFFFF4E5) : const Color(0xFFE2F6F0),
        borderRadius: BorderRadius.circular(16),
        border: macet
            ? Border.all(color: const Color(0xFFF0D9B5), width: 1.5)
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!ringkas) ...[
            Text(
              macet
                  ? 'JAM BELUM MENEMUKAN NADI · ${namaTitik.toUpperCase()}'
                  : 'JAM SEDANG MENGUKUR · ${namaTitik.toUpperCase()}',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
                color: macet ? _jingga : const Color(0xFF6B807B),
              ),
            ),
            const SizedBox(height: 6),
          ],
          if (!ringkas || sisa != null)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                if (!ringkas)
                  Text(
                    // Firmware ≤ v1.3 tidak mengirim persen. "0%" di situ
                    // akan terbaca sebagai jam yang belum mulai, padahal ia
                    // sedang bekerja — jadi yang ditulis adalah kata, bukan
                    // angka palsu.
                    persen != null ? '$persen%' : 'Mengukur…',
                    style: TextStyle(
                      fontSize: persen != null ? 28 : 20,
                      fontWeight: FontWeight.w700,
                      color: warna,
                      height: 1.1,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                const Spacer(),
                if (sisa != null)
                  Text(
                    sisa,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B807B),
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          _Bilah(persen: persen, warna: warna),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                macet ? Icons.warning_amber_rounded : Icons.favorite_rounded,
                size: 18,
                color: warna,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  macet
                      // Bukan kegagalan: jamnya hidup dan masih mencari nadi,
                      // dan yang memperbaikinya justru orang yang sedang
                      // membaca kalimat ini.
                      ? 'Rapatkan jam di pergelangan dan diamkan tangan. '
                            'Jam terus mencoba.'
                      : 'Diamkan tangan dan jangan lepas jamnya sampai '
                            'selesai.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: macet
                        ? const Color(0xFF6B4E1E)
                        : const Color(0xFF1E3A34),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Bilah kemajuan yang bergerak halus di antara denyut.
///
/// Denyut datang tiap 2 detik; tanpa animasi bilahnya melompat, dan lompatan
/// yang jarang terbaca sebagai layar yang macet di antaranya.
class _Bilah extends StatelessWidget {
  const _Bilah({required this.persen, required this.warna});

  final int? persen;
  final Color warna;

  @override
  Widget build(BuildContext context) {
    const tinggi = 10.0;
    const radius = BorderRadius.all(Radius.circular(tinggi / 2));
    final p = persen;
    if (p == null) {
      return LinearProgressIndicator(
        minHeight: tinggi,
        borderRadius: radius,
        color: warna,
        backgroundColor: Colors.white,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(end: (p.clamp(0, 100)) / 100),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOut,
      builder: (context, nilai, _) => LinearProgressIndicator(
        value: nilai,
        minHeight: tinggi,
        borderRadius: radius,
        color: warna,
        backgroundColor: Colors.white,
      ),
    );
  }
}
