import 'dart:async';

import 'package:flutter/material.dart';

import '../models/sesi_makan.dart';
import '../utils/format_waktu.dart';

/// Timeline empat titik pengukuran sebuah sesi.
///
/// Dipakai bersama oleh kartu sesi di Beranda (§4.1 wajah B) dan
/// `SesiBerjalanPage` (§5) supaya keduanya tidak pernah berbeda isi.
/// Titik yang belum ada ditulis `—`, tidak pernah diisi nilai lama (§8).
class TimelineSampel extends StatelessWidget {
  const TimelineSampel({
    super.key,
    required this.sampel,
    required this.t0,
    this.indexBerikutnya,
    this.kemampuan = KemampuanPerangkat.semua,
  });

  final List<Sampel> sampel;
  final DateTime? t0;

  /// Titik yang sedang dihitung mundur; null bila tidak ada yang dijadwalkan.
  final int? indexBerikutnya;

  /// Metrik yang jam ini benar-benar punya (protokol §3). Yang tidak dimiliki
  /// **tidak ditulis sama sekali** — bukan ditulis `—`, yang terbaca sebagai
  /// pengukuran yang gagal.
  final KemampuanPerangkat kemampuan;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final s in sampel)
          _BarisTitik(
            sampel: s,
            t0: t0,
            terakhir: s.index == sampel.length - 1,
            hitungMundur: s.index == indexBerikutnya,
            kemampuan: kemampuan,
          ),
      ],
    );
  }
}

class _BarisTitik extends StatelessWidget {
  const _BarisTitik({
    required this.sampel,
    required this.t0,
    required this.terakhir,
    required this.hitungMundur,
    required this.kemampuan,
  });

  final Sampel sampel;
  final DateTime? t0;
  final bool terakhir;
  final bool hitungMundur;
  final KemampuanPerangkat kemampuan;

  /// Metrik selain gula darah, dirangkai jadi satu baris.
  ///
  /// Gula darah tidak ikut: ia sudah berdiri sendiri di kanan baris ini sebagai
  /// angka besar, karena seluruh sesi makan memang tentang dia. Yang di sini
  /// adalah tiga metrik yang sebelumnya **tidak terlihat di mana pun sampai
  /// sesinya selesai** — padahal ketiganya sudah diukur di setiap titik sejak
  /// awal, dan seorang pengguna yang ingin tahu SpO2-nya tidak punya alasan
  /// menunggu dua jam untuk melihat angka yang sudah ada.
  String? get _metrikSekunder {
    if (!sampel.terisi) return null;
    final bagian = <String>[
      // Detak jantung tidak punya bit `kemampuan` di §3 dan selalu dianggap ada.
      if (sampel.detakJantung != null) '${sampel.detakJantung} bpm',
      if (kemampuan.tekananDarah && sampel.tekananDarah != null)
        '${sampel.tekananDarah} mmHg',
      if (kemampuan.spo2 && sampel.spo2 != null) 'SpO₂ ${sampel.spo2}%',
    ];
    return bagian.isEmpty ? null : bagian.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final terisi = sampel.terisi;
    final terlewat = sampel.status == StatusSampel.terlewat;
    final jadwal = t0 == null ? null : sampel.waktuUkur(t0!);

    final warnaIkon = terisi
        ? const Color(0xFF0EAD69)
        : terlewat
        ? Colors.red
        : const Color(0xFF8FA7A1);

    return Padding(
      padding: EdgeInsets.only(bottom: terakhir ? 0 : 14),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: terisi ? const Color(0xFFE2F6F0) : const Color(0xFFF4FAF7),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
            ),
            alignment: Alignment.center,
            child: Icon(
              terisi
                  ? Icons.check_rounded
                  : terlewat
                  ? Icons.close_rounded
                  : Icons.schedule_rounded,
              size: 15,
              color: warnaIkon,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sampel.label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E3A34),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (jadwal != null) formatJam(jadwal),
                    if (terlewat) 'terlewat',
                    if (sampel.dariBuffer) 'dari buffer jam',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF8FA7A1),
                  ),
                ),
                if (_metrikSekunder != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    _metrikSekunder!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      height: 1.2,
                      color: Color(0xFF6B807B),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (terisi && kemampuan.gulaDarah && sampel.gulaDarah != null)
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E3A34),
                ),
                children: [
                  TextSpan(text: '${sampel.gulaDarah}'),
                  const TextSpan(
                    text: ' mg/dL',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.normal,
                      color: Color(0xFF6B807B),
                    ),
                  ),
                ],
              ),
            )
          else if (hitungMundur && jadwal != null)
            HitungMundur(target: jadwal)
          else
            const Text(
              tandaKosong,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF9CB1AC),
              ),
            ),
        ],
      ),
    );
  }
}

/// Hitung mundur detik-detikan yang ditangani lokal (§8): `Timer.periodic`
/// milik kartu ini sendiri, bukan `notifyListeners()` tiap detik.
///
/// Sisa waktu selalu dihitung ulang dari [target] yang absolut, tidak pernah
/// disimpan lalu dikurangi (§12.6). [sekarang] hanya ada agar test bisa
/// menyuntikkan jamnya sendiri.
class HitungMundur extends StatefulWidget {
  const HitungMundur({
    super.key,
    required this.target,
    this.sekarang = DateTime.now,
    this.gaya,
    this.gayaSelesai,
  });

  final DateTime target;
  final DateTime Function() sekarang;

  /// Gaya angkanya. Null memakai ukuran baris timeline (14 px); kartu Beranda
  /// memberinya ukuran hero, karena di sana angka inilah yang dicari mata
  /// pertama kali dan bukan salah satu dari empat baris.
  ///
  /// `fontFeatures: tabularFigures` tetap dipasang di sini apa pun gayanya —
  /// angka yang lebarnya berubah tiap detik membuat seluruh baris bergoyang,
  /// dan pada ukuran hero goyangannya sebesar satu huruf.
  final TextStyle? gaya;

  /// Gaya teks "menunggu data". Terpisah karena ia kalimat, bukan angka: pada
  /// ukuran hero ia harus turun, bukan ikut membesar.
  final TextStyle? gayaSelesai;

  @override
  State<HitungMundur> createState() => _HitungMundurState();
}

class _HitungMundurState extends State<HitungMundur> {
  Timer? _timer;
  late Duration _sisa;

  @override
  void initState() {
    super.initState();
    _sisa = _hitung();
    _mulaiTimer();
  }

  @override
  void didUpdateWidget(covariant HitungMundur oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.target != widget.target) {
      _sisa = _hitung();
      _mulaiTimer();
    }
  }

  Duration _hitung() {
    final sisa = widget.target.difference(widget.sekarang());
    return sisa.isNegative ? Duration.zero : sisa;
  }

  void _mulaiTimer() {
    _timer?.cancel();
    if (_sisa == Duration.zero) return;
    // Berhenti begitu jadwalnya lewat: setelah itu yang ditunggu adalah data
    // dari jam, bukan waktu.
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final sisa = _hitung();
      if (sisa == Duration.zero) _timer?.cancel();
      if (mounted) setState(() => _sisa = sisa);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_sisa == Duration.zero) {
      return Text(
        'menunggu data',
        style:
            widget.gayaSelesai ??
            const TextStyle(fontSize: 11, color: Color(0xFF8FA7A1)),
      );
    }
    return Text(
      formatHitungMundur(_sisa),
      style:
          (widget.gaya ??
                  const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0EAD69),
                  ))
              .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
    );
  }
}
