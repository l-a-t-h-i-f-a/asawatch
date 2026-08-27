/// Riwayat sesi di sisi server — docs/rancangan-api-laravel.md §5.2.
///
/// Satu arah dan hanya itu: aplikasi mengunggah, tidak pernah mengunduh.
/// Sinkronisasi dua arah (§7) menuntut aturan konflik, penghapusan yang
/// menular, dan kursor waktu — dan tidak satu pun dari itu dibutuhkan sebelum
/// ada perangkat kedua. Yang dibutuhkan sekarang cuma satu: apa yang terjadi di
/// ponsel bisa dilihat di server.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io' show File, FileSystemException, SocketException;

import 'package:flutter/foundation.dart' show debugPrint;
import 'package:http/http.dart' as http;

import '../models/sesi_makan.dart';
import 'auth_service.dart';

/// Satu sesi sebagaimana server menyerahkannya.
///
/// [urlFoto] sengaja **tidak** menjadi field `SesiMakan`: ia bukan milik sesi
/// melainkan milik jawaban ini — URL bertanda tangan yang kedaluwarsa dalam satu
/// jam (§5.2). Disimpan ke basis data ia akan menjadi jalur mati dalam semalam,
/// dan `FotoMakanan` yang memperlakukannya sebagai jalur berkas akan
/// menjatuhkannya ke penampung cadangan tanpa pernah mengatakan kenapa. Yang
/// disimpan adalah berkas hasil unduhannya, bukan alamatnya.
class SesiUnduhan {
  const SesiUnduhan({required this.sesi, this.urlFoto});

  final SesiMakan sesi;

  /// null bila server memang tidak punya fotonya — bukan bila unduhannya gagal.
  final String? urlFoto;
}

abstract class SesiServerService {
  /// Seluruh sesi milik pemegang [token] di server (§5.2 `GET /sesi`).
  ///
  /// Mengembalikan null bila gagal — bukan daftar kosong. Bedanya menentukan:
  /// daftar kosong berarti "akun ini memang belum punya sesi", null berarti
  /// "tidak tahu", dan yang kedua tidak boleh sampai membuat apa pun terhapus.
  Future<List<SesiUnduhan>?> ambilSemua(String token);

  /// Mengunduh foto dari [url] bertanda tangan milik `GET /sesi`, menyimpannya
  /// ke [tujuan]. `true` bila berkasnya benar-benar tertulis.
  ///
  /// Terpisah dari [ambilSemua] karena biayanya sama sekali berbeda: satu
  /// jawaban JSON berisi dua puluh sesi jauh lebih murah daripada satu foto,
  /// dan unduhan yang putus tidak boleh menyeret riwayatnya ikut gagal.
  ///
  /// **[token] tetap diperlukan meskipun URL-nya bertanda tangan.** Rute
  /// `GET /api/v1/foto/{sesi}` memakai `signed` **di dalam** grup
  /// `auth:sanctum`, jadi tanda tangan hanya membuktikan alamatnya tidak
  /// dikarang — bukan siapa yang memintanya (§2 aturan 5: tidak pernah ada URL
  /// publik ke foto makanan). Tanpa header ini jawabannya 401, [unduhFoto]
  /// mengembalikan false, dan sesinya sampai dengan `fotoPath` kosong: angka
  /// gizi lengkap, piringnya hilang — persis yang terlihat sesudah ganti akun.
  Future<bool> unduhFoto(String token, String url, String tujuan);

  /// Mengunggah satu sesi. `true` bila server menerimanya.
  ///
  /// **Idempoten**, dan itulah yang membuat seluruh rancangan ini sederhana:
  /// `id` sesi adalah UUID buatan aplikasi dan endpoint-nya upsert (§2 aturan
  /// 2), jadi mengirim sesi yang sama dua kali tidak menghasilkan dua baris.
  /// Karena itu tidak ada kolom "sudah terkirim" di basis data lokal —
  /// pengiriman ulang selalu aman, dan keadaan yang tidak perlu disimpan adalah
  /// keadaan yang tidak bisa salah.
  Future<bool> kirim(String token, SesiMakan sesi);

