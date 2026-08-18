import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'gula_darah_detail_page.dart'
    show BarisNilaiSampel, JudulSesi, PesanTanpaSesi;
import 'kalibrasi_tekanan_darah_page.dart';
import 'models/sesi_makan.dart';
import 'utils/format_waktu.dart';
import 'widgets/judul_bagian.dart';
import 'widgets/kurva_sampel.dart';
import 'widgets/sparkline.dart';

/// Detail tekanan darah satu sesi: sistolik dan diastolik sebagai dua garis
/// yang digambar dari sampel, bukan dari path tetap (§7).
///
/// Di bawahnya: tren baseline antar sesi dan pintu masuk kalibrasi beserta
/// statusnya (§4.4). Alur kalibrasinya sendiri adalah langkah 7.
class TekananDarahDetailPage extends StatelessWidget {
  const TekananDarahDetailPage({super.key, this.sesi});

  final SesiMakan? sesi;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SesiMakanController>();
    final sesiTampil = sesi ?? controller.sesiTerakhir;

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
          'Tekanan Darah',
          style: TextStyle(
            color: Color(0xFF1E3A34),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        child: sesiTampil == null
            ? const PesanTanpaSesi()
            : _IsiTekananDarah(sesi: sesiTampil, semuaSesi: controller.riwayat),
      ),
    );
  }
}

class _IsiTekananDarah extends StatelessWidget {
  const _IsiTekananDarah({required this.sesi, required this.semuaSesi});

  final SesiMakan sesi;
  final List<SesiMakan> semuaSesi;

  @override
  Widget build(BuildContext context) {
    // Titik acuan halaman ini adalah kondisi sebelum makan.
    final baseline = sesi.sampel[0];

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
                        TextSpan(text: baseline.tekananDarah ?? tandaKosong),
                        const TextSpan(
                          text: ' mmHg',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            color: Color(0xFF6B807B),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Text(
                    'Baseline sebelum makan',
                    style: TextStyle(fontSize: 12, color: Color(0xFF7E9A94)),
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
                      Icons.speed_rounded,
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
            seri: const [seriSistolik, seriDiastolik],
            pesanKosong: 'Belum ada sampel tekanan darah',
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
              nilai: s.tekananDarah,
              satuan: 'mmHg',
            ),
          const SizedBox(height: 12),

          _TrenPerSesi(semuaSesi: semuaSesi),
          const SizedBox(height: 24),

          const _KartuKalibrasi(),
          const SizedBox(height: 24),

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
                        'Tekanan darah normal:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A34),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '90/60 - 120/80 mmHg',
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
                    Icons.speed_rounded,
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

/// Tren tekanan darah antar sesi: nilai baseline pra-makan tiap sesi, urut
/// lama → baru. Empat titik dalam satu sesi terlalu pendek untuk disebut tren,
/// jadi yang dibandingkan adalah sesi dengan sesi.
class _TrenPerSesi extends StatelessWidget {
  const _TrenPerSesi({required this.semuaSesi});

  final List<SesiMakan> semuaSesi;

  @override
  Widget build(BuildContext context) {
    // Urut lama → baru supaya sparkline terbaca kiri ke kanan.
    final urut = [...semuaSesi].reversed;
    final sistolik = <double>[];
    final diastolik = <double>[];
    for (final s in urut) {
      final dasar = s.sampel[0];
      if (!dasar.terisi || dasar.sistolik == null || dasar.diastolik == null) {
        continue;
      }
      sistolik.add(dasar.sistolik!.toDouble());
      diastolik.add(dasar.diastolik!.toDouble());
    }

    if (sistolik.length < 2) {
      return const SizedBox.shrink();
    }

    double rata(List<double> n) => n.reduce((a, b) => a + b) / n.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JudulBagian(
          ikon: Icons.show_chart_rounded,
          judul: 'Tren Antar Sesi',
          keterangan:
              'Baseline pra-makan ${sistolik.length} sesi terakhir · '
              'rata-rata ${rata(sistolik).round()}/'
              '${rata(diastolik).round()} mmHg',
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
          ),
          child: Column(
            children: [
              _garis('Sistolik', sistolik, const Color(0xFF0EAD69)),
              const SizedBox(height: 14),
              _garis('Diastolik', diastolik, const Color(0xFF7BE5C4)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _garis(String label, List<double> nilai, Color warna) {
    return Row(
      children: [
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B807B)),
          ),
        ),
        Expanded(
          child: SizedBox(
            height: 32,
            child: CustomPaint(
              painter: MiniSparklinePainter(
                colors: [warna, warna.withValues(alpha: 0.3)],
                nilai: nilai,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${nilai.last.round()}',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
      ],
    );
  }
}

/// Pintu masuk kalibrasi beserta statusnya (§4.4).
///
/// Statusnya dibaca dari controller: selama belum pernah dikalibrasi, yang
/// ditulis adalah "Belum pernah dikalibrasi" — bukan tanggal karangan (§8).
class _KartuKalibrasi extends StatelessWidget {
  const _KartuKalibrasi();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SesiMakanController>();
    final kalibrasi = controller.kalibrasiTerakhir;
    // Kedaluwarsa bukan sekadar "sudah lama": jam tetap mengoreksi memakai
    // angka lama itu, jadi statusnya diberi warna dan diletakkan di kalimat
    // pertama, bukan disamarkan jadi tanggal yang tinggal dihitung sendiri.
    final habis = controller.kalibrasiKedaluwarsa;
    final sisa = controller.sisaHariKalibrasi;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Color(0xFFE2F6F0),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              habis ? Icons.warning_amber_rounded : Icons.tune_rounded,
              size: 20,
              color: habis ? const Color(0xFFB4761E) : const Color(0xFF0EAD69),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kalibrasi Tekanan Darah',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A34),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  kalibrasi == null
                      ? 'Belum pernah dikalibrasi'
                      : habis
                      ? 'Kedaluwarsa — dikalibrasi '
                            '${formatWaktuRelatif(kalibrasi.waktu)}. Jam masih '
                            'memakai koreksi ${kalibrasi.ringkasanOffset}.'
                      : 'Koreksi ${kalibrasi.ringkasanOffset} untuk '
                            '${kalibrasi.sisi.label.toLowerCase()} · berlaku '
                            '$sisa hari lagi',
                  style: TextStyle(
                    fontSize: 11,
                    color: habis
                        ? const Color(0xFFB4761E)
                        : const Color(0xFF8FA7A1),
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const KalibrasiTekananDarahPage(),
              ),
            ),
            child: Text(
              kalibrasi == null
                  ? 'Kalibrasi'
                  : habis
                  ? 'Perbarui'
                  : 'Ulangi',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0EAD69),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
