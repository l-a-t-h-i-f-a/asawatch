import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/sesi_makan_controller.dart';
import '../models/sesi_makan.dart';

/// Dua cara memulai sesi, dan keduanya berujung di tempat yang sama.
///
/// Awalnya widget ini hanya berupa petunjuk: tombol "Selesai Makan & Pantau"
/// dihapus dari aplikasi (§6) karena `t0` hanya boleh datang dari jam, dan yang
/// tersisa bagi aplikasi cuma memberi tahu apa yang sedang ditunggu. Sekarang
/// tombolnya kembali — **tanpa mencabut aturan itu**.
///
/// Yang membuat keduanya bisa berdiri bersama adalah bentuk perintahnya:
/// tombol di sini mengirim `MULAI_SESI` (protokol §5.1), yang isinya cuma
/// `sesiId` **tanpa waktu sama sekali**. Jam yang membaca pencacahnya sendiri
/// lalu mengirim `TOMBOL_SELESAI_MAKAN` seperti biasa. Jadi ini bukan aplikasi
/// yang menetapkan `t0`, melainkan aplikasi yang menekan tombol jam dari jauh —
/// dan `t0` tetap berada di garis waktu jam, tetap sebanding dengan `uptime_s`
/// tiap sampel (§5.3).
///
/// Tiga hal yang dijaga tampilannya:
///
/// 1. **Tombol jam tetap disebut, bukan disembunyikan.** Ia satu-satunya yang
///    bekerja saat HP jauh atau mati, dan justru itu kasus yang paling sering:
///    orang tidak memegang ponselnya sambil makan. Menghapus kalimatnya akan
///    membuat pengguna mengira sesi hanya bisa dimulai dari layar.
/// 2. **Tombol aplikasi tidak berpura-pura sudah berhasil.** Setelah ditekan ia
///    menunggu jawaban jam, dan yang mengubah layar adalah balasan itu — bukan
///    ketukannya. Sesi yang tampak berjalan sebelum jamnya setuju berbohong
///    tepat pada detik yang paling menentukan.
/// 3. **Jam terputus mematikan tombolnya beserta alasannya.** Perintahnya
///    berjalan lewat BLE; tanpa tautan, tidak ada tombol mana pun yang bisa
///    dipakai — dan itu dikatakan, bukan dibiarkan sebagai ketukan yang tidak
///    menghasilkan apa-apa.
class PetunjukTombolJam extends StatefulWidget {
  const PetunjukTombolJam({
    super.key,
    required this.status,
    required this.perangkat,
  });

  final StatusSesi status;
  final StatusPerangkat perangkat;

  @override
  State<PetunjukTombolJam> createState() => _PetunjukTombolJamState();
}

class _PetunjukTombolJamState extends State<PetunjukTombolJam> {
  bool _mengirim = false;
  String? _galat;

