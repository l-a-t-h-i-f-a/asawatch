/// Kotak masuk entri jam — docs/protokol-jam.md §6.
///
/// Ada satu kalimat di protokol yang memaksa berkas ini berdiri: *"Aplikasi
/// hanya boleh meng-ack setelah data tersimpan permanen di DB lokal."* Jam
/// menghapus entri begitu di-ack, jadi ack yang mendahului penulisan berarti
/// data hilang bila aplikasi mati sedetik kemudian. Kalimat itulah yang membuat
/// Tahap A benar-benar memblokir Tahap B, bukan sekadar lebih murah didahulukan.
///
/// Alur satu entri, dari kabel sampai layar:
///
/// ```
/// notify → decode → simpan()      ← durabel di sini
///                 → ACK_EVENT     ← baru sekarang jam boleh lupa
///                 → stream        → controller → sesi ditulis (diproses = 1)
/// ```
///
/// Baris yang belum `diproses` saat aplikasi start adalah entri yang sempat
/// di-ack tetapi sesinya tidak keburu ditulis — persis celah yang aturan di atas
/// ingin selamatkan. `BleAsliService.mulai()` memutarnya ulang ke stream yang
/// sama seolah jam baru mengirimkannya.
///
/// Berkas ini mengimpor tipe protokol dari [../services/protokol_jam.dart] dengan
/// sengaja: yang disimpan memang entri protokol mentah, bukan model domain.
/// Menerjemahkannya lebih dulu ke `Sampel` akan membuang `seq` dan `boot_id` —
/// dua hal yang justru dibutuhkan untuk memutar ulang.
library;

import 'package:drift/drift.dart';

import '../services/protokol_jam.dart';
import 'basis_data.dart';

/// 0 dan 1 adalah nilai kolom `jenis`, bukan indeks enum Dart. Keduanya sengaja
/// tidak `textEnum`: mengganti nama tipe Dart tidak boleh mengubah isi basis
/// data.
const int jenisEntriSampel = 0;
const int jenisEntriPeristiwa = 1;

abstract class EntriJamRepository {
  /// Menulis satu entri. Harus selesai **sebelum** `ACK_EVENT` dikirim.
  Future<void> simpan(EntriJam entri);

  /// Entri yang sudah di-ack ke jam tetapi belum ikut tersimpan di sesinya,
  /// terlama dulu. Urutan penting: sebuah sampel tidak boleh mendahului
  /// peristiwa `TOMBOL_SELESAI_MAKAN` yang memberi sesinya t0.
  Future<List<EntriJam>> belumDiproses();

  /// `uptime_s` dan `boot_id` saat tombol "Selesai Makan" ditekan, per sesi.
  ///
  /// Inilah yang membuat `detikRelatifT0` tetap bisa dihitung sebagai **selisih
  /// dua pencacah** (§5.3) setelah aplikasi ditutup dan dibuka lagi. Alternatifnya
  /// — mengurangkan dua waktu kalender — akan ikut membawa setiap kesalahan
  /// anchor ke dalam bentuk kurvanya, padahal justru bentuk kurva itulah yang
  /// kebal terhadap anchor yang meleset.
  ///
  /// Tidak ada kolom baru untuk ini: peristiwa `TOMBOL_SELESAI_MAKAN` sudah
  /// tersimpan apa adanya di sini, lengkap dengan kedua angkanya.
  Future<Map<String, ({int bootId, int uptimeS})>> t0PerSesi();

  /// Membuang riwayat entri yang sudah diproses, menyisakan [simpanTerakhir]
  /// baris terbaru sebagai jejak diagnostik (§9.2 rencana produksi).
  ///
  /// Yang belum diproses tidak pernah dibuang di sini: satu-satunya salinannya
  /// ada di sini, karena jam sudah menghapus miliknya.
  Future<void> pangkas({int simpanTerakhir});
}

