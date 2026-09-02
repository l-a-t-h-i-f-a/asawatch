/// Jam yang sudah dipasangkan — docs/rencana-produksi.md §4.1 (`sambungkan()`).
///
/// Yang disimpan cuma dua string, tetapi keduanya memikul satu pembedaan yang
/// sudah dipakai seluruh UI: `StatusPerangkat.belumDipasangkan`. Jam yang belum
/// pernah dipasangkan harus ditawari **pemindaian**; jam yang sudah dipasangkan
/// tetapi sedang di luar jangkauan harus ditawari **menunggu/menyambung ulang**,
/// dengan penjelasan bahwa sampelnya menumpuk di buffer. Tanpa penyimpanan ini,
/// setiap kali aplikasi dibuka jam yang sudah dipasangkan akan terlihat seperti
/// jam yang tidak pernah ada.
///
/// `SharedPreferences`, bukan basis data, dengan alasan yang sama seperti
/// profil: dua nilai skalar tanpa relasi.
///
/// **Id perangkat berbeda per platform** — MAC di Android, UUID milik CoreBluetooth
/// di iOS (protokol §2.2) — jadi nilai ini tidak pernah boleh ikut disinkronkan
/// ke perangkat lain. Yang stabil lintas platform adalah `serial` di handshake,
/// dan ia hanya dipakai untuk mengenali, bukan untuk menyambung.
library;

import 'package:shared_preferences/shared_preferences.dart';

class PerangkatTersimpan {
  const PerangkatTersimpan({required this.id, required this.nama});

  final String id;
  final String nama;
}

abstract class PerangkatRepository {
  Future<PerangkatTersimpan?> muat();
  Future<void> simpan(PerangkatTersimpan perangkat);

  /// Melupakan jam. Dipakai saat user memutus pemasangan secara sengaja —
  /// bukan saat koneksi putus, yang justru harus tetap diingat.
  Future<void> lupakan();
}

class PerangkatRepositoryPrefs implements PerangkatRepository {
  static const _kunciId = 'jam_id';
  static const _kunciNama = 'jam_nama';

  @override
  Future<PerangkatTersimpan?> muat() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kunciId);
    final nama = prefs.getString(_kunciNama);
    if (id == null || id.isEmpty) return null;
    return PerangkatTersimpan(id: id, nama: nama ?? 'AsaWatch');
  }

  @override
  Future<void> simpan(PerangkatTersimpan perangkat) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kunciId, perangkat.id);
    await prefs.setString(_kunciNama, perangkat.nama);
  }

  @override
  Future<void> lupakan() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kunciId);
    await prefs.remove(_kunciNama);
  }
}

/// Pasangan di memori, untuk test.
class PerangkatRepositoryMemori implements PerangkatRepository {
  PerangkatRepositoryMemori({PerangkatTersimpan? awal}) : _tersimpan = awal;

  PerangkatTersimpan? _tersimpan;

  @override
  Future<PerangkatTersimpan?> muat() async => _tersimpan;

  @override
  Future<void> simpan(PerangkatTersimpan perangkat) async =>
      _tersimpan = perangkat;

  @override
  Future<void> lupakan() async => _tersimpan = null;
}
