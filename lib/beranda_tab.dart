import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'models/sesi_makan.dart';
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

/// Dua tingkat kartu, dan perbedaannya yang memikul hierarki halaman ini.
///
/// Sebelumnya **setiap** kartu di Beranda memakai garis tepi 1,5 px yang sama:
/// sesi yang sedang berjalan, ringkasan harian, sesi terakhir, dan pintu pindai
/// tampil dengan bobot yang persis sama, sehingga tidak ada satu pun yang
/// dilihat lebih dulu. Yang utama sekarang tidak lagi bergaris — ia diangkat
/// dari latar dengan bayangan, yang di atas latar 0xFFF4FAF7 terbaca jauh lebih
/// tegas daripada garis setipis itu — sedangkan yang sekunder tetap bergaris dan
/// dengan begitu jelas berada satu tingkat di bawahnya.
///
/// Warna bayangannya diturunkan dari warna teks utama, bukan hitam netral dan
/// bukan pula rona baru: bayangan kelabu di atas latar kehijauan terbaca kotor.
final BoxDecoration _dekorasiUtama = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(24),
  boxShadow: [
    BoxShadow(
      color: const Color(0xFF1E3A34).withValues(alpha: 0.07),
      blurRadius: 18,
      offset: const Offset(0, 6),
    ),
  ],
);

/// Kartu tingkat dua: tetap bergaris tipis seperti sebelumnya.
final BoxDecoration _dekorasiSekunder = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(20),
  border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
);

/// Label bagian di dalam kartu — kecil, huruf besar, berjarak.
///
/// Ada supaya angka besar di bawahnya tidak perlu menjelaskan dirinya sendiri
/// dengan ikut membesar.
const TextStyle _gayaLabelKecil = TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w700,
  letterSpacing: 0.9,
  color: Color(0xFF8FA7A1),
);

/// Angka yang dicari mata pertama kali di sebuah kartu.
const TextStyle _gayaHero = TextStyle(
  fontSize: 36,
  fontWeight: FontWeight.w700,
  color: Color(0xFF1E3A34),
  height: 1.05,
);

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
            // Header. Tanggal dan sapaan bertukar tempat: tanggal naik menjadi
            // baris atas yang kecil dan tenang, nama turun menjadi baris besar.
            // Sebelumnya keduanya 16 dan 12 px — dua ukuran yang terlalu
            // berdekatan untuk terbaca sebagai hierarki, sehingga mata harus
            // membaca keduanya dulu untuk tahu mana yang penting.
            //
            // Emoji 👋 ikut hilang. Ia satu-satunya elemen dekoratif di halaman
            // ini dan berdiri tepat di sebelah satu-satunya kata yang perlu
            // dibaca di baris itu.
            Row(
              children: [
                // Foto orang asing dari Unsplash dihapus bersama sisa identitas
                // demo; ia juga tidak pernah termuat di rilis karena izin
                // INTERNET tidak dideklarasikan.
                const CircleAvatar(
                  radius: 24,
                  backgroundColor: Color(0xFFE2F6F0),
                  child: Icon(
                    Icons.person_rounded,
                    size: 26,
                    color: Color(0xFF0EAD69),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _formatCurrentDate().toUpperCase(),
                        style: _gayaLabelKecil,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        // Tanpa nama tersimpan, sapaannya berhenti di "Halo" —
                        // bukan menyapa dengan nama orang lain.
                        _nama.isEmpty ? 'Halo' : 'Halo, $_nama',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A34),
                          height: 1.1,
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
            const SizedBox(height: 18),

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

        // Timeline mendominasi layar saat sesi berjalan (§4.1 B) — dan sejak
        // redesain ini, satu angka mendominasi timeline-nya. Hitung mundur ke
        // titik berikutnya sebelumnya hanya angka 14 px di ujung salah satu dari
        // empat baris yang seragam; ia harus dicari, padahal ia satu-satunya hal
        // di kartu ini yang berubah tiap detik dan satu-satunya yang menentukan
        // kapan pengguna harus bertindak.
        Container(
          padding: const EdgeInsets.all(18),
          decoration: _dekorasiUtama,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tindakan berdiri di atas timeline, bukan di bawah kartu foto.
              //
              // Sebelumnya keduanya terpisah satu kartu penuh: hitung mundur ke
              // titik berikutnya di baris teratas, tombol yang mengukur titik itu
              // di dasar halaman — di bawah timeline, di bawah foto makanan, dan
              // sering di bawah lipatan layar. Yang membaca "6 menit lagi" harus
              // menebak sendiri bahwa ada yang harus ditekan, lalu mencarinya.
              //
              // Sesi draft memakai slot yang sama dengan PetunjukTombolJam. Ia
              // tidak punya hero — yang ditunggu di sana bukan waktu melainkan
              // sebuah tekanan tombol — jadi petunjuk itulah yang berdiri
              // sendirian di puncak kartu.
              if (sesi.t0 == null)
                PetunjukTombolJam(
                  status: sesi.status,
                  perangkat: controller.statusPerangkat,
                )
              else ...[
                _HeroSesi(sesi: sesi),
                const SizedBox(height: 16),
                // Ringkas: hero di atasnya sudah menyebut titik, jadwal, dan
                // sisa waktunya, jadi kotak penjelas versi penuh hanya akan
                // mengulanginya sambil mendorong tombolnya turun lagi.
                const PetunjukTombolUkur(ringkas: true),
              ],
              const SizedBox(height: 18),
              const Divider(height: 1, thickness: 1, color: Color(0xFFE2EBE8)),
              const SizedBox(height: 18),
              TimelineSampel(
                sampel: sesi.sampel,
                t0: sesi.t0,
                indexBerikutnya: sesi.sampelBerikutnya?.index,
                kemampuan: controller.statusPerangkat.metrikTampil,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Di bawahnya: foto makanan dan ringkasan nutrisinya. Kartu tingkat dua
        // — apa yang dimakan sudah diputuskan dan tidak menuntut apa pun lagi.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          decoration: _dekorasiSekunder,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  FotoMakanan(fotoPath: sesi.fotoPath, lebar: 56, tinggi: 56),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('YANG DIMAKAN', style: _gayaLabelKecil),
                        const SizedBox(height: 3),
                        Text(
                          sesi.hasil?.ringkasanNama ?? 'Makanan',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF1E3A34),
                            height: 1.2,
                          ),
                        ),
                      ],
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

        // Yang tersisa di dasar kartu hanyalah pintu ke halaman sesi — sebuah
        // tindakan sekunder, dan satu-satunya yang pantas berada sejauh ini dari
        // atas. Ia kini juga ditawarkan untuk sesi draft, karena
        // SesiBerjalanPage melayani draft dengan sama baiknya.
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
    );
  }
}

