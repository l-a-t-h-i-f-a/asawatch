import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'menghubungkan_perangkat_page.dart';
import 'models/sesi_makan.dart';
import 'services/izin_ble.dart';
import 'services/protokol_jam.dart' show GalatJam;
import 'utils/format_waktu.dart';
import 'utils/ikon.dart';

/// Pindai kesehatan atas permintaan — satu perintah `UKUR_SEKARANG` ke jam
/// (docs/protokol-jam.md §5.1), di luar sesi makan mana pun.
///
/// Perintahnya sudah ada sejak Tahap B; yang baru di sini hanyalah pengguna
/// boleh menekannya sendiri, bukan cuma alur kalibrasi. Karena itu tidak ada
/// satu byte pun yang berubah di kawat.
///
/// Empat hal yang membentuk halaman ini:
///
/// 1. **Bertahap, bukan satu tombol di tengah layar.** Pengukuran memakan waktu
///    puluhan detik dan hasilnya bergantung pada apa yang dilakukan tubuh selama
///    itu. Layar yang langsung mengukur tanpa memberi tahu cara duduk
///    menghasilkan angka yang salah dengan cara yang tidak kelihatan salah.
/// 2. **Menunggu itu ditemani.** Detik berjalan ditampilkan dan kalimatnya
///    berganti seiring waktu, karena tanpa itu pengukuran 40 detik terbaca
///    sebagai aplikasi yang menggantung — dan orang akan menggerakkan tangannya
///    untuk "membangunkan", persis hal yang merusak pembacaannya.
/// 3. **Metrik yang gagal terbaca dikatakan gagal**, bukan ditulis `—` begitu
///    saja. Protokol memakai sentinel 0 → null (§5.2); yang null di sini punya
///    kalimatnya sendiri beserta apa yang bisa dilakukan.
/// 4. **Hasilnya tidak masuk riwayat, dan itu dikatakan.** Riwayat aplikasi ini
///    berisi sesi makan; satu pembacaan lepas tanpa `t0` dan tanpa pembanding
///    bukan sesi. Menyimpannya diam-diam ke tabel yang sama akan mencemari
///    seluruh hitungan `AnalisisSesi`, dan tidak menyimpannya tanpa berkata
///    apa-apa membuat pengguna mencarinya besok pagi.
class PindaiKesehatanPage extends StatefulWidget {
  const PindaiKesehatanPage({super.key, this.izin});

  /// Diteruskan apa adanya ke [MenghubungkanPerangkatPage], yang ditawarkan
  /// ketika belum ada jam yang dipasangkan. null berarti `izinBleBawaan`; ada di
  /// sini hanya supaya halaman ini bisa dites tanpa saluran platform izin.
  final IzinBle? izin;

  @override
  State<PindaiKesehatanPage> createState() => _PindaiKesehatanPageState();
}

enum _Tahap { persiapan, mengukur, hasil }