  /// Mengunggah foto makanan sesi (§5.2 `POST /sesi/{id}/foto`).
  ///
  /// Dipisah dari [kirim] oleh kontraknya sendiri, dan alasannya praktis: foto
  /// jauh lebih besar daripada seluruh data sesi digabung, jadi unggahan yang
  /// putus di tengah jaringan seluler bisa diulang tanpa mengirim ulang
  /// sesinya.
  Future<bool> kirimFoto(String token, String sesiId, String jalurFoto);

  /// Meminta analisis gizi dari foto yang sudah diunggah (§6), lalu menunggu
  /// hasilnya. Mengembalikan null bila gagal atau tidak selesai tepat waktu.
  ///
  /// Sengaja **menyembunyikan polling-nya**: §6 memilih alur asinkron
  /// (202 + `id_pekerjaan`, lalu status ditanyakan berkala), tetapi bagi
  /// pemanggil di aplikasi itu tetap satu permintaan yang menghasilkan angka
  /// gizi — persis seperti `NutrisiService.analisis`. Kalau suatu saat server
  /// berpindah ke jawaban langsung, yang berubah hanya berkas ini.
  Future<HasilDeteksi?> mintaAnalisis(String token, String sesiId);
}

class SesiHttpService implements SesiServerService {
  SesiHttpService({
    required this.basisUrl,
    this.onTokenDitolak,
    http.Client? klien,
  }) : _klien = klien ?? http.Client(),
       _klienMilikSendiri = klien == null;

  final String basisUrl;

  /// Dipanggil saat server menjawab 401. Lihat `PenjagaSesi` — dan perhatikan
  /// bahwa seluruh riwayat dikirim ulang setiap kali aplikasi dibuka, jadi satu
  /// token yang basi memicu ini berkali-kali sekaligus; penjaganya yang
  /// menahan agar keluarnya tetap sekali.
  final Future<void> Function()? onTokenDitolak;
  final http.Client _klien;
  final bool _klienMilikSendiri;

  @override
  Future<List<SesiUnduhan>?> ambilSemua(String token) async {
    try {
      final semua = <SesiUnduhan>[];
      String? kursor;

      // **Halamannya diikuti.** §5.2 memakai cursor pagination dengan
      // `per_page` bawaan 50, jadi membaca `data` sekali dan berhenti akan
      // memotong riwayat panjang tanpa satu pun tanda — sesi yang hilang itu
      // ada di server, tampil di web, dan tidak pernah sampai ke ponsel.
      // Batas putaran ada supaya `next_cursor` yang tidak pernah null (server
      // yang keliru, atau kursor yang berulang) tidak menggantung aplikasi
      // selamanya di layar masuk.
      for (var halaman = 0; halaman < 40; halaman++) {
        final alamat = Uri.parse(
          '$basisUrl/api/v1/sesi',
        ).replace(queryParameters: kursor == null ? null : {'cursor': kursor});

        final jawaban = await _klien
            .get(
              alamat,
              headers: {
                'accept': 'application/json',
                'authorization': 'Bearer $token',
              },
            )
            .timeout(AuthService.batasWaktu);

        if (jawaban.statusCode == 401) {
          await onTokenDitolak?.call();
          return null;
        }
        if (jawaban.statusCode != 200) return null;

        final isi = jsonDecode(jawaban.body);
        if (isi is! Map<String, dynamic>) return null;
        final data = isi['data'];
        if (data is! List) return null;

        for (final baris in data) {
          if (baris is! Map<String, dynamic>) continue;
          final sesi = sesiDariJson(baris);
          if (sesi == null) continue;
          semua.add(SesiUnduhan(sesi: sesi, urlFoto: urlFotoDariJson(baris)));
        }

        final meta = isi['meta'];
        final berikut = meta is Map ? meta['next_cursor'] : null;
        // Kursor yang tidak berubah adalah putaran tak berujung, bukan halaman
        // berikutnya.
        if (berikut is! String || berikut.isEmpty || berikut == kursor) break;
        kursor = berikut;
      }

      return semua;
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } on http.ClientException {
      return null;
    } on FormatException {
      return null;
    }
  }

