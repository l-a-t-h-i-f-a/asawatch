/// Kontrak masuk akun, dan tiruannya untuk test dan demo tanpa server.
///
/// Dibuat abstrak dengan alasan yang persis sama seperti `BleService`: bagian
/// yang tidak bisa dijalankan tanpa perangkat keras — di sini, tanpa jaringan
/// dan tanpa backend — dipisahkan dari bagian yang menentukan apa yang dilihat
/// pengguna. Halaman login tidak pernah menyentuh `http`, `json`, atau sebuah
/// URL; ia menerima [HasilMasuk] dan memutuskan apa yang digambar.
///
/// Pemisahan itu bukan kerapian. Backend AsaWatch **belum ada**, sementara lima
/// kondisi kegagalan di bawah sudah harus punya kalimatnya masing-masing. Tanpa
/// [FakeAuthService] tak satu pun dari kalimat itu bisa dilihat sebelum ada
/// server — dan tiga di antaranya ([WaktuHabis], [TidakAdaJaringan],
/// [ServerBermasalah]) tetap tidak bisa dipesan sesuka hati bahkan setelah
/// servernya ada.
library;

/// Bukti bahwa pengguna sudah masuk.
///
/// Belum ada yang menyimpannya: penyimpanan token adalah langkah berikutnya
/// (`flutter_secure_storage`, bukan `SharedPreferences` — token membuka data
/// kesehatan, dan preferences di Android adalah XML polos). Bentuknya sudah
/// ditetapkan sekarang supaya [AuthService] tidak perlu berubah saat
/// penyimpanan itu masuk.
class SesiLogin {
  const SesiLogin({
    required this.token,
    required this.kedaluwarsa,
    this.nama = '',
    this.email = '',
  });

  final String token;

  /// Kapan [token] tidak berlaku lagi, menurut jam ponsel.
  ///
  /// **Tidak ada token penyegar.** docs/rancangan-api-laravel.md §4 sengaja
  /// memilih satu token berumur panjang (30 hari, `config/sanctum.php`)
  /// ditambah endpoint `keluar-semua`, ketimbang rotasi token: dengan satu
  /// klien mobile, rotasi menambah keadaan yang harus benar tanpa menambah
  /// keamanan yang berarti.
  ///
  /// Server tidak mengirim tanggal kedaluwarsa sama sekali, jadi angkanya
  /// dihitung di sisi aplikasi dari [masaBerlakuToken] — dan karena itu ia
  /// **harus sama dengan setelan Sanctum**. Kalau server dipersingkat tanpa
  /// aplikasi ikut diubah, gejalanya adalah 401 yang datang lebih awal daripada
  /// yang diduga aplikasi; itu tidak berbahaya (401 tetap ditangani), hanya
  /// membingungkan saat dilacak.
  final DateTime kedaluwarsa;

  final String nama;
  final String email;

  bool get masihBerlaku => DateTime.now().isBefore(kedaluwarsa);

  /// Umur token menurut `config/sanctum.php` di backend.
  static const Duration masaBerlakuToken = Duration(days: 30);
}

/// Hasil satu percobaan masuk.
///
/// Sengaja bukan `bool`, dan bukan pula pengecualian yang dilempar — pelajaran
/// yang sama dengan `HasilSambung` di `BleService`: tindak lanjut tiap
/// kegagalan berbeda, dan "gagal masuk, coba lagi" untuk semuanya adalah cara
/// tercepat membuat pengguna mengulangi hal yang tidak mungkin berhasil.
/// [KredensialSalah] adalah satu-satunya yang tidak akan pernah pulih dengan
/// mencoba lagi tanpa mengubah apa pun.
sealed class HasilMasuk {
  const HasilMasuk();
}

class MasukBerhasil extends HasilMasuk {
  const MasukBerhasil(this.sesi);
  final SesiLogin sesi;
}

/// Server menjawab, dan jawabannya "bukan akun ini" (401).
class KredensialSalah extends HasilMasuk {
  const KredensialSalah();
}

/// Hanya bisa terjadi pada pendaftaran: emailnya sudah punya akun.
///
/// Berbagi [HasilMasuk] dengan alur masuk, bukan sealed class sendiri, karena
/// keduanya berakhir pada hal yang sama — sebuah [SesiLogin] — dan seluruh
/// kalimat kegagalannya (tanpa jaringan, server rusak, waktu habis) identik.
/// Yang berbeda hanya dua ujung: [KredensialSalah] tidak pernah muncul saat
/// mendaftar, dan ini tidak pernah muncul saat masuk.
class EmailSudahDipakai extends HasilMasuk {
  const EmailSudahDipakai();
}

/// Permintaan tidak pernah sampai: tidak ada sinyal, WiFi tanpa jalan keluar,
/// atau alamat server yang tidak bisa dihubungi sama sekali.
class TidakAdaJaringan extends HasilMasuk {
  const TidakAdaJaringan();
}