/// Satu angka yang menjawab "kapan aku harus mengukur lagi".
///
/// Hanya dipasang setelah `t0` ada — sebelum itu tidak ada yang bisa dihitung
/// mundur. Kedua keadaannya memakai slot yang sama persis — label kecil di atas,
/// angka atau kata besar di tengah, satu kalimat di bawah — supaya pergantian
/// keadaan tidak mengubah bentuk kartu. Kartu yang bergeser tiap kali keadaannya
/// berubah memaksa mata mencari ulang tempat angka itu berada.
class _HeroSesi extends StatelessWidget {
  const _HeroSesi({required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    final jadwal = sesi.jadwalBerikutnya;
    final berikutnya = sesi.sampelBerikutnya;

    final String label;
    final Widget utama;
    final String bawah;

    if (jadwal == null || berikutnya == null) {
      // Semua titik sudah terisi atau terlewat; sesi tinggal ditutup.
      label = 'SEMUA TITIK SELESAI';
      utama = Text(
        'Selesai',
        style: _gayaHero.copyWith(color: const Color(0xFF0EAD69)),
      );
      bawah = 'Ringkasan sesinya akan muncul sebentar lagi.';
    } else {
      label = 'TITIK BERIKUTNYA';
      utama = HitungMundur(
        target: jadwal,
        gaya: _gayaHero.copyWith(color: const Color(0xFF0EAD69)),
        // Nol bukan lagi hitungan, jadi ia turun ukuran: yang berlaku saat itu
        // adalah ajakan mengukur di PetunjukTombolUkur, bukan angka ini.
        gayaSelesai: const TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: Color(0xFF0EAD69),
          height: 1.05,
        ),
      );
      bawah = '${berikutnya.label} · dijadwalkan pukul ${formatJam(jadwal)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: _gayaLabelKecil),
        const SizedBox(height: 8),
        utama,
        const SizedBox(height: 6),
        Text(
          bawah,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF6B807B),
            height: 1.3,
          ),
        ),
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
        padding: const EdgeInsets.all(18),
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
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: Color(0xFF0EAD69),
                    ),
                  ),
                ),
                if (t0 != null)
                  Text(
                    formatWaktuRelatif(t0),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B807B),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),

            // Kenaikan puncak naik menjadi angka utama kartu ini. Ia satu-satunya
            // hasil sesi yang bisa dibaca dalam sekali lihat — verdict di
            // bawahnya adalah kalimat, dan kalimat menuntut dibaca sampai habis
            // sebelum memberi tahu apa pun.
            if (delta != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    delta > 0 ? '+$delta' : '$delta',
                    style: _gayaHero.copyWith(fontSize: 34),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'mg/dL dari baseline',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B807B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],

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
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A34),
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Text(
                            delta == null
                                ? 'Ketuk untuk melihat rinciannya'
                                : 'Ketuk untuk melihat kurva responsnya',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF0EAD69),
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right_rounded,
                            size: 16,
                            color: Color(0xFF0EAD69),
                          ),
                        ],
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
        if (jumlahSesi == 0)
          const _AjakanFoto()
        else
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _dekorasiUtama,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Kalori keluar dari barisan dan menjadi angka kartu ini.
                // Sebelumnya keempat makro adalah empat baris yang identik, jadi
                // pertanyaan yang paling sering dibawa ke halaman ini — "hari ini
                // sudah berapa?" — harus dijawab dengan membaca keempatnya lebih
                // dulu untuk menemukan yang mana kalori.
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(formatAngka(total.kalori), style: _gayaHero),
                    const SizedBox(width: 6),
                    const Text(
                      'kcal hari ini',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B807B),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                const Divider(
                  height: 1,
                  thickness: 1,
                  color: Color(0xFFE2EBE8),
                ),
                const SizedBox(height: 16),
                const Text('MAKRO', style: _gayaLabelKecil),
                const SizedBox(height: 12),
                _BarisMakro(label: 'Karbohidrat', nilai: total.karbohidrat),
                const SizedBox(height: 12),
                _BarisMakro(label: 'Protein', nilai: total.protein),
                const SizedBox(height: 12),
                _BarisMakro(label: 'Lemak', nilai: total.lemak),
              ],
            ),
          ),
      ],
    );
  }
}