class EntriJamRepositoryDrift implements EntriJamRepository {
  EntriJamRepositoryDrift(this.db);

  final BasisData db;

  @override
  Future<void> simpan(EntriJam entri) async {
    final sesiId = switch (entri) {
      EntriSampel(:final sesiId) => sesiId,
      EntriPeristiwa(:final sesiId) => sesiId,
    };

    await db
        .into(db.tabelEntriJam)
        .insert(
          TabelEntriJamCompanion.insert(
            jenis: entri is EntriSampel
                ? jenisEntriSampel
                : jenisEntriPeristiwa,
            seq: entri.seq,
            bootId: entri.bootId,
            uptimeS: entri.uptimeS,
            dariBuffer: entri.dariBuffer,
            waktuTidakPasti: entri.waktuTidakPasti,
            sesiId: Value(sesiId),
            indexSampel: Value(entri is EntriSampel ? entri.index : null),
            kodePeristiwa: Value(
              entri is EntriPeristiwa ? entri.jenis.kode : null,
            ),
            payload: Value(entri is EntriPeristiwa ? entri.payload : null),
            gulaDarah: Value(entri is EntriSampel ? entri.gulaDarah : null),
            detakJantung: Value(
              entri is EntriSampel ? entri.detakJantung : null,
            ),
            sistolik: Value(entri is EntriSampel ? entri.sistolik : null),
            diastolik: Value(entri is EntriSampel ? entri.diastolik : null),
            spo2: Value(entri is EntriSampel ? entri.spo2 : null),
            // Entri tanpa sesi tidak akan pernah ikut tertulis di dalam sebuah
            // sesi, jadi menunggunya berarti menumpuk baris yang tidak seorang
            // pun akan proses — dan memutarnya ulang setiap kali aplikasi start,
            // selamanya. Ack-nya tetap menyusul penulisan ini; itu saja aturannya.
            //
            // Dua bentuk "tanpa sesi", dan keduanya harus dihitung: peristiwa
            // yang `sesiId`-nya null (BOOT, BUFFER_PENUH), dan entri yang
            // `sesiId`-nya 16 byte nol — sampel jawaban `UKUR_SEKARANG`, yang
            // memang terjadi di luar sesi mana pun (§5.1).
            diproses: Value(!sesiIdNyata(sesiId)),
          ),
        );
  }

  @override
  Future<List<EntriJam>> belumDiproses() async {
    final baris =
        await (db.select(db.tabelEntriJam)
              ..where((t) => t.diproses.equals(false))
              ..orderBy([(t) => OrderingTerm(expression: t.id)]))
            .get();

    return [for (final b in baris) ?_keEntri(b)];
  }

  @override
  Future<Map<String, ({int bootId, int uptimeS})>> t0PerSesi() async {
    final baris =
        await (db.select(db.tabelEntriJam)
              ..where(
                (t) =>
                    t.jenis.equals(jenisEntriPeristiwa) &
                    t.kodePeristiwa.equals(
                      JenisPeristiwa.tombolSelesaiMakan.kode,
                    ) &
                    t.sesiId.isNotNull(),
              )
              // Tombolnya hanya bisa ditekan sekali per sesi, tetapi entrinya
              // bisa datang dua kali (pengiriman at-least-once, §6). Yang
              // pertama yang benar; yang kedua adalah salinan yang sama.
              ..orderBy([(t) => OrderingTerm(expression: t.id)]))
            .get();

    return {
      for (final b in baris) b.sesiId!: (bootId: b.bootId, uptimeS: b.uptimeS),
    };
  }

  @override
  Future<void> pangkas({int simpanTerakhir = 256}) async {
    final batas =
        await (db.select(db.tabelEntriJam)
              ..where((t) => t.diproses.equals(true))
              ..orderBy([
                (t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc),
              ])
              ..limit(1, offset: simpanTerakhir))
            .getSingleOrNull();
    if (batas == null) return;

    await (db.delete(db.tabelEntriJam)..where(
          (t) => t.diproses.equals(true) & t.id.isSmallerOrEqualValue(batas.id),
        ))
        .go();
  }