  @override
  Future<bool> kirim(String token, SesiMakan sesi) async {
    try {
      final jawaban = await _klien
          .put(
            Uri.parse('$basisUrl/api/v1/sesi/${sesi.id}'),
            headers: {
              'accept': 'application/json',
              'content-type': 'application/json; charset=utf-8',
              'authorization': 'Bearer $token',
            },
            body: jsonEncode(badanSesi(sesi)),
          )
          .timeout(AuthService.batasWaktu);
      if (jawaban.statusCode == 401) {
        await onTokenDitolak?.call();
        return false;
      }
      if (jawaban.statusCode >= 200 && jawaban.statusCode < 300) return true;

      // Ditolak, dan **kenapa**-nya dicatat. Aturannya sendiri tidak berubah:
      // unggahan yang gagal tidak dimunculkan ke layar, karena datanya tetap di
      // ponsel dan pembukaan berikutnya mengirimnya lagi (lihat
      // `SesiMakanController._kirimKeServer`). Yang berubah adalah bahwa
      // penolakan berhenti tidak berjejak sama sekali: `409 konflik_versi` yang
      // berulang 43 kali pernah hanya terlihat di log server, dan sesi yang
      // menggantung di keadaan draft di sana tampak lengkap di ponsel.
      debugPrint(
        'PUT /sesi/${sesi.id} ditolak ${jawaban.statusCode}: '
        '${_ringkas(jawaban.body)}',
      );
      return false;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    }
  }

  @override
  Future<bool> kirimFoto(String token, String sesiId, String jalurFoto) async {
    final berkas = File(jalurFoto);
    // Foto yang sudah tidak ada di penyimpanan bukan kegagalan jaringan, dan
    // mencobanya lagi tidak akan menolong.
    if (!berkas.existsSync()) return false;

    try {
      final permintaan =
          http.MultipartRequest(
              'POST',
              Uri.parse('$basisUrl/api/v1/sesi/$sesiId/foto'),
            )
            ..headers.addAll({
              'accept': 'application/json',
              'authorization': 'Bearer $token',
            })
            ..files.add(await http.MultipartFile.fromPath('foto', jalurFoto));

      final jawaban = await _klien.send(permintaan).timeout(batasUnggahFoto);

      if (jawaban.statusCode == 401) {
        await onTokenDitolak?.call();
        return false;
      }
      return jawaban.statusCode >= 200 && jawaban.statusCode < 300;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    } on FileSystemException {
      return false;
    }
  }

  /// Lebih longgar daripada permintaan biasa: yang dikirim beberapa ratus
  /// kilobyte foto, bukan beberapa baris JSON.
  static const Duration batasUnggahFoto = Duration(seconds: 60);

  @override
  Future<HasilDeteksi?> mintaAnalisis(String token, String sesiId) async {
    final alamat = Uri.parse('$basisUrl/api/v1/sesi/$sesiId/analisis');
    final kepala = {
      'accept': 'application/json',
      'authorization': 'Bearer $token',
    };

    try {
      final mulai = await _klien
          .post(alamat, headers: kepala)
          .timeout(AuthService.batasWaktu);
      if (mulai.statusCode == 401) {
        await onTokenDitolak?.call();
        return null;
      }
      // 202 antre (§6) maupun 200 selesai sama-sama sah; yang menentukan
      // hasilnya adalah pembacaan status di bawah.
      if (mulai.statusCode < 200 || mulai.statusCode >= 300) return null;

      // Backoff 2→4→8, berhenti di sekitar satu menit (§6). Yang menunggu di
      // sini bukan pengguna: analisis berjalan di latar belakang dan layar sesi
      // tetap bisa dipakai.
      for (final jeda in _jedaPolling) {
        await Future<void>.delayed(jeda);
        final jawaban = await _klien
            .get(alamat, headers: kepala)
            .timeout(AuthService.batasWaktu);
        if (jawaban.statusCode != 200) return null;

        final isi = jsonDecode(jawaban.body);
        if (isi is! Map<String, dynamic>) return null;
        switch (isi['status']) {
          case 'selesai':
            return _hasilDariJson(isi['hasil']);
          case 'gagal':
            // Gagal itu status, bukan HTTP 500 (§6). Tidak ada yang bisa
            // dilakukan aplikasi selain berhenti menunggu.
            return null;
        }
      }
      return null; // masih antre setelah semua jeda habis
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } on http.ClientException {
      return null;
    } on FormatException {
      return null;
    }
  }

