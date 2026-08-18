/// Codec protokol jam tangan — docs/protokol-jam.md.
///
/// Seluruh berkas ini adalah **byte ↔ Dart** dan tidak lebih dari itu: tidak ada
/// BLE, tidak ada I/O, tidak ada state. Alasannya bukan kerapian melainkan
/// pengujian — inilah satu-satunya bagian Tahap B yang bisa diuji tuntas tanpa
/// hardware, jadi ia sengaja dipisahkan dari [BleAsliService] yang tidak bisa.
///
/// Dokumen protokol normatif (§1 kalimat pembuka): bila berkas ini dan dokumen
/// itu berbeda, salah satunya bug. Nomor pasal disebut di tiap bagian supaya
/// perbedaannya bisa ditelusuri, bukan ditebak.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

/// Kesalahan bentuk paket: panjang tidak cukup, nilai di luar jangkauan, atau
/// jenis yang tidak dikenal.
///
/// Dibedakan dari [GalatVersiJam] karena penanganannya berbeda: yang ini dicatat
/// lalu paketnya dibuang, yang itu memutus koneksi dengan pesan ke pengguna.
class GalatProtokol implements Exception {
  const GalatProtokol(this.pesan);
  final String pesan;

  @override
  String toString() => 'GalatProtokol: $pesan';
}

/// Kegagalan perintah ke jam yang sudah tidak bisa diperbaiki dengan mencoba
/// lagi. [pesanPengguna] siap ditampilkan.
///
/// Tinggal di sini, bukan di `ble_asli_service.dart` tempatnya dulu, karena
/// [FakeBleService] harus bisa melemparkannya juga: jalur gagal sebuah perintah
/// tidak boleh hanya ada pada implementasi yang tidak bisa dites. Berkas ini
/// murni byte ↔ Dart dan tidak menyentuh `flutter_blue_plus`, jadi kontrak
/// [BleService] bisa memakainya tanpa menyeret radionya ikut serta.
/// `ble_asli_service.dart` mengekspornya kembali agar `import ... show GalatJam`
/// yang sudah ada tetap bekerja.
class GalatJam implements Exception {
  const GalatJam(this.pesanPengguna, {this.kode});

  final String pesanPengguna;
  final KodeGalatJam? kode;

  @override
  String toString() => 'GalatJam($kode): $pesanPengguna';
}

/// Versi mayor firmware tidak cocok dengan yang didukung aplikasi (§3).
///
/// [pesanPengguna] sudah berbahasa Indonesia dan siap ditampilkan apa adanya —
/// "versi mayor 2 != 1" bukan kalimat yang bisa ditindaklanjuti siapa pun.
class GalatVersiJam implements Exception {
  const GalatVersiJam({
    required this.versiJam,
    required this.versiApp,
    required this.pesanPengguna,
  });

  final int versiJam;
  final int versiApp;
  final String pesanPengguna;

  @override
  String toString() =>
      'GalatVersiJam(jam: $versiJam, app: $versiApp): $pesanPengguna';
}

/// UUID, konstanta, dan panjang paket (§2.1, §5).
abstract final class ProtokolJam {
  /// Versi yang dipahami aplikasi ini. Mayor yang berbeda memutus koneksi;
  /// minor yang berbeda hanya berarti ada field yang belum dikenal (§3).
  ///
  /// Minor 2 menandai perubahan-perubahan yang dibuat **setelah** implementasi
  /// kedua sisi dimulai — riwayatnya di §12 dokumen protokol. Nilainya belum
  /// dipakai untuk mencabangkan perilaku apa pun, dan memang tidak perlu: yang
  /// dibelinya adalah kemampuan mengenali firmware lama nanti, saat ada firmware
  /// lama.
  static const int versiMayorDidukung = 1;
  static const int versiMinorDidukung = 2;

  static const String uuidLayanan = 'a5a70001-6b4c-4e2a-9d31-0f8c2e5a7b10';
  static const String uuidInfo = 'a5a70002-6b4c-4e2a-9d31-0f8c2e5a7b10';
  static const String uuidKontrol = 'a5a70003-6b4c-4e2a-9d31-0f8c2e5a7b10';
  static const String uuidPeristiwa = 'a5a70004-6b4c-4e2a-9d31-0f8c2e5a7b10';
  static const String uuidSampel = 'a5a70005-6b4c-4e2a-9d31-0f8c2e5a7b10';
  static const String uuidStatus = 'a5a70006-6b4c-4e2a-9d31-0f8c2e5a7b10';

