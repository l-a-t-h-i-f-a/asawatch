/// Penyimpanan anchor waktu — docs/protokol-jam.md §4.5.
///
/// Belum ada penulisnya: yang memasang anchor adalah `BleAsliService` di Tahap
/// B, saat perintah `ANCHOR_WAKTU` dikirim pada tiap koneksi. Tabelnya ada
/// lebih dulu karena keputusan skema paling murah diambil selagi belum ada data
/// pengguna — begitu aplikasi terpasang, menambah tabel berarti menulis migrasi
/// dan menguji jalur upgrade-nya.
library;

import 'package:drift/drift.dart';

import '../models/anchor_waktu.dart';
import 'basis_data.dart';

abstract class AnchorRepository {
  /// Mencatat anchor baru. Anchor pada `(bootId, uptimeS)` yang sama ditimpa.
  Future<void> simpan(AnchorWaktu anchor);

  /// Anchor terbaru untuk satu boot, atau null bila boot itu tidak pernah
  /// tersambung sama sekali.
  ///
  /// Null di sini bukan error, melainkan justru keadaan yang protokol §4.3
  /// namai `waktu_tidak_pasti`: entri dari boot itu tidak akan pernah bisa
  /// diterjemahkan, karena tidak ada yang tahu berapa lama jam mati sebelumnya.
  Future<AnchorWaktu?> terbaruUntuk(int bootId);

  /// Seluruh anchor satu boot, terlama dulu.
  ///
  /// Dipakai koreksi drift osilator (§4.4), yang butuh dua titik untuk mengukur
  /// laju sebenarnya. Belum dipakai di v1.
  Future<List<AnchorWaktu>> semuaUntuk(int bootId);
}

class AnchorRepositoryDrift implements AnchorRepository {
  AnchorRepositoryDrift(this.db);

  final BasisData db;

  @override
  Future<void> simpan(AnchorWaktu anchor) async {
    await db
        .into(db.tabelAnchorWaktu)
        .insertOnConflictUpdate(
          TabelAnchorWaktuCompanion.insert(
            bootId: anchor.bootId,
            uptimeS: anchor.uptimeS,
            epoch: anchor.epoch.toUtc().microsecondsSinceEpoch,
          ),
        );
  }

  @override
  Future<AnchorWaktu?> terbaruUntuk(int bootId) async {
    final baris =
        await (db.select(db.tabelAnchorWaktu)
              ..where((t) => t.bootId.equals(bootId))
              // "Terbaru" diukur dengan uptime, bukan epoch: uptime adalah satu-
              // satunya besaran yang pasti monoton dalam satu boot. Jam HP bisa
              // mundur (koreksi NTP, user mengubah waktu) tanpa uptime ikut
              // mundur.
              ..orderBy([
                (t) => OrderingTerm(
                  expression: t.uptimeS,
                  mode: OrderingMode.desc,
                ),
              ])
              ..limit(1))
            .getSingleOrNull();

    return baris == null ? null : _keModel(baris);
  }

  @override
  Future<List<AnchorWaktu>> semuaUntuk(int bootId) async {
    final baris =
        await (db.select(db.tabelAnchorWaktu)
              ..where((t) => t.bootId.equals(bootId))
              ..orderBy([(t) => OrderingTerm(expression: t.uptimeS)]))
            .get();

    return baris.map(_keModel).toList();
  }

  static AnchorWaktu _keModel(TabelAnchorWaktuData b) => AnchorWaktu(
    bootId: b.bootId,
    uptimeS: b.uptimeS,
    epoch: DateTime.fromMicrosecondsSinceEpoch(b.epoch, isUtc: true).toLocal(),
  );
}