  /// null untuk baris yang tidak bisa lagi dibaca — kode peristiwa dari firmware
  /// yang lebih muda, misalnya. Dibuang di sini, bukan dilempar: satu baris
  /// aneh tidak boleh menahan seluruh pemutaran ulang.
  static EntriJam? _keEntri(TabelEntriJamData b) {
    if (b.jenis == jenisEntriSampel) {
      final sesiId = b.sesiId;
      final index = b.indexSampel;
      if (sesiId == null || index == null) return null;

      return EntriSampel(
        seq: b.seq,
        sesiId: sesiId,
        index: index,
        bootId: b.bootId,
        uptimeS: b.uptimeS,
        // Entri yang diputar ulang dari basis data adalah, menurut definisi,
        // entri yang datang terlambat — sama seperti yang datang dari buffer
        // jam. UI memang membedakan keduanya dari yang realtime.
        dariBuffer: true,
        waktuTidakPasti: b.waktuTidakPasti,
        gulaDarah: b.gulaDarah,
        detakJantung: b.detakJantung,
        sistolik: b.sistolik,
        diastolik: b.diastolik,
        spo2: b.spo2,
      );
    }

    final kode = b.kodePeristiwa;
    if (kode == null) return null;
    final JenisPeristiwa jenis;
    try {
      jenis = JenisPeristiwa.dariKode(kode);
    } on GalatProtokol {
      return null;
    }

    return EntriPeristiwa(
      seq: b.seq,
      jenis: jenis,
      sesiId: b.sesiId,
      bootId: b.bootId,
      uptimeS: b.uptimeS,
      dariBuffer: true,
      waktuTidakPasti: b.waktuTidakPasti,
      payload: b.payload ?? 0,
    );
  }
}

/// Kotak masuk di memori, untuk test dan untuk `FakeBleService` — yang tidak
/// pernah menyentuh basis data sungguhan.
class EntriJamRepositoryMemori implements EntriJamRepository {
  final List<EntriJam> _entri = [];

  /// Semua yang pernah ditulis, urut masuk — dipakai test untuk memastikan
  /// entri benar-benar disimpan sebelum ack.
  List<EntriJam> get semua => List.unmodifiable(_entri);

  final Set<EntriJam> _diproses = {};

  @override
  Future<void> simpan(EntriJam entri) async {
    _entri.add(entri);
    final sesiId = switch (entri) {
      EntriSampel(:final sesiId) => sesiId,
      EntriPeristiwa(:final sesiId) => sesiId,
    };
    if (sesiId == null) _diproses.add(entri);
  }

  void tandaiDiproses(String sesiId) {
    for (final e in _entri) {
      final id = switch (e) {
        EntriSampel(:final sesiId) => sesiId,
        EntriPeristiwa(:final sesiId) => sesiId,
      };
      if (id == sesiId) _diproses.add(e);
    }
  }

  @override
  Future<List<EntriJam>> belumDiproses() async => [
    for (final e in _entri)
      if (!_diproses.contains(e)) e,
  ];

  @override
  Future<Map<String, ({int bootId, int uptimeS})>> t0PerSesi() async => {
    for (final e in _entri)
      if (e is EntriPeristiwa &&
          e.jenis == JenisPeristiwa.tombolSelesaiMakan &&
          e.sesiId != null)
        e.sesiId!: (bootId: e.bootId, uptimeS: e.uptimeS),
  };

  @override
  Future<void> pangkas({int simpanTerakhir = 256}) async {
    final buang = _entri.where(_diproses.contains).toList();
    if (buang.length <= simpanTerakhir) return;
    for (final e in buang.take(buang.length - simpanTerakhir)) {
      _entri.remove(e);
      _diproses.remove(e);
    }
  }
}
