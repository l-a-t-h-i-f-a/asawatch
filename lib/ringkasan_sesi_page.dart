import 'package:flutter/material.dart';

import 'detak_jantung_detail_page.dart';
import 'gula_darah_detail_page.dart';
import 'models/sesi_makan.dart';
import 'sesi_berjalan_page.dart';
import 'tekanan_darah_detail_page.dart';
import 'utils/format_waktu.dart';
import 'utils/ikon.dart';
import 'utils/warna_respons.dart';
import 'widgets/foto_makanan.dart';
import 'widgets/judul_bagian.dart';
import 'widgets/kurva_sampel.dart';
import 'widgets/lencana_kualitas.dart';
import 'widgets/ringkasan_nutrisi.dart';
import 'widgets/timeline_sampel.dart';

/// Hasil satu sesi (§5): kurva respons, puncak, delta dari baseline, waktu
/// pemulihan, dan verdict berbahasa Indonesia.
///
/// Tujuan halaman ini adalah memberi konteks pada angka: gula darah 140 tidak
/// berarti apa-apa tanpa "1 jam setelah makan 45 g karbohidrat" (§2). Karena
/// itu urutannya: jawaban dulu (kartu hasil), lalu buktinya (kurva, nutrisi),
/// baru datanya (detail tiap titik, yang dilipat karena paling jarang dibaca).
class RingkasanSesiPage extends StatelessWidget {
  const RingkasanSesiPage({super.key, required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    final t0 = sesi.t0;
    final pemulihan = sesi.waktuPemulihan;
    final delta = sesi.deltaPuncak;
    final baseline = sesi.gulaDarahBaseline;
    final terukur = sesi.sampelTerisi.length;

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
          'Ringkasan Sesi',
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
            // Satu kartu yang menjawab "sesi ini bagaimana": identitas sesi,
            // angka intinya, dan kalimatnya — tidak lagi terpencar.
            _KartuHasil(sesi: sesi),
            const SizedBox(height: 16),

            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _KotakNilai(
                    ikon: Icons.arrow_upward_rounded,
                    label: 'Puncak',
                    nilai: sesi.puncakGulaDarah?.toString() ?? tandaKosong,
                    satuan: sesi.sampelPuncak == null
                        ? 'mg/dL'
                        : 'mg/dL di ${sesi.sampelPuncak!.label.toLowerCase()}',
                  ),
                  const SizedBox(width: 12),
                  _KotakNilai(
                    ikon: Icons.swap_vert_rounded,
                    label: 'Delta',
                    nilai: delta == null
                        ? tandaKosong
                        : '${delta >= 0 ? '+' : ''}$delta',
                    satuan: baseline == null
                        ? 'dari baseline'
                        : 'mg/dL dari $baseline',
                  ),
                  const SizedBox(width: 12),
                  _KotakNilai(
                    ikon: Icons.restart_alt_rounded,
                    label: 'Pemulihan',
                    nilai: pemulihan == null
                        ? tandaKosong
                        : formatDurasiRingkas(pemulihan),
                    satuan: pemulihan == null ? 'belum kembali' : 'setelah t0',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            JudulBagian(
              ikon: ikonGulaDarah,
              judul: 'Respons Gula Darah',
              keterangan: [
                '$terukur dari ${sesi.sampel.length} titik terukur',
                if (baseline != null) 'baseline $baseline mg/dL',
              ].join(' · '),
            ),
            KurvaSampel(
              sampel: sesi.sampel,
              seri: const [seriGulaDarah],
              garisAcuan: baseline,
              pesanKosong: 'Belum ada sampel gula darah',
            ),
            const SizedBox(height: 24),

            const JudulBagian(
              ikon: Icons.restaurant_menu_rounded,
              judul: 'Nutrisi Sesi Ini',
              keterangan: 'Yang masuk sebelum kurva di atas terbentuk',
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  RingkasanNutrisi(hasil: sesi.hasil),
                  if (sesi.hasil != null) ...[
                    const SizedBox(height: 16),
                    _KaitanKarbo(sesi: sesi),
                    const SizedBox(height: 12),
                    _CatatanKeyakinan(hasil: sesi.hasil!),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Data mentahnya tetap ada, tetapi dilipat: yang dicari orang saat
            // membuka sesi lama adalah jawabannya, bukan 16 angka.
            _DetailTitik(sesi: sesi, t0: t0),
            const SizedBox(height: 24),

            const JudulBagian(
              ikon: Icons.insights_rounded,
              judul: 'Telusuri Metrik',
              keterangan: 'Bandingkan sesi ini dengan sesi lain',
            ),
            _PintuMetrik(sesi: sesi),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Kartu hasil: identitas sesi, angka inti, dan verdict dalam satu blok.
///
/// Warnanya mengikuti kualitas respons — sesi "Lonjakan" tidak boleh terlihat
/// setenang sesi "Landai", yang sebelumnya terjadi karena kartu ini selalu
/// hijau.
class _KartuHasil extends StatelessWidget {
  const _KartuHasil({required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    final t0 = sesi.t0;
    final delta = sesi.deltaPuncak;
    final baseline = sesi.gulaDarahBaseline;
    final warna = warnaKualitas(sesi.kualitasRespons);
    final aktif = sesi.status.sedangAktif;
    final jadwal = sesi.jadwalBerikutnya;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: warna.latar,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FotoMakanan(
                fotoPath: sesi.fotoPath,
                lebar: 56,
                tinggi: 56,
                radius: 14,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sesi.hasil?.ringkasanNama ?? 'Makanan',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A34),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          ikonWaktuMakan(sesi.waktuMakan),
                          size: 12,
                          color: const Color(0xFF6B807B),
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            t0 == null
                                ? formatTanggal(sesi.waktuFoto)
                                : '${formatJam(t0)} · '
                                      '${formatWaktuRelatif(t0)} · '
                                      '${sesi.labelWaktuMakan}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B807B),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LencanaKualitas(kualitas: sesi.kualitasRespons),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(height: 1, color: Colors.white),
          const SizedBox(height: 14),

          // Angka inti hanya ditulis besar bila sesinya memang sudah selesai
          // dan datanya cukup; sisanya jujur menyebut statusnya (§8).
          if (!aktif && delta != null) ...[
            RichText(
              text: TextSpan(
                style: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.bold,
                  color: warna.teks,
                  height: 1.1,
                ),
                children: [
                  TextSpan(text: '${delta >= 0 ? '+' : ''}$delta'),
                  const TextSpan(
                    text: '  mg/dL',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B807B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'kenaikan puncak dari baseline $baseline mg/dL',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B807B)),
            ),
            const SizedBox(height: 10),
          ] else ...[
            Row(
              children: [
                Icon(ikonStatusSesi(sesi.status), size: 16, color: warna.teks),
                const SizedBox(width: 8),
                Text(
                  sesi.status.label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: warna.teks,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
          ],

          Text(
            sesi.verdict,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E3A34),
              height: 1.4,
            ),
          ),

          // Sesi yang masih berjalan tidak berpura-pura sudah punya hasil:
          // yang ditawarkan adalah jalan kembali ke layar sesi berjalan.
          if (aktif) ...[
            const SizedBox(height: 14),
            if (jadwal != null && sesi.sampelBerikutnya != null)
              Row(
                children: [
                  const Icon(
                    Icons.schedule_rounded,
                    size: 14,
                    color: Color(0xFF6B807B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Titik berikutnya: ${sesi.sampelBerikutnya!.label}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B807B),
                      ),
                    ),
                  ),
                  HitungMundur(target: jadwal),
                ],
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SesiBerjalanPage()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EAD69),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Buka Sesi Berjalan',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _KotakNilai extends StatelessWidget {
  const _KotakNilai({
    required this.ikon,
    required this.label,
    required this.nilai,
    required this.satuan,
  });

  final IconData ikon;
  final String label;
  final String nilai;
  final String satuan;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(ikon, size: 12, color: const Color(0xFF8FA7A1)),
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
            const SizedBox(height: 6),
            Text(
              nilai,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A34),
              ),
            ),
            const SizedBox(height: 2),
            Text(
              satuan,
              style: const TextStyle(fontSize: 10, color: Color(0xFF9CB1AC)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bagian "Detail Tiap Titik" yang dapat dilipat.
///
/// Isinya empat kartu penuh angka — berguna, tapi bukan yang dicari saat sesi
/// dibuka. Dilipat secara default supaya kurva, nutrisi, dan pintu metrik
/// muat dalam satu layar gulir.
class _DetailTitik extends StatefulWidget {
  const _DetailTitik({required this.sesi, required this.t0});

  final SesiMakan sesi;
  final DateTime? t0;

  @override
  State<_DetailTitik> createState() => _DetailTitikState();
}

class _DetailTitikState extends State<_DetailTitik> {
  bool _terbuka = false;

  @override
  Widget build(BuildContext context) {
    final sesi = widget.sesi;
    final terlewat = sesi.sampel
        .where((s) => s.status == StatusSampel.terlewat)
        .length;
    final tertunda = sesi.sampel
        .where((s) => s.status == StatusSampel.menunggu)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JudulBagian(
          ikon: Icons.timeline_rounded,
          judul: 'Detail Tiap Titik',
          keterangan: [
            '${sesi.sampelTerisi.length} dari ${sesi.sampel.length} terukur',
            if (terlewat > 0) '$terlewat terlewat',
            if (tertunda > 0) '$tertunda menunggu',
          ].join(' · '),
          aksi: TextButton.icon(
            onPressed: () => setState(() => _terbuka = !_terbuka),
            icon: Icon(
              _terbuka
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              size: 18,
              color: const Color(0xFF0EAD69),
            ),
            label: Text(
              _terbuka ? 'Sembunyikan' : 'Lihat',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0EAD69),
              ),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ),
        if (_terbuka)
          for (final s in sesi.sampel) _KartuSampel(sampel: s, t0: widget.t0),
      ],
    );
  }
}

/// Satu titik pengukuran beserta seluruh metriknya. Metrik yang tidak
/// berhasil diukur ditulis `—` (§8).
class _KartuSampel extends StatelessWidget {
  const _KartuSampel({required this.sampel, required this.t0});

  final Sampel sampel;
  final DateTime? t0;

  @override
  Widget build(BuildContext context) {
    final waktu = t0 == null ? null : sampel.waktuUkur(t0!);
    final terlewat = sampel.status == StatusSampel.terlewat;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
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
              Text(
                [
                  if (waktu != null) formatJam(waktu),
                  if (waktu != null) formatWaktuRelatif(waktu),
                  if (terlewat) 'terlewat',
                  if (sampel.dariBuffer) 'dari buffer',
                ].join(' · '),
                style: TextStyle(
                  fontSize: 10,
                  color: terlewat ? Colors.red : const Color(0xFF8FA7A1),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _metrik('Gula', sampel.gulaDarah?.toString(), 'mg/dL'),
              _metrik('Jantung', sampel.detakJantung?.toString(), 'bpm'),
              _metrik('Tekanan', sampel.tekananDarah, 'mmHg'),
              _metrik('SpO2', sampel.spo2?.toString(), '%'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _metrik(String label, String? nilai, String satuan) {
    final ada = nilai != null;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF8FA7A1)),
          ),
          const SizedBox(height: 3),
          Text(
            ada ? nilai : tandaKosong,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: ada ? const Color(0xFF1E3A34) : const Color(0xFF9CB1AC),
            ),
          ),
          if (ada)
            Text(
              satuan,
              style: const TextStyle(fontSize: 9, color: Color(0xFF9CB1AC)),
            ),
        ],
      ),
    );
  }
}

/// Kalimat yang menyambungkan karbohidrat yang masuk dengan lonjakan yang
/// terjadi — inti nilai aplikasi ini (§2), yang sebelumnya harus disimpulkan
/// sendiri oleh user dari dua bagian layar yang berjauhan.
class _KaitanKarbo extends StatelessWidget {
  const _KaitanKarbo({required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    final hasil = sesi.hasil;
    final delta = sesi.deltaPuncak;
    if (hasil == null) return const SizedBox.shrink();

    final karbo = formatAngka(hasil.total.karbohidrat);
    final teks = delta == null
        ? '$karbo g karbohidrat · responsnya belum bisa dinilai'
        : '$karbo g karbohidrat → puncak '
              '${delta >= 0 ? '+' : ''}$delta mg/dL '
              '(indeks glikemik ${hasil.indeksGlikemikPerkiraan})';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAF7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.compare_arrows_rounded,
            size: 16,
            color: Color(0xFF0EAD69),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF1E3A34),
                height: 1.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Keyakinan deteksi menentukan apakah sesi ini ikut diplot di Analisis
/// (§4.3), jadi ditampilkan apa adanya.
class _CatatanKeyakinan extends StatelessWidget {
  const _CatatanKeyakinan({required this.hasil});

  final HasilDeteksi hasil;

  @override
  Widget build(BuildContext context) {
    final persen = (hasil.keyakinan * 100).round();
    final teks = hasil.dikoreksiUser
        ? 'Porsi sudah dikoreksi user'
        : 'Keyakinan deteksi $persen%';

    return Row(
      children: [
        Icon(
          hasil.dikoreksiUser
              ? Icons.edit_note_rounded
              : Icons.auto_awesome_rounded,
          size: 16,
          color: const Color(0xFF0EAD69),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            teks,
            style: const TextStyle(fontSize: 11, color: Color(0xFF6B807B)),
          ),
        ),
      ],
    );
  }
}

/// Tiga pintu ke halaman detail metrik, membawa sesi ini sebagai konteksnya.
class _PintuMetrik extends StatelessWidget {
  const _PintuMetrik({required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _tombol(
          context,
          ikon: ikonGulaDarah,
          label: 'Gula Darah',
          halaman: () => GulaDarahDetailPage(sesi: sesi),
        ),
        const SizedBox(width: 10),
        _tombol(
          context,
          ikon: ikonTekananDarah,
          label: 'Tekanan',
          halaman: () => TekananDarahDetailPage(sesi: sesi),
        ),
        const SizedBox(width: 10),
        _tombol(
          context,
          ikon: ikonDetakJantung,
          label: 'Jantung',
          halaman: () => DetakJantungDetailPage(sesi: sesi),
        ),
      ],
    );
  }

  Widget _tombol(
    BuildContext context, {
    required IconData ikon,
    required String label,
    required Widget Function() halaman,
  }) {
    final bentuk = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFE2EBE8), width: 1.2),
    );

    return Expanded(
      child: Material(
        color: Colors.white,
        shape: bentuk,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => halaman()),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                Icon(ikon, size: 18, color: const Color(0xFF0EAD69)),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A34),
                  ),
                ),
                const SizedBox(height: 2),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: Color(0xFF9CB1AC),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
