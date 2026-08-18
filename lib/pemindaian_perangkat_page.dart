import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'models/sesi_makan.dart';
import 'konfigurasi.dart';
import 'services/ble_service.dart';
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

  /// Perangkat yang sedang disambungkan; null berarti tidak sedang menyambung.
  ///
  /// Selama ia terisi, seluruh halaman berganti menjadi layar penyambungan —
  /// bukan spinner kecil di baris daftar. Salah satu tahapnya menunggu tindakan
  /// pengguna, dan momen itu harus mustahil terlewat
  /// (docs/alur-pemasangan-jam.md §4.3).
  PerangkatDitemukan? _menyambungKe;
  TahapSambung _tahap = TahapSambung.menyambung;
  StreamSubscription<TahapSambung>? _langgananTahap;

  /// Permintaan penyandingan yang muncul sebagai notifikasi, bukan dialog,
  /// tidak akan pernah dilihat pengguna yang menunggu di layar ini (§4.4).
  Timer? _timerPetunjuk;
  bool _petunjukNotifikasi = false;

  /// Percobaan yang gagal, lengkap dengan perangkatnya — namanya ikut dipakai
  /// di dalam pesan, dan tombol "Coba Lagi" harus tahu apa yang harus diulang.
  ({HasilSambung hasil, PerangkatDitemukan perangkat})? _gagal;

  /// Hasil permintaan izin terakhir; null berarti belum pernah diminta.
  HasilIzinBle? _izin;

  /// Sedang menunggu jawaban dialog "nyalakan Bluetooth" dari sistem.
  ///
  /// Mengunci tombolnya: dialognya milik sistem dan hanya ada satu, jadi
  /// ketukan kedua tidak memunculkan apa pun dan hanya terasa seperti aplikasi
  /// yang mengabaikan pengguna.
  bool _menyalakanBluetooth = false;

  IzinBle get _izinDipakai => widget.izin ?? izinBleBawaan;

  /// Berapa lama menunggu sebelum memberi tahu di mana permintaan penyandingan
  /// bersembunyi.
  ///
  /// Dipilih supaya pengguna yang menjawab dengan normal **tidak pernah**
  /// melihatnya: petunjuk tambahan yang muncul saat semuanya berjalan baik
  /// justru menimbulkan ragu.
  static const Duration jedaPetunjukNotifikasi = Duration(seconds: 8);

  @override
  void initState() {
    super.initState();
    // Halaman ini dibuka justru untuk memindai, jadi langsung mulai.
    WidgetsBinding.instance.addPostFrameCallback((_) => _mulaiPindai());
  }

  @override
  void dispose() {
    _langganan?.cancel();
    _langgananTahap?.cancel();
    _timerPetunjuk?.cancel();
    super.dispose();
  }

  /// Menyalakan Bluetooth dari dalam aplikasi, lalu langsung memindai lagi.
  ///
  /// Ini bukan menyalakan diam-diam — sejak Android 13 tidak ada aplikasi yang
  /// bisa — melainkan memunculkan dialog sistem di sini, supaya pengguna tidak
  /// perlu keluar ke Pengaturan dan mencari jalan kembali. Untuk pengguna yang
  /// dituju halaman ini (docs/alur-pemasangan-jam.md: lansia), perjalanan itu
  /// justru bagian yang paling sering berakhir di tempat lain.
  Future<void> _nyalakanBluetooth() async {
    if (_menyalakanBluetooth) return;
    setState(() => _menyalakanBluetooth = true);

    final hasil = await _izinDipakai.nyalakanBluetooth();

    // Dialognya bisa berumur lebih panjang daripada halamannya.
    if (!mounted) return;
    setState(() => _menyalakanBluetooth = false);

    if (hasil == HasilNyalakanBluetooth.menyala) {
      // `nyalakanBluetooth()` baru selesai setelah radionya benar-benar hidup,
      // jadi pemindaian ulang di sini tidak akan menabrak adapter yang masih
      // menyala. Kartu izinnya hilang sendiri lewat `_mulaiPindai`.
      await _mulaiPindai();
      return;
    }

    // Kartu izinnya tetap di layar dan sudah menjelaskan keadaannya; yang
    // ditambahkan di sini hanya apa yang barusan terjadi.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(hasil.pesan ?? '')));
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
      _gagal = null;
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
    // dan menunggunya hanya menunda tampilnya layar penyambungan.
    unawaited(_langganan?.cancel() ?? Future<void>.value());

    // Dilanggan **sebelum** `sambungkan` dipanggil: tahap pertama dikirim di
    // baris pertama penyambungan, dan langganan yang terlambat sepersekian
    // detik akan melewatkannya.
    _langgananTahap?.cancel();
    _langgananTahap = controller.tahapSambung.listen(_terimaTahap);

    setState(() {
      _memindai = false;
      _menyambungKe = perangkat;
      _tahap = TahapSambung.menyambung;
      _petunjukNotifikasi = false;
      _gagal = null;
    });

    final hasil = await controller.sambungkanPerangkat(perangkat.id);
    if (!mounted) return;

    // User menekan "Batal" selagi menunggu; hasil yang datang belakangan tidak
    // boleh menariknya keluar dari halaman yang sudah ia tinggalkan.
    if (_menyambungKe?.id != perangkat.id) return;

    _hentikanPetunjuk();
    unawaited(_langgananTahap?.cancel() ?? Future<void>.value());
    _langgananTahap = null;

    if (hasil.berhasil) {
      navigator.pop(perangkat.nama);
      return;
    }
    setState(() {
      _menyambungKe = null;
      _gagal = (hasil: hasil, perangkat: perangkat);
    });
  }

  void _terimaTahap(TahapSambung tahap) {
    if (!mounted || _menyambungKe == null) return;
    setState(() {
      _tahap = tahap;
      _petunjukNotifikasi = false;
    });

    _timerPetunjuk?.cancel();
    _timerPetunjuk = null;
    if (tahap != TahapSambung.menyandingkan) return;

    _timerPetunjuk = Timer(jedaPetunjukNotifikasi, () {
      if (!mounted || _tahap != TahapSambung.menyandingkan) return;
      setState(() => _petunjukNotifikasi = true);
    });
  }

  void _hentikanPetunjuk() {
    _timerPetunjuk?.cancel();
    _timerPetunjuk = null;
  }

  /// Membatalkan penyambungan yang sedang berjalan.
  ///
  /// Jamnya ikut diputus: koneksi yang tetap hidup setelah user menyerah akan
  /// terus menahan radio, dan pada percobaan berikutnya `connect` bertabrakan
  /// dengan koneksi yang sebenarnya masih ada.
  void _batalkanSambung() {
    final controller = context.read<SesiMakanController>();
    _hentikanPetunjuk();
    unawaited(_langgananTahap?.cancel() ?? Future<void>.value());
    _langgananTahap = null;
    unawaited(controller.putuskanPerangkat());
    setState(() => _menyambungKe = null);
  }

  /// Menghapus penyandingan lama, lalu mencoba menyambung sekali lagi.
  ///
  /// Satu-satunya jalan keluar dari [HasilSambung.bondBasi] yang tidak menuntut
  /// user membuka Pengaturan sistem sendiri. Bila Android menolaknya, pesannya
  /// berganti menjadi petunjuk manual — bukan diam-diam gagal lagi.
  Future<void> _sandingkanUlang(PerangkatDitemukan perangkat) async {
    final controller = context.read<SesiMakanController>();
    final berhasil = await controller.lupakanPenyandingan(perangkat.id);
    if (!mounted) return;

    if (!berhasil) {
      setState(() => _gagal = null);
      _tampilkanPetunjukManual(perangkat);
      return;
    }
    await _sambungkan(perangkat);
  }

  void _tampilkanPetunjukManual(PerangkatDitemukan perangkat) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text(
          'Hapus lewat Pengaturan',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        content: Text(
          'Ponsel ini tidak mengizinkan aplikasi menghapus penyandingan. '
          'Buka Pengaturan ponsel, pilih Bluetooth, cari "${perangkat.nama}" '
          'di daftar perangkat tersimpan, lalu pilih Lupakan. Setelah itu '
          'kembali ke sini dan sambungkan lagi.',
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF6B807B),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Mengerti',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0EAD69),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        // Tombol kembali disembunyikan selagi menyambung: satu-satunya jalan
        // keluar pada saat itu adalah "Batal" yang juga memutus jamnya, dan dua
        // jalan keluar yang berbeda akibatnya adalah persis jenis kebingungan
        // yang alur ini dibuat untuk menghindarinya.
        leading: _menyambungKe != null
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A34)),
                onPressed: () => Navigator.pop(context),
              ),
        automaticallyImplyLeading: false,
        title: Text(
          _menyambungKe != null ? 'Menyambungkan' : 'Pindai Perangkat',
          style: const TextStyle(
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
          child: Padding(
            padding: const EdgeInsets.all(20),
            // Layar penyambungan mengambil alih seluruh halaman, tidak berdampingan
            // dengan daftar. Salah satu tahapnya menunggu tindakan pengguna, dan
            // daftar yang masih terlihat di belakangnya menawarkan hal lain untuk
            // diketuk tepat ketika hanya satu hal yang boleh diketuk (§4.3).
            child: switch (_menyambungKe) {
              final perangkat? => _layarMenyambung(perangkat),
              null => _layarPemindaian(),
            },
          ),
        ),
      ),
    );
  }

  Widget _layarPemindaian() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _kepala(),
        const SizedBox(height: 20),

        if (_izin case final izin? when izin != HasilIzinBle.diberikan)
          _kartuIzin(izin)
        else ...[
          if (_gagal case final gagal?) ...[
            _kartuGagal(gagal.hasil, gagal.perangkat),
            const SizedBox(height: 16),
          ],

          if (_ditemukan.isEmpty && !_memindai)
            _kartuKosong()
          else
            ..._ditemukan.map(_kartuPerangkat),

          if (_ditemukan.isEmpty && _memindai) _kartuMencari(),
        ],

        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _memindai ? null : _mulaiPindai,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              _memindai ? 'Memindai…' : 'Pindai Ulang',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
          style: TextStyle(fontSize: 11, color: Color(0xFF9CB1AC), height: 1.5),
        ),
      ],
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
    // Penyambungan mengambil alih seluruh halaman, jadi daftar ini tidak pernah
    // terlihat selagi ada yang sedang disambungkan — tidak ada keadaan "sibuk"
    // yang perlu digambar di sini.
    final aktif = perangkat.didukung;

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
                      // Baris ini adalah tindakan utama seluruh alur pemasangan,
                      // jadi ukurannya mengikuti §6: nama jam terbaca sekali
                      // lihat, bukan seukuran keterangan.
                      Text(
                        perangkat.nama,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: perangkat.didukung
                              ? const Color(0xFF1E3A34)
                              : const Color(0xFF8FA7A1),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        perangkat.didukung
                            ? 'Ketuk untuk menyambungkan'
                            : 'Tidak didukung aplikasi ini',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF7E9A94),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
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
          // Radio yang mati punya jalan keluarnya sendiri: satu ketukan di
          // sini, bukan perjalanan ke Pengaturan ponsel. Hanya ditawarkan di
          // platform yang benar-benar bisa memenuhinya — di iOS kalimat pada
          // kartu ini sudah menunjuk ke Pengaturan.
          if (izin == HasilIzinBle.bluetoothMati &&
              _izinDipakai.bisaMenyalakanBluetooth)
            ElevatedButton.icon(
              onPressed: _menyalakanBluetooth ? null : _nyalakanBluetooth,
              icon: _menyalakanBluetooth
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Colors.white),
                      ),
                    )
                  : const Icon(Icons.bluetooth_rounded, size: 18),
              label: Text(
                _menyalakanBluetooth ? 'Menunggu…' : 'Nyalakan Bluetooth',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EAD69),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFF9CB1AC),
                disabledForegroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            )
          else if (izin.butuhPengaturan)
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

  /// Layar penyambungan, satu tahap satu tampilan.
  ///
  /// Tiga tahapnya menuntut hal yang berbeda dari pengguna, dan itulah alasan
  /// mereka tidak boleh berbagi satu spinner: dua di antaranya cuma perlu
  /// ditunggu, sedangkan `menyandingkan` **menunggu pengguna**. Kalau ketiganya
  /// terlihat sama, satu-satunya momen yang membutuhkan tindakan menjadi tidak
  /// terlihat — dan pemasangan berhenti tanpa ada yang tahu kenapa.
  ///
  /// Penyandingan memakai **Just Works** (protokol §8), jadi yang muncul hanya
  /// konfirmasi, bukan permintaan PIN. Kalimatnya menyebut itu secara eksplisit:
  /// pengguna yang terbiasa menyandingkan speaker Bluetooth akan mencari-cari
  /// "0000" dan menyangka dirinya salah langkah.
  Widget _layarMenyambung(PerangkatDitemukan perangkat) {
    final menyandingkan = _tahap == TahapSambung.menyandingkan;

    return Column(
      children: [
        const SizedBox(height: 12),
        SizedBox(
          width: 84,
          height: 84,
          child: Stack(
            alignment: Alignment.center,
            children: [
              const SizedBox(
                width: 84,
                height: 84,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: Color(0xFF0EAD69),
                  backgroundColor: Color(0xFFE2F6F0),
                ),
              ),
              Icon(
                menyandingkan ? Icons.touch_app_rounded : Icons.watch_rounded,
                size: 34,
                color: const Color(0xFF0EAD69),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          switch (_tahap) {
            TahapSambung.menyambung => 'Menyambungkan ke ${perangkat.nama}…',
            TahapSambung.menyandingkan =>
              'Ketuk "Sandingkan" pada permintaan yang muncul',
            TahapSambung.menyiapkan => 'Menyiapkan jam…',
          },
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          switch (_tahap) {
            TahapSambung.menyambung => 'Pastikan jam berada di dekat ponsel.',
            TahapSambung.menyandingkan =>
              'Tidak ada kode atau PIN yang perlu dimasukkan. '
                  'Jangan tutup halaman ini.',
            TahapSambung.menyiapkan => 'Sebentar lagi selesai.',
          },
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF6B807B),
            height: 1.5,
          ),
        ),

        // Muncul hanya bila permintaannya sudah lama tidak dijawab — pada
        // sebagian ponsel ia memang tidak berupa dialog, melainkan notifikasi
        // yang tidak akan pernah dilihat pengguna yang menunggu di layar ini.
        if (menyandingkan && _petunjukNotifikasi) ...[
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.swipe_down_rounded,
                  size: 22,
                  color: Color(0xFF0EAD69),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Belum melihat permintaannya? Usap layar dari atas ke '
                    'bawah, lalu ketuk "Permintaan penyandingan Bluetooth".',
                    style: TextStyle(
                      fontSize: 15,
                      color: Color(0xFF1E3A34),
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: OutlinedButton(
            onPressed: _batalkanSambung,
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B807B),
              side: const BorderSide(color: Color(0xFFD0EBE0), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Batal',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  /// Kegagalan menyambung, dengan tindak lanjut yang sesuai sebabnya.
  ///
  /// Tombol utamanya **selalu** "Coba Lagi", termasuk pada dugaan kunci basi:
  /// dugaan itu bisa salah (jam yang menjauh di detik yang keliru terlihat
  /// serupa), dan menaruh "hapus penyandingan" sebagai tindakan utama berarti
  /// merusak pemasangan yang sehat atas dasar tebakan.
  Widget _kartuGagal(HasilSambung hasil, PerangkatDitemukan perangkat) {
    // Versi yang tidak cocok punya penjelasannya sendiri dari jam, dan itu jauh
    // lebih berguna daripada kalimat umum: ia menyebut sisi mana yang harus
    // diperbarui.
    final controller = context.read<SesiMakanController>();
    final pesan = hasil == HasilSambung.versiTidakCocok
        ? (controller.galatSambungTerakhir ?? hasil.pesan(perangkat.nama))
        : hasil.pesan(perangkat.nama);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFDEEEE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3D2D2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 22,
                color: Color(0xFFC0392B),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  pesan,
                  style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFF8E3B31),
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: () => _sambungkan(perangkat),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EAD69),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Coba Lagi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          if (hasil.butuhSandingUlang) ...[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: TextButton(
                onPressed: () => _sandingkanUlang(perangkat),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8E3B31),
                ),
                child: const Text(
                  'Sandingkan ulang jam ini',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
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