  /// Baterai memakai Battery Service standar, bukan karakteristik kustom (§2.1).
  static const String uuidLayananBaterai =
      '0000180f-0000-1000-8000-00805f9b34fb';
  static const String uuidLevelBaterai = '00002a19-0000-1000-8000-00805f9b34fb';

  /// Panjang minimum tiap paket. Paket yang lebih panjang **diterima**: firmware
  /// dengan `versi_minor` lebih tinggi boleh menambah field di belakang, dan
  /// §3 mewajibkan aplikasi mengabaikannya, bukan menolak paketnya.
  static const int panjangInfo = 20;
  static const int panjangSampel = 31;
  static const int panjangPeristiwa = 26;
  static const int panjangStatus = 8;

  /// MTU yang diminta dan minimum yang masih bisa dipakai (§8). Sampel butuh 31
  /// byte utuh dalam satu notifikasi, plus 3 byte header ATT.
  static const int mtuDiminta = 185;
  static const int mtuMinimum = 35;

  /// Batas retry write (§7).
  static const Duration timeoutTulis = Duration(seconds: 5);
  static const int maksPercobaan = 3;

  /// Backoff reconnect (§8).
  static const Duration backoffAwal = Duration(seconds: 1);
  static const Duration backoffMaks = Duration(seconds: 60);

  /// Nama iklan jam selalu diawali ini (§2.2) — dipakai sebagai jaring kedua
  /// setelah service UUID.
  static const String awalanNama = 'AsaWatch';
}

/// Opcode karakteristik Kontrol (§5.1).
abstract final class Opcode {
  static const int anchorWaktu = 0x01;
  static const int armSesi = 0x02;
  static const int batalSesi = 0x03;
  static const int ukur = 0x04;
  static const int ukurSekarang = 0x05;
  static const int setKalibrasi = 0x06;
  static const int sinkron = 0x07;
  static const int ackEvent = 0x08;

  /// Menekan tombol "Selesai Makan" **milik jam** dari aplikasi (v1.2, §5.1).
  ///
  /// Bukan "aplikasi menetapkan t0": jam yang mencatat `t0` dari pencacahnya
  /// sendiri lalu mengirim `TOMBOL_SELESAI_MAKAN` seperti biasa, jadi t0 tetap
  /// berada di garis waktu jam dan seluruh model waktu (§4) tidak tersentuh.
  static const int mulaiSesi = 0x09;

  static String nama(int opcode) => switch (opcode) {
    anchorWaktu => 'ANCHOR_WAKTU',
    armSesi => 'ARM_SESI',
    batalSesi => 'BATAL_SESI',
    ukur => 'UKUR',
    ukurSekarang => 'UKUR_SEKARANG',
    setKalibrasi => 'SET_KALIBRASI',
    sinkron => 'SINKRON',
    ackEvent => 'ACK_EVENT',
    mulaiSesi => 'MULAI_SESI',
    _ => 'opcode 0x${opcode.toRadixString(16)}',
  };
}

/// Jenis peristiwa pada karakteristik Peristiwa (§5.4).
enum JenisPeristiwa {
  tombolSelesaiMakan(0x01),
  sesiKedaluwarsa(0x02),
  sesiDibatalkanJam(0x03),
  ukurGagal(0x04),
  ack(0x05),
  nak(0x06),
  bufferPenuh(0x07),
  boot(0x08);

  const JenisPeristiwa(this.kode);
  final int kode;

  static JenisPeristiwa dariKode(int kode) {
    for (final j in JenisPeristiwa.values) {
      if (j.kode == kode) return j;
    }
    throw GalatProtokol(
      'Jenis peristiwa 0x${kode.toRadixString(16)} tidak dikenal.',
    );
  }
}

