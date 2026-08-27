/// Model inti untuk konsep "sesi makan" — lihat docs/rancangan-ui-sesi-makan.md §12.
///
/// Satu sesi = satu foto makanan, satu t0 ("selesai makan"), dan empat sampel
/// pengukuran dengan index yang bermakna tetap (§12.1). Semua nilai turunan
/// (baseline, puncak, delta, waktu pemulihan, verdict) dihitung di sini,
/// tidak disimpan.
library;

import 'jadwal_sesi.dart';

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
///
/// Diturunkan dari [jadwalNormal], bukan ditulis ulang: jadwal dan labelnya
/// adalah satu hal, dan dua daftar yang harus dijaga sebanding pada akhirnya
/// akan berselisih. Sengaja dari jadwal **sungguhan** meski mode uji memakai
/// jadwal yang dikecilkan — label sebuah titik menyebut maknanya ("+1 jam"),
/// bukan durasinya di mode itu, dan itu memang yang ingin dibaca penguji.
final List<String> labelTitikSampel = jadwalNormal.label;

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
  DateTime waktuUkur(DateTime t0) => t0.add(Duration(seconds: detikRelatifT0));

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
    this.sesiUji = false,
    this.diperbaruiPada,
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

  /// Kapan isi sesi ini terakhir berubah **di perangkat ini**, atau null bila
  /// belum pernah ditulis sejak kolom ini ada (v6).
  ///
  /// Distempel oleh `SesiRepository` saat menyimpan, bukan oleh pemanggilnya:
  /// setiap penulisan lokal adalah perubahan lokal, dan satu tempat yang
  /// menstempel tidak bisa lupa seperti selusin pemanggil. Dikirim ke server
  /// sebagai `diperbarui_pada` dan menjadi bahan aturan "yang terbaru menang"
  /// (§7.1) — sebelum ada kolom ini, aplikasi mengirim waktu **pengiriman**,
  /// sehingga kiriman ulang yang isinya sama pun mengaku lebih baru dan akan
  /// menimpa suntingan dari perangkat lain.
  final DateTime? diperbaruiPada;

  /// Sesi ini dibuat oleh rakitan mode jadwal uji — jadwal dua menit, bukan dua
  /// jam (docs/jadwal-titik-ukur.md §7).
  ///
  /// Ia **tetap disimpan dan tetap tampil di Riwayat**, dengan lencana:
  /// menyembunyikannya akan membuat mustahil memverifikasi bahwa persistensinya
  /// bekerja — yang justru salah satu hal yang sedang diuji. Yang dilarang
  /// adalah membiarkannya ikut dihitung: angka dari sesi dua menit di dalam
  /// garis tren `AnalisisSesi` adalah pencemaran yang besok tidak akan terlihat
  /// lagi sebagai pencemaran.
  final bool sesiUji;

  SesiMakan salin({
    String? fotoPath,
    DateTime? t0,
    StatusSesi? status,
    HasilDeteksi? hasil,
    List<Sampel>? sampel,
    bool? waktuTidakPasti,
    bool? sesiUji,
    DateTime? diperbaruiPada,
  }) {
    return SesiMakan(
      id: id,
      fotoPath: fotoPath ?? this.fotoPath,
      waktuFoto: waktuFoto,
      t0: t0 ?? this.t0,
      status: status ?? this.status,
      hasil: hasil ?? this.hasil,
      sampel: sampel ?? this.sampel,
      waktuTidakPasti: waktuTidakPasti ?? this.waktuTidakPasti,
      sesiUji: sesiUji ?? this.sesiUji,
      diperbaruiPada: diperbaruiPada ?? this.diperbaruiPada,
    );
  }

  /// Jadwal yang berlaku untuk sesi ini.
  ///
  /// Diturunkan dari [sesiUji], bukan dibaca dari konfigurasi rakitan yang
  /// sedang berjalan: sesi lama harus tetap dinilai dengan jadwal yang berlaku
  /// saat ia direkam. Rakitan uji yang membuka riwayat sungguhan tidak boleh
  /// menyatakan seluruh titiknya telat karena diukur dengan penggaris dua menit.
  JadwalSesi get jadwal => sesiUji ? jadwalUji : jadwalNormal;

  /// Pengukuran ini tiba di luar jendela toleransi titiknya
  /// (docs/jadwal-titik-ukur.md §3).
  ///
  /// Dihitung, tidak disimpan: [Sampel.detikRelatifT0] sudah merekam kapan
  /// pengukurannya benar-benar terjadi, dan jendelanya ada di [jadwal] — jadi
  /// sebuah kolom di sini hanya akan menduplikasi keduanya, lalu berselisih
  /// dengan salah satunya.
  ///
  /// Hanya "telat" yang ditandai, tidak ada padanan "terlalu cepat". Itu bukan
  /// kelalaian melainkan asimetri yang jadi aturannya: pengukuran yang terlalu
  /// cepat ditahan sebelum terjadi — titiknya belum lewat dan masih bisa diukur
  /// ulang — sedangkan yang telat sudah tidak punya pengganti dan hanya bisa
  /// diterima apa adanya.
  bool sampelTelat(Sampel s) {
    if (!s.terisi) return false;
    final titik = jadwal.titik.where((t) => t.index == s.index);
    if (titik.isEmpty) return false;
    return titik.first.telat(s.detikRelatifT0);
  }

  /// Label titik yang **ikut jujur saat pengukurannya meleset**.
  ///
  /// "+1 jam" selama selisihnya kosmetik; "+1 jam 24 mnt" begitu tidak. Label
  /// nominal di atas pengukuran yang telat 24 menit bukan merapikan tampilan,
  /// itu menyembunyikan satu-satunya hal yang menjelaskan kenapa angkanya
  /// mengejutkan.
  String labelSampel(Sampel s) {
    if (!s.terisi || !sampelTelat(s)) return s.label;
    final menit = (s.detikRelatifT0 / 60).round();
    final jam = menit ~/ 60;
    final sisa = menit % 60;
    if (jam == 0) return '+$sisa mnt';
    return sisa == 0 ? '+$jam jam' : '+$jam jam $sisa mnt';
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
  ///
  /// **Yang membandingkan titik di sini adalah `detikRelatifT0`, bukan `index`.**
  /// Keduanya memberi jawaban yang sama selama jadwalnya empat titik yang
  /// kebetulan berurutan waktu — dan itulah yang membuat versi lama (`s.index <=
  /// puncak.index`) tampak benar. Ia meleset pada titik pertama yang disisipkan:
  /// `+30 menit` yang ditambahkan sebagai `index: 4` akan terbaca sebagai
  /// "sesudah +2 jam", dan pemulihannya salah dihitung tanpa satu pun gejala.
  /// Sejak jadwal jadi data per sesi (docs/jadwal-titik-ukur.md §1), penyisipan
  /// itu berhenti menjadi hal yang mustahil, jadi asumsinya diganti dengan hal
  /// yang memang dimaksud kalimat ini: urutan waktu.
  Duration? get waktuPemulihan {
    final dasar = gulaDarahBaseline;
    final puncak = sampelPuncak;
    if (dasar == null || puncak == null) return null;
    final urut = [...sampel]
      ..sort((a, b) => a.detikRelatifT0.compareTo(b.detikRelatifT0));
    for (final s in urut) {
      if (s.detikRelatifT0 <= puncak.detikRelatifT0 ||
          !s.terisi ||
          s.gulaDarah == null) {
        continue;
      }
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
    if (delta == null || status.sedangAktif) {
      return KualitasRespons.belumLengkap;
    }
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

/// Satu dari enam zat gizi yang dilaporkan.
///
/// Ada sebagai enum, bukan sebagai string lepas, karena ia dipakai di tiga
/// tempat sekaligus: nama field di kabel (§5.2), penanda `zatTidakLengkap`, dan
/// label di layar. Tiga daftar yang harus sebanding adalah tiga daftar yang
/// cepat atau lambat berselisih.
enum ZatGizi {
  kalori('kalori', 'Kalori', ' kcal'),
  karbohidrat('karbohidrat', 'Karbohidrat', ' g'),
  protein('protein', 'Protein', ' g'),
  lemak('lemak', 'Lemak', ' g'),
  gulaTotal('gula_total', 'Gula Total', ' g'),
  serat('serat', 'Serat', ' g');

  const ZatGizi(this.kunci, this.label, this.satuan);

  /// Nama field di JSON §5.2 — bukan `name`, karena `gulaTotal` di Dart adalah
  /// `gula_total` di kabel.
  final String kunci;
  final String label;
  final String satuan;

  static ZatGizi? dariKunci(String kunci) =>
      values.where((z) => z.kunci == kunci).firstOrNull;
}

/// Enam angka makro satu makanan atau satu sesi.
///
/// **Setiap angka boleh null, dan null berarti "tidak diketahui" — bukan nol.**
/// Perbedaan itu bukan kerapian: sumber angkanya adalah tabel TKPI, yang tidak
/// memuat kolom gula sama sekali dan kosong pada serat untuk ratusan bahan,
/// dan makanan yang belum punya padanan di sana tidak menghasilkan satu angka
/// pun. Menampilkan ketidaktahuan itu sebagai "0 g" adalah klaim — dan pada
/// aplikasi yang justru mengukur gula darah, klaim yang salah.
class Nutrisi {
  const Nutrisi({
    required this.kalori,
    required this.karbohidrat,
    required this.protein,
    required this.lemak,
    required this.gulaTotal,
    required this.serat,
  });

  /// Semuanya nol — makanan yang memang tidak menyumbang apa pun.
  static const Nutrisi kosong = Nutrisi(
    kalori: 0,
    karbohidrat: 0,
    protein: 0,
    lemak: 0,
    gulaTotal: 0,
    serat: 0,
  );

  /// Tidak satu pun diketahui — makanan yang tidak ada di tabel gizi.
  static const Nutrisi tidakDiketahui = Nutrisi(
    kalori: null,
    karbohidrat: null,
    protein: null,
    lemak: null,
    gulaTotal: null,
    serat: null,
  );

  final double? kalori, karbohidrat, protein, lemak, gulaTotal, serat;

  double? operator [](ZatGizi zat) => switch (zat) {
    ZatGizi.kalori => kalori,
    ZatGizi.karbohidrat => karbohidrat,
    ZatGizi.protein => protein,
    ZatGizi.lemak => lemak,
    ZatGizi.gulaTotal => gulaTotal,
    ZatGizi.serat => serat,
  };

  /// Zat yang angkanya tidak diketahui di sini.
  Set<ZatGizi> get zatTidakDiketahui => {
    for (final z in ZatGizi.values)
      if (this[z] == null) z,
  };

  /// Menskalakan seluruh makro sekaligus — dipakai saat user mengoreksi porsi
  /// ("1 piring" → "setengah piring"), §4.5. Yang tidak diketahui tetap tidak
  /// diketahui: setengah dari entah berapa tetap entah berapa.
  Nutrisi operator *(double faktor) => Nutrisi(
    kalori: kalori == null ? null : kalori! * faktor,
    karbohidrat: karbohidrat == null ? null : karbohidrat! * faktor,
    protein: protein == null ? null : protein! * faktor,
    lemak: lemak == null ? null : lemak! * faktor,
    gulaTotal: gulaTotal == null ? null : gulaTotal! * faktor,
    serat: serat == null ? null : serat! * faktor,
  );

  /// Menjumlahkan, dan **yang tidak diketahui diperlakukan sebagai nol** —
  /// tetapi penjumlahannya sendiri tidak menyimpan ingatan bahwa itu terjadi.
  /// Yang menyimpannya adalah [HasilDeteksi.zatTidakLengkap], dan itulah yang
  /// membuat totalnya dibaca sebagai "sekurang-kurangnya", bukan "tepat".
  Nutrisi operator +(Nutrisi lain) => Nutrisi(
    kalori: _jumlah(kalori, lain.kalori),
    karbohidrat: _jumlah(karbohidrat, lain.karbohidrat),
    protein: _jumlah(protein, lain.protein),
    lemak: _jumlah(lemak, lain.lemak),
    gulaTotal: _jumlah(gulaTotal, lain.gulaTotal),
    serat: _jumlah(serat, lain.serat),
  );

  /// null + null tetap null: menjumlahkan dua ketidaktahuan tidak menghasilkan
  /// nol. Yang satunya diketahui berarti totalnya parsial, dan itu ditandai di
  /// tempat lain.
  static double? _jumlah(double? a, double? b) {
    if (a == null && b == null) return null;
    return (a ?? 0) + (b ?? 0);
  }
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
    this.indeksGlikemikPerkiraan,
    this.keyakinan,
    this.zatTidakLengkap = const {},
    this.dikoreksiUser = false,
  });

  final List<ItemMakanan> makanan;
  final Nutrisi total;

  /// "rendah" | "sedang" | "tinggi", atau **null bila tidak diketahui**.
  ///
  /// Nullable sejak layanan deteksi sungguhan dipasang: tabel TKPI tidak punya
  /// kolom indeks glikemik sama sekali. Sebelumnya nilai yang hilang diam-diam
  /// menjadi "sedang" — sebuah taksiran yang tidak pernah dibuat siapa pun,
  /// tampil sebagai fakta.
  final String? indeksGlikemikPerkiraan;

  /// 0..1, atau null bila layanan tidak menghasilkan keyakinan terkalibrasi.
  /// null bukan 0: "tidak tahu seberapa yakin" bukan "yakin nol persen".
  final double? keyakinan;

  /// Zat yang angkanya di [total] hanya **jumlah parsial** (§5.2
  /// `zat_tidak_lengkap`): ada makanan pada sesi ini yang tidak menyumbang
  /// angka untuk zat itu, entah karena tidak ada di tabel gizi atau karena
  /// selnya kosong di sana.
  ///
  /// Dibawa terpisah dari [total] karena angkanya sendiri tetap berguna — ia
  /// hanya berarti "sekurang-kurangnya sekian", bukan "tepat sekian". Dan bila
  /// angkanya nol sementara zatnya ada di sini, artinya bukan "tanpa kalori"
  /// melainkan "belum ada satu pun angka".
  final Set<ZatGizi> zatTidakLengkap;

  final bool dikoreksiUser;

  /// Apakah [zat] pada [total] boleh dibaca sebagai angka yang pasti.
  bool pasti(ZatGizi zat) =>
      total[zat] != null && !zatTidakLengkap.contains(zat);

  /// Hasil dengan daftar makanan yang sudah dikoreksi user.
  ///
  /// Totalnya dihitung ulang dari itemnya, dan `dikoreksiUser` menjadi true —
  /// itulah yang membuat sesi ini tetap ikut diplot di Analisis meskipun
  /// keyakinan deteksi awalnya rendah (§4.3).
  HasilDeteksi dikoreksi(List<ItemMakanan> makananBaru) {
    var total = Nutrisi.tidakDiketahui;
    for (final m in makananBaru) {
      total = total + m.nutrisi;
    }
    return HasilDeteksi(
      makanan: makananBaru,
      total: total,
      indeksGlikemikPerkiraan: indeksGlikemikPerkiraan,
      keyakinan: keyakinan,
      // Dihitung ulang dari itemnya, bukan diwarisi: koreksi user bisa
      // menghapus makanan yang tadinya membuat sebuah zat menjadi parsial, dan
      // bisa pula menambah yang baru.
      zatTidakLengkap: {
        for (final z in ZatGizi.values)
          if (makananBaru.any((m) => m.nutrisi[z] == null)) z,
      },
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
/// Pergelangan tempat jam dipakai saat dikalibrasi.
///
/// Ikut disimpan karena koreksinya **hanya berlaku untuk tangan itu**: tekanan
/// yang terbaca di pergelangan kiri dan kanan orang yang sama bisa berbeda
/// belasan mmHg, jadi kalibrasi yang dipindah tangan diam-diam menjadi salah.
enum SisiPergelangan {
  kiri('Tangan kiri'),
  kanan('Tangan kanan');

  const SisiPergelangan(this.label);
  final String label;

  /// Sisi seberangnya — tempat manset tensimeter dipasang saat kalibrasi.
  ///
  /// Manset dan jam tidak boleh berada di lengan yang sama: manset yang
  /// mengembang menutup aliran darah ke pergelangan di bawahnya, sehingga jam
  /// justru buta pada detik yang sedang diukur.
  SisiPergelangan get seberang => this == kiri ? kanan : kiri;

  /// Sebutan untuk lengan, dipakai saat berbicara tentang manset.
  String get labelLengan => this == kiri ? 'lengan kiri' : 'lengan kanan';
}

/// Satu putaran kalibrasi: sepasang bacaan tensimeter dan jam yang diambil
/// berdekatan.
class PutaranKalibrasi {
  const PutaranKalibrasi({
    required this.sistolikReferensi,
    required this.diastolikReferensi,
    required this.sistolikJam,
    required this.diastolikJam,
  });

  final int sistolikReferensi; // dari tensimeter
  final int diastolikReferensi;
  final int sistolikJam; // pembacaan jam pada saat yang sama
  final int diastolikJam;

  int get offsetSistolik => sistolikReferensi - sistolikJam;
  int get offsetDiastolik => diastolikReferensi - diastolikJam;

  String get ringkasanReferensi => '$sistolikReferensi/$diastolikReferensi';
  String get ringkasanJam => '$sistolikJam/$diastolikJam';
}

/// Rentang tensimeter yang masih masuk akal untuk dijadikan acuan.
///
/// Bukan penilaian medis, hanya penyaring salah ketik: angka di luar ini
/// hampir selalu berarti kolomnya tertukar atau ada digit yang kelebihan, dan
/// satu salah ketik di sini menghasilkan koreksi yang salah selama empat
/// minggu penuh.
const int sistolikMinimum = 70;
const int sistolikMaksimum = 250;
const int diastolikMinimum = 40;
const int diastolikMaksimum = 150;

/// Alasan sepasang angka tensimeter ditolak, atau null bila keduanya wajar.
///
/// Dipisahkan dari halamannya supaya bisa dites tanpa memompa widget, dan
/// supaya kalimatnya cuma ada di satu tempat.
String? galatReferensiTensimeter({int? sistolik, int? diastolik}) {
  if (sistolik == null || diastolik == null) return null; // belum lengkap
  if (sistolik < sistolikMinimum || sistolik > sistolikMaksimum) {
    return 'Sistolik biasanya antara $sistolikMinimum dan $sistolikMaksimum '
        'mmHg. Periksa lagi angka di tensimeter.';
  }
  if (diastolik < diastolikMinimum || diastolik > diastolikMaksimum) {
    return 'Diastolik biasanya antara $diastolikMinimum dan $diastolikMaksimum '
        'mmHg. Periksa lagi angka di tensimeter.';
  }
  if (sistolik <= diastolik) {
    return 'Sistolik harus lebih besar dari diastolik. Angka atas di kolom '
        'kiri, angka bawah di kolom kanan.';
  }
  return null;
}

/// Kalibrasi tekanan darah: **tiga** putaran tensimeter + jam, bukan satu.
///
/// Metodenya mengikuti alat sejenis yang sudah dipakai luas (Samsung Health
/// Monitor). Tiga hal di dalamnya bukan hiasan:
///
/// 1. **Tiga putaran, koreksinya diambil median.** Satu pengukuran manset
///    tunggal bisa meleset belasan mmHg karena manset kendur, lengan tidak
///    setinggi jantung, atau user baru saja berjalan. Dengan satu putaran,
///    meleset itu langsung menjadi koreksi permanen. Median dari tiga tahan
///    terhadap satu putaran yang kacau; rata-rata tidak.
/// 2. **Kalibrasi punya tanggal kedaluwarsa** ([masaBerlaku], 4 minggu).
///    Hubungan antara gelombang nadi di pergelangan dan tekanan sebenarnya
///    ikut bergeser mengikuti tonus pembuluh, berat badan, dan obat. Koreksi
///    yang tidak pernah kedaluwarsa akan dipercaya bertahun-tahun.
/// 3. **Terikat pada satu pergelangan** ([sisi]).
class Kalibrasi {
  Kalibrasi({required this.waktu, required this.putaran, required this.sisi})
    : assert(
        putaran.isNotEmpty,
        'Kalibrasi tanpa putaran tidak berarti apa-apa',
      );

  /// Kalibrasi satu putaran — bentuk yang dipakai sebelum metode tiga putaran.
  ///
  /// Masih ada karena baris yang tersimpan di basis data sebelum skema v4
  /// memang hanya punya satu pasang angka; jangan dipakai untuk kalibrasi baru.
  Kalibrasi.tunggal({
    required DateTime waktu,
    required int sistolikReferensi,
    required int diastolikReferensi,
    required int sistolikJam,
    required int diastolikJam,
    SisiPergelangan sisi = SisiPergelangan.kiri,
  }) : this(
         waktu: waktu,
         sisi: sisi,
         putaran: [
           PutaranKalibrasi(
             sistolikReferensi: sistolikReferensi,
             diastolikReferensi: diastolikReferensi,
             sistolikJam: sistolikJam,
             diastolikJam: diastolikJam,
           ),
         ],
       );

  /// Jumlah putaran yang diminta alur kalibrasi baru.
  static const int jumlahPutaran = 3;

  /// Jeda minimum antar putaran. Manset yang langsung dipompa ulang membaca
  /// terlalu tinggi — pembuluh di lengan belum pulih dari tekanan sebelumnya.
  static const Duration jedaAntarPutaran = Duration(seconds: 60);

  /// Selisih offset terbesar yang masih dianggap satu keadaan yang sama
  /// (mmHg). Di atas ini ketiga putaran bercerita tentang tiga tekanan yang
  /// berbeda, dan mediannya tidak mewakili apa pun.
  static const int sebaranMaksimum = 12;

  static const Duration masaBerlaku = Duration(days: 28);

  final DateTime waktu;
  final List<PutaranKalibrasi> putaran;
  final SisiPergelangan sisi;

  static int _median(List<int> nilai) {
    final urut = [...nilai]..sort();
    return urut[urut.length ~/ 2];
  }

  static int _sebaran(List<int> nilai) =>
      nilai.reduce((a, b) => a > b ? a : b) -
      nilai.reduce((a, b) => a < b ? a : b);

  int get offsetSistolik =>
      _median([for (final p in putaran) p.offsetSistolik]);
  int get offsetDiastolik =>
      _median([for (final p in putaran) p.offsetDiastolik]);

  int get sebaranSistolik =>
      _sebaran([for (final p in putaran) p.offsetSistolik]);
  int get sebaranDiastolik =>
      _sebaran([for (final p in putaran) p.offsetDiastolik]);

  /// Ketiga putaran cukup mirip satu sama lain untuk dirangkum jadi satu
  /// koreksi. Bila tidak, yang benar adalah mengulang — bukan mengirim median
  /// dari angka yang saling bertentangan.
  bool get konsisten =>
      sebaranSistolik <= sebaranMaksimum && sebaranDiastolik <= sebaranMaksimum;

  DateTime get berlakuSampai => waktu.add(masaBerlaku);

  bool kedaluwarsaPada(DateTime kini) => !kini.isBefore(berlakuSampai);

  /// Sisa hari sebelum kedaluwarsa; 0 berarti habis hari ini atau sudah lewat.
  int sisaHariPada(DateTime kini) {
    final sisa = berlakuSampai.difference(kini).inHours;
    return sisa <= 0 ? 0 : (sisa / 24).ceil();
  }

  String get ringkasanOffset {
    String tanda(int n) => n >= 0 ? '+$n' : '$n';
    return '${tanda(offsetSistolik)}/${tanda(offsetDiastolik)} mmHg';
  }
}

/// Satu pindai kesehatan atas permintaan — hasil `UKUR_SEKARANG` (protokol
/// §5.1) di luar sesi makan mana pun.
///
/// Bukan [SesiMakan] dan sengaja tidak dijadikan satu: ia tidak punya makanan,
/// tidak punya `t0`, dan tidak punya tiga titik pembanding, sehingga tidak satu
/// pun hitungan di `AnalisisSesi` berlaku untuknya. [waktu] adalah waktu ponsel
/// saat jawabannya diterima, dan itu memang sah di sini — berbeda dari sampel
/// sesi, pindai hanya terjadi selagi jam tersambung dan menjawab seketika, jadi
/// tidak ada jalur buffer yang bisa membuatnya datang berjam-jam terlambat.
class HasilPindai {
  const HasilPindai({required this.waktu, required this.sampel});

  final DateTime waktu;
  final Sampel sampel;

  /// Tidak satu metrik pun terbaca. Dibedakan dari sebagian gagal karena
  /// tindak lanjutnya berbeda: yang ini selalu berarti jam tidak menempel
  /// dengan benar, bukan satu sensor yang kebetulan meleset.
  bool get kosong =>
      sampel.gulaDarah == null &&
      sampel.detakJantung == null &&
      sampel.tekananDarah == null &&
      sampel.spo2 == null;

  /// Ada metrik yang terbaca dan ada yang tidak.
  bool get sebagianGagal =>
      !kosong &&
      (sampel.gulaDarah == null ||
          sampel.detakJantung == null ||
          sampel.tekananDarah == null ||
          sampel.spo2 == null);
}

/// Metrik yang benar-benar bisa diukur jam ini — bitfield `kemampuan` di
/// handshake (docs/protokol-jam.md §3, byte 11).
///
/// **Ini bukan hiasan**, dan §3 menyatakannya sebagai kewajiban: metrik yang
/// bit-nya 0 harus **disembunyikan** dari UI, bukan ditampilkan sebagai `—`.
/// Bedanya besar bagi yang membaca layar. `—` berarti "diukur tetapi gagal" —
/// kalimat yang mengundang orang merapatkan tali jam, mencoba lagi, dan
/// menyalahkan dirinya sendiri untuk sensor yang memang tidak ada di alat itu.
///
/// **Detak jantung tidak punya bit** di §3 dan karena itu selalu dianggap ada;
/// jangan mengarang bit untuknya. Bit3 (OTA) bukan metrik dan tidak diwakili di
/// sini.
class KemampuanPerangkat {
  const KemampuanPerangkat({
    required this.gulaDarah,
    required this.tekananDarah,
    required this.spo2,
  });

  /// Jawaban saat kemampuannya **belum diketahui** — sebelum handshake pertama,
  /// dan untuk sesi lama di riwayat yang jamnya mungkin sudah bukan jam ini.
  ///
  /// Sengaja "semua boleh", bukan "semua disembunyikan": menyembunyikan angka
  /// yang **sudah ada di basis data** karena kita belum sempat bertanya ke jam
  /// adalah kerugian yang pasti, ditukar dengan kerapian yang belum tentu benar.
  static const KemampuanPerangkat semua = KemampuanPerangkat(
    gulaDarah: true,
    tekananDarah: true,
    spo2: true,
  );

  final bool gulaDarah;
  final bool tekananDarah;
  final bool spo2;

  @override
  bool operator ==(Object other) =>
      other is KemampuanPerangkat &&
      other.gulaDarah == gulaDarah &&
      other.tekananDarah == tekananDarah &&
      other.spo2 == spo2;

  @override
  int get hashCode => Object.hash(gulaDarah, tekananDarah, spo2);
}

/// Status jam yang ditampilkan apa adanya di sesi berjalan (§8).
class StatusPerangkat {
  const StatusPerangkat({
    required this.tersambung,
    int? baterai,
    this.sampelTertunda = 0,
    this.sinkronTerakhir,
    this.namaPerangkat,
    this.penyandinganHilang = false,
    this.kemampuan,
  }) : _bateraiTerakhir = baterai;

  /// Belum pernah ada jam yang dipasangkan sama sekali.
  static const StatusPerangkat kosong = StatusPerangkat(tersambung: false);

  final bool tersambung;

  final int? _bateraiTerakhir;

  /// Level baterai jam dalam persen, atau null kalau tidak diketahui.
  ///
  /// **Jam yang terputus selalu null.** Baterai hanya terbaca selagi tautan
  /// hidup (characteristic `0x2A19`), jadi begitu jam lepas, angka terakhir
  /// hanya menua: jam yang dipakai seharian di luar jangkauan ponsel akan
  /// tetap "100%" di layar sampai tersambung lagi. Menahan angka basi itu
  /// lebih buruk daripada tidak menampilkan apa pun — user memutuskan
  /// mengisi daya atau tidak berdasarkan angka itu.
  ///
  /// Aturannya ada di sini, bukan di tiap halaman, supaya permukaan baru tidak
  /// bisa lupa. Konsekuensinya [salin] ikut membuang angkanya begitu status
  /// berubah jadi terputus; nilai yang segar datang lagi dari paket status
  /// saat menyambung (§7) dan dari langganan Battery Service.
  int? get baterai => tersambung ? _bateraiTerakhir : null;
  final int sampelTertunda; // masih tertahan di buffer jam
  final DateTime? sinkronTerakhir;

  /// Jam masih tercatat dipasangkan di aplikasi, tetapi ponsel sudah tidak
  /// menyandingkannya — user menghapusnya lewat Pengaturan Bluetooth sistem,
  /// atau jamnya di-reset.
  ///
  /// Dibedakan dari sekadar terputus karena tindak lanjutnya bertolak belakang:
  /// yang terputus akan tersambung sendiri dan sampelnya menyusul, sedangkan
  /// yang ini **tidak akan pernah** sampai user menyandingkannya lagi. Aplikasi
  /// sengaja tidak menyandinginya sendiri dari latar belakang — dialog
  /// penyandingan yang muncul entah kapan, tanpa user sedang memasang apa pun,
  /// adalah permintaan yang tidak mungkin dimengerti
  /// (docs/alur-pemasangan-jam.md §4.5).
  final bool penyandinganHilang;

  /// Nama jam yang sedang/terakhir dipasangkan. null berarti belum pernah ada
  /// perangkat yang dipasangkan sama sekali — bedanya dengan `tersambung:
  /// false` adalah yang terakhir cuma putus sementara, dan sampelnya masih
  /// menunggu di buffer.
  final String? namaPerangkat;

  /// Metrik yang bisa diukur jam ini, dari handshake (§3). null berarti
  /// **belum diketahui** — belum pernah handshake sejak aplikasi dibuka.
  ///
  /// Berbeda dari [baterai], nilainya **tidak dibuang saat jam terputus**, dan
  /// perbedaan itu disengaja: baterai menua tiap menit, sedangkan jam tidak
  /// menumbuhkan sensor SpO2 selagi berada di luar jangkauan. Menyembunyikan
  /// metrik hanya selagi tersambung, lalu menampilkannya lagi begitu putus,
  /// adalah layar yang berubah-ubah tanpa ada yang berubah.
  final KemampuanPerangkat? kemampuan;

  /// Metrik yang boleh ditampilkan sekarang. Selama [kemampuan] belum diketahui,
  /// jawabannya semua — lihat [KemampuanPerangkat.semua].
  KemampuanPerangkat get metrikTampil => kemampuan ?? KemampuanPerangkat.semua;

  /// Belum pernah dipasangkan, jadi UI harus menawarkan pemindaian, bukan
  /// sekadar "menunggu tersambung kembali".
  bool get belumDipasangkan => namaPerangkat == null;

  StatusPerangkat salin({
    bool? tersambung,
    int? baterai,
    int? sampelTertunda,
    DateTime? sinkronTerakhir,
    String? namaPerangkat,
    bool? penyandinganHilang,
    KemampuanPerangkat? kemampuan,
  }) {
    return StatusPerangkat(
      tersambung: tersambung ?? this.tersambung,
      // `this.baterai` di sini adalah getter-nya, jadi menyalin status yang
      // sudah terputus tidak membawa angka lama ikut serta — sekali putus,
      // angkanya hilang dan hanya bacaan baru yang bisa mengisinya.
      baterai: baterai ?? this.baterai,
      sampelTertunda: sampelTertunda ?? this.sampelTertunda,
      sinkronTerakhir: sinkronTerakhir ?? this.sinkronTerakhir,
      namaPerangkat: namaPerangkat ?? this.namaPerangkat,
      penyandinganHilang: penyandinganHilang ?? this.penyandinganHilang,
      // Ditahan, tidak seperti baterai: lihat alasannya di definisi field-nya.
      kemampuan: kemampuan ?? this.kemampuan,
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