/// Satu-satunya ajakan bertindak di wajah idle.
///
/// Tombol kamera di nav adalah satu-satunya jalan memulai sesi, dan sebelum ini
/// tidak ada satu pun kalimat di Beranda yang menyebutnya — kecuali pada
/// instalasi yang riwayatnya benar-benar kosong. Begitu ada satu sesi
/// tersimpan, petunjuk itu hilang selamanya, padahal ia dibutuhkan tiap pagi.
///
/// Karena itu pemicunya **"belum ada sesi hari ini"**, bukan "belum pernah ada
/// sesi": keduanya sama-sama keadaan di mana yang benar untuk dilakukan adalah
/// memfoto makanan.
class _AjakanFoto extends StatelessWidget {
  const _AjakanFoto();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 26),
      decoration: _dekorasiUtama,
      child: Column(
        children: const [
          SizedBox(
            width: 56,
            height: 56,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Color(0xFFE2F6F0),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.photo_camera_rounded,
                size: 28,
                color: Color(0xFF0EAD69),
              ),
            ),
          ),
          SizedBox(height: 14),
          Text(
            'Belum ada sesi hari ini',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E3A34),
            ),
          ),
          SizedBox(height: 6),
          Text(
            'Foto makananmu lewat tombol kamera di bawah untuk memulai sesi.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: Color(0xFF7E9A94),
            ),
          ),
        ],
      ),
    );
  }
}

/// Satu makro, tanpa pembanding.
///
/// Bar kemajuan dan penyebutnya dihapus bersama `TargetHarian`: angka yang tidak
/// pernah dipilih siapa pun bukan target, dan bar yang mengukur terhadapnya
/// hanya menggambar pecahan yang tidak berarti apa-apa. Yang tersisa adalah
/// jumlah yang benar-benar diketahui aplikasi.
class _BarisMakro extends StatelessWidget {
  const _BarisMakro({required this.label, required this.nilai});

  final String label;
  final double nilai;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          ikonMakro[label] ?? Icons.circle,
          size: 14,
          color: const Color(0xFF8FA7A1),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1E3A34),
            ),
          ),
        ),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1E3A34),
            ),
            children: [
              TextSpan(text: formatAngka(nilai)),
              const TextSpan(
                text: ' g',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8FA7A1),
                ),
              ),
            ],
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

    // Tidak ada kartu kosong di sini lagi. Ajakan memfoto sudah berdiri di
    // ringkasan harian, dan dua kartu kosong berturut-turut pada instalasi baru
    // mengatakan hal yang sama dua kali — sambil membuat halaman terlihat penuh
    // oleh ketiadaan.
    if (sesi == null) return const SizedBox.shrink();

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
            decoration: _dekorasiSekunder,
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
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF1E3A34),
                          height: 1.3,
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
      padding: const EdgeInsets.all(16),
      decoration: _dekorasiSekunder,
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
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF1E3A34),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              RichText(
                text: TextSpan(
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E3A34),
                    height: 1.05,
                  ),
                  children: [
                    TextSpan(text: formatAngka(puncak.last)),
                    const TextSpan(
                      text: ' mg/dL',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B807B),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${puncak.length} sesi terakhir',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF8FA7A1),
                ),
              ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: SizedBox(
              height: 52,
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