  static const List<Duration> _jedaPolling = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 8),
    Duration(seconds: 8),
    Duration(seconds: 8),
    Duration(seconds: 8),
    Duration(seconds: 8),
  ];

  @override
  Future<bool> unduhFoto(String token, String url, String tujuan) async {
    try {
      final jawaban = await _klien
          .get(
            Uri.parse(url),
            headers: {'authorization': 'Bearer $token'},
          )
          .timeout(batasUnggahFoto);
      if (jawaban.statusCode != 200) return false;
      if (jawaban.bodyBytes.isEmpty) return false;

      final berkas = File(tujuan);
      await berkas.parent.create(recursive: true);
      await berkas.writeAsBytes(jawaban.bodyBytes, flush: true);
      return true;
    } on TimeoutException {
      return false;
    } on SocketException {
      return false;
    } on http.ClientException {
      return false;
    } on FileSystemException {
      return false;
    }
  }

  void dispose() {
    if (_klienMilikSendiri) _klien.close();
  }

  /// Badan jawaban secukupnya untuk mengenali kode galatnya, bukan seluruhnya:
  /// yang dicari selalu ada di awal (`{"galat":{"kode":…`), dan log yang
  /// panjang justru menenggelamkan baris berikutnya.
  static String _ringkas(String badan) =>
      badan.length <= 200 ? badan : '${badan.substring(0, 200)}…';
}

/// Bentuk JSON satu sesi (§5.2).
///
/// Dipisah dari kelasnya supaya bisa diuji tanpa soket sama sekali — ini bagian
/// yang paling gampang salah diam-diam, dan yang paling mahal kalau salah:
/// server menyimpan apa yang dikirim, dan sampel yang sudah `terisi` di sana
/// bersifat final (§2 aturan 4).
Map<String, dynamic> badanSesi(SesiMakan sesi) => {
  'waktu_foto': _waktu(sesi.waktuFoto),
  't0': sesi.t0 == null ? null : _waktu(sesi.t0!),
  'status': statusKeKawat(sesi.status),
  'waktu_tidak_pasti': sesi.waktuTidakPasti,
  // Sesi uji **ikut dikirim**, bukan disembunyikan. Jalur unggah yang hanya
  // bisa dilatih oleh sesi sungguhan berarti menunggu dua setengah jam untuk
  // setiap percobaan — jalur seperti itu tidak pernah teruji. Yang menjaga
  // angkanya tidak mencemari apa pun adalah tandanya sendiri: server menyimpan
  // dan menampilkannya, tetapi tidak pernah menghitungnya.
  'sesi_uji': sesi.sesiUji,
  'sampel': [
    for (final s in sesi.sampel)
      {
        'index': s.index,
        'detik_relatif_t0': s.detikRelatifT0,
        'status': s.status.name,
        'dari_buffer': s.dariBuffer,
        'gula_darah': s.gulaDarah,
        'detak_jantung': s.detakJantung,
        'sistolik': s.sistolik,
        'diastolik': s.diastolik,
        'spo2': s.spo2,
      },
  ],
  // Angka gizinya ikut naik: tanpa ini, sesi yang diunduh di perangkat lain
  // kehilangan seluruh kartu makanannya — dan justru itulah satu-satunya bagian
  // sesi yang tidak bisa dihitung ulang dari sampel.
  'hasil': sesi.hasil == null ? null : _hasilKeJson(sesi.hasil!),
  // Waktu perubahan terakhir, **bukan** waktu pengiriman. Mengirim
  // `DateTime.now()` di sini akan membuat setiap kiriman ulang mengaku lebih
  // baru walau isinya sama persis — dan aturan "yang terbaru menang" (§7.1)
  // lalu menimpa suntingan dari perangkat lain dengan salinan lama.
  // Sesi lama yang belum punya stempel jatuh ke waktu fotonya: yang pasti tidak
  // lebih baru daripada kenyataan.
  'diperbarui_pada': _waktu(sesi.diperbaruiPada ?? sesi.waktuFoto),
};

Map<String, dynamic> _hasilKeJson(HasilDeteksi hasil) => {
  'indeks_glikemik_perkiraan': hasil.indeksGlikemikPerkiraan,
  'keyakinan': hasil.keyakinan,
  'dikoreksi_user': hasil.dikoreksiUser,
  'zat_tidak_lengkap': [
    for (final z in ZatGizi.values)
      if (hasil.zatTidakLengkap.contains(z)) z.kunci,
  ],
  'total': _nutrisiKeJson(hasil.total),
  'makanan': [
    for (final (i, m) in hasil.makanan.indexed)
      {
        // §8: urutan dipertahankan — judul kartu di aplikasi dirangkai dari
        // nama makanan sesuai urutan ini.
        'urutan': i,
        'nama': m.nama,
        'porsi': m.porsi,
        'estimasi_gram': m.estimasiGram,
        'nutrisi': _nutrisiKeJson(m.nutrisi),
      },
  ],
};

