import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'detak_jantung_detail_page.dart';
import 'gula_darah_detail_page.dart';
import 'models/analisis_sesi.dart';
import 'tekanan_darah_detail_page.dart';
import 'utils/format_waktu.dart';
import 'utils/ikon.dart';
import 'widgets/judul_bagian.dart';
import 'widgets/sebaran_karbo.dart';

/// Analisis menjawab pertanyaan yang datanya kini nyata (§4.3), menggantikan
/// toggle Mingguan/Bulanan yang isinya hardcoded (§7):
///
/// 1. apakah karbohidrat yang terdeteksi berhubungan dengan kenaikan gula darah,
/// 2. makanan mana yang paling memicu lonjakan,
/// 3. apakah pemulihan membaik dari waktu ke waktu.
///
/// Tab ini juga menjadi pintu masuk ke tiga halaman detail metrik, karena
/// dashboard vital di Beranda sudah dihapus (§4.4).
class AnalisisTab extends StatelessWidget {
  const AnalisisTab({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SesiMakanController>();
    final analisis = AnalisisSesi(controller.riwayat);

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Analisis',
          style: TextStyle(
            color: Color(0xFF1E3A34),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (analisis.kosong)
              const _AnalisisKosong()
            else ...[
              _KartuSebaran(analisis: analisis),
              const SizedBox(height: 24),
              _KartuPemicu(analisis: analisis),
              const SizedBox(height: 24),
              _KartuPemulihan(analisis: analisis),
              const SizedBox(height: 24),
            ],
            const _PintuDetailMetrik(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _AnalisisKosong extends StatelessWidget {
  const _AnalisisKosong();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
      ),
      child: Column(
        children: const [
          Icon(Icons.insights_rounded, size: 40, color: Color(0xFF8FA7A1)),
          SizedBox(height: 12),
          Text(
            'Belum ada sesi untuk dianalisis',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A34),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Setiap sesi makan yang selesai menambah satu titik di sini.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: Color(0xFF7E9A94)),
          ),
        ],
      ),
    );
  }
}

class _KartuSebaran extends StatelessWidget {
  const _KartuSebaran({required this.analisis});

  final AnalisisSesi analisis;

