/// Pemetaan ikon untuk nilai-nilai domain.
///
/// Sengaja dipisah dari `models/`, supaya model tetap murni data dan tidak
/// bergantung pada Flutter. Ikon hanya boleh menegaskan label yang sudah ada,
/// tidak pernah menggantikannya — teks tetap yang menjelaskan.
library;

import 'package:flutter/material.dart';

import '../models/sesi_makan.dart';

/// null berarti waktu sesi tidak diketahui (docs/protokol-jam.md §4.3) — ikon
/// tanda tanya, bukan ikon salah satu waktu makan yang kebetulan dipilih.
IconData ikonWaktuMakan(WaktuMakan? waktu) => switch (waktu) {
  WaktuMakan.sarapan => Icons.wb_twilight_rounded,
  WaktuMakan.makanSiang => Icons.light_mode_rounded,
  WaktuMakan.makanMalam => Icons.nightlight_round,
  WaktuMakan.camilan => Icons.cookie_rounded,
  null => Icons.help_outline_rounded,
};

IconData ikonKualitasRespons(KualitasRespons kualitas) => switch (kualitas) {
  KualitasRespons.landai => Icons.trending_flat_rounded,
  KualitasRespons.sedang => Icons.trending_up_rounded,
  KualitasRespons.lonjakan => Icons.priority_high_rounded,
  KualitasRespons.belumLengkap => Icons.more_horiz_rounded,
};

IconData ikonStatusSesi(StatusSesi status) => switch (status) {
  StatusSesi.draft => Icons.restaurant_rounded,
  StatusSesi.menungguPerangkat => Icons.watch_off_rounded,
  StatusSesi.berjalan => Icons.timelapse_rounded,
  StatusSesi.selesai => Icons.check_circle_rounded,
  StatusSesi.tidakLengkap => Icons.error_outline_rounded,
  StatusSesi.dibatalkan => Icons.cancel_outlined,
};

/// Ikon per makro pada ringkasan nutrisi.
const Map<String, IconData> ikonMakro = {
  'Kalori': Icons.local_fire_department_rounded,
  'Karbohidrat': Icons.rice_bowl_rounded,
  'Protein': Icons.egg_alt_rounded,
  'Lemak': Icons.opacity_rounded,
  'Gula Total': Icons.cookie_rounded,
  'Serat': Icons.grass_rounded,
};

/// Ikon metrik, dipakai halaman detail dan pintu masuknya.
const IconData ikonGulaDarah = Icons.water_drop_rounded;
const IconData ikonTekananDarah = Icons.speed_rounded;
const IconData ikonDetakJantung = Icons.favorite_rounded;
