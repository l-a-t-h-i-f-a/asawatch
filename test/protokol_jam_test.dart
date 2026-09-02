// Codec protokol jam — docs/protokol-jam.md.
//
// Ini satu-satunya bagian Tahap B yang bisa diuji tuntas tanpa hardware, jadi
// pengujiannya dibuat menyeluruh: setiap offset di tabel §3/§5.2/§5.4/§5.5
// benar-benar dibaca, bukan hanya "tidak melempar".

import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/models/anchor_waktu.dart';
import 'package:asawatch/services/protokol_jam.dart';

/// Paket Info 20 byte (§3) dengan nilai bawaan yang sah.
Uint8List paketInfo({
  int versiMayor = 1,
  int versiMinor = 0,
  List<int> serial = const [0xDE, 0xAD, 0xBE, 0xEF, 0x00, 0x01],
  int firmwareBuild = 42,
  int kapasitasBuffer = 64,
  int kemampuan = 0x0F,
  int bootId = 7,
  int uptimeS = 12345,
  bool punyaAnchor = true,
}) {
  final d = Uint8List(20);
  final b = ByteData.view(d.buffer);
  b.setUint8(0, versiMayor);
  b.setUint8(1, versiMinor);
  d.setRange(2, 8, serial);
  b.setUint16(8, firmwareBuild, Endian.little);
  b.setUint8(10, kapasitasBuffer);
  b.setUint8(11, kemampuan);
  b.setUint16(12, bootId, Endian.little);
  b.setUint32(14, uptimeS, Endian.little);
  b.setUint8(18, punyaAnchor ? 0x01 : 0x00);
  return d;
}

/// Paket Sampel 31 byte (§5.2).
Uint8List paketSampel({
  int seq = 3,
  String sesiId = '00112233-4455-6677-8899-aabbccddeeff',
  int index = 2,
  int flag = 0,
  int bootId = 7,
  int uptimeS = 20000,
  int gulaDarah = 142,
  int detakJantung = 88,
  int sistolik = 118,
  int diastolik = 76,
  int spo2 = 97,
}) {
  final d = Uint8List(31);
  final b = ByteData.view(d.buffer);
  b.setUint8(0, seq);
  d.setRange(1, 17, uuidKeBiner(sesiId));
  b.setUint8(17, index);
  b.setUint8(18, flag);
  b.setUint16(19, bootId, Endian.little);
  b.setUint32(21, uptimeS, Endian.little);
  b.setUint16(25, gulaDarah, Endian.little);
  b.setUint8(27, detakJantung);
  b.setUint8(28, sistolik);
  b.setUint8(29, diastolik);
  b.setUint8(30, spo2);
  return d;
}

/// Paket Peristiwa 26 byte (§5.4).
Uint8List paketPeristiwa({
  int seq = 9,
  int jenis = 0x01,
  String? sesiId = '00112233-4455-6677-8899-aabbccddeeff',
  int bootId = 7,
  int uptimeS = 18000,
  int flag = 0,
  int payload = 0,
}) {
  final d = Uint8List(26);
  final b = ByteData.view(d.buffer);
  b.setUint8(0, seq);
  b.setUint8(1, jenis);
  if (sesiId != null) d.setRange(2, 18, uuidKeBiner(sesiId));
  b.setUint16(18, bootId, Endian.little);
  b.setUint32(20, uptimeS, Endian.little);
  b.setUint8(24, flag);
  b.setUint8(25, payload);
  return d;
}

/// Paket Status — 8 byte (§5.5), atau 10 sejak firmware v1.4 bila [persen]
/// atau [sisaDetik] diisi.
Uint8List paketStatus({
  int statusSesi = 2,
  int sampelTertunda = 5,
  int baterai = 68,
  int flag = 0x0A,
  int uptimeS = 999,
  int? persen,
  int? sisaDetik,
}) {
  final panjang = (persen == null && sisaDetik == null) ? 8 : 10;
  final d = Uint8List(panjang);
  final b = ByteData.view(d.buffer);
  b.setUint8(0, statusSesi);
  b.setUint8(1, sampelTertunda);
  b.setUint8(2, baterai);
  b.setUint8(3, flag);
  b.setUint32(4, uptimeS, Endian.little);
  if (panjang == 10) {
    b.setUint8(8, persen ?? 0);
    b.setUint8(9, sisaDetik ?? 0);
  }
  return d;
}

