import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'models/sesi_makan.dart';
import 'ringkasan_sesi_page.dart';
import 'utils/format_waktu.dart';
import 'widgets/foto_makanan.dart';
import 'widgets/petunjuk_tombol_jam.dart';
import 'widgets/petunjuk_tombol_ukur.dart';
import 'widgets/ringkasan_nutrisi.dart';
import 'widgets/timeline_sampel.dart';

/// Tampilan penuh sesi aktif (§5): timeline 4 titik, foto, nutrisi, status
/// jam, dan dua jalan keluar — menyelesaikan sesi (data disimpan sebagai
/// `tidakLengkap`) atau membatalkannya (baris dihapus).
///
/// Halaman ini mengikuti `SesiMakanController` karena sampel bisa masuk dari
/// BLE kapan saja (§12.7). Bila sesi selesai selagi halaman terbuka, isinya
/// berganti menjadi pintu ke `RingkasanSesiPage`, bukan layar kosong.
///
/// Catatan test: hitung mundur memakai `Timer.periodic`, jadi selama masih ada
/// titik yang ditunggu gunakan `tester.pump(...)`, bukan `pumpAndSettle`.
class SesiBerjalanPage extends StatelessWidget {
  const SesiBerjalanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SesiMakanController>();
    final sesi = controller.sesiAktif;

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
          'Sesi Berjalan',
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
        child: sesi == null
            ? _SesiSudahBerakhir(controller: controller)
            : _IsiSesi(sesi: sesi, controller: controller),
      ),
    );
  }
}

class _IsiSesi extends StatelessWidget {
  const _IsiSesi({required this.sesi, required this.controller});

  final SesiMakan sesi;
  final SesiMakanController controller;