class _PindaiKesehatanPageState extends State<PindaiKesehatanPage>
    with SingleTickerProviderStateMixin {
  _Tahap _tahap = _Tahap.persiapan;
  String? _galat;

  /// Pengguna berhenti menunggu. Jam **tidak** bisa disuruh membatalkan
  /// pengukuran yang sudah berjalan (tidak ada opcode untuk itu, §5.1), jadi
  /// yang berhenti di sini hanyalah layarnya. Hasilnya tetap disimpan controller
  /// kalau sempat sampai, dan muncul sebagai kartu "hasil terakhir".
  bool _berhentiMenunggu = false;

  Timer? _detak;
  DateTime? _mulaiPada;

  /// Dibuat di [initState], **bukan** sebagai `late final` yang menunggu
  /// dipakai: halaman yang ditutup tanpa pernah memindai membuat `dispose()`
  /// menjadi sentuhan pertamanya, dan membuat `Ticker` di dalam dispose berarti
  /// mencari `TickerMode` lewat pohon widget yang sudah dibongkar.
  late final AnimationController _denyut;

  @override
  void initState() {
    super.initState();
    _denyut = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );
  }

  @override
  void dispose() {
    _detak?.cancel();
    _denyut.dispose();
    super.dispose();
  }

  int get _detikBerjalan {
    final mulai = _mulaiPada;
    if (mulai == null) return 0;
    return DateTime.now().difference(mulai).inSeconds;
  }

  Future<void> _mulaiPindai() async {
    final controller = context.read<SesiMakanController>();

    setState(() {
      _tahap = _Tahap.mengukur;
      _galat = null;
      _berhentiMenunggu = false;
      _mulaiPada = DateTime.now();
    });
    _denyut.repeat();
    // Hanya untuk menggerakkan angka detik; perintahnya sendiri tidak
    // dijadwalkan oleh timer ini.
    _detak = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });

    try {
      await controller.pindaiKesehatan();
      if (!mounted || _berhentiMenunggu) return;
      setState(() => _tahap = _Tahap.hasil);
    } on GalatJam catch (e) {
      if (!mounted || _berhentiMenunggu) return;
      setState(() {
        _tahap = _Tahap.persiapan;
        _galat = e.pesanPengguna;
      });
    } catch (_) {
      if (!mounted || _berhentiMenunggu) return;
      setState(() {
        _tahap = _Tahap.persiapan;
        _galat =
            'Pengukuran tidak selesai. Pastikan jam terpasang dan tersambung, '
            'lalu coba lagi.';
      });
    } finally {
      _detak?.cancel();
      _detak = null;
      if (mounted) _denyut.stop();
    }
  }

  void _hentikanMenunggu() {
    _detak?.cancel();
    _detak = null;
    _denyut.stop();
    setState(() {
      _berhentiMenunggu = true;
      _tahap = _Tahap.persiapan;
    });
  }

  // --- Tampilan -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        // Selagi mengukur, tombol kembali dihilangkan: meninggalkan halaman
        // tidak menghentikan jam, dan tombol yang tampak seperti "batal" tetapi
        // bukan lebih buruk daripada tidak ada tombol sama sekali. Yang
        // menghentikan penantian ada di badan halaman, dengan kalimatnya.
        leading: _tahap == _Tahap.mengukur
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A34)),
                onPressed: () => Navigator.pop(context),
              ),
        automaticallyImplyLeading: false,
        title: const Text(
          'Pindai Kesehatan',
          style: TextStyle(
            color: Color(0xFF1E3A34),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: switch (_tahap) {
            _Tahap.persiapan => _persiapan(),
            _Tahap.mengukur => _mengukur(),
            _Tahap.hasil => _hasil(),
          },
        ),
      ),
    );
  }

  // Tahap 1 — persiapan, sekaligus tempat galat dan hasil terakhir muncul.
  Widget _persiapan() {
    final controller = context.watch<SesiMakanController>();
    final perangkat = controller.statusPerangkat;
    final terakhir = controller.pindaiTerakhir;
    final halangan = controller.alasanJamTidakBisaUkur;
    final siap = halangan == null && !controller.sedangMemindai;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_galat != null) ...[
          _KartuGalat(pesan: _galat!),
          const SizedBox(height: 16),
        ],

        if (!perangkat.tersambung) ...[
          _KartuJamBelumSiap(perangkat: perangkat, izin: widget.izin),
          const SizedBox(height: 16),
        ],

        if (_berhentiMenunggu && controller.sedangMemindai) ...[
          const _KartuInfo(
            ikon: Icons.hourglass_bottom_rounded,
            teks:
                'Jam masih menyelesaikan pengukurannya. Hasilnya akan muncul di '
                'halaman ini kalau sempat sampai.',
          ),
          const SizedBox(height: 16),
        ],

        if (terakhir != null) ...[
          _KartuHasilTerakhir(
            hasil: terakhir,
            onLihat: () => setState(() => _tahap = _Tahap.hasil),
          ),
          const SizedBox(height: 16),
        ],

        const Text(
          'Mengukur di luar jam makan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Jam akan membaca gula darah, detak jantung, tekanan darah, dan kadar '
          'oksigen sekali jalan. Prosesnya sekitar setengah menit sampai satu '
          'menit, dan hasilnya sangat bergantung pada tenang atau tidaknya Anda '
          'selama itu.',
          style: TextStyle(fontSize: 12, color: Color(0xFF6B807B), height: 1.5),
        ),
        const SizedBox(height: 20),

        const _JudulLangkah(nomor: 1, judul: 'Siapkan dulu'),
        const SizedBox(height: 12),
        const _KartuDaftarPeriksa(
          butir: [
            (
              ikon: Icons.watch_outlined,
              teks:
                  'Jam dipakai pas — tidak longgar — sedikit di atas tulang '
                  'pergelangan.',
            ),
            (
              ikon: Icons.event_seat_outlined,
              teks:
                  'Duduk tenang dulu 5 menit: punggung bersandar, kaki menapak '
                  'lantai, kaki tidak menyilang.',
            ),
            (
              ikon: Icons.back_hand_outlined,
              teks:
                  'Letakkan lengan di meja setinggi dada, telapak menghadap ke '
                  'atas, dan jangan digerakkan.',
            ),
            (
              ikon: Icons.record_voice_over_outlined,
              teks:
                  'Jangan bicara selama pengukuran. Bicara menaikkan tekanan '
                  'darah beberapa mmHg.',
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (controller.sesiAktif != null) ...[
          const _KartuInfo(
            ikon: Icons.restaurant_rounded,
            teks:
                'Sesi makan Anda sedang berjalan. Pindai ini berdiri sendiri: '
                'hasilnya tidak masuk ke sesi tersebut, dan jadwal pengukuran '
                'sesi tidak berubah.',
          ),
          const SizedBox(height: 20),
        ],

        // Sama seperti di kalibrasi, kalimat ini tidak boleh disembunyikan di
        // balik tautan: alat ini mengeluarkan angka yang tampak seperti angka
        // alat medis, dan orang menyesuaikan obat berdasarkan angka semacam itu.
        const _KartuPeringatan(
          teks:
              'Hasil jam adalah perkiraan untuk memantau tren, bukan alat '
              'diagnosis. Jangan memakainya untuk mengubah dosis obat. Bila '
              'Anda merasa tidak enak badan, periksakan diri — jangan menunggu '
              'angka di sini berubah.',
        ),
        const SizedBox(height: 20),

        _TombolUtama(
          label: 'Mulai Pindai',
          ikon: Icons.play_arrow_rounded,
          onPressed: siap ? _mulaiPindai : null,
        ),
        if (!siap) ...[
          const SizedBox(height: 8),
          Center(
            child: Text(
              controller.sedangMemindai
                  ? 'Pengukuran sebelumnya masih berjalan.'
                  // Sebabnya diambil dari controller, bukan ditulis ulang di
                  // sini: baterai kritis dan jam terputus menuntut hal yang
                  // berbeda, dan dua salinan kalimat akan berbeda pada saat
                  // yang paling tidak tepat.
                  : (halangan ??
                        'Jam perlu tersambung dulu sebelum bisa memindai.'),
              style: const TextStyle(fontSize: 11, color: Color(0xFF9CB1AC)),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // Tahap 2 — menunggu jawaban jam.
  Widget _mengukur() {
    final detik = _detikBerjalan;
    final kemajuan = context.watch<SesiMakanController>().kemajuanUkur;

    // **Kalimatnya berasal dari kabar jam, bukan dari detik yang berjalan.**
    // Sebelumnya seluruh copy di sini disetir `detik`: layar menuliskan "Sedang
    // mengukur" pada detik ke-8 apa pun yang terjadi di pergelangan — termasuk
    // ketika jamnya sudah mati, sudah keluar jangkauan, atau tidak pernah
    // mulai. Yang membuat kalimat itu benar sekarang adalah paket Status yang
    // betul-betul tiba tiap dua detik (docs/protokol-jam.md §5.5 v1.4); tanpa
    // kabar itu, layar tidak berhak berkata jam sedang bekerja.
    //
    // Tiga keadaan, tiga kalimat, karena tindak lanjutnya tiga-tiganya berbeda:
    // belum ada kabar (tunggu), macet (rapatkan jam), berjalan (diam saja).
    final (String judul, String penjelasan) = switch (kemajuan) {
      null => (
        'Menunggu jam',
        'Perintah sudah dikirim. Layar ini akan berubah begitu jam melaporkan '
            'bahwa ia mulai membaca.',
      ),
      final k when k.macet => (
        'Nadi belum ketemu',
        'Jam masih bekerja, tetapi belum menemukan gelombang nadi. Rapatkan '
            'jam di pergelangan dan diamkan tangan.',
      ),
      final k when (k.sisaDetik ?? 99) <= 5 => (
        'Hampir selesai',
        'Tahan posisi sebentar lagi sampai jam mengirim hasilnya.',
      ),
      _ => (
        'Jam sedang mengukur',
        'Jangan bicara dan jangan menggerakkan tangan. Satu gerakan kecil '
            'membuat jam mengulang pembacaannya dari awal.',
      ),
    };

    // Perkiraan sisa **dari jam**, bukan hitung mundur buatan layar: yang
    // mengakhiri pengukuran adalah kecukupan data, jadi angka ini boleh
    // memanjang — dan justru itulah yang membuatnya jujur.
    final sisa = kemajuan?.sisaDetik;
    final keterangan = sisa == null
        ? null
        : sisa >= 255
        ? 'Perkiraan sisa: lebih dari 4 menit'
        : 'Perkiraan sisa: ±$sisa detik menurut jam';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 24),
        Center(
          child: _CincinDenyut(
            denyut: _denyut,
            detik: detik,
            persen: kemajuan?.persen,
          ),
        ),
        const SizedBox(height: 28),
        Text(
          judul,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            penjelasan,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B807B),
              height: 1.5,
            ),
          ),
        ),
        if (keterangan != null) ...[
          const SizedBox(height: 8),
          Text(
            keterangan,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CB1AC)),
          ),
        ],
        const SizedBox(height: 28),

        const _KartuInfo(
          ikon: Icons.watch_rounded,
          teks:
              'Biarkan ponsel tetap dekat dengan jam sampai pengukuran selesai.',
        ),
        const SizedBox(height: 24),

        Center(
          child: TextButton(
            onPressed: _hentikanMenunggu,
            child: const Text(
              'Berhenti Menunggu',
              style: TextStyle(fontSize: 12, color: Color(0xFF8FA7A1)),
            ),
          ),
        ),
        const SizedBox(height: 6),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              // Dikatakan apa adanya: tombolnya menutup layar ini, bukan
              // menghentikan jam. Tidak ada perintah "batalkan pengukuran" di
              // protokol, dan tombol yang mengaku punya akan berbohong.
              'Jam tetap menyelesaikan pengukurannya. Yang berhenti hanyalah '
              'penantian di layar ini.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 10, color: Color(0xFF9CB1AC)),
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // Tahap 3 — hasil.
  Widget _hasil() {
    final controller = context.watch<SesiMakanController>();
    final hasil = controller.pindaiTerakhir;

    // Hasilnya bisa dibuang dari tempat lain (mis. controller di-reset); jangan
    // menampilkan layar hasil yang isinya tidak ada.
    if (hasil == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 40),
          const Center(
            child: Text(
              'Belum ada hasil pindai.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B807B)),
            ),
          ),
          const SizedBox(height: 20),
          _TombolUtama(
            label: 'Kembali',
            onPressed: () => setState(() => _tahap = _Tahap.persiapan),
          ),
        ],
      );
    }

    final s = hasil.sampel;
    final kemampuan = controller.statusPerangkat.metrikTampil;
    final adaKalibrasi = controller.kalibrasiTerakhir != null;
    final kalibrasiKedaluwarsa = controller.kalibrasiKedaluwarsa;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: hasil.kosong
                    ? const Color(0xFFFFF4E5)
                    : const Color(0xFFE2F6F0),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                hasil.kosong
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_rounded,
                size: 22,
                color: hasil.kosong
                    ? const Color(0xFFB4761E)
                    : const Color(0xFF0EAD69),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasil.kosong ? 'Tidak ada yang terbaca' : 'Pindai selesai',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A34),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    // Jam pengukuran ikut ditulis, bukan hanya "baru saja":
                    // halaman ini bisa dibuka lagi berjam-jam kemudian dan
                    // angkanya akan terlihat persis sama segarnya.
                    '${formatJam(hasil.waktu)} · '
                    '${formatWaktuRelatif(hasil.waktu)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF7E9A94),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (hasil.kosong) ...[
          const _KartuPeringatan(
            teks:
                'Jam tidak berhasil membaca satu pun metrik. Hampir selalu '
                'penyebabnya sama: jam terlalu longgar atau tangan bergerak. '
                'Rapatkan tali jam, diamkan tangan di meja, lalu pindai lagi.',
          ),
          const SizedBox(height: 20),
        ] else if (hasil.sebagianGagal) ...[
          const _KartuInfo(
            ikon: Icons.info_outline_rounded,
            teks:
                'Sebagian metrik tidak terbaca. Angka yang ada tetap sah — yang '
                'kosong memang tidak diukur, bukan bernilai nol.',
          ),
          const SizedBox(height: 20),
        ],

        // `IntrinsicHeight` supaya dua kotak yang bersebelahan sama tinggi
        // meski isinya berbeda panjang — "Tidak terbaca" satu baris di sebelah
        // angka besar akan menghasilkan dua kotak yang tidak sejajar, dan itu
        // terbaca sebagai satu kotak yang rusak.
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _KartuMetrik(
                  ikon: ikonGulaDarah,
                  nama: 'Gula Darah',
                  nilai: s.gulaDarah?.toString(),
                  satuan: 'mg/dL',
                  didukung: kemampuan.gulaDarah,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                // Detak jantung tidak punya bit kemampuan di §3 protokol.
                child: _KartuMetrik(
                  ikon: ikonDetakJantung,
                  nama: 'Detak Jantung',
                  nilai: s.detakJantung?.toString(),
                  satuan: 'bpm',
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _KartuMetrik(
                  ikon: ikonTekananDarah,
                  nama: 'Tekanan Darah',
                  nilai: s.tekananDarah,
                  satuan: 'mmHg',
                  didukung: kemampuan.tekananDarah,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _KartuMetrik(
                  ikon: Icons.air_rounded,
                  nama: 'Oksigen (SpO₂)',
                  nilai: s.spo2?.toString(),
                  satuan: '%',
                  didukung: kemampuan.spo2,
                ),
              ),
            ],
          ),
        ),

        // Angka tekanan darah tanpa keterangan kalibrasinya menyesatkan: jam
        // tetap mengeluarkannya dengan koreksi apa pun yang terakhir tersimpan
        // di flash-nya, termasuk koreksi yang sudah kedaluwarsa (§5.1).
        if (s.tekananDarah != null) ...[
          const SizedBox(height: 12),
          _CatatanKalibrasi(
            adaKalibrasi: adaKalibrasi,
            kedaluwarsa: kalibrasiKedaluwarsa,
            sisaHari: controller.sisaHariKalibrasi,
          ),
        ],
        const SizedBox(height: 20),

        const _KartuInfo(
          ikon: Icons.history_toggle_off_rounded,
          teks:
              'Hasil pindai tidak disimpan ke Riwayat — Riwayat berisi sesi '
              'makan. Angka ini bertahan di layar selama aplikasi terbuka.',
        ),
        const SizedBox(height: 20),

        _TombolUtama(
          label: 'Pindai Lagi',
          ikon: Icons.refresh_rounded,
          onPressed:
              controller.statusPerangkat.tersambung &&
                  !controller.sedangMemindai
              ? _mulaiPindai
              : null,
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Selesai',
              style: TextStyle(fontSize: 12, color: Color(0xFF8FA7A1)),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// --- Bagian-bagian ---------------------------------------------------------

/// Cincin berdenyut selama pengukuran, dengan detik berjalan di tengahnya.
///
/// Sengaja **tidak** berupa progress bar: aplikasi tidak tahu berapa lama jam
/// akan mengukur, dan bar yang merangkak ke 90% lalu berhenti di sana adalah
/// kebohongan yang persis paling terasa. Yang dijanjikan cincin ini hanya satu
/// hal yang memang benar — sesuatu sedang berjalan.
class _CincinDenyut extends StatelessWidget {
  const _CincinDenyut({required this.denyut, required this.detik, this.persen});

  final Animation<double> denyut;
  final int detik;

  /// Kemajuan yang dilaporkan jam, 0..100. null berarti jam belum (atau tidak
  /// pernah) mengabarkannya — firmware ≤ v1.3 tidak mengirimkannya sama sekali,
  /// jadi detik yang berjalan tetap ditampilkan sebagai gantinya, bukan angka
  /// yang dikarang layar ini.
  final int? persen;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 180,
      child: AnimatedBuilder(
        animation: denyut,
        builder: (context, child) {
          // Dua gelombang yang saling menyusul, supaya ada yang terlihat
          // bergerak di setiap saat, bukan berkedip.
          final fase = denyut.value;
          return Stack(
            alignment: Alignment.center,
            children: [
              for (final geser in const [0.0, 0.5])
                _gelombang((fase + geser) % 1.0),
              child!,
            ],
          );
        },
        child: Container(
          width: 108,
          height: 108,
          decoration: const BoxDecoration(
            color: Color(0xFF0EAD69),
            shape: BoxShape.circle,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.monitor_heart_rounded,
                color: Colors.white,
                size: 26,
              ),
              const SizedBox(height: 2),
              Text(
                persen != null ? '$persen%' : '$detik dtk',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _gelombang(double t) {
    final ukuran = 108.0 + 72.0 * t;
    return Opacity(
      opacity: (1 - t) * 0.35,
      child: Container(
        width: ukuran,
        height: ukuran,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: const Color(0xFF0EAD69), width: 2),
        ),
      ),
    );
  }
}

/// Satu metrik hasil pindai.
///
/// [nilai] null berarti **tidak terbaca**, dan itu ditulis dengan kata, bukan
/// dengan `—` di tempat angka: tanda hubung di kotak yang bentuknya sama persis
/// dengan kotak berisi angka terbaca sebagai nol atau sebagai kesalahan
/// aplikasi.
class _KartuMetrik extends StatelessWidget {
  const _KartuMetrik({
    required this.ikon,
    required this.nama,
    required this.nilai,
    required this.satuan,
    this.didukung = true,
  });

  final IconData ikon;
  final String nama;
  final String? nilai;
  final String satuan;

  /// Jam ini punya sensornya. False berarti kotaknya **hilang sama sekali**
  /// (§3 protokol), bukan berisi "Tidak terbaca" — kalimat itu menyuruh orang
  /// merapatkan tali jam untuk sensor yang tidak pernah dipasang.
  ///
  /// Angka yang sudah ada tetap ditampilkan meski false: menyembunyikan
  /// pengukuran sungguhan tidak pernah benar.
  final bool didukung;

  @override
  Widget build(BuildContext context) {
    final terbaca = nilai != null;
    if (!didukung && !terbaca) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: terbaca ? const Color(0xFFE2EBE8) : const Color(0xFFEFE3D2),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ikon,
                size: 16,
                color: terbaca
                    ? const Color(0xFF0EAD69)
                    : const Color(0xFF9CB1AC),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  nama,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B807B),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (terbaca)
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    nilai!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A34),
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  satuan,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8FA7A1),
                  ),
                ),
              ],
            )
          else
            const Text(
              'Tidak terbaca',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Color(0xFFB4761E),
              ),
            ),
        ],
      ),
    );
  }
}

