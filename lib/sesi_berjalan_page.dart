import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'models/sesi_makan.dart';
import 'ringkasan_sesi_page.dart';
import 'utils/format_waktu.dart';
import 'widgets/foto_makanan.dart';
import 'widgets/petunjuk_tombol_jam.dart';
import 'widgets/ringkasan_nutrisi.dart';
import 'widgets/timeline_sampel.dart';

/// Tampilan penuh sesi aktif (§5): timeline 4 titik, foto, nutrisi, status
/// jam, dan opsi membatalkan sesi.
///
/// Halaman ini mengikuti `SesiMakanController` karena sampel bisa masuk dari
/// BLE kapan saja (§12.7). Bila sesi selesai selagi halaman terbuka, isinya
/// berganti menjadi pintu ke `RingkasanSesiPage`, bukan layar kosong.
///
/// Catatan test: hitung mundur memakai `Timer.periodic`, jadi selama masih ada
/// titik yang ditunggu gunakan `tester.pump(...)`, bukan `pumpAndSettle`.
class SesiBerjalanPage extends StatelessWidget {
  const SesiBerjalanPage({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SesiMakanController>();
    final sesi = controller.sesiAktif;

    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A34)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Sesi Berjalan',
          style: TextStyle(
            color: Color(0xFF1E3A34),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: sesi == null
          ? _SesiSudahBerakhir(controller: controller)
          : _IsiSesi(sesi: sesi, controller: controller),
    );
  }
}

class _IsiSesi extends StatelessWidget {
  const _IsiSesi({required this.sesi, required this.controller});

  final SesiMakan sesi;
  final SesiMakanController controller;

  @override
  Widget build(BuildContext context) {
    final t0 = sesi.t0;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusPerangkatBar(perangkat: controller.statusPerangkat),
          const SizedBox(height: 16),

          // Timeline 4 titik — inti layar ini.
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    Row(
                      children: const [
                        Icon(
                          Icons.timeline_rounded,
                          size: 18,
                          color: Color(0xFF0EAD69),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Titik Pengukuran',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A34),
                          ),
                        ),
                      ],
                    ),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2F6F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          sesi.status.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF0EAD69),
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TimelineSampel(
                  sampel: sesi.sampel,
                  t0: t0,
                  indexBerikutnya: sesi.sampelBerikutnya?.index,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Foto makanan tetap terlihat sepanjang jeda 2 jam (§8).
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    FotoMakanan(fotoPath: sesi.fotoPath, lebar: 64, tinggi: 64),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sesi.hasil?.ringkasanNama ?? 'Makanan',
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1E3A34),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            t0 == null
                                ? 'Difoto ${formatJam(sesi.waktuFoto)}'
                                : 'Selesai makan ${formatJam(t0)}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF8FA7A1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                RingkasanNutrisi(hasil: sesi.hasil),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Kejujuran soal keterlambatan data (§8).
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFE8F8F5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: const [
                Icon(
                  Icons.info_outline_rounded,
                  color: Color(0xFF0EAD69),
                  size: 18,
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Jam menyimpan sampel di buffer. Data bisa datang '
                    'terlambat — sesi tidak gagal hanya karena telat.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF6B807B)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (sesi.t0 == null) ...[
            PetunjukTombolJam(
              status: sesi.status,
              perangkat: controller.statusPerangkat,
            ),
            const SizedBox(height: 12),
          ],

          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => _konfirmasiBatal(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Color(0xFFE2EBE8), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.stop_circle_outlined, size: 18),
                  SizedBox(width: 8),
                  Text(
                    'Batalkan Sesi',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _konfirmasiBatal(BuildContext context) async {
    final navigator = Navigator.of(context);
    final jadi = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Batalkan sesi ini?',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        content: const Text(
          'Sampel yang belum masuk tidak akan dikumpulkan lagi dan sesi ini '
          'tidak dihitung dalam analisis.',
          style: TextStyle(fontSize: 13, color: Color(0xFF6B807B)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Lanjutkan Sesi',
              style: TextStyle(
                color: Color(0xFF6B807B),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Batalkan',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (jadi != true) return;
    await controller.batalkan();
    navigator.pop(true);
  }
}

/// Sesi kelar selagi halaman ini terbuka — arahkan ke hasilnya, jangan
/// tinggalkan layar kosong.
class _SesiSudahBerakhir extends StatelessWidget {
  const _SesiSudahBerakhir({required this.controller});

  final SesiMakanController controller;

  @override
  Widget build(BuildContext context) {
    final sesi = controller.hasilBelumDibaca ?? controller.sesiTerakhir;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.check_circle_outline_rounded,
              size: 56,
              color: Color(0xFF0EAD69),
            ),
            const SizedBox(height: 16),
            Text(
              sesi == null ? 'Tidak ada sesi berjalan' : 'Sesi sudah berakhir',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A34),
              ),
            ),
            if (sesi != null) ...[
              const SizedBox(height: 8),
              Text(
                sesi.verdict,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF6B807B),
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  controller.tandaiHasilDibaca();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => RingkasanSesiPage(sesi: sesi),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EAD69),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Lihat Ringkasan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Status jam apa adanya: tersambung, baterai, dan jumlah sampel yang masih
/// tertahan di buffer jam (§4.1, §4.7).
class StatusPerangkatBar extends StatelessWidget {
  const StatusPerangkatBar({super.key, this.perangkat});

  final StatusPerangkat? perangkat;

  @override
  Widget build(BuildContext context) {
    final p = perangkat;
    final tersambung = p?.tersambung ?? false;
    final keterangan = <String>[
      tersambung ? 'Jam tersambung' : 'Jam terputus',
      if (p?.baterai != null) 'baterai ${p!.baterai}%',
      if ((p?.sampelTertunda ?? 0) > 0) '${p!.sampelTertunda} sampel tertunda',
    ];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
      ),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: tersambung
                  ? const Color(0xFFE2F6F0)
                  : const Color(0xFFE2EBE8),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(
              tersambung ? Icons.watch_rounded : Icons.watch_off_rounded,
              size: 18,
              color: tersambung
                  ? const Color(0xFF0EAD69)
                  : const Color(0xFF8FA7A1),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              keterangan.join(' · '),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E3A34),
              ),
            ),
          ),
          if (p?.sinkronTerakhir != null)
            Text(
              'sinkron ${formatWaktuRelatif(p!.sinkronTerakhir!)}',
              style: const TextStyle(fontSize: 10, color: Color(0xFF8FA7A1)),
            ),
        ],
      ),
    );
  }
}
