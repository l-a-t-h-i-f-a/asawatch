/// Seam ke `google_sign_in` — bagian yang tidak bisa dijalankan tanpa Google
/// Play Services dan tanpa akun sungguhan di perangkat.
///
/// Alasannya sama persis dengan `KameraService` dan `BleService`: di bawah
/// `flutter_test` tidak ada platform channel untuk `google_sign_in`, jadi tanpa
/// tiruan ini tombol "Masuk dengan Google" tidak bisa disentuh satu test pun.
/// Dan sama seperti keduanya, [GoogleMasukPalsu] **tidak akan pernah dihapus**:
/// tiga dari empat jalur di bawah tidak bisa dipesan dari Google sesuka hati.
///
/// Yang **tidak** ada di sini: pengetahuan tentang AsaWatch. Berkas ini hanya
/// menukar ketukan pengguna menjadi sebuah ID token; yang menukarnya lagi
/// menjadi sesi AsaWatch adalah `AuthService.masukDenganGoogle`.
library;

import 'package:google_sign_in/google_sign_in.dart';

/// Hasil satu percobaan masuk di sisi ponsel, **sebelum** server terlibat.
sealed class HasilGoogle {
  const HasilGoogle();
}

/// Pengguna memilih akun, dan Google menerbitkan ID token untuknya.
///
/// [idToken] adalah JWT yang akan diverifikasi backend — bukan access token.
/// Bedanya bukan gaya: access token hanya membuktikan "seseorang punya token
/// dari Google", sedangkan ID token membawa klaim `aud` yang membuktikan token
/// itu diterbitkan **untuk aplikasi ini**. Tanpa pemeriksaan itu, token yang
/// diambil dari aplikasi lain bisa dipakai masuk sebagai orang lain.
class GoogleBerhasil extends HasilGoogle {
  const GoogleBerhasil({
    required this.idToken,
    this.email = '',
    this.nama = '',
  });

  final String idToken;

  /// Hanya untuk tampilan sementara dan log. Yang menentukan siapa pemilik
  /// akun tetap klaim di dalam [idToken] setelah diverifikasi server — apa pun
  /// yang dikirim ponsel bisa dikarang.
  final String email;
  final String nama;
}

/// Pemilih akun dibuka lalu ditutup kembali.
///
/// **Bukan kegagalan**, dan inilah alasan utama tipe ini tidak berupa `bool`:
/// layar harus kembali diam seperti sebelum tombol ditekan. Menampilkan pesan
/// galat kepada orang yang baru saja berubah pikiran adalah cara tercepat
/// membuatnya mengira aplikasinya rusak.
class GoogleDibatalkan extends HasilGoogle {
  const GoogleDibatalkan();
}

/// Google menjawab, tetapi tidak dengan sesuatu yang bisa dipakai.
///
/// [catatan] tidak pernah tampil di layar — ia untuk `debugPrint`. Kegagalan
/// paling sering di sini bukan kesalahan pengguna melainkan kesalahan
/// pendaftaran: SHA-1 yang belum didaftarkan menghasilkan `ApiException: 10`
/// yang tidak menyebut sertifikat sama sekali, dan `serverClientId` yang salah
/// menghasilkan [idTokenKosong] — sukses yang tidak membawa apa pun.
class GoogleGagal extends HasilGoogle {
  const GoogleGagal(this.catatan);

  final String catatan;

  /// Masuk berhasil tetapi tanpa ID token.
  ///
  /// Artinya hampir selalu satu hal: `serverClientId` tidak diisi, atau diisi
  /// dengan **client ID Android** alih-alih client ID **Web**. Google tidak
  /// menganggapnya galat — pengguna melihat pemilih akun, memilih, lalu tidak
  /// terjadi apa-apa — jadi tanpa cabang tersendiri, salah pasang client ID
  /// terlihat persis seperti server yang sedang rusak.
  static const idTokenKosong = GoogleGagal(
    'ID token kosong — serverClientId belum diisi, atau diisi client ID '
    'Android alih-alih client ID Web.',
  );
}

abstract class GoogleMasukService {
  /// Membuka pemilih akun dan mengembalikan ID token-nya.
  Future<HasilGoogle> masuk();

