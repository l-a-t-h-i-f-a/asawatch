import 'package:flutter/material.dart';

import '../models/sesi_makan.dart';

/// Peringatan gula darah rendah pada sesi puasa.
///
/// Tampil begitu **satu** titik terbaca di bawah [ambangGulaRendah], selagi
/// sesi masih berjalan — gula yang sudah rendah tidak menunggu sesi selesai
/// untuk menjadi penting — dan tetap tampil di ringkasannya.
///
/// Kalimatnya sengaja **tidak memerintah**. Gula darah dari jam adalah
/// perkiraan optik, bukan hasil tusuk jari; memerintahkan orang membatalkan
/// puasanya berdasarkan angka itu saja adalah keputusan medis yang tidak
/// boleh diambil sebuah perkiraan. Yang dikatakan: pastikan dengan alat cek
/// gula darah, pertimbangkan membatalkan puasa, dan kenali tanda bahayanya.
///
/// Menggambar dirinya kosong bila tidak ada yang perlu diperingatkan, supaya
/// pemanggil cukup menaruhnya tanpa syarat.
class PeringatanGulaRendah extends StatelessWidget {
  const PeringatanGulaRendah({super.key, required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    if (!sesi.puasa) return const SizedBox.shrink();
    final kondisi = sesi.kondisiPuasa;
    if (!kondisi.perluPerhatian) return const SizedBox.shrink();

    final sangat = kondisi == KondisiPuasa.sangatRendah;
    final aksen = sangat ? const Color(0xFFC0392B) : const Color(0xFFB4761E);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sangat ? const Color(0xFFFDECEA) : const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: sangat ? const Color(0xFFF2B8B0) : const Color(0xFFF0D9B5),
          width: 1.5,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: aksen, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${sangat ? 'Gula darah sangat rendah' : 'Gula darah rendah'}'
                  ' · ${sesi.gulaTerendah} mg/dL',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: aksen,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Angka dari jam adalah perkiraan. Pastikan dengan alat cek '
                  'gula darah, dan pertimbangkan membatalkan puasa.',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: sangat
                        ? const Color(0xFF7A2318)
                        : const Color(0xFF6B4E1E),
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Bila lemas, gemetar, pusing, atau berkeringat dingin, '
                  'segera minum atau makan yang manis dan hubungi tenaga '
                  'kesehatan.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF6B807B),
                    height: 1.4,
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