/// Server sampai, tetapi rusak (5xx) atau menjawab dengan sesuatu yang bukan
/// bentuk yang dijanjikan. Dibedakan dari [KredensialSalah] karena **bukan
/// kesalahan pengguna** — menyuruhnya memeriksa kata sandi di sini hanya
/// membuatnya meragukan sesuatu yang sudah benar.
class ServerBermasalah extends HasilMasuk {
  const ServerBermasalah();
}

/// Tidak ada jawaban dalam [AuthService.batasWaktu].
///
/// Berhak berdiri sendiri karena inilah satu-satunya kegagalan yang, dari kursi
/// pengguna, tidak bisa dibedakan dari aplikasi yang menggantung.
class WaktuHabis extends HasilMasuk {
  const WaktuHabis();
}

extension PesanHasilMasuk on HasilMasuk {
  bool get berhasil => this is MasukBerhasil;

  /// Kalimat siap tampil. Tidak satu pun menyebut kode status, "server", atau
  /// istilah jaringan: yang perlu diketahui pengguna adalah **langkah
  /// berikutnya**, bukan lapisan mana yang gagal.
  String get pesan => switch (this) {
    MasukBerhasil() => '',
    KredensialSalah() =>
      'Email atau kata sandi tidak cocok. Periksa kembali, lalu coba lagi.',
    EmailSudahDipakai() =>
      'Email ini sudah terdaftar. Masuk dengan email tersebut, atau pakai '
          'email lain.',
    TidakAdaJaringan() =>
      'Tidak ada koneksi internet. Nyalakan data atau WiFi, lalu coba lagi.',
    ServerBermasalah() =>
      'Layanan AsaWatch sedang bermasalah. Ini bukan kesalahan Anda — coba '
          'lagi beberapa saat lagi.',
    WaktuHabis() =>
      'Sambungan terlalu lama menjawab. Periksa koneksi Anda, lalu coba lagi.',
  };

  /// Apakah menawarkan "Coba Lagi" masuk akal.
  ///
  /// [KredensialSalah] tidak: tombol yang mengulang hal yang sama persis
  /// menyiratkan bahwa yang diketik pengguna sudah benar dan cukup diulang.
  /// Yang harus berubah adalah isian formulirnya.
  bool get bisaDiulang => switch (this) {
    // Ketiganya tidak akan berubah hasilnya tanpa isian yang berubah — dan
    // tombol yang mengulang hal yang sama persis menyiratkan bahwa yang
    // diketik pengguna sudah benar.
    MasukBerhasil() || KredensialSalah() || EmailSudahDipakai() => false,
    _ => true,
  };
}

abstract class AuthService {
  /// Batas tunggu satu permintaan.
  ///
  /// Ada di kontrak, bukan di implementasi http-nya, karena tanpa batas yang
  /// disepakati [WaktuHabis] tidak pernah terjadi — soket yang menggantung
  /// hanya terbaca sebagai tombol yang berputar selamanya.
  static const Duration batasWaktu = Duration(seconds: 15);

  /// [identifier] adalah **email**, dan hanya email.
  ///
  /// Halaman masuk dulu menuliskan "Email atau Nomor HP", padahal
  /// `MasukRequest` di backend memvalidasi `'email' => ['required','email']`
  /// lalu mencari `where('email', ...)`. Nomor HP karena itu dijawab 422
  /// `validasi_gagal`, yang dipetakan ke [KredensialSalah] — sehingga orang
  /// yang menuruti label itu diberi tahu bahwa kredensialnya salah, bukan
  /// bahwa cara masuknya memang tidak pernah ada. Namanya dibiarkan
  /// `identifier` supaya seam-nya tetap terbuka bila suatu saat backend
  /// menerima lebih dari satu bentuk.
  Future<HasilMasuk> masuk({
    required String identifier,
    required String kataSandi,
  });

  /// Membuat akun baru (§4 `daftar`).
  ///
  /// Mengembalikan [HasilMasuk] yang sama dengan [masuk], dan pada keberhasilan
  /// membawa [SesiLogin] — server sudah memberi token pada balasan pendaftaran,
  /// jadi pengguna baru tidak perlu mengetik ulang kredensialnya untuk masuk.
  /// Menyuruhnya masuk sekali lagi tepat setelah mendaftar adalah langkah yang
  /// tidak menambah keamanan apa pun.
  Future<HasilMasuk> daftar({
    required String nama,
    required String email,
    required String kataSandi,
  });

  /// Mencabut [token] di server (§4 `keluar`).
  ///
  /// **Tidak mengembalikan apa pun, dan tidak pernah melempar.** Token
  /// Sanctum berumur 30 hari, jadi keluar yang hanya menghapus salinan di
  /// ponsel meninggalkan kunci yang masih sah selama itu — karena itu server
  /// tetap dikabari. Tetapi kegagalannya tidak boleh menghalangi: orang yang
  /// menyerahkan ponselnya ke tukang servis harus tetap bisa keluar walau
  /// sedang tanpa sinyal. Penghapusan lokal dilakukan pemanggil, apa pun
  /// hasilnya di sini.
  Future<void> keluar(String token);

  void dispose();
}

/// Akun tiruan untuk [FakeAuthService].
typedef AkunPalsu = ({String identifier, String kataSandi});