/// Kode error pada payload `NAK` (§7).
///
/// [bolehRetry] ada di sini, bukan di pemanggilnya, karena tabel §7 adalah satu-
/// satunya sumber kebenarannya: "Bug versi. Catat, jangan retry" bukan pilihan
/// pemanggil.
enum KodeGalatJam {
  opcodeTidakDikenal(0x01, 'Perintah tidak dikenali jam.', bolehRetry: false),
  payloadTidakValid(0x02, 'Isi perintah tidak valid.', bolehRetry: false),
  belumDiarm(0x03, 'Jam belum disiapkan untuk sesi ini.', bolehRetry: false),
  sesiTidakDikenal(0x04, 'Sesi sudah tidak dikenal jam.', bolehRetry: false),
  sedangMengukur(0x05, 'Jam sedang mengukur.', bolehRetry: true),
  bateraiRendah(
    0x06,
    'Baterai jam terlalu rendah untuk mengukur.',
    bolehRetry: false,
  ),
  sensorGagal(0x07, 'Sensor jam gagal membaca.', bolehRetry: false),
  kalibrasiBelumAda(
    0x08,
    'Jam belum dikalibrasi, tekanan darah dikirim tanpa koreksi.',
    bolehRetry: false,
  ),
  bootIdTidakCocok(0x09, 'Jam sempat menyala ulang.', bolehRetry: true);

  const KodeGalatJam(this.kode, this.pesan, {required this.bolehRetry});

  final int kode;
  final String pesan;

  /// Apakah perintah yang gagal ini layak diulang. `0x05` diulang setelah jeda,
  /// `0x09` setelah handshake dan anchor diulang lebih dulu (§7).
  final bool bolehRetry;

  /// Jeda sebelum percobaan berikutnya, hanya bermakna bila [bolehRetry].
  Duration get jedaRetry => this == sedangMengukur
      ? const Duration(seconds: 5)
      : const Duration(milliseconds: 300);

  static KodeGalatJam? dariKode(int kode) {
    for (final g in KodeGalatJam.values) {
      if (g.kode == kode) return g;
    }
    return null; // kode baru dari firmware yang lebih muda
  }
}

/// Status sesi menurut mesin status firmware (§9).
enum StatusSesiJam { idle, armed, running }

/// Isi karakteristik Info & Handshake (§3).
class InfoJam {
  const InfoJam({
    required this.versiMayor,
    required this.versiMinor,
    required this.serial,
    required this.firmwareBuild,
    required this.kapasitasBuffer,
    required this.kemampuan,
    required this.bootId,
    required this.uptimeS,
    required this.punyaAnchor,
  });

  final int versiMayor;
  final int versiMinor;

  /// Enam byte identitas yang stabil lintas platform — berbeda dari id
  /// perangkat milik OS, yang MAC di Android dan UUID di iOS (§2.2).
  final String serial;

  final int firmwareBuild;
  final int kapasitasBuffer;
  final KemampuanJam kemampuan;
  final int bootId;
  final int uptimeS;

  /// Boot ini sudah pernah menerima `ANCHOR_WAKTU`. Bila false, entri lamanya
  /// akan datang dengan flag `waktu_tidak_pasti` (§4.3).
  final bool punyaAnchor;

  /// Melempar [GalatVersiJam] bila mayor tidak cocok (§3).
  ///
  /// Perbedaan minor sengaja lolos tanpa peringatan: itulah gunanya minor.
  void periksaVersi() {
    if (versiMayor == ProtokolJam.versiMayorDidukung) return;
    throw GalatVersiJam(
      versiJam: versiMayor,
      versiApp: ProtokolJam.versiMayorDidukung,
      pesanPengguna: versiMayor > ProtokolJam.versiMayorDidukung
          ? 'Jam perlu aplikasi versi lebih baru.'
          : 'Firmware jam perlu diperbarui.',
    );
  }
}

/// Bitfield kemampuan (§3).
///
/// Bukan hiasan: metrik yang bitnya 0 harus **disembunyikan** dari UI, bukan
/// ditampilkan sebagai "—" seolah pengukurannya gagal.
class KemampuanJam {
  const KemampuanJam(this.bit);
  final int bit;

  bool get gulaDarah => bit & 0x01 != 0;
  bool get tekananDarah => bit & 0x02 != 0;
  bool get spo2 => bit & 0x04 != 0;
  bool get ota => bit & 0x08 != 0;
}

