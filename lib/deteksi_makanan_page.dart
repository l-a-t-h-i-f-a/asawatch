import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'konfigurasi.dart';
import 'models/sesi_makan.dart';
import 'services/kamera_service.dart';
import 'utils/format_waktu.dart';
import 'utils/gaya_sistem.dart';
import 'widgets/foto_makanan.dart';
import 'widgets/petunjuk_tombol_jam.dart';
import 'widgets/ringkasan_nutrisi.dart';

/// Kamera deteksi makanan — pemicu seluruh siklus sesi (§2 poin 4).
///
/// **Kameranya sungguhan**: pratinjaunya `CameraPreview`, rananya memotret, dan
/// hasilnya disalin ke folder dokumen aplikasi sebelum menjadi `fotoPath`
/// sesi — bukan lagi satu URL contoh yang sama untuk setiap sesi. Yang masih
/// palsu hanyalah **angka gizinya** (`FakeNutrisiService`), karena tidak ada
/// endpoint deteksi nutrisi untuk dituju; keduanya sengaja tidak digabung
/// menjadi satu sakelar.
///
/// Dua hal yang diminta §4.5 tetap ada di sini: kartu hasilnya **bisa diedit**
/// (estimasi porsi dari satu foto bisa meleset 30–50%, dan angka karbohidrat
/// itulah yang nanti dikorelasikan dengan respons glukosa), dan tombol
/// "Selesai Makan & Pantau" yang menetapkan t0.
class DeteksiMakananPage extends StatefulWidget {
  const DeteksiMakananPage({super.key, this.kamera});

  /// Disuntikkan oleh test — perannya persis seperti `izin:` pada halaman
  /// pemindaian. null berarti ikut [buatKameraBawaan], yang menghasilkan kamera
  /// sungguhan kecuali `--dart-define=PAKAI_KAMERA_PALSU=true` diminta.
  final KameraService? kamera;

  @override
  State<DeteksiMakananPage> createState() => _DeteksiMakananPageState();
}

