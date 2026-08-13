import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'models/sesi_makan.dart';
import 'konfigurasi.dart';
import 'services/izin_ble.dart';

/// Alur pemasangan jam: izin → pindai → pilih → sambungkan.
///
/// Hasil pemindaian masuk satu per satu, perangkat yang tidak didukung tetap
/// ditampilkan tetapi tidak bisa dipilih, dan kegagalan menyambung tidak
/// menutup halaman — user harus bisa mencoba lagi.
///
/// Izin diminta **di sini**, saat pemindaian benar-benar akan dimulai, bukan
/// saat aplikasi dibuka (rencana-produksi.md §4.4). Penolakan permanen tidak
/// berujung pada layar pemindaian yang berputar selamanya: ia mengatakan
/// masalahnya dan menawarkan Pengaturan sistem.
class PemindaianPerangkatPage extends StatefulWidget {
  const PemindaianPerangkatPage({super.key, this.izin});

  /// null berarti [izinBleBawaan] — yang sendirinya sudah membedakan jalur jam
  /// sungguhan dari jam palsu. Test menyuntikkan [IzinBleSelaluBoleh] supaya
  /// tidak ada saluran platform yang perlu ada.
  final IzinBle? izin;

  @override
  State<PemindaianPerangkatPage> createState() =>
      _PemindaianPerangkatPageState();
}

class _PemindaianPerangkatPageState extends State<PemindaianPerangkatPage> {
  StreamSubscription<PerangkatDitemukan>? _langganan;
  final List<PerangkatDitemukan> _ditemukan = [];

  bool _memindai = false;
  String? _idMenyambung; // perangkat yang sedang disambungkan
  String? _pesanGagal;

  /// Hasil permintaan izin terakhir; null berarti belum pernah diminta.
  HasilIzinBle? _izin;

  IzinBle get _izinDipakai => widget.izin ?? izinBleBawaan;

  @override
  void initState() {
    super.initState();
    // Halaman ini dibuka justru untuk memindai, jadi langsung mulai.
    WidgetsBinding.instance.addPostFrameCallback((_) => _mulaiPindai());
  }

  @override
  void dispose() {
    _langganan?.cancel();
    super.dispose();
  }

  Future<void> _mulaiPindai() async {
    if (_memindai) return;
    final controller = context.read<SesiMakanController>();

    // Tanpa izin, `startScan` di Android bukan gagal dengan pesan — ia hanya
    // tidak pernah menemukan apa pun, yang di layar terlihat persis seperti jam
    // yang mati.
    final izin = await _izinDipakai.minta();
    if (!mounted) return;
    setState(() => _izin = izin);
    if (izin != HasilIzinBle.diberikan) return;

    setState(() {
      _memindai = true;
      _pesanGagal = null;
      _ditemukan.clear();
    });

    _langganan?.cancel();
    _langganan = controller.pindaiPerangkat().listen(
      (perangkat) {
        if (!mounted) return;
        setState(() => _ditemukan.add(perangkat));
      },
      // Stream ditutup jam sendiri saat pemindaiannya habis (§12.5), jadi
      // halaman ini tidak perlu timer sendiri untuk berhenti.
      onDone: () {
        if (!mounted) return;
        setState(() => _memindai = false);
      },
    );
  }