/// Keterangan kalibrasi di bawah angka tekanan darah.
///
/// Ketiga keadaannya berbeda tindak lanjutnya, jadi ketiganya punya kalimat
/// sendiri — dan yang kedaluwarsa **tidak** diam-diam disamakan dengan yang
/// belum pernah ada: jam tetap memakai koreksi lamanya (§5.1), jadi angkanya
/// tetap keluar, hanya tidak lagi bisa dipertanggungjawabkan.
class _CatatanKalibrasi extends StatelessWidget {
  const _CatatanKalibrasi({
    required this.adaKalibrasi,
    required this.kedaluwarsa,
    required this.sisaHari,
  });

  final bool adaKalibrasi;
  final bool kedaluwarsa;
  final int? sisaHari;

  @override
  Widget build(BuildContext context) {
    if (adaKalibrasi && !kedaluwarsa) {
      final sisa = sisaHari;
      return _BarisCatatan(
        ikon: Icons.verified_outlined,
        warna: const Color(0xFF0EAD69),
        teks: sisa == null
            ? 'Tekanan darah sudah dikoreksi dengan kalibrasi tensimeter.'
            : 'Tekanan darah sudah dikoreksi dengan kalibrasi tensimeter; '
                  'berlaku $sisa hari lagi.',
      );
    }

    return _BarisCatatan(
      ikon: Icons.tune_rounded,
      warna: const Color(0xFFB4761E),
      teks: adaKalibrasi
          ? 'Kalibrasi tekanan darah sudah lewat masa berlakunya. Jam masih '
                'memakai koreksi lama, jadi angka di atas bisa meleset — '
                'kalibrasi ulang lewat Profil.'
          : 'Jam belum pernah dikalibrasi dengan tensimeter, jadi angka '
                'tekanan darah di atas belum dikoreksi. Kalibrasi bisa '
                'dilakukan lewat Profil.',
    );
  }
}

