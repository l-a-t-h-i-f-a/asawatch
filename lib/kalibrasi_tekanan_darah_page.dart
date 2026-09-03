import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'models/sesi_makan.dart';
import 'services/ble_asli_service.dart' show GalatJam;
import 'utils/format_waktu.dart';

/// Kalibrasi tekanan darah (§5), dengan metode manset berulang yang sudah
/// dipakai alat sejenis (Samsung Health Monitor).
///
/// Bentuknya sebuah alur bertahap, bukan satu formulir, karena kalibrasi
/// bukan pengisian data melainkan **prosedur**: ada yang harus disiapkan
/// sebelum angka pertama muncul, ada dua alat yang harus jalan bersamaan, dan
/// ada jeda yang harus benar-benar ditunggu. Formulir yang menampilkan semuanya
/// sekaligus menyiratkan bahwa urutannya bebas.
///
/// Lima hal yang membedakannya dari versi satu-tembak sebelumnya:
///
/// 1. **Persiapan diminta lebih dulu dan pergelangannya dipilih.** Koreksi ini
///    hanya berlaku untuk tangan tempat jam dipakai saat mengukur.
/// 2. **Manset dipasang di lengan yang berlawanan dengan jam.** Bukan pilihan
///    kenyamanan: manset yang mengembang menyumbat aliran darah ke pergelangan
///    di bawahnya, sehingga jam di lengan yang sama tidak punya gelombang nadi
///    untuk dibaca justru pada detik yang sedang diukur.
/// 3. **Keduanya diukur bersamaan**, satu tombol menyalakan jam sementara user
///    menekan START tensimeter. Tekanan darah berubah dari menit ke menit;
///    dua pengukuran yang berjarak beberapa menit membandingkan dua keadaan
///    yang berbeda, dan selisihnya masuk ke koreksi sebagai kesalahan tetap.
///
///    Konsekuensinya angka tensimeter baru bisa diketik **setelah** jam
///    selesai. Karena itu **pembacaan jam disembunyikan sampai angka
///    tensimeter masuk**: melihat angka jam lebih dulu membuat orang "membetulkan"
///    angka yang diketiknya, dan koreksi yang lahir dari situ menipu diri
///    sendiri. Yang dulu dijaga oleh urutan, sekarang dijaga oleh tirai.
/// 4. **Jeda satu menit antar putaran**, dihitung mundur di layar. Manset yang
///    langsung dipompa ulang membaca terlalu tinggi.
/// 5. **Hasilnya boleh ditolak.** Bila ketiga putaran terlalu jauh berbeda
///    (`Kalibrasi.konsisten`), yang ditawarkan adalah mengulang — bukan
///    mengirim median dari angka yang saling bertentangan.
class KalibrasiTekananDarahPage extends StatefulWidget {
  const KalibrasiTekananDarahPage({super.key});

  @override
  State<KalibrasiTekananDarahPage> createState() =>
      _KalibrasiTekananDarahPageState();
}

enum _Tahap { persiapan, putaran, jeda, ringkasan }

class _KalibrasiTekananDarahPageState extends State<KalibrasiTekananDarahPage> {
  final _sistolik = TextEditingController();
  final _diastolik = TextEditingController();

  _Tahap _tahap = _Tahap.persiapan;
  SisiPergelangan? _sisi;

  final List<PutaranKalibrasi> _selesai = [];

  Sampel? _pembacaanJam;
  bool _sedangMengukur = false;
  bool _sedangMengirim = false;
  String? _galat;

  Timer? _jeda;
  int _sisaJeda = 0;

  @override
  void dispose() {
    _jeda?.cancel();
    _sistolik.dispose();
    _diastolik.dispose();
    super.dispose();
  }

  int? get _nilaiSistolik => int.tryParse(_sistolik.text.trim());
  int? get _nilaiDiastolik => int.tryParse(_diastolik.text.trim());

  String? get _galatReferensi => galatReferensiTensimeter(
    sistolik: _nilaiSistolik,
    diastolik: _nilaiDiastolik,
  );

