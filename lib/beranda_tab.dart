import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'models/sesi_makan.dart';
import 'models/target_harian.dart';
import 'pindai_kesehatan_page.dart';
import 'repositories/profil_repository.dart';
import 'ringkasan_sesi_page.dart';
import 'sesi_berjalan_page.dart';
import 'utils/format_waktu.dart';
import 'utils/ikon.dart';
import 'widgets/foto_makanan.dart';
import 'widgets/judul_bagian.dart';
import 'widgets/petunjuk_tombol_jam.dart';
import 'widgets/petunjuk_tombol_ukur.dart';
import 'widgets/ringkasan_nutrisi.dart';
import 'widgets/sparkline.dart';
import 'widgets/timeline_sampel.dart';
import 'widgets/tombol_sinkron.dart';

/// Beranda menjawab "sesi kamu sampai mana", bukan lagi "bagaimana kondisimu
/// sekarang" (§3). Kartu vital "sekarang" sudah dihapus: jam hanya mengukur
/// saat sesi makan, jadi angka semacam itu akan basi hampir sepanjang waktu.
///
/// Tiga wajah sesuai status sesi (§4.1): idle, sesi berjalan, dan sesi baru
/// selesai. Hanya bagian sesi yang mendengarkan controller — sapaan dan
/// tanggal tetap di luar, karena `build()` di sini memanggil `_loadNama()`
/// yang async.
class BerandaTab extends StatefulWidget {
  const BerandaTab({super.key});

  @override
  State<BerandaTab> createState() => _BerandaTabState();
}

class _BerandaTabState extends State<BerandaTab> {
  String _nama = '';

  @override
  void initState() {
    super.initState();
    _loadNama();
  }

  // Memuat nama lewat ProfilRepository saat tab ini dibangun.
  //
  // Dipanggil juga dari build(), jadi pemeriksaan `nama == _nama` di bawah
  // WAJIB ada: tanpa itu setState memicu build berikutnya, yang memanggil
  // _loadNama() lagi, dan tab ini rebuild tanpa henti begitu ada nama tersimpan.
  Future<void> _loadNama() async {
    final nama = (await const ProfilRepository().muat()).nama;

    if (!mounted || nama == _nama) return;

    setState(() {
      _nama = nama;
    });
  }

  // Format tanggal saat ini ke format Indonesia
  String _formatCurrentDate() {
    final now = DateTime.now();
    const days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    return '${days[now.weekday]}, ${formatTanggal(now)}';
  }

  @override
  Widget build(BuildContext context) {
    // Pastikan memuat nama terbaru saat widget dibuild kembali
    _loadNama();

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                // Foto orang asing dari Unsplash dihapus bersama sisa identitas
                // demo; ia juga tidak pernah termuat di rilis karena izin
                // INTERNET tidak dideklarasikan.
                const CircleAvatar(
                  radius: 22,
                  backgroundColor: Color(0xFFE0F2F1),
                  child: Icon(Icons.person, color: Color(0xFF0EAD69)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            // Tanpa nama tersimpan, sapaannya berhenti di
                            // "Halo" — bukan menyapa dengan nama orang lain.
                            _nama.isEmpty ? 'Halo' : 'Halo, $_nama',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A34),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '👋',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.amber.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrentDate(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7E9A94),
                        ),
                      ),
                    ],
                  ),
                ),
                // Lonceng notifikasi dihapus bersama titik merahnya, karena
                // keduanya berbohong: `onPressed` kosong, dan titiknya
                // di-hardcode menyala sehingga selalu mengaku ada pemberitahuan
                // belum dibaca. Aplikasi ini tidak punya notifikasi sama sekali.
                //
                // Kalau kelak dibuat sungguhan, pemicunya sudah jelas dan bukan
                // ini: titik ukur +1 jam dan +2 jam sebuah sesi, serta
                // `tenggatSampelTerakhir` yang menutup sesi jadi `tidakLengkap`.
                // Sesi berlangsung ~2 jam dan pengguna pasti meninggalkan
                // aplikasi, jadi saat ini tak satu pun dari ketiganya
                // diberitahukan.
              ],
            ),
            const SizedBox(height: 16),

            // Status jam ringkas — pendengar sendiri, bukan seluruh tab.
            const _StatusJamHeader(),
            const _PeringatanPenyimpanan(),
            const SizedBox(height: 20),

            // Tiga wajah sesi.
            const _AreaSesi(),
            const SizedBox(height: 20),

            // Di bawah area sesi, bukan di atasnya: Beranda menjawab "sesi kamu
            // sampai mana" lebih dulu (§3), dan pindai lepas adalah tindakan
            // sampingan. Tetap di Beranda — bukan hanya di Profil — karena ia
            // dipakai saat seseorang merasa ada yang tidak beres, dan pada saat
            // itu ia tidak akan mencarinya di dalam menu.
            const _KartuPindaiKesehatan(),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _StatusJamHeader extends StatelessWidget {
  const _StatusJamHeader();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SesiMakanController>();
    final p = controller.statusPerangkat;

    return Row(
      children: [
        Expanded(child: StatusPerangkatBar(perangkat: p)),
        // Tanpa jam yang pernah dipasangkan tidak ada apa pun untuk ditarik,
        // jadi tombolnya tidak ada sama sekali — bukan ada tapi mati. Aturan
        // yang sama dipakai kartu status di MenghubungkanPerangkatPage.
        if (!p.belumDipasangkan) ...[
          const SizedBox(width: 10),
          TombolSinkron(aktif: p.tersambung, ringkas: true),
        ],
      ],
    );
  }
}

