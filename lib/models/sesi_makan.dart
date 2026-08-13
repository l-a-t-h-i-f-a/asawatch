/// Model inti untuk konsep "sesi makan" — lihat docs/rancangan-ui-sesi-makan.md §12.
///
/// Satu sesi = satu foto makanan, satu t0 ("selesai makan"), dan empat sampel
/// pengukuran dengan index yang bermakna tetap (§12.1). Semua nilai turunan
/// (baseline, puncak, delta, waktu pemulihan, verdict) dihitung di sini,
/// tidak disimpan.
library;

enum StatusSesi {
  // Foto sudah diambil dan tombol "Selesai Makan" di jam sudah menyala; yang
  // ditunggu adalah tombol itu ditekan.
  draft,
  // Foto sudah diambil tetapi jam belum tersambung, jadi tombolnya belum bisa
  // dinyalakan. t0 hanya bisa datang dari jam, sehingga sesi belum bisa mulai.
  menungguPerangkat,
  berjalan, // menunggu sampel +1 jam / +2 jam
  selesai, // 4 sampel lengkap
  tidakLengkap, // sesi berakhir dengan sampel terlewat
  dibatalkan,
}

enum StatusSampel { menunggu, terisi, terlewat }

/// Pengelompokan sesi di Riwayat menggantikan filter per-metrik lama (§4.2).
/// Diturunkan dari jam t0, tidak pernah dipilih user.
enum WaktuMakan { sarapan, makanSiang, makanMalam, camilan }

/// Seberapa besar lonjakan gula darah sesi ini dibanding baseline — dipakai
/// sebagai indikator respons di daftar Riwayat dan sebagai filter kedua.
enum KualitasRespons { landai, sedang, lonjakan, belumLengkap }

/// Ambang delta puncak (mg/dL) yang memisahkan ketiga kualitas respons.
const int ambangResponsLandai = 30;
const int ambangResponsSedang = 60;

/// Selisih dari baseline yang masih dianggap "kembali normal", dalam mg/dL.
const int ambangPemulihan = 10;

/// Label titik pengukuran sesuai tabel index di §12.1.
const List<String> labelTitikSampel = [
  'Baseline',
  'Selesai makan',
  '+1 jam',
  '+2 jam',
];

extension LabelStatusSesi on StatusSesi {
  String get label => switch (this) {
    // Ringkas karena dipakai sebagai lencana; penjelasannya ada di
    // PetunjukTombolJam dan di verdict.
    StatusSesi.draft => 'Siap dimulai',
    StatusSesi.menungguPerangkat => 'Jam terputus',
    StatusSesi.berjalan => 'Sesi berjalan',
    StatusSesi.selesai => 'Selesai',
    StatusSesi.tidakLengkap => 'Tidak lengkap',
    StatusSesi.dibatalkan => 'Dibatalkan',
  };

  bool get sedangAktif =>
      this == StatusSesi.draft ||
      this == StatusSesi.menungguPerangkat ||
      this == StatusSesi.berjalan;
}

extension LabelWaktuMakan on WaktuMakan {
  String get label => switch (this) {
    WaktuMakan.sarapan => 'Sarapan',
    WaktuMakan.makanSiang => 'Makan Siang',
    WaktuMakan.makanMalam => 'Makan Malam',
    WaktuMakan.camilan => 'Camilan',
  };
}

extension LabelKualitasRespons on KualitasRespons {
  String get label => switch (this) {
    KualitasRespons.landai => 'Landai',
    KualitasRespons.sedang => 'Sedang',
    KualitasRespons.lonjakan => 'Lonjakan',
    KualitasRespons.belumLengkap => 'Belum lengkap',
  };
}

class Sampel {
  const Sampel({
    required this.index,
    required this.detikRelatifT0,
    required this.status,
    this.dariBuffer = false,
    this.gulaDarah,
    this.detakJantung,
    this.sistolik,
    this.diastolik,
    this.spo2,
  });