  /// Angka tensimeter lengkap **dan** masuk akal. Keduanya syarat: jam tidak
  /// boleh diminta mengukur untuk dipasangkan dengan angka yang salah ketik.
  bool get _referensiSiap =>
      _nilaiSistolik != null &&
      _nilaiDiastolik != null &&
      _galatReferensi == null;

  /// Putaran ke berapa yang sedang berjalan, mulai dari 1.
  int get _nomorPutaran => _selesai.length + 1;

  PutaranKalibrasi? get _putaranIni {
    final jam = _pembacaanJam;
    if (!_referensiSiap ||
        jam == null ||
        jam.sistolik == null ||
        jam.diastolik == null) {
      return null;
    }
    return PutaranKalibrasi(
      sistolikReferensi: _nilaiSistolik!,
      diastolikReferensi: _nilaiDiastolik!,
      sistolikJam: jam.sistolik!,
      diastolikJam: jam.diastolik!,
    );
  }

  Kalibrasi? get _kalibrasi => _selesai.length < Kalibrasi.jumlahPutaran
      ? null
      : Kalibrasi(
          waktu: DateTime.now(),
          sisi: _sisi ?? SisiPergelangan.kiri,
          putaran: List.unmodifiable(_selesai),
        );

  // --- Perpindahan tahap --------------------------------------------------

  void _mulai() => setState(() {
    _selesai.clear();
    _bersihkanPutaran();
    _tahap = _Tahap.putaran;
  });

  void _bersihkanPutaran() {
    _sistolik.clear();
    _diastolik.clear();
    _pembacaanJam = null;
    _galat = null;
  }

  Future<void> _ukurDenganJam() async {
    final controller = context.read<SesiMakanController>();
    setState(() {
      _sedangMengukur = true;
      _galat = null;
      // Mengukur ulang berarti pasangannya juga baru. Angka tensimeter dari
      // pengukuran sebelumnya bukan lagi pasangan yang sezaman, dan justru
      // itulah satu-satunya syarat yang membuat selisihnya berarti.
      _pembacaanJam = null;
      _sistolik.clear();
      _diastolik.clear();
    });
    try {
      final sampel = await controller.ukurUntukKalibrasi();
      if (!mounted) return;
      setState(() {
        _pembacaanJam = sampel;
        // Sensor bisa gagal dan protokol menyatakannya dengan sentinel 0 →
        // null (§5.2). Diam saja di sini akan menampilkan "—" tanpa sebab.
        if (sampel.sistolik == null || sampel.diastolik == null) {
          _galat =
              'Jam tidak berhasil membaca tekanan darah. Rapatkan jam di '
              'pergelangan, diamkan tangan, lalu ukur lagi.';
        }
      });
    } on GalatJam catch (e) {
      if (mounted) setState(() => _galat = e.pesanPengguna);
    } catch (_) {
      if (mounted) {
        setState(() => _galat = 'Jam tidak menjawab. Coba ukur sekali lagi.');
      }
    } finally {
      if (mounted) setState(() => _sedangMengukur = false);
    }
  }

  /// Judul kartu selagi jam mengukur — tiga keadaan, tiga kalimat.
  ///
  /// Ketiganya lahir dari paket Status yang benar-benar tiba, karena "sedang
  /// mengukur" yang ditulis atas dasar perintah yang sudah dikirim akan tetap
  /// terpampang pada jam yang mati di tengah jalan.
  static String _judulMengukur(KemajuanUkur? kemajuan) => switch (kemajuan) {
    null => 'Menunggu jam mulai…',
    final k when k.macet => 'Jam belum menemukan nadi',
    _ => 'Jam sedang mengukur…',
  };

  static String _penjelasanMengukur(KemajuanUkur? kemajuan) =>
      switch (kemajuan) {
        null =>
          'Perintah sudah dikirim. Kalimat ini berubah begitu jam melapor '
              'bahwa ia mulai membaca.',
        final k when k.macet =>
          'Jam masih bekerja. Rapatkan jam di pergelangan dan diamkan tangan.',
        final k when k.sisaDetik != null =>
          'Diam, jangan bicara, kedua lengan tetap di meja. Perkiraan sisa '
              '±${k.sisaDetik} detik menurut jam.',
        _ => 'Diam, jangan bicara, kedua lengan tetap di meja.',
      };

