import 'package:flutter/material.dart';

class RiwayatItem {
  final DateTime dateTime;
  final String type;
  final String value;
  final String status;
  final bool isNormal;

  RiwayatItem({
    required this.dateTime,
    required this.type,
    required this.value,
    required this.status,
    required this.isNormal,
  });
}

class RiwayatTab extends StatefulWidget {
  const RiwayatTab({super.key});

  @override
  State<RiwayatTab> createState() => _RiwayatTabState();
}

class _RiwayatTabState extends State<RiwayatTab> {
  String _selectedFilter = 'Semua';
  List<RiwayatItem> _allRiwayat = [];

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    _allRiwayat = [
      RiwayatItem(
        dateTime: DateTime(today.year, today.month, today.day, 8, 0),
        type: 'Detak Jantung',
        value: '78 bpm',
        status: 'Normal',
        isNormal: true,
      ),
      RiwayatItem(
        dateTime: DateTime(today.year, today.month, today.day, 8, 0),
        type: 'Gula Darah',
        value: '112 mg/dL',
        status: 'Normal',
        isNormal: true,
      ),
      RiwayatItem(
        dateTime: DateTime(today.year, today.month, today.day, 8, 0),
        type: 'Tekanan Darah',
        value: '118/78 mmHg',
        status: 'Normal',
        isNormal: true,
      ),
      RiwayatItem(
        dateTime: DateTime(today.year, today.month, today.day, 6, 0),
        type: 'Detak Jantung',
        value: '82 bpm',
        status: 'Normal',
        isNormal: true,
      ),
      RiwayatItem(
        dateTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 20, 0),
        type: 'Detak Jantung',
        value: '95 bpm',
        status: 'Normal',
        isNormal: true,
      ),
      RiwayatItem(
        dateTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 18, 0),
        type: 'Tekanan Darah',
        value: '125/82 mmHg',
        status: 'Sedikit Tinggi',
        isNormal: false,
      ),
      RiwayatItem(
        dateTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 12, 0),
        type: 'Gula Darah',
        value: '140 mg/dL',
        status: 'Tinggi',
        isNormal: false,
      ),
      RiwayatItem(
        dateTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 8, 0),
        type: 'Detak Jantung',
        value: '75 bpm',
        status: 'Normal',
        isNormal: true,
      ),
    ];
  }

  List<RiwayatItem> get _filteredRiwayat {
    if (_selectedFilter == 'Semua') {
      return _allRiwayat;
    }
    return _allRiwayat.where((item) => item.type == _selectedFilter).toList();
  }

  String _formatDate(DateTime dt) {
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
    return '${dt.day} ${months[dt.month]} ${dt.year}';
  }

  String _formatMonthYear(DateTime dt) {
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
    return '${months[dt.month]} ${dt.year}';
  }

  void _showFilterBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Filter Riwayat',
                    style: TextStyle(
                      fontSize: 18,
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
              const SizedBox(height: 16),
              const Text(
                'Kategori Kesehatan',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7E9A94),
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildFilterChip('Semua'),
                  _buildFilterChip('Detak Jantung'),
                  _buildFilterChip('Gula Darah'),
                  _buildFilterChip('Tekanan Darah'),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _selectedFilter == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = label;
        });
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF0EAD69) : const Color(0xFFE5EDE9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF6B807B),
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    // Pisahkan item yang sudah difilter menjadi Hari Ini dan Kemarin
    final filtered = _filteredRiwayat;
    final todayItems = filtered.where((item) {
      final date = DateTime(item.dateTime.year, item.dateTime.month, item.dateTime.day);
      return date.isAtSameMomentAs(today);
    }).toList();

    final yesterdayItems = filtered.where((item) {
      final date = DateTime(item.dateTime.year, item.dateTime.month, item.dateTime.day);
      return date.isAtSameMomentAs(yesterday);
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Riwayat Kesehatan',
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
            // Month selector Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatMonthYear(now),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A34),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showFilterBottomSheet,
                  icon: const Icon(Icons.filter_list_rounded, color: Color(0xFF0EAD69), size: 18),
                  label: Text(
                    _selectedFilter == 'Semua' ? 'Filter' : _selectedFilter,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0EAD69),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            if (todayItems.isNotEmpty) ...[
              // Today's Date header label
              Text(
                'Hari Ini - ${_formatDate(now)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7E9A94),
                ),
              ),
              const SizedBox(height: 12),
              ...todayItems.map((item) {
                final timeStr = '${item.dateTime.hour.toString().padLeft(2, '0')}:${item.dateTime.minute.toString().padLeft(2, '0')}';
                return _buildHistoryItem(
                  time: timeStr,
                  type: item.type,
                  value: item.value,
                  status: item.status,
                  isNormal: item.isNormal,
                );
              }),
              const SizedBox(height: 12),
            ],

            if (yesterdayItems.isNotEmpty) ...[
              // Yesterday's Date header label
              Text(
                'Kemarin - ${_formatDate(yesterday)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF7E9A94),
                ),
              ),
              const SizedBox(height: 12),
              ...yesterdayItems.map((item) {
                final timeStr = '${item.dateTime.hour.toString().padLeft(2, '0')}:${item.dateTime.minute.toString().padLeft(2, '0')}';
                return _buildHistoryItem(
                  time: timeStr,
                  type: item.type,
                  value: item.value,
                  status: item.status,
                  isNormal: item.isNormal,
                );
              }),
            ],

            if (todayItems.isEmpty && yesterdayItems.isEmpty)
              Container(
                height: 250,
                alignment: Alignment.center,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.history_toggle_off_rounded,
                      size: 64,
                      color: const Color(0xFF7E9A94).withValues(alpha: 0.5),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Tidak ada riwayat untuk filter ini',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7E9A94),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildHistoryItem({
    required String time,
    required String type,
    required String value,
    required String status,
    required bool isNormal,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isNormal ? const Color(0xFFE2F6F0) : const Color(0xFFFFEBEE),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  type == 'Detak Jantung'
                      ? Icons.favorite_rounded
                      : type == 'Gula Darah'
                          ? Icons.water_drop_rounded
                          : Icons.speed_rounded,
                  color: isNormal ? const Color(0xFF0EAD69) : Colors.red,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    type,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A34),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    time,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF8FA7A1),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                status,
                style: TextStyle(
                  fontSize: 11,
                  color: isNormal ? const Color(0xFF0EAD69) : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
