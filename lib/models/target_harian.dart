/// Target nutrisi harian yang dipakai ringkasan hari ini di Beranda.
///
/// Rancangan §4.6 menempatkan sumber angka ini di Tujuan Kesehatan, tetapi
/// halaman itu hari ini hanya punya target langkah/berat/air/tidur/detak —
/// belum ada target kalori maupun karbohidrat. Sampai langkah tersebut
/// dikerjakan, nilai bawaan di bawah dipakai apa adanya dan tidak disimpan
/// di SharedPreferences, supaya tidak ada dua sumber kebenaran.
class TargetHarian {
  const TargetHarian({
    this.kalori = 2000,
    this.karbohidrat = 250,
    this.protein = 60,
    this.lemak = 65,
  });

  final double kalori, karbohidrat, protein, lemak;

  static const TargetHarian bawaan = TargetHarian();
}