  Future<void> _sambungkan(PerangkatDitemukan perangkat) async {
    final controller = context.read<SesiMakanController>();
    final navigator = Navigator.of(context);

    // Menyambung sambil memindai membuat statusnya kabur; hentikan dulu.
    // Tidak ditunggu: pembatalannya sudah menghentikan jadwal di jam palsu,
    // dan menunggunya hanya menunda tampilnya indikator "menyambungkan".
    unawaited(_langganan?.cancel() ?? Future<void>.value());
    setState(() {
      _memindai = false;
      _idMenyambung = perangkat.id;
      _pesanGagal = null;
    });

    final berhasil = await controller.sambungkanPerangkat(perangkat.id);
    if (!mounted) return;

    if (berhasil) {
      navigator.pop(perangkat.nama);
      return;
    }
    setState(() {
      _idMenyambung = null;
      _pesanGagal =
          '${perangkat.nama} tidak dapat disambungkan. Dekatkan jam, '
          'lalu coba lagi.';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A34)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Pindai Perangkat',
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
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _kepala(),
              const SizedBox(height: 20),

              if (_izin case final izin? when izin != HasilIzinBle.diberikan)
                _kartuIzin(izin)
              else ...[
                if (_pesanGagal != null) ...[
                  _kartuGagal(_pesanGagal!),
                  const SizedBox(height: 16),
                ],

                if (_ditemukan.isEmpty && !_memindai)
                  _kartuKosong()
                else
                  ..._ditemukan.map(_kartuPerangkat),

                if (_ditemukan.isEmpty && _memindai) _kartuMencari(),

                // Ditampilkan tepat saat dialog penyandingan sistem muncul,
                // bukan sebagai catatan kaki permanen yang tidak akan dibaca
                // siapa pun ketika ia akhirnya relevan.
                if (_idMenyambung != null) ...[
                  const SizedBox(height: 16),
                  _kartuPenyandingan(),
                ],
              ],

              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _memindai || _idMenyambung != null
                      ? null
                      : _mulaiPindai,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(
                    _memindai ? 'Memindai…' : 'Pindai Ulang',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0EAD69),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: Color(0xFFD0EBE0), width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Hanya jam AsaWatch yang dicari, jadi perangkat Bluetooth lain '
                'tidak akan muncul di daftar ini. Jam yang sedang tersambung ke '
                'ponsel lain juga tidak akan terlihat.',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFF9CB1AC),
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _kepala() {
    return Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: _memindai
              ? const CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Color(0xFF0EAD69),
                )
              : const Icon(
                  Icons.bluetooth_searching_rounded,
                  color: Color(0xFF0EAD69),
                  size: 22,
                ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            _memindai
                ? 'Mencari perangkat di sekitar…'
                : '${_ditemukan.length} perangkat ditemukan',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A34),
            ),
          ),
        ),
      ],
    );
  }

  Widget _kartuPerangkat(PerangkatDitemukan perangkat) {
    final menyambung = _idMenyambung == perangkat.id;
    final adaYangMenyambung = _idMenyambung != null;
    final aktif = perangkat.didukung && !adaYangMenyambung;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: aktif ? () => _sambungkan(perangkat) : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: perangkat.didukung
                        ? const Color(0xFFE2F6F0)
                        : const Color(0xFFE2EBE8),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    perangkat.didukung
                        ? Icons.watch_rounded
                        : Icons.bluetooth_rounded,
                    size: 20,
                    color: perangkat.didukung
                        ? const Color(0xFF0EAD69)
                        : const Color(0xFF8FA7A1),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        perangkat.nama,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: perangkat.didukung
                              ? const Color(0xFF1E3A34)
                              : const Color(0xFF8FA7A1),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        perangkat.didukung
                            ? perangkat.id
                            : 'Tidak didukung aplikasi ini',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF9CB1AC),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (menyambung)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFF0EAD69),
                    ),
                  )
                else ...[
                  _BatangSinyal(
                    batang: perangkat.batangSinyal,
                    aktif: perangkat.didukung,
                  ),
                  if (perangkat.didukung) ...[
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Color(0xFF8FA7A1),
                      size: 20,
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _kartuMencari() {
    return _kotakPesan(
      ikon: Icons.bluetooth_searching_rounded,
      judul: 'Memindai…',
      isi: 'Perangkat akan muncul di sini begitu terlihat.',
    );
  }

  /// Kosong di sini berarti sesuatu yang lebih sempit daripada "tidak ada apa-apa
  /// di sekitar": pemindaian disaring di level OS sehingga **hanya AsaWatch yang
  /// bisa muncul sama sekali**. Perangkat Bluetooth lain tidak akan pernah
  /// terlihat, betapapun banyaknya.
  ///
  /// Itu harus dikatakan. Sebelum penyaringan ini ada, daftar yang berisi
  /// headset dan TV tetangga adalah bukti murah bahwa radionya bekerja; sekarang
  /// bukti itu hilang, dan layar kosong yang tidak menjelaskan diri akan terbaca
  /// sebagai aplikasi yang rusak.
  Widget _kartuKosong() {
    return _kotakPesan(
      ikon: Icons.watch_off_rounded,
      judul: 'Jam AsaWatch tidak ditemukan',
      isi:
          'Pemindaian ini hanya mencari jam AsaWatch, jadi perangkat Bluetooth '
          'lain memang tidak akan muncul di sini. Pastikan jam menyala, berada '
          'dalam jangkauan, dan tidak sedang tersambung ke ponsel lain, lalu '
          'pindai ulang.',
    );
  }

  Widget _kotakPesan({
    required IconData ikon,
    required String judul,
    required String isi,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
      ),
      child: Column(
        children: [
          Icon(ikon, size: 30, color: const Color(0xFF8FA7A1)),
          const SizedBox(height: 10),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A34),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            isi,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF7E9A94),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  /// Izin belum ada — dan justru karena itu daftar perangkat tidak ditampilkan
  /// sama sekali. Pemindaian tanpa izin di Android tidak melempar apa pun; ia
  /// hanya diam, dan layar yang diam terbaca sebagai "tidak ada jam di sini".
  Widget _kartuIzin(HasilIzinBle izin) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
      ),
      child: Column(
        children: [
          Icon(
            izin == HasilIzinBle.bluetoothMati
                ? Icons.bluetooth_disabled_rounded
                : Icons.lock_outline_rounded,
            size: 30,
            color: const Color(0xFF8FA7A1),
          ),
          const SizedBox(height: 10),
          Text(
            izin.pesan ?? '',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF6B807B),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 14),
          if (izin.butuhPengaturan)
            ElevatedButton(
              onPressed: () => _izinDipakai.bukaPengaturan(),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EAD69),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Buka Pengaturan',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            )
          else
            OutlinedButton(
              onPressed: _mulaiPindai,
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF0EAD69),
                side: const BorderSide(color: Color(0xFFD0EBE0), width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Coba Lagi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
            ),
        ],
      ),
    );
  }

  /// Penjelasan untuk dialog penyandingan Bluetooth milik sistem.
  ///
  /// Dialog itu datang dari Android, bukan dari aplikasi ini, dan muncul begitu
  /// karakteristik terenkripsi pertama disentuh (protokol §8: enkripsi wajib di
  /// semua karakteristik kustom). Tanpa kalimat ini, pengguna melihat permintaan
  /// izin yang tidak pernah ia minta, di tengah alur yang baru saja ia mulai —
  /// dan menolaknya menghentikan pemasangan tanpa pesan apa pun.
  ///
  /// Pairing memakai **Just Works**, jadi yang muncul biasanya hanya konfirmasi,
  /// bukan permintaan PIN. Kalimatnya sengaja tidak menyebut PIN sama sekali:
  /// menyebut angka yang tidak akan ditanyakan justru membuat pengguna mencarinya.
  Widget _kartuPenyandingan() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F8F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Icon(Icons.lock_outline_rounded, size: 18, color: Color(0xFF0EAD69)),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Ponsel mungkin meminta konfirmasi penyandingan Bluetooth. '
              'Pilih Sambungkan — data kesehatan dari jam hanya dikirim lewat '
              'sambungan yang tersandi.',
              style: TextStyle(
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

  Widget _kartuGagal(String pesan) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEEEE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFF3D2D2), width: 1),
      ),
      child: Row(
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
                fontSize: 11,
                color: Color(0xFF8E3B31),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Empat batang sinyal ala BLE, digambar dari `batangSinyal` (1..4).
class _BatangSinyal extends StatelessWidget {
  const _BatangSinyal({required this.batang, required this.aktif});

  final int batang;
  final bool aktif;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(4, (i) {
        final nyala = i < batang;
        return Container(
          width: 3,
          height: 5.0 + i * 3,
          margin: const EdgeInsets.only(left: 2),
          decoration: BoxDecoration(
            color: nyala && aktif
                ? const Color(0xFF0EAD69)
                : const Color(0xFFD5E2DE),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}