/// Peringatan bahwa sesi terakhir gagal ditulis ke penyimpanan.
///
/// Ditempatkan di Beranda, bukan sebagai SnackBar, karena akibatnya bertahan:
/// sesinya masih terlihat di layar tetapi akan hilang saat aplikasi ditutup.
/// Pesan sekilas yang menghilang sendiri akan menyembunyikan justru bagian yang
/// perlu diketahui.
class _PeringatanPenyimpanan extends StatelessWidget {
  const _PeringatanPenyimpanan();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SesiMakanController>();
    final pesan = controller.galatPenyimpanan;
    if (pesan == null) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0D9B5), width: 1.5),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 20,
            color: Color(0xFFB4761E),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pesan,
              style: const TextStyle(fontSize: 12, color: Color(0xFF6B4E1E)),
            ),
          ),
          GestureDetector(
            onTap: controller.buangGalatPenyimpanan,
            child: const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(
                Icons.close_rounded,
                size: 18,
                color: Color(0xFFB4761E),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pintu masuk pindai kesehatan atas permintaan.
///
/// Kalimat pendukungnya berubah menurut keadaan jam, bukan hanya tombolnya yang
/// mati: kartu yang terlihat sama persis baik jam tersambung maupun tidak
/// membuat ketukan yang tidak menghasilkan apa-apa terbaca sebagai aplikasi yang
/// rusak. Kartunya tetap **bisa diketuk** meski jam sedang terputus — halaman
/// tujuannya justru yang menerangkan sebabnya dan menawarkan jalan keluarnya.
class _KartuPindaiKesehatan extends StatelessWidget {
  const _KartuPindaiKesehatan();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<SesiMakanController>().statusPerangkat;
    final keterangan = p.belumDipasangkan
        ? 'Perlu jam AsaWatch yang sudah dipasangkan'
        : !p.tersambung
        ? 'Jam belum tersambung — dekatkan ke ponsel'
        : 'Ukur sekali jalan tanpa menunggu jam makan';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PindaiKesehatanPage()),
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F6F0),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.monitor_heart_rounded,
                  size: 22,
                  color: Color(0xFF0EAD69),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Pindai Kesehatan',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A34),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      keterangan,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7E9A94),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: Color(0xFF8FA7A1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AreaSesi extends StatelessWidget {
  const _AreaSesi();

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SesiMakanController>();
    final aktif = controller.sesiAktif;
    final hasilBaru = controller.hasilBelumDibaca;

    // Wajah B — sesi berjalan.
    if (aktif != null) {
      return _KartuSesiBerjalan(sesi: aktif, controller: controller);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Wajah C — hasil sesi terbaru, bertahan sampai dibuka user.
        if (hasilBaru != null) ...[
          _KartuHasilBaru(sesi: hasilBaru, controller: controller),
          const SizedBox(height: 20),
        ],

        // Wajah A — ringkasan hari ini, selalu ada datanya karena tiap makan
        // difoto.
        _RingkasanHariIni(controller: controller),
        const SizedBox(height: 20),

        if (hasilBaru == null) ...[
          _KartuSesiTerakhir(controller: controller),
          const SizedBox(height: 20),
        ],

        _KartuPuncakTerakhir(controller: controller),
      ],
    );
  }
}

