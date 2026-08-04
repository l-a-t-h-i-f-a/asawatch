import 'package:flutter/material.dart';

class AnalisisTab extends StatefulWidget {
  const AnalisisTab({super.key});

  @override
  State<AnalisisTab> createState() => _AnalisisTabState();
}

class _AnalisisTabState extends State<AnalisisTab> {
  bool _isMingguan = true;

  @override
  Widget build(BuildContext context) {
    // Data tiruan yang berubah berdasarkan filter Mingguan / Bulanan
    final String bannerTitle = _isMingguan ? 'Kondisi Anda Minggu Ini:' : 'Kondisi Anda Bulan Ini:';
    final String bannerStatus = _isMingguan ? 'Sangat Baik! 🌟' : 'Luar Biasa! 🏆';
    final String bannerDesc = _isMingguan
        ? 'Semua parameter kesehatan Anda berada dalam batas normal. Pertahankan gaya hidup sehat Anda!'
        : 'Sepanjang bulan ini, tubuh Anda menunjukkan adaptasi fisik yang optimal dengan tingkat kebugaran yang stabil.';

    final String avgHeartRate = _isMingguan ? '75 bpm' : '72 bpm';
    final double progressHeartRate = _isMingguan ? 0.75 : 0.72;

    final String avgSugar = _isMingguan ? '108 mg/dL' : '104 mg/dL';
    final double progressSugar = _isMingguan ? 0.8 : 0.76;

    final String avgBloodPressure = _isMingguan ? '115/75 mmHg' : '112/72 mmHg';
    final double progressBloodPressure = _isMingguan ? 0.9 : 0.88;

    final String avgSleep = _isMingguan ? '7j 30m' : '7j 45m';
    final double progressSleep = _isMingguan ? 0.75 : 0.78;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Analisis Kesehatan',
          style: TextStyle(color: Color(0xFF1E3A34), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Tabs toggle (Mingguan, Bulanan)
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFE5EDE9),
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _buildTab('Mingguan', _isMingguan, () {
                    setState(() {
                      _isMingguan = true;
                    });
                  }),
                  _buildTab('Bulanan', !_isMingguan, () {
                    setState(() {
                      _isMingguan = false;
                    });
                  }),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Health Status Banner Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFE2F6F0),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          bannerTitle,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF7E9A94),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bannerStatus,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0EAD69),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          bannerDesc,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B807B),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Rincian Parameter Title
            const Text(
              'Rincian Parameter',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A34),
              ),
            ),
            const SizedBox(height: 16),

            // Parameter cards
            _buildParameterCard(
              title: 'Rata-rata Detak Jantung',
              value: avgHeartRate,
              status: 'Normal',
              color: Colors.redAccent,
              progress: progressHeartRate,
            ),
            _buildParameterCard(
              title: 'Rata-rata Gula Darah',
              value: avgSugar,
              status: 'Normal',
              color: const Color(0xFF0EAD69),
              progress: progressSugar,
            ),
            _buildParameterCard(
              title: 'Rata-rata Tekanan Darah',
              value: avgBloodPressure,
              status: 'Normal',
              color: Colors.teal,
              progress: progressBloodPressure,
            ),
            _buildParameterCard(
              title: 'Tidur Rata-rata',
              value: avgSleep,
              status: 'Cukup',
              color: Colors.indigo,
              progress: progressSleep,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildTab(String title, bool isSelected, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
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
      ),
    );
  }

  Widget _buildParameterCard({
    required String title,
    required String value,
    required String status,
    required Color color,
    required double progress,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2F6F0),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  status,
                  style: const TextStyle(
                    color: Color(0xFF0EAD69),
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A34),
            ),
          ),
          const SizedBox(height: 12),
          // Progress bar indicators
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE5EDE9),
              color: color,
              minHeight: 8,
            ),
          ),
        ],
      ),
    );
  }
}