class _BarisCatatan extends StatelessWidget {
  const _BarisCatatan({
    required this.ikon,
    required this.warna,
    required this.teks,
  });

  final IconData ikon;
  final Color warna;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(ikon, size: 14, color: warna),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            teks,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B807B),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// Jam belum siap dipakai memindai — tiga keadaan, tiga jalan keluar.
class _KartuJamBelumSiap extends StatelessWidget {
  const _KartuJamBelumSiap({required this.perangkat, this.izin});

  final StatusPerangkat perangkat;
  final IzinBle? izin;

  @override
  Widget build(BuildContext context) {
    // Belum pernah dipasangkan dan sekadar putus adalah dua hal yang berbeda:
    // yang satu menuntut pemindaian perangkat, yang lain hanya menunggu — dan
    // menawarkan pemindaian pada yang kedua mengirim pengguna memasang ulang jam
    // yang sebenarnya tidak apa-apa.
    final (
      IconData ikon,
      String judul,
      String pesan,
      String? aksi,
    ) = perangkat.belumDipasangkan
        ? (
            Icons.watch_off_rounded,
            'Belum ada jam',
            'Pindai kesehatan dilakukan oleh jam AsaWatch, jadi jamnya perlu '
                'dipasangkan lebih dulu.',
            'Pasangkan Jam',
          )
        : perangkat.penyandinganHilang
        ? (
            Icons.link_off_rounded,
            'Jam tidak tersandingkan',
            'Penyandingan jam terhapus dari ponsel, jadi jam tidak bisa '
                'diperintah. Sandingkan sekali lagi.',
            'Sandingkan Ulang',
          )
        : (
            Icons.bluetooth_disabled_rounded,
            'Jam belum tersambung',
            '${perangkat.namaPerangkat ?? 'Jam'} sedang di luar jangkauan. '
                'Dekatkan jam ke ponsel — sambungannya kembali sendiri, tanpa '
                'perlu memasang ulang.',
            null,
          );

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0D9B5), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(ikon, size: 18, color: const Color(0xFFB4761E)),
              const SizedBox(width: 8),
              Text(
                judul,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF6B4E1E),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            pesan,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B4E1E),
              height: 1.5,
            ),
          ),
          if (aksi != null) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MenghubungkanPerangkatPage(izin: izin),
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFB4761E),
                  side: const BorderSide(color: Color(0xFFF0D9B5), width: 1.5),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  aksi,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Ringkasan hasil terakhir di layar persiapan, sebagai pintu kembali ke
