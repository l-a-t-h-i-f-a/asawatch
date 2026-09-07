import 'dart:convert';

import 'package:asawatch/beranda_tab.dart';
import 'package:asawatch/login_page.dart';
import 'package:asawatch/repositories/sesi_login_repository.dart';
import 'package:asawatch/services/auth_http_service.dart';
import 'package:asawatch/services/auth_service.dart';
import 'package:asawatch/services/google_masuk_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers.dart';

/// `pakaiGoogle` berasal dari `String.fromEnvironment`, jadi ia selalu mati di
/// bawah `flutter test` dan tombolnya tidak akan pernah digambar dengan
/// sendirinya. `tampilkanGoogle: true` ada persis untuk itu — lihat
/// [LoginPage.tampilkanGoogle].
Future<SesiLoginRepositoryMemori> _pumpMasuk(
  WidgetTester tester, {
  required AuthService auth,
}) async {
  SharedPreferences.setMockInitialValues({});
  final penyimpanan = SesiLoginRepositoryMemori();
  await pumpHalaman(
    tester,
    LoginPage(auth: auth, sesiLogin: penyimpanan, tampilkanGoogle: true),
  );
  return penyimpanan;
}

Future<void> _tekanGoogle(WidgetTester tester) async {
  await tester.tap(find.text('Masuk dengan Google'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(loadMontserrat);

  group('GoogleMasukPalsu', () {
    test('bawaannya mengembalikan ID token', () async {
      final hasil = await GoogleMasukPalsu().masuk();
      expect(hasil, isA<GoogleBerhasil>());
      expect((hasil as GoogleBerhasil).idToken, isNotEmpty);
    });

    test(
      'bisa dipesan membatalkan — jalur yang tidak bisa diminta ke Google',
      () async {
        final hasil = await GoogleMasukPalsu(
          hasil: const GoogleDibatalkan(),
        ).masuk();
        expect(hasil, isA<GoogleDibatalkan>());
      },
    );
  });

  group('HasilMasuk.DibatalkanPengguna', () {
    test('tidak berpesan apa pun, dan tidak menawarkan coba lagi', () {
      // Keduanya menentukan: kalimat kosong supaya tidak ada kotak merah, dan
      // `bisaDiulang` false supaya tidak ada tombol "Coba Lagi" untuk sesuatu
      // yang bukan kegagalan.
      const batal = DibatalkanPengguna();
      expect(batal.pesan, isEmpty);
      expect(batal.bisaDiulang, isFalse);
      expect(batal.berhasil, isFalse);
    });
  });

  group('AuthHttpService.masukDenganGoogle', () {
    test('menukar ID token di /auth/google, lalu mengembalikan sesi', () async {
      late http.Request terkirim;
      final layanan = AuthHttpService(
        basisUrl: 'https://contoh.test',
        google: GoogleMasukPalsu(),
        klien: MockClient((permintaan) async {
          terkirim = permintaan;
          return http.Response(
            jsonEncode({
              'data': {
                'token': '9|token-google',
                'profil': {'nama': 'Rara'},
              },
            }),
            201,
          );
        }),
      );
      addTearDown(layanan.dispose);

      final hasil = await layanan.masukDenganGoogle();

      expect(terkirim.url.path, '/api/v1/auth/google');
      final badan = jsonDecode(terkirim.body) as Map<String, dynamic>;
      // ID token, bukan access token: hanya ID token yang membawa `aud`, dan
      // tanpa `aud` server tidak bisa membuktikan token itu untuk aplikasi ini.
      expect(badan['id_token'], 'id-token-palsu');
      expect(badan['nama_perangkat'], isNotEmpty);

      expect(hasil, isA<MasukBerhasil>());
      final sesi = (hasil as MasukBerhasil).sesi;
      expect(sesi.token, '9|token-google');
      // `masuk` tidak mengembalikan email, jadi yang dipakai adalah alamat yang
      // dilaporkan Google — satu-satunya yang ada pada titik ini.
      expect(sesi.email, 'test@email.com');
    });

    test('pembatalan tidak pernah menjadi permintaan jaringan', () async {
      var dipanggil = false;
      final layanan = AuthHttpService(
        basisUrl: 'https://contoh.test',
        google: GoogleMasukPalsu(hasil: const GoogleDibatalkan()),
        klien: MockClient((_) async {
          dipanggil = true;
          return http.Response('{}', 200);
        }),
      );
      addTearDown(layanan.dispose);

      final hasil = await layanan.masukDenganGoogle();

      expect(hasil, isA<DibatalkanPengguna>());
      // Yang dibuktikan bukan pesannya melainkan ketiadaan permintaannya:
      // menutup pemilih akun tidak boleh menyentuh server sama sekali.
      expect(dipanggil, isFalse);
    });

    test(
      'ID token kosong dibaca sebagai server bermasalah, bukan kredensial',
      () async {
        // Gejala salah pasang client ID (Android alih-alih Web). Pengguna tidak
        // mengetik apa pun, jadi menyuruhnya memeriksa kredensial adalah jalan
        // buntu.
        final layanan = AuthHttpService(
          basisUrl: 'https://contoh.test',
          google: GoogleMasukPalsu(hasil: GoogleGagal.idTokenKosong),
          klien: MockClient((_) async => http.Response('{}', 200)),
        );
        addTearDown(layanan.dispose);

        final hasil = await layanan.masukDenganGoogle();

        expect(hasil, isA<ServerBermasalah>());
        expect(hasil, isNot(isA<KredensialSalah>()));
      },
    );

    test('401 dari server tidak dibaca sebagai kredensial salah', () async {
      // Di jalur ini 401 berarti ID token ditolak Google. Tidak ada kata sandi
      // yang bisa diperiksa pengguna.
      final layanan = AuthHttpService(
        basisUrl: 'https://contoh.test',
        google: GoogleMasukPalsu(),
        klien: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'galat': {'kode': 'tidak_terautentikasi', 'pesan': 'x'},
            }),
            401,
          ),
        ),
      );
      addTearDown(layanan.dispose);

      expect(await layanan.masukDenganGoogle(), isA<ServerBermasalah>());
    });

    test(
      'keluar melepas akun Google di ponsel, bukan hanya token server',
      () async {
        final google = GoogleMasukPalsu();
        final layanan = AuthHttpService(
          basisUrl: 'https://contoh.test',
          google: google,
          klien: MockClient((_) async => http.Response('{}', 200)),
        );
        addTearDown(layanan.dispose);

        await layanan.keluar('9|token-google');

        // Tanpa ini, ketukan berikutnya masuk kembali ke akun yang sama tanpa
        // pemilih akun — di ponsel bersama itu terbaca sebagai keluar yang gagal.
        expect(google.jumlahKeluar, 1);
      },
    );
  });

  group('Halaman masuk', () {
    testWidgets('menekan tombolnya menyimpan token lalu membuka Beranda', (
      tester,
    ) async {
      final auth = FakeAuthService();
      addTearDown(auth.dispose);
      final penyimpanan = await _pumpMasuk(tester, auth: auth);

      await _tekanGoogle(tester);

      // Token disimpan **sebelum** berpindah: aplikasi yang ditutup tepat
      // sesudah masuk harus tetap ditemukan dalam keadaan masuk.
      expect((await penyimpanan.muat())?.token, 'token-palsu-google');
      expect(find.byType(BerandaTab), findsOneWidget);
    });

    testWidgets('tanpa mengetik apa pun — formulir tidak divalidasi', (
      tester,
    ) async {
      // Tombol Masuk biasa menolak formulir kosong. Jalur Google tidak boleh
      // ikut tertahan oleh validasi isian yang memang tidak diisi siapa pun.
      final auth = FakeAuthService();
      addTearDown(auth.dispose);
      await _pumpMasuk(tester, auth: auth);

      await _tekanGoogle(tester);

      expect(auth.jumlahPanggilan, 1);
      expect(find.text('Masukkan email'), findsNothing);
    });

    testWidgets('pembatalan tidak memunculkan pesan galat', (tester) async {
      final auth = FakeAuthService(paksa: const DibatalkanPengguna());
      addTearDown(auth.dispose);
      final penyimpanan = await _pumpMasuk(tester, auth: auth);

      await _tekanGoogle(tester);

      // Layar harus kembali persis seperti sebelum tombol ditekan: tidak ada
      // kalimat kegagalan, tidak berpindah, dan tidak ada token yang tersimpan.
      expect(find.textContaining('tidak cocok'), findsNothing);
      expect(find.textContaining('bermasalah'), findsNothing);
      expect(find.textContaining('koneksi'), findsNothing);
      expect(find.byType(BerandaTab), findsNothing);
      expect(await penyimpanan.muat(), isNull);
      // Tombolnya hidup lagi — pembatalan bukan keadaan yang menahan halaman.
      expect(find.text('Masuk dengan Google'), findsOneWidget);
    });

    testWidgets('kegagalan jaringan tetap dijelaskan', (tester) async {
      final auth = FakeAuthService(paksa: const TidakAdaJaringan());
      addTearDown(auth.dispose);
      await _pumpMasuk(tester, auth: auth);

      await _tekanGoogle(tester);

      expect(find.textContaining('koneksi internet'), findsOneWidget);
    });
  });
}
