import 'package:flutter/material.dart';
import 'package:asawatch/welcome_page.dart';
import 'package:asawatch/login_page.dart';
import 'package:asawatch/register_page.dart';
import 'package:asawatch/beranda_tab.dart';
import 'package:asawatch/riwayat_tab.dart';
import 'package:asawatch/analisis_tab.dart';
import 'package:asawatch/profil_tab.dart';
import 'package:asawatch/deteksi_makanan_page.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HealthWatch',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0EAD69),
          primary: const Color(0xFF0EAD69),
          secondary: const Color(0xFF7BE5C4),
        ),
        fontFamily: 'Montserrat',
        useMaterial3: true,
      ),
      initialRoute: '/welcome',
      routes: {
        '/welcome': (context) => const WelcomePage(),
        '/login': (context) => const LoginPage(),
        '/register': (context) => const RegisterPage(),
        '/home': (context) => const MyHomePage(title: 'HealthWatch'),
      },
    );
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

  void _onTabSelected(int index) {
    if (index == 2) {
      // Open camera detection screen
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const DeteksiMakananPage()),
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
        index: _currentIndex == 2 ? 0 : _currentIndex, // Keep showing previous tab if index 2 is clicked (though it pushes a page)
        children: _tabs,
      ),
      bottomNavigationBar: Container(
        height: 80,
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
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    final color = isSelected ? const Color(0xFF0EAD69) : const Color(0xFF8FA7A1);
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
        child: const Icon(
          Icons.photo_camera_rounded, // Camera icon replaced the '+' icon
          color: Colors.white,
          size: 28,
        ),
      ),
    );
  }
}