  void _simpanPutaran() {
    final putaran = _putaranIni;
    if (putaran == null) return;

    setState(() {
      _selesai.add(putaran);
      _bersihkanPutaran();
      if (_selesai.length >= Kalibrasi.jumlahPutaran) {
        _tahap = _Tahap.ringkasan;
      } else {
        _tahap = _Tahap.jeda;
        _mulaiHitungMundur();
      }
    });
  }

  void _mulaiHitungMundur() {
    _jeda?.cancel();
    _sisaJeda = Kalibrasi.jedaAntarPutaran.inSeconds;
    _jeda = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _sisaJeda--);
      if (_sisaJeda <= 0) t.cancel();
    });
  }

  void _lanjutSetelahJeda() {
    _jeda?.cancel();
    setState(() => _tahap = _Tahap.putaran);
  }

  void _ulangSemua() {
    _jeda?.cancel();
    setState(() {
      _selesai.clear();
      _bersihkanPutaran();
      _tahap = _Tahap.persiapan;
    });
  }

  Future<void> _kirim() async {
    final kalibrasi = _kalibrasi;
    if (kalibrasi == null || !kalibrasi.konsisten) return;

    final controller = context.read<SesiMakanController>();
    final navigator = Navigator.of(context);
    setState(() {
      _sedangMengirim = true;
      _galat = null;
    });
    try {
      await controller.simpanKalibrasi(kalibrasi);
      if (!mounted) return;
      navigator.pop(true);
    } on GalatJam catch (e) {
      if (mounted) {
        setState(() {
          _sedangMengirim = false;
          // Kalibrasi yang gagal sampai ke jam tidak boleh terlihat berhasil:
          // jam terus memakai offset lamanya.
          _galat = '${e.pesanPengguna} Koreksi belum tersimpan di jam.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _sedangMengirim = false;
          _galat =
              'Koreksi gagal dikirim ke jam. Pastikan jam tersambung, lalu '
              'coba lagi.';
        });
      }
    }
  }

  // --- Tampilan -----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
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
          'Kalibrasi Tekanan Darah',
          style: TextStyle(
            color: Color(0xFF1E3A34),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: switch (_tahap) {
            _Tahap.persiapan => _persiapan(),
            _Tahap.putaran => _putaran(),
            _Tahap.jeda => _tampilanJeda(),
            _Tahap.ringkasan => _ringkasan(),
          },
        ),
      ),
    );
  }

  // Tahap 1 — persiapan.
  Widget _persiapan() {
    final controller = context.watch<SesiMakanController>();
    final terakhir = controller.kalibrasiTerakhir;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (terakhir != null) ...[
          _KartuStatusKalibrasi(kalibrasi: terakhir),
          const SizedBox(height: 16),
        ],
        const Text(
          'Menyamakan jam dengan tensimeter',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Jam mengukur tekanan darah dari gelombang nadi, jadi ia perlu satu '
          'kali dibandingkan dengan tensimeter lengan atas. Prosesnya '
          '${Kalibrasi.jumlahPutaran} kali pengukuran berpasangan, sekitar 10 '
          'menit, dan berlaku ${Kalibrasi.masaBerlaku.inDays ~/ 7} minggu.',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B807B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),

        const _JudulLangkah(nomor: 1, judul: 'Siapkan dulu'),
        const SizedBox(height: 12),
        _KartuDaftarPeriksa(
          butir: [
            const (
              ikon: Icons.monitor_heart_outlined,
              teks: 'Tensimeter lengan atas yang biasa Anda pakai.',
            ),
            const (
              ikon: Icons.event_seat_outlined,
              teks:
                  'Duduk tenang 5 menit: punggung bersandar, kaki menapak '
                  'lantai, kaki tidak menyilang.',
            ),
            (
              ikon: Icons.swap_horiz_rounded,
              // Ini butir yang paling sering salah dikerjakan, jadi ia
              // disebutkan di sini dan diulang lagi di tiap putaran.
              teks: _sisi == null
                  ? 'Manset dipasang di lengan yang berlawanan dengan jam — '
                        'manset yang mengembang membuat jam di lengan yang '
                        'sama tidak bisa membaca apa pun.'
                  : 'Manset di ${_sisi!.seberang.labelLengan}, jam tetap di '
                        '${_sisi!.label.toLowerCase()}. Manset yang mengembang '
                        'membuat jam di lengan yang sama tidak bisa membaca '
                        'apa pun.',
            ),
            const (
              ikon: Icons.back_hand_outlined,
              teks:
                  'Kedua lengan diletakkan di meja, setinggi dada. Jangan '
                  'bicara atau bergerak selama pengukuran.',
            ),
            const (
              ikon: Icons.watch_outlined,
              teks:
                  'Jam dipakai pas — tidak longgar — sedikit di atas tulang '
                  'pergelangan.',
            ),
          ],
        ),
        const SizedBox(height: 24),

        const _JudulLangkah(nomor: 2, judul: 'Jam dipakai di tangan mana?'),
        const SizedBox(height: 6),
        Text(
          _sisi == null
              ? 'Kalibrasi hanya berlaku untuk tangan ini. Kalau nanti jam '
                    'pindah tangan, ulangi kalibrasinya. Mansetnya dipasang di '
                    'lengan sebelahnya.'
              : 'Kalibrasi hanya berlaku untuk ${_sisi!.label.toLowerCase()}; '
                    'kalau nanti jam pindah tangan, ulangi. Manset dipasang di '
                    '${_sisi!.seberang.labelLengan}.',
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF8FA7A1),
            height: 1.4,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            for (final sisi in SisiPergelangan.values) ...[
              Expanded(
                child: _PilihanSisi(
                  sisi: sisi,
                  terpilih: _sisi == sisi,
                  onTap: () => setState(() => _sisi = sisi),
                ),
              ),
              if (sisi != SisiPergelangan.values.last)
                const SizedBox(width: 12),
            ],
          ],
        ),
        const SizedBox(height: 20),

        // Kalimat ini tidak bisa ditawar dan tidak boleh disembunyikan di
        // balik tautan: alat ini menghasilkan angka yang tampak seperti angka
        // tensimeter, dan orang menyesuaikan obat berdasarkan angka semacam
        // itu.
        const _KartuPeringatan(
          teks:
              'Hasil jam adalah perkiraan untuk memantau tren, bukan alat '
              'diagnosis. Jangan memakainya untuk mengubah dosis obat. Bila '
              'Anda punya gangguan irama jantung atau sedang hamil, angkanya '
              'bisa jauh meleset — bicarakan dengan dokter lebih dulu.',
        ),
        const SizedBox(height: 20),

        _TombolUtama(
          label: 'Mulai Kalibrasi',
          onPressed: _sisi == null ? null : _mulai,
        ),
        if (_sisi == null) ...[
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Pilih tangan tempat jam dipakai untuk melanjutkan.',
              style: TextStyle(fontSize: 11, color: Color(0xFF9CB1AC)),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  // Tahap 2 — satu putaran pengukuran.
  Widget _putaran() {
    final putaran = _putaranIni;
    final sisi = _sisi ?? SisiPergelangan.kiri;
    // "Ada bacaan" bukan sekadar "sudah ditekan": sensor bisa gagal dan
    // mengembalikan sampel tanpa tekanan darah (§5.2 sentinel 0 → null).
    final sudahAdaBacaan =
        _pembacaanJam?.sistolik != null && _pembacaanJam?.diastolik != null;
    // Kabar dari jam, bukan tebakan layar. null selagi [_sedangMengukur]
    // berarti perintahnya sudah dikirim tetapi jam belum sekali pun melapor —
    // dan itu dikatakan apa adanya, bukan disamarkan sebagai "sedang
    // mengukur" (docs/protokol-jam.md §5.5 v1.4).
    final kemajuan = context.watch<SesiMakanController>().kemajuanUkur;
    // Diperiksa sebelum tombolnya bisa ditekan, bukan sesudah: prosedur ini
    // tiga putaran berjeda 60 detik, dan gagal di putaran terakhir karena
    // baterai berarti seluruhnya diulang dari awal.
    final halangan = context
        .watch<SesiMakanController>()
        .alasanJamTidakBisaUkur;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PenandaKemajuan(
          selesai: _selesai.length,
          total: Kalibrasi.jumlahPutaran,
        ),
        const SizedBox(height: 18),
        Text(
          'Putaran $_nomorPutaran dari ${Kalibrasi.jumlahPutaran}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Manset di ${sisi.seberang.labelLengan}, jam di '
          '${sisi.label.toLowerCase()}. Tekan tombol di bawah ini dan tombol '
          'START tensimeter pada saat yang sama, lalu diam sampai keduanya '
          'selesai.',
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF6B807B),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 22),

        const _JudulLangkah(nomor: 1, judul: 'Ukur bersamaan'),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
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
                children: [
                  Expanded(
                    child: Text(
                      _sedangMengukur
                          ? _judulMengukur(kemajuan)
                          : _pembacaanJam == null
                          ? 'Jam belum mengukur'
                          : sudahAdaBacaan
                          ? 'Jam sudah selesai mengukur'
                          : 'Jam gagal membaca',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E3A34),
                      ),
                    ),
                  ),
                  if (_sedangMengukur)
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF0EAD69),
                      ),
                    )
                  else if (sudahAdaBacaan)
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 20,
                      color: Color(0xFF0EAD69),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _sedangMengukur
                    ? _penjelasanMengukur(kemajuan)
                    : sudahAdaBacaan
                    // Angkanya sengaja tidak ditampilkan di sini. Lihat
                    // alasannya di komentar kelas — ini yang menggantikan
                    // penguncian urutan.
                    ? 'Angkanya disembunyikan dulu supaya tidak memengaruhi '
                          'angka yang Anda tulis di bawah.'
                    : 'Tekan bersamaan dengan tombol START tensimeter.',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8FA7A1),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: (_sedangMengukur || halangan != null)
                      ? null
                      : _ukurDenganJam,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0EAD69),
                    side: const BorderSide(
                      color: Color(0xFFE2EBE8),
                      width: 1.5,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    _sedangMengukur
                        ? (kemajuan?.persen != null
                              ? 'Jam sedang mengukur… ${kemajuan!.persen}%'
                              : 'Menunggu jam…')
                        : _pembacaanJam == null
                        ? 'Mulai Ukur Bersamaan'
                        : 'Ukur Ulang',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              if (halangan != null && _galat == null) ...[
                const SizedBox(height: 10),
                Text(
                  halangan,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFFC0392B),
                    height: 1.4,
                  ),
                ),
              ],
              if (_galat != null) ...[
                const SizedBox(height: 10),
                _BarisGalat(pesan: _galat!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 24),

        const _JudulLangkah(nomor: 2, judul: 'Tulis hasil tensimeter'),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _kolomAngka(
                kunci: 'sistolik',
                label: 'Sistolik (atas)',
                controller: _sistolik,
                aktif: sudahAdaBacaan,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _kolomAngka(
                kunci: 'diastolik',
                label: 'Diastolik (bawah)',
                controller: _diastolik,
                aktif: sudahAdaBacaan,
              ),
            ),
          ],
        ),
        if (!sudahAdaBacaan) ...[
          const SizedBox(height: 8),
          const Text(
            'Bisa diisi setelah jam selesai mengukur.',
            style: TextStyle(fontSize: 10, color: Color(0xFF9CB1AC)),
          ),
        ],
        if (_galatReferensi != null) ...[
          const SizedBox(height: 8),
          _BarisGalat(pesan: _galatReferensi!),
        ],
        const SizedBox(height: 20),

        // Tirainya baru dibuka di sini: kedua angka sudah ada, jadi tidak ada
        // lagi yang bisa dipengaruhi.
        if (putaran != null) ...[
          _KartuPerbandingan(nomor: _nomorPutaran, putaran: putaran),
          const SizedBox(height: 16),
        ],
        _TombolUtama(
          label: _selesai.length == Kalibrasi.jumlahPutaran - 1
              ? 'Simpan & Lihat Hasil'
              : 'Simpan Putaran $_nomorPutaran',
          onPressed: putaran == null ? null : _simpanPutaran,
        ),
        const SizedBox(height: 10),
        Center(
          child: TextButton(
            onPressed: _ulangSemua,
            child: const Text(
              'Batalkan kalibrasi',
              style: TextStyle(fontSize: 12, color: Color(0xFF8FA7A1)),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // Tahap 3 — jeda wajib antar putaran.
  Widget _tampilanJeda() {
    final total = Kalibrasi.jedaAntarPutaran.inSeconds;
    final sisa = _sisaJeda.clamp(0, total);
    final selesai = sisa == 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PenandaKemajuan(
          selesai: _selesai.length,
          total: Kalibrasi.jumlahPutaran,
        ),
        const SizedBox(height: 28),
        Center(
          child: SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: selesai ? 1 : (total - sisa) / total,
                    strokeWidth: 8,
                    backgroundColor: const Color(0xFFE2EBE8),
                    color: const Color(0xFF0EAD69),
                  ),
                ),
                Text(
                  selesai ? 'Siap' : '$sisa',
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A34),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            selesai ? 'Jeda selesai' : 'Istirahat sebentar',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A34),
            ),
          ),
        ),
        const SizedBox(height: 8),
        const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              // Sebabnya disebut, bukan cuma perintahnya: jeda yang tidak
              // diterangkan akan terasa seperti aplikasi yang lambat, dan
              // orang akan mencari cara melewatinya.
              'Lepaskan manset dan tetap duduk tenang. Manset yang langsung '
              'dipompa ulang membaca lebih tinggi dari keadaan sebenarnya.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: Color(0xFF6B807B),
                height: 1.5,
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        _TombolUtama(
          label: 'Mulai Putaran $_nomorPutaran',
          onPressed: selesai ? _lanjutSetelahJeda : null,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // Tahap 4 — ringkasan dan pengiriman.
  Widget _ringkasan() {
    final kalibrasi = _kalibrasi!;
    final konsisten = kalibrasi.konsisten;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PenandaKemajuan(
          selesai: Kalibrasi.jumlahPutaran,
          total: Kalibrasi.jumlahPutaran,
        ),
        const SizedBox(height: 18),
        Text(
          konsisten ? 'Hasil kalibrasi' : 'Hasilnya belum bisa dipakai',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
          ),
          child: Column(
            children: [
              const Row(
                children: [
                  Expanded(flex: 2, child: _TeksTabel('Putaran', kepala: true)),
                  Expanded(
                    flex: 3,
                    child: _TeksTabel('Tensimeter', kepala: true),
                  ),
                  Expanded(flex: 3, child: _TeksTabel('Jam', kepala: true)),
                  Expanded(flex: 3, child: _TeksTabel('Selisih', kepala: true)),
                ],
              ),
              const SizedBox(height: 6),
              for (var i = 0; i < kalibrasi.putaran.length; i++) ...[
                const Divider(height: 14, color: Color(0xFFE2EBE8)),
                Row(
                  children: [
                    Expanded(flex: 2, child: _TeksTabel('${i + 1}')),
                    Expanded(
                      flex: 3,
                      child: _TeksTabel(
                        kalibrasi.putaran[i].ringkasanReferensi,
                      ),
                    ),
                    Expanded(
                      flex: 3,
                      child: _TeksTabel(kalibrasi.putaran[i].ringkasanJam),
                    ),
                    Expanded(
                      flex: 3,
                      child: _TeksTabel(
                        '${_tanda(kalibrasi.putaran[i].offsetSistolik)}/'
                        '${_tanda(kalibrasi.putaran[i].offsetDiastolik)}',
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        if (!konsisten) ...[
          _KartuPeringatan(
            teks:
                'Selisih antar putaran terlalu jauh '
                '(${kalibrasi.sebaranSistolik}/${kalibrasi.sebaranDiastolik} '
                'mmHg, batasnya ${Kalibrasi.sebaranMaksimum}). Biasanya karena '
                'manset kurang rapat, lengan tidak setinggi dada, atau tubuh '
                'belum benar-benar istirahat. Ulangi kalibrasinya — koreksi '
                'dari angka yang berbeda-beda akan salah selama sebulan penuh.',
          ),
          const SizedBox(height: 16),
          _TombolUtama(label: 'Ulangi Kalibrasi', onPressed: _ulangSemua),
        ] else ...[
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFE2F6F0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Koreksi ${kalibrasi.ringkasanOffset}',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A34),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Nilai tengah dari ${Kalibrasi.jumlahPutaran} putaran, untuk '
                  '${kalibrasi.sisi.label.toLowerCase()}. Jam akan '
                  'menambahkannya pada tiap pengukuran berikutnya sampai '
                  '${formatTanggal(kalibrasi.berlakuSampai)}.',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF6B807B),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
          if (_galat != null) ...[
            const SizedBox(height: 12),
            _BarisGalat(pesan: _galat!),
          ],
          const SizedBox(height: 16),
          _TombolUtama(
            label: _sedangMengirim ? 'Mengirim…' : 'Kirim ke Jam',
            onPressed: _sedangMengirim ? null : _kirim,
          ),
          const SizedBox(height: 10),
          Center(
            child: TextButton(
              onPressed: _ulangSemua,
              child: const Text(
                'Ukur ulang dari awal',
                style: TextStyle(fontSize: 12, color: Color(0xFF8FA7A1)),
              ),
            ),
          ),
        ],
        const SizedBox(height: 24),
      ],
    );
  }

  static String _tanda(int n) => n >= 0 ? '+$n' : '$n';

  Widget _kolomAngka({
    required String kunci,
    required String label,
    required TextEditingController controller,
    bool aktif = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Color(0xFF6B807B),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          key: Key(kunci),
          controller: controller,
          enabled: aktif,
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(3),
          ],
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            suffixText: 'mmHg',
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 12,
            ),
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2EBE8)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2EBE8)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF0EAD69),
                width: 1.5,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Status kalibrasi yang sedang berlaku, termasuk sisa masa berlakunya.
class _KartuStatusKalibrasi extends StatelessWidget {
  const _KartuStatusKalibrasi({required this.kalibrasi});

  final Kalibrasi kalibrasi;

  @override
  Widget build(BuildContext context) {
    final kini = DateTime.now();
    final habis = kalibrasi.kedaluwarsaPada(kini);
    final sisa = kalibrasi.sisaHariPada(kini);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: habis ? const Color(0xFFFFF4E5) : const Color(0xFFE8F8F5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                habis ? Icons.warning_amber_rounded : Icons.verified_outlined,
                size: 18,
                color: habis
                    ? const Color(0xFFB4761E)
                    : const Color(0xFF0EAD69),
              ),
              const SizedBox(width: 8),
              Text(
                habis ? 'Kalibrasi kedaluwarsa' : 'Kalibrasi berlaku',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            habis
                // Yang penting bukan tanggalnya, melainkan bahwa jam tetap
                // mengoreksi memakai angka lama itu.
                ? 'Dibuat ${formatWaktuRelatif(kalibrasi.waktu)} untuk '
                      '${kalibrasi.sisi.label.toLowerCase()}. Jam masih '
                      'memakai koreksi ${kalibrasi.ringkasanOffset}, tetapi '
                      'angkanya sudah tidak bisa dipertanggungjawabkan. '
                      'Kalibrasi ulang.'
                : 'Koreksi ${kalibrasi.ringkasanOffset} untuk '
                      '${kalibrasi.sisi.label.toLowerCase()}, dibuat '
                      '${formatWaktuRelatif(kalibrasi.waktu)}. Berlaku '
                      '$sisa hari lagi (sampai '
                      '${formatTanggal(kalibrasi.berlakuSampai)}).',
            style: const TextStyle(
              fontSize: 11,
              color: Color(0xFF6B807B),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

typedef _Butir = ({IconData ikon, String teks});

class _KartuDaftarPeriksa extends StatelessWidget {
  const _KartuDaftarPeriksa({required this.butir});

  final List<_Butir> butir;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < butir.length; i++) ...[
            if (i > 0) const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE2F6F0),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    butir[i].ikon,
                    size: 16,
                    color: const Color(0xFF0EAD69),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      butir[i].teks,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF1E3A34),
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PilihanSisi extends StatelessWidget {
  const _PilihanSisi({
    required this.sisi,
    required this.terpilih,
    required this.onTap,
  });

  final SisiPergelangan sisi;
  final bool terpilih;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: terpilih ? const Color(0xFFE2F6F0) : Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: terpilih
                  ? const Color(0xFF0EAD69)
                  : const Color(0xFFE2EBE8),
              width: terpilih ? 1.8 : 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.watch_rounded,
                size: 22,
                color: terpilih
                    ? const Color(0xFF0EAD69)
                    : const Color(0xFF8FA7A1),
              ),
              const SizedBox(height: 8),
              Text(
                sisi.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: terpilih
                      ? const Color(0xFF0EAD69)
                      : const Color(0xFF6B807B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tiga titik yang menunjukkan sudah berapa putaran yang tersimpan.
class _PenandaKemajuan extends StatelessWidget {
  const _PenandaKemajuan({required this.selesai, required this.total});

  final int selesai;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Container(
              height: 6,
              decoration: BoxDecoration(
                color: i < selesai
                    ? const Color(0xFF0EAD69)
                    : i == selesai
                    ? const Color(0xFF7BE5C4)
                    : const Color(0xFFE2EBE8),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Kedua angka satu putaran, ditampilkan berdampingan begitu keduanya ada.
///
/// Inilah saat tirainya dibuka: sebelum angka tensimeter masuk, pembacaan jam
/// sengaja tidak terlihat di mana pun (lihat komentar kelas halaman).
class _KartuPerbandingan extends StatelessWidget {
  const _KartuPerbandingan({required this.nomor, required this.putaran});

  final int nomor;
  final PutaranKalibrasi putaran;

  @override
  Widget build(BuildContext context) {
    String tanda(int n) => n >= 0 ? '+$n' : '$n';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE2F6F0),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Putaran $nomor',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B807B),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _nilai('Tensimeter', '${putaran.ringkasanReferensi} mmHg'),
              _nilai('Jam', '${putaran.ringkasanJam} mmHg'),
              _nilai(
                'Selisih',
                '${tanda(putaran.offsetSistolik)}/'
                    '${tanda(putaran.offsetDiastolik)}',
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Text(
            'Belum dikirim ke jam. Koreksi baru dihitung setelah semua putaran '
            'selesai.',
            style: TextStyle(fontSize: 11, color: Color(0xFF6B807B)),
          ),
        ],
      ),
    );
  }

  Widget _nilai(String label, String nilai) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 10, color: Color(0xFF8FA7A1)),
          ),
          const SizedBox(height: 2),
          Text(
            nilai,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A34),
            ),
          ),
        ],
      ),
    );
  }
}