  @override
  Widget build(BuildContext context) {
    final t0 = sesi.t0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPerangkatBar(perangkat: controller.statusPerangkat),
          const SizedBox(height: 16),

          // Timeline 4 titik — inti layar ini.
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
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.timeline_rounded,
                          size: 18,
                          color: Color(0xFF0EAD69),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Titik Pengukuran',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A34),
                          ),
                        ),
                      ],
                    ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2F6F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          sesi.status.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0EAD69),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TimelineSampel(
                  sampel: sesi.sampel,
                  t0: t0,
                  indexBerikutnya: sesi.sampelBerikutnya?.index,
                  kemampuan: controller.statusPerangkat.metrikTampil,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Foto makanan tetap terlihat sepanjang jeda 2 jam (§8).
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
                    FotoMakanan(fotoPath: sesi.fotoPath, lebar: 64, tinggi: 64),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sesi.hasil?.ringkasanNama ?? 'Makanan',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A34),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t0 == null
                                ? 'Difoto ${formatJam(sesi.waktuFoto)}'
                                : 'Selesai makan ${formatJam(t0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8FA7A1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                RingkasanNutrisi(hasil: sesi.hasil),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Kejujuran soal keterlambatan data (§8), dan — sejak jam sungguhan
          // menempel — soal koneksi yang putus di tengah sesi
          // (rencana-produksi.md §4.3). Yang terakhir wajib dinyatakan
          // eksplisit: melihat "Jam terputus" di tengah sesi dua jam, tanpa
          // kalimat ini, wajar dibaca sebagai sesi yang sudah gagal, dan
          // pengguna akan membatalkannya sendiri padahal datanya aman.
          _KartuInfo(
            terputusDiTengahSesi:
                t0 != null && !controller.statusPerangkat.tersambung,
          ),
          const SizedBox(height: 20),

          if (sesi.waktuTidakPasti) ...[
            const _KartuWaktuTidakPasti(),
            const SizedBox(height: 20),
          ],

          if (sesi.t0 == null) ...[
            PetunjukTombolJam(
              status: sesi.status,
              perangkat: controller.statusPerangkat,
            ),
            const SizedBox(height: 12),
          ],

          // Setelah t0, yang ditunggu bukan lagi tombol "Selesai Makan"
          // melainkan tiap titik ukur — dan sejak protokol v1.3 titik itu
          // tidak datang sendiri (§9): jam dimatikan di antara pengukuran, jadi
          // ada yang harus memicunya. Widget ini menyembunyikan dirinya bila
          // tidak ada titik yang menunggu.
          if (sesi.t0 != null) ...[
            const PetunjukTombolUkur(),
            const SizedBox(height: 12),
          ],

          // Dua jalan keluar, dan bedanya adalah nasib datanya — karena itu
          // keduanya tidak boleh terlihat sama. "Selesaikan" menyimpan sesi
          // sebagai `tidakLengkap` beserta sampel yang sudah masuk;
          // "Batalkan" menghapusnya. Sebelum ini hanya yang kedua yang ada,
          // sehingga sesi yang jamnya tidak pernah menuntaskan pengukuran
          // memaksa pilihan antara membuang data yang sudah terkumpul atau
          // menunggu tenggat — sampai 2,5 jam sejak t0.
          //
          // Hanya ditawarkan setelah t0 ada. Sesi yang tombol jamnya belum
          // pernah ditekan bukan sesi yang belum selesai, melainkan sesi yang
          // belum mulai: tidak ada momen makan untuk direkam, dan
          // menyelesaikannya hanya akan menyimpan baris kosong.
          if (t0 != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => _konfirmasiSelesai(context),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF0EAD69),
                  side: const BorderSide(color: Color(0xFF0EAD69), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline_rounded, size: 18),
                    SizedBox(width: 8),
                    Text(
                      'Selesaikan Sesi',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _konfirmasiBatal(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Color(0xFFE2EBE8), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stop_circle_outlined, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Batalkan Sesi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  /// Menutup sesi yang jamnya tidak akan menuntaskan pengukurannya.
  ///
  /// Selalu dikonfirmasi, dan konfirmasinya menyebut **jumlah pengukuran yang
  /// sudah masuk** — bukan basa-basi "apakah Anda yakin". Itu satu-satunya
  /// angka yang menentukan apakah keputusannya benar, dan pengguna tidak bisa
  /// melihatnya dari tombol.
  ///
  /// Konsekuensi yang wajib dinyatakan: `akhiriLebihAwal()` memanggil
  /// `batalkanSesi()` ke jam, jadi sampel yang mungkin masih tertahan di buffer
  /// jam **tidak akan pernah masuk ke sesi ini** — alasan yang sama mengapa
  /// `lupakanPerangkat()` juga tidak pernah berjalan tanpa konfirmasi.
  Future<void> _konfirmasiSelesai(BuildContext context) async {
    final masuk = sesi.sampel
        .where((s) => s.status == StatusSampel.terisi)
        .length;
    final adaData = masuk > 0;

    final jadi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Selesaikan sesi ini?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        content: Text(
          adaData
              ? '$masuk dari ${sesi.sampel.length} pengukuran sudah masuk. '
                    'Sisanya ditandai terlewat dan sesi disimpan sebagai '
                    '"Tidak lengkap" — datanya tetap masuk riwayat dan ikut '
                    'dihitung.\n\n'
                    'Sampel yang mungkin masih tersimpan di jam tidak akan '
                    'masuk lagi ke sesi ini. Bila jam hanya sedang terputus, '
                    'sesi ini masih bisa ditunggu.'
              : 'Belum ada satu pun pengukuran yang masuk. Sesi tetap disimpan '
                    'sebagai "Tidak lengkap", tanpa data pengukuran, sebagai '
                    'catatan bahwa makan ini pernah terjadi.\n\n'
                    'Sampel yang mungkin masih tersimpan di jam tidak akan '
                    'masuk lagi ke sesi ini. Bila jam hanya sedang terputus, '
                    'sesi ini masih bisa ditunggu.',
          style: const TextStyle(
            fontSize: 13,
            color: Color(0xFF6B807B),
            height: 1.45,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Lanjutkan Sesi',
              style: TextStyle(
                color: Color(0xFF6B807B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Selesaikan',
              style: TextStyle(
                color: Color(0xFF0EAD69),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (jadi != true) return;
    // Tidak mem-pop halaman: `sesiAktif` menjadi null, dan badan halaman ini
    // berganti sendiri menjadi `_SesiSudahBerakhir` yang menawarkan pintu ke
    // ringkasannya. Mem-pop akan membuang pengguna ke shell tepat pada saat
    // ada sesuatu untuk dilihat.
    await controller.akhiriLebihAwal();
  }

  Future<void> _konfirmasiBatal(BuildContext context) async {
    final navigator = Navigator.of(context);
    final jadi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Batalkan sesi ini?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        content: const Text(
          'Sampel yang belum masuk tidak akan dikumpulkan lagi dan sesi ini '
          'tidak dihitung dalam analisis.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B807B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Lanjutkan Sesi',
              style: TextStyle(
                color: Color(0xFF6B807B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Batalkan',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (jadi != true) return;
    await controller.batalkan();
    navigator.pop(true);
  }
}

/// Apa yang sedang terjadi dengan data yang belum sampai.
///
/// Dua kalimat berbeda untuk dua keadaan berbeda: jam yang tersambung tetapi
/// sampelnya belum jatuh tempo, dan jam yang **terputus di tengah sesi**. Yang
/// kedua tampak seperti kegagalan padahal bukan — sampel terus diukur di
/// pergelangan tangan dan menunggu di buffer jam (docs/protokol-jam.md §6).
class _KartuInfo extends StatelessWidget {
  const _KartuInfo({required this.terputusDiTengahSesi});

  final bool terputusDiTengahSesi;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: terputusDiTengahSesi
            ? const Color(0xFFE2EBE8)
            : const Color(0xFFE8F8F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            terputusDiTengahSesi
                ? Icons.cloud_off_rounded
                : Icons.info_outline_rounded,
            color: terputusDiTengahSesi
                ? const Color(0xFF6B807B)
                : const Color(0xFF0EAD69),
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              terputusDiTengahSesi
                  ? 'Jam terputus, tetapi sesi ini tetap berjalan. Jam terus '
                        'mengukur sendiri dan menyimpan hasilnya; sampelnya '
                        'menyusul begitu jam tersambung lagi. Tidak perlu '
                        'membatalkan sesi.'
                  : 'Jam menyimpan sampel di buffer. Data bisa datang '
                        'terlambat — sesi tidak gagal hanya karena telat.',
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B807B),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sesi yang jam dindingnya tidak diketahui (docs/protokol-jam.md §4.3).
///
/// Ditampilkan, bukan disembunyikan: datanya nyata dan bentuk kurvanya benar.
/// Yang tidak boleh adalah membiarkan pengguna mengira waktunya juga benar.
class _KartuWaktuTidakPasti extends StatelessWidget {
  const _KartuWaktuTidakPasti();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF6E3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEFE0B8), width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.schedule_rounded, color: Color(0xFFB98B00), size: 18),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Jam tidak tersambung sepanjang sesi ini, sehingga waktunya tidak '
              'bisa dipastikan. Hasil pengukurannya tetap benar, tetapi sesi ini '
              'tidak dihitung sebagai sesi hari ini dan tidak ikut analisis '
              'tren.',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF7A6420),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sesi kelar selagi halaman ini terbuka — arahkan ke hasilnya, jangan
/// tinggalkan layar kosong.
class _SesiSudahBerakhir extends StatelessWidget {
  const _SesiSudahBerakhir({required this.controller});

  final SesiMakanController controller;

  @override
  Widget build(BuildContext context) {
    final sesi = controller.hasilBelumDibaca ?? controller.sesiTerakhir;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: Color(0xFF0EAD69),
            ),
            const SizedBox(height: 16),
            Text(
              sesi == null ? 'Tidak ada sesi berjalan' : 'Sesi sudah berakhir',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A34),
              ),
            ),
            if (sesi != null) ...[
              const SizedBox(height: 8),
              Text(
                sesi.verdict,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF6B807B)),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  controller.tandaiHasilDibaca();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RingkasanSesiPage(sesi: sesi),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EAD69),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Lihat Ringkasan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Status jam apa adanya: tersambung, baterai, dan jumlah sampel yang masih
/// tertahan di buffer jam (§4.1, §4.7).
class StatusPerangkatBar extends StatelessWidget {
  const StatusPerangkatBar({super.key, this.perangkat});

  final StatusPerangkat? perangkat;

  @override
  Widget build(BuildContext context) {
    final p = perangkat;
    final tersambung = p?.tersambung ?? false;
    final belumDipasangkan = p?.belumDipasangkan ?? true;
    final keterangan = <String>[
      // "Terputus" menjanjikan sesuatu yang akan kembali sendiri. Jam yang
      // belum pernah dipasangkan tidak akan, dan yang penyandingannya hilang
      // juga tidak — keduanya butuh tindakan user, jadi keduanya dinamai
      // sendiri (sama seperti kartu status di MenghubungkanPerangkatPage).
      tersambung
          ? 'Jam tersambung'
          : belumDipasangkan
          ? 'Belum ada jam'
          : (p?.penyandinganHilang ?? false)
          ? 'Jam tidak tersandingkan'
          : 'Jam terputus',
      if (p?.baterai != null) 'baterai ${p!.baterai}%',
      // "Sampel" adalah kosakata protokol, bukan kosakata pengguna. Yang perlu
      // diketahui adalah bahwa ada hasil pengukuran yang belum pindah dari jam
      // ke ponsel — dan kalimatnya berbeda menurut keadaan, karena artinya
      // memang berbeda: yang tersambung sedang berpindah saat ini juga (angkanya
      // turun sendiri sampai nol, lihat `BleAsliService._kurangiTertunda`),
      // sedangkan yang terputus akan menunggu sampai jamnya didekatkan.
      if ((p?.sampelTertunda ?? 0) > 0)
        tersambung
            ? 'mengambil ${p!.sampelTertunda} data dari jam'
            : '${p!.sampelTertunda} data menunggu di jam',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tersambung
                  ? const Color(0xFFE2F6F0)
                  : const Color(0xFFE2EBE8),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              tersambung ? Icons.watch_rounded : Icons.watch_off_rounded,
              size: 18,
              color: tersambung
                  ? const Color(0xFF0EAD69)
                  : const Color(0xFF8FA7A1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              keterangan.join(' · '),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A34),
              ),
            ),
          ),
          if (p?.sinkronTerakhir != null)
            Text(
              'sinkron ${formatWaktuRelatif(p!.sinkronTerakhir!)}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF8FA7A1)),
            ),
        ],
      ),
    );
  }
}
