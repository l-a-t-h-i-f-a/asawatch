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

    test('ARM_SESI dikirim sebelum permintaan baseline', () async {
      // Jam hanya melayani UKUR index 0 dalam status ARMED (§9). Permintaan
      // baseline yang mendahului ARM ditolak diam-diam, dan akibatnya baru
      // terlihat dua jam kemudian: ketiga titik lain masuk dengan benar, lalu
      // sesinya menggantung menunggu baseline yang tidak akan pernah datang.
      final ble = _BleUrutanPerintah();
      final c = buatController(ble: ble);
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath);
      await Future<void>.delayed(Duration.zero);

      expect(ble.urutan, ['arm', 'ukur-0']);
    });

    test('baseline yang ditolak jam ditandai terlewat seketika', () async {
      // Jam yang terputus menolak `UKUR` (§9), dan pengukuran itu tidak akan
      // pernah datang. Menampilkannya sebagai "menunggu data" selama dua jam
      // menjanjikan sesuatu yang sudah pasti tidak ada — dan menahan sesi tetap
      // berjalan setengah jam setelah titik terakhir.
      final ble = FakeBleService(
        percepatan: 3600,
        otomatisSelesaiMakan: null,
        status: const StatusPerangkat(tersambung: false),
      );
      final c = buatController(ble: ble);
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath);
      await Future<void>.delayed(Duration.zero);

      expect(c.sesiAktif!.sampel[0].status, StatusSampel.terlewat);
    });

    test('baseline yang diterima jam tetap menunggu datanya', () async {
      // Penjaga untuk perbaikan di atas: "ditolak" dan "belum datang" adalah dua
      // hal berbeda, dan menandai keduanya terlewat akan membuang baseline yang
      // sebenarnya sedang diukur.
      final c = buatController();
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath);
      await Future<void>.delayed(Duration.zero);

      expect(c.sesiAktif!.sampel[0].status, StatusSampel.menunggu);

      await c.batalkan();
    });

    test('notifikasi status berulang tidak memicu ARM_SESI berulang', () async {
      // Jam sungguhan mengirim notifikasi Status setiap kali keadaannya
      // berubah — termasuk saat ia berpindah ke ARMED karena ARM_SESI yang baru
      // saja dikirim aplikasi. Menyiapkan jam pada setiap status berarti
      // status → ARM_SESI → status → ARM_SESI → … selamanya, dengan radio
      // menulis terus-menerus. Itu benar-benar terjadi di perangkat.
      final ble = _BleHitungArm();
      final c = buatController(ble: ble);
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath);
      await Future<void>.delayed(Duration.zero);
      expect(ble.jumlahArm, 1);

      // Sepuluh notifikasi status berturut-turut, seperti jam yang sibuk.
      for (var i = 0; i < 10; i++) {
        ble.perbaruiStatus(
          StatusPerangkat(
            tersambung: true,
            baterai: 70 - i,
            namaPerangkat: 'AsaWatch X1',
          ),
        );
        await Future<void>.delayed(Duration.zero);
      }

      expect(ble.jumlahArm, 1);
    });

    test('jam yang tersambung kembali disiapkan ulang', () async {
      // Penjaga di atas tidak boleh berubah menjadi "hanya sekali seumur sesi":
      // jam yang sempat mati atau ARM-nya kedaluwarsa (4 jam, §5.1) harus
      // di-ARM lagi begitu tersambung kembali.
      final ble = _BleHitungArm();
      final c = buatController(ble: ble);
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath);
      await Future<void>.delayed(Duration.zero);
      expect(ble.jumlahArm, 1);

      ble.perbaruiStatus(
        const StatusPerangkat(tersambung: false, namaPerangkat: 'AsaWatch X1'),
      );
      await Future<void>.delayed(Duration.zero);
      ble.perbaruiStatus(
        const StatusPerangkat(tersambung: true, namaPerangkat: 'AsaWatch X1'),
      );
      await Future<void>.delayed(Duration.zero);

      expect(ble.jumlahArm, 2);
    });

    test('t0 memakai waktu jam, bukan waktu HP saat pesannya sampai', () async {
      // Tombol bisa ditekan saat HP tidak tersambung; pesannya baru sampai
      // belakangan. Menghitung ulang t0 di HP akan menggeser seluruh jadwal.
      final c = buatController();
      addTearDown(c.dispose);

      final ditekanPukul = DateTime.now().subtract(const Duration(hours: 1));
      await c.mulaiDraft(contohFotoPath);
      await tekanTombolJam(c, waktu: ditekanPukul);

      expect(c.sesiAktif!.t0, ditekanPukul);
    });

    test('t0 yang sudah lewat tenggat langsung ditutup tidak lengkap', () async {
      // Jam mati, sensornya gagal, atau tombolnya ditekan lalu jamnya tidak
      // pernah tersambung lagi: sampelnya tidak akan datang, dan tidak ada
      // seorang pun yang akan menutup sesinya (§4.3 rencana produksi).
      final c = buatController();
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath);
      await tekanTombolJam(
        c,
        waktu: DateTime.now().subtract(const Duration(hours: 5)),
      );
      await Future<void>.delayed(Duration.zero); // tenggat lewat microtask

      expect(c.sesiAktif, isNull);
      final sesi = c.sesiTerakhir!;
      expect(sesi.status, StatusSesi.tidakLengkap);
      expect(sesi.sampel[3].status, StatusSampel.terlewat);
    });

    test('sesi berwaktu tidak pasti tidak ikut hitungan berbasis kalender',
        () async {
      // Protokol §4.3: satu boot penuh tanpa pernah tersambung. Datanya nyata,
      // jamnya tidak — jadi ia tidak boleh punya WaktuMakan, tidak masuk
      // "hari ini", dan tidak ikut tren.
      final c = buatController();
      addTearDown(c.dispose);

      await c.mulaiDraft(contohFotoPath);
      (c.ble as FakeBleService).tekanSelesaiMakan(waktuTidakPasti: true);
      await Future<void>.delayed(Duration.zero);

      final sesi = c.sesiAktif!;
      expect(sesi.waktuTidakPasti, isTrue);
      expect(sesi.waktuMakan, isNull);
      expect(sesi.labelWaktuMakan, 'Waktu tidak pasti');
      expect(c.sesiHariIni(), isEmpty);

      await c.akhiriLebihAwal();
      expect(c.sesiTerakhir!.waktuTidakPasti, isTrue);
      expect(c.sesiHariIni(), isEmpty);
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

/// Jam palsu yang menghitung berapa kali tombolnya disiapkan.
///
/// Menghitung `ARM_SESI` adalah satu-satunya cara menangkap umpan balik
/// status → ARM → status dari sisi test: gejalanya di perangkat adalah radio
/// yang menulis tanpa henti, dan itu tidak punya wujud lain di dalam proses.
class _BleHitungArm extends FakeBleService {
  _BleHitungArm() : super(percepatan: 3600, otomatisSelesaiMakan: null);

  /// Hanya yang **berhasil** dihitung. Penyiapan saat jam terputus ditolak
  /// sebelum menyentuh radio (`siapkanSesi` mengembalikan false lebih dulu),
  /// jadi ia bukan bagian dari lalu lintas yang sedang dijaga di sini — dan
  /// menghitungnya akan membuat test ini mengunci detail yang tidak penting.
  int jumlahArm = 0;

  @override
  Future<bool> siapkanSesi(String sesiId) async {
    final berhasil = await super.siapkanSesi(sesiId);
    if (berhasil) jumlahArm++;
    return berhasil;
  }
}

/// Jam palsu yang mencatat urutan perintah yang diterimanya.
///
/// Urutan adalah satu-satunya hal yang salah pada bug ini — kedua perintahnya
/// terkirim, hanya saja yang satu terlalu cepat. Test yang cuma memeriksa
/// "keduanya dipanggil" akan tetap hijau sementara baseline tetap hilang.
class _BleUrutanPerintah extends FakeBleService {
  _BleUrutanPerintah() : super(percepatan: 3600, otomatisSelesaiMakan: null);

  final List<String> urutan = [];

  @override
  Future<bool> siapkanSesi(String sesiId) {
    urutan.add('arm');
    return super.siapkanSesi(sesiId);
  }

  @override
  Future<bool> mintaUkur(String sesiId, int index) {
    urutan.add('ukur-$index');
    return super.mintaUkur(sesiId, index);
  }
}
