import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';

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
///
/// **Urutan itu tidak berubah; tata letaknya yang dirombak.** Tiga hal yang
/// diperbaiki, dan ketiganya soal hirarki, bukan hiasan:
///
/// 1. **Satu kartu tidak lagi mengerjakan delapan hal.** Identitas sesi (foto,
///    nama, jam) keluar menjadi baris tipis tanpa kartu, sehingga kartu berwarna
///    di bawahnya hanya menjawab satu pertanyaan — "sesi ini bagaimana" — dan
///    angka besarnya tidak lagi bersaing dengan foto dan lencana di kartu yang
///    sama.
/// 2. **Angka utamanya benar-benar utama.** Delta naik dari 34 ke 46 px dan
///    berdiri sendiri; satu halaman hanya boleh punya satu angka sebesar itu.
/// 3. **Tidak ada angka yang ditulis dua kali.** Sebelumnya delta muncul sebagai
///    angka besar **dan** sebagai satu dari tiga kotak nilai. Kotak itu kini diisi
///    **baseline**, yang sebelumnya hanya terselip di keterangan kecil — sehingga
///    ketiganya membaca sebagai satu kalimat kiri ke kanan: mulai dari mana,
///    setinggi apa, berapa lama kembali.
class RingkasanSesiPage extends StatelessWidget {
  const RingkasanSesiPage({super.key, required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    final t0 = sesi.t0;
    final pemulihan = sesi.waktuPemulihan;
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
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Identitas sesi berdiri sendiri, tanpa kartu: "makanan apa, jam
              // berapa" adalah pertanyaan yang berbeda dari "hasilnya bagaimana",
              // dan menumpuk keduanya dalam satu kotak berwarna membuat angka
              // utamanya harus bersaing dengan foto.
              _KepalaSesi(sesi: sesi),
              const SizedBox(height: 16),

              _KartuHasil(sesi: sesi),
              const SizedBox(height: 16),

              // Dibaca kiri ke kanan sebagai satu kalimat: mulai dari mana,
              // setinggi apa, berapa lama kembali. Delta sengaja tidak ada di
              // sini — ia sudah menjadi angka besar di kartu atas, dan angka yang
              // sama ditulis dua kali membuat keduanya terasa kurang penting.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _KotakNilai(
                      ikon: Icons.trip_origin_rounded,
                      label: 'Baseline',
                      nilai: baseline?.toString() ?? tandaKosong,
                      satuan: baseline == null
                          ? 'belum terukur'
                          : 'mg/dL sebelum makan',
                    ),
                    const SizedBox(width: 10),
                    _KotakNilai(
                      ikon: Icons.arrow_upward_rounded,
                      label: 'Puncak',
                      nilai: sesi.puncakGulaDarah?.toString() ?? tandaKosong,
                      satuan: sesi.sampelPuncak == null
                          ? 'mg/dL'
                          : 'mg/dL di ${sesi.sampelPuncak!.label.toLowerCase()}',
                    ),
                    const SizedBox(width: 10),
                    _KotakNilai(
                      ikon: Icons.restart_alt_rounded,
                      label: 'Pemulihan',
                      nilai: pemulihan == null
                          ? tandaKosong
                          : formatDurasiRingkas(pemulihan),
                      satuan: pemulihan == null
                          ? 'belum kembali'
                          : 'setelah t0',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

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

              // Hanya bila jam ini memang punya sensornya **dan** ada angkanya.
              // Kurva kosong berjudul "Oksigen" pada jam tanpa pulse oximeter
              // adalah persis yang §3 protokol larang.
              _KurvaSpo2(sesi: sesi),

              const JudulBagian(
                ikon: Icons.restaurant_menu_rounded,
                judul: 'Nutrisi Sesi Ini',
                keterangan: 'Yang masuk sebelum kurva di atas terbentuk',
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFE2EBE8),
                    width: 1.5,
                  ),
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
      ),
    );
  }
}

