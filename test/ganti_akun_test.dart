// Pergantian akun di satu ponsel — data pemilik sebelumnya tidak boleh
// tertinggal, dan yang lebih berbahaya: tidak boleh ikut naik ke akun baru.
//
// Satu ponsel dipakai dua orang bukan keadaan aneh (satu keluarga, satu
// perangkat pinjaman, satu ponsel demo), dan tidak ada satu pun gejala di layar
// yang membuat kebocorannya terlihat: di server, sesi milik orang lain tampak
// sah.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/login_page.dart';
import 'package:asawatch/models/sesi_makan.dart';
import 'package:asawatch/repositories/entri_jam_repository.dart';
import 'package:asawatch/repositories/kalibrasi_repository.dart';
import 'package:asawatch/repositories/profil_repository.dart';
import 'package:asawatch/repositories/sesi_login_repository.dart';
import 'package:asawatch/repositories/sesi_repository.dart';
import 'package:asawatch/services/auth_service.dart';
import 'package:asawatch/services/protokol_jam.dart';
import 'package:asawatch/services/sesi_server_service.dart';

import 'helpers.dart';

/// Satu sesi yang sudah berakhir, milik pemilik ponsel sebelumnya.
SesiMakan _sesiLama({String fotoPath = '/tmp/nasi.jpg'}) => SesiMakan(
  id: buatIdSesi(),
  fotoPath: fotoPath,
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
      gulaDarah: 140,
    ),
    Sampel(
      index: 2,
      detikRelatifT0: 3600,
      status: StatusSampel.terisi,
      gulaDarah: 118,
    ),
    Sampel(
      index: 3,
      detikRelatifT0: 7200,
      status: StatusSampel.terisi,
      gulaDarah: 99,
    ),
  ],
);

