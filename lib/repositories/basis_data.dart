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

  /// Sesi ini berasal dari boot jam yang tidak pernah punya anchor, sehingga
  /// waktunya tidak diketahui dan tidak akan pernah bisa diketahui
  /// (docs/protokol-jam.md §4.3).
  ///
  /// Disimpan, bukan dihitung: begitu sesinya berakhir, tidak ada lagi jejak
  /// yang bisa dipakai menurunkan ulang fakta ini — anchor untuk boot itu tidak
  /// akan pernah ada.
  BoolColumn get waktuTidakPasti =>
      boolean().withDefault(const Constant(false))();

  /// Sesi ini dibuat oleh rakitan `--dart-define=PAKAI_JADWAL_UJI=true`, jadwal
  /// dua menit (docs/jadwal-titik-ukur.md §7).
  ///
  /// Disimpan, bukan diturunkan, dan alasannya dua. Pertama sama dengan
  /// [waktuTidakPasti]: begitu sesinya tersimpan tidak ada lagi jejak yang bisa
  /// dipakai memastikannya — sesi dua menit memang mencurigakan, tetapi sesi
  /// sungguhan yang semua titiknya terlewat terlihat mirip, dan menebak di sini
  /// berarti menyembunyikan data sungguhan seseorang. Kedua, dan yang
  /// menentukan: **rakitan tanpa flag itu tetap harus bisa membaca baris yang
  /// ditulis rakitan yang punya flag.** Sesi uji akan tetap ada di basis data
  /// tester lama setelah build ujinya diganti, dan hanya kolom ini yang masih
  /// mengetahuinya.
  BoolColumn get sesiUji => boolean().withDefault(const Constant(false))();

  /// Kapan isi sesi ini terakhir berubah **di perangkat ini**.
  ///
  /// Dikirim ke server sebagai `diperbarui_pada` dan dipakai aturan "yang
  /// terbaru menang" (§7.1). Sebelum kolom ini ada, aplikasi mengirim
  /// `DateTime.now()` saat pengiriman — sehingga setiap kiriman ulang mengaku
  /// paling baru walau isinya tidak berubah, dan suntingan dari perangkat lain
  /// akan tertimpa salinan lama tanpa ada yang menghalangi.
  IntColumn get diperbaruiPada => integer().nullable()();

  /// Batu nisan: kapan sesi ini dibatalkan pengguna di perangkat ini.
  ///
  /// Bukan "sesi yang disembunyikan". Saat kolom ini terisi, sampel, hasil
  /// gizi, item makanan, dan **berkas fotonya** sudah dihapus permanen; yang
  /// tersisa hanya id dan waktunya. Gunanya satu: memberi tahu server bahwa
  /// sesi ini dibuang (§7 `dihapus_pada`, `POST /sinkron`) — draft-nya sudah
  /// terunggah sejak rana ditekan, jadi tanpa nisan ia tinggal di sana selamanya
  /// sebagai sesi yang tak pernah selesai, dan ikut terunduh ke perangkat kedua.
  ///
  /// Umurnya pendek: begitu server mengakuinya, barisnya dihapus betulan
  /// (`SesiRepository.ambilNisan` → `hapus`). Yang menumpuk hanya milik
  /// pengguna yang belum pernah masuk — dan di sana tidak ada server untuk
  /// diberi tahu, jadi nisannya tidak pernah dibuat sejak awal.
  IntColumn get dihapusPada => integer().nullable()();

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
  // Nullable sejak v6, dan itu bukan kelonggaran melainkan inti persoalannya:
  // sumber angkanya (tabel TKPI lewat layanan deteksi) tidak punya kolom indeks
  // glikemik maupun gula sama sekali, dan makanan yang belum punya padanan di
  // sana tidak menghasilkan satu angka pun. null berarti "tidak diketahui";
  // menyimpannya sebagai 0 akan mengubah ketidaktahuan menjadi klaim.
  TextColumn get indeksGlikemikPerkiraan => text().nullable()();
  RealColumn get keyakinan => real().nullable()();
  BoolColumn get dikoreksiUser => boolean()();
  RealColumn get totalKalori => real().nullable()();
  RealColumn get totalKarbohidrat => real().nullable()();
  RealColumn get totalProtein => real().nullable()();
  RealColumn get totalLemak => real().nullable()();
  RealColumn get totalGulaTotal => real().nullable()();
  RealColumn get totalSerat => real().nullable()();

  /// Kunci §5.2 yang dipisah koma, mis. `gula_total,serat`.
  ///
  /// Disimpan sebagai teks, bukan tabel sendiri: isinya paling banyak enam
  /// nilai tetap yang tidak pernah di-query satu per satu, dan sebuah tabel
  /// untuk itu hanya menambah join tanpa menjawab pertanyaan apa pun.
  TextColumn get zatTidakLengkap => text().withDefault(const Constant(''))();

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
  // Nullable sejak v6 — lihat TabelHasilDeteksi. Makanan yang tidak ada di
  // tabel gizi punya nama, porsi, dan berat, tetapi tidak satu pun angka.
  RealColumn get kalori => real().nullable()();
  RealColumn get karbohidrat => real().nullable()();
  RealColumn get protein => real().nullable()();
  RealColumn get lemak => real().nullable()();
  RealColumn get gulaTotal => real().nullable()();
  RealColumn get serat => real().nullable()();

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