/// null dikirim sebagai null, bukan sebagai 0 — di kedua arah artinya sama:
/// "tidak diketahui".
Map<String, dynamic> _nutrisiKeJson(Nutrisi n) => {
  for (final z in ZatGizi.values) z.kunci: n[z],
};

/// Satu sesi dari JSON §5.2, atau null bila bentuknya tidak bisa dipercaya.
///
/// Null, bukan lemparan: satu baris rusak di antara lima puluh tidak boleh
/// menggagalkan seluruh unduhan.
SesiMakan? sesiDariJson(Map<String, dynamic> data) {
  final id = data['id'];
  final waktuFoto = DateTime.tryParse(data['waktu_foto'] as String? ?? '');
  if (id is! String || id.isEmpty || waktuFoto == null) return null;

  final status = statusDariKawat(data['status']);
  if (status == null) return null;

  final sampel = <Sampel>[];
  final daftar = data['sampel'];
  if (daftar is List) {
    for (final s in daftar) {
      if (s is! Map) continue;
      final index = s['index'];
      final detik = s['detik_relatif_t0'];
      final statusSampel = StatusSampel.values.where(
        (v) => v.name == s['status'],
      );
      if (index is! int || detik is! int || statusSampel.isEmpty) continue;
      sampel.add(
        Sampel(
          index: index,
          detikRelatifT0: detik,
          status: statusSampel.first,
          dariBuffer: s['dari_buffer'] == true,
          gulaDarah: _int(s['gula_darah']),
          detakJantung: _int(s['detak_jantung']),
          sistolik: _int(s['sistolik']),
          diastolik: _int(s['diastolik']),
          spo2: _int(s['spo2']),
        ),
      );
    }
  }
  sampel.sort((a, b) => a.index.compareTo(b.index));

  // **Offset baseline diturunkan di sini, bukan dipercaya dari kawat.**
  //
  // Jarak baseline ke t0 adalah `waktuFoto - t0` — persis rumus yang dipakai
  // `SesiMakanController._terimaT0`, dan kedua sukunya ikut naik-turun apa
  // adanya. Yang ada di `detik_relatif_t0` index 0 justru tidak bisa dipercaya:
  // sesi draft sudah diunggah sebelum tombol "selesai makan" ditekan, jadi
  // server menerima baseline berstatus `terisi` dengan nilai sementara — lalu
  // membekukannya, karena sampel terisi tidak pernah ditimpa (§2 aturan 4).
  // Koreksi yang menyusul ditolak diam-diam, dan yang turun kembali adalah
  // nilai sebelum t0 diketahui.
  //
  // Gejalanya bukan angka yang meleset sedikit melainkan grafik yang rusak:
  // sumbu x kurva direntang dari `detikRelatifT0` terkecil, jadi baseline yang
  // meleset jauh memampatkan ketiga titik lain ke tepi kanan kartu.
  //
  // Tanpa t0 tidak ada yang bisa diturunkan, dan nilai kawat tetap dipakai:
  // sesi yang tombolnya tidak pernah ditekan memang belum punya titik nol.
  final t0 = DateTime.tryParse(data['t0'] as String? ?? '')?.toLocal();
  if (t0 != null && sampel.first.index == 0) {
    final b = sampel.first;
    sampel[0] = Sampel(
      index: b.index,
      detikRelatifT0: waktuFoto.toLocal().difference(t0).inSeconds,
      status: b.status,
      dariBuffer: b.dariBuffer,
      gulaDarah: b.gulaDarah,
      detakJantung: b.detakJantung,
      sistolik: b.sistolik,
      diastolik: b.diastolik,
      spo2: b.spo2,
    );
  }
  // §5.2 menjanjikan **selalu empat elemen**, dan seluruh aplikasi memercayai
  // itu: `SesiMakan.baseline` membaca `sampel[0]` tanpa bertanya, sehingga sesi
  // tanpa sampel bukan sesi yang tampil kosong melainkan layar merah di
  // Ringkasan Sesi. Sesi yang tidak memenuhi janji itu dilewati, bukan
  // dipaksakan masuk — satu baris cacat dari server tidak boleh merusak layar
  // yang sedang dibuka pengguna.
  if (sampel.isEmpty) return null;

  return SesiMakan(
    id: id,
    // Fotonya tidak ikut diunduh: berkasnya ada di ponsel yang memotretnya, dan
    // §5.2 hanya memberi URL bertanda tangan yang berumur pendek. `FotoMakanan`
    // menjatuhkannya ke penampung cadangan, bukan ke layar galat.
    fotoPath: '',
    waktuFoto: waktuFoto.toLocal(),
    t0: t0,
    status: status,
    sampel: sampel,
    hasil: _hasilDariJson(data['hasil']),
    waktuTidakPasti: data['waktu_tidak_pasti'] == true,
    sesiUji: data['sesi_uji'] == true,
    // Ikut dibaca, dan itu perlu: sesi hasil unduhan yang stempelnya null akan
    // mengirim ulang dirinya dengan `waktuFoto` sebagai `diperbarui_pada`, yang
    // pasti lebih tua daripada `updated_at` baris itu di server — 409 setiap
    // kali aplikasi dibuka. Yang menulisnya ke SQLite akan menstempelnya lagi
    // dengan waktu sekarang; nilai ini yang berlaku sampai saat itu.
    diperbaruiPada: DateTime.tryParse(
      data['diperbarui_pada'] as String? ?? '',
    )?.toLocal(),
  );
}

