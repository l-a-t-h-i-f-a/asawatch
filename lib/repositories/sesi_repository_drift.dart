/// Implementasi [SesiRepository] di atas SQLite — docs/rencana-produksi.md §3.1.
///
/// Seluruh berkas ini adalah penerjemahan antara model dan tabel. Tidak ada
/// aturan domain di sini: verdict, kualitas respons, dan waktu pemulihan tetap
/// dihitung di `SesiMakan`, tidak pernah disimpan, dan karena itu tidak punya
/// kolom. Menambah kolom turunan ke tabel berarti dua sumber kebenaran yang
/// bisa berselisih setelah rumusnya diperbaiki.
library;

import 'package:drift/drift.dart';

import '../models/sesi_makan.dart';
import 'basis_data.dart';
import 'sesi_repository.dart';

class SesiRepositoryDrift implements SesiRepository {
  SesiRepositoryDrift(this.db);

  final BasisData db;

  @override
  Future<List<SesiMakan>> muatSemua() async {
    // Urutan "terbaru di depan" ditegakkan di SQL, bukan diwariskan dari urutan
    // penyisipan — dan memakai kunci yang sama dengan yang dipakai aplikasi
    // untuk mengurutkan sesi: t0 bila sudah ada, jika tidak waktu fotonya.
    final barisSesi =
        await (db.select(db.tabelSesi)..orderBy([
              (t) => OrderingTerm(
                expression: coalesce<int>([t.t0, t.waktuFoto]),
                mode: OrderingMode.desc,
              ),
            ]))
            .get();
    if (barisSesi.isEmpty) return const [];

    final id = barisSesi.map((s) => s.id).toList();

    // Tiga query, bukan satu per sesi: riwayat panjang tidak boleh berubah
    // menjadi ratusan pembacaan saat aplikasi start.
    final barisSampel = await (db.select(
      db.tabelSampel,
    )..where((t) => t.sesiId.isIn(id))).get();
    final barisHasil = await (db.select(
      db.tabelHasilDeteksi,
    )..where((t) => t.sesiId.isIn(id))).get();
    final barisItem =
        await (db.select(db.tabelItemMakanan)
              ..where((t) => t.sesiId.isIn(id))
              ..orderBy([(t) => OrderingTerm(expression: t.urutan)]))
            .get();

    final sampelPerSesi = <String, List<TabelSampelData>>{};
    for (final b in barisSampel) {
      (sampelPerSesi[b.sesiId] ??= []).add(b);
    }
    final hasilPerSesi = {for (final b in barisHasil) b.sesiId: b};
    final itemPerSesi = <String, List<TabelItemMakananData>>{};
    for (final b in barisItem) {
      (itemPerSesi[b.sesiId] ??= []).add(b);
    }

    return [
      for (final s in barisSesi)
        SesiMakan(
          id: s.id,
          fotoPath: s.fotoPath,
          waktuFoto: _keWaktu(s.waktuFoto),
          t0: s.t0 == null ? null : _keWaktu(s.t0!),
          status: s.status,
          waktuTidakPasti: s.waktuTidakPasti,
          sampel: _rakitSampel(sampelPerSesi[s.id] ?? const []),
          hasil: _rakitHasil(hasilPerSesi[s.id], itemPerSesi[s.id] ?? const []),
        ),
    ];
  }

  @override
  Future<void> simpan(SesiMakan sesi) async {
    // Satu transaksi: sesi tanpa sampelnya, atau hasil deteksi tanpa itemnya,
    // adalah keadaan yang tidak pernah sah untuk dibaca.
    await db.transaction(() async {
      await db
          .into(db.tabelSesi)
          .insertOnConflictUpdate(
            TabelSesiCompanion.insert(
              id: sesi.id,
              fotoPath: sesi.fotoPath,
              waktuFoto: _keEpoch(sesi.waktuFoto),
              t0: Value(sesi.t0 == null ? null : _keEpoch(sesi.t0!)),
              status: sesi.status,
              waktuTidakPasti: Value(sesi.waktuTidakPasti),
            ),
          );

      // Anak-anaknya ditulis ulang, bukan ditambal. Jumlah sampel tetap empat,
      // tetapi daftar makanan bisa menyusut setelah dikoreksi user — menambal
      // akan meninggalkan item yang sudah dihapus.
      await (db.delete(
        db.tabelSampel,
      )..where((t) => t.sesiId.equals(sesi.id))).go();
      await (db.delete(
        db.tabelHasilDeteksi,
      )..where((t) => t.sesiId.equals(sesi.id))).go();
      await (db.delete(
        db.tabelItemMakanan,
      )..where((t) => t.sesiId.equals(sesi.id))).go();

      await db.batch((b) {
        b.insertAll(db.tabelSampel, [
          for (final s in sesi.sampel)
            TabelSampelCompanion.insert(
              sesiId: sesi.id,
              index: s.index,
              detikRelatifT0: s.detikRelatifT0,
              status: s.status,
              dariBuffer: Value(s.dariBuffer),
              gulaDarah: Value(s.gulaDarah),
              detakJantung: Value(s.detakJantung),
              sistolik: Value(s.sistolik),
              diastolik: Value(s.diastolik),
              spo2: Value(s.spo2),
            ),
        ]);

        final hasil = sesi.hasil;
        if (hasil != null) {
          b.insert(
            db.tabelHasilDeteksi,
            TabelHasilDeteksiCompanion.insert(
              sesiId: sesi.id,
              indeksGlikemikPerkiraan: hasil.indeksGlikemikPerkiraan,
              keyakinan: hasil.keyakinan,
              dikoreksiUser: hasil.dikoreksiUser,
              totalKalori: hasil.total.kalori,
              totalKarbohidrat: hasil.total.karbohidrat,
              totalProtein: hasil.total.protein,
              totalLemak: hasil.total.lemak,
              totalGulaTotal: hasil.total.gulaTotal,
              totalSerat: hasil.total.serat,
            ),
          );
          b.insertAll(db.tabelItemMakanan, [
            for (var i = 0; i < hasil.makanan.length; i++)
              TabelItemMakananCompanion.insert(
                sesiId: sesi.id,
                urutan: i,
                nama: hasil.makanan[i].nama,
                porsi: hasil.makanan[i].porsi,
                estimasiGram: hasil.makanan[i].estimasiGram,
                kalori: hasil.makanan[i].nutrisi.kalori,
                karbohidrat: hasil.makanan[i].nutrisi.karbohidrat,
                protein: hasil.makanan[i].nutrisi.protein,
                lemak: hasil.makanan[i].nutrisi.lemak,
                gulaTotal: hasil.makanan[i].nutrisi.gulaTotal,
                serat: hasil.makanan[i].nutrisi.serat,
              ),
          ]);
        }
      });

      // Entri mentah yang membentuk sesi ini sekarang durabel di dalam sesinya,
      // jadi ia tidak perlu diputar ulang saat aplikasi start
      // (docs/protokol-jam.md §6, lihat `EntriJamRepository`). Ditandai **di
      // dalam transaksi yang sama**: "sesinya tersimpan" dan "entrinya sudah
      // diproses" harus benar atau salah bersama-sama, karena kalau tandanya
      // duluan dan penulisannya gagal, entri itu hilang tanpa jejak.
      await (db.update(db.tabelEntriJam)
            ..where((t) => t.sesiId.equals(sesi.id) & t.diproses.equals(false)))
          .write(const TabelEntriJamCompanion(diproses: Value(true)));
    });
  }

