/// Warna indikator kualitas respons, dipakai bersama oleh daftar Riwayat dan
/// Ringkasan Sesi.
///
/// Sengaja satu sumber: sebelumnya Riwayat memilikinya sendiri sementara
/// Ringkasan Sesi selalu hijau, sehingga sesi "Lonjakan" terlihat sama
/// tenangnya dengan sesi "Landai" begitu dibuka.
library;

import 'package:flutter/material.dart';

import '../models/sesi_makan.dart';

typedef WarnaRespons = ({Color latar, Color teks});

WarnaRespons warnaKualitas(KualitasRespons kualitas) => switch (kualitas) {
  KualitasRespons.landai => (
    latar: const Color(0xFFE2F6F0),
    teks: const Color(0xFF0EAD69),
  ),
  KualitasRespons.sedang => (
    latar: const Color(0xFFE5EDE9),
    teks: const Color(0xFF6B807B),
  ),
  KualitasRespons.lonjakan => (
    latar: const Color(0xFFFFEBEE),
    teks: Colors.red,
  ),
  KualitasRespons.belumLengkap => (
    latar: const Color(0xFFE2EBE8),
    teks: const Color(0xFF8FA7A1),
  ),
};