/// Identitas sesi: foto, nama makanan, dan kapan.
///
/// Sengaja **tanpa kartu**. Ia menjawab "makanan yang mana", bukan "hasilnya
/// bagaimana", dan memberinya bingkai sendiri membuat halaman ini dibuka dengan
/// dua kotak yang sama beratnya sebelum satu angka pun terbaca.
class _KepalaSesi extends StatelessWidget {
  const _KepalaSesi({required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    final t0 = sesi.t0;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FotoMakanan(fotoPath: sesi.fotoPath, lebar: 56, tinggi: 56, radius: 18),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sesi.hasil?.ringkasanNama ?? 'Makanan',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                ),
              ),
              const SizedBox(height: 5),
              Row(
                children: [
                  Icon(
                    ikonWaktuMakan(sesi.waktuMakan),
                    size: 13,
                    color: const Color(0xFF8FA7A1),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      t0 == null
                          ? formatTanggal(sesi.waktuFoto)
                          : '${formatJam(t0)} · '
                                '${formatWaktuRelatif(t0)} · '
                                '${sesi.labelWaktuMakan}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF7E9A94),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Kartu hasil: satu pertanyaan, satu jawaban.
///
/// Warnanya mengikuti kualitas respons — sesi "Lonjakan" tidak boleh terlihat
/// setenang sesi "Landai", yang sebelumnya terjadi karena kartu ini selalu
/// hijau. Warnanya **tidak pernah sendirian**: lencana di atas membawa ikon dan
/// katanya, jadi keadaan sesi tetap terbaca tanpa membedakan warna.
class _KartuHasil extends StatelessWidget {
  const _KartuHasil({required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    final delta = sesi.deltaPuncak;
    final baseline = sesi.gulaDarahBaseline;
    final warna = warnaKualitas(sesi.kualitasRespons);
    final aktif = sesi.status.sedangAktif;
    final jadwal = sesi.jadwalBerikutnya;
    final adaAngka = !aktif && delta != null;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: warna.latar,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LencanaKualitas(
            kualitas: sesi.kualitasRespons,
            ukuranTeks: 11,
            diAtasLatarBerwarna: true,
          ),
          const SizedBox(height: 14),

          // Angka inti hanya ditulis besar bila sesinya memang sudah selesai
          // dan datanya cukup; sisanya jujur menyebut statusnya (§8).
          if (adaAngka) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                // Satu-satunya angka sebesar ini di seluruh halaman. Kalau nanti
                // ada yang kedua, keduanya berhenti menjadi jawaban.
                Text(
                  '${delta >= 0 ? '+' : ''}$delta',
                  style: TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.bold,
                    color: warna.teks,
                    height: 1.05,
                  ),
                ),
                const SizedBox(width: 8),
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'mg/dL',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B807B),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(
              baseline == null
                  ? 'kenaikan puncak dari baseline'
                  : 'kenaikan puncak dari baseline $baseline mg/dL',
              style: const TextStyle(fontSize: 11.5, color: Color(0xFF6B807B)),
            ),
          ] else ...[
            Row(
              children: [
                Icon(ikonStatusSesi(sesi.status), size: 17, color: warna.teks),
                const SizedBox(width: 8),
                Text(
                  sesi.status.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: warna.teks,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 14),
          Text(
            sesi.verdict,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1E3A34),
              height: 1.45,
            ),
          ),

          // Sesi yang masih berjalan tidak berpura-pura sudah punya hasil:
          // yang ditawarkan adalah jalan kembali ke layar sesi berjalan.
          if (aktif) ...[
            const SizedBox(height: 16),
            if (jadwal != null && sesi.sampelBerikutnya != null) ...[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.65),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.schedule_rounded,
                      size: 15,
                      color: Color(0xFF6B807B),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Titik berikutnya: ${sesi.sampelBerikutnya!.label}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: Color(0xFF6B807B),
                        ),
                      ),
                    ),
                    HitungMundur(target: jadwal),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SesiBerjalanPage()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EAD69),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Buka Sesi Berjalan',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Kurva SpO2 satu sesi.
///
/// Terpisah jadi widget sendiri semata-mata karena ia perlu membaca kemampuan
/// jam dari controller, sementara [RingkasanSesiPage] sengaja tetap menerima
/// [SesiMakan] lewat konstruktor — halaman ini dipakai untuk sesi lama di
/// riwayat, bukan hanya sesi terbaru.
class _KurvaSpo2 extends StatelessWidget {
  const _KurvaSpo2({required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    final kemampuan = context
        .watch<SesiMakanController>()
        .statusPerangkat
        .metrikTampil;
    final ada = sesi.sampel.any((s) => s.terisi && s.spo2 != null);

    // Dua syarat, dan keduanya perlu. Tanpa sensor: bagian ini tidak boleh ada
    // sama sekali. Dengan sensor tetapi tanpa angka: ia hanya akan menampilkan
    // "Belum ada sampel" di bawah judul yang menjanjikan grafik — sementara
    // ketiadaan angkanya sudah terbaca di detail tiap titik.
    if (!kemampuan.spo2 || !ada) return const SizedBox.shrink();

    final nilai = [
      for (final s in sesi.sampel)
        if (s.terisi && s.spo2 != null) s.spo2!,
    ];
    final terendah = nilai.reduce((a, b) => a < b ? a : b);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JudulBagian(
          ikon: Icons.air_rounded,
          judul: 'Oksigen Darah',
          // Yang terendah, bukan yang terakhir: pada SpO2 justru titik
          // terendahnya yang berarti sesuatu.
          keterangan: 'Terendah $terendah% selama sesi',
        ),
        KurvaSampel(
          sampel: sesi.sampel,
          seri: const [seriSpo2],
          tinggi: 170,
          pesanKosong: 'Belum ada sampel oksigen',
        ),
        const SizedBox(height: 24),
      ],
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
    final ada = nilai != tandaKosong;

    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 14, 10, 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Ikonnya diberi petak bertekstur tipis alih-alih berdiri telanjang
            // di samping label: pada tiga kotak bersebelahan, ikon tanpa wadah
            // terbaca sebagai bagian dari tulisannya.
            Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F8F5),
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: Icon(ikon, size: 14, color: const Color(0xFF0EAD69)),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFF8FA7A1),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              nilai,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.bold,
                height: 1.1,
                // Angka yang belum ada tidak boleh sepekat angka yang ada:
                // tiga kotak dengan `—` sehitam angkanya membuat halaman
                // terlihat penuh data padahal kosong.
                color: ada ? const Color(0xFF1E3A34) : const Color(0xFF9CB1AC),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              satuan,
              maxLines: 2,
              style: const TextStyle(
                fontSize: 10,
                height: 1.25,
                color: Color(0xFF9CB1AC),
              ),
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
          for (final s in sesi.sampel)
            _KartuSampel(
              sampel: s,
              t0: widget.t0,
              kemampuan: context
                  .watch<SesiMakanController>()
                  .statusPerangkat
                  .metrikTampil,
            ),
      ],
    );
  }
}

