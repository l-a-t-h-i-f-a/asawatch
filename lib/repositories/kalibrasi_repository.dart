/// Penyimpanan kalibrasi tekanan darah — docs/rencana-produksi.md §3.1.
///
/// Ditunda dari Tahap A dengan alasan yang eksplisit: selama `kirimKalibrasi()`
/// hanya menuju jam palsu, tidak ada yang menuntut nilainya bertahan. Begitu
/// perintahnya benar-benar sampai ke flash jam (§5.1 `SET_KALIBRASI`), aplikasi
/// yang lupa pernah mengalibrasi menjadi masalah nyata: jam mengoreksi setiap
/// pembacaan, dan layar kalibrasi menampilkan "belum pernah dikalibrasi".
library;

import 'package:drift/drift.dart';

import '../models/sesi_makan.dart';
import 'basis_data.dart';

abstract class KalibrasiRepository {
  Future<void> simpan(Kalibrasi kalibrasi);

  /// Kalibrasi terbaru, null bila jam belum pernah dikalibrasi dari HP ini.
  Future<Kalibrasi?> terbaru();
}

class KalibrasiRepositoryDrift implements KalibrasiRepository {
  KalibrasiRepositoryDrift(this.db);

  final BasisData db;

  @override
  Future<void> simpan(Kalibrasi kalibrasi) async {
    await db
        .into(db.tabelKalibrasi)
        .insertOnConflictUpdate(
          TabelKalibrasiCompanion.insert(
            // `Value(...)` karena kolom integer yang menjadi satu-satunya kunci
            // primer adalah alias rowid di SQLite, sehingga drift menganggapnya
            // boleh dikosongkan. Di sini ia tidak boleh: waktunya adalah datanya.
            waktu: Value(kalibrasi.waktu.toUtc().microsecondsSinceEpoch),
            sistolikReferensi: kalibrasi.sistolikReferensi,
            diastolikReferensi: kalibrasi.diastolikReferensi,
            sistolikJam: kalibrasi.sistolikJam,
            diastolikJam: kalibrasi.diastolikJam,
          ),
        );
  }

  @override
  Future<Kalibrasi?> terbaru() async {
    final b =
        await (db.select(db.tabelKalibrasi)
              ..orderBy([
                (t) =>
                    OrderingTerm(expression: t.waktu, mode: OrderingMode.desc),
              ])
              ..limit(1))
            .getSingleOrNull();
    if (b == null) return null;

    return Kalibrasi(
      waktu: DateTime.fromMicrosecondsSinceEpoch(
        b.waktu,
        isUtc: true,
      ).toLocal(),
      sistolikReferensi: b.sistolikReferensi,
      diastolikReferensi: b.diastolikReferensi,
      sistolikJam: b.sistolikJam,
      diastolikJam: b.diastolikJam,
    );
  }
}

/// Kalibrasi di memori — peran yang sama dengan `SesiRepositoryMemori`.
class KalibrasiRepositoryMemori implements KalibrasiRepository {
  Kalibrasi? _terakhir;

  @override
  Future<void> simpan(Kalibrasi kalibrasi) async => _terakhir = kalibrasi;

  @override
  Future<Kalibrasi?> terbaru() async => _terakhir;
}