/// Satu entri ring buffer, apa pun jenisnya (§6).
///
/// [seq] dan [bootId] hidup di kelas induk karena keduanya berlaku untuk sampel
/// maupun peristiwa: yang pertama adalah kunci ack, yang kedua kunci apakah dua
/// `uptime_s` boleh dibandingkan sama sekali.
sealed class EntriJam {
  const EntriJam({
    required this.seq,
    required this.bootId,
    required this.uptimeS,
    required this.dariBuffer,
    required this.waktuTidakPasti,
  });

  final int seq;
  final int bootId;
  final int uptimeS;

  /// Entri kiriman ulang dari buffer, bukan realtime (§6 aturan 4).
  final bool dariBuffer;

  /// Boot asal entri ini tidak pernah punya anchor, jadi waktunya tidak akan
  /// pernah bisa diketahui (§4.3).
  final bool waktuTidakPasti;
}

/// Sampel pengukuran (§5.2).
class EntriSampel extends EntriJam {
  const EntriSampel({
    required super.seq,
    required this.sesiId,
    required this.index,
    required super.bootId,
    required super.uptimeS,
    required super.dariBuffer,
    required super.waktuTidakPasti,
    this.gulaDarah,
    this.detakJantung,
    this.sistolik,
    this.diastolik,
    this.spo2,
  });

  final String sesiId;
  final int index;

  // Sentinel 0 dari protokol sudah menjadi null di sini — §5.2 melarang membawa
  // nol sampai ke UI, dan lapisan ini adalah tempat terakhir yang tahu bahwa
  // nol itu artinya "gagal diukur", bukan "nol".
  final int? gulaDarah;
  final int? detakJantung;
  final int? sistolik;
  final int? diastolik;
  final int? spo2;
}

/// Peristiwa (§5.4).
class EntriPeristiwa extends EntriJam {
  const EntriPeristiwa({
    required super.seq,
    required this.jenis,
    required this.sesiId,
    required super.bootId,
    required super.uptimeS,
    required super.dariBuffer,
    required super.waktuTidakPasti,
    required this.payload,
  });

  final JenisPeristiwa jenis;

  /// null bila paketnya berisi 16 byte nol — §5.4 memakai itu untuk "tidak
  /// relevan", dan meneruskannya sebagai string nol akan terlihat seperti sesi
  /// sungguhan yang tidak dikenal.
  final String? sesiId;

  final int payload;

  /// Opcode yang di-ack, hanya bermakna untuk [JenisPeristiwa.ack].
  int get opcodeDiack => payload;

  /// Kode error, hanya bermakna untuk [JenisPeristiwa.nak]. null berarti
  /// firmware mengirim kode yang belum dikenal aplikasi ini.
  KodeGalatJam? get kodeGalat => KodeGalatJam.dariKode(payload);
}

/// Isi karakteristik Status (§5.5).
class StatusJam {
  const StatusJam({
    required this.statusSesi,
    required this.sampelTertunda,
    required this.baterai,
    required this.sedangMengukur,
    required this.kalibrasiTersimpan,
    required this.bateraiKritis,
    required this.punyaAnchor,
    required this.uptimeS,
  });

  final StatusSesiJam statusSesi;
  final int sampelTertunda;
  final int baterai;
  final bool sedangMengukur;
  final bool kalibrasiTersimpan;
  final bool bateraiKritis;
  final bool punyaAnchor;
  final int uptimeS;
}

// --- Pembacaan ------------------------------------------------------------

/// Membaca 20 byte handshake (§3).
InfoJam bacaInfo(List<int> data) {
  final b = _periksa(data, ProtokolJam.panjangInfo, 'Info');
  return InfoJam(
    versiMayor: b.getUint8(0),
    versiMinor: b.getUint8(1),
    serial: _hex(data.sublist(2, 8)),
    firmwareBuild: b.getUint16(8, Endian.little),
    kapasitasBuffer: b.getUint8(10),
    kemampuan: KemampuanJam(b.getUint8(11)),
    bootId: b.getUint16(12, Endian.little),
    uptimeS: b.getUint32(14, Endian.little),
    punyaAnchor: b.getUint8(18) & 0x01 != 0,
  );
}