  @override
  Widget build(BuildContext context) {
    final tren = analisis.tren;
    final dikecualikan = analisis.jumlahDikecualikan;

    final String kalimat;
    if (tren == null) {
      kalimat =
          'Butuh lebih banyak sesi dengan deteksi nutrisi yang meyakinkan '
          'sebelum hubungannya bisa disimpulkan.';
    } else {
      final per10 = (tren.kemiringan * 10).round();
      kalimat = tren.meyakinkan
          ? 'Tiap tambahan 10 g karbohidrat, gula darahmu naik sekitar '
                '$per10 mg/dL lebih tinggi.'
          : 'Sebarannya masih longgar — kenaikan gula darahmu belum jelas '
                'mengikuti jumlah karbohidrat.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JudulBagian(
          ikon: Icons.scatter_plot_rounded,
          judul: 'Karbohidrat vs Kenaikan Gula Darah',
          keterangan:
              '${analisis.titikSebaran.length} sesi · satu titik per sesi',
        ),
        SebaranKarboGula(titik: analisis.titikSebaran, tren: tren),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: const Color(0xFFE2F6F0),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text(
            kalimat,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF1E3A34),
              height: 1.4,
            ),
          ),
        ),
        if (dikecualikan > 0) ...[
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.radio_button_unchecked,
                size: 14,
                color: Color(0xFF9CB1AC),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$dikecualikan sesi digambar sebagai lingkaran kosong dan '
                  'tidak ikut garis tren: keyakinan deteksi porsinya rendah.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF7E9A94),
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _KartuPemicu extends StatelessWidget {
  const _KartuPemicu({required this.analisis});

  final AnalisisSesi analisis;

  @override
  Widget build(BuildContext context) {
    final pemicu = analisis.pemicuTeratas.take(4).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const JudulBagian(
          ikon: Icons.local_fire_department_rounded,
          judul: 'Paling Memicu Lonjakan',
          keterangan: 'Rata-rata kenaikan per makanan',
        ),
        if (pemicu.isEmpty)
          const Text(
            'Belum ada makanan dengan deteksi yang cukup meyakinkan.',
            style: TextStyle(fontSize: 12, color: Color(0xFF7E9A94)),
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
            ),
            child: Column(
              children: [
                for (final (i, p) in pemicu.indexed)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: i == 0
                                ? const Color(0xFFFFEBEE)
                                : const Color(0xFFE5EDE9),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            '${i + 1}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: i == 0
                                  ? Colors.red
                                  : const Color(0xFF6B807B),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                p.nama,
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A34),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${formatAngka(p.rataKarbohidrat)} g karbo · '
                                '${p.jumlahSesi} sesi',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF8FA7A1),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          '+${p.rataDelta.round()} mg/dL',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A34),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _KartuPemulihan extends StatelessWidget {
  const _KartuPemulihan({required this.analisis});

  final AnalisisSesi analisis;

  @override
  Widget build(BuildContext context) {
    final rekap = analisis.rekapPemulihan;
    final selisih = analisis.selisihProporsiPemulihan;

    final String kabar;
    if (selisih == null) {
      kabar = 'Perbandingan antar periode baru bisa dibuat setelah empat sesi.';
    } else if (selisih > 0.01) {
      kabar =
          'Membaik: sesi-sesi terbarumu lebih sering kembali ke baseline '
          'dibanding sebelumnya.';
    } else if (selisih < -0.01) {
      kabar =
          'Menurun: sesi-sesi terbarumu lebih jarang kembali ke baseline '
          'dibanding sebelumnya.';
    } else {
      kabar = 'Stabil: proporsinya sama dengan periode sebelumnya.';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const JudulBagian(
          ikon: Icons.restart_alt_rounded,
          judul: 'Waktu Pemulihan',
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A34),
                  ),
                  children: [
                    TextSpan(text: '${rekap.pulih} dari ${rekap.total}'),
                    const TextSpan(
                      text: ' sesi',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.normal,
                        color: Color(0xFF6B807B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'kembali ke sekitar baseline dalam 2 jam',
                style: TextStyle(fontSize: 11, color: Color(0xFF8FA7A1)),
              ),
              const SizedBox(height: 12),
              Text(
                kabar,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B807B),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Pintu masuk ke halaman detail metrik. Sejak kartu vital "sekarang" dihapus
/// dari Beranda, di sinilah (dan di Ringkasan Sesi) ketiganya dijangkau.
class _PintuDetailMetrik extends StatelessWidget {
  const _PintuDetailMetrik();

  @override
  Widget build(BuildContext context) {
    // Metrik yang jam ini tidak punya tidak diberi pintu: halamannya hanya akan
    // berisi `—` dari atas ke bawah, dan itu terbaca sebagai aplikasi yang rusak
    // atau pengukuran yang gagal — bukan sebagai sensor yang memang tidak ada
    // (docs/protokol-jam.md §3).
    final kemampuan = context
        .watch<SesiMakanController>()
        .statusPerangkat
        .metrikTampil;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const JudulBagian(
          ikon: Icons.travel_explore_rounded,
          judul: 'Telusuri per Metrik',
        ),
        if (kemampuan.gulaDarah)
          _baris(
            context,
            ikon: ikonGulaDarah,
            judul: 'Gula Darah',
            keterangan: 'Kurva respons semua sesi dan rata-rata puncak',
            halaman: () => const GulaDarahDetailPage(),
          ),
        if (kemampuan.tekananDarah)
          _baris(
            context,
            ikon: ikonTekananDarah,
            judul: 'Tekanan Darah',
            keterangan: 'Tren per sesi dan status kalibrasi',
            halaman: () => const TekananDarahDetailPage(),
          ),
        _baris(
          context,
          ikon: ikonDetakJantung,
          judul: 'Detak Jantung',
          keterangan: 'Empat titik per sesi',
          halaman: () => const DetakJantungDetailPage(),
        ),
      ],
    );
  }

  Widget _baris(
    BuildContext context, {
    required IconData ikon,
    required String judul,
    required String keterangan,
    required Widget Function() halaman,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => halaman()),
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  color: Color(0xFFE2F6F0),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(ikon, size: 18, color: const Color(0xFF0EAD69)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      judul,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A34),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      keterangan,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8FA7A1),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8FA7A1)),
            ],
          ),
        ),
      ),
    );
  }
}
