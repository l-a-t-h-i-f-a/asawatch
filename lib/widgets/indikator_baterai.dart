import 'package:flutter/material.dart';

/// Baterai jam sebagai **empat kotak — tiruan ikon di layar jam itu sendiri**,
/// tanpa angka.
///
/// **Aturannya disalin dari firmware, bukan dirancang ulang** (`batt_hitung_kotak`,
/// `BATT_TURUN`/`BATT_NAIK`, dan `refresh_cb` di varian `touchscreen` dan
/// `no_touch-callibration`). Orang melihat kedua layar bergantian; bila jam
/// menunjukkan tiga kotak dan ponsel empat, yang dipercaya bukan salah satunya
/// tetapi tidak keduanya. Karena itu:
///
/// - satu kotak = 25%, menyala di 25/50/75/100 dan padam di bawah 20/45/70/95.
///   **Histeresisnya ikut**, sebab tanpa itu kotak di ambang berkedip tiap kali
///   persen bergoyang satu — dan tampilan pertama memakai titik tengah kedua
///   ambang, persis seperti jam;
/// - warna redup biasanya, **hijau selama dicas**, **merah saat kotaknya habis**
///   (atau jam melapor kritis, §5.5 bit2 — ambang 10% itu milik firmware);
/// - petir di kiri badan hanya selama dicas **dan di bawah 100%**: jam
///   membungkam tanda cas pada sel yang sudah penuh walau kabel masih
///   tertancap, dan bit4 di kawat sengaja tetap jujur, jadi aplikasilah yang
///   harus menerapkan pembungkaman yang sama.
///
/// **Persen sengaja tidak ditulis.** Angka dari jam tidak seteliti
/// kelihatannya — rasio pembagi tegangannya baru diukur di satu board, dan
/// selama dicas yang terbaca bukan tegangan sel, sehingga angkanya melompat
/// 8–15%. Kotak sudah mengatakan hal yang sama tanpa mengaku teliti. Angka
/// persisnya tetap ada di halaman Perangkat, untuk penguji.
class IndikatorBaterai extends StatefulWidget {
  const IndikatorBaterai({
    super.key,
    required this.persen,
    this.kritis = false,
    this.dicas = false,
  });

  final int persen;
  final bool kritis;

  /// §5.5 `flag` bit4 (v1.5), apa adanya dari jam.
  final bool dicas;

  static const int jumlahKotak = 4;

  /// Kotak ke-n padam di bawah ini (firmware `BATT_TURUN`).
  static const List<int> ambangTurun = [20, 45, 70, 95];

  /// Kotak ke-n menyala mulai dari ini (firmware `BATT_NAIK`).
  static const List<int> ambangNaik = [25, 50, 75, 100];

  /// Jumlah kotak yang menyala, dengan histeresis terhadap [lalu] — salinan
  /// `batt_hitung_kotak`. [lalu] null berarti tampilan pertama: belum ada
  /// riwayat, jadi dipakai titik tengah kedua ambang.
  static int hitungKotak(int persen, [int? lalu]) {
    final p = persen.clamp(0, 100);
    if (lalu == null) {
      var n = 0;
      while (n < jumlahKotak && p >= (ambangTurun[n] + ambangNaik[n]) ~/ 2) {
        n++;
      }
      return n;
    }
    var n = lalu.clamp(0, jumlahKotak);
    while (n < jumlahKotak && p >= ambangNaik[n]) {
      n++;
    }
    while (n > 0 && p < ambangTurun[n - 1]) {
      n--;
    }
    return n;
  }

  /// Petir dan warna cas — dibungkam pada 100%, seperti di layar jam.
  static bool tampilDicas(int persen, bool dicas) => dicas && persen < 100;

  static const Color warnaBiasa = Color(0xFF6B807B);
  static const Color warnaDicas = Color(0xFF0EAD69);
  static const Color warnaHabis = Color(0xFFC0392B);

  @override
  State<IndikatorBaterai> createState() => _IndikatorBateraiState();
}

class _IndikatorBateraiState extends State<IndikatorBaterai> {
  late int _kotak = IndikatorBaterai.hitungKotak(widget.persen);

  @override
  void didUpdateWidget(IndikatorBaterai lama) {
    super.didUpdateWidget(lama);
    if (lama.persen != widget.persen) {
      _kotak = IndikatorBaterai.hitungKotak(widget.persen, _kotak);
    }
  }

  @override
  Widget build(BuildContext context) {
    const kosong = Color(0xFFE2EBE8);
    final dicas = IndikatorBaterai.tampilDicas(widget.persen, widget.dicas);
    // Urutannya sama dengan `batt_gambar`: cas menang atas kotak kosong. Kritis
    // tidak bisa terjadi selagi dicas dengan kotak menyala dalam praktik, dan
    // bila terjadi, hijau yang jujur ("sedang diisi") lebih berguna.
    final warna = dicas
        ? IndikatorBaterai.warnaDicas
        : (_kotak == 0 || widget.kritis)
        ? IndikatorBaterai.warnaHabis
        : IndikatorBaterai.warnaBiasa;

    return Semantics(
      label:
          'Baterai jam $_kotak dari ${IndikatorBaterai.jumlahKotak} kotak'
          '${dicas ? ', sedang dicas' : ''}',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dicas) ...[
              Icon(Icons.bolt_rounded, size: 15, color: warna),
              const SizedBox(width: 1),
            ],
            Container(
              height: 16,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                border: Border.all(color: warna, width: 1.5),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < IndikatorBaterai.jumlahKotak; i++) ...[
                    if (i > 0) const SizedBox(width: 1.5),
                    Container(
                      width: 6,
                      decoration: BoxDecoration(
                        color: i < _kotak ? warna : kosong,
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            // Kepala baterai.
            Container(
              width: 2.5,
              height: 6,
              decoration: BoxDecoration(
                color: warna,
                borderRadius: const BorderRadius.horizontal(
                  right: Radius.circular(1.5),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