/// Membaca 31 byte sampel (§5.2).
EntriSampel bacaSampel(List<int> data) {
  final b = _periksa(data, ProtokolJam.panjangSampel, 'Sampel');
  final flag = b.getUint8(18);
  final index = b.getUint8(17);
  if (index > 3) {
    // Empat titik ukur adalah janji model (`labelTitikSampel`), dan seluruh UI
    // mengindeks `sampel[index]` langsung. Index kelima akan menjatuhkan
    // aplikasi jauh dari sini, dengan pesan yang tidak menyebut BLE sama sekali.
    throw GalatProtokol('Index sampel $index di luar 0..3.');
  }

  return EntriSampel(
    seq: b.getUint8(0),
    sesiId: binerKeUuid(data.sublist(1, 17)),
    index: index,
    dariBuffer: flag & 0x01 != 0,
    waktuTidakPasti: flag & 0x02 != 0,
    bootId: b.getUint16(19, Endian.little),
    uptimeS: b.getUint32(21, Endian.little),
    gulaDarah: _nolJadiNull(b.getUint16(25, Endian.little)),
    detakJantung: _nolJadiNull(b.getUint8(27)),
    sistolik: _nolJadiNull(b.getUint8(28)),
    diastolik: _nolJadiNull(b.getUint8(29)),
    spo2: _nolJadiNull(b.getUint8(30)),
  );
}

/// Membaca 26 byte peristiwa (§5.4).
EntriPeristiwa bacaPeristiwa(List<int> data) {
  final b = _periksa(data, ProtokolJam.panjangPeristiwa, 'Peristiwa');
  final flag = b.getUint8(24);
  final sesiId = data.sublist(2, 18);

  return EntriPeristiwa(
    seq: b.getUint8(0),
    jenis: JenisPeristiwa.dariKode(b.getUint8(1)),
    sesiId: sesiId.every((x) => x == 0) ? null : binerKeUuid(sesiId),
    bootId: b.getUint16(18, Endian.little),
    uptimeS: b.getUint32(20, Endian.little),
    dariBuffer: flag & 0x01 != 0,
    waktuTidakPasti: flag & 0x02 != 0,
    payload: b.getUint8(25),
  );
}

/// Membaca 8 byte status (§5.5).
StatusJam bacaStatus(List<int> data) {
  final b = _periksa(data, ProtokolJam.panjangStatus, 'Status');
  final kode = b.getUint8(0);
  if (kode > 2) {
    throw GalatProtokol('Status sesi jam $kode tidak dikenal.');
  }
  final flag = b.getUint8(3);

  return StatusJam(
    statusSesi: StatusSesiJam.values[kode],
    sampelTertunda: b.getUint8(1),
    baterai: b.getUint8(2),
    sedangMengukur: flag & 0x01 != 0,
    kalibrasiTersimpan: flag & 0x02 != 0,
    bateraiKritis: flag & 0x04 != 0,
    punyaAnchor: flag & 0x08 != 0,
    uptimeS: b.getUint32(4, Endian.little),
  );
}

// --- Penulisan ------------------------------------------------------------

/// `ANCHOR_WAKTU` (§5.1). [bootId] ikut dikirim supaya jam bisa mem-NAK bila ia
/// sempat menyala ulang antara handshake dan write — tanpa itu anchor bisa
/// terpasang pada garis waktu yang salah (§4.2).
Uint8List tulisAnchorWaktu({required DateTime epoch, required int bootId}) {
  final data = Uint8List(7);
  final b = ByteData.view(data.buffer);
  b.setUint8(0, Opcode.anchorWaktu);
  b.setUint32(1, epoch.toUtc().millisecondsSinceEpoch ~/ 1000, Endian.little);
  b.setUint16(5, bootId, Endian.little);
  return data;
}

Uint8List tulisArmSesi(String sesiId) =>
    _opcodeDenganSesi(Opcode.armSesi, sesiId);

