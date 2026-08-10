import 'package:flutter/material.dart';

import '../models/sesi_makan.dart';
import '../utils/format_waktu.dart';
import '../utils/ikon.dart';

/// Ringkasan nutrisi satu sesi: enam angka makro (§12.4), termasuk gula total
/// dan serat yang menjelaskan perbedaan respons antar makanan berkarbohidrat
/// sama.
///
/// `hasil == null` adalah kondisi normal, bukan error — foto bisa diambil saat
/// offline dan analisis menyusul. Slot nutrisi menampilkan "Menganalisis…"
/// dan sesi tetap berjalan (§12.3).
class RingkasanNutrisi extends StatelessWidget {
  const RingkasanNutrisi({super.key, required this.hasil});

  final HasilDeteksi? hasil;

  @override
  Widget build(BuildContext context) {
    final h = hasil;
    if (h == null) return const _NutrisiMenganalisis();

    final t = h.total;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _item('Kalori', formatAngka(t.kalori), ' kcal'),
            _item('Karbohidrat', formatAngka(t.karbohidrat), ' g'),
            _item('Protein', formatAngka(t.protein), ' g'),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            _item('Lemak', formatAngka(t.lemak), ' g'),
            _item('Gula Total', formatAngka(t.gulaTotal), ' g'),
            _item('Serat', formatAngka(t.serat), ' g'),
          ],
        ),
      ],
    );
  }

  Widget _item(String label, String nilai, String satuan) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                ikonMakro[label] ?? Icons.circle,
                size: 12,
                color: const Color(0xFF8FA7A1),
              ),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
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
          const SizedBox(height: 4),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E3A34),
              ),
              children: [
                TextSpan(text: nilai),
                TextSpan(
                  text: satuan,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.normal,
                    color: Color(0xFF6B807B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NutrisiMenganalisis extends StatelessWidget {
  const _NutrisiMenganalisis();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFF0EAD69),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                'Menganalisis…',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Nutrisi menyusul, sesi tetap berjalan',
                style: TextStyle(fontSize: 11, color: Color(0xFF8FA7A1)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
