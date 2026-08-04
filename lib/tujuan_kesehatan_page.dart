import 'package:flutter/material.dart';

class TujuanKesehatanPage extends StatefulWidget {
  const TujuanKesehatanPage({super.key});

  @override
  State<TujuanKesehatanPage> createState() => _TujuanKesehatanPageState();
}

class _TujuanKesehatanPageState extends State<TujuanKesehatanPage> {
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
          'Tujuan Kesehatan',
          style: TextStyle(
            color: Color(0xFF1E3A34),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0EAD69), size: 28),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Tambah tujuan belum tersedia.')),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tujuan Aktif',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                ),
              ),
              const SizedBox(height: 16),
              
              _buildTargetItem(
                icon: Icons.directions_walk_rounded,
                iconColor: const Color(0xFF0EAD69),
                title: 'Langkah Harian',
                progressValue: 0.75,
                progressText: '75%',
                detailText: '8.000 langkah',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const EditTujuanPage(title: 'Langkah Harian'),
                    ),
                  );
                },
              ),
              _buildTargetItem(
                icon: Icons.monitor_weight_outlined,
                iconColor: Colors.blueAccent,
                title: 'Berat Badan',
                progressValue: 0.80,
                progressText: '80%',
                detailText: '52 kg',
              ),
              _buildTargetItem(
                icon: Icons.opacity_rounded,
                iconColor: const Color(0xFF0EAD69),
                title: 'Minum Air',
                progressValue: 0.60,
                progressText: '60%',
                detailText: '2.0 Liter / hari',
              ),
              _buildTargetItem(
                icon: Icons.nights_stay_outlined,
                iconColor: const Color(0xFF1E3A34),
                title: 'Tidur',
                progressValue: 0.70,
                progressText: '70%',
                detailText: '7 - 8 jam / malam',
              ),
              _buildTargetItem(
                icon: Icons.favorite_border_rounded,
                iconColor: Colors.redAccent,
                title: 'Detak Jantung',
                progressValue: 1.0,
                progressText: '100%',
                detailText: '60 - 100 bpm',
              ),
              
              const SizedBox(height: 24),
              
              // Bottom advice green banner for creating new goals
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
                            'Tambah Tujuan Baru',
                            style: TextStyle(
                              fontSize: 14,
                              color: Color(0xFF1E3A34),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Buat tujuan kesehatanmu sendiri',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6B807B),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Tambah tujuan belum tersedia.')),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Color(0xFF0EAD69),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.add_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTargetItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required double progressValue,
    required String progressText,
    required String detailText,
    VoidCallback? onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF4FAF7),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: iconColor, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A34),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          detailText,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B807B),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    progressText,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A34),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: progressValue,
                  backgroundColor: const Color(0xFFE2EBE8),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF0EAD69)),
                  minHeight: 6,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EditTujuanPage extends StatefulWidget {
  final String title;
  const EditTujuanPage({super.key, required this.title});

  @override
  State<EditTujuanPage> createState() => _EditTujuanPageState();
}

class _EditTujuanPageState extends State<EditTujuanPage> {
  int _targetSteps = 8000;
  String _selectedUnit = 'Langkah';
  String _selectedPeriod = 'Setiap hari';
  String _startDate = '21 Mei 2024';
  String _reminderTime = '08:00';
  bool _isReminderActive = true;

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
          'Edit Tujuan',
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
              // Goal header mockup
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F8F5),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFD0EBE0), width: 1.5),
                      ),
                      child: const Icon(
                        Icons.directions_walk_rounded,
                        color: Color(0xFF0EAD69),
                        size: 32,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A34),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // Target Harian Row with - and +
              const Text(
                'Target Harian',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '$_targetSteps langkah',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E3A34),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline_rounded, color: Color(0xFF6B807B)),
                      onPressed: () {
                        setState(() {
                          if (_targetSteps > 1000) _targetSteps -= 1000;
                        });
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline_rounded, color: Color(0xFF0EAD69)),
                      onPressed: () {
                        setState(() {
                          _targetSteps += 1000;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              _buildDropdownField(
                label: 'Satuan',
                value: _selectedUnit,
                items: ['Langkah', 'Meter', 'Kalori'],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedUnit = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              _buildDropdownField(
                label: 'Tenggat Waktu',
                value: _selectedPeriod,
                items: ['Setiap hari', 'Setiap minggu', 'Setiap bulan'],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedPeriod = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              _buildDropdownField(
                label: 'Mulai',
                value: _startDate,
                items: ['21 Mei 2024', '22 Mei 2024', '23 Mei 2024'],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _startDate = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              _buildDropdownField(
                label: 'Pengingat',
                value: _reminderTime,
                items: ['07:00', '08:00', '09:00', '10:00'],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _reminderTime = val;
                    });
                  }
                },
              ),
              const SizedBox(height: 16),

              // Switch reminder row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Aktifkan Pengingat',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A34),
                      ),
                    ),
                    Switch(
                      value: _isReminderActive,
                      activeThumbColor: Colors.white,
                      activeTrackColor: const Color(0xFF0EAD69),
                      inactiveThumbColor: const Color(0xFF9CB1AC),
                      inactiveTrackColor: const Color(0xFFE2EBE8),
                      onChanged: (val) {
                        setState(() {
                          _isReminderActive = val;
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Simpan Button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Perubahan berhasil disimpan!'),
                        backgroundColor: Color(0xFF0EAD69),
                      ),
                    );
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0EAD69),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Simpan',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Hapus Tujuan link
              Center(
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Tujuan dihapus.'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                    Navigator.pop(context);
                  },
                  child: const Text(
                    'Hapus Tujuan',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          style: const TextStyle(color: Color(0xFF1E3A34), fontSize: 14, fontWeight: FontWeight.w600),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B807B)),
          decoration: InputDecoration(
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0EAD69), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2EBE8), width: 1.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ],
    );
  }
}