/// Kalibrasi tekanan darah yang pernah dikirim ke jam (§5.1 `SET_KALIBRASI`).
///
/// Riwayat, bukan satu baris yang ditimpa: offset yang melonjak antar kalibrasi
/// adalah tanda pengukuran yang salah satunya keliru, dan itu hanya terlihat
/// bila yang lama masih ada. Yang dipakai aplikasi tetap yang terbaru.
///
/// Jam sendiri menyimpan offsetnya di flash, jadi tabel ini bukan sumber
/// kebenaran bagi jam — ia sumber kebenaran bagi **aplikasi**, yang tanpa ini
/// lupa pernah mengalibrasi setiap kali ditutup.
/// Sejak v4 baris ini hanya menyimpan **identitas** satu kalibrasi: kapan dan
/// di pergelangan mana. Angkanya pindah ke [TabelPutaranKalibrasi], karena satu
/// kalibrasi kini terdiri dari tiga putaran (`Kalibrasi.jumlahPutaran`) dan
/// koreksi yang dikirim ke jam adalah mediannya — nilai turunan, yang seperti
/// nilai turunan lain di skema ini tidak punya kolom sendiri.
class TabelKalibrasi extends Table {
  IntColumn get waktu => integer()();

  /// `textEnum`, jadi mengganti nama anggota [SisiPergelangan] adalah
  /// perubahan skema — sama seperti `StatusSesi` di [TabelSesi].
  TextColumn get sisi => textEnum<SisiPergelangan>()();

  @override
  Set<Column> get primaryKey => {waktu};
}

/// Satu putaran tensimeter + jam milik sebuah kalibrasi.
///
/// Ketiganya disimpan mentah, bukan hanya mediannya, karena sebaran antar
/// putaran adalah satu-satunya bukti bahwa kalibrasinya layak dipercaya
/// (`Kalibrasi.konsisten`). Median tanpa sebarannya tidak bisa dibedakan dari
/// median tiga angka yang saling bertentangan.
///
/// Tidak ada `references` ke [TabelKalibrasi] dengan sengaja: induknya tidak
/// pernah dihapus (kalibrasi adalah riwayat), dan kunci asing ke tabel yang
/// ikut ditulis ulang saat migrasi hanya menambah satu cara gagal yang baru
/// muncul di perangkat pengguna.
class TabelPutaranKalibrasi extends Table {
  IntColumn get waktuKalibrasi => integer()();
  IntColumn get urutan => integer()();
  IntColumn get sistolikReferensi => integer()();
  IntColumn get diastolikReferensi => integer()();
  IntColumn get sistolikJam => integer()();
  IntColumn get diastolikJam => integer()();

  @override
  Set<Column> get primaryKey => {waktuKalibrasi, urutan};
}