/// `MULAI_SESI` (§5.1) — tombol "Selesai Makan" ditekan dari aplikasi.
///
/// Payload-nya `sesiId` saja, **tanpa waktu**, dan justru ketiadaan waktu itulah
/// isi perintah ini: jam yang membaca pencacahnya sendiri saat perintah tiba,
/// lalu mengirim `TOMBOL_SELESAI_MAKAN` persis seperti kalau tombol fisiknya
/// yang ditekan. Aplikasi tidak pernah mengarang `t0` — ia hanya meminta jam
/// menekan tombolnya sendiri.
///
/// Mengirim epoch di sini akan membatalkan seluruh §4: jam tidak punya RTC, dan
/// satu-satunya cara `t0` bisa dibandingkan dengan `uptime_s` sampelnya adalah
/// bila keduanya berasal dari pencacah yang sama.
Uint8List tulisMulaiSesi(String sesiId) =>
    _opcodeDenganSesi(Opcode.mulaiSesi, sesiId);

Uint8List tulisBatalSesi(String sesiId) =>
    _opcodeDenganSesi(Opcode.batalSesi, sesiId);

/// `UKUR` (§5.1). Index 0 adalah baseline, diminta saat shutter kamera ditekan —
/// sebelum `t0` ada, dan karena itu membawa `sesiId` yang sama dengan
/// `ARM_SESI` yang menyusul.
Uint8List tulisUkur(String sesiId, int index) {
  if (index < 0 || index > 3) {
    throw GalatProtokol('Index sampel $index di luar 0..3.');
  }
  final data = Uint8List(18);
  data[0] = Opcode.ukur;
  data.setRange(1, 17, uuidKeBiner(sesiId));
  data[17] = index;
  return data;
}

Uint8List tulisUkurSekarang() => Uint8List.fromList([Opcode.ukurSekarang]);

/// `SET_KALIBRASI` (§5.1) — yang dikirim adalah **offset**, bukan nilai
/// referensi tensimeternya. Firmware hanya menambahkan; ia tidak perlu tahu
/// tekanan darah pengguna yang sebenarnya.
Uint8List tulisSetKalibrasi({
  required int offsetSistolik,
  required int offsetDiastolik,
}) {
  final data = Uint8List(5);
  final b = ByteData.view(data.buffer);
  b.setUint8(0, Opcode.setKalibrasi);
  b.setInt16(1, _batasInt16(offsetSistolik), Endian.little);
  b.setInt16(3, _batasInt16(offsetDiastolik), Endian.little);
  return data;
}

/// `SINKRON` (§5.1): kirim ulang mulai dari seq berikutnya setelah [seqTerakhir].
/// 0 berarti "belum pernah menerima apa pun" — seq 0 tidak pernah dipakai (§6).
Uint8List tulisSinkron(int seqTerakhir) =>
    Uint8List.fromList([Opcode.sinkron, _batasUint8(seqTerakhir)]);

/// `ACK_EVENT` (§5.1). Hanya boleh dikirim **setelah** entrinya tersimpan
/// permanen di basis data lokal (§6) — jam menghapus entrinya begitu ack
/// diterima, jadi ack yang mendahului penulisan adalah data yang hilang bila
/// aplikasi mati di antara keduanya.
Uint8List tulisAckEvent(int seq) =>
    Uint8List.fromList([Opcode.ackEvent, _batasUint8(seq)]);

// --- Id sesi --------------------------------------------------------------

/// Id sesi baru dalam bentuk UUID v4 kanonik.
///
/// Protokol membawa `sesiId` sebagai 16 byte biner (§5.1), jadi id aplikasi
/// harus berupa sesuatu yang bisa bolak-balik utuh ke 16 byte. Id lama
/// (`sesi-<mikrodetik>`) tidak bisa, dan itu tidak apa-apa: ia hanya ada di
/// riwayat yang sudah berakhir dan tidak pernah dikirim ke jam lagi.
String buatIdSesi([Random? acak]) {
  final r = acak ?? Random.secure();
  final b = Uint8List.fromList([for (var i = 0; i < 16; i++) r.nextInt(256)]);
  b[6] = (b[6] & 0x0f) | 0x40; // versi 4
  b[8] = (b[8] & 0x3f) | 0x80; // varian RFC 4122
  return binerKeUuid(b);
}

/// `sesiId` yang seluruh 16 byte-nya nol: **bukan sesi**, melainkan "tidak
/// relevan" (§5.4) — dan pada paket Sampel, jawaban `UKUR_SEKARANG` yang memang
/// terjadi di luar sesi mana pun (§5.1).
///
/// Dibuat konstanta karena ia harus diperlakukan berbeda di dua tempat: entri
/// seperti ini tidak akan pernah ikut tersimpan di dalam sebuah sesi, jadi
/// menunggunya diproses berarti memutarnya ulang setiap kali aplikasi start,
/// selamanya.
const String uuidSesiKosong = '00000000-0000-0000-0000-000000000000';

