/// Gaya bilah sistem (status bar & navigation bar) untuk kedua jenis latar
/// yang dipakai aplikasi ini.
///
/// Hampir seluruh layar berlatar terang (`0xFFF4FAF7` / putih), jadi ikon
/// bilah statusnya harus **gelap** agar terbaca — itulah bawaan aplikasi.
/// Satu-satunya pengecualian adalah layar kamera yang berlatar hitam, yang
/// memasang [gayaSistemGelap] lewat `AnnotatedRegion`.
library;

import 'package:flutter/material.dart' show Brightness, Color, Colors;
import 'package:flutter/services.dart';

/// Latar terang → ikon gelap.
///
/// `statusBarIconBrightness` dibaca Android, `statusBarBrightness` dibaca iOS
/// (dan artinya kebalikan: itu kecerahan **latarnya**, bukan ikonnya).
const SystemUiOverlayStyle gayaSistemTerang = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.dark,
  statusBarBrightness: Brightness.light,
  systemNavigationBarColor: Color(0xFFF4FAF7),
  systemNavigationBarIconBrightness: Brightness.dark,
);

/// Latar gelap → ikon terang. Dipakai layar kamera deteksi makanan.
const SystemUiOverlayStyle gayaSistemGelap = SystemUiOverlayStyle(
  statusBarColor: Colors.transparent,
  statusBarIconBrightness: Brightness.light,
  statusBarBrightness: Brightness.dark,
  systemNavigationBarColor: Colors.black,
  systemNavigationBarIconBrightness: Brightness.light,
);