class _KartuPeringatan extends StatelessWidget {
  const _KartuPeringatan({required this.teks});

  final String teks;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0D9B5), width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: Color(0xFFB4761E),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              teks,
              style: const TextStyle(
                fontSize: 11,
                color: Color(0xFF6B807B),
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BarisGalat extends StatelessWidget {
  const _BarisGalat({required this.pesan});

  final String pesan;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(
          Icons.error_outline_rounded,
          size: 15,
          color: Colors.redAccent,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            pesan,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.redAccent,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _TeksTabel extends StatelessWidget {
  const _TeksTabel(this.teks, {this.kepala = false});

  final String teks;
  final bool kepala;

  @override
  Widget build(BuildContext context) {
    return Text(
      teks,
      style: TextStyle(
        fontSize: kepala ? 10 : 12,
        fontWeight: kepala ? FontWeight.w600 : FontWeight.bold,
        color: kepala ? const Color(0xFF8FA7A1) : const Color(0xFF1E3A34),
      ),
    );
  }
}

class _TombolUtama extends StatelessWidget {
  const _TombolUtama({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0EAD69),
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFE2EBE8),
          disabledForegroundColor: const Color(0xFF9CB1AC),
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        ),
      ),
    );
  }
}

class _JudulLangkah extends StatelessWidget {
  const _JudulLangkah({required this.nomor, required this.judul});

  final int nomor;
  final String judul;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: const BoxDecoration(
            color: Color(0xFF0EAD69),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            '$nomor',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            judul,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A34),
            ),
          ),
        ),
      ],
    );
  }
}