// --- Wajah B ---------------------------------------------------------------

class _KartuSesiBerjalan extends StatelessWidget {
  const _KartuSesiBerjalan({required this.sesi, required this.controller});

  final SesiMakan sesi;
  final SesiMakanController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JudulBagian(
          ikon: ikonStatusSesi(sesi.status),
          judul: 'Sesi Kamu',
          aksi: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFE2F6F0),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              sesi.status.label,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0EAD69),
              ),
            ),
          ),
        ),

        // Timeline mendominasi layar saat sesi berjalan (§4.1 B).
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
          ),
          child: TimelineSampel(
            sampel: sesi.sampel,
            t0: sesi.t0,
            indexBerikutnya: sesi.sampelBerikutnya?.index,
            kemampuan: controller.statusPerangkat.metrikTampil,
          ),
        ),
        const SizedBox(height: 16),

        // Di bawahnya: foto makanan dan ringkasan nutrisinya.
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
              Row(
                children: [
                  FotoMakanan(fotoPath: sesi.fotoPath, lebar: 56, tinggi: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      sesi.hasil?.ringkasanNama ?? 'Makanan',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A34),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              RingkasanNutrisi(hasil: sesi.hasil),
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (sesi.t0 == null)
          PetunjukTombolJam(
            status: sesi.status,
            perangkat: controller.statusPerangkat,
          )
        else ...[
          // Titik ukur tidak datang sendiri sejak protokol v1.3 (§9), dan
          // notifikasinya mendarat di ponsel — jadi tombolnya harus ada di
          // layar yang pertama dibuka, bukan hanya satu ketukan lebih dalam di
          // SesiBerjalanPage. Widget ini menyembunyikan dirinya sendiri bila
          // tidak ada titik yang menunggu, jadi kartu ini tidak berubah bentuk
          // di sebagian besar waktu sesi.
          const PetunjukTombolUkur(),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SesiBerjalanPage()),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0EAD69),
                side: const BorderSide(color: Color(0xFFE2EBE8), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Buka Sesi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// --- Wajah C ---------------------------------------------------------------

class _KartuHasilBaru extends StatelessWidget {
  const _KartuHasilBaru({required this.sesi, required this.controller});

  final SesiMakan sesi;
  final SesiMakanController controller;

  @override
  Widget build(BuildContext context) {
    final t0 = sesi.t0;
    final delta = sesi.deltaPuncak;

    return GestureDetector(
      onTap: () {
        controller.tandaiHasilDibaca();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => RingkasanSesiPage(sesi: sesi)),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFFE2F6F0),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.insights_rounded,
                  color: Color(0xFF0EAD69),
                  size: 18,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Sesi baru selesai',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A34),
                    ),
                  ),
                ),
                if (t0 != null)
                  Text(
                    formatWaktuRelatif(t0),
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B807B),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FotoMakanan(fotoPath: sesi.fotoPath, lebar: 56, tinggi: 56),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        sesi.verdict,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A34),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        delta == null
                            ? 'Ketuk untuk melihat rinciannya'
                            : 'Ketuk untuk melihat kurva responsnya',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6B807B),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// --- Wajah A ---------------------------------------------------------------

class _RingkasanHariIni extends StatelessWidget {
  const _RingkasanHariIni({required this.controller});

  final SesiMakanController controller;