/// Satu titik pengukuran beserta seluruh metriknya. Metrik yang tidak
/// berhasil diukur ditulis `—` (§8).
class _KartuSampel extends StatelessWidget {
  const _KartuSampel({
    required this.sampel,
    required this.t0,
    required this.kemampuan,
  });

  final KemampuanPerangkat kemampuan;

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
              // `didukung` menentukan apakah metriknya ada di layar sama
              // sekali; `nilai` menentukan `—` atau angkanya (§3 vs §5.2).
              _metrik(
                'Gula',
                sampel.gulaDarah?.toString(),
                'mg/dL',
                didukung: kemampuan.gulaDarah,
              ),
              // Detak jantung tidak punya bit kemampuan di §3.
              _metrik('Jantung', sampel.detakJantung?.toString(), 'bpm'),
              _metrik(
                'Tekanan',
                sampel.tekananDarah,
                'mmHg',
                didukung: kemampuan.tekananDarah,
              ),
              _metrik(
                'SpO₂',
                sampel.spo2?.toString(),
                '%',
                didukung: kemampuan.spo2,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Satu metrik di kartu titik ukur.
  ///
  /// [didukung] false berarti jam ini **tidak punya sensornya**, dan metriknya
  /// hilang dari layar — bukan ditulis `—`, yang berarti "diukur tetapi gagal"
  /// dan mengundang orang mencoba lagi untuk sensor yang tidak ada (§3).
  ///
  /// Satu pengecualian yang tidak boleh dilewatkan: **angka yang sudah ada tetap
  /// ditampilkan** meski `didukung` false. Sesi lama di riwayat bisa saja diukur
  /// jam lain, dan menyembunyikan angka sungguhan yang tersimpan di basis data
  /// adalah kerugian yang pasti — jauh lebih buruk daripada satu kolom yang
  /// seharusnya tidak ada.
  Widget _metrik(
    String label,
    String? nilai,
    String satuan, {
    bool didukung = true,
  }) {
    final ada = nilai != null;
    if (!didukung && !ada) return const SizedBox.shrink();
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
    // Pintu ke halaman yang seluruh isinya `—` bukan pintu, melainkan jalan
    // buntu yang harus ditempuh dulu sebelum ketahuan buntu.
    final kemampuan = context
        .watch<SesiMakanController>()
        .statusPerangkat
        .metrikTampil;

    return Row(
      children: [
        if (kemampuan.gulaDarah) ...[
          _tombol(
            context,
            ikon: ikonGulaDarah,
            label: 'Gula Darah',
            halaman: () => GulaDarahDetailPage(sesi: sesi),
          ),
          const SizedBox(width: 10),
        ],
        if (kemampuan.tekananDarah) ...[
          _tombol(
            context,
            ikon: ikonTekananDarah,
            label: 'Tekanan',
            halaman: () => TekananDarahDetailPage(sesi: sesi),
          ),
          const SizedBox(width: 10),
        ],
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