Kalibrasi _kalibrasiLama() => Kalibrasi(
  waktu: DateTime.now(),
  sisi: SisiPergelangan.kiri,
  putaran: const [
    PutaranKalibrasi(
      sistolikReferensi: 120,
      diastolikReferensi: 80,
      sistolikJam: 112,
      diastolikJam: 74,
    ),
    PutaranKalibrasi(
      sistolikReferensi: 122,
      diastolikReferensi: 81,
      sistolikJam: 114,
      diastolikJam: 75,
    ),
    PutaranKalibrasi(
      sistolikReferensi: 121,
      diastolikReferensi: 80,
      sistolikJam: 113,
      diastolikJam: 74,
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadMontserrat);

  group('hapusDataLokal', () {
    test('membuang sesi, kalibrasi, dan kotak masuk jam sekaligus', () async {
      final repo = SesiRepositoryMemori(awal: [_sesiLama()]);
      final repoKalibrasi = KalibrasiRepositoryMemori();
      await repoKalibrasi.simpan(_kalibrasiLama());
      final repoEntri = EntriJamRepositoryMemori();
      await repoEntri.simpan(
        const EntriPeristiwa(
          seq: 1,
          bootId: 7,
          uptimeS: 42,
          jenis: JenisPeristiwa.tombolSelesaiMakan,
          sesiId: 'sesi-lama',
          dariBuffer: false,
          waktuTidakPasti: false,
          payload: 0,
        ),
      );

      final c = buatControllerUji(
        riwayatAwal: await repo.muatSemua(),
        repo: repo,
        repoKalibrasi: repoKalibrasi,
        repoEntri: repoEntri,
        kalibrasiAwal: await repoKalibrasi.terbaru(),
      );
      addTearDown(c.dispose);

      expect(c.riwayat, hasLength(1));
      expect(c.kalibrasiTerakhir, isNotNull);

      await c.hapusDataLokal();

      // Di memori dan di penyimpanan — yang pertama saja akan hidup kembali
      // pada pembukaan aplikasi berikutnya.
      expect(c.riwayat, isEmpty);
      expect(c.kalibrasiTerakhir, isNull);
      expect(await repo.muatSemua(), isEmpty);
      expect(await repoKalibrasi.terbaru(), isNull);
      // Kotak masuk ikut kosong: entri yang tersisa akan diputar ulang saat
      // start dan membangun kembali sesi yang baru saja dihapus.
      expect(await repoEntri.belumDiproses(), isEmpty);
      expect(repoEntri.semua, isEmpty);
    });

    test('berkas fotonya ikut terhapus dari penyimpanan', () async {
      // Menghapus barisnya saja meninggalkan foto makanan pemilik sebelumnya
      // utuh di penyimpanan ponsel yang sekarang dipakai orang lain.
      final folder = Directory.systemTemp.createTempSync('foto_uji');
      addTearDown(() {
        if (folder.existsSync()) folder.deleteSync(recursive: true);
      });
      final foto = File('${folder.path}/makan.jpg')
        ..writeAsBytesSync([1, 2, 3]);

      final repo = SesiRepositoryMemori(awal: [_sesiLama(fotoPath: foto.path)]);
      final c = buatControllerUji(
        riwayatAwal: await repo.muatSemua(),
        repo: repo,
      );
      addTearDown(c.dispose);

      expect(foto.existsSync(), isTrue);
      await c.hapusDataLokal();
      expect(foto.existsSync(), isFalse);
    });
  });

  group('Masuk dengan akun lain', () {
    testWidgets('riwayat pemilik sebelumnya dibuang, bukan diunggah', (
      tester,
    ) async {
      // Ponsel ini sudah punya pemiliknya.
      SharedPreferences.setMockInitialValues({
        'user_account_email': 'rara@email.com',
        'user_name': 'Rara',
      });

      final server = SesiServerPalsu();
      final repo = SesiRepositoryMemori(awal: [_sesiLama()]);
      final c = buatControllerUji(
        riwayatAwal: await repo.muatSemua(),
        repo: repo,
        serverSesi: server,
        sesiLogin: SesiLoginRepositoryMemori(),
      );

      final auth = FakeAuthService();
      addTearDown(auth.dispose);
      await pumpHalaman(
        tester,
        LoginPage(
          auth: auth,
          profil: const ProfilRepository(),
          sesiLogin: c.sesiLogin,
        ),
        controller: c,
      );

      final akun = FakeAuthService.akunDemo.first;
      await tester.enterText(find.byType(TextFormField).at(0), akun.identifier);
      await tester.enterText(find.byType(TextFormField).at(1), akun.kataSandi);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      // Yang paling penting dari test ini: **tidak satu pun** sesi naik ke akun
      // yang baru masuk. Ini bukan soal tampilan — di server sesi orang lain
      // tidak bisa dibedakan lagi dari sesi milik pemiliknya.
      expect(server.diterima, isEmpty);
      expect(c.riwayat, isEmpty);
      expect(await repo.muatSemua(), isEmpty);
    });

    testWidgets('akun yang sama tidak kehilangan apa pun', (tester) async {
      final akun = FakeAuthService.akunDemo.first;
      SharedPreferences.setMockInitialValues({
        'user_account_email': akun.identifier,
      });

      final server = SesiServerPalsu();
      final repo = SesiRepositoryMemori(awal: [_sesiLama()]);
      final c = buatControllerUji(
        riwayatAwal: await repo.muatSemua(),
        repo: repo,
        serverSesi: server,
        sesiLogin: SesiLoginRepositoryMemori(),
      );

      final auth = FakeAuthService();
      addTearDown(auth.dispose);
      await pumpHalaman(
        tester,
        LoginPage(
          auth: auth,
          profil: const ProfilRepository(),
          sesiLogin: c.sesiLogin,
        ),
        controller: c,
      );

      await tester.enterText(find.byType(TextFormField).at(0), akun.identifier);
      await tester.enterText(find.byType(TextFormField).at(1), akun.kataSandi);
      await tester.tap(find.widgetWithText(ElevatedButton, 'Masuk'));
      await tester.pumpAndSettle();

      // Masuk lagi sebagai diri sendiri adalah hal yang paling sering terjadi,
      // dan membuang riwayat di sana akan jauh lebih merusak daripada bug yang
      // sedang diperbaiki.
      expect(c.riwayat, hasLength(1));
      expect(server.diterima, hasLength(1));
    });
  });
}