/// Auth palsu untuk pengembangan UI dan test — padanan `FakeBleService`.
///
/// Seperti jam palsu, ia **tidak akan pernah dihapus**: ia tulang punggung test
/// dan satu-satunya cara menjalankan aplikasi ini selama backend-nya belum ada
/// (`--dart-define=PAKAI_AUTH_PALSU=true`).
///
/// [paksa] memesan satu hasil apa pun isian formulirnya. Inilah alasan utama
/// kelas ini ada: [WaktuHabis] dan [TidakAdaJaringan] tidak bisa diminta dari
/// server sungguhan tanpa merusak servernya atau mencabut WiFi, padahal
/// keduanya adalah jalur yang paling sering dilihat pengguna di lapangan.
///
/// [jeda] adalah lama "permintaan"-nya. Bawaannya nol supaya test cepat;
/// demo memakai jeda nyata agar keadaan tombol terkunci benar-benar terlihat —
/// di jaringan lokal, keadaan itu lewat terlalu cepat untuk sempat dilihat.
class FakeAuthService implements AuthService {
  FakeAuthService({
    this.paksa,
    this.jeda = Duration.zero,
    this.akun = akunDemo,
    this.terimaSemua = false,
  });

  /// Satu-satunya akun yang dikenali secara bawaan:
  /// **`test@email.com` / `rahasia123`**.
  static const List<AkunPalsu> akunDemo = [
    (identifier: 'test@email.com', kataSandi: 'rahasia123'),
  ];

  /// Hasil yang dipesan. null berarti perilaku normal: cocokkan ke [akun].
  final HasilMasuk? paksa;
  final Duration jeda;
  final List<AkunPalsu> akun;

  /// Akun yang lahir dari [daftar] selama aplikasi berjalan. Terpisah dari
  /// [akun] karena bawaannya `const` — dan karena mendaftar lalu masuk dengan
  /// akun itu juga harus bekerja, kalau tidak, yang palsu ini memodelkan
  /// sesuatu yang tidak pernah terjadi pada server sungguhan.
  final List<AkunPalsu> akunBaru = [];

  /// Menerima kombinasi apa pun yang tidak kosong, alih-alih hanya yang ada di
  /// [akun].
  ///
  /// Bawaannya **false**, dan itu disengaja: auth palsu yang menerima kata sandi
  /// apa pun tidak pernah melewati jalur [KredensialSalah] dengan sendirinya,
  /// sehingga satu-satunya cara melihatnya adalah memesannya lewat [paksa].
  /// Tiruan yang menolak sandi salah lebih setia kepada yang akan
  /// menggantikannya — dan itulah gunanya ia ada.
  final bool terimaSemua;

  var _dibuang = false;

  /// Berapa kali [masuk] dipanggil.
  ///
  /// Dipakai test untuk membuktikan bahwa tombol yang terkunci benar-benar
  /// mencegah permintaan kedua — hal yang tidak bisa dilihat dari layar, karena
  /// dua permintaan yang berjalan bersamaan terlihat persis sama dengan satu.
  var jumlahPanggilan = 0;

  @override
  Future<HasilMasuk> masuk({
    required String identifier,
    required String kataSandi,
  }) async {
    jumlahPanggilan++;
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    if (_dibuang) return const ServerBermasalah();

    final dipesan = paksa;
    if (dipesan != null) return dipesan;

    if (identifier.trim().isEmpty || kataSandi.isEmpty) {
      return const KredensialSalah();
    }

    final cocok =
        terimaSemua ||
        [...akun, ...akunBaru].any(
          (a) => a.identifier == identifier.trim() && a.kataSandi == kataSandi,
        );
    if (!cocok) return const KredensialSalah();

    return MasukBerhasil(
      SesiLogin(
        token: 'token-palsu',
        kedaluwarsa: DateTime.now().add(SesiLogin.masaBerlakuToken),
        email: identifier.trim(),
      ),
    );
  }

  @override
  Future<HasilMasuk> daftar({
    required String nama,
    required String email,
    required String kataSandi,
  }) async {
    jumlahPanggilan++;
    if (jeda > Duration.zero) await Future<void>.delayed(jeda);
    if (_dibuang) return const ServerBermasalah();

    final dipesan = paksa;
    if (dipesan != null) return dipesan;

    final sudahAda = [
      ...akun,
      ...akunBaru,
    ].any((a) => a.identifier == email.trim());
    if (sudahAda) return const EmailSudahDipakai();
    akunBaru.add((identifier: email.trim(), kataSandi: kataSandi));

    return MasukBerhasil(
      SesiLogin(
        token: 'token-palsu-daftar',
        kedaluwarsa: DateTime.now().add(SesiLogin.masaBerlakuToken),
        nama: nama.trim(),
        email: email.trim(),
      ),
    );
  }

  @override
  Future<void> keluar(String token) async {
    tokenDicabut.add(token);
  }

  /// Token yang sempat dicabut — dipakai test untuk membuktikan bahwa keluar
  /// mengabari server, bukan sekadar menghapus salinan lokalnya.
  final List<String> tokenDicabut = [];

  @override
  void dispose() => _dibuang = true;
}
