import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'
    show LicenseEntryWithLineBreaks, LicenseRegistry;
import 'package:flutter/services.dart' show SystemChrome, rootBundle;
import 'package:asawatch/utils/gaya_sistem.dart';
import 'package:provider/provider.dart';
import 'package:asawatch/welcome_page.dart';
import 'package:asawatch/login_page.dart';
import 'package:asawatch/register_page.dart';
import 'package:asawatch/beranda_tab.dart';
import 'package:asawatch/riwayat_tab.dart';
import 'package:asawatch/analisis_tab.dart';
import 'package:asawatch/profil_tab.dart';
import 'package:asawatch/deteksi_makanan_page.dart';
import 'package:asawatch/sesi_berjalan_page.dart';
import 'package:asawatch/controllers/sesi_makan_controller.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:asawatch/konfigurasi.dart';
import 'package:asawatch/repositories/anchor_repository.dart';
import 'package:asawatch/repositories/basis_data.dart';
import 'package:asawatch/repositories/entri_jam_repository.dart';
import 'package:asawatch/repositories/kalibrasi_repository.dart';
import 'package:asawatch/repositories/perangkat_repository.dart';
import 'package:asawatch/repositories/sesi_repository_drift.dart';
import 'package:asawatch/services/auth_service.dart';
import 'package:asawatch/services/ble_asli_service.dart';
import 'package:asawatch/services/ble_service.dart';
import 'package:asawatch/services/nutrisi_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Seluruh layar aplikasi berlatar terang, jadi ikon bilah status harus gelap
  // supaya terbaca. Layar kamera yang berlatar hitam menimpanya sendiri.
  SystemChrome.setSystemUIOverlayStyle(gayaSistemTerang);

  // Montserrat is bundled from assets/fonts; the SIL OFL requires its licence
  // to travel with it, so surface it in the app's licence page.
  LicenseRegistry.addLicense(() async* {
    final license = await rootBundle.loadString('assets/fonts/OFL.txt');
    yield LicenseEntryWithLineBreaks(const ['Montserrat'], license);
  });

  // Membuka basis data bisa gagal — berkas rusak, penyimpanan penuh, migrasi
  // yang belum ditulis. Tanpa tangkapan ini `main()` melempar sebelum `runApp`
  // dan pengguna hanya melihat layar kosong tanpa satu pun petunjuk.
  try {
    runApp(MyApp(controller: await buatControllerBawaan()));
  } catch (galat, jejak) {
    debugPrint('Gagal menyiapkan aplikasi: $galat\n$jejak');
    runApp(AplikasiGagalMulai(galat: galat));
  }
}

/// Merakit seluruh aplikasi: basis data, repository, jam, dan controller.
///
/// **Jam sungguhan adalah bawaannya sejak Tahap B.** Jam palsu tetap ada dan
/// tidak akan pernah dihapus (§11 aturan 4), tetapi ia sekarang harus diminta:
///
/// ```bash
/// flutter run --dart-define=PAKAI_JAM_PALSU=true
/// ```
///
/// `percepatan: 360` pada jam palsu memampatkan jeda 1 jam menjadi 10 detik,
/// supaya siklus sesi bisa dilihat utuh tanpa menunggu dua jam.
///
/// Riwayat dimuat di sini, sebelum `runApp`, bukan di dalam controller — lihat
/// `SesiRepository.muatSemua()`. Pembacaannya berlangsung milidetik, jadi tidak
/// ada layar "sedang memuat" yang perlu dibayar seluruh permukaan sesi. Yang
/// **tidak** ditunggu di sini adalah radio BLE: `BleAsliService.mulai()` berjalan
/// di belakang, karena menunggu jam tersambung berarti layar putih beberapa
/// detik setiap kali aplikasi dibuka.
Future<SesiMakanController> buatControllerBawaan() async {
  final db = BasisData(driftDatabase(name: 'asawatch'));
  final repo = SesiRepositoryDrift(db);
  final repoKalibrasi = KalibrasiRepositoryDrift(db);

  final BleService ble;
  if (pakaiJamPalsu) {
    ble = FakeBleService();
  } else {
    final asli = BleAsliService(
      anchorRepo: AnchorRepositoryDrift(db),
      entriRepo: EntriJamRepositoryDrift(db),
      perangkatRepo: PerangkatRepositoryPrefs(),
    );
    unawaited(asli.mulai());
    ble = asli;
  }

  return SesiMakanController(
    ble: ble,
    nutrisi: const FakeNutrisiService(),
    // Termasuk sesi yang masih berjalan: controller memisahkannya sendiri, dan
    // jadwalnya dihitung ulang dari t0 absolut (Tahap B).
    riwayatAwal: await repo.muatSemua(),
    repo: repo,
    repoKalibrasi: repoKalibrasi,
    kalibrasiAwal: await repoKalibrasi.terbaru(),
  );
}

