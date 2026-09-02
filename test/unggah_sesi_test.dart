// Unggahan riwayat sesi ke server (docs/rancangan-api-laravel.md §5.2).
//
// Satu arah: aplikasi mengunggah, tidak pernah mengunduh. Yang diuji di sini
// adalah kapan ia mengirim, apa yang ikut terbawa, dan apa yang terjadi kalau
// gagal — bukan HTTP-nya.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/ringkasan_sesi_page.dart';
import 'package:asawatch/services/ble_service.dart';
import 'package:asawatch/services/nutrisi_service.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/repositories/sesi_login_repository.dart';
import 'package:asawatch/repositories/sesi_repository.dart';
import 'package:asawatch/services/auth_service.dart';
import 'package:asawatch/services/sesi_server_service.dart';

import 'helpers.dart';

SesiLoginRepositoryMemori _masuk() => SesiLoginRepositoryMemori(
  SesiLogin(
    token: '4|token-uji',
    kedaluwarsa: DateTime.now().add(const Duration(days: 30)),
  ),
);

class _NutrisiGagal implements NutrisiService {
  @override
  Future<HasilDeteksi> analisis(String fotoPath) async =>
      throw Exception('tidak ada jaringan');
}

SesiMakan _sesiTanpaHasil(String id) => SesiMakan(
  id: id,
  fotoPath: '',
  waktuFoto: DateTime.now().subtract(const Duration(hours: 3)),
  t0: DateTime.now().subtract(const Duration(hours: 2)),
  status: StatusSesi.selesai,
  sampel: const [
    Sampel(
      index: 0,
      detikRelatifT0: -600,
      status: StatusSampel.terisi,
      gulaDarah: 96,
    ),
    Sampel(
      index: 1,
      detikRelatifT0: 0,
      status: StatusSampel.terisi,
      gulaDarah: 138,
    ),
    Sampel(
      index: 2,
      detikRelatifT0: 3600,
      status: StatusSampel.terisi,
      gulaDarah: 112,
    ),
    Sampel(
      index: 3,
      detikRelatifT0: 7200,
      status: StatusSampel.terisi,
      gulaDarah: 99,
    ),
  ],
);

SesiMakan _sesiSelesai(String id, {String nama = 'Nasi'}) => SesiMakan(
  id: id,
  fotoPath: '',
  waktuFoto: DateTime.now().subtract(const Duration(hours: 3)),
  t0: DateTime.now().subtract(const Duration(hours: 2)),
  status: StatusSesi.selesai,
  sampel: const [],
  hasil: HasilDeteksi(
    makanan: [
      ItemMakanan(
        nama: nama,
        porsi: '1 piring',
        estimasiGram: 100,
        nutrisi: Nutrisi.kosong,
      ),
    ],
    total: Nutrisi.kosong,
    indeksGlikemikPerkiraan: 'sedang',
    keyakinan: 0.8,
  ),
);

