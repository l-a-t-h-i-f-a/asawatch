/// Penerjemah waktu jam tangan — lihat docs/protokol-jam.md §4.
///
/// Jam tidak punya RTC. Ia tidak pernah mengirim wall clock, hanya `uptime_s`
/// (detik sejak boot) dan `boot_id`. Seluruh pengetahuan tentang waktu
/// sungguhan hidup di aplikasi, dalam bentuk *anchor*: satu pasangan
/// "pada uptime sekian, jam HP menunjukkan sekian".
library;

class AnchorWaktu {
  const AnchorWaktu({
    required this.bootId,
    required this.uptimeS,
    required this.epoch,
  });

  /// Masa hidup daya jam yang anchor ini berlaku untuknya. Dua nilai
  /// `uptime_s` hanya boleh dibandingkan bila `bootId`-nya sama — di antara dua
  /// boot ada jeda mati yang panjangnya tidak diketahui siapa pun.
  final int bootId;

  /// Uptime jam saat anchor dipasang.
  final int uptimeS;

  /// Waktu menurut HP pada saat yang sama.
  final DateTime epoch;

  /// Menerjemahkan `uptime_s` mana pun dari boot yang sama menjadi waktu nyata.
  ///
  /// Selisihnya boleh negatif, dan justru itulah yang membuat skema ini
  /// bekerja: peristiwa yang terjadi **sebelum** anchor dipasang tetap bisa
  /// diterjemahkan. Jam yang menyala sendirian sepanjang siang, tombolnya
  /// ditekan, sampelnya terkumpul, lalu baru tersambung malam hari — satu
  /// anchor di akhir sudah cukup untuk seluruh isi buffer boot itu.
  DateTime keWaktu(int uptimeSampel) =>
      epoch.add(Duration(seconds: uptimeSampel - uptimeS));

  /// Apakah anchor ini boleh dipakai menerjemahkan entri dari [bootIdEntri].
  bool berlakuUntuk(int bootIdEntri) => bootIdEntri == bootId;
}
