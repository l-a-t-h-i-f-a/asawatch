import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/sesi_makan_controller.dart';

/// Dua cara mengukur satu titik sesi, dan keduanya berujung di tempat yang sama.
///
/// Saudara [PetunjukTombolJam], bukan salinannya. Yang membedakannya bukan copy
/// saja: yang ini mengirim `UKUR` dan menunggu paket Sampel, sedangkan yang itu
/// mengirim `MULAI_SESI` dan menunggu `TOMBOL_SELESAI_MAKAN`. Kondisi matinya
/// pun berbeda — yang ini hidup hanya selama ada titik yang jendelanya sudah
/// terbuka dan belum terisi.
///
/// Widget ini ada karena protokol v1.3: jam tidak bertahan lebih dari ~50 menit
/// menyala sementara sesi berdurasi lebih dari dua jam, jadi ia dimatikan di
/// antara titik ukur dan tidak bisa lagi menjadwalkan apa pun sendiri
/// (docs/protokol-jam.md §9, §12).
///
/// **Urutan penyebutannya dibalik dari [PetunjukTombolJam], dan itu disengaja.**
/// Untuk `t0`, tombol jam disebut lebih dulu karena orang sedang makan dan
/// ponselnya ada di meja lain. Di sini keadaannya kebalikan: yang membuat
/// pengguna bertindak adalah notifikasi yang baru berbunyi di ponselnya, jadi
/// ponselnya sudah pasti di tangan. Menyebut tombol jam lebih dulu berarti
/// menyuruhnya mencari tombol yang lebih jauh daripada yang sedang dipegang.
///
/// Yang **tidak** berubah: tombol jam tetap disebut. Aturannya bukan "jam harus
/// disebut duluan" melainkan "jam tidak boleh dihilangkan" — kalimat yang hilang
/// membuat pengguna mengira titik ukur hanya bisa diambil dari layar, padahal
/// justru tombol jam yang bekerja saat ponselnya tertinggal di ruangan lain.
class PetunjukTombolUkur extends StatefulWidget {
  const PetunjukTombolUkur({super.key, this.ringkas = false});

  /// Tanpa kotak penjelasnya, hanya tombol dan satu baris keterangan.
  ///
  /// Dipakai di kartu sesi Beranda, yang tepat di atas tombol ini sudah memasang
  /// hero berisi hitung mundur, nama titiknya, dan jam jadwalnya. Kotak penjelas
  /// versi penuh akan mengatakan ketiganya untuk kedua kalinya dalam jarak 12
  /// piksel — dan yang lebih buruk, mendorong tombolnya turun sejauh kotak itu,
  /// yang justru masalah yang sedang diperbaiki.
  ///
  /// Yang **tidak** boleh ikut hilang: alasan tombolnya mati. Di versi penuh
  /// alasan itu ada di dalam kotak; di sini ia pindah ke baris keterangan di
  /// bawah tombol, karena tombol mati tanpa sebab terbaca sebagai aplikasi rusak.
  final bool ringkas;

  @override
  State<PetunjukTombolUkur> createState() => _PetunjukTombolUkurState();
}

class _PetunjukTombolUkurState extends State<PetunjukTombolUkur> {
  bool _mengirim = false;
  String? _galat;

  /// Hitung mundurnya harus bergerak sendiri.
  ///
  /// Tanpa ini "Bisa diukur dalam 6 menit" akan membeku sampai ada hal lain yang
  /// memicu rebuild — dan selama titiknya belum jatuh tempo, tidak ada hal lain
  /// yang terjadi. Angka yang diam adalah angka yang tidak dipercaya.
  Timer? _detak;

  @override
  void initState() {
    super.initState();
    _detak = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _detak?.cancel();
    super.dispose();
  }

  Future<void> _ukur() async {
    setState(() {
      _mengirim = true;
      _galat = null;
    });
    try {
      final galat = await context
          .read<SesiMakanController>()
          .ukurTitikSekarang();
      if (!mounted) return;
      setState(() => _galat = galat);
      // Yang berhasil sengaja tidak mengubah apa pun di sini: titiknya baru
      // benar-benar terisi saat sampelnya datang, dan saat itu widget ini
      // berganti sendiri lewat controller.
    } finally {
      if (mounted) setState(() => _mengirim = false);
    }
  }

  String _hitungMundur(Duration sisa) {
    final menit = (sisa.inSeconds / 60).ceil();
    if (menit >= 60) {
      final jam = menit ~/ 60;
      final sisaMenit = menit % 60;
      return sisaMenit == 0
          ? '$jam jam lagi'
          : '$jam jam $sisaMenit menit lagi';
    }
    if (menit > 1) return '$menit menit lagi';
    return '${sisa.inSeconds} detik lagi';
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SesiMakanController>();
    final titik = c.titikBerikutnya;
    if (titik == null) return const SizedBox.shrink();

    final sisa = c.sisaSampaiTitikBerikutnya ?? Duration.zero;
    final belumWaktunya = sisa.inSeconds > 0;
    final tersambung = c.statusPerangkat.tersambung;
    final siap = !belumWaktunya && tersambung;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.ringkas) ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: siap ? const Color(0xFFE2F6F0) : const Color(0xFFE2EBE8),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  siap
                      ? Icons.monitor_heart_rounded
                      : (belumWaktunya
                            ? Icons.schedule_rounded
                            : Icons.watch_off_rounded),
                  size: 18,
                  color: siap
                      ? const Color(0xFF0EAD69)
                      : const Color(0xFF6B807B),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        belumWaktunya
                            ? 'Pengukuran ${titik.label} ${_hitungMundur(sisa)}'
                            : (tersambung
                                  ? 'Saatnya pengukuran ${titik.label}'
                                  : 'Jam belum tersambung'),
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: siap
                              ? const Color(0xFF0EAD69)
                              : const Color(0xFF6B807B),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        belumWaktunya
                            // Diminta menyalakan jam **sebelum** waktunya, bukan
                            // tepat pada waktunya: menyalakan jam dan
                            // memasangnya butuh waktu, dan titik yang diukur
                            // terlambat tidak punya pengganti.
                            ? 'Jam boleh dimatikan dulu untuk menghemat baterai. '
                                  'Nyalakan dan pakai kembali beberapa menit '
                                  'sebelum waktunya.'
                            : (tersambung
                                  ? 'Nyalakan jam, pakai rapat di pergelangan, '
                                        'lalu tekan tombol di bawah. Bisa juga '
                                        'langsung dari tombol ukur di jam kalau '
                                        'ponsel sedang tidak dipegang.'
                                  : 'Nyalakan jam dan dekatkan ke ponsel. '
                                        'Pengukuran ini masih bisa diambil '
                                        'setelahnya.'),
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

          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: (siap && !_mengirim) ? _ukur : null,
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
                  const Icon(Icons.favorite_rounded, size: 20),
                const SizedBox(width: 10),
                Text(
                  _mengirim ? 'Mengukur…' : 'Ukur ${titik.label} Sekarang',
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
              (belumWaktunya
                  ? 'Mengukur terlalu awal akan mencatat angka dari titik yang '
                        'salah, jadi tombolnya menyala tepat waktu.'
                  : !tersambung
                  // Hanya terpakai di mode ringkas: versi penuh sudah
                  // mengatakannya di dalam kotak di atas.
                  ? 'Jam belum tersambung — nyalakan dan dekatkan ke ponsel. '
                        'Pengukuran ini masih bisa diambil setelahnya.'
                  : 'Pengukuran memakan waktu beberapa detik.'),
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
    );
  }
}