  /// Sampel yang jadwalnya sudah ditetapkan tetapi datanya belum datang.
  const Sampel.menunggu({required this.index, required this.detikRelatifT0})
    : status = StatusSampel.menunggu,
      dariBuffer = false,
      gulaDarah = null,
      detakJantung = null,
      sistolik = null,
      diastolik = null,
      spo2 = null;

  final int index; // 0..3, lihat labelTitikSampel
  final int detikRelatifT0; // negatif untuk baseline
  final StatusSampel status;
  final bool dariBuffer; // true bila dikirim jam setelah tertunda

  // null = metrik tidak berhasil diukur. Protokol BLE memakai sentinel 0;
  // konversikan ke null saat decode, jangan bawa 0 sampai ke UI.
  final int? gulaDarah; // mg/dL
  final int? detakJantung; // bpm
  final int? sistolik; // mmHg
  final int? diastolik; // mmHg
  final int? spo2; // %

  String get label => labelTitikSampel[index];

  bool get terisi => status == StatusSampel.terisi;

  /// Waktu ukur diturunkan dari t0, tidak disimpan (§12.2).
  DateTime waktuUkur(DateTime t0) =>
      t0.add(Duration(seconds: detikRelatifT0));

  String? get tekananDarah =>
      (sistolik == null || diastolik == null) ? null : '$sistolik/$diastolik';
}

class SesiMakan {
  const SesiMakan({
    required this.id,
    required this.fotoPath,
    required this.waktuFoto,
    required this.status,
    required this.sampel,
    this.t0,
    this.hasil,
    this.waktuTidakPasti = false,
  });

  final String id;
  final String fotoPath;
  final DateTime waktuFoto;
  final DateTime? t0; // null selama status == draft
  final StatusSesi status;
  final HasilDeteksi? hasil; // null bila analisis nutrisi belum selesai
  final List<Sampel> sampel; // selalu 4 elemen, index 0..3

  /// Waktu sesi ini tidak diketahui dan tidak akan pernah diketahui
  /// (docs/protokol-jam.md §4.3): jam menjalani satu boot penuh tanpa sekali pun
  /// tersambung, jadi tidak ada anchor yang bisa menerjemahkan `uptime_s`-nya.
  ///
  /// Sesi seperti ini **tidak dibuang** — datanya nyata, bentuk kurvanya benar,
  /// dan membuangnya diam-diam lebih buruk daripada menampilkannya apa adanya.
  /// Yang dilarang adalah memperlakukan jamnya seolah benar: ia tidak ikut
  /// [SesiMakanController.sesiHariIni], tidak punya [waktuMakan], dan tidak
  /// masuk `AnalisisSesi`.
  final bool waktuTidakPasti;

  SesiMakan salin({
    DateTime? t0,
    StatusSesi? status,
    HasilDeteksi? hasil,
    List<Sampel>? sampel,
    bool? waktuTidakPasti,
  }) {
    return SesiMakan(
      id: id,
      fotoPath: fotoPath,
      waktuFoto: waktuFoto,
      t0: t0 ?? this.t0,
      status: status ?? this.status,
      hasil: hasil ?? this.hasil,
      sampel: sampel ?? this.sampel,
      waktuTidakPasti: waktuTidakPasti ?? this.waktuTidakPasti,
    );
  }

  /// Sampel baseline pra-makan, hanya bila sudah terisi.
  Sampel? get baseline {
    final s = sampel[0];
    return s.terisi ? s : null;
  }

  int? get gulaDarahBaseline => baseline?.gulaDarah;

  /// Titik berikutnya yang datanya masih ditunggu, null bila tidak ada lagi.
  Sampel? get sampelBerikutnya {
    for (final s in sampel) {
      if (s.status == StatusSampel.menunggu) return s;
    }
    return null;
  }

  /// Waktu jadwal sampel berikutnya, null bila t0 belum ditetapkan.
  DateTime? get jadwalBerikutnya {
    final t = t0;
    final berikutnya = sampelBerikutnya;
    if (t == null || berikutnya == null) return null;
    return berikutnya.waktuUkur(t);
  }

  Iterable<Sampel> get sampelTerisi => sampel.where((s) => s.terisi);

  bool get adaSampelTerlewat =>
      sampel.any((s) => s.status == StatusSampel.terlewat);

