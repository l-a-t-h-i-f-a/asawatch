import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'models/sesi_makan.dart';
import 'pemindaian_perangkat_page.dart';
import 'services/izin_ble.dart';
import 'utils/format_waktu.dart';
import 'widgets/tombol_sinkron.dart';

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
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFFE2EBE8),
                      width: 1.2,
                    ),
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
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A34),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '2. Nyalakan Perangkat',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A34),
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              '3. Hubungkan di Aplikasi',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E3A34),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),

                // Langkah-langkah pemasangan — docs/alur-pemasangan-jam.md §4.1.
                //
                // Penyandingan berdiri sebagai langkah tersendiri, bukan
                // tersembunyi di dalam "tunggu sampai selesai". Ia satu-satunya
                // langkah yang menuntut tindakan pengguna, dan sebelumnya ialah
                // yang paling sering menghentikan pemasangan tanpa penjelasan.
                _buildInstructionStep(
                  stepNumber: '1',
                  text: 'Pastikan Bluetooth ponsel aktif',
                ),
                _buildInstructionStep(
                  stepNumber: '2',
                  text: 'Nyalakan jam AsaWatch Anda',
                ),
                _buildInstructionStep(
                  stepNumber: '3',
                  text: 'Dekatkan jam ke ponsel, dalam jarak satu meter',
                ),
                _buildInstructionStep(
                  stepNumber: '4',
                  text: 'Ketuk "Pindai & Sambungkan", lalu pilih AsaWatch X1',
                ),
                // Kata "Sandingkan" harus sama persis dengan tombol di dialog
                // sistem (§2): pengguna yang membaca kata lain di sini akan
                // mengira dialog itu sesuatu yang berbeda, lalu menolaknya.
                _buildInstructionStep(
                  stepNumber: '5',
                  text:
                      'Saat diminta, ketuk "Sandingkan". Tidak ada kode atau PIN '
                      'yang perlu dimasukkan',
                ),
                _buildInstructionStep(
                  stepNumber: '6',
                  text: 'Tunggu sampai muncul "Jam Tersambung"',
                ),

                const SizedBox(height: 16),

                // Tanpa kalimat ini, pemasangan yang terasa berbelit terbaca
                // sebagai sesuatu yang harus diulang setiap kali makan.
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle_outline_rounded,
                        size: 18,
                        color: Color(0xFF0EAD69),
                      ),
                      SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Pemasangan ini hanya dilakukan sekali. Setelah itu jam '
                          'tersambung sendiri setiap kali berada di dekat ponsel.',
                          style: TextStyle(
                            fontSize: 13,
                            color: Color(0xFF1E3A34),
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),

                // Bottom assistance green banner
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8F5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFD0EBE0),
                      width: 1,
                    ),
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

  /// Melepas pemasangan, setelah user menyatakan ia memang memaksudkannya.
  ///
  /// Dikonfirmasi karena akibatnya tidak terlihat dan tidak bisa dibatalkan:
  /// sampel yang masih menunggu di buffer jam **tidak akan pernah sampai**
  /// setelah tidak ada lagi yang menyambunginya. Jumlahnya disebut apa adanya —
  /// "beberapa data akan hilang" tidak cukup untuk memutuskan.
  Future<void> _konfirmasiLupakan(BuildContext context) async {
    final controller = context.read<SesiMakanController>();
    final messenger = ScaffoldMessenger.of(context);
    final nama = status.namaPerangkat ?? 'jam ini';
    final tertunda = status.sampelTertunda;
    final adaSesi = controller.sesiAktif != null;

    final yakin = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        title: Text(
          'Lupakan $nama?',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        content: Text(
          [
            'Jam akan dilepas dari ponsel ini, dan harus disandingkan lagi dari '
                'awal bila nanti dipakai kembali.',
            if (tertunda > 0)
              '$tertunda data yang masih tersimpan di jam belum sempat '
                  'dipindahkan, dan tidak akan bisa diambil lagi.',
            if (adaSesi)
              'Sesi yang sedang berjalan akan kehilangan sisa pengukurannya.',
            'Riwayat yang sudah tersimpan tetap aman.',
          ].join('\n\n'),
          style: const TextStyle(
            fontSize: 15,
            color: Color(0xFF6B807B),
            height: 1.5,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Batal',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF6B807B),
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Lupakan',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFFC0392B),
              ),
            ),
          ),
        ],
      ),
    );
    if (yakin != true) return;

    await controller.lupakanPerangkat();
    messenger.showSnackBar(
      SnackBar(
        content: Text('$nama dilepas dari ponsel ini'),
        backgroundColor: const Color(0xFF6B807B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.read<SesiMakanController>();

    if (!status.tersambung) {
      return Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () => _bukaPemindaian(context),
              icon: const Icon(Icons.bluetooth_searching_rounded, size: 18),
              label: Text(
                switch ((status.belumDipasangkan, status.penyandinganHilang)) {
                  (true, _) => 'Pindai & Sambungkan',
                  // Penyandingannya hilang, jadi yang dibutuhkan bukan sekadar
                  // menyambung lagi — jamnya harus disandingkan dari awal, dan
                  // tombolnya mengatakan itu supaya tidak terasa seperti
                  // percobaan yang sama yang gagal berulang kali.
                  (false, true) => 'Sandingkan Ulang',
                  (false, false) => 'Sambungkan Ulang',
                },
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                ),
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
          ),
          // Melupakan jam hanya ditawarkan pada jam yang memang ada untuk
          // dilupakan. Pada layar "belum pernah dipasangkan" ia tidak punya
          // arti apa pun selain menambah satu tombol untuk salah ditekan.
          if (!status.belumDipasangkan) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => _konfirmasiLupakan(context),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF8FA7A1),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  'Lupakan Jam Ini',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      );
    }

    return Column(
      children: [
        Row(
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
        ),
        const SizedBox(height: 10),
        // Sengaja dipisahkan dari baris "Putuskan": keduanya terdengar mirip
        // tetapi hanya satu yang bisa dibatalkan. Yang permanen tidak boleh
        // berdampingan sebagai pilihan yang setara.
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: () => _konfirmasiLupakan(context),
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF8FA7A1),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
            child: const Text(
              'Lupakan Jam Ini',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
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
                          // Bukan "terputus": yang terputus menyambung sendiri,
                          // yang ini tidak akan pernah sampai disandingkan lagi.
                          : status.penyandinganHilang
                          ? 'Jam Tidak Tersandingkan'
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
                    // Baris ketiga bercerita tentang riwayat sinkronisasi satu
                    // jam tertentu. Tanpa jam, "Belum pernah sinkron" hanya
                    // menambah satu "belum" lagi di bawah dua yang sudah ada.
                    if (!status.belumDipasangkan)
                      Text(
                        // Sebabnya dikatakan, bukan hanya keadaannya: tanpa ini
                        // user melihat jam yang "tidak nyambung-nyambung" dan
                        // tidak punya alasan menduga bahwa yang dihapusnya di
                        // Pengaturan Bluetooth kemarinlah penyebabnya.
                        status.penyandinganHilang && !status.tersambung
                            ? 'Dihapus dari Bluetooth ponsel'
                            : status.sinkronTerakhir == null
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
              // Tanpa jam yang dipasangkan tidak ada apa pun untuk
              // disinkronkan, jadi tombolnya tidak ada — bukan ada tapi mati.
              // Tombol mati berarti "nanti bisa", dan di sini tidak ada
              // "nanti": yang dibutuhkan adalah memasang jam dulu, dan itu
              // sudah ditawarkan tombol Pindai & Sambungkan di bawah.
              if (!status.belumDipasangkan)
                TombolSinkron(aktif: status.tersambung),
            ],
          ),
          // Angka-angka ini semuanya milik sebuah jam. Kalau tidak ada jam yang
          // dipasangkan, angka apa pun di sini adalah kalimat tentang perangkat
          // yang tidak ada.
          //
          // Petak "tertunda" hanya muncul saat memang ada yang tertunda.
          // Sebelumnya ia selalu tampil, dan karena buffer ditarik otomatis di
          // setiap koneksi, isinya nyaris selalu "0 · buffer jam kosong": satu
          // petak yang seumur pemakaian menampilkan angka yang sama. Petak
          // berisi nol tidak menenangkan — ia mengundang pertanyaan apakah ada
          // yang rusak. Yang menenangkan sudah ada di atasnya, dan berubah
          // sungguhan: "Sinkron terakhir 2 menit lalu".
          if (!status.belumDipasangkan &&
              (status.baterai != null || status.sampelTertunda > 0)) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                // Baterai hanya ada selagi jam tersambung — `StatusPerangkat`
                // memastikan angkanya null begitu tautan putus. Petaknya ikut
                // hilang, bukan berisi tanda kosong: petak kosong masih terbaca
                // sebagai "aplikasi seharusnya tahu ini", padahal jam yang
                // terputus memang tidak bisa ditanya.
                if (status.baterai != null)
                  _petak(
                    label: 'Baterai',
                    nilai: '${status.baterai}%',
                    // Angka saja tidak memberitahu apa pun yang bisa
                    // ditindaklanjuti: "8%" dan "12%" terlihat sama-sama
                    // rendah, sedangkan di bawah 10% jam berhenti melayani
                    // seluruh perintah ukur (§5.5 bit2). Yang membedakan
                    // keduanya adalah jamnya sendiri, bukan pembacanya.
                    keterangan: status.bateraiKritis
                        ? 'jam menolak mengukur — isi daya'
                        : null,
                  ),
                if (status.baterai != null && status.sampelTertunda > 0)
                  const SizedBox(width: 12),
                if (status.sampelTertunda > 0)
                  _petak(
                    label: 'Data belum diambil',
                    nilai: '${status.sampelTertunda}',
                    keterangan: status.tersambung
                        ? 'sedang dipindahkan'
                        : 'menunggu jam didekatkan',
                  ),
              ],
            ),
          ],
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
                style: const TextStyle(fontSize: 9, color: Color(0xFF9CB1AC)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
