/// Jadwal titik ukur sebuah sesi — docs/jadwal-titik-ukur.md.
///
/// Sampai v1.2 protokol, jadwal ini hidup di firmware: jam menyimpan `t0` di
/// pencacahnya sendiri lalu menembakkan index 2 dan 3 pada `+3600` dan `+7200`.
/// v1.3 memindahkannya ke sini, karena jam tidak bertahan lebih dari ~50 menit
/// menyala sementara satu sesi berdurasi lebih dari dua jam — penjadwal di
/// firmware tidak pernah bisa menyelesaikan tugasnya (protokol §9, §12).
///
/// Konsekuensi yang membuat berkas ini ada: **jadwal jadi data, bukan literal.**
/// Menambah atau menggeser titik tidak lagi menuntut flash ulang, dan tidak
/// menuntut migrasi basis data — `TabelSampel` sejak Tahap A sudah menyimpan
/// `detikRelatifT0` per baris, dan `index` di protokol adalah 1 byte penuh.
///
/// Yang **tidak** berubah: jadwalnya sendiri tetap empat titik, sama persis
/// dengan sebelumnya. Titik tambahan (mis. `+30 menit`) dibahas di §2.1 dokumen
/// itu dan sengaja tidak diaktifkan — tiap titik berarti satu notifikasi lagi,
/// satu kali menyalakan jam lagi, dan satu tombol lagi yang harus ditekan tepat
/// waktu.
library;

/// Satu titik ukur: kapan nominalnya, dan sampai kapan pengukurannya masih
/// dianggap mewakili titik itu.
class TitikJadwal {
  const TitikJadwal({
    required this.index,
    required this.detikNominal,
    required this.label,
    this.jendelaAwal,
    this.jendelaAkhir,
    this.ambangNormalisasi = 120,
  });

  /// Index protokol (§5.1) — juga kunci baris `TabelSampel` bersama `sesiId`.
  final int index;

  /// `detikRelatifT0` nominal titik ini. Negatif hanya untuk baseline, yang
  /// waktunya ditentukan peristiwa (shutter kamera) dan bukan jadwal.
  final int detikNominal;

  final String label;

  /// Batas jendela toleransi dalam detik relatif t0, null bila titik ini tidak
  /// berjendela (baseline dan t0: keduanya dipicu peristiwa, bukan jadwal).
  final int? jendelaAwal;
  final int? jendelaAkhir;

  bool get berjendela => jendelaAwal != null && jendelaAkhir != null;

  /// Titik yang tidak berjendela tidak pernah "belum waktunya" dan tidak pernah
  /// "telat" — ia diukur saat peristiwanya terjadi, titik.
  bool belumWaktunya(int detikRelatifT0) =>
      berjendela && detikRelatifT0 < jendelaAwal!;

  bool telat(int detikRelatifT0) =>
      berjendela && detikRelatifT0 > jendelaAkhir!;

  /// Selisih di bawah ini dianggap kosmetik dan dinormalkan ke [detikNominal].
  ///
  /// Alasannya yang lama masih berlaku pada skala detik: label menjanjikan
  /// "+1 jam", bukan "+1 jam 40 detik". Ia **berbalik** pada skala menit —
  /// menyembunyikan keterlambatan 25 menit bukan merapikan label, itu
  /// memalsukan sumbu x. Karena itu ambangnya ada, dan karena itu ia kecil.
  ///
  /// Ikut dikecilkan oleh [dibagi], bukan konstanta global, karena kalau tidak
  /// ia akan menelan seluruh jadwal uji: ambang 120 detik di atas jadwal yang
  /// titik terakhirnya jatuh pada detik ke-120 berarti tidak ada satu pun
  /// keterlambatan yang bisa terdeteksi, dan justru deteksi itulah yang sedang
  /// diuji.
  final int ambangNormalisasi;

  /// `detikRelatifT0` yang disimpan untuk pengukuran yang tiba pada [terukur].
  int normalkan(int terukur) =>
      (terukur - detikNominal).abs() < ambangNormalisasi
      ? detikNominal
      : terukur;

  /// Membagi seluruh angka, dengan dua lantai yang bukan kosmetik.
  ///
  /// [detikNominal] tidak boleh runtuh menjadi 0 bila aslinya bukan 0 — dua
  /// titik berbeda yang jatuh pada detik yang sama bukan lagi jadwal. Dan
  /// [ambangNormalisasi] tidak boleh turun di bawah dua detik: di jadwal yang
  /// sangat dimampatkan, satu frame test yang tersendat sudah cukup membuat
  /// pengukuran yang tepat waktu tercatat telat.
  TitikJadwal dibagi(int faktor) => TitikJadwal(
    index: index,
    detikNominal: detikNominal == 0 ? 0 : _minimal(detikNominal ~/ faktor, 1),
    label: label,
    jendelaAwal: jendelaAwal == null ? null : jendelaAwal! ~/ faktor,
    jendelaAkhir: jendelaAkhir == null ? null : jendelaAkhir! ~/ faktor,
    ambangNormalisasi: _minimal(ambangNormalisasi ~/ faktor, 2),
  );

