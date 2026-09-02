/// Pemformat waktu berbahasa Indonesia yang dipakai layar-layar sesi makan.
///
/// Prinsip §8 rancangan: setiap angka membawa waktu ukurnya, dan angka yang
/// belum ada ditulis `—`, tidak pernah diisi nilai lama.
library;

const String tandaKosong = '—';

const List<String> _namaBulan = [
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

String formatJam(DateTime dt) =>
    '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';

String formatTanggal(DateTime dt) =>
    '${dt.day} ${_namaBulan[dt.month]} ${dt.year}';

/// Hitung mundur gaya "42:17", atau "1:02:17" bila lebih dari sejam.
String formatHitungMundur(Duration sisa) {
  if (sisa.isNegative) sisa = Duration.zero;
  final menit = sisa.inMinutes.remainder(60).toString().padLeft(2, '0');
  final detik = sisa.inSeconds.remainder(60).toString().padLeft(2, '0');
  if (sisa.inHours > 0) return '${sisa.inHours}:$menit:$detik';
  return '$menit:$detik';
}

/// "3 jam lalu" — label kejujuran soal data basi (§8).
String formatWaktuRelatif(DateTime waktu, {DateTime? sekarang}) {
  final selisih = (sekarang ?? DateTime.now()).difference(waktu);
  if (selisih.isNegative) return 'sebentar lagi';
  if (selisih.inMinutes < 1) return 'baru saja';
  if (selisih.inMinutes < 60) return '${selisih.inMinutes} menit lalu';
  if (selisih.inHours < 24) return '${selisih.inHours} jam lalu';
  if (selisih.inDays == 1) return 'kemarin';
  return '${selisih.inDays} hari lalu';
}

/// "2 jam" / "45 menit" untuk durasi bulat seperti waktu pemulihan.
String formatDurasiRingkas(Duration d) {
  if (d.inMinutes % 60 == 0 && d.inHours >= 1) return '${d.inHours} jam';
  if (d.inMinutes >= 60) {
    return '${d.inHours} jam ${d.inMinutes.remainder(60)} menit';
  }
  return '${d.inMinutes} menit';
}

/// Angka nutrisi tanpa ".0" yang mengganggu.
String formatAngka(double nilai) {
  if (nilai == nilai.roundToDouble()) return nilai.round().toString();
  return nilai.toStringAsFixed(1);
}
