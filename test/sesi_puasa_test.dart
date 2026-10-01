// Mode puasa — sesi tanpa foto untuk memantau gula darah saat berpuasa
// (docs/rancangan-api-laravel.md §5.2 `jenis`).
//
// Mode ini tambahan. Separuh berkas ini menguji bahwa ia bekerja; separuhnya
// lagi menguji bahwa ia tidak menyentuh sesi makan: tidak ikut hitungan makan,
// dan sesi makan tetap menunggu foto dan tombolnya.

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/deteksi_makanan_page.dart';
import 'package:asawatch/models/analisis_sesi.dart';
import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/jadwal_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/repositories/basis_data.dart';
import 'package:asawatch/repositories/sesi_repository_drift.dart';
import 'package:asawatch/ringkasan_sesi_page.dart';
import 'package:asawatch/sesi_berjalan_page.dart';
import 'package:asawatch/services/kamera_service.dart';
import 'package:asawatch/services/sesi_server_service.dart';
import 'package:asawatch/widgets/kurva_sampel.dart';
import 'package:asawatch/widgets/peringatan_gula_rendah.dart';

import 'helpers.dart';

/// Sesi puasa rakitan tangan. [gula] berisi gula darah untuk index 0, 2, 3;
/// null berarti titiknya belum terisi.
SesiMakan _puasa({
  List<int?> gula = const [95, 92, 90],
  StatusSesi status = StatusSesi.selesai,
  DateTime? t0,
}) {
  final mulai = t0 ?? DateTime(2026, 9, 25, 5, 0);
  const index = [0, 2, 3];
  const detik = [0, 3600, 7200];
  return SesiMakan(
    id: '6f1c2b7e-4c1a-4b0e-9a6f-2d3e4f5a6b7c',
    fotoPath: '',
    waktuFoto: mulai,
    t0: mulai,
    status: status,
    jenis: JenisSesi.puasa,
    sampel: [
      for (var i = 0; i < 3; i++)
        gula[i] == null
            ? Sampel.menunggu(index: index[i], detikRelatifT0: detik[i])
            : Sampel(
                index: index[i],
                detikRelatifT0: detik[i],
                status: StatusSampel.terisi,
                gulaDarah: gula[i],
              ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(loadMontserrat);
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('Model', () {
    test('jadwal puasa: baseline di t0, +1 jam, +2 jam — tanpa index 1', () {
      expect(jadwalPuasa.titik.map((t) => t.index), [0, 2, 3]);
      expect(jadwalPuasa.titik.first.detikNominal, 0);
      // +1 jam dan +2 jam sama persis dengan sesi makan, supaya slot di server
      // dan kolom ekspor tetap sejajar.
      for (final i in [2, 3]) {
        expect(jadwalPuasa[i].jendelaAwal, jadwalNormal[i].jendelaAwal);
        expect(jadwalPuasa[i].jendelaAkhir, jadwalNormal[i].jendelaAkhir);
      }
    });

    test('jadwal uji ikut dimampatkan untuk sesi puasa', () {
      final uji = jadwalNormal.dibagi(60);
      expect(uji.keJenis(JenisSesi.makan), same(uji));
      final puasaUji = uji.keJenis(JenisSesi.puasa);
      expect(puasaUji.uji, isTrue);
      expect(puasaUji[2].detikNominal, 60);
    });

    test('kondisi puasa dinilai dari titik terendah', () {
      expect(_puasa(gula: [95, 92, 90]).kondisiPuasa, KondisiPuasa.stabil);
      expect(_puasa(gula: [100, 90, 84]).kondisiPuasa, KondisiPuasa.turun);
      expect(_puasa(gula: [95, 68, 80]).kondisiPuasa, KondisiPuasa.rendah);
      expect(
        _puasa(gula: [95, 80, 50]).kondisiPuasa,
        KondisiPuasa.sangatRendah,
      );
    });

    test('gula rendah diperingatkan selagi berjalan, stabil belum', () {
      final berjalanRendah = _puasa(
        gula: [95, 66, null],
        status: StatusSesi.berjalan,
      );
      expect(berjalanRendah.kondisiPuasa, KondisiPuasa.rendah);

      final berjalanWajar = _puasa(
        gula: [95, 92, null],
        status: StatusSesi.berjalan,
      );
      expect(berjalanWajar.kondisiPuasa, KondisiPuasa.belumLengkap);
    });

    test('sesi puasa tidak punya waktu makan dan tidak dinilai responsnya', () {
      final s = _puasa();
      expect(s.waktuMakan, isNull);
      expect(s.labelWaktuMakan, 'Pemantauan Puasa');
      expect(s.kualitasRespons, KualitasRespons.belumLengkap);
      expect(s.verdict, contains('stabil'));
    });

    test('AnalisisSesi tidak mengikutkan sesi puasa', () {
      final analisis = AnalisisSesi([_puasa(), ...contohRiwayatSesi()]);
      expect(analisis.sesi.any((s) => s.puasa), isFalse);
    });
  });

  group('Alur controller', () {
    testWidgets('dimulai tanpa foto dan tanpa tombol Selesai Makan', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiPuasa();
      await tester.pump();

      final sesi = c.sesiAktif!;
      expect(sesi.puasa, isTrue);
      expect(sesi.fotoPath, isEmpty);
      expect(sesi.sampel.map((s) => s.index), [0, 2, 3]);
      // t0 datang dari jam lewat `MULAI_SESI` yang dikirim aplikasi sendiri.
      expect(sesi.t0, isNotNull);
      expect(sesi.status, StatusSesi.berjalan);

      await hentikanSesi(tester, c);
    });

    testWidgets('pengukuran jam di t0 menjadi baseline, lalu sesi tuntas', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiPuasa();
      // percepatan 3600: dua jam jadwal = dua detik.
      await tester.pump(const Duration(seconds: 3));

      expect(c.sesiAktif, isNull, reason: 'ketiga titik sudah masuk');
      final selesai = c.riwayat.first;
      expect(selesai.puasa, isTrue);
      expect(selesai.status, StatusSesi.selesai);
      // Jam menamai pengukuran t0-nya index 1; sesi puasa menyimpannya
      // sebagai baseline (index 0), sesuai kontrak server.
      expect(selesai.sampel.map((s) => s.index), [0, 2, 3]);
      expect(selesai.sampel.every((s) => s.terisi), isTrue);
      expect(selesai.baseline, isNotNull);
    });

    testWidgets('tidak ikut ringkasan harian maupun puncak setelah makan', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await c.mulaiPuasa();
      await tester.pump(const Duration(seconds: 3));

      expect(c.riwayat.first.puasa, isTrue);
      expect(c.sesiHariIni(), isEmpty);
      expect(c.puncakTerakhir(), isEmpty);
    });

    testWidgets('sesi makan tetap menunggu tombolnya — tidak dimulai sendiri', (
      tester,
    ) async {
      // Mulai otomatis milik sesi puasa saja. Sesi makan yang dimulai tanpa
      // tombol akan mengambil t0 dari saat foto, bukan saat selesai makan.
      final c = buatControllerUji();
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);

      await c.mulaiDraft(contohFotoPath);
      await tester.pump(const Duration(milliseconds: 200));

      final sesi = c.sesiAktif!;
      expect(sesi.jenis, JenisSesi.makan);
      expect(sesi.sampel.map((s) => s.index), [0, 1, 2, 3]);
      expect(sesi.t0, isNull);

      await hentikanSesi(tester, c);
    });
  });

  group('Kawat (§5.2)', () {
    test('jenis ikut terkirim, dan sesi puasa hanya membawa tiga titiknya', () {
      final badan = badanSesi(_puasa());
      expect(badan['jenis'], 'puasa');
      expect((badan['sampel'] as List).map((s) => s['index']), [0, 2, 3]);

      expect(badanSesi(contohSesiSelesai())['jenis'], 'makan');
    });

    Map<String, dynamic> json({
      Object? jenis,
      List<int> index = const [0, 2, 3],
    }) => {
      'id': 'x1',
      'waktu_foto': '2026-09-25T05:00:00.000000Z',
      't0': '2026-09-25T05:00:03.000000Z',
      'status': 'selesai',
      'jenis': ?jenis,
      'sampel': [
        for (final i in index)
          {
            'index': i,
            'detik_relatif_t0': i == 0 ? 4 : (i == 1 ? 0 : (i - 1) * 3600),
            'status': 'terisi',
            'gula_darah': 90,
          },
      ],
    };

    test('sesi puasa dari server: jenis terbaca, index 1 dibuang', () {
      final s = sesiDariJson(json(jenis: 'puasa', index: [0, 1, 2, 3]))!;
      expect(s.puasa, isTrue);
      expect(s.sampel.map((x) => x.index), [0, 2, 3]);
      // Baseline puasa diukur sesudah t0; nilainya di kawat yang benar, bukan
      // `waktuFoto - t0` seperti koreksi milik sesi makan.
      expect(s.sampel.first.detikRelatifT0, 4);
    });

    test('tanpa field jenis (server lama) dibaca sebagai sesi makan', () {
      final s = sesiDariJson(json(index: [0, 1, 2, 3]))!;
      expect(s.jenis, JenisSesi.makan);
      expect(s.sampel.length, 4);
    });
  });

  group('Penyimpanan', () {
    test('jenis dan tiga titik bertahan bolak-balik lewat SQLite', () async {
      final db = BasisData(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = SesiRepositoryDrift(db);

      await repo.simpan(_puasa(gula: [95, 88, null]));
      final dimuat = (await repo.muatSemua()).single;

      expect(dimuat.jenis, JenisSesi.puasa);
      expect(dimuat.sampel.map((s) => s.index), [0, 2, 3]);
      expect(dimuat.sampel[1].gulaDarah, 88);
      expect(dimuat.sampel[2].status, StatusSampel.menunggu);
    });

    test('sesi makan tetap empat titik dan berjenis makan', () async {
      final db = BasisData(NativeDatabase.memory());
      addTearDown(db.close);
      final repo = SesiRepositoryDrift(db);

      await repo.simpan(contohSesiSelesai());
      final dimuat = (await repo.muatSemua()).single;

      expect(dimuat.jenis, JenisSesi.makan);
      expect(dimuat.sampel.map((s) => s.index), [0, 1, 2, 3]);
    });
  });

  group('Layar', () {
    testWidgets('kamera menawarkan mode puasa dan membuka Sesi Berjalan', (
      tester,
    ) async {
      final c = buatControllerUji();
      await pumpHalaman(
        tester,
        DeteksiMakananPage(kamera: KameraPalsuService()),
        controller: c,
      );
      await tester.pump(const Duration(milliseconds: 50));

      await tester.tap(find.text('Mulai Tanpa Foto (Puasa)'));
      await tester.pumpAndSettle();
      expect(find.text('Mulai pemantauan puasa?'), findsOneWidget);

      await tester.tap(find.text('Mulai'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(c.sesiAktif?.puasa, isTrue);
      expect(find.byType(SesiBerjalanPage), findsOneWidget);
      expect(find.text('Pemantauan Puasa'), findsOneWidget);
      // Tidak ada kartu makanan yang menunggu nutrisi yang tidak akan datang.
      expect(find.text('Makanan'), findsNothing);

      await hentikanSesi(tester, c);
    });

    testWidgets('sesi berjalan memperingatkan gula rendah seketika', (
      tester,
    ) async {
      final c = buatControllerUji(
        riwayatAwal: [
          _puasa(
            gula: [95, 64, null],
            status: StatusSesi.berjalan,
            t0: DateTime.now().subtract(const Duration(minutes: 70)),
          ),
        ],
      );
      await pumpHalaman(tester, const SesiBerjalanPage(), controller: c);
      await tester.pump();

      expect(find.byType(PeringatanGulaRendah), findsOneWidget);
      expect(
        find.textContaining('Gula darah rendah · 64 mg/dL'),
        findsOneWidget,
      );
      // Tidak memerintah: angka jam adalah perkiraan.
      expect(find.textContaining('Pastikan dengan alat cek'), findsOneWidget);

      await hentikanSesi(tester, c);
    });

    testWidgets(
      'ringkasan puasa: terendah sebagai angka utama, tanpa nutrisi',
      (tester) async {
        await pumpHalaman(
          tester,
          RingkasanSesiPage(sesi: _puasa(gula: [95, 80, 52])),
        );
        await tester.pump();

        expect(find.text('Ringkasan Pemantauan'), findsOneWidget);
        expect(find.text('Gula Darah Selama Puasa'), findsOneWidget);
        expect(find.text('Nutrisi Sesi Ini'), findsNothing);
        expect(find.text('Gula sangat rendah'), findsOneWidget);
        expect(find.byType(PeringatanGulaRendah), findsOneWidget);
        // Satu angka, satu tempat: terendah sudah menjadi angka besar, jadi
        // kotak di bawahnya menyebut kapan, bukan berapa lagi.
        expect(find.text('Saat terendah'), findsOneWidget);
        expect(find.text('52'), findsOneWidget);
      },
    );

    testWidgets('kurva puasa membawa batas rendah; kurva makan tidak', (
      tester,
    ) async {
      KurvaSampel kurvaGula() => tester
          .widgetList<KurvaSampel>(find.byType(KurvaSampel))
          .firstWhere((k) => k.seri.contains(seriGulaDarah));

      await pumpHalaman(
        tester,
        RingkasanSesiPage(sesi: _puasa(gula: [95, 90, 88])),
      );
      await tester.pump();
      expect(kurvaGula().ambangRendah, ambangGulaRendah);

      await pumpHalaman(tester, RingkasanSesiPage(sesi: contohSesiSelesai()));
      await tester.pump();
      expect(kurvaGula().ambangRendah, isNull);
    });
  });
}