  @override
  Widget build(BuildContext context) {
    const target = TargetHarian.bawaan;
    final total = controller.totalNutrisiHariIni();
    final jumlahSesi = controller.sesiHariIni().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JudulBagian(
          ikon: Icons.restaurant_menu_rounded,
          judul: 'Ringkasan Hari Ini',
          aksi: Text(
            jumlahSesi == 0 ? 'belum ada sesi' : '$jumlahSesi sesi',
            style: const TextStyle(fontSize: 11, color: Color(0xFF7E9A94)),
          ),
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
              _BarisTarget(
                label: 'Kalori',
                nilai: total.kalori,
                target: target.kalori,
                satuan: 'kcal',
              ),
              const SizedBox(height: 14),
              _BarisTarget(
                label: 'Karbohidrat',
                nilai: total.karbohidrat,
                target: target.karbohidrat,
                satuan: 'g',
              ),
              const SizedBox(height: 14),
              _BarisTarget(
                label: 'Protein',
                nilai: total.protein,
                target: target.protein,
                satuan: 'g',
              ),
              const SizedBox(height: 14),
              _BarisTarget(
                label: 'Lemak',
                nilai: total.lemak,
                target: target.lemak,
                satuan: 'g',
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarisTarget extends StatelessWidget {
  const _BarisTarget({
    required this.label,
    required this.nilai,
    required this.target,
    required this.satuan,
  });

  final String label;
  final double nilai;
  final double target;
  final String satuan;

  @override
  Widget build(BuildContext context) {
    final rasio = target <= 0 ? 0.0 : (nilai / target).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              ikonMakro[label] ?? Icons.circle,
              size: 13,
              color: const Color(0xFF8FA7A1),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E3A34),
                ),
              ),
            ),
            Text(
              '${formatAngka(nilai)} / ${formatAngka(target)} $satuan',
              style: const TextStyle(fontSize: 11, color: Color(0xFF6B807B)),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: LinearProgressIndicator(
            value: rasio,
            minHeight: 6,
            backgroundColor: const Color(0xFFE2EBE8),
            valueColor: const AlwaysStoppedAnimation(Color(0xFF0EAD69)),
          ),
        ),
      ],
    );
  }
}

class _KartuSesiTerakhir extends StatelessWidget {
  const _KartuSesiTerakhir({required this.controller});

  final SesiMakanController controller;

  @override
  Widget build(BuildContext context) {
    final sesi = controller.sesiTerakhir;

    if (sesi == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
        ),
        child: Column(
          children: const [
            Icon(
              Icons.photo_camera_rounded,
              size: 32,
              color: Color(0xFF8FA7A1),
            ),
            SizedBox(height: 10),
            Text(
              'Belum ada sesi',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A34),
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Foto makananmu lewat tombol kamera untuk memulai sesi.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Color(0xFF7E9A94)),
            ),
          ],
        ),
      );
    }

    final t0 = sesi.t0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const JudulBagian(ikon: Icons.history_rounded, judul: 'Sesi Terakhir'),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => RingkasanSesiPage(sesi: sesi)),
          ),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
            ),
            child: Row(
              children: [
                FotoMakanan(fotoPath: sesi.fotoPath, lebar: 52, tinggi: 52),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            ikonWaktuMakan(sesi.waktuMakan),
                            size: 12,
                            color: const Color(0xFF8FA7A1),
                          ),
                          const SizedBox(width: 5),
                          Expanded(
                            child: Text(
                              t0 == null
                                  ? formatJam(sesi.waktuFoto)
                                  : '${formatJam(t0)} · '
                                        '${formatWaktuRelatif(t0)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF8FA7A1),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        sesi.verdict,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A34),
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF8FA7A1),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _KartuPuncakTerakhir extends StatelessWidget {
  const _KartuPuncakTerakhir({required this.controller});

  final SesiMakanController controller;

  @override
  Widget build(BuildContext context) {
    final puncak = controller.puncakTerakhir();
    // Satu titik bukan tren; jangan digambar (§8).
    if (puncak.length < 2) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: const [
                  Icon(ikonGulaDarah, size: 14, color: Color(0xFF0EAD69)),
                  SizedBox(width: 6),
                  Text(
                    'Puncak Gula Darah',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A34),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${puncak.length} sesi terakhir',
                style: const TextStyle(fontSize: 10, color: Color(0xFF8FA7A1)),
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A34),
                  ),
                  children: [
                    TextSpan(text: formatAngka(puncak.last)),
                    const TextSpan(
                      text: ' mg/dL',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.normal,
                        color: Color(0xFF6B807B),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 44,
              child: CustomPaint(
                painter: MiniSparklinePainter(
                  colors: [
                    const Color(0xFF0EAD69),
                    const Color(0xFF0EAD69).withValues(alpha: 0.3),
                  ],
                  nilai: puncak,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