  Future<void> _mulai() async {
    setState(() {
      _mengirim = true;
      _galat = null;
    });
    try {
      final berhasil = await context
          .read<SesiMakanController>()
          .mulaiSesiDariApp();
      if (!mounted) return;
      if (!berhasil) {
        setState(() {
          _galat =
              'Jam belum menerima perintahnya. Dekatkan jam ke ponsel, lalu '
              'coba lagi — atau tekan langsung tombol di jam.';
        });
      }
      // Yang berhasil sengaja tidak mengubah apa pun di sini: sesinya baru
      // benar-benar dimulai saat jam mengirim balik tombolnya, dan saat itu
      // seluruh widget ini berganti wajah lewat controller.
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status;
    final perangkat = widget.perangkat;

    // Tiga keadaan, bukan dua. Kalau tombolnya sudah ditekan, sesi sudah
    // berjalan — mengulang "jam belum tersambung" di sana adalah kebohongan:
    // sinyalnya justru baru saja sampai, dan sampel sedang ditulis.
    final sudahMulai =
        status != StatusSesi.draft && status != StatusSesi.menungguPerangkat;
    // Baterai kritis membuat jam men-`NAK` `MULAI_SESI` **dan** membuat tombol
    // fisiknya tidak berbuat apa-apa (§5.5 bit2, §7 kode 0x06). Jadi bukan
    // hanya tombol di layar ini yang mati — kalimatnya harus menyebut keduanya,
    // atau orang akan berpindah menekan tombol jam yang sama-sama tidak
    // menjawab dan menyimpulkan sesinya rusak.
    final bateraiKritis = perangkat.bateraiKritis;
    // Baseline diukur tepat saat rana kamera ditekan (`UKUR` index 0), jadi
    // pengukuran itu sedang berjalan justru di layar ini — sebelum sesinya
    // punya t0, dan karena itu sebelum `PetunjukTombolUkur` ada di layar sama
    // sekali. Tanpa baris ini, satu-satunya pengukuran yang terjadi tanpa
    // diminta pengguna adalah juga satu-satunya yang tidak pernah dikabarkan.
    final kemajuan = context.watch<SesiMakanController>().kemajuanUkur;
    final siap =
        status == StatusSesi.draft && perangkat.tersambung && !bateraiKritis;
    final hijau = siap || sudahMulai;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: hijau ? const Color(0xFFE2F6F0) : const Color(0xFFE2EBE8),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                sudahMulai
                    ? Icons.check_circle_rounded
                    : bateraiKritis
                    ? Icons.battery_alert_rounded
                    : (siap ? Icons.watch_rounded : Icons.watch_off_rounded),
                size: 18,
                color: hijau
                    ? const Color(0xFF0EAD69)
                    : const Color(0xFF6B807B),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sudahMulai
                          ? 'Sesi sudah dimulai'
                          : siap
                          ? 'Selesai makan? Tekan tombol di jam'
                          : bateraiKritis
                          ? 'Baterai jam habis'
                          : 'Jam belum tersambung',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: hijau
                            ? const Color(0xFF0EAD69)
                            : const Color(0xFF6B807B),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      sudahMulai
                          ? 'Sesi berjalan memakai waktu jam. Pantau '
                                'perkembangannya di layar Sesi Berjalan.'
                          : (siap
                                // Kelebihan tombol jam disebut apa adanya, bukan
                                // dijual: ia bekerja walau ponselnya ditinggal
                                // di meja lain — dan itu memang yang biasanya
                                // terjadi saat orang sedang makan.
                                ? 'Tombolnya bekerja walau ponsel Anda sedang '
                                      'tidak dipegang. Kalau ponselnya ada di '
                                      'tangan, tombol di bawah ini sama saja.'
                                : bateraiKritis
                                ? 'Di bawah 10%, tombol Selesai Makan di jam '
                                      'juga tidak berfungsi. Isi daya jam dulu '
                                      '— fotonya tetap tersimpan.'
                                : 'Tombol Selesai Makan di jam baru menyala '
                                      'setelah jam tersambung. Fotonya tetap '
                                      'tersimpan.'),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B807B),
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Kabar pengukuran baseline. **Tombolnya tidak dimatikan** — firmware
        // sengaja tidak memeriksa `s_ukur_aktif` saat tombol Selesai Makan
        // ditekan (§9), karena orang yang selesai makan tidak boleh menunggu
        // sensor. Yang perlu diketahui hanyalah jamnya memang sedang bekerja,
        // supaya pengukuran yang berjalan sendiri tidak terbaca sebagai jam
        // yang tidak melakukan apa-apa.
        if (kemajuan != null && !sudahMulai) ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF0EAD69),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  kemajuan.macet
                      ? 'Jam sedang mengukur baseline, tetapi belum menemukan '
                            'nadi. Rapatkan jam di pergelangan.'
                      : kemajuan.persen != null
                      ? 'Jam sedang mengukur baseline… ${kemajuan.persen}%'
                      : 'Jam sedang mengukur baseline…',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B807B),
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],

        // Tombolnya hanya ada selama sesi memang belum dimulai. Setelah t0
        // datang tidak ada lagi yang bisa dilakukannya, dan tombol yang tersisa
        // di layar hanya mengundang ketukan yang tidak menghasilkan apa-apa.
        if (!sudahMulai) ...[
          const SizedBox(height: 12),
          SizedBox(
            height: 52,
            child: ElevatedButton(
              onPressed: (siap && !_mengirim) ? _mulai : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EAD69),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFC7DAD5),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_mengirim)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  else
                    const Icon(Icons.restaurant_rounded, size: 20),
                  const SizedBox(width: 10),
                  Text(
                    // Kalimat orang, bukan nama perintah. Yang ditekan pengguna
                    // adalah pernyataan tentang dirinya — "saya sudah selesai
                    // makan" — dan itulah yang membuatnya tidak tertukar dengan
                    // "Selesaikan Sesi" yang justru mengakhiri pemantauan.
                    _mengirim
                        ? 'Memberi tahu jam…'
                        : 'Saya Sudah Selesai Makan',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _galat ??
                (siap
                    ? 'Jam yang mencatat waktunya, bukan ponsel — hasilnya sama '
                          'persis dengan menekan tombol di jam.'
                    : bateraiKritis
                    ? 'Baterai jam tinggal ${perangkat.baterai ?? 0}% — jam '
                          'menolak memulai sesi di bawah 10%. Isi daya jam dulu.'
                    : 'Menunggu jam tersambung kembali.'),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              height: 1.35,
              color: _galat == null
                  ? const Color(0xFF9CB1AC)
                  : const Color(0xFFC0392B),
            ),
          ),
        ],
      ],
    );
  }
}
