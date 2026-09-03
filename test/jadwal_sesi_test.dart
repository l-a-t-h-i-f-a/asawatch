// Jadwal titik ukur sebagai data — docs/jadwal-titik-ukur.md.
//
// Sampai protokol v1.2 jadwal ini hidup di firmware dan tidak bisa diuji dari
// sini sama sekali. Sejak v1.3 memindahkannya ke aplikasi (§9, §12), ia menjadi
// salah satu bagian Tahap B yang bisa diperiksa tanpa radio — dan berkas ini
// yang memeriksanya.

import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/controllers/sesi_makan_controller.dart';
import 'package:asawatch/models/jadwal_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/services/ble_service.dart';
import 'package:asawatch/services/nutrisi_service.dart';

import 'helpers.dart';

void main() {
  group('Jadwal normal', () {
    test('empat titik, tidak berubah dari sebelum v1.3', () {
      expect(jadwalNormal.jumlahTitik, 4);
      expect(jadwalNormal.titik.map((t) => t.detikNominal), [0, 0, 3600, 7200]);
      expect(jadwalNormal.detikTitikTerakhir, 7200);
      expect(jadwalNormal.tenggatSetelahAkhir, const Duration(minutes: 30));
    });

    // Bukan sekadar mencatat angka: asimetrinya yang jadi aturan. Yang sebelum
    // jendela ditahan karena titiknya belum lewat dan masih bisa diukur ulang;
    // yang sesudahnya diterima karena tidak ada penggantinya.
    test('jendela +1 jam sempit ke belakang, +2 jam longgar', () {
      final satuJam = jadwalNormal[2];
      expect(satuJam.jendelaAwal, 3300); // 55 mnt
      expect(satuJam.jendelaAkhir, 4200); // 70 mnt
      expect(satuJam.jendelaAkhir! - satuJam.detikNominal, 600);

      final duaJam = jadwalNormal[3];
      expect(duaJam.jendelaAkhir! - duaJam.detikNominal, 1800);
    });

    // Baseline dan t0 dipicu peristiwa (shutter, tombol), bukan jadwal, jadi
    // keduanya tidak pernah "belum waktunya" maupun "telat".
    test('baseline dan t0 tidak berjendela', () {
      for (final i in [0, 1]) {
        expect(jadwalNormal[i].berjendela, isFalse);
        expect(jadwalNormal[i].belumWaktunya(-99999), isFalse);
        expect(jadwalNormal[i].telat(99999), isFalse);
      }
    });
  });

  group('Jendela toleransi', () {
    final satuJam = jadwalNormal[2];

    test('sebelum jendela ditahan, sesudahnya ditandai telat', () {
      expect(satuJam.belumWaktunya(2700), isTrue); // 45 mnt
      expect(satuJam.telat(2700), isFalse);

      expect(satuJam.belumWaktunya(3600), isFalse);
      expect(satuJam.telat(3600), isFalse);

      expect(satuJam.belumWaktunya(5100), isFalse); // 85 mnt
      expect(satuJam.telat(5100), isTrue);
    });

    test('tepat di batas jendela masih di dalam', () {
      expect(satuJam.belumWaktunya(3300), isFalse);
      expect(satuJam.telat(4200), isFalse);
      expect(satuJam.belumWaktunya(3299), isTrue);
      expect(satuJam.telat(4201), isTrue);
    });
  });

  group('Normalisasi detikRelatifT0', () {
    final satuJam = jadwalNormal[2];

    // Alasan lamanya masih berlaku pada skala detik: label menjanjikan
    // "+1 jam", bukan "+1 jam 40 detik".
    test('selisih berskala detik dinormalkan ke nominal', () {
      expect(satuJam.normalkan(3640), 3600);
      expect(satuJam.normalkan(3540), 3600);
    });

    // Dan berbalik pada skala menit: menyembunyikan keterlambatan 25 menit
    // bukan merapikan label, itu memalsukan sumbu x.
    test('selisih berskala menit disimpan apa adanya', () {
      expect(satuJam.normalkan(5100), 5100);
      expect(satuJam.normalkan(3721), 3721);
    });
  });

  group('Jadwal uji', () {
    // Yang dijaga di sini bukan angkanya melainkan **asalnya**: jadwal uji
    // diturunkan dari jadwal sungguhan, bukan ditulis sebagai daftar kedua.
    // Dua daftar yang harus dijaga sebanding akan berselisih, dan selisihnya
    // muncul justru di jalur yang paling jarang dijalankan.
    test('setiap angka jadwal normal dibagi 60', () {
      for (var i = 0; i < jadwalNormal.jumlahTitik; i++) {
        final n = jadwalNormal.titik[i];
        final u = jadwalUji.titik[i];
        expect(u.index, n.index);
        expect(u.detikNominal, n.detikNominal ~/ faktorJadwalUji);
        expect(
          u.jendelaAwal,
          n.jendelaAwal == null ? null : n.jendelaAwal! ~/ 60,
        );
        expect(
          u.jendelaAkhir,
          n.jendelaAkhir == null ? null : n.jendelaAkhir! ~/ 60,
        );
      }
      expect(jadwalUji.tenggatSetelahAkhir, const Duration(seconds: 30));
      expect(jadwalUji.uji, isTrue);
      expect(jadwalNormal.uji, isFalse);
    });

    test('sesi penuh selesai dalam dua menit', () {
      expect(jadwalUji.detikTitikTerakhir, 120);
    });

    // Label menyebut **makna** titiknya, bukan durasinya di mode itu. Penguji
    // yang melihat "+1 jam" pada sesi dua menit membaca yang benar: titik yang
    // sedang diuji adalah titik +1 jam.
    test('label tidak ikut dikecilkan', () {
      expect(jadwalUji.label, jadwalNormal.label);
      expect(labelTitikSampel, [
        'Baseline',
        'Selesai makan',
        '+1 jam',
        '+2 jam',
      ]);
    });
  });

  group('Controller memakai jadwal yang disuntikkan', () {
    test(
      'sesi baru mengambil titiknya dari jadwal, bukan dari literal',
      () async {
        final c = buatControllerUji(jadwal: jadwalUji);
        addTearDown(c.dispose);

        await c.mulaiDraft('x.jpg');

        expect(c.sesiAktif!.sampel.map((s) => s.detikRelatifT0), [
          0,
          0,
          60,
          120,
        ]);
        expect(c.tenggatSampelTerakhir, const Duration(seconds: 30));

        await c.batalkan();
      },
    );

    // Lewat konstruktor sungguhan, bukan `buatControllerUji`: helper itu
    // memampatkan jadwal agar cocok dengan `percepatan` jam palsunya, jadi ia
    // tidak bisa membuktikan apa pun tentang bawaan controller.
    test('bawaannya jadwal sungguhan', () async {
      final c = SesiMakanController(
        ble: FakeBleService(otomatisSelesaiMakan: null),
        nutrisi: const FakeNutrisiService(jeda: Duration.zero),
      );
      addTearDown(c.dispose);

      await c.mulaiDraft('x.jpg');

      expect(c.sesiAktif!.sampel.map((s) => s.detikRelatifT0), [
        0,
        0,
        3600,
        7200,
      ]);

      await c.batalkan();
    });
  });
}
