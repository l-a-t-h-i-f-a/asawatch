import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'controllers/sesi_makan_controller.dart';
import 'models/sesi_makan.dart';
import 'utils/format_waktu.dart';

/// Kalibrasi tekanan darah (§5): user memasukkan hasil tensimeter, aplikasi
/// meminta jam mengukur bersamaan, lalu selisihnya dikirim ke jam sebagai
/// koefisien.
///
/// Urutannya sengaja dikunci — angka tensimeter dulu, baru jam mengukur —
/// supaya keduanya benar-benar sezaman. Mengetik hasil tensimeter setelah
/// melihat angka jam akan menghasilkan koefisien yang menipu diri sendiri.
class KalibrasiTekananDarahPage extends StatefulWidget {
  const KalibrasiTekananDarahPage({super.key});

  @override
  State<KalibrasiTekananDarahPage> createState() =>
      _KalibrasiTekananDarahPageState();
}

class _KalibrasiTekananDarahPageState extends State<KalibrasiTekananDarahPage> {
  final _sistolik = TextEditingController();
  final _diastolik = TextEditingController();

  Sampel? _pembacaanJam;
  bool _sedangMengukur = false;
  bool _sedangMengirim = false;

  @override
  void dispose() {
    _sistolik.dispose();
    _diastolik.dispose();
    super.dispose();
  }

  int? get _nilaiSistolik => int.tryParse(_sistolik.text.trim());
  int? get _nilaiDiastolik => int.tryParse(_diastolik.text.trim());

  bool get _referensiLengkap =>
      (_nilaiSistolik ?? 0) > 0 && (_nilaiDiastolik ?? 0) > 0;

  Kalibrasi? get _kalibrasi {
    final jam = _pembacaanJam;
    if (!_referensiLengkap ||
        jam == null ||
        jam.sistolik == null ||
        jam.diastolik == null) {
      return null;
    }
    return Kalibrasi(
      waktu: DateTime.now(),
      sistolikReferensi: _nilaiSistolik!,
      diastolikReferensi: _nilaiDiastolik!,
      sistolikJam: jam.sistolik!,
      diastolikJam: jam.diastolik!,
    );
  }

  Future<void> _ukurDenganJam() async {
    final controller = context.read<SesiMakanController>();
    setState(() => _sedangMengukur = true);
    try {
      final sampel = await controller.ukurUntukKalibrasi();
      if (!mounted) return;
      setState(() => _pembacaanJam = sampel);
    } finally {
      if (mounted) setState(() => _sedangMengukur = false);
    }
  }

  Future<void> _kirim() async {
    final kalibrasi = _kalibrasi;
    if (kalibrasi == null) return;

    final controller = context.read<SesiMakanController>();
    final navigator = Navigator.of(context);
    setState(() => _sedangMengirim = true);
    await controller.simpanKalibrasi(kalibrasi);
    if (!mounted) return;
    navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<SesiMakanController>();
    final terakhir = controller.kalibrasiTerakhir;
    final kalibrasi = _kalibrasi;

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
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
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
                      'Ukur dengan tensimeter dan jam pada waktu yang sama, '
                      'dalam posisi duduk tenang. Selisih keduanya dikirim ke '
                      'jam sebagai koreksi.',
                      style: TextStyle(
                        fontSize: 11,
                        color: Color(0xFF6B807B),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            _JudulLangkah(nomor: 1, judul: 'Hasil tensimeter'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _kolomAngka(
                    kunci: 'sistolik',
                    label: 'Sistolik',
                    controller: _sistolik,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _kolomAngka(
                    kunci: 'diastolik',
                    label: 'Diastolik',
                    controller: _diastolik,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            _JudulLangkah(nomor: 2, judul: 'Minta jam mengukur'),
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
                  Text(
                    _pembacaanJam?.tekananDarah == null
                        ? tandaKosong
                        : '${_pembacaanJam!.tekananDarah} mmHg',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: _pembacaanJam == null
                          ? const Color(0xFF9CB1AC)
                          : const Color(0xFF1E3A34),
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pembacaan jam',
                    style: TextStyle(fontSize: 11, color: Color(0xFF8FA7A1)),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: _referensiLengkap && !_sedangMengukur
                          ? _ukurDenganJam
                          : null,
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
                            ? 'Jam sedang mengukur…'
                            : _pembacaanJam == null
                            ? 'Ukur Sekarang'
                            : 'Ukur Ulang',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  if (!_referensiLengkap) ...[
                    const SizedBox(height: 8),
                    const Text(
                      'Isi hasil tensimeter lebih dulu agar kedua angka '
                      'berasal dari waktu yang sama.',
                      style: TextStyle(fontSize: 10, color: Color(0xFF9CB1AC)),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 24),

            _JudulLangkah(nomor: 3, judul: 'Kirim koreksi ke jam'),
            const SizedBox(height: 12),
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
                    kalibrasi == null
                        ? 'Koreksi $tandaKosong'
                        : 'Koreksi ${kalibrasi.ringkasanOffset}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E3A34),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    kalibrasi == null
                        ? 'Lengkapi kedua langkah di atas.'
                        : 'Jam akan menambahkan koreksi ini pada tiap '
                              'pengukuran berikutnya.',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF6B807B),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: kalibrasi == null || _sedangMengirim ? null : _kirim,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0EAD69),
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: const Color(0xFFE2EBE8),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Kirim ke Jam',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),

            if (terakhir != null) ...[
              const SizedBox(height: 20),
              Text(
                'Kalibrasi terakhir ${formatWaktuRelatif(terakhir.waktu)} · '
                'koreksi ${terakhir.ringkasanOffset}',
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF8FA7A1),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _kolomAngka({
    required String kunci,
    required String label,
    required TextEditingController controller,
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
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
              borderSide: const BorderSide(color: Color(0xFF0EAD69), width: 1.5),
            ),
          ),
        ),
      ],
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
        Text(
          judul,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
      ],
    );
  }
}
