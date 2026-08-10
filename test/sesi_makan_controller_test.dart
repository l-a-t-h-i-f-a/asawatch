// Test untuk SesiMakanController (§12.6): satu sesi aktif, dedup sampel,
// jadwal dari t0 absolut, dan jumlah notifikasi yang tetap sedikit.

import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/controllers/sesi_makan_controller.dart';
import 'package:asawatch/models/contoh_sesi.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/services/ble_service.dart';
import 'package:asawatch/services/nutrisi_service.dart';

SesiMakanController buatController({
  FakeBleService? ble,
  List<SesiMakan> riwayatAwal = const [],
}) {
  return SesiMakanController(
    ble: ble ?? FakeBleService(percepatan: 3600, otomatisSelesaiMakan: null),
    nutrisi: const FakeNutrisiService(jeda: Duration.zero),
    riwayatAwal: riwayatAwal,
  );
}

/// Menekan tombol "Selesai Makan" di jam palsu lalu menunggu pesannya sampai
/// ke controller. App tidak punya jalan lain menetapkan t0 (§6).
Future<bool> tekanTombolJam(SesiMakanController c, {DateTime? waktu}) async {
  final ditekan = (c.ble as FakeBleService).tekanSelesaiMakan(waktu: waktu);
  await Future<void>.delayed(Duration.zero);
  return ditekan;
}

