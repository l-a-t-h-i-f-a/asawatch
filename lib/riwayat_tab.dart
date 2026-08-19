import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'models/sesi_makan.dart';
import 'ringkasan_sesi_page.dart';
import 'utils/format_waktu.dart';
import 'utils/ikon.dart';
import 'widgets/foto_makanan.dart';
import 'widgets/lencana_kualitas.dart';

/// Riwayat mendaftar **sesi**, bukan pembacaan tunggal (§4.2).
///
/// Gula darah 140 tanpa konteks "1 jam setelah makan 45 g karbohidrat" tidak
/// bermakna, jadi pembacaan per metrik kini menjadi isi di dalam sesi —
/// dibuka lewat `RingkasanSesiPage` — bukan entri sejajar. Filternya pun
/// bergeser dari per-metrik menjadi per waktu makan dan per kualitas respons.
class RiwayatTab extends StatefulWidget {
  const RiwayatTab({super.key});

  @override
  State<RiwayatTab> createState() => _RiwayatTabState();
}

class _RiwayatTabState extends State<RiwayatTab> {
  WaktuMakan? _filterWaktu; // null = semua
  KualitasRespons? _filterKualitas; // null = semua

  bool get _adaFilter => _filterWaktu != null || _filterKualitas != null;

  String get _labelFilter {
    final bagian = <String>[
      if (_filterWaktu != null) _filterWaktu!.label,
      if (_filterKualitas != null) _filterKualitas!.label,
    ];
    return bagian.isEmpty ? 'Filter' : bagian.join(' · ');
  }

  List<SesiMakan> _saring(List<SesiMakan> semua) {
    return semua.where((s) {
      // Sesi berwaktu tidak pasti punya `waktuMakan` null, jadi ia jatuh dari
      // setiap filter waktu makan dengan sendirinya (protokol §4.3) — dan tetap
      // terlihat selama filter itu tidak dipasang.
      if (_filterWaktu != null && s.waktuMakan != _filterWaktu) return false;
      if (_filterKualitas != null && s.kualitasRespons != _filterKualitas) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Kelompokkan per tanggal, urut terbaru lebih dulu.
  Map<DateTime, List<SesiMakan>> _kelompokkan(List<SesiMakan> sesi) {
    final peta = <DateTime, List<SesiMakan>>{};
    for (final s in sesi) {
      final waktu = s.t0 ?? s.waktuFoto;
      final hari = DateTime(waktu.year, waktu.month, waktu.day);
      peta.putIfAbsent(hari, () => []).add(s);
    }
    return peta;
  }

  String _labelHari(DateTime hari, DateTime sekarang) {
    final hariIni = DateTime(sekarang.year, sekarang.month, sekarang.day);
    final selisih = hariIni.difference(hari).inDays;
    if (selisih == 0) return 'Hari Ini - ${formatTanggal(hari)}';
    if (selisih == 1) return 'Kemarin - ${formatTanggal(hari)}';
    return formatTanggal(hari);
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
                    'Filter Sesi',
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
                'Waktu Makan',
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
                  _chipWaktu(null, 'Semua'),
                  for (final w in WaktuMakan.values) _chipWaktu(w, w.label),
                ],
              ),
              const SizedBox(height: 20),
              const Text(
                'Kualitas Respons',
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
                  _chipKualitas(null, 'Semua'),
                  for (final k in KualitasRespons.values)
                    _chipKualitas(k, k.label),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }

  Widget _chipWaktu(WaktuMakan? nilai, String label) {
    return _chip(
      label,
      _filterWaktu == nilai,
      () {
        setState(() => _filterWaktu = nilai);
        Navigator.pop(context);
      },
      ikon: nilai == null ? Icons.done_all_rounded : ikonWaktuMakan(nilai),
    );
  }

  Widget _chipKualitas(KualitasRespons? nilai, String label) {
    return _chip(
      label,
      _filterKualitas == nilai,
      () {
        setState(() => _filterKualitas = nilai);
        Navigator.pop(context);
      },
      ikon: nilai == null ? Icons.done_all_rounded : ikonKualitasRespons(nilai),
    );
  }

  Widget _chip(
    String label,
    bool terpilih,
    VoidCallback onTap, {
    IconData? ikon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: terpilih ? const Color(0xFF0EAD69) : const Color(0xFFE5EDE9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (ikon != null) ...[
              Icon(
                ikon,
                size: 14,
                color: terpilih ? Colors.white : const Color(0xFF6B807B),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: terpilih ? Colors.white : const Color(0xFF6B807B),
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SesiMakanController>();
    final now = DateTime.now();
    final tersaring = _saring(controller.riwayat);
    final kelompok = _kelompokkan(tersaring);
    final hariUrut = kelompok.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Riwayat Sesi',
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Icon(
                  Icons.event_note_rounded,
                  size: 18,
                  color: Color(0xFF0EAD69),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    tersaring.length == 1
                        ? '1 sesi'
                        : '${tersaring.length} sesi',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A34),
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _showFilterBottomSheet,
                  icon: const Icon(
                    Icons.filter_list_rounded,
                    color: Color(0xFF0EAD69),
                    size: 18,
                  ),
                  label: Text(
                    _labelFilter,
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

            for (final hari in hariUrut) ...[
              Row(
                children: [
                  const Icon(
                    Icons.calendar_today_rounded,
                    size: 12,
                    color: Color(0xFF9CB1AC),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _labelHari(hari, now),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF7E9A94),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (final sesi in kelompok[hari]!) _EntriSesi(sesi: sesi),
              const SizedBox(height: 12),
            ],

            if (tersaring.isEmpty)
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
                    Text(
                      _adaFilter
                          ? 'Tidak ada sesi untuk filter ini'
                          : 'Belum ada sesi yang selesai',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF7E9A94),
                      ),
                    ),
                    if (_adaFilter) ...[
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => setState(() {
                          _filterWaktu = null;
                          _filterKualitas = null;
                        }),
                        child: const Text(
                          'Hapus filter',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0EAD69),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),

            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

/// Satu baris daftar: thumbnail foto · nama & kalori · indikator respons ·
/// waktu (§4.2).
class _EntriSesi extends StatelessWidget {
  const _EntriSesi({required this.sesi});

  final SesiMakan sesi;

  @override
  Widget build(BuildContext context) {
    final waktu = sesi.t0 ?? sesi.waktuFoto;
    final kalori = sesi.kalori;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => RingkasanSesiPage(sesi: sesi)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
        ),
        child: Row(
          children: [
            FotoMakanan(fotoPath: sesi.fotoPath, lebar: 48, tinggi: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    sesi.hasil?.ringkasanNama ?? 'Makanan',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A34),
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Icon(
                        ikonWaktuMakan(sesi.waktuMakan),
                        size: 12,
                        color: const Color(0xFF8FA7A1),
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          [
                            // Disebut lebih dulu, bukan diselipkan di ujung:
                            // seluruh sisa baris ini adalah angka, dan pembaca
                            // harus tahu angka siapa sebelum membacanya.
                            if (sesi.sesiUji) 'SESI UJI',
                            sesi.labelWaktuMakan,
                            // Nutrisi yang belum dianalisis ditulis apa
                            // adanya (§8).
                            kalori == null
                                ? 'nutrisi $tandaKosong'
                                : '${formatAngka(kalori)} kcal',
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF8FA7A1),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LencanaKualitas(kualitas: sesi.kualitasRespons),
                const SizedBox(height: 4),
                Text(
                  formatJam(waktu),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8FA7A1),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