void main() {
  group('Kapan sesi dikirim', () {
    test('sesi yang berakhir langsung diunggah', () async {
      final server = SesiServerPalsu();
      final c = buatControllerUji(serverSesi: server, sesiLogin: _masuk());
      addTearDown(c.dispose);

      await c.mulaiDraft('/tmp/foto.jpg');
      (c.ble as FakeBleService).tekanSelesaiMakan();
      await Future<void>.delayed(Duration.zero);
      await c.akhiriLebihAwal();
      await Future<void>.delayed(Duration.zero);

      // Dua kali terkirim, dan itu memang alurnya: sekali sebagai draft —
      // endpoint foto menolak sesi yang belum ada di server — lalu sekali lagi
      // saat sesinya berakhir, kali ini lengkap dengan sampelnya.
      expect(server.diterima.first.status, StatusSesi.draft);
      expect(server.diterima.last.id, c.riwayat.single.id);
      expect(server.diterima.last.status.sedangAktif, isFalse);
    });

    test('gagal mengunggah tidak menjatuhkan sesinya', () async {
      final server = SesiServerPalsu(gagal: true);
      final c = buatControllerUji(serverSesi: server, sesiLogin: _masuk());
      addTearDown(c.dispose);

      await c.mulaiDraft('/tmp/foto.jpg');
      (c.ble as FakeBleService).tekanSelesaiMakan();
      await Future<void>.delayed(Duration.zero);
      await c.akhiriLebihAwal();
      await Future<void>.delayed(Duration.zero);

      // Datanya tetap di ponsel, dan akan dikirim lagi saat aplikasi dibuka
      // berikutnya — tidak ada yang hilang, jadi tidak ada yang perlu
      // dikeluhkan ke pengguna.
      expect(server.diterima, isEmpty);
      expect(c.riwayat, hasLength(1));
      expect(c.galatPenyimpanan, isNull);
    });

    test('tanpa token, tidak ada yang dikirim', () async {
      final server = SesiServerPalsu();
      final c = buatControllerUji(
        serverSesi: server,
        sesiLogin: SesiLoginRepositoryMemori(), // belum masuk
      );
      addTearDown(c.dispose);

      await c.mulaiDraft('/tmp/foto.jpg');
      (c.ble as FakeBleService).tekanSelesaiMakan();
      await Future<void>.delayed(Duration.zero);
      await c.akhiriLebihAwal();
      await c.kirimRiwayatKeServer();

      expect(server.diterima, isEmpty);
    });

    test('kirimRiwayatKeServer mengirim ulang seluruh riwayat', () async {
      final server = SesiServerPalsu(gagal: true);
      final c = buatControllerUji(serverSesi: server, sesiLogin: _masuk());
      addTearDown(c.dispose);

      await c.mulaiDraft('/tmp/foto.jpg');
      (c.ble as FakeBleService).tekanSelesaiMakan();
      await Future<void>.delayed(Duration.zero);
      await c.akhiriLebihAwal();
      await Future<void>.delayed(Duration.zero);
      expect(server.diterima, isEmpty);

      // Jaringan kembali; percobaan ulang tidak menuntut catatan apa pun,
      // karena PUT-nya idempoten terhadap UUID buatan aplikasi.
      server.gagal = false;
      await c.kirimRiwayatKeServer();

      expect(server.diterima, hasLength(1));
    });
  });

  group('Foto dan analisis lewat server', () {
    test('foto diunggah, lalu analisisnya diminta', () async {
      final server = SesiServerPalsu()
        ..hasilAnalisis = const HasilDeteksi(
          makanan: [
            ItemMakanan(
              nama: 'Nasi goreng',
              porsi: '1 piring',
              estimasiGram: 250,
              nutrisi: Nutrisi.kosong,
            ),
          ],
          total: Nutrisi.kosong,
          indeksGlikemikPerkiraan: 'tinggi',
          keyakinan: 0.77,
        );
      final c = buatControllerUji(serverSesi: server, sesiLogin: _masuk());
      addTearDown(c.dispose);

      await c.mulaiDraft('/tmp/piring.jpg');
      await Future<void>.delayed(Duration.zero);

      // Urutannya bukan selera: endpoint foto menolak sesi yang belum ada di
      // server, dan analisis menolak sesi yang belum punya foto.
      expect(server.diterima.first.status, StatusSesi.draft);
      expect(server.fotoDiunggah.single.$2, '/tmp/piring.jpg');
      expect(server.analisisDiminta.single, c.sesiAktif!.id);
      expect(c.sesiAktif!.hasil!.makanan.single.nama, 'Nasi goreng');

      await c.batalkan();
    });

    test('tanpa akun, angka gizinya tetap dari NutrisiService lokal', () async {
      final server = SesiServerPalsu();
      final c = buatControllerUji(
        serverSesi: server,
        sesiLogin: SesiLoginRepositoryMemori(), // belum masuk
      );
      addTearDown(c.dispose);

      await c.mulaiDraft('/tmp/piring.jpg');
      await Future<void>.delayed(Duration.zero);

      // Aplikasi harus tetap utuh tanpa akun (§2 aturan 3).
      expect(server.fotoDiunggah, isEmpty);
      expect(c.sesiAktif!.hasil, isNotNull);

      await c.batalkan();
    });

    test('unggahan foto yang gagal tidak menjatuhkan sesinya', () async {
      final server = SesiServerPalsu(gagal: true);
      final c = buatControllerUji(serverSesi: server, sesiLogin: _masuk());
      addTearDown(c.dispose);

      await c.mulaiDraft('/tmp/piring.jpg');
      await Future<void>.delayed(Duration.zero);

      // Sesinya tetap lahir dan tetap bisa dijalankan; yang hilang hanya angka
      // gizinya — dan layar mengatakannya, bukan berputar selamanya.
      expect(c.sesiAktif, isNotNull);
      expect(c.sesiAktif!.hasil, isNull);
      expect(c.sedangMenganalisis(c.sesiAktif!.id), isFalse);

      await c.batalkan();
    });
  });

  group('Mengunduh riwayat', () {
    test('sesi yang belum ada di ponsel ini ditambahkan', () async {
      final server = SesiServerPalsu()
        ..tersedia = [
          _sesiSelesai('dari-hp-lain-1'),
          _sesiSelesai('dari-hp-lain-2'),
        ];
      final c = buatControllerUji(serverSesi: server, sesiLogin: _masuk());
      addTearDown(c.dispose);

      await c.unduhRiwayatDariServer();

      // Inilah yang membuat pasang ulang dan ganti ponsel tidak lagi berarti
      // riwayat yang hilang.
      expect(
        c.riwayat.map((s) => s.id),
        containsAll(['dari-hp-lain-1', 'dari-hp-lain-2']),
      );
    });

    test('sesi yang sudah ada di sini tidak pernah ditimpa', () async {
      final lokal = _sesiSelesai('sama', nama: 'punya ponsel ini');
      final server = SesiServerPalsu()
        ..tersedia = [_sesiSelesai('sama', nama: 'punya server')];
      final c = buatControllerUji(
        serverSesi: server,
        sesiLogin: _masuk(),
        riwayatAwal: [lokal],
      );
      addTearDown(c.dispose);

      await c.unduhRiwayatDariServer();

      // Ponsel yang merekamnya tahu lebih banyak — fotonya saja hanya ada di
      // sini. Menimpanya berarti menukar yang lengkap dengan yang ringkas.
      expect(c.riwayat, hasLength(1));
      expect(c.riwayat.single.hasil!.makanan.single.nama, 'punya ponsel ini');
    });

    test('sesi yang masih berjalan di server dilewati', () async {
      final server = SesiServerPalsu()
        ..tersedia = [
          SesiMakan(
            id: 'masih-jalan',
            fotoPath: '',
            waktuFoto: DateTime.now(),
            t0: DateTime.now(),
            status: StatusSesi.berjalan,
            sampel: const [],
          ),
        ];
      final c = buatControllerUji(serverSesi: server, sesiLogin: _masuk());
      addTearDown(c.dispose);

      await c.unduhRiwayatDariServer();

      // Satu sesi aktif pada satu waktu (§6) berlaku untuk seluruh aplikasi;
      // menarik sesi berjalan milik perangkat lain membuat dua-duanya aktif.
      expect(c.riwayat, isEmpty);
      expect(c.sesiAktif, isNull);
    });

    test('gagal menarik tidak menghapus apa pun', () async {
      final server = SesiServerPalsu(gagal: true);
      final c = buatControllerUji(
        serverSesi: server,
        sesiLogin: _masuk(),
        riwayatAwal: [_sesiSelesai('lokal')],
      );
      addTearDown(c.dispose);

      await c.unduhRiwayatDariServer();

      // null berarti "tidak tahu", dan tidak tahu tidak pernah menghapus.
      expect(c.riwayat.single.id, 'lokal');
    });
  });

  group('Nutrisi yang tidak akan pernah datang', () {
    testWidgets('sesi hasil unduhan tidak berputar selamanya', (tester) async {
      final server = SesiServerPalsu()..tersedia = [_sesiTanpaHasil('unduhan')];
      // Tanpa addTearDown di sini: `pumpHalaman` yang memiliki controllernya.
      final c = buatControllerUji(serverSesi: server, sesiLogin: _masuk());
      await c.unduhRiwayatDariServer();

      await pumpHalaman(
        tester,
        RingkasanSesiPage(sesi: c.riwayat.single),
        controller: c,
      );
      await tester.pumpAndSettle();

      // Spinner di sini menjanjikan angka yang tidak akan pernah tiba: fotonya
      // tertinggal di ponsel yang memotretnya, dan tidak ada yang akan
      // menganalisis apa pun.
      expect(find.text('Menganalisis…'), findsNothing);
      expect(
        find.text('Rincian makanan tidak tersedia untuk sesi ini.'),
        findsOneWidget,
      );
    });

    test('analisis yang gagal berhenti dianggap sedang berjalan', () async {
      final c = buatControllerUji(nutrisi: _NutrisiGagal());
      addTearDown(c.dispose);

      await c.mulaiDraft('/tmp/foto.jpg');
      await Future<void>.delayed(Duration.zero);

      expect(c.sesiAktif!.hasil, isNull);
      expect(c.sedangMenganalisis(c.sesiAktif!.id), isFalse);

      await c.batalkan();
    });
  });

  group('Foto sesi hasil unduhan', () {
    test('fotonya ikut turun dan tersimpan sebagai berkas', () async {
      final folder = Directory.systemTemp.createTempSync('unduh_foto');
      addTearDown(() {
        if (folder.existsSync()) folder.deleteSync(recursive: true);
      });

      final server = SesiServerPalsu();
      final sesiServer = _sesiTanpaHasil('a1');
      server.tersedia = [sesiServer];
      server.urlFoto[sesiServer.id] = 'https://server/foto/a1?signature=abc';

      final c = buatControllerUji(
        serverSesi: server,
        sesiLogin: _masuk(),
        jalurFoto: (nama) async => '${folder.path}/\$nama',
      );
      addTearDown(c.dispose);

      await c.unduhRiwayatDariServer();

      // Yang disimpan adalah berkasnya, bukan URL-nya: tanda tangan §5.2
      // kedaluwarsa satu jam, jadi menyimpan alamatnya berarti jalur mati esok
      // pagi.
      final sesi = c.riwayat.single;
      expect(sesi.fotoPath, isNotEmpty);
      expect(sesi.fotoPath, isNot(contains('signature')));
      expect(File(sesi.fotoPath).existsSync(), isTrue);
      expect(server.fotoDiunduh, hasLength(1));
    });

    test('unduhan foto membawa token', () async {
      // Rutenya (`GET /api/v1/foto/{sesi}`) memakai `signed` di dalam grup
      // `auth:sanctum`: tanpa header ini jawabannya 401, dan sesinya sampai
      // dengan angka gizi lengkap tetapi tanpa piring.
      final folder = Directory.systemTemp.createTempSync('token_foto');
      addTearDown(() {
        if (folder.existsSync()) folder.deleteSync(recursive: true);
      });

      final server = SesiServerPalsu();
      final sesiServer = _sesiTanpaHasil('a1');
      server.tersedia = [sesiServer];
      server.urlFoto[sesiServer.id] = 'https://server/foto/a1?signature=abc';

      final c = buatControllerUji(
        serverSesi: server,
        sesiLogin: _masuk(),
        jalurFoto: (nama) async => '${folder.path}/\$nama',
      );
      addTearDown(c.dispose);

      await c.unduhRiwayatDariServer();

      expect(server.tokenUnduhFoto, ['4|token-uji']);
    });

    test('sesi lama yang fotonya kosong dicoba lagi', () async {
      // Sesi yang sudah terlanjur turun tanpa foto tidak pernah ditimpa oleh
      // [unduhRiwayatDariServer] (aturan 1), jadi tanpa percobaan ulang di sini
      // piringnya hilang selamanya walaupun server menyimpannya.
      final folder = Directory.systemTemp.createTempSync('foto_menyusul');
      addTearDown(() {
        if (folder.existsSync()) folder.deleteSync(recursive: true);
      });

      final sesi = _sesiTanpaHasil('a1'); // fotoPath kosong
      final server = SesiServerPalsu();
      server.tersedia = [sesi];
      server.urlFoto[sesi.id] = 'https://server/foto/a1?signature=abc';

      final c = buatControllerUji(
        riwayatAwal: [sesi],
        serverSesi: server,
        sesiLogin: _masuk(),
        jalurFoto: (nama) async => '${folder.path}/\$nama',
      );
      addTearDown(c.dispose);

      await c.kirimRiwayatKeServer();

      expect(c.riwayat.single.fotoPath, isNotEmpty);
      expect(File(c.riwayat.single.fotoPath).existsSync(), isTrue);
      // Tidak ada foto lokal untuk dikirim balik.
      expect(server.fotoDiunggah, isEmpty);
    });

    test('unduhan foto yang gagal tidak menjatuhkan sesinya', () async {
      final server = SesiServerPalsu();
      final sesiServer = _sesiTanpaHasil('a1');
      server.tersedia = [sesiServer];
      server.urlFoto[sesiServer.id] = 'https://server/foto/a1';
      server.isiFoto = null; // unduhannya gagal

      final c = buatControllerUji(
        serverSesi: server,
        sesiLogin: _masuk(),
        jalurFoto: (nama) async => '/tmp/\$nama',
      );
      addTearDown(c.dispose);

      await c.unduhRiwayatDariServer();

      // Sesi dengan kurva dan angka yang utuh jauh lebih berharga daripada
      // tidak ada sesi sama sekali; piringnya jatuh ke penampung cadangan.
      expect(c.riwayat, hasLength(1));
      expect(c.riwayat.single.fotoPath, isEmpty);
    });
  });

  group('Percobaan ulang unggah foto', () {
    test('sesi yang fotonya belum ada di server dikirim ulang', () async {
      // Sesi ini **punya** angka gizi — dari NutrisiService lokal, karena
      // difoto sebelum pengguna masuk. Penanda lama ("sudah punya hasil")
      // melewatinya selamanya, dan piringnya hilang dari akun secara permanen.
      final folder = Directory.systemTemp.createTempSync('foto_ulang');
      addTearDown(() {
        if (folder.existsSync()) folder.deleteSync(recursive: true);
      });
      final berkas = File('${folder.path}/p.jpg')
        ..writeAsBytesSync([9, 9, 9]);

      final sesi = _sesiTanpaHasil('a1').salin(
        fotoPath: berkas.path,
        hasil: const HasilDeteksi(makanan: [], total: Nutrisi.tidakDiketahui),
      );

      final server = SesiServerPalsu();
      // Server punya sesinya, tetapi tidak punya fotonya.
      server.tersedia = [sesi];

      final c = buatControllerUji(
        riwayatAwal: [sesi],
        serverSesi: server,
        sesiLogin: _masuk(),
      );
      addTearDown(c.dispose);

      await c.kirimRiwayatKeServer();

      expect(server.fotoDiunggah, hasLength(1));
      expect(server.fotoDiunggah.single.$1, sesi.id);
      // Angka gizinya sudah ada, jadi analisis tidak diminta ulang.
      expect(server.analisisDiminta, isEmpty);
    });

    test('sesi yang fotonya sudah ada di server tidak dikirim dua kali', () async {
      final folder = Directory.systemTemp.createTempSync('foto_ada');
      addTearDown(() {
        if (folder.existsSync()) folder.deleteSync(recursive: true);
      });
      final berkas = File('${folder.path}/p.jpg')
        ..writeAsBytesSync([9, 9, 9]);

      final sesi = _sesiTanpaHasil('a1').salin(fotoPath: berkas.path);
      final server = SesiServerPalsu();
      server.tersedia = [sesi];
      server.urlFoto[sesi.id] = 'https://server/foto/a1';

      final c = buatControllerUji(
        riwayatAwal: [sesi],
        serverSesi: server,
        sesiLogin: _masuk(),
      );
      addTearDown(c.dispose);

      await c.kirimRiwayatKeServer();

      // Foto berukuran ratusan kilobyte; mengirimnya ulang tiap pembukaan
      // aplikasi adalah biaya yang tidak dibayar apa pun.
      expect(server.fotoDiunggah, isEmpty);
    });
  });

  group('Stempel diperbarui_pada', () {
    // Kenapa grup ini ada: server memakai aturan "yang terbaru menang" (§7.1)
    // dan menolak `409 konflik_versi` bila `diperbarui_pada` kiriman lebih tua
    // daripada `updated_at` barisnya. Sesi yang tidak pernah menerima kembali
    // stempel hasil penulisan lokalnya akan mengirim `waktuFoto` — yang selalu
    // lebih tua daripada `updated_at` yang server tulis saat draft-nya
    // diunggah — sehingga kiriman kedua selalu ditolak. Gejalanya di ponsel
    // nol, jadi hanya test ini yang bisa menangkapnya.
    test('sesi yang berakhir membawa stempel dari penulisan lokal', () async {
      final server = SesiServerPalsu();
      final c = buatControllerUji(
        serverSesi: server,
        sesiLogin: _masuk(),
        repo: SesiRepositoryMemori(),
      );
      addTearDown(c.dispose);

      await c.mulaiDraft('/tmp/foto.jpg');
      (c.ble as FakeBleService).tekanSelesaiMakan();
      await Future<void>.delayed(Duration.zero);
      await c.akhiriLebihAwal();
      await Future<void>.delayed(Duration.zero);

      final draft = server.diterima.first;
      final akhir = server.diterima.last;
      expect(draft.diperbaruiPada, isNotNull);
      expect(akhir.diperbaruiPada, isNotNull);
      // Yang menentukan: bukan sekadar ada, melainkan **maju**. Dua kiriman
      // yang membawa stempel sama persis adalah bentuk bug yang diperbaiki.
      expect(
        akhir.diperbaruiPada!.isAfter(draft.diperbaruiPada!) ||
            akhir.diperbaruiPada!.isAtSameMomentAs(draft.diperbaruiPada!),
        isTrue,
      );
      expect(akhir.diperbaruiPada!.isAfter(akhir.waktuFoto), isTrue);
      // Dan salinan di memori ikut berstempel — itulah yang dibaca pengiriman
      // ulang di pembukaan aplikasi berikutnya.
      expect(c.riwayat.single.diperbaruiPada, akhir.diperbaruiPada);
    });

    test('stempel dikirim apa adanya, bukan waktu pengiriman', () {
      final stempel = DateTime.utc(2026, 8, 20, 5, 7, 29);
      final badan = badanSesi(
        _sesiTanpaHasil('a1').salin(diperbaruiPada: stempel),
      );
      expect(badan['diperbarui_pada'], '2026-08-20T05:07:29.000000Z');
    });
  });

  group('Nama status di kawat', () {
    // §5.2 memakai snake_case, `StatusSesi.name` di Dart camelCase. Mengirim
    // nama Dart apa adanya membuat setiap sesi yang berakhir `tidakLengkap`
    // ditolak `422 validasi_gagal` — tanpa satu pun gejala di layar, karena
    // aplikasi menelan jawaban non-2xx.
    test('setiap status punya nama snake_case, dan bolak-balik utuh', () {
      const harapan = {
        StatusSesi.draft: 'draft',
        StatusSesi.menungguPerangkat: 'menunggu_perangkat',
        StatusSesi.berjalan: 'berjalan',
        StatusSesi.selesai: 'selesai',
        StatusSesi.tidakLengkap: 'tidak_lengkap',
        StatusSesi.dibatalkan: 'dibatalkan',
      };
      for (final status in StatusSesi.values) {
        expect(statusKeKawat(status), harapan[status], reason: '$status');
        expect(statusDariKawat(harapan[status]), status);
      }
    });

    test('sesi tidak lengkap dikirim sebagai tidak_lengkap', () {
      final badan = badanSesi(
        _sesiTanpaHasil('a1').salin(status: StatusSesi.tidakLengkap),
      );
      expect(badan['status'], 'tidak_lengkap');
    });

    test('sesi tidak_lengkap dari server terbaca, bukan dibuang', () {
      // Arah balik dari bug yang sama: `sesiDariJson` yang mencocokkan nama
      // enum Dart membuang seluruh sesi ini diam-diam.
      final sesi = sesiDariJson({
        'id': 'b2',
        'waktu_foto': '2026-08-20T08:00:00.000000Z',
        'status': 'tidak_lengkap',
        'diperbarui_pada': '2026-08-20T10:31:00.000000Z',
        'sampel': [
          {'index': 0, 'detik_relatif_t0': 0, 'status': 'terisi'},
        ],
      });
      expect(sesi?.status, StatusSesi.tidakLengkap);
      expect(sesi?.diperbaruiPada, DateTime.utc(2026, 8, 20, 10, 31).toLocal());
    });
  });

  group('Offset baseline sesi unduhan', () {
    Map<String, dynamic> jsonSesi({
      required int detikBaseline,
      String? t0 = '2026-08-20T08:25:00.000000Z',
    }) => {
      'id': 'b1',
      'waktu_foto': '2026-08-20T08:00:00.000000Z',
      't0': t0,
      'status': 'selesai',
      'sampel': [
        {'index': 0, 'detik_relatif_t0': detikBaseline, 'status': 'terisi'},
        {'index': 1, 'detik_relatif_t0': 0, 'status': 'terisi'},
        {'index': 2, 'detik_relatif_t0': 3600, 'status': 'terisi'},
        {'index': 3, 'detik_relatif_t0': 7200, 'status': 'terisi'},
      ],
    };

    test('diturunkan dari waktu foto dan t0, bukan dari kawat', () {
      // Server membekukan sampel yang sudah `terisi` (§2 aturan 4), dan sesi
      // draft sudah diunggah sebelum tombol ditekan — jadi yang tersimpan di
      // sana adalah offset baseline sebelum t0 diketahui, dan koreksinya
      // ditolak diam-diam. Yang benar bisa dihitung, jadi dihitung.
      final sesi = sesiDariJson(jsonSesi(detikBaseline: 0));
      expect(sesi!.sampel.first.detikRelatifT0, -1500); // 25 menit sebelum t0
      // Titik lain tidak disentuh: nilainya memang datang dari pengukuran.
      expect(sesi.sampel[2].detikRelatifT0, 3600);
    });

    test('nilai kawat yang bukan nol pun tetap diturunkan ulang', () {
      // Kasus yang benar-benar terjadi: `FakeBleService` mengirim baseline
      // -1500 sementara t0 datang dua menit setelah foto. Rentang -1500..20
      // memampatkan ketiga titik lain ke ujung kanan kartu — grafik yang
      // "gepeng di belakang".
      final sesi = sesiDariJson(
        jsonSesi(
          detikBaseline: -1500,
          t0: '2026-08-20T08:02:00.000000Z',
        ),
      )!;
      expect(sesi.sampel.first.detikRelatifT0, -120);
    });

    test('tanpa t0 nilai kawat tetap dipakai', () {
      // Sesi yang tombolnya tidak pernah ditekan belum punya titik nol; tidak
      // ada yang bisa diturunkan, dan menebak lebih buruk daripada menerima.
      final sesi = sesiDariJson(jsonSesi(detikBaseline: -900, t0: null))!;
      expect(sesi.t0, isNull);
      expect(sesi.sampel.first.detikRelatifT0, -900);
    });
  });

  group('Kiriman server yang cacat', () {
    test('sesi tanpa sampel dilewati, bukan dipaksakan masuk', () {
      // `SesiMakan.baseline` membaca sampel[0] tanpa bertanya; sesi tanpa
      // sampel bukan tampil kosong, melainkan layar merah di Ringkasan Sesi.
      expect(
        sesiDariJson({
          'id': 'cacat',
          'waktu_foto': '2026-08-20T08:00:00.000000Z',
          'status': 'selesai',
          'sampel': <Object>[],
        }),
        isNull,
      );
    });

    test('status yang tidak dikenal dilewati', () {
      expect(
        sesiDariJson({
          'id': 'cacat',
          'waktu_foto': '2026-08-20T08:00:00.000000Z',
          'status': 'entah_apa',
          'sampel': [
            {'index': 0, 'detik_relatif_t0': 0, 'status': 'terisi'},
          ],
        }),
        isNull,
      );
    });
  });

  group('Bentuk yang dikirim', () {
    test('sesi uji ikut naik, lengkap dengan tandanya', () {
      final sesi = SesiMakan(
        id: 'a1',
        fotoPath: '/tmp/f.jpg',
        waktuFoto: DateTime.utc(2026, 8, 20, 4, 12, 31),
        t0: DateTime.utc(2026, 8, 20, 4, 22, 10),
        status: StatusSesi.selesai,
        sesiUji: true,
        sampel: const [
          Sampel(
            index: 0,
            detikRelatifT0: -580,
            status: StatusSampel.terisi,
            gulaDarah: 96,
            detakJantung: 74,
            sistolik: 118,
            diastolik: 76,
            spo2: 98,
          ),
          Sampel(index: 1, detikRelatifT0: 0, status: StatusSampel.menunggu),
        ],
      );

      final badan = badanSesi(sesi);

      // Tandanya yang menjaga angka sesi dua menit tidak ikut dihitung di
      // server; menyembunyikan sesinya sendiri justru membuat jalur unggah ini
      // tak pernah terlatih.
      expect(badan['sesi_uji'], isTrue);
      expect(badan['status'], 'selesai');
      // UTC, bukan waktu lokal: server di zona lain akan menggeser setiap sesi.
      expect(badan['waktu_foto'], '2026-08-20T04:12:31.000000Z');
      expect(badan['t0'], '2026-08-20T04:22:10.000000Z');

      final sampel = badan['sampel'] as List;
      expect(sampel, hasLength(2));
      expect(sampel[0]['index'], 0);
      expect(sampel[0]['gula_darah'], 96);
      expect(sampel[1]['status'], 'menunggu');
      // Gagal diukur dikirim sebagai null — 0 adalah nilai yang berarti.
      expect(sampel[1]['gula_darah'], isNull);

      // Harus tetap bisa di-encode: satu objek DateTime yang lolos akan
      // melempar tepat saat dikirim, bukan saat dibangun.
      expect(() => jsonEncode(badan), returnsNormally);
    });

    test('sesi tanpa t0 mengirim null, bukan dilewati', () {
      final badan = badanSesi(
        SesiMakan(
          id: 'a2',
          fotoPath: '/tmp/f.jpg',
          waktuFoto: DateTime.utc(2026, 8, 20, 4, 12, 31),
          status: StatusSesi.draft,
          sampel: const [],
        ),
      );

      expect(badan.containsKey('t0'), isTrue);
      expect(badan['t0'], isNull);
    });
  });
}