void main() {
  group('Siklus sesi', () {
    test('shutter membuat draft dengan empat titik yang masih menunggu', () async {
      final c = buatController();
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath);

      expect(c.sesiAktif, isNotNull);
      expect(c.sesiAktif!.status, StatusSesi.draft);
      expect(c.sesiAktif!.t0, isNull);
      expect(c.sesiAktif!.sampel.length, 4);
      expect(
        c.sesiAktif!.sampel.every((s) => s.status == StatusSampel.menunggu),
        isTrue,
      );
    });

    test('hanya satu sesi aktif pada satu waktu', () async {
      final c = buatController();
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath);

      expect(() => c.mulaiDraft(contohFotoPath), throwsStateError);
    });

    test('tombol di jam mengisi t0 dan menempatkan baseline sebelum t0', () async {
      final c = buatController();
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath);
      await tekanTombolJam(c);

      final sesi = c.sesiAktif!;
      expect(sesi.t0, isNotNull);
      expect(sesi.status, StatusSesi.berjalan);
      expect(sesi.sampel[0].detikRelatifT0, lessThanOrEqualTo(0));
      expect(sesi.sampel[2].detikRelatifT0, 3600);
      expect(sesi.sampel[3].detikRelatifT0, 7200);
    });

    test('t0 memakai waktu jam, bukan waktu HP saat pesannya sampai', () async {
      // Tombol bisa ditekan saat HP tidak tersambung; pesannya baru sampai
      // belakangan. Menghitung ulang t0 di HP akan menggeser seluruh jadwal.
      final c = buatController();
      addTearDown(c.dispose);

      final ditekanPukul = DateTime.now().subtract(const Duration(hours: 3));
      await c.mulaiDraft(contohFotoPath);
      await tekanTombolJam(c, waktu: ditekanPukul);

      expect(c.sesiAktif!.t0, ditekanPukul);
    });

    test('jam terputus: sesi menunggu perangkat dan tombolnya belum menyala', () async {
      final ble = FakeBleService(
        percepatan: 3600,
        otomatisSelesaiMakan: null,
        status: const StatusPerangkat(tersambung: false, sampelTertunda: 1),
      );
      final c = buatController(ble: ble);
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath);
      expect(c.sesiAktif!.status, StatusSesi.menungguPerangkat);

      // Jam yang belum disiapkan menolak tombolnya, jadi t0 tidak pernah lahir
      // dari sesi tanpa foto.
      expect(await tekanTombolJam(c), isFalse);
      expect(c.sesiAktif!.t0, isNull);
    });

    test('tombol jam tanpa foto tidak memulai sesi apa pun', () async {
      final c = buatController();
      addTearDown(c.dispose);

      expect(await tekanTombolJam(c), isFalse);
      expect(c.sesiAktif, isNull);
    });

    // Sesi yang berjalan sampai selesai diuji di sesi_pages_test.dart, di mana
    // waktu bisa dipompa lewat WidgetTester.

    test('sampel yang sama datang dua kali hanya dihitung sekali', () async {
      final ble = _BleTerkendali();
      final c = buatController(ble: ble);
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath);
      await tekanTombolJam(c);

      const sampel = Sampel(
        index: 2,
        detikRelatifT0: 3600,
        status: StatusSampel.terisi,
        gulaDarah: 141,
      );
      final id = c.sesiAktif!.id;

      ble.kirim(id, sampel);
      await Future<void>.delayed(Duration.zero);
      final setelahSekali = c.sesiAktif!.sampel[2].gulaDarah;

      // Pengiriman jam at-least-once: sampel yang sama bisa datang lagi dengan
      // nilai berbeda, dan yang kedua harus diabaikan.
      ble.kirim(
        id,
        const Sampel(
          index: 2,
          detikRelatifT0: 3600,
          status: StatusSampel.terisi,
          gulaDarah: 999,
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(setelahSekali, 141);
      expect(c.sesiAktif!.sampel[2].gulaDarah, 141);
    });

    test('membatalkan sesi tidak menyisakan jejak di riwayat', () async {
      final c = buatController();
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath);
      await tekanTombolJam(c);
      await c.batalkan();

      expect(c.sesiAktif, isNull);
      expect(c.riwayat, isEmpty);
      expect(c.hasilBelumDibaca, isNull);
    });

    test('akhiri lebih awal menandai sampel sisa sebagai terlewat', () async {
      final c = buatController();
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath);
      await tekanTombolJam(c);
      await c.akhiriLebihAwal();

      final sesi = c.sesiTerakhir!;
      expect(c.sesiAktif, isNull);
      expect(sesi.status, StatusSesi.tidakLengkap);
      expect(sesi.sampel[2].status, StatusSampel.terlewat);
      expect(sesi.sampel[3].status, StatusSampel.terlewat);
      // Kartu hasilnya menunggu dibuka user (§4.1 wajah C).
      expect(c.hasilBelumDibaca, isNotNull);

      c.tandaiHasilDibaca();
      expect(c.hasilBelumDibaca, isNull);
    });

    test('notifikasi tetap sedikit selama satu sesi', () async {
      final c = buatController();
      addTearDown(c.dispose);

      var jumlah = 0;
      c.addListener(() => jumlah++);

      await c.mulaiDraft(contohFotoPath);
      await tekanTombolJam(c);
      await c.akhiriLebihAwal();

      // Hitung mundur ditangani lokal, jadi controller tidak boleh berisik.
      expect(jumlah, lessThanOrEqualTo(6));
    });
  });

  group('Ringkasan untuk Beranda', () {
    test('total nutrisi hari ini hanya menjumlah sesi hari ini', () {
      final riwayat = contohRiwayatSesi();
      final c = buatController(riwayatAwal: riwayat);
      addTearDown(c.dispose);

      final hariIni = c.sesiHariIni();
      final total = c.totalNutrisiHariIni();

      // Menu tiap sesi berbeda, jadi totalnya dijumlah dari sesinya sendiri.
      double jumlah(double Function(Nutrisi n) ambil) => hariIni
          .map((s) => ambil(s.hasil!.total))
          .reduce((a, b) => a + b);

      expect(hariIni.length, lessThan(riwayat.length));
      expect(total.kalori, jumlah((n) => n.kalori));
      expect(total.karbohidrat, jumlah((n) => n.karbohidrat));
    });

    test('sesi yang nutrisinya belum ada dilewati, bukan ditaksir', () async {
      final c = buatController();
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath); // hasil masih null pada tick ini
      expect(c.totalNutrisiHariIni().kalori, 0);
    });

    test('puncak terakhir urut lama ke baru untuk sparkline', () {
      final c = buatController(riwayatAwal: contohRiwayatSesi());
      addTearDown(c.dispose);

      final puncak = c.puncakTerakhir(jumlah: 3);

      expect(puncak.length, 3);
      // riwayat[0] adalah yang terbaru, jadi ia harus jatuh di ujung kanan.
      expect(puncak.last, c.riwayat.first.puncakGulaDarah!.toDouble());
    });

    test('sesi terakhir adalah entri riwayat terbaru', () {
      final c = buatController(riwayatAwal: contohRiwayatSesi());
      addTearDown(c.dispose);

      expect(c.sesiTerakhir!.id, 'riwayat-0');
    });
  });
}

/// BLE palsu tanpa jadwal otomatis, supaya test bisa mengirim sampel persis
/// kapan dan berapa kali ia mau.
class _BleTerkendali extends FakeBleService {
  _BleTerkendali() : super(percepatan: 3600, lewatkan: const {0, 1, 2, 3});

  void kirim(String sesiId, Sampel sampel) => kirimSampel(sesiId, sampel);
}