/// angkanya tanpa harus memindai ulang.
class _KartuHasilTerakhir extends StatelessWidget {
  const _KartuHasilTerakhir({required this.hasil, required this.onLihat});

  final HasilPindai hasil;
  final VoidCallback onLihat;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onLihat,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Hasil pindai terakhir',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A34),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatWaktuRelatif(hasil.waktu),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF8FA7A1),
                      ),
                    ),
                  ],
                ),
              ),
              const Text(
                'Lihat',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0EAD69),
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: Color(0xFF0EAD69),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _JudulLangkah extends StatelessWidget {
  const _JudulLangkah({required this.nomor, required this.judul});

  final int nomor;
  final String judul;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            color: Color(0xFFE2F6F0),
            shape: BoxShape.circle,
          ),
          child: Text(
            '$nomor',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Color(0xFF0EAD69),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          judul,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
      ],
    );
  }
}

class _KartuDaftarPeriksa extends StatelessWidget {
  const _KartuDaftarPeriksa({required this.butir});

  final List<({IconData ikon, String teks})> butir;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
      ),
      child: Column(
        children: [
          for (final b in butir)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(b.ikon, size: 18, color: const Color(0xFF0EAD69)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      b.teks,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6B807B),
                        height: 1.45,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _KartuInfo extends StatelessWidget {
  const _KartuInfo({required this.ikon, required this.teks});

  final IconData ikon;
  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8F5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2F6F0), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(ikon, size: 18, color: const Color(0xFF0EAD69)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF3F5C55),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuPeringatan extends StatelessWidget {
  const _KartuPeringatan({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0D9B5), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: Color(0xFFB4761E),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF6B4E1E),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuGalat extends StatelessWidget {
  const _KartuGalat({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDECEC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF5C9C9), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: Color(0xFFC0392B),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              pesan,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF8C2F22),
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TombolUtama extends StatelessWidget {
  const _TombolUtama({required this.label, this.onPressed, this.ikon});

  final String label;
  final VoidCallback? onPressed;
  final IconData? ikon;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
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
            if (ikon != null) ...[
              Icon(ikon, size: 20),
              const SizedBox(width: 8),
            ],
            Text(
              label,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