  static int _minimal(int nilai, int lantai) => nilai < lantai ? lantai : nilai;
}

/// Daftar titik sebuah sesi, plus berapa lama sesi masih ditunggu setelah titik
/// terakhirnya.
class JadwalSesi {
  const JadwalSesi({
    required this.titik,
    required this.tenggatSetelahAkhir,
    this.uji = false,
  });

  final List<TitikJadwal> titik;

  /// Jadwal ini dikecilkan untuk pengujian, bukan jadwal sungguhan.
  ///
  /// Ada di sini, bukan sebagai sakelar terpisah di controller, supaya tidak ada
  /// jalan untuk memakai jadwal dua menit tanpa sesinya ikut tertandai. Satu
  /// rakitan uji yang menulis sesi tanpa tanda akan mencemari `AnalisisSesi`
  /// selamanya, dan tidak ada cara memisahkannya lagi sesudahnya.
  final bool uji;

  /// Berapa lama setelah titik terakhir sesi berhenti ditunggu dan ditutup
  /// `tidakLengkap`. Sebelum Tahap B satu-satunya jalan ke sana adalah pengguna
  /// menekan "akhiri lebih awal"; dengan jam sungguhan, baterai habis atau
  /// sensor gagal akan meninggalkan sesi menunggu selamanya.
  final Duration tenggatSetelahAkhir;

  TitikJadwal operator [](int index) =>
      titik.firstWhere((t) => t.index == index);

  int get jumlahTitik => titik.length;

  int get detikTitikTerakhir =>
      titik.map((t) => t.detikNominal).reduce((a, b) => a > b ? a : b);

  List<String> get label => titik.map((t) => t.label).toList(growable: false);

  /// Jadwal yang sama dengan seluruh angkanya dibagi [faktor].
  ///
  /// Dipakai mode uji, dan sengaja diturunkan dari jadwal sungguhan alih-alih
  /// ditulis ulang sebagai daftar kedua: dua daftar yang harus dijaga sebanding
  /// pada akhirnya akan berselisih, dan selisihnya justru muncul di jalur yang
  /// paling jarang dijalankan.
  JadwalSesi dibagi(int faktor) => JadwalSesi(
    titik: titik.map((t) => t.dibagi(faktor)).toList(growable: false),
    // Lantai lima detik, dan alasannya bukan kenyamanan test. Tenggat ini ada
    // sebagai **masa tenggang** bagi sampel yang menyusul lewat buffer jam
    // (protokol §6). Dimampatkan sampai satu detik ia berhenti menjadi masa
    // tenggang dan berubah menjadi perlombaan: sesi yang seluruh titiknya
    // sebenarnya terkumpul akan tetap ditutup `tidakLengkap` hanya karena
    // pengirimannya butuh satu putaran lagi.
    tenggatSetelahAkhir: Duration(
      seconds: TitikJadwal._minimal(tenggatSetelahAkhir.inSeconds ~/ faktor, 5),
    ),
    uji: true,
  );
}

/// Jadwal sungguhan — empat titik, tidak berubah sejak §12.1 rancangan UI.
///
/// Jendela toleransinya **asimetris, dan itu inti aturannya**: terlalu cepat
/// masih bisa diperbaiki (titiknya belum lewat, ukur lagi nanti), terlalu lambat
/// tidak. Karena itu yang sebelum jendela ditahan, sedangkan yang sesudahnya
/// diterima dan ditandai.
///
/// `+1 jam` sempit ke belakang karena puncak gula darah sesungguhnya sering
/// jatuh sebelum menit ke-60: terlambat di sana langsung merusak `deltaPuncak`,
/// dan arah kesalahannya menyesatkan — sesi tampak **lebih landai** daripada
/// kenyataan. `+2 jam` longgar karena kurvanya sudah datar di sana.
const JadwalSesi jadwalNormal = JadwalSesi(
  titik: [
    TitikJadwal(index: 0, detikNominal: 0, label: 'Baseline'),
    TitikJadwal(index: 1, detikNominal: 0, label: 'Selesai makan'),
    TitikJadwal(
      index: 2,
      detikNominal: 3600,
      label: '+1 jam',
      jendelaAwal: 3300, // 55 mnt
      jendelaAkhir: 4200, // 70 mnt
    ),
    TitikJadwal(
      index: 3,
      detikNominal: 7200,
      label: '+2 jam',
      jendelaAwal: 6600, // 110 mnt
      jendelaAkhir: 9000, // 150 mnt
    ),
  ],
  tenggatSetelahAkhir: Duration(minutes: 30),
);

/// Faktor pengecil mode uji. 60 dipilih supaya tiap "menit" jadwal sungguhan
/// menjadi satu detik — angkanya bisa dibaca langsung tanpa aritmetika, dan
/// sesi penuh selesai dalam dua menit.
const int faktorJadwalUji = 60;

/// Jadwal mode uji. Lihat `pakaiJadwalUji` di konfigurasi.dart.
final JadwalSesi jadwalUji = jadwalNormal.dibagi(faktorJadwalUji);
