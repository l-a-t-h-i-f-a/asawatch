// AuthHttpService diuji terhadap soket palsu, bukan terhadap server.
//
// `MockClient` menggantikan **hanya** lapisan soketnya, jadi yang dijalankan di
// bawah ini adalah `AuthHttpService` yang sungguhan: penyusunan URL, header,
// encoding body, pembacaan JSON, dan pemetaan kode status semuanya nyata. Itu
// sebabnya seam `http.Client` disuntikkan lewat konstruktor alih-alih memanggil
// `http.post()` — tanpa seam itu, satu-satunya cara menguji berkas ini adalah
// menyalakan sebuah server.
//
// Yang **tidak** dibuktikan di sini, dan hanya bisa dibuktikan sekali dengan
// server sungguhan: bahwa Android mengizinkan koneksinya (cleartext diblokir
// sejak Android 9), bahwa TLS-nya sah, dan bahwa bentuk JSON di bawah memang
// bentuk yang dikirim backend. Test ini mengabadikan asumsi itu, tidak
// memvalidasinya.

import 'dart:async';
import 'dart:convert';
import 'dart:io' show SocketException;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:asawatch/services/auth_http_service.dart';
import 'package:asawatch/services/auth_service.dart';

const _basis = 'http://uji.lokal:8080';

AuthHttpService _layanan(Future<http.Response> Function(http.Request) tangani) {
  final layanan = AuthHttpService(
    basisUrl: _basis,
    klien: MockClient(tangani),
  );
  addTearDown(layanan.dispose);
  return layanan;
}

/// Badan jawaban sukses, dalam bentuk yang dijanjikan kontrak API.
String _badanSukses({int expiresIn = 3600}) => jsonEncode({
  'access_token': 'token-abc',
  'refresh_token': 'token-segar-def',
  'expires_in': expiresIn,
  'user': {'name': 'Rara', 'email': 'rara@email.com'},
});