void main() {
  group('Info & handshake (§3)', () {
    test('membaca setiap field pada offsetnya', () {
      final info = bacaInfo(paketInfo());

      expect(info.versiMayor, 1);
      expect(info.versiMinor, 0);
      expect(info.serial, 'deadbeef0001');
      expect(info.firmwareBuild, 42);
      expect(info.kapasitasBuffer, 64);
      expect(info.bootId, 7);
      expect(info.uptimeS, 12345);
      expect(info.punyaAnchor, isTrue);
    });

    test('kemampuan adalah bitfield, bukan hiasan', () {
      final semua = bacaInfo(paketInfo(kemampuan: 0x0F)).kemampuan;
      expect(semua.gulaDarah, isTrue);
      expect(semua.tekananDarah, isTrue);
      expect(semua.spo2, isTrue);
      expect(semua.ota, isTrue);

      // Jam tanpa SpO2 dan tanpa OTA: UI harus menyembunyikan metriknya, bukan
      // menampilkan "—" seolah pengukurannya gagal.
      final sebagian = bacaInfo(paketInfo(kemampuan: 0x03)).kemampuan;
      expect(sebagian.gulaDarah, isTrue);
      expect(sebagian.tekananDarah, isTrue);
      expect(sebagian.spo2, isFalse);
      expect(sebagian.ota, isFalse);
    });

    test('versi mayor lebih baru menolak sambungan dengan pesan pengguna', () {
      final info = bacaInfo(paketInfo(versiMayor: 2));
      expect(
        () => info.periksaVersi(),
        throwsA(
          isA<GalatVersiJam>().having(
            (e) => e.pesanPengguna,
            'pesan',
            'Jam perlu aplikasi versi lebih baru.',
          ),
        ),
      );
    });

    test('versi mayor lebih tua menyuruh memperbarui firmware', () {
      final info = bacaInfo(paketInfo(versiMayor: 0));
      expect(
        () => info.periksaVersi(),
        throwsA(
          isA<GalatVersiJam>().having(
            (e) => e.pesanPengguna,
            'pesan',
            'Firmware jam perlu diperbarui.',
          ),
        ),
      );
    });

    test('versi minor berbeda tetap lanjut', () {
      expect(() => bacaInfo(paketInfo(versiMinor: 9)).periksaVersi(), returnsNormally);
    });

    test('byte tambahan dari versi minor lebih muda diabaikan, bukan ditolak', () {
      final panjang = Uint8List.fromList([...paketInfo(), 0xAA, 0xBB, 0xCC]);
      expect(bacaInfo(panjang).bootId, 7);
    });

    test('paket kependekan melempar GalatProtokol', () {
      expect(
        () => bacaInfo(paketInfo().sublist(0, 19)),
        throwsA(isA<GalatProtokol>()),
      );
    });
  });

  group('Sampel (§5.2)', () {
    test('membaca setiap field pada offsetnya', () {
      final s = bacaSampel(paketSampel());

      expect(s.seq, 3);
      expect(s.sesiId, '00112233-4455-6677-8899-aabbccddeeff');
      expect(s.index, 2);
      expect(s.bootId, 7);
      expect(s.uptimeS, 20000);
      expect(s.gulaDarah, 142);
      expect(s.detakJantung, 88);
      expect(s.sistolik, 118);
      expect(s.diastolik, 76);
      expect(s.spo2, 97);
      expect(s.dariBuffer, isFalse);
      expect(s.waktuTidakPasti, isFalse);
    });

    test('sentinel 0 menjadi null sebelum meninggalkan layer BLE', () {
      final s = bacaSampel(
        paketSampel(
          gulaDarah: 0,
          detakJantung: 0,
          sistolik: 0,
          diastolik: 0,
          spo2: 0,
        ),
      );

      expect(s.gulaDarah, isNull);
      expect(s.detakJantung, isNull);
      expect(s.sistolik, isNull);
      expect(s.diastolik, isNull);
      expect(s.spo2, isNull);
    });

    test('metrik yang gagal tidak menjatuhkan metrik lain di paket yang sama', () {
      final s = bacaSampel(paketSampel(sistolik: 0, diastolik: 0));
      expect(s.sistolik, isNull);
      expect(s.gulaDarah, 142);
    });

    test('flag bit0 dariBuffer dan bit1 waktu_tidak_pasti', () {
      expect(bacaSampel(paketSampel(flag: 0x01)).dariBuffer, isTrue);
      expect(bacaSampel(paketSampel(flag: 0x01)).waktuTidakPasti, isFalse);
      expect(bacaSampel(paketSampel(flag: 0x02)).waktuTidakPasti, isTrue);

      final keduanya = bacaSampel(paketSampel(flag: 0x03));
      expect(keduanya.dariBuffer, isTrue);
      expect(keduanya.waktuTidakPasti, isTrue);
    });

    test('gula darah memakai uint16 little-endian penuh', () {
      expect(bacaSampel(paketSampel(gulaDarah: 600)).gulaDarah, 600);
    });

    test('index di luar 0..3 ditolak di sini, bukan di UI', () {
      expect(
        () => bacaSampel(paketSampel(index: 4)),
        throwsA(isA<GalatProtokol>()),
      );
    });
  });

  group('Peristiwa (§5.4)', () {
    test('TOMBOL_SELESAI_MAKAN membawa uptime saat tombol ditekan', () {
      final e = bacaPeristiwa(paketPeristiwa(uptimeS: 18000));

      expect(e.jenis, JenisPeristiwa.tombolSelesaiMakan);
      expect(e.uptimeS, 18000);
      expect(e.sesiId, '00112233-4455-6677-8899-aabbccddeeff');
    });

    test('sesiId nol berarti tidak relevan, bukan sesi bernama nol', () {
      final e = bacaPeristiwa(paketPeristiwa(jenis: 0x08, sesiId: null));
      expect(e.jenis, JenisPeristiwa.boot);
      expect(e.sesiId, isNull);
    });

    test('ACK membawa opcode asalnya', () {
      final e = bacaPeristiwa(
        paketPeristiwa(jenis: 0x05, payload: Opcode.armSesi),
      );
      expect(e.jenis, JenisPeristiwa.ack);
      expect(e.opcodeDiack, Opcode.armSesi);
    });

    test('NAK membawa kode error beserta aturan retry-nya (§7)', () {
      final sedangMengukur = bacaPeristiwa(
        paketPeristiwa(jenis: 0x06, payload: 0x05),
      );
      expect(sedangMengukur.kodeGalat, KodeGalatJam.sedangMengukur);
      expect(sedangMengukur.kodeGalat!.bolehRetry, isTrue);
      expect(sedangMengukur.kodeGalat!.jedaRetry, const Duration(seconds: 5));

      final bateraiRendah = bacaPeristiwa(
        paketPeristiwa(jenis: 0x06, payload: 0x06),
      );
      expect(bateraiRendah.kodeGalat, KodeGalatJam.bateraiRendah);
      expect(bateraiRendah.kodeGalat!.bolehRetry, isFalse);
    });

    test('kode NAK yang belum dikenal tidak menjatuhkan pembacaan', () {
      final e = bacaPeristiwa(paketPeristiwa(jenis: 0x06, payload: 0x7F));
      expect(e.kodeGalat, isNull);
    });

    test('jenis peristiwa tidak dikenal melempar GalatProtokol', () {
      expect(
        () => bacaPeristiwa(paketPeristiwa(jenis: 0x77)),
        throwsA(isA<GalatProtokol>()),
      );
    });
  });

  group('Status (§5.5)', () {
    test('membaca status sesi, buffer, baterai, dan flag', () {
      final s = bacaStatus(paketStatus());

      expect(s.statusSesi, StatusSesiJam.running);
      expect(s.sampelTertunda, 5);
      expect(s.baterai, 68);
      expect(s.sedangMengukur, isFalse);
      expect(s.kalibrasiTersimpan, isTrue);
      expect(s.bateraiKritis, isFalse);
      expect(s.punyaAnchor, isTrue);
      expect(s.uptimeS, 999);
    });

    test('baterai kritis terbaca dari bit2', () {
      expect(bacaStatus(paketStatus(flag: 0x04)).bateraiKritis, isTrue);
    });

    test('kemajuan pengukuran terbaca dari byte 8 dan 9 (v1.4)', () {
      final s = bacaStatus(
        paketStatus(flag: 0x01, persen: 45, sisaDetik: 20),
      );

      expect(s.sedangMengukur, isTrue);
      expect(s.ukurPersen, 45);
      expect(s.ukurSisaDetik, 20);
      expect(s.punyaKemajuan, isTrue);
    });

    test('paket 8 byte firmware lama: kemajuan null, bukan nol', () {
      // Bedanya bukan kosmetik. null berarti jam ini tidak pernah mengabarkan
      // kemajuan sama sekali, sehingga aplikasi tidak boleh memasang penjaga
      // denyut yang akan menggagalkan setiap pengukurannya setelah 8 detik;
      // 0 berarti pengukuran yang baru saja dimulai.
      final s = bacaStatus(paketStatus(flag: 0x01));

      expect(s.sedangMengukur, isTrue);
      expect(s.ukurPersen, isNull);
      expect(s.ukurSisaDetik, isNull);
      expect(s.punyaKemajuan, isFalse);
    });

    test('byte berlebih di luar v1.4 diabaikan, bukan ditolak', () {
      final panjang = [...paketStatus(persen: 10, sisaDetik: 3), 0xFF, 0xFF];
      expect(bacaStatus(panjang).ukurPersen, 10);
    });

    test('status sesi tidak dikenal melempar, bukan diam-diam jadi idle', () {
      expect(
        () => bacaStatus(paketStatus(statusSesi: 5)),
        throwsA(isA<GalatProtokol>()),
      );
    });
  });

  group('Perintah kontrol (§5.1)', () {
    const sesiId = '00112233-4455-6677-8899-aabbccddeeff';

    test('ANCHOR_WAKTU: epoch detik LE + boot_id', () {
      final epoch = DateTime.fromMillisecondsSinceEpoch(1700000000000, isUtc: true);
      final data = tulisAnchorWaktu(epoch: epoch, bootId: 258);

      expect(data.length, 7);
      expect(data[0], Opcode.anchorWaktu);
      final b = ByteData.view(Uint8List.fromList(data).buffer);
      expect(b.getUint32(1, Endian.little), 1700000000);
      expect(b.getUint16(5, Endian.little), 258);
    });

    test('ARM_SESI membawa 16 byte sesiId', () {
      final data = tulisArmSesi(sesiId);
      expect(data.length, 17);
      expect(data[0], Opcode.armSesi);
      expect(binerKeUuid(data.sublist(1)), sesiId);
    });

    test('UKUR membawa sesiId yang sama dengan ARM_SESI plus index', () {
      final data = tulisUkur(sesiId, 0);
      expect(data.length, 18);
      expect(data[0], Opcode.ukur);
      expect(binerKeUuid(data.sublist(1, 17)), sesiId);
      expect(data[17], 0);
    });

    // Batasnya 1 byte, bukan 0..3, sejak protokol v1.3 (§12). Jadwal titik ukur
    // kini data sisi aplikasi (docs/jadwal-titik-ukur.md §1), jadi menambah
    // titik tidak boleh tertahan oleh penjaga di codec — dan yang benar-benar
    // menentukan bentuk paketnya cuma lebar bytenya.
    test('UKUR menerima index di luar empat titik hari ini', () {
      expect(tulisUkur(sesiId, 4)[17], 4);
      expect(tulisUkur(sesiId, 255)[17], 255);
    });

    test('UKUR menolak index yang tidak muat dalam 1 byte', () {
      expect(() => tulisUkur(sesiId, 256), throwsA(isA<GalatProtokol>()));
      expect(() => tulisUkur(sesiId, -1), throwsA(isA<GalatProtokol>()));
    });

    group('ARM_TITIK (§5.1, v1.3)', () {
      test('18 byte: opcode, sesiId, index', () {
        final data = tulisArmTitik(sesiId, 2);

        expect(data.length, 18);
        expect(data[0], Opcode.armTitik);
        expect(data[0], 0x0A);
        expect(binerKeUuid(data.sublist(1, 17)), sesiId);
        expect(data[17], 2);
      });

      // Rancangan pertama v1.3 membawa 2B `detik_tunda` di ujung. Dibuang
      // sebelum implementasi: penundaan itu tidak pernah selamat melewati
      // pemutusan daya, dan pemutusan daya adalah keadaan normal di v1.3.
      // Yang dijaga di sini adalah paketnya benar-benar berhenti di byte 17.
      test('tidak membawa penundaan', () {
        expect(tulisArmTitik(sesiId, 3).length, 18);
      });

      test('menolak index yang tidak muat dalam 1 byte', () {
        expect(() => tulisArmTitik(sesiId, 256), throwsA(isA<GalatProtokol>()));
        expect(() => tulisArmTitik(sesiId, -1), throwsA(isA<GalatProtokol>()));
      });

      test('opcode punya nama untuk log', () {
        expect(Opcode.nama(Opcode.armTitik), 'ARM_TITIK');
      });
    });

    test('SET_KALIBRASI mengirim offset int16, termasuk yang negatif', () {
      final data = tulisSetKalibrasi(offsetSistolik: -7, offsetDiastolik: 12);
      final b = ByteData.view(Uint8List.fromList(data).buffer);

      expect(data[0], Opcode.setKalibrasi);
      expect(b.getInt16(1, Endian.little), -7);
      expect(b.getInt16(3, Endian.little), 12);
    });

    test('SINKRON dan ACK_EVENT membawa satu byte seq', () {
      expect(tulisSinkron(200), [Opcode.sinkron, 200]);
      expect(tulisAckEvent(17), [Opcode.ackEvent, 17]);
    });

    test('UKUR_SEKARANG tidak berpayload', () {
      expect(tulisUkurSekarang(), [Opcode.ukurSekarang]);
    });

    test('MULAI_SESI membawa sesiId saja — tanpa satu byte pun waktu', () {
      // Ini bukan sekadar memeriksa panjang. Ketiadaan waktu di paket inilah
      // yang membuat tombol "Selesai Makan" di aplikasi tidak melanggar §4:
      // jam yang membaca pencacahnya sendiri, jadi t0 tetap berada di garis
      // waktu yang sama dengan `uptime_s` tiap sampel (§5.3). Epoch di sini akan
      // membuat `+1 jam` dan `+2 jam` dijadwalkan dari titik yang tidak ada di
      // garis waktu jam.
      const id = '3f2b7c10-9d4e-4a15-8c33-0b6e1f5a2d47';
      final data = tulisMulaiSesi(id);

      expect(data.length, 17);
      expect(data[0], Opcode.mulaiSesi);
      expect(binerKeUuid(data.sublist(1)), id);
    });

    test('MULAI_SESI menolak id sesi pra-Tahap-B', () {
      expect(
        () => tulisMulaiSesi('sesi-1712345678901'),
        throwsA(isA<GalatProtokol>()),
      );
    });
  });

  group('Id sesi', () {
    test('buatIdSesi menghasilkan UUID v4 yang bolak-balik utuh ke 16 byte', () {
      final id = buatIdSesi();

      expect(id.length, 36);
      expect(id[14], '4'); // versi
      expect('89ab'.contains(id[19]), isTrue); // varian
      expect(binerKeUuid(uuidKeBiner(id)), id);
    });

    test('dua id berturut-turut tidak pernah sama', () {
      final id = {for (var i = 0; i < 200; i++) buatIdSesi()};
      expect(id.length, 200);
    });

    test('id sesi lama sebelum Tahap B dikenali tidak bisa dikirim ke jam', () {
      expect(idSesiValid('sesi-1754870000000000'), isFalse);
      expect(idSesiValid(buatIdSesi()), isTrue);
      expect(
        () => tulisArmSesi('sesi-1754870000000000'),
        throwsA(isA<GalatProtokol>()),
      );
    });
  });

  group('Anchor waktu (§4.2)', () {
    // Uji inti §4.2: satu anchor di akhir menerjemahkan seluruh isi buffer boot
    // itu, termasuk entri yang terjadi jauh sebelum anchor dipasang.
    test('entri sebelum anchor diterjemahkan lewat selisih negatif', () {
      final anchor = AnchorWaktu(
        bootId: 7,
        uptimeS: 40000,
        epoch: DateTime(2026, 8, 11, 20, 0),
      );

      // Tombol ditekan pada uptime 18000 — 22000 detik (6 jam 6 menit 40 detik)
      // sebelum HP tersambung.
      expect(anchor.keWaktu(18000), DateTime(2026, 8, 11, 13, 53, 20));
    });

    test('anchor hanya berlaku untuk boot-nya sendiri', () {
      final anchor = AnchorWaktu(
        bootId: 7,
        uptimeS: 100,
        epoch: DateTime(2026, 8, 11),
      );

      expect(anchor.berlakuUntuk(7), isTrue);
      expect(anchor.berlakuUntuk(8), isFalse);
    });
  });

  group('Iklan (§2.2)', () {
    test('versi mayor dibaca dari manufacturer data', () {
      expect(versiMayorDariIklan({0xFFFF: [1, 2, 3]}), 1);
    });

    test('iklan tanpa manufacturer data tidak menolak perangkat di sini', () {
      expect(versiMayorDariIklan(const {}), isNull);
      expect(versiMayorDariIklan(const {0xFFFF: []}), isNull);
    });
  });
}
