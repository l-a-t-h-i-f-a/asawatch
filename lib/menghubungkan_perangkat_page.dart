import 'package:flutter/material.dart';

class MenghubungkanPerangkatPage extends StatelessWidget {
  const MenghubungkanPerangkatPage({super.key});

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
          'Menghubungkan Perangkat',
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
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 3-step diagram mockup (Matches mockup)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Step 1: Smartphone with BT
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F8F5),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.phone_android_rounded,
                                color: Color(0xFF0EAD69),
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                        
                        // Arrow
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF6B807B),
                        ),
                        
                        // Step 2: Smartwatch
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F8F5),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.watch_rounded,
                                color: Color(0xFF0EAD69),
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                        
                        // Arrow
                        const Icon(
                          Icons.arrow_forward_rounded,
                          color: Color(0xFF6B807B),
                        ),
                        
                        // Step 3: Success connection
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F8F5),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: const Icon(
                                Icons.phonelink_ring_rounded,
                                color: Color(0xFF0EAD69),
                                size: 28,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Step Text labels below
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: const [
                        Expanded(
                          child: Text(
                            '1. Aktifkan Bluetooth',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A34)),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '2. Nyalakan Perangkat',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A34)),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '3. Hubungkan di Aplikasi',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF1E3A34)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Instructions list
              _buildInstructionStep(
                stepNumber: '1',
                text: 'Pastikan Bluetooth aktif di smartphone Anda',
              ),
              _buildInstructionStep(
                stepNumber: '2',
                text: 'Nyalakan perangkat HealthWatch',
              ),
              _buildInstructionStep(
                stepNumber: '3',
                text: 'Buka aplikasi dan masuk ke menu Pengaturan Perangkat',
              ),
              _buildInstructionStep(
                stepNumber: '4',
                text: 'Pilih "Tambah Perangkat" dan pilih HealthWatch X1',
              ),
              _buildInstructionStep(
                stepNumber: '5',
                text: 'Tunggu hingga proses koneksi selesai',
              ),

              const SizedBox(height: 48),

              // Bottom assistance green banner
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F8F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFD0EBE0), width: 1),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Masih mengalami kesulitan?',
                            style: TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E3A34),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Hubungi kami',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF0EAD69),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.headset_mic_outlined,
                        color: Color(0xFF0EAD69),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionStep({
    required String stepNumber,
    required String text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: Text(
              stepNumber,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A34),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                text,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                  height: 1.4,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