  @override
  Future<void> hapus(String sesiId) async {
    // Anak-anaknya ikut lewat `onDelete: cascade` — yang hanya benar-benar
    // berjalan karena `PRAGMA foreign_keys = ON` dipasang di `beforeOpen`.
    await (db.delete(db.tabelSesi)..where((t) => t.id.equals(sesiId))).go();

    // Entri mentahnya tidak lagi akan ikut tersimpan di dalam sesi mana pun,
    // jadi menandainya "diproses" adalah satu-satunya cara ia tidak diputar
    // ulang selamanya setiap aplikasi start.
    await (db.update(db.tabelEntriJam)..where((t) => t.sesiId.equals(sesiId)))
        .write(const TabelEntriJamCompanion(diproses: Value(true)));
  }

  // --- Pemetaan ----------------------------------------------------------

  // Disimpan sebagai epoch mikrodetik UTC. `toLocal()` saat membaca menjaga
  // `DateTime ==` tetap benar: dua DateTime hanya sama bila zona waktunya juga
  // sama, jadi mengembalikan nilai UTC akan membuat round-trip gagal dibanding
  // aslinya yang lokal.
  static int _keEpoch(DateTime w) => w.toUtc().microsecondsSinceEpoch;

  static DateTime _keWaktu(int e) =>
      DateTime.fromMicrosecondsSinceEpoch(e, isUtc: true).toLocal();

  /// Merakit empat titik ukur dari baris yang ada.
  ///
  /// `SesiMakan.sampel` dijanjikan selalu empat elemen dan diindeks langsung
  /// (`sampel[0]`, `sampel[2]`, …) di seluruh UI. Baris yang hilang — hanya
  /// mungkin bila basis data pernah rusak atau disunting tangan — diisi kembali
  /// sebagai `menunggu` alih-alih dibiarkan menjatuhkan aplikasi saat start.
  static List<Sampel> _rakitSampel(List<TabelSampelData> baris) {
    const jadwalBawaan = [0, 0, 3600, 7200];
    final perIndex = {for (final b in baris) b.index: b};

    return [
      for (var i = 0; i < 4; i++)
        if (perIndex[i] case final b?)
          Sampel(
            index: b.index,
            detikRelatifT0: b.detikRelatifT0,
            status: b.status,
            dariBuffer: b.dariBuffer,
            gulaDarah: b.gulaDarah,
            detakJantung: b.detakJantung,
            sistolik: b.sistolik,
            diastolik: b.diastolik,
            spo2: b.spo2,
          )
        else
          Sampel.menunggu(index: i, detikRelatifT0: jadwalBawaan[i]),
    ];
  }

  static HasilDeteksi? _rakitHasil(
    TabelHasilDeteksiData? hasil,
    List<TabelItemMakananData> item,
  ) {
    if (hasil == null) return null;

    return HasilDeteksi(
      makanan: [
        for (final m in item)
          ItemMakanan(
            nama: m.nama,
            porsi: m.porsi,
            estimasiGram: m.estimasiGram,
            nutrisi: Nutrisi(
              kalori: m.kalori,
              karbohidrat: m.karbohidrat,
              protein: m.protein,
              lemak: m.lemak,
              gulaTotal: m.gulaTotal,
              serat: m.serat,
            ),
          ),
      ],
      total: Nutrisi(
        kalori: hasil.totalKalori,
        karbohidrat: hasil.totalKarbohidrat,
        protein: hasil.totalProtein,
        lemak: hasil.totalLemak,
        gulaTotal: hasil.totalGulaTotal,
        serat: hasil.totalSerat,
      ),
      indeksGlikemikPerkiraan: hasil.indeksGlikemikPerkiraan,
      keyakinan: hasil.keyakinan,
      dikoreksiUser: hasil.dikoreksiUser,
    );
  }
}