  /// Sampel dengan gula darah tertinggi, mengabaikan baseline.
  Sampel? get sampelPuncak {
    Sampel? puncak;
    for (final s in sampel) {
      if (s.index == 0 || !s.terisi || s.gulaDarah == null) continue;
      if (puncak == null || s.gulaDarah! > puncak.gulaDarah!) puncak = s;
    }
    return puncak;
  }

  int? get puncakGulaDarah => sampelPuncak?.gulaDarah;

  /// Kenaikan puncak dari baseline. null bila salah satunya belum ada.
  int? get deltaPuncak {
    final puncak = puncakGulaDarah;
    final dasar = gulaDarahBaseline;
    if (puncak == null || dasar == null) return null;
    return puncak - dasar;
  }

  /// Berapa lama sejak t0 gula darah kembali ke sekitar baseline.
  ///
  /// null berarti belum kembali (atau datanya belum cukup), bukan gagal.
  Duration? get waktuPemulihan {
    final dasar = gulaDarahBaseline;
    final puncak = sampelPuncak;
    if (dasar == null || puncak == null) return null;
    for (final s in sampel) {
      if (s.index <= puncak.index || !s.terisi || s.gulaDarah == null) continue;
      if (s.gulaDarah! <= dasar + ambangPemulihan) {
        return Duration(seconds: s.detikRelatifT0);
      }
    }
    return null;
  }

  /// Waktu makan diturunkan dari jam t0 (jam foto bila t0 belum ada), bukan
  /// dipilih user — satu sesi tidak pernah perlu ditandai manual.
  ///
  /// null bila [waktuTidakPasti]: menyebut sesi yang jamnya tidak diketahui
  /// sebagai "Sarapan" adalah menebak, dan tebakan itu akan terlihat persis
  /// seperti fakta (protokol §4.3).
  WaktuMakan? get waktuMakan {
    if (waktuTidakPasti) return null;
    final jam = (t0 ?? waktuFoto).hour;
    if (jam >= 5 && jam < 11) return WaktuMakan.sarapan;
    if (jam >= 11 && jam < 15) return WaktuMakan.makanSiang;
    if (jam >= 17 && jam < 22) return WaktuMakan.makanMalam;
    return WaktuMakan.camilan;
  }

  /// Label waktu makan yang selalu bisa ditampilkan, termasuk saat jamnya tidak
  /// diketahui. Dipakai seluruh kartu sesi supaya tidak ada satu pun tempat yang
  /// harus mengarang teks pengganti sendiri.
  String get labelWaktuMakan => waktuMakan?.label ?? 'Waktu tidak pasti';

  /// Indikator respons untuk daftar Riwayat. Sesi yang datanya belum cukup
  /// dinyatakan `belumLengkap`, bukan dipaksa masuk salah satu kategori.
  KualitasRespons get kualitasRespons {
    final delta = deltaPuncak;
    if (delta == null || status.sedangAktif) return KualitasRespons.belumLengkap;
    if (delta <= ambangResponsLandai) return KualitasRespons.landai;
    if (delta <= ambangResponsSedang) return KualitasRespons.sedang;
    return KualitasRespons.lonjakan;
  }

  /// Kalori sesi ini; null selama analisis nutrisi belum selesai.
  double? get kalori => hasil?.total.kalori;

  /// Kalimat Bahasa Indonesia untuk kartu hasil (§12.3).
  String get verdict {
    switch (status) {
      case StatusSesi.dibatalkan:
        return 'Sesi dibatalkan.';
      case StatusSesi.draft:
        return 'Foto sudah diambil. Tekan tombol Selesai Makan di jam untuk '
            'memulai sesi.';
      case StatusSesi.menungguPerangkat:
        return 'Jam belum tersambung, jadi tombol Selesai Makan di jam belum '
            'bisa dipakai.';
      case StatusSesi.berjalan:
        return 'Sesi masih berjalan, menunggu sampel berikutnya.';
      case StatusSesi.selesai:
      case StatusSesi.tidakLengkap:
        break;
    }

    final delta = deltaPuncak;
    if (delta == null) {
      return 'Data gula darah belum cukup untuk menilai respons sesi ini.';
    }

    final tanda = delta >= 0 ? '+' : '';
    final pemulihan = waktuPemulihan;
    final bagian = <String>[
      'puncak $tanda$delta mg/dL',
      if (pemulihan != null)
        'normal dalam ${_jamRingkas(pemulihan)}'
      else
        'belum kembali ke baseline dalam 2 jam',
      if (adaSampelTerlewat) 'ada sampel terlewat',
    ];
    return bagian.join(' · ');
  }