/// Entri mentah yang datang dari jam, sebelum jadi bagian sebuah sesi —
/// docs/protokol-jam.md §6.
///
/// Alasannya satu kalimat di protokol: **ack hanya boleh dikirim setelah data
/// tersimpan permanen**, karena jam menghapus entrinya begitu di-ack. Tanpa
/// tabel ini, satu-satunya tempat sampel tersimpan sebelum ack adalah memori,
/// dan aplikasi yang mati sedetik setelah ack kehilangannya untuk selamanya.
///
/// Kolomnya sengaja primitif — `jenis` dan `kodePeristiwa` adalah **angka
/// protokol**, bukan `textEnum`. Nilai-nilainya sudah dikunci dokumen protokol
/// dan tidak boleh ikut berubah saat sebuah enum Dart diganti namanya, berbeda
/// dari `StatusSesi` di [TabelSesi] yang memang milik aplikasi.
class TabelEntriJam extends Table {
  /// Kunci lokal, bukan `seq`: `seq` berputar 1..255 (§6 aturan 1) dan karena
  /// itu tidak unik bahkan dalam satu boot.
  IntColumn get id => integer().autoIncrement()();

  /// 0 = sampel (§5.2), 1 = peristiwa (§5.4).
  IntColumn get jenis => integer()();

  IntColumn get seq => integer()();
  IntColumn get bootId => integer()();
  IntColumn get uptimeS => integer()();
  BoolColumn get dariBuffer => boolean()();
  BoolColumn get waktuTidakPasti => boolean()();

  TextColumn get sesiId => text().nullable()();
  IntColumn get indexSampel => integer().nullable()();
  IntColumn get kodePeristiwa => integer().nullable()();
  IntColumn get payload => integer().nullable()();

  IntColumn get gulaDarah => integer().nullable()();
  IntColumn get detakJantung => integer().nullable()();
  IntColumn get sistolik => integer().nullable()();
  IntColumn get diastolik => integer().nullable()();
  IntColumn get spo2 => integer().nullable()();

  /// Entri sudah ikut tersimpan di dalam sesinya, jadi tidak perlu diputar
  /// ulang saat aplikasi start. Ditandai oleh `SesiRepositoryDrift.simpan()`
  /// **di dalam transaksi yang sama** dengan penulisan sesinya: "sudah
  /// diproses" dan "sesinya durabel" harus benar atau salah bersama-sama.
  BoolColumn get diproses => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(
  tables: [
    TabelSesi,
    TabelSampel,
    TabelHasilDeteksi,
    TabelItemMakanan,
    TabelAnchorWaktu,
    TabelKalibrasi,
    TabelPutaranKalibrasi,
    TabelEntriJam,
  ],
)
class BasisData extends _$BasisData {
  BasisData(super.e);

  @override
  int get schemaVersion => 7;

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
          case 2: // v2 → v3: BLE sungguhan (Tahap B)
            await m.addColumn(tabelSesi, tabelSesi.waktuTidakPasti);
            await m.createTable(tabelKalibrasi);
            await m.createTable(tabelEntriJam);
          case 3: // v3 → v4: kalibrasi tiga putaran (metode manset berulang)
            // Urutannya penting: angka v3 disalin dulu menjadi putaran 0,
            // baru kolom asalnya dibuang bersama penulisan ulang tabelnya.
            // Kalibrasi lama tetap terbaca — satu putaran, mediannya dirinya
            // sendiri — jadi tidak ada pengguna yang tiba-tiba "belum pernah
            // dikalibrasi" padahal jamnya masih memakai offset itu.
            await m.createTable(tabelPutaranKalibrasi);

            // `createTable` selalu memakai definisi Dart **hari ini**, bukan
            // definisi versi yang sedang dimigrasikan. Jadi perangkat yang
            // melompat dari v2 baru saja membuat `tabel_kalibrasi` dalam bentuk
            // v4 di langkah sebelumnya, dan tidak punya kolom lama untuk
            // disalin. Yang membedakan keduanya cuma isi tabelnya sendiri —
            // karena itu ditanya, bukan diasumsikan.
            final kolom = await m.database
                .customSelect('PRAGMA table_info(tabel_kalibrasi)')
                .get();
            final bentukV3 = kolom.any(
              (baris) => baris.read<String>('name') == 'sistolik_referensi',
            );

