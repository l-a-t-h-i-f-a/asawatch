// Baterai kritis jam — protokol §5.5 `flag` bit2, ambang 10% milik firmware
// (`AW_BATERAI_KRITIS_PCT`).
//
// Yang diuji di sini bukan angkanya melainkan **akibatnya**. Di bawah ambang
// itu jam men-`NAK` setiap `UKUR`, `UKUR_SEKARANG`, dan `MULAI_SESI`, dan
// tombol fisiknya pun tidak berbuat apa-apa. Sebelum ini, bit-nya sampai ke
// `StatusJam` lalu berhenti di sana: layar menulis "8%", orang menekan tombol
// yang pasti ditolak, dan sebabnya baru muncul sesudahnya — kalau sempat
// terbaca.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/pindai_kesehatan_page.dart';
import 'package:asawatch/services/izin_ble.dart';

import 'helpers.dart';

const _kritis = StatusPerangkat(
  tersambung: true,
  baterai: 8,
  namaPerangkat: 'AsaWatch X1',
  bateraiKritis: true,
);

void main() {
  setUpAll(loadMontserrat);

  group('StatusPerangkat', () {
    test('kabar kritis dibuang saat jam terputus, seperti baterai', () {
      // Sifat alat (kemampuan) ditahan melewati pemutusan; keadaan yang berubah
      // tiap menit tidak. Baterai jam yang tidak tersambung bisa saja sudah
      // diisi penuh sejak tadi.
      expect(_kritis.bateraiKritis, isTrue);
      expect(_kritis.salin(tersambung: false).bateraiKritis, isFalse);
    });

    test('jam sehat tidak kritis', () {
      const sehat = StatusPerangkat(tersambung: true, baterai: 68);
      expect(sehat.bateraiKritis, isFalse);
    });
  });

  group('Penjaga di controller', () {
    test('alasannya menyebut ambang jam, bukan sekadar "baterai rendah"', () {
      final c = buatControllerUji(status: _kritis);
      addTearDown(c.dispose);

      final alasan = c.alasanJamTidakBisaUkur;
      expect(alasan, isNotNull);
      expect(alasan, contains('8%'));
      expect(alasan, contains('10%'));
      expect(alasan, contains('Isi daya'));
    });

    test('pindai ditolak sebelum satu perintah pun dikirim', () async {
      final c = buatControllerUji(status: _kritis);
      addTearDown(c.dispose);

      await expectLater(c.pindaiKesehatan(), throwsA(isA<Object>()));
    });

    test('kalibrasi memakai penjaga yang sama', () async {
      // Alur kalibrasi tiga putaran berjeda 60 detik: gagal di putaran
      // terakhir berarti seluruhnya diulang dari awal.
      final c = buatControllerUji(status: _kritis);
      addTearDown(c.dispose);

      await expectLater(c.ukurUntukKalibrasi(), throwsA(isA<Object>()));
    });

    test('jam sehat tidak punya halangan', () {
      final c = buatControllerUji();
      addTearDown(c.dispose);

      expect(c.alasanJamTidakBisaUkur, isNull);
    });
  });

  group('Layar pindai', () {
    testWidgets('tombolnya mati dan sebabnya tertulis', (tester) async {
      final c = buatControllerUji(status: _kritis);

      await pumpHalaman(
        tester,
        const PindaiKesehatanPage(izin: IzinBleSelaluBoleh()),
        controller: c,
      );

      expect(find.textContaining('menolak mengukur'), findsOneWidget);
      // "Jam perlu tersambung dulu" akan menyesatkan: jamnya justru tersambung.
      expect(find.textContaining('perlu tersambung dulu'), findsNothing);

      final tombol = tester.widget<ElevatedButton>(
        find.ancestor(
          of: find.text('Mulai Pindai'),
          matching: find.byType(ElevatedButton),
        ),
      );
      expect(tombol.onPressed, isNull);
    });
  });
}
