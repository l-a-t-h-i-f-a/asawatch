import '../models/contoh_sesi.dart';
import '../models/sesi_makan.dart';

/// Kontrak analisis nutrisi dari foto (§12.5).
abstract class NutrisiService {
  Future<HasilDeteksi> analisis(String fotoPath);
}

/// Analisis palsu untuk Fase UI: mengembalikan angka yang sudah dipakai
/// halaman deteksi makanan hari ini, ditambah gula total, serat, dan
/// keyakinan.
///
/// [jeda] sengaja tidak nol supaya kondisi `hasil == null` — yang normal, bukan
/// error — benar-benar terlihat di UI.
class FakeNutrisiService implements NutrisiService {
  const FakeNutrisiService({this.jeda = const Duration(milliseconds: 600)});

  final Duration jeda;

  @override
  Future<HasilDeteksi> analisis(String fotoPath) async {
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    return contohHasilDeteksi();
  }
}