class _DeteksiMakananPageState extends State<DeteksiMakananPage>
    with WidgetsBindingObserver {
  late final KameraService _kamera;
  GalatKamera? _galat;
  bool _menyiapkan = true;
  bool _sibuk = false;

  @override
  void initState() {
    super.initState();
    _kamera = widget.kamera ?? buatKameraBawaan();
    WidgetsBinding.instance.addObserver(this);
    _siapkanKamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _kamera.lepas();
    super.dispose();
  }

  /// Android mencabut kamera dari aplikasi yang tidak terlihat. Pratinjau yang
  /// tidak dilepas saat aplikasi ke latar belakang kembali sebagai layar hitam
  /// tanpa satu pun pesan galat, jadi ia dilepas dan disiapkan lagi.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _kamera.lepas();
    } else if (state == AppLifecycleState.resumed) {
      _siapkanKamera();
    }
  }

  /// Menyalakan kamera. Dipanggil dari `initState`, jadi ia **tidak** boleh
  /// membuka dengan `setState`: pemanggilan pertama terjadi di tengah fase
  /// build, dan `setState` di sana melempar. Keadaan awalnya cukup ditulis
  /// langsung — belum ada frame yang menampilkannya. Yang dari tombol "Coba
  /// Lagi" lewat [_cobaLagi], yang memang perlu memicu gambar ulang.
  Future<void> _siapkanKamera() async {
    _menyiapkan = true;
    _galat = null;
    try {
      await _kamera.siapkan();
    } on GalatKamera catch (e) {
      if (mounted) setState(() => _galat = e);
    } catch (e) {
      if (mounted) {
        setState(() => _galat = GalatKamera('Kamera tidak bisa dibuka ($e).'));
      }
    } finally {
      if (mounted) setState(() => _menyiapkan = false);
    }
  }

  void _cobaLagi() {
    setState(() {
      _menyiapkan = true;
      _galat = null;
    });
    _siapkanKamera();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SesiMakanController>();
    final sesi = controller.sesiAktif;

    // Satu-satunya layar berlatar gelap: ikon bilah statusnya harus terang,
    // kebalikan dari bawaan aplikasi (lihat utils/gaya_sistem.dart).
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: gayaSistemGelap,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
            // 1. Latar: pratinjau kamera selama belum ada foto, lalu foto yang
            //    barusan diambil — piring yang sedang dianalisis harus terlihat
            //    saat angkanya dikoreksi.
            Positioned.fill(child: _latar(sesi)),

            // 2. Camera Viewfinder Overlay bounds (Corners)
            if (sesi == null && _kamera.siap) const _BingkaiKamera(),

            // 3. Header Arrow Back
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 20,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.4),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 22,
              left: 0,
              right: 0,
              child: const Center(
                child: Text(
                  'Deteksi Makanan',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),

            // 4. Camera controls — hanya selama belum ada foto yang diambil.
            if (sesi == null && _galat == null)
              Positioned(
                // Bilah navigasi sistem menumpang di atas pratinjau kamera,
                // jadi 60 px itu diukur dari tepi layar, bukan dari tepi yang
                // bisa disentuh. Tombol rana yang setengah tertutup bilah tiga
                // tombol adalah kegagalan yang tidak terlihat di emulator.
                bottom: 60 + MediaQuery.paddingOf(context).bottom,
                left: 40,
                right: 40,
                child: _KendaliKamera(
                  aktif: _kamera.siap && !_sibuk,
                  lampuMenyala: _kamera.lampuMenyala,
                  punyaLampu: _kamera.punyaLampu,
                  onGaleri: _pilihDariGaleri,
                  onRana: _tekanShutter,
                  onLampu: () async {
                    await _kamera.gantiLampu();
                    if (mounted) setState(() {});
                  },
                ),
              ),

            // 5. Kartu hasil analisis — muncul setelah shutter ditekan.
            if (sesi != null)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _KartuHasil(sesi: sesi, controller: controller),
              ),
          ],
        ),
      ),
    );
  }

  Widget _latar(SesiMakan? sesi) {
    if (sesi != null) {
      return Opacity(
        opacity: 0.85,
        child: FotoMakanan(fotoPath: sesi.fotoPath, radius: 0),
      );
    }
    if (_galat != null) {
      return _LayarGalatKamera(
        galat: _galat!,
        onCobaLagi: _cobaLagi,
        onGaleri: _pilihDariGaleri,
      );
    }
    if (_kamera.siap) return _kamera.pratinjau();
    return ColoredBox(
      color: const Color(0xFF10201C),
      child: Center(
        child: _menyiapkan
            ? const CircularProgressIndicator(color: Color(0xFF0EAD69))
            : const SizedBox.shrink(),
      ),
    );
  }

  /// Shutter ditekan: foto diambil, sesi draft dibuat, baseline pra-makan
  /// diminta ke jam, dan analisis nutrisi berjalan di belakang (§12.6).
  Future<void> _tekanShutter() async {
    if (_sibuk || !_kamera.siap) return;
    setState(() => _sibuk = true);
    try {
      if (!await _pastikanTidakAdaSesiAktif()) return;
      final jalur = await _kamera.ambilFoto();
      if (!mounted) return;
      await context.read<SesiMakanController>().mulaiDraft(jalur);
    } on GalatKamera catch (e) {
      _kabarkan(e.pesan);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  Future<void> _pilihDariGaleri() async {
    if (_sibuk) return;
    setState(() => _sibuk = true);
    try {
      if (!await _pastikanTidakAdaSesiAktif()) return;
      final jalur = await _kamera.pilihDariGaleri();
      if (jalur == null || !mounted) return;
      await context.read<SesiMakanController>().mulaiDraft(jalur);
    } on GalatKamera catch (e) {
      _kabarkan(e.pesan);
    } finally {
      if (mounted) setState(() => _sibuk = false);
    }
  }

  void _kabarkan(String pesan) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(pesan), backgroundColor: const Color(0xFF1E3A34)),
    );
  }

  /// Hanya satu sesi aktif pada satu waktu (§6). Mengembalikan false bila
  /// pengguna memilih membiarkan sesi yang sedang berjalan.
  Future<bool> _pastikanTidakAdaSesiAktif() async {
    final controller = context.read<SesiMakanController>();
    if (controller.sesiAktif == null) return true;

    final akhiri = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Akhiri sesi berjalan?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        content: const Text(
          'Masih ada sesi yang belum selesai. Sampel yang belum masuk akan '
          'ditandai terlewat, lalu sesi baru dimulai.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B807B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Batal',
              style: TextStyle(
                color: Color(0xFF6B807B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Akhiri & Foto',
              style: TextStyle(
                color: Color(0xFF0EAD69),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (akhiri != true) return false;
    await controller.akhiriLebihAwal();
    return true;
  }
}

/// Baris tombol kamera: galeri, rana, lampu.
class _KendaliKamera extends StatelessWidget {
  const _KendaliKamera({
    required this.aktif,
    required this.lampuMenyala,
    required this.punyaLampu,
    required this.onGaleri,
    required this.onRana,
    required this.onLampu,
  });

  final bool aktif;
  final bool lampuMenyala;
  final bool punyaLampu;
  final VoidCallback onGaleri;
  final VoidCallback onRana;
  final VoidCallback onLampu;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _bulat(ikon: Icons.image_outlined, onTap: aktif ? onGaleri : null),
        Opacity(
          opacity: aktif ? 1 : 0.5,
          child: GestureDetector(
            onTap: aktif ? onRana : null,
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              padding: const EdgeInsets.all(4),
              child: Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.black, width: 3),
                  color: const Color(0xFF0EAD69),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.photo_camera_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
          ),
        ),
        // Tombol lampu hilang, bukan sekadar mati, pada kamera yang tidak
        // punya lampu kilat.
        if (punyaLampu)
          _bulat(
            ikon: lampuMenyala
                ? Icons.flash_on_rounded
                : Icons.flash_off_rounded,
            onTap: aktif ? onLampu : null,
            terang: lampuMenyala,
          )
        else
          const SizedBox(width: 48),
      ],
    );
  }

  Widget _bulat({
    required IconData ikon,
    required VoidCallback? onTap,
    bool terang = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 24,
        backgroundColor: terang
            ? const Color(0xFF0EAD69)
            : Colors.white.withValues(alpha: 0.2),
        child: Icon(
          ikon,
          color: onTap == null ? Colors.white54 : Colors.white,
          size: 24,
        ),
      ),
    );
  }
}