/// Layar terakhir sebelum menyerah.
///
/// Aplikasi tidak bisa berjalan tanpa basis datanya, jadi tidak ada tombol
/// "lanjutkan saja" di sini — menawarkannya berarti menjanjikan aplikasi yang
/// diam-diam kehilangan setiap sesi yang direkamnya. Yang ditawarkan hanya
/// menutup, dan pesan yang cukup jelas untuk dilaporkan.
class AplikasiGagalMulai extends StatelessWidget {
  const AplikasiGagalMulai({super.key, required this.galat});

  final Object galat;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFFF4FAF7),
        body: SafeArea(
          top: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.warning_amber_rounded,
                    size: 48,
                    color: Color(0xFF8FA7A1),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'AsaWatch tidak bisa dibuka',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A34),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Data di perangkat ini gagal dibuka. Coba jalankan ulang '
                    'aplikasi. Bila terus berulang, hapus data aplikasi lewat '
                    'Pengaturan — riwayat sesi yang tersimpan akan ikut hilang.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 13,
                      color: Color(0xFF6B807B),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '$galat',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Montserrat',
                      fontSize: 11,
                      color: Color(0xFF9CB1AC),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, required this.controller, this.auth});

  /// Dirakit di `main()` — dan di test, agar `FakeBleService` bisa
  /// dikendalikan (§11). Dimiliki pemanggil, bukan widget ini.
  final SesiMakanController controller;

  /// Auth yang dipakai alur masuk. null berarti rakit yang bawaan sekali di
  /// sini — bukan di tiap pembangunan rute, yang akan membuat satu `http.Client`
  /// baru setiap kali halaman login dibuka.
  final AuthService? auth;

  @override
  State<MyApp> createState() => _MyAppState();
}

