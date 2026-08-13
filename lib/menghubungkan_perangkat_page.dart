import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'models/sesi_makan.dart';
import 'pemindaian_perangkat_page.dart';
import 'services/izin_ble.dart';
import 'utils/format_waktu.dart';

class MenghubungkanPerangkatPage extends StatelessWidget {
  const MenghubungkanPerangkatPage({super.key, this.izin});

  /// Diteruskan apa adanya ke [PemindaianPerangkatPage]; null berarti
  /// `izinBleBawaan`. Ada di sini hanya supaya alur pemasangan bisa dites tanpa
  /// saluran platform izin — lihat catatannya di halaman pemindaian.
  final IzinBle? izin;

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
              // Status jam apa adanya: tersambung, baterai, sinkronisasi
              // terakhir, dan berapa sampel yang masih tertahan di buffer jam
              // (§4.7).
              _StatusJam(izin: izin),
              const SizedBox(height: 20),

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
                text: 'Nyalakan perangkat AsaWatch',
              ),
              _buildInstructionStep(
                stepNumber: '3',
                text: 'Buka aplikasi dan masuk ke menu Status Perangkat',
              ),
              _buildInstructionStep(
                stepNumber: '4',
                text: 'Tekan "Pindai & Sambungkan", lalu pilih AsaWatch X1',
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

/// Tombol pemasangan jam di bawah kartu status.
///
/// Bentuknya mengikuti status: jam yang belum pernah dipasangkan hanya perlu
/// satu ajakan memindai, sedangkan jam yang sudah dipasangkan butuh jalan
/// keluar (putus/ganti). Semua jalur menuju [PemindaianPerangkatPage] — tidak
/// ada penyambungan diam-diam di halaman ini.
class _AksiPerangkat extends StatelessWidget {
  const _AksiPerangkat({required this.status, this.izin});

  final StatusPerangkat status;
  final IzinBle? izin;

  Future<void> _bukaPemindaian(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final nama = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => PemindaianPerangkatPage(izin: izin)),
    );
    if (nama == null) return; // user mundur tanpa menyambung

    messenger.showSnackBar(
      SnackBar(
        content: Text('Tersambung ke $nama'),
        backgroundColor: const Color(0xFF0EAD69),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SesiMakanController>();

    if (!status.tersambung) {
      return SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          onPressed: () => _bukaPemindaian(context),
          icon: const Icon(Icons.bluetooth_searching_rounded, size: 18),
          label: Text(
            status.belumDipasangkan ? 'Pindai & Sambungkan' : 'Sambungkan Ulang',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0EAD69),
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 13),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: OutlinedButton(
            onPressed: () => _bukaPemindaian(context),
            style: _gayaGaris(const Color(0xFF0EAD69)),
            child: const Text(
              'Ganti Perangkat',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton(
            onPressed: controller.putuskanPerangkat,
            style: _gayaGaris(const Color(0xFF8FA7A1)),
            child: const Text(
              'Putuskan',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  ButtonStyle _gayaGaris(Color warna) => OutlinedButton.styleFrom(
    foregroundColor: warna,
    padding: const EdgeInsets.symmetric(vertical: 12),
    side: const BorderSide(color: Color(0xFFE2EBE8), width: 1.2),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
  );
}

/// Kartu status jam: tersambung, baterai, sinkronisasi terakhir, dan jumlah
/// sampel yang masih tertahan di buffer jam (§4.7).
///
/// Angkanya dibaca dari `SesiMakanController`, bukan literal — sampel yang
/// tertahan adalah alasan sah kenapa data sesi bisa datang terlambat (§8).
class _StatusJam extends StatelessWidget {
  const _StatusJam({this.izin});

  final IzinBle? izin;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SesiMakanController>();
    final status = controller.statusPerangkat;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: status.tersambung
                      ? const Color(0xFFE2F6F0)
                      : const Color(0xFFE2EBE8),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(
                  status.tersambung
                      ? Icons.watch_rounded
                      : Icons.watch_off_rounded,
                  color: status.tersambung
                      ? const Color(0xFF0EAD69)
                      : const Color(0xFF8FA7A1),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status.tersambung
                          ? 'Jam Tersambung'
                          : status.belumDipasangkan
                          ? 'Belum Ada Jam'
                          : 'Jam Terputus',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A34),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      status.namaPerangkat ?? 'Belum ada perangkat dipasangkan',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF6B807B),
                      ),
                    ),
                    Text(
                      status.sinkronTerakhir == null
                          ? 'Belum pernah sinkron'
                          : 'Sinkron terakhir '
                                '${formatWaktuRelatif(status.sinkronTerakhir!)}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF7E9A94),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                // Menyinkronkan jam yang putus tidak mungkin — buffer-nya baru
                // bisa ditarik setelah tersambung lagi.
                onPressed: status.tersambung ? controller.sinkronkan : null,
                icon: const Icon(Icons.sync_rounded, size: 14),
                label: const Text(
                  'Sinkronkan',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EAD69),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _petak(
                label: 'Baterai',
                nilai: status.baterai == null
                    ? tandaKosong
                    : '${status.baterai}%',
              ),
              const SizedBox(width: 12),
              _petak(
                label: 'Sampel tertunda',
                nilai: '${status.sampelTertunda}',
                keterangan: status.sampelTertunda > 0
                    ? 'menunggu disinkronkan'
                    : 'buffer jam kosong',
              ),
            ],
          ),
          const SizedBox(height: 14),
          _AksiPerangkat(status: status, izin: izin),
        ],
      ),
    );
  }

  Widget _petak({
    required String label,
    required String nilai,
    String? keterangan,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFF4FAF7),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF8FA7A1)),
            ),
            const SizedBox(height: 4),
            Text(
              nilai,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A34),
              ),
            ),
            if (keterangan != null) ...[
              const SizedBox(height: 2),
              Text(
                keterangan,
                style: const TextStyle(
                  fontSize: 9,
                  color: Color(0xFF9CB1AC),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