/// Apakah [sesiId] menunjuk sesi sungguhan, bukan penanda "tidak relevan".
bool sesiIdNyata(String? sesiId) => sesiId != null && sesiId != uuidSesiKosong;

/// UUID kanonik → 16 byte, urutan teks (big-endian), sesuai RFC 4122.
Uint8List uuidKeBiner(String uuid) {
  final hex = uuid.replaceAll('-', '');
  if (hex.length != 32) {
    throw GalatProtokol('Id sesi "$uuid" bukan UUID 16 byte.');
  }
  final data = Uint8List(16);
  for (var i = 0; i < 16; i++) {
    final nilai = int.tryParse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    if (nilai == null) {
      throw GalatProtokol('Id sesi "$uuid" bukan heksadesimal.');
    }
    data[i] = nilai;
  }
  return data;
}

/// 16 byte → UUID kanonik berhuruf kecil.
String binerKeUuid(List<int> data) {
  if (data.length != 16) {
    throw GalatProtokol('Id sesi butuh 16 byte, dapat ${data.length}.');
  }
  final h = _hex(data);
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}'
      '-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Apakah [id] bisa dikirim ke jam sama sekali.
///
/// Sesi lama dari sebelum Tahap B memakai id `sesi-<mikrodetik>` yang tidak muat
/// di 16 byte. Semuanya sudah berakhir, jadi satu-satunya yang perlu dilakukan
/// adalah tidak mencoba mengirimkannya.
bool idSesiValid(String id) {
  try {
    uuidKeBiner(id);
    return true;
  } on GalatProtokol {
    return false;
  }
}

// --- Iklan ----------------------------------------------------------------

/// Versi mayor dari Manufacturer Specific Data di paket iklan (§2.2), agar
/// firmware yang terlalu tua bisa ditandai **sebelum** disambung.
///
/// null berarti iklannya tidak memuatnya — perangkat asing, atau AsaWatch yang
/// firmware-nya belum menuruti §2.2. Keduanya tidak boleh ditolak di sini;
/// handshake yang memutuskan.
int? versiMayorDariIklan(Map<int, List<int>> dataPabrikan) {
  for (final isi in dataPabrikan.values) {
    if (isi.isNotEmpty) return isi.first;
  }
  return null;
}

// --- Bantuan --------------------------------------------------------------

ByteData _periksa(List<int> data, int minimal, String nama) {
  if (data.length < minimal) {
    throw GalatProtokol(
      'Paket $nama butuh minimal $minimal byte, dapat ${data.length}.',
    );
  }
  // Byte berlebih dibiarkan: firmware ber-`versi_minor` lebih tinggi boleh
  // menambah field di belakang, dan §3 mewajibkan aplikasi mengabaikannya.
  final salinan = Uint8List.fromList(data);
  return ByteData.view(salinan.buffer);
}

Uint8List _opcodeDenganSesi(int opcode, String sesiId) {
  final data = Uint8List(17);
  data[0] = opcode;
  data.setRange(1, 17, uuidKeBiner(sesiId));
  return data;
}

/// Sentinel `0` = metrik gagal diukur (§5.2). Aman karena tidak ada nilai
/// fisiologis nol yang sah untuk kelima metriknya.
int? _nolJadiNull(int nilai) => nilai == 0 ? null : nilai;

int _batasInt16(int n) => n.clamp(-32768, 32767);

int _batasUint8(int n) => n.clamp(0, 255);

String _hex(List<int> data) =>
    [for (final b in data) b.toRadixString(16).padLeft(2, '0')].join();

/// Ringkasan satu paket untuk log diagnostik (§9.2 rencana produksi).
///
/// Kegagalan BLE hampir mustahil didiagnosis dari laporan pengguna saja, dan
/// byte mentah adalah satu-satunya bukti yang tersisa setelah kejadiannya lewat.
String ringkasPaket(String nama, List<int> data) =>
    '$nama[${data.length}] ${base64Encode(data)}';
