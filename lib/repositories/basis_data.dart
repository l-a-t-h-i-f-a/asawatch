/// Basis data lokal — docs/rencana-produksi.md §3.1 (Tahap A2).
///
/// Bentuk tabelnya mengikuti model di [../models/sesi_makan.dart], bukan
/// sebaliknya. Tiga keputusan yang menjelaskan sisanya:
///
/// 1. **Id memakai teks, bukan autoincrement.** `SesiMakan.id` sudah menjadi
///    identitas di seluruh aplikasi (kunci dedup sampel memakainya), dan
///    sinkronisasi lintas perangkat nanti (K5) menuntut id yang tidak
///    bergantung pada urutan penyisipan.
/// 2. **Waktu disimpan sebagai epoch mikrodetik UTC**, bukan teks. Bandingannya
///    murah dan tidak bergantung pada zona waktu perangkat.
/// 3. **Nutrisi diratakan menjadi enam kolom**, tidak di-JSON-kan. Kolomnya
///    tetap, jarang berubah, dan meng-agregasi karbohidrat lewat SQL adalah
///    hal pertama yang akan diminta Analisis begitu riwayatnya panjang.
///
/// Satu konsekuensi yang mengikat: status disimpan lewat `textEnum`, jadi yang
/// masuk basis data adalah **nama** anggotanya (`selesai`, `tidakLengkap`, …).
/// Mengganti nama anggota `StatusSesi`/`StatusSampel` karena itu adalah
/// perubahan skema yang menuntut migrasi; mengubah urutannya tidak.
library;

import 'package:drift/drift.dart';

import '../models/sesi_makan.dart';

part 'basis_data.g.dart';

/// Satu sesi makan. Sampel dan hasil deteksinya ada di tabel terpisah.
///
/// Sesi yang masih aktif **juga** muat di sini — `status` menampung `draft`
/// hingga `dibatalkan` — meskipun untuk sekarang hanya sesi yang sudah berakhir
/// yang benar-benar ditulis. Lihat catatan di `SesiRepositoryDrift`.
class TabelSesi extends Table {
  TextColumn get id => text()();
  TextColumn get fotoPath => text()();
  IntColumn get waktuFoto => integer()();
  IntColumn get t0 => integer().nullable()();
  TextColumn get status => textEnum<StatusSesi>()();

  @override
  Set<Column> get primaryKey => {id};
}

