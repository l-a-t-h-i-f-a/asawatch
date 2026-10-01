import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'models/sesi_makan.dart';
import 'services/pengingat_titik_ukur.dart';
import 'sesi_berjalan_page.dart';

/// Layar yang dibuka alarm titik ukur — satu pertanyaan, satu tombol.
///
/// **Konfirmasinya berarti "jam sudah dipakai", dan hanya itu yang membungkam
/// alarm.** Aplikasi tidak bisa tahu sendiri apakah jam menempel di kulit:
/// jam yang tergeletak di meja tetap tersambung, dan protokol tidak membawa
/// tanda "terpakai". Jadi yang ditanyakan adalah orangnya.
///
/// Sengaja **tanpa tombol tunda**: titik ukur punya jendela beberapa menit,
/// dan tundaan adalah cara paling mudah melewatkannya. Menekan tombolnya
/// sekaligus menyuruh jam mengukur, lalu layar berganti ke Sesi Berjalan,
/// tempat kemajuan pengukuran dan alasan bila jam belum bisa mengukur sudah
/// ditulis.
class KonfirmasiPakaiJamPage extends StatefulWidget {
  const KonfirmasiPakaiJamPage({super.key, required this.alarm});

  final AlarmTitik alarm;

  /// Apakah [alarm] masih menunjuk titik yang perlu diukur: sesinya masih
  /// yang berjalan, dan sampel titiknya masih kosong.
  static bool masihPerlu(SesiMakan? sesi, AlarmTitik alarm) =>
      sesi != null &&
      sesi.status.sedangAktif &&
      sesi.id == alarm.sesiId &&
      sesi.sampel.any(
        (s) => s.index == alarm.index && s.status == StatusSampel.menunggu,
      );

  @override
  State<KonfirmasiPakaiJamPage> createState() => _KonfirmasiPakaiJamPageState();
}

class _KonfirmasiPakaiJamPageState extends State<KonfirmasiPakaiJamPage> {
  bool _mengirim = false;

  @override
  void initState() {
    super.initState();
    // Alarm basi tidak punya tombol konfirmasi untuk membungkamnya, jadi ia
    // dibungkam di sini — laci notifikasi tidak boleh terus berbunyi untuk
    // titik yang sudah terisi.
    final c = context.read<SesiMakanController>();
    if (!KonfirmasiPakaiJamPage.masihPerlu(c.sesiAktif, widget.alarm)) {
      c.pengingat.hentikanAlarm(widget.alarm.index);
    }
  }

  Future<void> _konfirmasi() async {
    final c = context.read<SesiMakanController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _mengirim = true);

    final galat = await c.konfirmasiJamDipakai(widget.alarm.index);
    if (!mounted) return;

    navigator.pushReplacement(
      MaterialPageRoute(builder: (_) => const SesiBerjalanPage()),
    );
    // Jam yang belum tersambung atau baterainya kritis sudah diterangkan di
    // Sesi Berjalan; yang perlu disampaikan di sini hanya penolakan lainnya.
    if (galat != null && c.alasanJamTidakBisaUkur == null) {
      messenger.showSnackBar(SnackBar(content: Text(galat)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<SesiMakanController>();
    final sesi = c.sesiAktif;
    final perlu = KonfirmasiPakaiJamPage.masihPerlu(sesi, widget.alarm);
    final label = sesi?.jadwal.titik
        .where((t) => t.index == widget.alarm.index)
        .map((t) => t.label)
        .firstOrNull;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A34)),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: perlu
              ? _Pertanyaan(
                  label: label,
                  mengirim: _mengirim,
                  onKonfirmasi: _konfirmasi,
                )
              : const _TidakPerluLagi(),
        ),
      ),
    );
  }
}

class _Pertanyaan extends StatelessWidget {
  const _Pertanyaan({
    required this.label,
    required this.mengirim,
    required this.onKonfirmasi,
  });

  final String? label;
  final bool mengirim;
  final VoidCallback onKonfirmasi;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        Center(
          child: Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(
              color: Color(0xFFE2F6F0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.watch_rounded,
              size: 56,
              color: Color(0xFF0EAD69),
            ),
          ),
        ),
        const SizedBox(height: 28),
        if (label != null)
          Text(
            'PENGUKURAN ${label!.toUpperCase()}',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: Color(0xFF7E9A94),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'Pakai jam di pergelangan',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E3A34),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Pasang jam dengan rapat, lalu tekan tombol di bawah. Alarm '
          'berhenti dan jam langsung mengukur.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 15,
            height: 1.45,
            color: Color(0xFF6B807B),
          ),
        ),
        const Spacer(flex: 2),
        SizedBox(
          height: 60,
          child: ElevatedButton(
            onPressed: mengirim ? null : onKonfirmasi,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0EAD69),
              foregroundColor: Colors.white,
              disabledBackgroundColor: const Color(0xFFC7DAD5),
              disabledForegroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: mengirim
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Oke, Jam Sudah Dipakai',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
          ),
        ),
      ],
    );
  }
}

/// Alarm yang diketuk setelah titiknya terisi atau sesinya berakhir — dari
/// laci notifikasi, atau dari peluncuran yang terlambat.
class _TidakPerluLagi extends StatelessWidget {
  const _TidakPerluLagi();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Spacer(),
        const Icon(
          Icons.check_circle_rounded,
          size: 72,
          color: Color(0xFF0EAD69),
        ),
        const SizedBox(height: 20),
        const Text(
          'Pengukuran ini sudah tidak perlu',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: Color(0xFF1E3A34),
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Titiknya sudah terisi, atau sesinya sudah berakhir.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15, color: Color(0xFF6B807B)),
        ),
        const Spacer(flex: 2),
        SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF1E3A34),
              side: const BorderSide(color: Color(0xFFE2EBE8), width: 1.5),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text(
              'Tutup',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