/// Stateful hanya demi satu hal: mendengarkan daur hidup aplikasi.
///
/// Sesi berlangsung ~2 jam dan pengguna pasti meninggalkan aplikasi. Di iOS
/// prosesnya bahkan tidak akan hidup selama itu, jadi menarik buffer jam saat
/// aplikasi kembali ke depan bukan penyempurnaan — itulah satu-satunya jalan
/// sampel yang terkumpul selama itu masuk (docs/protokol-jam.md §6,
/// rencana-produksi.md §7.1).
class _MyAppState extends State<MyApp> with WidgetsBindingObserver {
  late final AuthService _auth = widget.auth ?? buatAuthBawaan();
  late final bool _authMilikSendiri = widget.auth == null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_authMilikSendiri) _auth.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState keadaan) {
    if (keadaan != AppLifecycleState.resumed) return;
    final ble = widget.controller.ble;
    if (ble is BleAsliService) unawaited(ble.kembaliKeDepan());
  }

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
      title: 'AsaWatch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0EAD69),
          primary: const Color(0xFF0EAD69),
          secondary: const Color(0xFF7BE5C4),
        ),
        fontFamily: 'Montserrat',
        useMaterial3: true,
        // Tanpa ini tiap AppBar menghitung sendiri gaya bilah statusnya dari
        // warna latarnya yang transparan, dan hasilnya bisa ikon terang di
        // atas halaman terang.
        appBarTheme: const AppBarTheme(systemOverlayStyle: gayaSistemTerang),
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => WelcomePage(auth: _auth),
        '/login': (context) => LoginPage(auth: _auth),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const MyHomePage(title: 'AsaWatch'),
      },
    );

    // Satu ChangeNotifierProvider di atas MaterialApp (§12.6). Controller
    // dimiliki pemanggil — `main()` atau test — jadi dipasang lewat .value agar
    // tidak ikut di-dispose di sini.
    return ChangeNotifierProvider.value(value: widget.controller, child: app);
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});
  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _currentIndex = 0;

  late final List<Widget> _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = [
      const BerandaTab(),
      const RiwayatTab(),
      const Center(child: Text('Kamera')), // Placeholder for camera trigger
      const AnalisisTab(),
      const ProfilTab(),
    ];
  }

  /// Tombol tengah kontekstual (§6). Strukturnya tetap: index 2 selalu
  /// mendorong halaman, tidak pernah berpindah tab, sehingga `_tabs[2]` tetap
  /// placeholder dan IndexedStack tetap di-clamp.
  void _onTabSelected(int index) {
    if (index == 2) {
      final controller = context.read<SesiMakanController>();
      final aktif = controller.sesiAktif;

      // Dua wajah, bukan tiga: t0 ditetapkan dari tombol di jam, jadi app tidak
      // punya lagi aksi "selesai makan" (§6). Sesi yang sudah punya foto —
      // termasuk yang masih menunggu tombol jam — dibuka di Sesi Berjalan.
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => aktif == null
              ? const DeteksiMakananPage()
              : const SesiBerjalanPage(),
        ),
      );
    } else {
      setState(() {
        _currentIndex = index;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      body: IndexedStack(
        index: _currentIndex == 2
            ? 0
            : _currentIndex, // Keep showing previous tab if index 2 is clicked (though it pushes a page)
        children: _tabs,
      ),
      // `SafeArea` di dalam `Container`, bukan di luarnya: putihnya harus tetap
      // membentang sampai dasar layar (sejak Android 15 bilah navigasi sistem
      // selalu menumpang di atas aplikasi), sementara ikon dan labelnya naik ke
      // atas bilah itu. Dibalik urutannya, akan ada pita berwarna latar di
      // bawah bilah navigasi aplikasi.
      //
      // `BottomNavigationBar` bawaan Material melakukan persis ini sendiri;
      // bilah ini dirakit tangan, jadi ia harus melakukannya sendiri juga.
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 16,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 80,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildNavItem(0, Icons.home_rounded, 'Beranda'),
                _buildNavItem(1, Icons.assignment_outlined, 'Riwayat'),
                _buildCenterNavItem(),
                _buildNavItem(3, Icons.analytics_outlined, 'Analisis'),
                _buildNavItem(4, Icons.person_outline_rounded, 'Profil'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? const Color(0xFF0EAD69)
        : const Color(0xFF8FA7A1);
    return GestureDetector(
      onTap: () => _onTabSelected(index),
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 26),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterNavItem() {
    // Ikonnya ikut berubah karena maknanya berubah: foto → selesai makan →
    // buka sesi.
    final status = context.select<SesiMakanController, StatusSesi?>(
      (c) => c.sesiAktif?.status,
    );
    final ikon = switch (status) {
      null => Icons.photo_camera_rounded,
      StatusSesi.draft => Icons.restaurant_rounded,
      _ => Icons.timelapse_rounded,
    };

    return GestureDetector(
      onTap: () => _onTabSelected(2),
      child: Container(
        width: 56,
        height: 56,
        decoration: const BoxDecoration(
          color: Color(0xFF0EAD69),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: Color(0x3D0EAD69),
              blurRadius: 12,
              offset: Offset(0, 4),
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(ikon, color: Colors.white, size: 28),
      ),
    );
  }
}
