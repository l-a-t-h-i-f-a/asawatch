import 'package:flutter/material.dart';

import '../models/sesi_makan.dart';
import '../utils/format_waktu.dart';
import '../utils/ikon.dart';

/// Ringkasan nutrisi satu sesi: enam angka makro (§12.4), termasuk gula total
/// dan serat yang menjelaskan perbedaan respons antar makanan berkarbohidrat
/// sama.
///
/// `hasil == null` adalah kondisi normal, bukan error — foto bisa diambil saat
/// offline dan analisis menyusul. Slot nutrisi menampilkan "Menganalisis…"
/// dan sesi tetap berjalan (§12.3).
///
/// **Tetapi kosong punya dua arti, dan keduanya tidak boleh digambar sama.**
/// Selain "tunggu sebentar" ada "tidak akan pernah ada": analisis yang gagal
/// permanen, dan sesi yang diunduh dari server — yang membawa angka gizinya
/// hanya bila server menyimpannya, sedangkan fotonya tertinggal di ponsel yang
/// memotretnya. Sebuah spinner untuk keadaan kedua menjanjikan sesuatu yang
/// tidak datang, dan orang akan menunggunya.
class RingkasanNutrisi extends StatelessWidget {
  const RingkasanNutrisi({
    super.key,
    required this.hasil,
    this.sedangDianalisis = false,
  });

  final HasilDeteksi? hasil;

  /// Apakah permintaan analisisnya benar-benar sedang berjalan sekarang.
  final bool sedangDianalisis;

  @override
  Widget build(BuildContext context) {
    final h = hasil;
    if (h == null) {
      return sedangDianalisis
          ? const _NutrisiMenganalisis()
          : const _NutrisiTidakAda();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final z in const [
              ZatGizi.kalori,
              ZatGizi.karbohidrat,
              ZatGizi.protein,
            ])
              _item(h, z),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            for (final z in const [
              ZatGizi.lemak,
              ZatGizi.gulaTotal,
              ZatGizi.serat,
            ])
              _item(h, z),
          ],
        ),
        if (h.zatTidakLengkap.isNotEmpty) ...[
          const SizedBox(height: 12),
          _CatatanTidakLengkap(hasil: h),
        ],
      ],
    );
  }

  /// Satu angka makro, dengan tiga kemungkinan tampilan.
  ///
  /// Yang membedakannya bukan gaya, melainkan **apa yang sedang dikatakan**:
  ///
  /// - angka pasti           → `45 g`
  /// - jumlah parsial (> 0)  → `≥ 45 g` — ada makanan yang tidak menyumbang
  /// - tidak diketahui, atau parsial yang angkanya nol → `—`
  ///
  /// Kasus terakhir yang paling penting dan paling gampang salah: nol pada zat
  /// yang ditandai tidak lengkap **bukan** berarti "tanpa kalori", melainkan
  /// "tidak ada satu pun makanan yang ketemu di tabel gizi". Menuliskannya
  /// sebagai `0 g` — apalagi pada gula, di aplikasi yang mengukur gula darah —
  /// adalah klaim yang tidak pernah dibuat siapa pun.
  Widget _item(HasilDeteksi h, ZatGizi zat) {
    final nilai = h.total[zat];
    final parsial = h.zatTidakLengkap.contains(zat);
    final tidakDiketahui = nilai == null || (parsial && nilai == 0);

    final label = zat.label;
    final teks = tidakDiketahui
        ? '—'
        : '${parsial ? '≥ ' : ''}${formatAngka(nilai)}';
    final satuan = tidakDiketahui ? '' : zat.satuan;

    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ikonMakro[label] ?? Icons.circle,
                size: 12,
                color: const Color(0xFF8FA7A1),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8FA7A1),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A34),
              ),
              children: [
                TextSpan(text: teks),
                TextSpan(
                  text: satuan,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                    color: Color(0xFF6B807B),
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

/// Kosong dan memang akan tetap kosong.
///
/// Tanpa spinner dan tanpa warna galat: tidak ada yang rusak, dan tidak ada
/// yang bisa dilakukan pengguna. Sesinya sendiri utuh — kurva gula darahnya
/// justru bagian yang paling penting, dan itu tidak bergantung pada angka gizi.
/// Satu baris yang menerangkan kenapa ada angka bertanda `≥` atau `—`.
///
/// Tanpa kalimat ini, `≥` hanyalah lambang aneh di sebelah angka. Dengan ini,
/// ia menjadi informasi: sebagian bahan belum ada di tabel gizi, jadi totalnya
/// pasti lebih besar daripada yang tertulis.
class _CatatanTidakLengkap extends StatelessWidget {
  const _CatatanTidakLengkap({required this.hasil});

  final HasilDeteksi hasil;

  @override
  Widget build(BuildContext context) {
    final adaYangKosong = hasil.zatTidakLengkap.any(
      (z) => (hasil.total[z] ?? 0) == 0,
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.info_outline_rounded,
          size: 13,
          color: Color(0xFF9CB1AC),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            adaYangKosong
                ? 'Sebagian makanan belum ada di tabel gizi, jadi angkanya '
                      'belum bisa dihitung.'
                : 'Sebagian makanan belum ada di tabel gizi, jadi angka '
                      'bertanda ≥ sebenarnya lebih besar.',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF8FA7A1),
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _NutrisiTidakAda extends StatelessWidget {
  const _NutrisiTidakAda();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAF7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.no_food_outlined,
            size: 16,
            color: Color(0xFF9CB1AC),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Rincian makanan tidak tersedia untuk sesi ini.',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B807B)),
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrisiMenganalisis extends StatelessWidget {
  const _NutrisiMenganalisis();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF0EAD69),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Menganalisis…',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Nutrisi menyusul, sesi tetap berjalan',
                style: TextStyle(fontSize: 11, color: Color(0xFF8FA7A1)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