/// Empat titik ukur per sesi. `index` bermakna tetap (lihat `labelTitikSampel`),
/// jadi ia ikut menjadi kunci primer — bukan sekadar kolom urutan.
///
/// Metrik yang gagal diukur disimpan `NULL`, bukan sentinel `0`. Sentinel itu
/// milik protokol BLE dan sudah dikonversi jauh sebelum sampai ke sini.
class TabelSampel extends Table {
  TextColumn get sesiId =>
      text().references(TabelSesi, #id, onDelete: KeyAction.cascade)();
  IntColumn get index => integer()();
  IntColumn get detikRelatifT0 => integer()();
  TextColumn get status => textEnum<StatusSampel>()();
  BoolColumn get dariBuffer => boolean().withDefault(const Constant(false))();
  IntColumn get gulaDarah => integer().nullable()();
  IntColumn get detakJantung => integer().nullable()();
  IntColumn get sistolik => integer().nullable()();
  IntColumn get diastolik => integer().nullable()();
  IntColumn get spo2 => integer().nullable()();

  @override
  Set<Column> get primaryKey => {sesiId, index};
}

/// Hasil analisis nutrisi, satu baris per sesi (relasi 1–0..1).
///
/// `total*` disimpan terpisah dari penjumlahan itemnya dengan sengaja: sebelum
/// dikoreksi user, total dari layanan deteksi tidak harus sama persis dengan
/// jumlah per-itemnya, dan menghitung ulang saat memuat akan diam-diam
/// mengubah data yang pernah ditampilkan.
class TabelHasilDeteksi extends Table {
  TextColumn get sesiId =>
      text().references(TabelSesi, #id, onDelete: KeyAction.cascade)();
  TextColumn get indeksGlikemikPerkiraan => text()();
  RealColumn get keyakinan => real()();
  BoolColumn get dikoreksiUser => boolean()();
  RealColumn get totalKalori => real()();
  RealColumn get totalKarbohidrat => real()();
  RealColumn get totalProtein => real()();
  RealColumn get totalLemak => real()();
  RealColumn get totalGulaTotal => real()();
  RealColumn get totalSerat => real()();

  @override
  Set<Column> get primaryKey => {sesiId};
}

/// Item makanan di dalam satu hasil deteksi.
///
/// `urutan` dipertahankan karena `HasilDeteksi.ringkasanNama` merangkai nama
/// sesuai urutannya, dan judul kartu yang berubah-ubah antar restart akan
/// terbaca sebagai bug.
class TabelItemMakanan extends Table {
  TextColumn get sesiId =>
      text().references(TabelSesi, #id, onDelete: KeyAction.cascade)();
  IntColumn get urutan => integer()();
  TextColumn get nama => text()();
  TextColumn get porsi => text()();
  RealColumn get estimasiGram => real()();
  RealColumn get kalori => real()();
  RealColumn get karbohidrat => real()();
  RealColumn get protein => real()();
  RealColumn get lemak => real()();
  RealColumn get gulaTotal => real()();
  RealColumn get serat => real()();

  @override
  Set<Column> get primaryKey => {sesiId, urutan};
}

/// Anchor waktu jam tangan — docs/protokol-jam.md §4.2, §4.5.
///
/// Jam tidak punya RTC, jadi tabel inilah satu-satunya tempat pengetahuan waktu
/// berada. Anchor yang hilang membuat seluruh isi buffer jam tidak dapat
/// diterjemahkan, dan itu tidak bisa diperbaiki belakangan — karena itu ia
/// disimpan, bukan disimpan di memori.
///
/// **Sengaja mengizinkan lebih dari satu baris per `bootId`.** Untuk sekarang
/// yang dipakai hanya yang terbaru, tetapi koreksi drift osilator (§4.4) butuh
/// dua anchor dalam satu boot untuk mengukur laju sebenarnya. Menyediakan
/// tempatnya sekarang jauh lebih murah daripada memigrasi data pengguna nanti.
class TabelAnchorWaktu extends Table {
  IntColumn get bootId => integer()();
  IntColumn get uptimeS => integer()();
  IntColumn get epoch => integer()();

  /// Satu boot bisa punya banyak anchor, tetapi tidak dua pada uptime yang
  /// sama — anchor kedua pada detik yang sama adalah penulisan ulang, bukan
  /// pengukuran baru.
  @override
  Set<Column> get primaryKey => {bootId, uptimeS};
}

@DriftDatabase(
  tables: [
    TabelSesi,
    TabelSampel,
    TabelHasilDeteksi,
    TabelItemMakanan,
    TabelAnchorWaktu,
  ],
)
class BasisData extends _$BasisData {
  BasisData(super.e);

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
    },
    beforeOpen: (details) async {
      // Tanpa ini SQLite mengabaikan seluruh `references(...)` di atas, dan
      // sampel yatim baru ketahuan jauh setelah sesinya terhapus.
      await customStatement('PRAGMA foreign_keys = ON');
    },
    // Langkahnya ditulis satu per satu dan berurutan, sehingga perangkat yang
    // lama tidak dibuka — melompati beberapa versi sekaligus — tetap melewati
    // setiap langkah. Versi yang tidak dikenal melempar, bukan diam: menaikkan
    // `schemaVersion` tanpa menulis langkahnya harus gagal saat dites, bukan di
    // perangkat pengguna.
    onUpgrade: (m, dari, ke) async {
      for (var v = dari; v < ke; v++) {
        switch (v) {
          case 1: // v1 → v2: anchor waktu jam tangan (protokol-jam.md §4)
            await m.createTable(tabelAnchorWaktu);
          default:
            throw UnsupportedError(
              'Belum ada migrasi dari skema v$v ke v${v + 1}. '
              'Tambahkan langkahnya di BasisData.migration sebelum menaikkan '
              'schemaVersion.',
            );
        }
      }
    },
  );
}