/// Nama status sesi **di kawat** (§5.2), yang snake_case — sedangkan
/// `StatusSesi.name` di Dart camelCase.
///
/// Ditulis sebagai tabel, bukan diturunkan dengan regex, karena inilah kontrak
/// itu sendiri: dua nilai yang berbeda hurufnya (`menungguPerangkat`,
/// `tidakLengkap`) ditolak server sebagai `422 validasi_gagal`, dan aplikasi
/// yang menelan setiap jawaban non-2xx tidak menunjukkan gejala apa pun —
/// setiap sesi yang berakhir `tidakLengkap` sekadar tidak pernah sampai.
/// Arah baliknya sama merusaknya: `sesiDariJson` yang mencocokkan nama enum
/// Dart membuang sesi ber-status `tidak_lengkap` / `menunggu_perangkat` diam-
/// diam saat diunduh.
const Map<StatusSesi, String> _statusKawat = {
  StatusSesi.draft: 'draft',
  StatusSesi.menungguPerangkat: 'menunggu_perangkat',
  StatusSesi.berjalan: 'berjalan',
  StatusSesi.selesai: 'selesai',
  StatusSesi.tidakLengkap: 'tidak_lengkap',
  StatusSesi.dibatalkan: 'dibatalkan',
};

/// URL bertanda tangan foto sesi dari satu elemen `GET /sesi`, atau null bila
/// server tidak punya fotonya. Bentuknya `foto: {url, kadaluarsa_pada}`.
String? urlFotoDariJson(Map<String, dynamic> data) {
  final foto = data['foto'];
  if (foto is! Map) return null;
  final url = foto['url'];
  return url is String && url.isNotEmpty ? url : null;
}

String statusKeKawat(StatusSesi status) => _statusKawat[status]!;

StatusSesi? statusDariKawat(Object? nilai) {
  for (final e in _statusKawat.entries) {
    if (e.value == nilai) return e.key;
  }
  return null;
}

int? _int(Object? nilai) => nilai is num ? nilai.round() : null;

double? _double(Object? nilai) => nilai is num ? nilai.toDouble() : null;

HasilDeteksi? _hasilDariJson(Object? data) {
  if (data is! Map) return null;
  final makanan = data['makanan'];
  if (makanan is! List) return null;

  final zat = data['zat_tidak_lengkap'];
  return HasilDeteksi(
    makanan: [
      for (final m in makanan)
        if (m is Map)
          ItemMakanan(
            nama: m['nama'] as String? ?? '',
            porsi: m['porsi'] as String? ?? '',
            estimasiGram: _double(m['estimasi_gram']) ?? 0,
            nutrisi: _nutrisiDariJson(m['nutrisi']),
          ),
    ],
    total: _nutrisiDariJson(data['total']),
    // Tidak ada lagi nilai bawaan di sini. Sebelumnya null diam-diam menjadi
    // "sedang" dan 0.0 — taksiran yang tidak pernah dibuat siapa pun, tampil
    // sebagai fakta.
    indeksGlikemikPerkiraan: data['indeks_glikemik_perkiraan'] as String?,
    keyakinan: _double(data['keyakinan']),
    zatTidakLengkap: {
      if (zat is List)
        for (final k in zat)
          if (k is String) ?ZatGizi.dariKunci(k),
    },
    dikoreksiUser: data['dikoreksi_user'] == true,
  );
}

