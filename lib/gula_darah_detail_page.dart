import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'models/analisis_sesi.dart';
import 'models/sesi_makan.dart';
import 'utils/format_waktu.dart';
import 'utils/ikon.dart';
import 'widgets/judul_bagian.dart';
import 'widgets/kurva_sampel.dart';

/// Detail gula darah satu sesi.
///
/// Kurvanya digambar dari `List<Sampel>` lewat [KurvaSampel] — tidak ada lagi
/// path bezier hardcoded (§7) — dan di bawahnya ada kurva respons lintas sesi
/// yang ditumpuk plus rata-rata puncak, bagian paling bernilai dari ketiga
/// halaman detail (§4.4).
class GulaDarahDetailPage extends StatelessWidget {
  const GulaDarahDetailPage({super.key, this.sesi});

  /// Sesi yang ditampilkan; bila null dipakai sesi terakhir dari controller.
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
          'Gula Darah',
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
            : _IsiGulaDarah(sesi: sesiTampil, semuaSesi: controller.riwayat),
      ),
    );
  }
}

class _IsiGulaDarah extends StatelessWidget {
  const _IsiGulaDarah({required this.sesi, required this.semuaSesi});

  final SesiMakan sesi;
  final List<SesiMakan> semuaSesi;

  @override
  Widget build(BuildContext context) {
    final puncak = sesi.puncakGulaDarah;
    final delta = sesi.deltaPuncak;

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
                        TextSpan(text: puncak?.toString() ?? tandaKosong),
                        const TextSpan(
                          text: ' mg/dL',
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
                    delta == null
                        ? 'Puncak sesi ini'
                        : 'Puncak sesi ini · ${delta >= 0 ? '+' : ''}$delta '
                              'dari baseline',
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
                  children: [
                    Icon(
                      ikonKualitasRespons(sesi.kualitasRespons),
                      color: const Color(0xFF0EAD69),
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      sesi.kualitasRespons.label,
                      style: const TextStyle(
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
            seri: const [seriGulaDarah],
            garisAcuan: sesi.gulaDarahBaseline,
            pesanKosong: 'Belum ada sampel gula darah',
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
              nilai: s.gulaDarah?.toString(),
              satuan: 'mg/dL',
            ),
          const SizedBox(height: 12),

          _LintasSesi(semuaSesi: semuaSesi),
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
                        'Kadar gula darah normal (puasa):',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A34),
                        ),
                      ),
                      SizedBox(height: 6),
                      Text(
                        '70 - 130 mg/dL',
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
                    Icons.water_drop,
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

/// Bagian paling bernilai dari ketiga halaman detail (§4.4): kurva respons
/// seluruh sesi yang ditumpuk, plus rata-rata puncaknya.
class _LintasSesi extends StatelessWidget {
  const _LintasSesi({required this.semuaSesi});

  final List<SesiMakan> semuaSesi;

  @override
  Widget build(BuildContext context) {
    final analisis = AnalisisSesi(semuaSesi);
    final rataPuncak = analisis.rataPuncak;
    final rataDelta = analisis.rataDelta;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JudulBagian(
          ikon: Icons.stacked_line_chart_rounded,
          judul: 'Semua Sesi',
          keterangan: rataPuncak == null
              ? 'Belum ada puncak yang terukur'
              : 'Rata-rata puncak ${rataPuncak.round()} mg/dL'
                    '${rataDelta == null ? '' : ' · rata-rata kenaikan '
                              '+${rataDelta.round()} mg/dL'}',
        ),
        KurvaTumpukSesi(sesi: semuaSesi),
        const SizedBox(height: 8),
        const Text(
          'Tiap garis tipis satu sesi, digambar sebagai selisih dari '
          'baselinenya sendiri; garis tebal rata-ratanya.',
          style: TextStyle(fontSize: 10, color: Color(0xFF9CB1AC), height: 1.4),
        ),
      ],
    );
  }
}

/// Judul kecil yang menyebut sesi mana yang sedang dilihat — tanpa ini angka
/// di halaman detail kehilangan konteksnya (§2).
class JudulSesi extends StatelessWidget {
  const JudulSesi({super.key, required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    final waktu = sesi.t0 ?? sesi.waktuFoto;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              ikonWaktuMakan(sesi.waktuMakan),
              size: 14,
              color: const Color(0xFF0EAD69),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${sesi.labelWaktuMakan} · '
                '${sesi.hasil?.ringkasanNama ?? 'Makanan'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          '${formatTanggal(waktu)} · ${formatJam(waktu)} · '
          '${formatWaktuRelatif(waktu)}',
          style: const TextStyle(fontSize: 11, color: Color(0xFF8FA7A1)),
        ),
      ],
    );
  }
}

/// Satu baris nilai per titik pengukuran. Nilai yang tidak ada ditulis `—`.
class BarisNilaiSampel extends StatelessWidget {
  const BarisNilaiSampel({
    super.key,
    required this.sampel,
    required this.t0,
    required this.nilai,
    required this.satuan,
  });

  final Sampel sampel;
  final DateTime? t0;
  final String? nilai;
  final String satuan;

  @override
  Widget build(BuildContext context) {
    final ada = sampel.terisi && nilai != null;
    final jadwal = t0 == null ? null : sampel.waktuUkur(t0!);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: ada ? const Color(0xFF0EAD69) : const Color(0xFF9CB1AC),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              sampel.label,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A34),
              ),
            ),
          ),
          if (jadwal != null)
            Text(
              formatJam(jadwal),
              style: const TextStyle(fontSize: 11, color: Color(0xFF8FA7A1)),
            ),
          const SizedBox(width: 12),
          Text(
            ada ? '$nilai $satuan' : tandaKosong,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: ada ? const Color(0xFF1E3A34) : const Color(0xFF9CB1AC),
            ),
          ),
        ],
      ),
    );
  }
}

/// Halaman detail hanya bermakna dalam konteks sebuah sesi; tanpa sesi
/// katakan apa adanya, jangan tampilkan kurva kosong.
class PesanTanpaSesi extends StatelessWidget {
  const PesanTanpaSesi({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: const [
            Icon(Icons.insights_rounded, size: 48, color: Color(0xFF8FA7A1)),
            SizedBox(height: 12),
            Text(
              'Belum ada sesi yang selesai',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A34),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Jam hanya mengukur saat sesi makan, jadi grafik ini terisi '
              'setelah sesi pertamamu selesai.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF7E9A94)),
            ),
          ],
        ),
      ),
    );
  }
}
