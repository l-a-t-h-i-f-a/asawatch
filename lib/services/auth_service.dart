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
    required this.tokenSegar,
    required this.kedaluwarsa,
    this.nama = '',
    this.email = '',
  });

  final String token;
  final String tokenSegar;

  /// Kapan [token] tidak berlaku lagi, menurut jam ponsel.
  ///
  /// Server mengirim `expires_in` dalam detik, bukan tanggal — justru karena
  /// jam ponsel dan jam server tidak pernah persis sama. Penjumlahannya
  /// dilakukan sekali, di sini, agar sisa aplikasi cukup membandingkan tanggal.
  final DateTime kedaluwarsa;

  final String nama;
  final String email;

  bool get masihBerlaku => DateTime.now().isBefore(kedaluwarsa);
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
    MasukBerhasil() || KredensialSalah() => false,
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

  /// [identifier] adalah email **atau** nomor HP — halaman login menerima
  /// keduanya di satu isian, dan yang membedakannya adalah server.
  Future<HasilMasuk> masuk({
    required String identifier,
    required String kataSandi,
  });

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
        akun.any(
          (a) => a.identifier == identifier.trim() && a.kataSandi == kataSandi,
        );
    if (!cocok) return const KredensialSalah();

    return MasukBerhasil(
      SesiLogin(
        token: 'token-palsu',
        tokenSegar: 'token-segar-palsu',
        kedaluwarsa: DateTime.now().add(const Duration(hours: 1)),
        email: identifier.trim(),
      ),
    );
  }

  @override
  void dispose() => _dibuang = true;
}