/// Blok gizi yang **tidak ada sama sekali** dibaca sebagai tidak diketahui,
/// bukan sebagai nol — sama seperti setiap angkanya yang hilang satu per satu.
Nutrisi _nutrisiDariJson(Object? data) {
  if (data is! Map) return Nutrisi.tidakDiketahui;
  return Nutrisi(
    kalori: _double(data['kalori']),
    karbohidrat: _double(data['karbohidrat']),
    protein: _double(data['protein']),
    lemak: _double(data['lemak']),
    gulaTotal: _double(data['gula_total']),
    serat: _double(data['serat']),
  );
}

/// ISO-8601 **UTC** (§3): aplikasi yang mengirim waktu lokal akan menggeser
/// setiap sesi begitu servernya berada di zona lain.
String _waktu(DateTime waktu) =>
    waktu.toUtc().toIso8601String().replaceFirst('Z', '000Z');

/// Server palsu untuk test — mencatat apa yang dikirim, dan bisa disuruh gagal.
class SesiServerPalsu implements SesiServerService {
  SesiServerPalsu({this.gagal = false});

  bool gagal;
  final List<SesiMakan> diterima = [];

  /// Apa yang "sudah ada di server" saat [ambilSemua] dipanggil.
  List<SesiMakan>? tersedia;

  /// URL foto yang "dipunyai server", per id sesi. Yang tidak terdaftar di sini
  /// dianggap tidak punya foto — persis seperti `foto: null` di §5.2.
  final Map<String, String> urlFoto = {};

  /// Berkas yang berhasil diunduh: (url, jalur tujuan).
  final List<(String, String)> fotoDiunduh = [];

  /// Token yang dibawa setiap panggilan [unduhFoto] — rutenya di server berada
  /// di dalam `auth:sanctum`, jadi unduhan tanpa token adalah 401.
  final List<String> tokenUnduhFoto = [];

  /// Isi berkas yang dituliskan [unduhFoto]. Kosong berarti unduhan gagal —
  /// satu-satunya cara mencapai jalur "server punya fotonya tapi tidak sampai".
  List<int>? isiFoto = const [1, 2, 3];

  @override
  Future<List<SesiUnduhan>?> ambilSemua(String token) async => gagal
      ? null
      : [
          for (final s in tersedia ?? diterima)
            SesiUnduhan(sesi: s, urlFoto: urlFoto[s.id]),
        ];

  @override
  Future<bool> unduhFoto(String token, String url, String tujuan) async {
    tokenUnduhFoto.add(token);
    final isi = isiFoto;
    if (gagal || isi == null) return false;
    final berkas = File(tujuan);
    await berkas.parent.create(recursive: true);
    await berkas.writeAsBytes(isi, flush: true);
    fotoDiunduh.add((url, tujuan));
    return true;
  }

  @override
  Future<bool> kirim(String token, SesiMakan sesi) async {
    if (gagal) return false;
    diterima.add(sesi);
    return true;
  }

  /// Jalur foto yang sempat diunggah, berpasangan dengan id sesinya.
  final List<(String, String)> fotoDiunggah = [];

  /// Hasil yang "dikembalikan server" saat analisis diminta. null berarti
  /// analisisnya gagal atau tidak selesai — keadaan yang harus tetap terurus.
  HasilDeteksi? hasilAnalisis;

  final List<String> analisisDiminta = [];

  @override
  Future<bool> kirimFoto(String token, String sesiId, String jalurFoto) async {
    if (gagal) return false;
    fotoDiunggah.add((sesiId, jalurFoto));
    return true;
  }

  @override
  Future<HasilDeteksi?> mintaAnalisis(String token, String sesiId) async {
    if (gagal) return null;
    analisisDiminta.add(sesiId);
    return hasilAnalisis;
  }
}
