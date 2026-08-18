import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'models/contoh_sesi.dart';
import 'models/sesi_makan.dart';
import 'utils/format_waktu.dart';
import 'utils/gaya_sistem.dart';
import 'widgets/petunjuk_tombol_jam.dart';
import 'widgets/ringkasan_nutrisi.dart';

/// Kamera deteksi makanan — pemicu seluruh siklus sesi (§2 poin 4).
///
/// Dua hal yang diminta §4.5 ada di sini: kartu hasilnya **bisa diedit**
/// (estimasi porsi dari satu foto bisa meleset 30–50%, dan angka karbohidrat
/// itulah yang nanti dikorelasikan dengan respons glukosa), dan tombol
/// "Selesai Makan & Pantau" yang menetapkan t0.
class DeteksiMakananPage extends StatelessWidget {
  const DeteksiMakananPage({super.key});

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
            // 1. Cameraview Finder Background (Placeholder Food Image)
            Positioned.fill(
              child: Opacity(
                opacity: 0.85,
                child: Image.network(
                  contohFotoPath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFF1E3A34),
                      child: const Center(
                        child: Icon(
                          Icons.restaurant_menu,
                          color: Colors.white,
                          size: 80,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

            // 2. Camera Viewfinder Overlay bounds (Corners)
            if (sesi == null) const _BingkaiKamera(),

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
            if (sesi == null)
              Positioned(
                // Bilah navigasi sistem menumpang di atas pratinjau kamera,
                // jadi 60 px itu diukur dari tepi layar, bukan dari tepi yang
                // bisa disentuh. Tombol rana yang setengah tertutup bilah tiga
                // tombol adalah kegagalan yang tidak terlihat di emulator.
                bottom: 60 + MediaQuery.paddingOf(context).bottom,
                left: 40,
                right: 40,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: const Icon(
                        Icons.image_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _tekanShutter(context),
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
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: Colors.white.withValues(alpha: 0.2),
                      child: const Icon(
                        Icons.flash_on_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ],
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

  /// Shutter ditekan: sesi draft dibuat, baseline pra-makan diminta ke jam,
  /// dan analisis nutrisi berjalan di belakang (§12.6).
  Future<void> _tekanShutter(BuildContext context) async {
    final controller = context.read<SesiMakanController>();

    // Hanya satu sesi aktif pada satu waktu (§6).
    if (controller.sesiAktif != null) {
      final akhiri = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
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
      if (akhiri != true) return;
      await controller.akhiriLebihAwal();
    }

    await controller.mulaiDraft(contohFotoPath);
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
                if (hasil != null)
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
                      hasil.dikoreksiUser
                          ? 'Sudah dikoreksi'
                          : 'Keyakinan ${(hasil.keyakinan * 100).round()}%',
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
              const RingkasanNutrisi(hasil: null)
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
                  '${formatAngka(item.nutrisi.karbohidrat)} g karbo',
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
              'Menjadi ${formatAngka(_hasil.nutrisi.kalori)} kcal · '
              '${formatAngka(_hasil.nutrisi.karbohidrat)} g karbohidrat',
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
