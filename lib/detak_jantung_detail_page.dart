import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'gula_darah_detail_page.dart' show BarisNilaiSampel, JudulSesi, PesanTanpaSesi;
import 'models/sesi_makan.dart';
import 'utils/format_waktu.dart';
import 'widgets/judul_bagian.dart';
import 'widgets/kurva_sampel.dart';

/// Detail detak jantung satu sesi.
///
/// Isinya memang paling tipis — hanya 4 titik per sesi — dan rancangan §4.4
/// meminta prominensinya diturunkan, bukan dihapus. Yang berubah di langkah 4
/// adalah kurvanya: digambar dari sampel, tanpa path bezier hardcoded (§7).
class DetakJantungDetailPage extends StatelessWidget {
  const DetakJantungDetailPage({super.key, this.sesi});

  final SesiMakan? sesi;

  @override
  Widget build(BuildContext context) {
    final sesiTampil =
        sesi ?? context.watch<SesiMakanController>().sesiTerakhir;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A34)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Detak Jantung',
          style: TextStyle(
            color: Color(0xFF1E3A34),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: sesiTampil == null
          ? const PesanTanpaSesi()
          : _IsiDetakJantung(sesi: sesiTampil),
    );
  }
}

class _IsiDetakJantung extends StatelessWidget {
  const _IsiDetakJantung({required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    final nilai = [
      for (final s in sesi.sampel)
        if (s.terisi && s.detakJantung != null) s.detakJantung!,
    ];
    final tertinggi = nilai.isEmpty
        ? null
        : nilai.reduce((a, b) => a > b ? a : b);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          JudulSesi(sesi: sesi),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A34),
                      ),
                      children: [
                        TextSpan(text: tertinggi?.toString() ?? tandaKosong),
                        const TextSpan(
                          text: ' bpm',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            color: Color(0xFF6B807B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    nilai.isEmpty
                        ? 'Belum ada pengukuran di sesi ini'
                        : 'Tertinggi dari ${nilai.length} titik sesi ini',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7E9A94),
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F6F0),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.favorite_rounded,
                      color: Color(0xFF0EAD69),
                      size: 16,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Per sesi',
                      style: TextStyle(
                        color: Color(0xFF0EAD69),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          KurvaSampel(
            sampel: sesi.sampel,
            seri: const [seriDetakJantung],
            tinggi: 170,
            pesanKosong: 'Belum ada sampel detak jantung',
          ),
          const SizedBox(height: 24),

          const JudulBagian(
            ikon: Icons.timeline_rounded,
            judul: 'Nilai Tiap Titik',
          ),
          for (final s in sesi.sampel)
            BarisNilaiSampel(
              sampel: s,
              t0: sesi.t0,
              nilai: s.detakJantung?.toString(),
              satuan: 'bpm',
            ),
          const SizedBox(height: 12),

          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE2F6F0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Detak jantung istirahat normal:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A34),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '60 - 100 bpm',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0EAD69),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Color(0xFF0EAD69),
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