  static String _jamRingkas(Duration d) {
    if (d.inMinutes % 60 == 0) return '${d.inHours} jam';
    return '${d.inMinutes} menit';
  }
}

class Nutrisi {
  const Nutrisi({
    required this.kalori,
    required this.karbohidrat,
    required this.protein,
    required this.lemak,
    required this.gulaTotal,
    required this.serat,
  });

  static const Nutrisi kosong = Nutrisi(
    kalori: 0,
    karbohidrat: 0,
    protein: 0,
    lemak: 0,
    gulaTotal: 0,
    serat: 0,
  );

  final double kalori, karbohidrat, protein, lemak, gulaTotal, serat;

  /// Menskalakan seluruh makro sekaligus — dipakai saat user mengoreksi porsi
  /// ("1 piring" → "setengah piring"), §4.5.
  Nutrisi operator *(double faktor) => Nutrisi(
    kalori: kalori * faktor,
    karbohidrat: karbohidrat * faktor,
    protein: protein * faktor,
    lemak: lemak * faktor,
    gulaTotal: gulaTotal * faktor,
    serat: serat * faktor,
  );

  Nutrisi operator +(Nutrisi lain) => Nutrisi(
    kalori: kalori + lain.kalori,
    karbohidrat: karbohidrat + lain.karbohidrat,
    protein: protein + lain.protein,
    lemak: lemak + lain.lemak,
    gulaTotal: gulaTotal + lain.gulaTotal,
    serat: serat + lain.serat,
  );
}

class ItemMakanan {
  const ItemMakanan({
    required this.nama,
    required this.porsi,
    required this.estimasiGram,
    required this.nutrisi,
  });

  final String nama;
  final String porsi; // "1 piring", teks yang bisa diedit user
  final double estimasiGram;
  final Nutrisi nutrisi;

  /// Koreksi user atas satu item.
  ///
  /// Mengubah [estimasiGram] ikut menskalakan nutrisinya, karena angka yang
  /// dikoreksi user memang porsinya — bukan kandungan gizi per gram.
  ItemMakanan salin({String? nama, String? porsi, double? estimasiGram}) {
    final gramBaru = estimasiGram ?? this.estimasiGram;
    final faktor = this.estimasiGram <= 0 ? 1.0 : gramBaru / this.estimasiGram;
    return ItemMakanan(
      nama: nama ?? this.nama,
      porsi: porsi ?? this.porsi,
      estimasiGram: gramBaru,
      nutrisi: nutrisi * faktor,
    );
  }
}

class HasilDeteksi {
  const HasilDeteksi({
    required this.makanan,
    required this.total,
    required this.indeksGlikemikPerkiraan,
    required this.keyakinan,
    this.dikoreksiUser = false,
  });

  final List<ItemMakanan> makanan;
  final Nutrisi total;
  final String indeksGlikemikPerkiraan; // "rendah" | "sedang" | "tinggi"
  final double keyakinan; // 0..1
  final bool dikoreksiUser;

  /// Hasil dengan daftar makanan yang sudah dikoreksi user.
  ///
  /// Totalnya dihitung ulang dari itemnya, dan `dikoreksiUser` menjadi true —
  /// itulah yang membuat sesi ini tetap ikut diplot di Analisis meskipun
  /// keyakinan deteksi awalnya rendah (§4.3).
  HasilDeteksi dikoreksi(List<ItemMakanan> makananBaru) {
    var total = Nutrisi.kosong;
    for (final m in makananBaru) {
      total = total + m.nutrisi;
    }
    return HasilDeteksi(
      makanan: makananBaru,
      total: total,
      indeksGlikemikPerkiraan: indeksGlikemikPerkiraan,
      keyakinan: keyakinan,
      dikoreksiUser: true,
    );
  }