            if (bentukV3) {
              await m.database.customStatement(
                'INSERT INTO tabel_putaran_kalibrasi ('
                'waktu_kalibrasi, urutan, sistolik_referensi, '
                'diastolik_referensi, sistolik_jam, diastolik_jam) '
                'SELECT waktu, 0, sistolik_referensi, diastolik_referensi, '
                'sistolik_jam, diastolik_jam FROM tabel_kalibrasi',
              );
              await m.alterTable(
                TableMigration(
                  tabelKalibrasi,
                  newColumns: [tabelKalibrasi.sisi],
                  // Pergelangannya tidak terekam sebelum v4 dan tidak bisa
                  // diterka. Diisi kiri — sisi yang paling lazim — dan tidak
                  // dipakai untuk apa pun selain kalimat di layar; kalibrasi
                  // lama itu sendiri sudah kedaluwarsa 4 minggu setelah dibuat.
                  columnTransformer: {
                    tabelKalibrasi.sisi: const Constant('kiri'),
                  },
                ),
              );
            }
          case 4: // v4 → v5: penandaan sesi dari mode jadwal uji
            // Sama seperti langkah v3 → v4 di atas, `createTable` memakai
            // definisi hari ini, jadi perangkat yang melompat dari versi lama
            // bisa saja tiba di sini dengan tabel yang sudah berbentuk v5.
            // Karena itu ditanya lebih dulu, bukan diasumsikan — `addColumn`
            // pada kolom yang sudah ada akan gagal dan menggagalkan seluruh
            // pembukaan basis data.
            final kolomSesi = await m.database
                .customSelect('PRAGMA table_info(tabel_sesi)')
                .get();
            final sudahAda = kolomSesi.any(
              (baris) => baris.read<String>('name') == 'sesi_uji',
            );
            if (!sudahAda) {
              await m.addColumn(tabelSesi, tabelSesi.sesiUji);
            }
          case 5: // v5 → v6: "tidak diketahui" dibedakan dari nol
            // SQLite tidak bisa melonggarkan NOT NULL lewat ALTER TABLE, jadi
            // kedua tabel gizi dibangun ulang oleh `alterTable` — ia yang
            // mengurus tabel sementara, penyalinan isi, penghapusan yang lama,
            // dan penggantian nama. Isinya pindah apa adanya: angka lama memang
            // benar-benar angka, yang berubah hanya kemampuan menyimpan
            // ketiadaannya mulai sekarang.
            //
            // `zat_tidak_lengkap` harus disebut sebagai kolom **baru**. Tanpa
            // itu, penyalinannya ikut menyebut kolom yang belum pernah ada di
            // tabel lama, dan seluruh pembukaan basis data gagal.
            await m.alterTable(
              TableMigration(
                tabelHasilDeteksi,
                newColumns: [tabelHasilDeteksi.zatTidakLengkap],
              ),
            );
            await m.alterTable(TableMigration(tabelItemMakanan));

            // Kolom stempel perubahan. Bawaannya null — sesi lama belum pernah
            // disunting sejak kolom ini ada, dan itu memang yang benar.
            final kolomSesiV6 = await m.database
                .customSelect('PRAGMA table_info(tabel_sesi)')
                .get();
            if (!kolomSesiV6.any(
              (b) => b.read<String>('name') == 'diperbarui_pada',
            )) {
              await m.addColumn(tabelSesi, tabelSesi.diperbaruiPada);
            }

          case 6: // v6 → v7: batu nisan sesi yang dibatalkan (§7)
            // Ditanya lebih dulu, dengan alasan yang sama seperti langkah v4 →
            // v5 di atas: perangkat yang melompat dari versi lama bisa tiba di
            // sini dengan tabel yang sudah berbentuk v7.
            final kolomSesiV7 = await m.database
                .customSelect('PRAGMA table_info(tabel_sesi)')
                .get();
            if (!kolomSesiV7.any(
              (b) => b.read<String>('name') == 'dihapus_pada',
            )) {
              await m.addColumn(tabelSesi, tabelSesi.dihapusPada);
            }

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
