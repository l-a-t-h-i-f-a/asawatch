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

/// Warna penilaian sesi puasa, dari keluarga warna yang sama dengan
/// [warnaKualitas] supaya Riwayat tetap terbaca sebagai satu sistem: yang
/// tenang hijau, yang perlu perhatian jingga, yang berbahaya merah.
WarnaRespons warnaKondisiPuasa(KondisiPuasa kondisi) => switch (kondisi) {
  KondisiPuasa.stabil => warnaKualitas(KualitasRespons.landai),
  KondisiPuasa.turun => warnaKualitas(KualitasRespons.sedang),
  KondisiPuasa.rendah => (
    latar: const Color(0xFFFFF4E5),
    teks: const Color(0xFFB4761E),
  ),
  KondisiPuasa.sangatRendah => warnaKualitas(KualitasRespons.lonjakan),
  KondisiPuasa.belumLengkap => warnaKualitas(KualitasRespons.belumLengkap),
};