/// Layar penuh saat kamera tidak bisa dibuka.
///
/// Izin yang ditolak tidak pernah pulih dengan "coba lagi" — sistem tidak
/// menanyakannya dua kali — jadi hanya kasus itu yang menawarkan Pengaturan.
/// Galeri selalu ditawarkan: memotret piring dengan aplikasi kamera bawaan
/// lalu memilihnya di sini tetap menghasilkan sesi yang utuh.
class _LayarGalatKamera extends StatelessWidget {
  const _LayarGalatKamera({
    required this.galat,
    required this.onCobaLagi,
    required this.onGaleri,
  });

  final GalatKamera galat;
  final VoidCallback onCobaLagi;
  final VoidCallback onGaleri;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: const Color(0xFF10201C),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                color: Colors.white70,
                size: 56,
              ),
              const SizedBox(height: 16),
              const Text(
                'Kamera tidak bisa dibuka',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                galat.pesan,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: galat.izinDitolak ? openAppSettings : onCobaLagi,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EAD69),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    galat.izinDitolak ? 'Buka Pengaturan' : 'Coba Lagi',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: onGaleri,
                style: TextButton.styleFrom(foregroundColor: Colors.white70),
                child: const Text(
                  'Pilih Foto dari Galeri',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BingkaiKamera extends StatelessWidget {
  const _BingkaiKamera();

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Center(
        child: Container(
          width: 280,
          height: 280,
          decoration: BoxDecoration(
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.5),
              width: 1,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Stack(
            children: [
              _sudut(top: 0, left: 0),
              _sudut(top: 0, right: 0),
              _sudut(bottom: 0, left: 0),
              _sudut(bottom: 0, right: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sudut({double? top, double? bottom, double? left, double? right}) {
    const sisi = BorderSide(color: Colors.white, width: 4);
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
          border: Border(
            top: top != null ? sisi : BorderSide.none,
            bottom: bottom != null ? sisi : BorderSide.none,
            left: left != null ? sisi : BorderSide.none,
            right: right != null ? sisi : BorderSide.none,
          ),
        ),
      ),
    );
  }
}

/// Lencana kecil di pojok kartu hasil, atau null bila tidak ada yang bisa
/// dikatakan.
///
/// Keyakinan yang **tidak diketahui** tidak ditampilkan sama sekali — bukan
/// ditampilkan sebagai 0%. Layanan deteksi sekarang memang tidak menghasilkan
/// keyakinan terkalibrasi, dan "Keyakinan 0%" akan terbaca sebagai deteksi yang
/// buruk padahal tidak ada yang pernah menilainya.
String? _lencana(HasilDeteksi hasil) {
  if (hasil.dikoreksiUser) return 'Sudah dikoreksi';
  final k = hasil.keyakinan;
  return k == null ? null : 'Keyakinan ${(k * 100).round()}%';
}

/// Angka yang boleh tidak ada.
String _teksNutrisi(double? nilai, String satuan) =>
    nilai == null ? '— $satuan' : '${formatAngka(nilai)} $satuan';

/// Kartu hasil yang bisa dikoreksi sebelum sesi dimulai.
class _KartuHasil extends StatelessWidget {
  const _KartuHasil({required this.sesi, required this.controller});

  final SesiMakan sesi;
  final SesiMakanController controller;

  @override
  Widget build(BuildContext context) {
    final hasil = sesi.hasil;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.72,
      ),
      // Putihnya sengaja tetap membentang sampai tepi bawah layar; yang
      // ditambah hanya jarak isinya, supaya tombol paling bawah tidak duduk di
      // belakang bilah navigasi sistem.
      padding: EdgeInsets.fromLTRB(
        20,
        20,
        20,
        24 + MediaQuery.paddingOf(context).bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: const [
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 18,
                      color: Color(0xFF0EAD69),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Hasil Analisis',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A34),
                      ),
                    ),
                  ],
                ),
                if (hasil != null && _lencana(hasil) != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2F6F0),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _lencana(hasil)!,
                      style: const TextStyle(
                        color: Color(0xFF0EAD69),
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),

            if (hasil == null)
              RingkasanNutrisi(
                hasil: null,
                sedangDianalisis: controller.sedangMenganalisis(sesi.id),
              )
            else ...[
              // Estimasi porsi dari satu foto sering meleset; koreksinya paling
              // akurat sekarang, saat piringnya masih di depan mata (§4.5).
              for (final item in hasil.makanan)
                _BarisItem(
                  item: item,
                  onEdit: () => _editItem(context, hasil, item),
                ),
              const SizedBox(height: 8),
              const Divider(color: Color(0xFFE2EBE8), height: 24),
              RingkasanNutrisi(hasil: hasil),
            ],
            const SizedBox(height: 20),

            // t0 tidak lagi bisa ditetapkan dari sini: tombolnya ada di jam
            // (§6). Yang tersisa untuk app adalah menerangkan apa yang
            // ditunggu.
            PetunjukTombolJam(
              status: sesi.status,
              perangkat: controller.statusPerangkat,
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  await controller.batalkan();
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text(
                  'Ambil ulang foto',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF6B807B),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editItem(
    BuildContext context,
    HasilDeteksi hasil,
    ItemMakanan item,
  ) async {
    final hasilEdit = await showModalBottomSheet<ItemMakanan>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => _SheetKoreksi(item: item),
    );
    if (hasilEdit == null) return;

    controller.koreksiHasil([
      for (final m in hasil.makanan)
        if (identical(m, item)) hasilEdit else m,
    ]);
  }
}

class _BarisItem extends StatelessWidget {
  const _BarisItem({required this.item, required this.onEdit});

  final ItemMakanan item;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: const BoxDecoration(
              color: Color(0xFFE2F6F0),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: const Icon(
              Icons.restaurant_rounded,
              size: 16,
              color: Color(0xFF0EAD69),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.nama,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A34),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${item.porsi} · ${formatAngka(item.estimasiGram)} g · '
                  // Makanan yang belum ada di tabel gizi tetap tampil dengan
                  // nama, porsi, dan beratnya — pengguna memang memakannya, dan
                  // menyembunyikannya membuat kartu tidak cocok dengan piring
                  // yang dilihatnya. Yang hilang cuma angkanya.
                  '${item.nutrisi.karbohidrat == null ? 'karbo belum ada di tabel gizi' : '${formatAngka(item.nutrisi.karbohidrat!)} g karbo'}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8FA7A1),
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 14),
            label: const Text('Koreksi', style: TextStyle(fontSize: 12)),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF0EAD69),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel koreksi satu item: nama, teks porsi, dan berat.
///
/// Nutrisinya ikut terskala mengikuti berat, karena yang dikoreksi user adalah
/// porsinya — bukan kandungan gizi per gram.
class _SheetKoreksi extends StatefulWidget {
  const _SheetKoreksi({required this.item});

  final ItemMakanan item;

  @override
  State<_SheetKoreksi> createState() => _SheetKoreksiState();
}

class _SheetKoreksiState extends State<_SheetKoreksi> {
  late final TextEditingController _nama;
  late final TextEditingController _porsi;
  late final TextEditingController _gramTeks;
  late double _gram;

  @override
  void initState() {
    super.initState();
    _nama = TextEditingController(text: widget.item.nama);
    _porsi = TextEditingController(text: widget.item.porsi);
    _gram = widget.item.estimasiGram;
    _gramTeks = TextEditingController(text: _gram.round().toString());
  }

  @override
  void dispose() {
    _nama.dispose();
    _porsi.dispose();
    _gramTeks.dispose();
    super.dispose();
  }

  /// Dipakai tombol ½× dan 1½×; kolom teksnya ikut menyesuaikan.
  void _setGram(double gram) {
    setState(() => _gram = gram);
    _gramTeks.text = gram.round().toString();
  }

  ItemMakanan get _hasil => widget.item.salin(
    nama: _nama.text.trim().isEmpty ? widget.item.nama : _nama.text.trim(),
    porsi: _porsi.text.trim().isEmpty ? widget.item.porsi : _porsi.text.trim(),
    estimasiGram: _gram,
  );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Koreksi Makanan',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _kolom('Nama', _nama),
          const SizedBox(height: 14),
          _kolom('Porsi', _porsi, petunjuk: 'mis. setengah piring'),
          const SizedBox(height: 18),

          const Text(
            'Perkiraan berat',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B807B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('gram'),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  controller: _gramTeks,
                  onChanged: (teks) {
                    final nilai = double.tryParse(teks);
                    if (nilai != null && nilai > 0) {
                      setState(() => _gram = nilai);
                    }
                  },
                  decoration: _dekorasi(satuan: 'gram'),
                ),
              ),
              const SizedBox(width: 12),
              for (final faktor in const [0.5, 1.5])
                Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: GestureDetector(
                    onTap: () => _setGram(_gram * faktor),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE5EDE9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        faktor == 0.5 ? '½×' : '1½×',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF6B807B),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Dampak koreksi langsung terlihat: inilah angka yang nanti masuk
          // ke sebaran di Analisis.
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFE2F6F0),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              _hasil.nutrisi.kalori == null &&
                      _hasil.nutrisi.karbohidrat == null
                  // Menskalakan yang tidak diketahui tetap menghasilkan yang
                  // tidak diketahui; menampilkan "Menjadi 0 kcal" di sini akan
                  // membuat koreksi porsi terasa seperti menghapus makanannya.
                  ? 'Beratnya berubah; angka gizinya belum ada di tabel gizi.'
                  : 'Menjadi ${_teksNutrisi(_hasil.nutrisi.kalori, 'kcal')} · '
                        '${_teksNutrisi(_hasil.nutrisi.karbohidrat, 'g karbohidrat')}',
              style: const TextStyle(fontSize: 12, color: Color(0xFF1E3A34)),
            ),
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context, _hasil),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0EAD69),
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Simpan Koreksi',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _kolom(
    String label,
    TextEditingController controller, {
    String? petunjuk,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B807B),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: Key(label.toLowerCase()),
          controller: controller,
          onChanged: (_) => setState(() {}),
          decoration: _dekorasi(petunjuk: petunjuk),
        ),
      ],
    );
  }

  InputDecoration _dekorasi({String? satuan, String? petunjuk}) {
    return InputDecoration(
      hintText: petunjuk,
      hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF9CB1AC)),
      suffixText: satuan,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      filled: true,
      fillColor: const Color(0xFFF4FAF7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2EBE8)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFE2EBE8)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0EAD69), width: 1.5),
      ),
    );
  }
}
