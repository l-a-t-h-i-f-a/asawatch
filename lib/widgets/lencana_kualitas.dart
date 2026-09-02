import 'package:flutter/material.dart';

import '../models/sesi_makan.dart';
import '../utils/ikon.dart';
import '../utils/warna_respons.dart';

/// Lencana kecil "Landai / Sedang / Lonjakan / Belum lengkap".
///
/// Dipakai daftar Riwayat dan kepala Ringkasan Sesi supaya sesi yang sama
/// terbaca sama di kedua tempat.
///
/// Warnanya tidak pernah sendirian: ikon dan katanya selalu ikut, jadi keadaan
/// sesi tetap terbaca oleh siapa pun yang tidak membedakan warnanya.
class LencanaKualitas extends StatelessWidget {
  const LencanaKualitas({
    super.key,
    required this.kualitas,
    this.ukuranTeks = 10,
    this.diAtasLatarBerwarna = false,
  });

  final KualitasRespons kualitas;
  final double ukuranTeks;

  /// Lencana ini berdiri di atas permukaan yang **sudah** memakai warna kualitas
  /// yang sama — kartu hasil di Ringkasan Sesi.
  ///
  /// Tanpa ini ia lenyap: latar lencananya dan latar kartunya persis satu warna,
  /// sehingga yang tersisa hanya teks mengambang. Paling parah pada "Sedang",
  /// yang latarnya abu-abu kehijauan nyaris sama dengan kartunya. Isian putih
  /// mengembalikan bentuk lencananya tanpa mengubah warna teks dan ikonnya, yang
  /// tetap membawa arti.
  final bool diAtasLatarBerwarna;

  @override
  Widget build(BuildContext context) {
    final warna = warnaKualitas(kualitas);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: diAtasLatarBerwarna ? 10 : 8,
        vertical: diAtasLatarBerwarna ? 6 : 4,
      ),
      decoration: BoxDecoration(
        color: diAtasLatarBerwarna ? Colors.white : warna.latar,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            ikonKualitasRespons(kualitas),
            size: ukuranTeks + 1,
            color: warna.teks,
          ),
          const SizedBox(width: 4),
          Text(
            kualitas.label,
            style: TextStyle(
              fontSize: ukuranTeks,
              fontWeight: FontWeight.bold,
              color: warna.teks,
            ),
          ),
        ],
      ),
    );
  }
}
