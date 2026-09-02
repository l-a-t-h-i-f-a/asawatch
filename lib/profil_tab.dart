import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'informasi_pribadi_page.dart';
import 'kalibrasi_tekanan_darah_page.dart';
import 'menghubungkan_perangkat_page.dart';
import 'pindai_kesehatan_page.dart';

import 'repositories/profil_repository.dart';

class ProfilTab extends StatefulWidget {
  const ProfilTab({
    super.key,
    this.onKeluar,
    this.profil = const ProfilRepository(),
  });

  /// Pintu ke profil; diteruskan apa adanya ke `InformasiPribadiPage`. Lihat
  /// `InformasiPribadiPage.profil`.
  final ProfilRepository profil;

  /// Dijalankan sebelum kembali ke halaman sambutan: mencabut token di server
  /// dan menghapus salinannya di perangkat. Dirakit `MyHomePage`, karena di
  /// sanalah `AuthService` dan penyimpanan sesinya hidup.
  final Future<void> Function()? onKeluar;

  @override
  State<ProfilTab> createState() => _ProfilTabState();
}

class _ProfilTabState extends State<ProfilTab> {
  Profil _profil = Profil.kosong;
  bool _isLoading = true;

  /// Keluar selalu ditanya dulu.
  ///
  /// Bukan karena datanya hilang — sesi makan tersimpan di ponsel dan tetap ada
  /// setelah masuk lagi — melainkan karena masuk kembali menuntut mengetik
  /// email dan kata sandi, dan tombolnya duduk tepat di bawah menu yang sering
  /// disentuh.
  Future<void> _konfirmasiKeluar() async {
    final navigator = Navigator.of(context);
    final ya = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Keluar dari akun?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        content: const Text(
          'Anda perlu memasukkan email dan kata sandi lagi untuk masuk. '
          'Riwayat sesi yang tersimpan di ponsel ini tidak dihapus.',
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
              'Keluar',
              style: TextStyle(
                color: Colors.redAccent,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
    if (ya != true) return;

    await widget.onKeluar?.call();
    navigator.pushNamedAndRemoveUntil('/welcome', (route) => false);
  }

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    // Sengaja salinan lokal saja: tab ini dibangun bersama seluruh tab lain
    // saat shell dipasang (IndexedStack membangun semuanya), dan menarik
    // jaringan di situ berarti setiap pembukaan aplikasi menunggu server.
    // Penyamaan dengan server terjadi di halaman Informasi Pribadi.
    final profil = await widget.profil.muat();
    if (!mounted) return;
    setState(() {
      _profil = profil;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Profil Pengguna',
          style: TextStyle(
            color: Color(0xFF1E3A34),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EAD69)),
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // Profile Card/Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: const Color(0xFFE2EBE8),
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Dulu memuat foto orang asing dari Unsplash. Selain
                        // menampilkan identitas yang bukan milik pengguna, ia
                        // tidak pernah muncul di build rilis: aplikasi ini tidak
                        // mendeklarasikan izin INTERNET.
                        const CircleAvatar(
                          radius: 36,
                          backgroundColor: Color(0xFFE0F2F1),
                          child: Icon(
                            Icons.person,
                            color: Color(0xFF0EAD69),
                            size: 36,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _profil.nama.isEmpty
                                    ? 'Belum ada nama'
                                    : _profil.nama,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: _profil.nama.isEmpty
                                      ? const Color(0xFF8FA7A1)
                                      : const Color(0xFF1E3A34),
                                ),
                              ),
                              // Baris yang belum diisi dihilangkan, bukan
                              // ditampilkan kosong: satu ajakan lebih jelas
                              // daripada tiga baris hampa.
                              if (_profil.belumDiisi) ...[
                                const SizedBox(height: 4),
                                const Text(
                                  'Lengkapi lewat Informasi Pribadi di bawah.',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF7E9A94),
                                  ),
                                ),
                              ],
                              if (_profil.email.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _profil.email,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF7E9A94),
                                  ),
                                ),
                              ],
                              if (_profil.telepon.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  _profil.telepon,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF7E9A94),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Profile menu items
                  _buildProfileMenu(
                    icon: Icons.person_outline_rounded,
                    title: 'Informasi Pribadi',
                    onTap: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              InformasiPribadiPage(profil: widget.profil),
                        ),
                      );
                      if (updated == true) {
                        _loadProfileData();
                      }
                    },
                  ),
                  _buildProfileMenu(
                    icon: Icons.watch_rounded,
                    title: 'Status Perangkat',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const MenghubungkanPerangkatPage(),
                        ),
                      );
                    },
                  ),
                  _buildProfileMenu(
                    icon: Icons.monitor_heart_rounded,
                    title: 'Pindai Kesehatan',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const PindaiKesehatanPage(),
                        ),
                      );
                    },
                  ),
                  _buildProfileMenu(
                    icon: Icons.tune_rounded,
                    title: 'Kalibrasi Tekanan Darah',
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const KalibrasiTekananDarahPage(),
                        ),
                      );
                    },
                  ),
                  // Hanya muncul bila memang ada yang bisa dibersihkan.
                  // Ditanyakan ke riwayat, bukan ke `pakaiJadwalUji`: sesi uji
                  // tetap tersimpan setelah build ujinya diganti, dan rakitan
                  // biasalah yang kemudian memegangnya.
                  if (context.watch<SesiMakanController>().adaSesiUji)
                    _buildProfileMenu(
                      icon: Icons.science_rounded,
                      title: 'Hapus Semua Sesi Uji',
                      onTap: _konfirmasiHapusSesiUji,
                    ),
                  _buildProfileMenu(
                    icon: Icons.logout_rounded,
                    title: 'Keluar',
                    color: Colors.redAccent,
                    onTap: _konfirmasiKeluar,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  /// Selalu dikonfirmasi, walau yang dihapus "cuma" data uji: tidak ada yang
  /// bisa mengembalikannya, dan sebuah sesi uji yang sedang dipakai memeriksa
  /// persistensi punya nilai justru karena ia bertahan.
  Future<void> _konfirmasiHapusSesiUji() async {
    final controller = context.read<SesiMakanController>();
    final jumlah = controller.riwayat.where((s) => s.sesiUji).length;

    final ya = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hapus Sesi Uji?'),
        content: Text(
          '$jumlah sesi dari mode jadwal uji akan dihapus permanen, berikut '
          'seluruh pengukurannya. Sesi sungguhan tidak tersentuh.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ya != true) return;
    await controller.hapusSesiUji();
  }

  Widget _buildProfileMenu({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = const Color(0xFF1E3A34),
  }) {
    // The white background and border live on Material/ListTile.shape rather
    // than a wrapping Container: ListTile paints its ink splash on the nearest
    // Material ancestor, so an opaque DecoratedBox in between would hide it.
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: Color(0xFFE2EBE8), width: 1.2),
          ),
          leading: Icon(icon, color: color),
          title: Text(
            title,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          trailing: Icon(
            Icons.chevron_right_rounded,
            color: color.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }
}