void main() {
  group('permintaan yang dikirim', () {
    test('menembak /auth/login dengan JSON dan header yang benar', () async {
      late http.Request terkirim;
      final layanan = _layanan((req) async {
        terkirim = req;
        return http.Response(_badanSukses(), 200);
      });

      await layanan.masuk(identifier: 'rara@email.com', kataSandi: 'rahasia');

      expect(terkirim.method, 'POST');
      expect(terkirim.url.toString(), '$_basis/auth/login');
      expect(terkirim.headers['content-type'], contains('application/json'));

      // Sandi hanya boleh ada di badan permintaan — tidak pernah di URL, yang
      // akan menuliskannya ke log akses server dan riwayat proxy.
      expect(terkirim.url.query, isEmpty);

      final badan = jsonDecode(terkirim.body) as Map<String, dynamic>;
      expect(badan['identifier'], 'rara@email.com');
      expect(badan['password'], 'rahasia');
    });

    test('memangkas spasi di identifier, tetapi tidak di kata sandi', () async {
      late http.Request terkirim;
      final layanan = _layanan((req) async {
        terkirim = req;
        return http.Response(_badanSukses(), 200);
      });

      // Spasi di ujung email hampir selalu salah ketik. Spasi di kata sandi
      // bisa saja disengaja, dan memangkasnya diam-diam membuat sandi yang
      // benar ditolak tanpa satu pun petunjuk.
      await layanan.masuk(identifier: '  rara@email.com  ', kataSandi: ' abc ');

      final badan = jsonDecode(terkirim.body) as Map<String, dynamic>;
      expect(badan['identifier'], 'rara@email.com');
      expect(badan['password'], ' abc ');
    });
  });

  group('jawaban yang dibaca', () {
    test('200 menjadi MasukBerhasil beserta isi tokennya', () async {
      final layanan = _layanan((_) async => http.Response(_badanSukses(), 200));

      final hasil = await layanan.masuk(identifier: 'a@b.c', kataSandi: 'x');

      expect(hasil, isA<MasukBerhasil>());
      final sesi = (hasil as MasukBerhasil).sesi;
      expect(sesi.token, 'token-abc');
      expect(sesi.tokenSegar, 'token-segar-def');
      expect(sesi.nama, 'Rara');
      expect(sesi.email, 'rara@email.com');
      expect(sesi.masihBerlaku, isTrue);
    });

    test('expires_in dihitung menjadi tanggal kedaluwarsa', () async {
      final layanan = _layanan(
        (_) async => http.Response(_badanSukses(expiresIn: 60), 200),
      );

      final sebelum = DateTime.now();
      final hasil = await layanan.masuk(identifier: 'a@b.c', kataSandi: 'x');
      final sesi = (hasil as MasukBerhasil).sesi;

      // Detik dari server, bukan tanggal dari server: jam ponsel dan jam server
      // tidak pernah persis sama.
      expect(
        sesi.kedaluwarsa.difference(sebelum).inSeconds,
        closeTo(60, 2),
      );
    });

    test('expires_in yang hilang jatuh ke satu jam', () async {
      final layanan = _layanan(
        (_) async => http.Response(
          jsonEncode({
            'access_token': 'token-abc',
            'refresh_token': 'token-segar-def',
          }),
          200,
        ),
      );

      final hasil = await layanan.masuk(identifier: 'a@b.c', kataSandi: 'x');
      final sesi = (hasil as MasukBerhasil).sesi;
      expect(sesi.kedaluwarsa.difference(DateTime.now()).inMinutes, closeTo(60, 1));
    });

    test('401 dan 403 menjadi KredensialSalah', () async {
      for (final kode in [401, 403]) {
        final layanan = _layanan(
          (_) async => http.Response('{"kode":"kredensial_salah"}', kode),
        );
        final hasil = await layanan.masuk(identifier: 'a@b.c', kataSandi: 'x');
        expect(hasil, isA<KredensialSalah>(), reason: 'kode $kode');
      }
    });

    test('5xx menjadi ServerBermasalah, bukan KredensialSalah', () async {
      final layanan = _layanan((_) async => http.Response('gagal', 503));

      final hasil = await layanan.masuk(identifier: 'a@b.c', kataSandi: 'x');

      // Pembedaan yang paling mahal bila salah: menyuruh pengguna memeriksa
      // kata sandinya karena server yang rusak membuatnya meragukan sesuatu
      // yang sudah benar.
      expect(hasil, isA<ServerBermasalah>());
    });

    test('400 juga ServerBermasalah — itu bug aplikasi, bukan salah pengguna', () async {
      final layanan = _layanan((_) async => http.Response('{"pesan":"bad"}', 400));

      expect(
        await layanan.masuk(identifier: 'a@b.c', kataSandi: 'x'),
        isA<ServerBermasalah>(),
      );
    });

    test('200 dengan badan bukan JSON menjadi ServerBermasalah', () async {
      // Terjadi di dunia nyata saat sebuah portal WiFi atau proxy menjawab
      // dengan halaman HTML-nya sendiri, lengkap dengan status 200.
      final layanan = _layanan(
        (_) async => http.Response('<html>Login WiFi</html>', 200),
      );

      expect(
        await layanan.masuk(identifier: 'a@b.c', kataSandi: 'x'),
        isA<ServerBermasalah>(),
      );
    });

    test('200 tanpa access_token menjadi ServerBermasalah', () async {
      final layanan = _layanan(
        (_) async => http.Response(jsonEncode({'refresh_token': 'x'}), 200),
      );

      // Bukan dilempar keluar: sebuah pengecualian di sini sampai ke layar
      // sebagai galat merah, bukan sebagai kalimat yang bisa ditindaklanjuti.
      expect(
        await layanan.masuk(identifier: 'a@b.c', kataSandi: 'x'),
        isA<ServerBermasalah>(),
      );
    });
  });

  group('kegagalan jaringan', () {
    test('SocketException menjadi TidakAdaJaringan', () async {
      final layanan = _layanan(
        (_) async => throw const SocketException('tidak ada rute'),
      );

      expect(
        await layanan.masuk(identifier: 'a@b.c', kataSandi: 'x'),
        isA<TidakAdaJaringan>(),
      );
    });

    test('ClientException menjadi TidakAdaJaringan', () async {
      final layanan = _layanan(
        (_) async => throw http.ClientException('koneksi ditutup'),
      );

      expect(
        await layanan.masuk(identifier: 'a@b.c', kataSandi: 'x'),
        isA<TidakAdaJaringan>(),
      );
    });

    // Dijalankan sebagai widget test semata-mata untuk jam palsunya: batas
    // waktunya 15 detik nyata, dan menunggunya betulan membuat berkas test ini
    // berhenti selama itu. Inilah kondisi yang paling sulit dipesan dari server
    // sungguhan — ia menuntut server yang sengaja menggantung.
    testWidgets('jawaban yang tak kunjung datang menjadi WaktuHabis', (
      tester,
    ) async {
      final layanan = _layanan((_) async {
        await Future<void>.delayed(const Duration(seconds: 60));
        return http.Response(_badanSukses(), 200);
      });

      HasilMasuk? hasil;
      unawaited(
        layanan
            .masuk(identifier: 'a@b.c', kataSandi: 'x')
            .then((h) => hasil = h),
      );

      await tester.pump(AuthService.batasWaktu + const Duration(seconds: 1));
      expect(hasil, isA<WaktuHabis>());

      // Jawaban yang telanjur dijadwalkan tetap harus dituntaskan, atau
      // flutter_test melaporkannya sebagai timer yang menggantung.
      await tester.pump(const Duration(seconds: 60));
    });
  });
}