  /// Nama gabungan untuk judul kartu, mis. "Nasi ayam & tumis buncis".
  String get ringkasanNama {
    if (makanan.isEmpty) return 'Makanan';
    return makanan.map((m) => m.nama).join(' & ');
  }
}

/// Hasil kalibrasi tekanan darah (§5, §4.7).
///
/// User memasukkan hasil tensimeter, jam mengukur bersamaan, dan selisih
/// keduanya menjadi koefisien yang dikirim ke jam.
class Kalibrasi {
  const Kalibrasi({
    required this.waktu,
    required this.sistolikReferensi,
    required this.diastolikReferensi,
    required this.sistolikJam,
    required this.diastolikJam,
  });

  final DateTime waktu;
  final int sistolikReferensi; // dari tensimeter
  final int diastolikReferensi;
  final int sistolikJam; // pembacaan jam pada saat yang sama
  final int diastolikJam;

  int get offsetSistolik => sistolikReferensi - sistolikJam;
  int get offsetDiastolik => diastolikReferensi - diastolikJam;

  String get ringkasanOffset {
    String tanda(int n) => n >= 0 ? '+$n' : '$n';
    return '${tanda(offsetSistolik)}/${tanda(offsetDiastolik)} mmHg';
  }
}

/// Status jam yang ditampilkan apa adanya di sesi berjalan (§8).
class StatusPerangkat {
  const StatusPerangkat({
    required this.tersambung,
    this.baterai,
    this.sampelTertunda = 0,
    this.sinkronTerakhir,
    this.namaPerangkat,
  });

  final bool tersambung;
  final int? baterai; // persen
  final int sampelTertunda; // masih tertahan di buffer jam
  final DateTime? sinkronTerakhir;

  /// Nama jam yang sedang/terakhir dipasangkan. null berarti belum pernah ada
  /// perangkat yang dipasangkan sama sekali — bedanya dengan `tersambung:
  /// false` adalah yang terakhir cuma putus sementara, dan sampelnya masih
  /// menunggu di buffer.
  final String? namaPerangkat;

  /// Belum pernah dipasangkan, jadi UI harus menawarkan pemindaian, bukan
  /// sekadar "menunggu tersambung kembali".
  bool get belumDipasangkan => namaPerangkat == null;

  StatusPerangkat salin({
    bool? tersambung,
    int? baterai,
    int? sampelTertunda,
    DateTime? sinkronTerakhir,
    String? namaPerangkat,
  }) {
    return StatusPerangkat(
      tersambung: tersambung ?? this.tersambung,
      baterai: baterai ?? this.baterai,
      sampelTertunda: sampelTertunda ?? this.sampelTertunda,
      sinkronTerakhir: sinkronTerakhir ?? this.sinkronTerakhir,
      namaPerangkat: namaPerangkat ?? this.namaPerangkat,
    );
  }
}

/// Satu jam yang terlihat saat memindai (§12.5, tambahan alur pemasangan).
///
/// [kekuatanSinyal] adalah RSSI dalam dBm — selalu negatif, makin dekat nol
/// makin kuat. Dipakai UI untuk mengurutkan dan menggambar bar sinyal.
class PerangkatDitemukan {
  const PerangkatDitemukan({
    required this.id,
    required this.nama,
    required this.kekuatanSinyal,
    this.didukung = true,
  });

  final String id;
  final String nama;
  final int kekuatanSinyal;

  /// false untuk perangkat BLE lain yang kebetulan ikut terlihat; ditampilkan
  /// supaya user tahu pemindaiannya jalan, tetapi tidak bisa disambungkan.
  final bool didukung;

  /// 1..4 batang, cukup untuk indikator sinyal sederhana.
  int get batangSinyal => switch (kekuatanSinyal) {
    >= -55 => 4,
    >= -70 => 3,
    >= -85 => 2,
    _ => 1,
  };
}
