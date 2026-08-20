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
///
/// **Aturan ketiga itu ternyata baru setengah ditegakkan, dan sisanya dibereskan
/// kemudian.** Delta masih muncul tiga kali (angka besar, kalimat verdict, baris
/// kaitan karbo), baseline tiga kali (subjudul kartu hasil, kotak nilai,
/// keterangan judul kurva), dan jumlah titik dua kali. Halaman terasa
/// bertele-tele bukan karena bagiannya banyak, melainkan karena tiap angka
/// diulang sampai pembacanya ragu apakah dua angka yang sama itu memang hal yang
/// sama. Yang berlaku sekarang: **satu angka, satu tempat**, dan tempatnya
/// adalah yang paling menonjol — subjudul, keterangan, dan kalimat pendukung
/// menyebut *apa* angka itu, tidak pernah mengulang *berapa*.
/// Batas bawah SpO₂ yang masih dianggap wajar. Di bawah ini bentuk kurvanya
/// mulai berarti, jadi kurvanya ditampilkan.
const int ambangSpo2Wajar = 95;

class RingkasanSesiPage extends StatelessWidget {
  const RingkasanSesiPage({super.key, required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    final t0 = sesi.t0;
    final pemulihan = sesi.waktuPemulihan;
    final baseline = sesi.gulaDarahBaseline;

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
                      satuan: baseline == null ? 'belum terukur' : 'mg/dL',
                    ),
                    const SizedBox(width: 10),
                    _KotakNilai(
                      ikon: Icons.arrow_upward_rounded,
                      label: 'Puncak',
                      nilai: sesi.puncakGulaDarah?.toString() ?? tandaKosong,
                      satuan: sesi.sampelPuncak == null
                          ? 'mg/dL'
                          : 'mg/dL · ${sesi.sampelPuncak!.label.toLowerCase()}',
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
                          : 'sejak selesai makan',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Tanpa keterangan: jumlah titik terukur adalah milik "Detail Tiap
              // Titik" di bawah, dan baseline sudah berdiri sebagai kotak nilai
              // beberapa piksel di atas — lengkap dengan garis acuannya sendiri
              // di dalam kurva.
              const JudulBagian(
                ikon: ikonGulaDarah,
                judul: 'Respons Gula Darah',
              ),
              KurvaSampel(
                sampel: sesi.sampel,
                seri: const [seriGulaDarah],
                garisAcuan: baseline,
                pesanKosong: 'Belum ada sampel gula darah',
              ),
              const SizedBox(height: 24),

              // Tekanan darah berdiri sejajar dengan gula darah, bukan
              // terkubur di dalam tabel rincian: keduanya adalah yang berubah
              // karena makan, dan keduanya yang dipantau orang dengan alasan
              // medis. SpO₂ menyusul di bawahnya sebagai satu baris — ia diukur
              // di titik yang sama, tetapi bukan alasan sesi ini dijalankan.
              _TekananDarahSesi(sesi: sesi),

              // Hanya bila jam ini memang punya sensornya **dan** ada angkanya.
              // Kurva kosong berjudul "Oksigen" pada jam tanpa pulse oximeter
              // adalah persis yang §3 protokol larang.
              _Spo2Sesi(sesi: sesi),

              const JudulBagian(
                ikon: Icons.restaurant_menu_rounded,
                judul: 'Nutrisi Sesi Ini',
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
                    // Fotonya berdiri di sini, bukan sebagai jempol 72 px di
                    // kepala halaman.
                    //
                    // Seluruh angka di kartu ini adalah **perkiraan dari foto
                    // itu**, dan baris di bawahnya menyebut seberapa yakin
                    // perkiraannya. "Keyakinan 82%" tidak bisa dinilai siapa pun
                    // tanpa melihat apa yang dilihat detektornya: porsi yang
                    // jelas meleset baru kelihatan meleset ketika piringnya ada
                    // di layar yang sama. Di kepala halaman ia hanya menandai
                    // sesi yang mana — dan itu sudah dikerjakan oleh nama
                    // makanan tepat di sebelahnya.
                    FotoMakanan(
                      fotoPath: sesi.fotoPath,
                      lebar: double.infinity,
                      tinggi: 150,
                    ),
                    const SizedBox(height: 14),
                    RingkasanNutrisi(hasil: sesi.hasil),
                    if (sesi.hasil != null) ...[
                      const SizedBox(height: 14),
                      _CatatanMakanan(hasil: sesi.hasil!),
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

    // Tanpa foto: fotonya turun ke kartu nutrisi, di samping angka-angka yang
    // diperkirakan darinya, dan tidak ditampilkan dua kali di satu halaman.
    return Column(
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
                // "Makan Siang" tidak ikut ditulis di samping "12.40",
                // karena ia **diturunkan dari jam itu** (`waktuMakan` di
                // sesi_makan.dart): pukul 12.40 justru sebabnya disebut
                // makan siang. Label itu baru membawa keterangan baru
                // ketika jam pastinya tidak diketahui — dan di situlah ia
                // satu-satunya yang bisa dikatakan.
                sesi.waktuTidakPasti
                    ? sesi.labelWaktuMakan
                    : t0 == null
                    ? '${formatTanggal(sesi.waktuFoto)} · '
                          '${sesi.labelWaktuMakan}'
                    : '${formatJam(t0)} · ${formatWaktuRelatif(t0)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12, color: Color(0xFF7E9A94)),
              ),
            ),
          ],
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
            // Angkanya tidak diulang: baseline berdiri sebagai kotak nilai
            // sendiri tepat di bawah kartu ini. Kalimat ini hanya menerangkan
            // **apa** angka besar di atasnya, bukan menyebut ulang berapa.
            const Text(
              'kenaikan puncak dari baseline',
              style: TextStyle(fontSize: 11.5, color: Color(0xFF6B807B)),
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

          // Verdict hanya dipasang bila angkanya **tidak** ada.
          //
          // Kalimatnya berbunyi "puncak +50 mg/dL · belum kembali ke baseline
          // dalam 2 jam" — persis angka 46 px di atasnya ditambah persis isi
          // kotak Pemulihan di bawahnya. Di sesi yang sudah punya hasil ia tidak
          // menambahkan satu fakta pun, hanya mengucapkannya untuk kedua kali.
          // Di sesi yang belum punya hasil ia satu-satunya yang bercerita, jadi
          // di sanalah ia tinggal.
          if (!adaAngka) ...[
            const SizedBox(height: 14),
            Text(
              sesi.verdict,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF1E3A34),
                height: 1.45,
              ),
            ),
          ],

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

/// Tekanan darah satu sesi — kurva sistolik dan diastolik.
///
/// **Bagian ini sebelumnya tidak ada sama sekali**, padahal tekanan darah diukur
/// di keempat titik yang sama dan ikut tersimpan sejak Tahap A. Satu-satunya
/// tempatnya muncul adalah sel di tabel rincian yang terlipat, dan pintu ke
/// halaman detail — dua tempat yang keduanya menuntut ketukan lebih dulu.
/// Sementara itu SpO₂, yang pada sesi sehat tidak bergerak, mendapat judul dan
/// kurva penuh. Urutan penekanannya terbalik dari alasan orang membuka aplikasi
/// ini.
///
/// Keterangannya menyebut yang **tertinggi**, dengan alasan cermin dari SpO₂:
/// di sana yang berarti adalah titik terendah, di sini titik tertinggi.
class _TekananDarahSesi extends StatelessWidget {
  const _TekananDarahSesi({required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    final kemampuan = context
        .watch<SesiMakanController>()
        .statusPerangkat
        .metrikTampil;

    final terisi = [
      for (final s in sesi.sampel)
        if (s.terisi && s.sistolik != null && s.diastolik != null) s,
    ];
    if (!kemampuan.tekananDarah || terisi.isEmpty) {
      return const SizedBox.shrink();
    }

    final puncak = terisi.reduce((a, b) => b.sistolik! > a.sistolik! ? b : a);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JudulBagian(
          ikon: ikonTekananDarah,
          judul: 'Tekanan Darah',
          keterangan:
              'Tertinggi ${puncak.tekananDarah} mmHg '
              'di ${puncak.label.toLowerCase()}',
        ),
        KurvaSampel(
          sampel: sesi.sampel,
          seri: const [seriSistolik, seriDiastolik],
          pesanKosong: 'Belum ada sampel tekanan darah',
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

/// SpO₂ satu sesi: satu baris bila wajar, kurva penuh bila tidak.
///
/// **Kurvanya dulu selalu digambar, dan itu seperempat halaman untuk garis yang
/// sengaja kami ratakan sendiri.** `seriSpo2.rentangMinimum` bernilai 8 justru
/// supaya SpO₂ 96–98 tidak terlihat bergelombang — sehat memang berarti datar.
/// Jadi bagian itu memakai satu judul, satu keterangan, dan kurva 170 px untuk
/// menggambar bentuk yang sudah diputuskan tidak boleh bercerita apa-apa.
///
/// Sekarang bentuknya baru ditampilkan ketika bentuk itu berarti: satu saja
/// pembacaan di bawah [ambangSpo2Wajar] dan seluruh bagian lamanya kembali,
/// lengkap dengan kurvanya, karena yang ingin dilihat di sana adalah **kapan**
/// turunnya dan seberapa lama. Selebihnya cukup satu baris.
///
/// Yang tidak berubah: jam tanpa sensor SpO₂ tidak menampilkan apa pun (§3),
/// bukan baris berisi `—`.
class _Spo2Sesi extends StatelessWidget {
  const _Spo2Sesi({required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    final kemampuan = context
        .watch<SesiMakanController>()
        .statusPerangkat
        .metrikTampil;

    final nilai = [
      for (final s in sesi.sampel)
        if (s.terisi && s.spo2 != null) s.spo2!,
    ];
    if (!kemampuan.spo2 || nilai.isEmpty) return const SizedBox.shrink();

    final terendah = nilai.reduce((a, b) => a < b ? a : b);
    final tertinggi = nilai.reduce((a, b) => a > b ? a : b);

    if (terendah >= ambangSpo2Wajar) {
      final rentang = terendah == tertinggi
          ? '$terendah%'
          : '$terendah–$tertinggi%';
      return Column(
        children: [
          _BarisCatatan(
            ikon: Icons.air_rounded,
            teks: 'Oksigen darah $rentang sepanjang sesi · dalam rentang wajar',
          ),
          const SizedBox(height: 24),
        ],
      );
    }

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

/// Satu baris berlatar tipis dengan ikon — bentuk yang dipakai catatan yang
/// tidak cukup penting untuk menjadi bagian sendiri, tetapi terlalu penting
/// untuk dihilangkan.
class _BarisCatatan extends StatelessWidget {
  const _BarisCatatan({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
      ),
      child: Row(
        children: [
          Icon(ikon, size: 16, color: const Color(0xFF0EAD69)),
          const SizedBox(width: 10),
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
            // Dikecilkan bila perlu, tidak pernah dipotong. Nilai pemulihan
            // ditulis dengan satuan ("1 jam 30 menit", "0 menit"), jadi pada
            // sepertiga lebar layar ia melewati batas kotaknya dan berakhir
            // sebagai "0 me…" — potongan yang menyembunyikan justru angkanya.
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                nilai,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                  height: 1.1,
                  // Angka yang belum ada tidak boleh sepekat angka yang ada:
                  // tiga kotak dengan `—` sehitam angkanya membuat halaman
                  // terlihat penuh data padahal kosong.
                  color: ada
                      ? const Color(0xFF1E3A34)
                      : const Color(0xFF9CB1AC),
                ),
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
          _TabelTitik(
            sampel: sesi.sampel,
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

/// Seluruh titik pengukuran sebagai satu tabel, bukan satu kartu per titik.
///
/// Bentuk lamanya adalah empat kartu bertumpuk, masing-masing dengan bingkai,
/// bantalan, judul, dan empat metrik yang menuliskan satuannya sendiri. Untuk 16
/// angka itu berarti empat bingkai, empat baris keterangan waktu yang isinya
/// hampir sama, dan satuan yang ditulis empat kali — "mg/dL" muncul empat kali
/// untuk empat angka yang sudah jelas semuanya gula darah.
///
/// Sebagai tabel, tiap hal ditulis sekali di tempat yang benar: nama metrik dan
/// satuannya di kepala kolom, waktu di sisi kiri barisnya, angka di dalam sel.
/// Yang paling dicari di sini — membandingkan satu metrik antar titik —
/// akhirnya menjadi gerakan mata lurus ke bawah, bukan melompati empat kartu.
///
/// Aturan §3 tidak berubah, hanya berpindah tempat: kolom untuk sensor yang
/// tidak dimiliki jam **dihapus seluruhnya**, kecuali bila ada angka tersimpan
/// di dalamnya — sesi lama bisa saja diukur jam lain, dan menyembunyikan angka
/// sungguhan adalah kerugian yang pasti. Sel kosong tetap `—`, yang berarti
/// "diukur tetapi gagal".
class _TabelTitik extends StatelessWidget {
  const _TabelTitik({
    required this.sampel,
    required this.t0,
    required this.kemampuan,
  });

  final List<Sampel> sampel;
  final DateTime? t0;
  final KemampuanPerangkat kemampuan;

  @override
  Widget build(BuildContext context) {
    // Detak jantung tidak punya bit kemampuan di §3, jadi selalu ada.
    final kolom =
        <({String nama, String satuan, String? Function(Sampel) ambil})>[
          (
            nama: 'Gula',
            satuan: 'mg/dL',
            ambil: (s) => s.gulaDarah?.toString(),
          ),
          (
            nama: 'Jantung',
            satuan: 'bpm',
            ambil: (s) => s.detakJantung?.toString(),
          ),
          (nama: 'Tekanan', satuan: 'mmHg', ambil: (s) => s.tekananDarah),
          (nama: 'SpO₂', satuan: '%', ambil: (s) => s.spo2?.toString()),
        ];
    final didukung = {
      'Gula': kemampuan.gulaDarah,
      'Jantung': true,
      'Tekanan': kemampuan.tekananDarah,
      'SpO₂': kemampuan.spo2,
    };
    final tampil = [
      for (final k in kolom)
        if (didukung[k.nama]! || sampel.any((s) => k.ambil(s) != null)) k,
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              const SizedBox(width: _lebarKiri),
              for (final k in tampil)
                Expanded(
                  child: Column(
                    children: [
                      Text(
                        k.nama,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B807B),
                        ),
                      ),
                      Text(
                        k.satuan,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 8.5,
                          color: Color(0xFF9CB1AC),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, thickness: 1, color: Color(0xFFE2EBE8)),
          for (final s in sampel) _baris(s, tampil),
        ],
      ),
    );
  }

  static const double _lebarKiri = 86;

  Widget _baris(
    Sampel s,
    List<({String nama, String satuan, String? Function(Sampel) ambil})> kolom,
  ) {
    final waktu = t0 == null ? null : s.waktuUkur(t0!);
    final terlewat = s.status == StatusSampel.terlewat;

    // Waktu relatif ("2 hari lalu") sengaja tidak ikut: ia sama untuk keempat
    // baris, dan sudah tertulis satu kali di kepala halaman.
    final catatan = [
      if (waktu != null) formatJam(waktu),
      if (terlewat) 'terlewat',
      if (s.dariBuffer) 'dari buffer',
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: _lebarKiri,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E3A34),
                  ),
                ),
                if (catatan.isNotEmpty)
                  Text(
                    catatan,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 9.5,
                      color: terlewat
                          ? const Color(0xFFC0392B)
                          : const Color(0xFF9CB1AC),
                    ),
                  ),
              ],
            ),
          ),
          for (final k in kolom)
            Expanded(
              child: Center(
                child: Text(
                  k.ambil(s) ?? tandaKosong,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: k.ambil(s) == null
                        ? const Color(0xFF9CB1AC)
                        : const Color(0xFF1E3A34),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Satu baris fakta tentang makanannya — karbohidrat, indeks glikemik, dan
/// seberapa yakin deteksinya.
///
/// Menggantikan dua blok bertumpuk (`_KaitanKarbo` dan `_CatatanKeyakinan`) yang
/// bersama-sama memakan empat baris untuk tiga angka. Yang **sengaja hilang**
/// dari kalimat lamanya adalah panah "45 g karbohidrat → puncak +50 mg/dL": itu
/// penyebutan ketiga untuk delta yang sudah menjadi angka 46 px di kartu paling
/// atas halaman ini. Yang tersisa hanya hal yang belum dikatakan di tempat lain.
///
/// Keyakinan deteksi tetap disebut apa adanya karena ia menentukan apakah sesi
/// ini ikut diplot di Analisis (§4.3).
class _CatatanMakanan extends StatelessWidget {
  const _CatatanMakanan({required this.hasil});

  final HasilDeteksi hasil;

  @override
  Widget build(BuildContext context) {
    final bagian = [
      '${formatAngka(hasil.total.karbohidrat)} g karbohidrat',
      'indeks glikemik ${hasil.indeksGlikemikPerkiraan}',
      hasil.dikoreksiUser
          ? 'porsi dikoreksi'
          : 'keyakinan ${(hasil.keyakinan * 100).round()}%',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4FAF7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
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
              bagian.join(' · '),
              style: const TextStyle(
                fontSize: 11.5,
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