  /// Melepas akun yang dipilih di sisi ponsel.
  ///
  /// Wajib dipanggil saat keluar, dan **terpisah** dari pencabutan token
  /// Sanctum di server: tanpa ini, ketukan "Masuk dengan Google" berikutnya
  /// langsung masuk kembali ke akun yang sama tanpa memunculkan pemilih akun.
  /// Di ponsel yang dipakai bergantian, itu terbaca sebagai keluar yang tidak
  /// bekerja.
  Future<void> keluar();
}

/// Implementasi sungguhan di atas `google_sign_in` 7.x.
///
/// API 7.0 berbeda total dari 6.x — `GoogleSignIn.instance` + [initialize],
/// dan `authenticate()` menggantikan `signIn()` — jadi contoh kode mana pun
/// yang lebih tua tidak akan cocok.
class GoogleMasukAsli implements GoogleMasukService {
  GoogleMasukAsli({required this.idKlienWeb});

  /// **Client ID Web**, bukan Android. Lihat [GoogleGagal.idTokenKosong].
  final String idKlienWeb;

  var _siap = false;

  /// [GoogleSignIn.initialize] hanya boleh dijalankan sekali, dan tidak boleh
  /// dijalankan di `main()`: ia menyentuh Play Services, sedangkan seluruh alur
  /// ini harus tetap bisa dilewati oleh orang yang tidak memakai Google.
  Future<void> _siapkan() async {
    if (_siap) return;
    await GoogleSignIn.instance.initialize(serverClientId: idKlienWeb);
    _siap = true;
  }

  @override
  Future<HasilGoogle> masuk() async {
    if (idKlienWeb.isEmpty) return GoogleGagal.idTokenKosong;

    try {
      await _siapkan();
      final akun = await GoogleSignIn.instance.authenticate();
      final idToken = akun.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        return GoogleGagal.idTokenKosong;
      }
      return GoogleBerhasil(
        idToken: idToken,
        email: akun.email,
        nama: akun.displayName ?? '',
      );
    } on GoogleSignInException catch (e) {
      // `canceled` adalah satu-satunya yang bukan kegagalan. `interrupted`
      // sengaja **tidak** ikut: ia berarti alurnya terputus oleh sesuatu di
      // luar kehendak pengguna, dan diam saja setelah itu meninggalkan orang
      // menatap tombol yang tidak melakukan apa pun.
      if (e.code == GoogleSignInExceptionCode.canceled) {
        return const GoogleDibatalkan();
      }
      return GoogleGagal('${e.code.name}: ${e.description}');
    } catch (e) {
      // Play Services yang tidak ada atau kedaluwarsa muncul di sini, bukan
      // sebagai GoogleSignInException.
      return GoogleGagal('$e');
    }
  }

  @override
  Future<void> keluar() async {
    // Ditelan dengan alasan yang sama seperti `AuthService.keluar`: keluar
    // harus tetap berhasil di sisi ponsel walau apa pun terjadi di sini.
    try {
      if (_siap) await GoogleSignIn.instance.signOut();
    } catch (_) {}
  }
}

/// Tiruan untuk test dan demo — padanan `FakeBleService`/`KameraPalsuService`.
///
/// [hasil] memesan jawaban apa pun. Itulah gunanya: [GoogleDibatalkan] dan
/// [GoogleGagal] tidak bisa diminta dari Google sesuka hati, padahal keduanya
/// jalur yang paling sering dilihat pengguna di lapangan.
class GoogleMasukPalsu implements GoogleMasukService {
  GoogleMasukPalsu({this.hasil, this.jeda = Duration.zero});

  /// null berarti berhasil dengan token tiruan.
  final HasilGoogle? hasil;
  final Duration jeda;

  /// Berapa kali [masuk] dipanggil — dipakai test untuk membuktikan bahwa
  /// tombol yang terkunci benar-benar mencegah permintaan kedua, hal yang
  /// tidak terlihat dari layar.
  var jumlahPanggilan = 0;
  var jumlahKeluar = 0;

  @override
  Future<HasilGoogle> masuk() async {
    jumlahPanggilan++;
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    return hasil ??
        const GoogleBerhasil(
          idToken: 'id-token-palsu',
          email: 'test@email.com',
          nama: 'Rara',
        );
  }

  @override
  Future<void> keluar() async => jumlahKeluar++;
}
