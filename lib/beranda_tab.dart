import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:asawatch/tekanan_darah_detail_page.dart';
import 'package:asawatch/gula_darah_detail_page.dart';
import 'package:asawatch/detak_jantung_detail_page.dart';
import 'package:asawatch/widgets/sparkline.dart';

class BerandaTab extends StatefulWidget {
  const BerandaTab({super.key});

  @override
  State<BerandaTab> createState() => _BerandaTabState();
}

class _BerandaTabState extends State<BerandaTab> {
  String _nama = 'Lathifa';

  @override
  void initState() {
    super.initState();
    _loadNama();
  }

  // Fungsi memuat nama dari SharedPreferences secara periodik / saat dimuat
  Future<void> _loadNama() async {
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('user_name');
    if (savedName != null && savedName.isNotEmpty) {
      if (mounted) {
        setState(() {
          _nama = savedName;
        });
      }
    }
  }

  // Format tanggal saat ini ke format Indonesia
  String _formatCurrentDate() {
    final now = DateTime.now();
    const days = [
      'Minggu',
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const months = [
      '',
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];

    final dayName = days[now.weekday];
    final monthName = months[now.month];
    return '$dayName, ${now.day} $monthName ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Pastikan memuat nama terbaru saat widget dibuild kembali
    _loadNama();

    return SafeArea(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: const Color(0xFFE0F2F1),
                  child: ClipOval(
                    child: Image.network(
                      'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&q=80&w=150',
                      fit: BoxFit.cover,
                      width: 44,
                      height: 44,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.person, color: Color(0xFF0EAD69));
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            'Halo, $_nama',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A34),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '👋',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.amber.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatCurrentDate(),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF7E9A94),
                        ),
                      ),
                    ],
                  ),
                ),
                // Notification and Badge
                Stack(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.notifications_none_rounded, color: Color(0xFF1E3A34), size: 28),
                      onPressed: () {},
                    ),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.redAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Watch Connected Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE2F6F0),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  // Smartwatch Illustration
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Watch bands
                        Container(
                          width: 24,
                          height: 60,
                          decoration: BoxDecoration(
                            color: const Color(0xFF2C3E50),
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        // Screen
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1A1A1A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFF5AB693), width: 1.5),
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.favorite_rounded,
                              color: Color(0xFF0EAD69),
                              size: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Watch Terhubung',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A34),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.battery_5_bar_rounded, color: Color(0xFF0EAD69), size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '100%',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: const Color(0xFF1E3A34).withValues(alpha: 0.8),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Terakhir sinkronisasi\n21 Mei 2024, 08:00',
                          style: TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B807B),
                            height: 1.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Sync Button
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.sync_rounded, size: 14, color: Colors.white),
                    label: const Text(
                      'Sinkronkan',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0EAD69),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Ringkasan Kesehatan
            const Text(
              'Ringkasan Kesehatan',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A34),
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Data terbaru 08:00',
              style: TextStyle(
                fontSize: 11,
                color: Color(0xFF7E9A94),
              ),
            ),
            const SizedBox(height: 16),

            // Grid of 4 Health summaries
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 16,
              crossAxisSpacing: 16,
              childAspectRatio: 1.3,
              children: [
                _buildHealthCard(
                  context,
                  title: 'Detak Jantung',
                  value: '78',
                  unit: ' bpm',
                  status: 'Normal',
                  icon: Icons.favorite_rounded,
                  iconColor: Colors.redAccent,
                  sparklineColors: [Colors.redAccent, Colors.redAccent.withValues(alpha: 0.2)],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const DetakJantungDetailPage()),
                  ),
                ),
                _buildHealthCard(
                  context,
                  title: 'Gula Darah',
                  value: '112',
                  unit: ' mg/dL',
                  status: 'Normal',
                  icon: Icons.water_drop_rounded,
                  iconColor: const Color(0xFF0EAD69),
                  sparklineColors: [const Color(0xFF0EAD69), const Color(0xFF0EAD69).withValues(alpha: 0.2)],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const GulaDarahDetailPage()),
                  ),
                ),
                _buildHealthCard(
                  context,
                  title: 'Tekanan Darah',
                  value: '118/78',
                  unit: ' mmHg',
                  status: 'Normal',
                  icon: Icons.favorite_border_rounded,
                  iconColor: Colors.teal,
                  sparklineColors: [Colors.teal, Colors.teal.withValues(alpha: 0.2)],
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const TekananDarahDetailPage()),
                  ),
                ),
                _buildHealthCard(
                  context,
                  title: 'Kalori Hari Ini',
                  value: '1560',
                  unit: ' kcal',
                  status: 'Baik',
                  icon: Icons.local_fire_department_rounded,
                  iconColor: Colors.orange,
                  sparklineColors: [Colors.orange, Colors.orange.withValues(alpha: 0.2)],
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Tren Kesehatan section
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Tren Kesehatan (Per 2 Jam)',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A34),
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text(
                    'Lihat Semua',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0EAD69),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Toggle Tabs
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE5EDE9),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildToggleTab('Harian', true),
                  _buildToggleTab('Mingguan', false),
                  _buildToggleTab('Bulanan', false),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Chart Card
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Stack(
                children: [
                  // Chart background grid
                  Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(4, (index) {
                      return Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 1,
                              color: const Color(0xFFE0EDE9).withValues(alpha: 0.6),
                            ),
                          ),
                        ],
                      );
                    }),
                  ),
                  // Spline line
                  Positioned.fill(
                    child: CustomPaint(
                      painter: DashboardSplinePainter(),
                    ),
                  ),
                  // Highlight Label at 08:00
                  Positioned(
                    left: 92,
                    top: 42,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2F6F0),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text(
                        '08:00',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0EAD69),
                        ),
                      ),
                    ),
                  ),
                  // Timeline texts
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Text('00:00', style: TextStyle(fontSize: 10, color: Color(0xFF90A4AE))),
                        Text('04:00', style: TextStyle(fontSize: 10, color: Color(0xFF90A4AE))),
                        Text('08:00', style: TextStyle(fontSize: 10, color: Color(0xFF90A4AE), fontWeight: FontWeight.bold)),
                        Text('12:00', style: TextStyle(fontSize: 10, color: Color(0xFF90A4AE))),
                        Text('16:00', style: TextStyle(fontSize: 10, color: Color(0xFF90A4AE))),
                        Text('20:00', style: TextStyle(fontSize: 10, color: Color(0xFF90A4AE))),
                        Text('24:00', style: TextStyle(fontSize: 10, color: Color(0xFF90A4AE))),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildToggleTab(String title, bool isSelected) {
    return Expanded(
      child: Container(
        height: 38,
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0EAD69) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        alignment: Alignment.center,
        child: Text(
          title,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF6B807B),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildHealthCard(
    BuildContext context, {
    required String title,
    required String value,
    required String unit,
    required String status,
    required IconData icon,
    required Color iconColor,
    required List<Color> sparklineColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A34),
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                ),
                children: [
                  TextSpan(text: value),
                  TextSpan(
                    text: unit,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.normal,
                      color: Color(0xFF6B807B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text(
              status,
              style: TextStyle(
                fontSize: 10,
                color: status == 'Baik' || status == 'Normal' ? const Color(0xFF0EAD69) : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            // Miniature Sparkline
            SizedBox(
              height: 18,
              width: double.infinity,
              child: CustomPaint(
                painter: MiniSparklinePainter(colors: sparklineColors),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardSplinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Wave line path
    final paintLine = Paint()
      ..color = const Color(0xFF0EAD69)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.6)
      ..cubicTo(size.width * 0.15, size.height * 0.5, size.width * 0.22, size.height * 0.65, size.width * 0.33, size.height * 0.48)
      ..cubicTo(size.width * 0.45, size.height * 0.3, size.width * 0.55, size.height * 0.6, size.width * 0.68, size.height * 0.52)
      ..cubicTo(size.width * 0.78, size.height * 0.4, size.width * 0.88, size.height * 0.63, size.width, size.height * 0.55);

    // Gradient below the line
    final pathFill = Path.from(path)
      ..lineTo(size.width, size.height - 20)
      ..lineTo(0, size.height - 20)
      ..close();

    final paintFill = Paint()
      ..shader = LinearGradient(
        colors: [
          const Color(0xFF0EAD69).withValues(alpha: 0.15),
          const Color(0xFF0EAD69).withValues(alpha: 0.0),
        ],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(pathFill, paintFill);
    canvas.drawPath(path, paintLine);

    // Draw active dot at 08:00 (around x = width * 0.33, y = height * 0.48)
    final dotX = size.width * 0.33;
    final dotY = size.height * 0.48;

    final dotOuter = Paint()
      ..color = const Color(0xFFE2F6F0)
      ..style = PaintingStyle.fill;
    final dotInner = Paint()
      ..color = const Color(0xFF0EAD69)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(dotX, dotY), 8, dotOuter);
    canvas.drawCircle(Offset(dotX, dotY), 4, dotInner);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
