/// Satu-satunya pintu ke data profil — docs/rencana-produksi.md §3.2.
///
/// Sebelumnya delapan kunci `user_*` dibaca dan ditulis langsung di tiap
/// halaman, masing-masing dengan nilai bawaannya sendiri. Akibatnya sudah
/// terlihat sebelum berkas ini ada: `profil_tab.dart` memakai
/// `lathifa@gmail.com` sebagai nilai awal field tetapi `lathifa21@email.com`
/// saat memuat, sehingga emailnya berubah sendiri sepersekian detik setelah
/// halaman terbuka. Itulah yang dicegah satu pintu — bukan sekadar kerapian.
///
/// Tetap memakai `SharedPreferences`, bukan basis data: profil adalah delapan
/// nilai skalar tanpa relasi, dan memindahkannya ke SQLite tidak membeli apa
/// pun. Yang akan memindahkannya nanti adalah kewajiban enkripsi data
/// kesehatan (rencana-produksi.md §10), bukan bentuk datanya.
library;

import 'package:shared_preferences/shared_preferences.dart';

import '../services/profil_server_service.dart';
import 'sesi_login_repository.dart';

class Profil {
  const Profil({
    required this.nama,
    required this.tanggalLahir,
    required this.jenisKelamin,
    required this.tinggi,
    required this.berat,
    required this.golonganDarah,
    required this.email,
    required this.telepon,
  });

  /// Profil yang belum diisi sama sekali.
  ///
  /// Menggantikan identitas demo ("Lathifa", dst.) yang dulu disodorkan ke
  /// setiap pengguna baru. Data kesehatan milik orang lain yang tampil sebagai
  /// milik sendiri bukan sekadar tampilan sementara yang salah — tinggi dan
  /// berat badan ikut menentukan angka yang ditafsirkan pengguna.
  static const Profil kosong = Profil(
    nama: '',
    tanggalLahir: '',
    jenisKelamin: '',
    tinggi: '',
    berat: '',
    golonganDarah: '',
    email: '',
    telepon: '',
  );

  /// Apakah profilnya sama sekali belum diisi — dipakai layar untuk memutuskan
  /// antara menampilkan data dan mengajak melengkapi.
  bool get belumDiisi => nama.isEmpty && email.isEmpty && telepon.isEmpty;

  final String nama;
  final String tanggalLahir;
  final String jenisKelamin;
  final String tinggi;
  final String berat;
  final String golonganDarah;
  final String email;
  final String telepon;

  Profil salin({
    String? nama,
    String? tanggalLahir,
    String? jenisKelamin,
    String? tinggi,
    String? berat,
    String? golonganDarah,
    String? email,
    String? telepon,
  }) => Profil(
    nama: nama ?? this.nama,
    tanggalLahir: tanggalLahir ?? this.tanggalLahir,
    jenisKelamin: jenisKelamin ?? this.jenisKelamin,
    tinggi: tinggi ?? this.tinggi,
    berat: berat ?? this.berat,
    golonganDarah: golonganDarah ?? this.golonganDarah,
    email: email ?? this.email,
    telepon: telepon ?? this.telepon,
  );
}

/// Apa yang terjadi pada satu penyimpanan profil.
///
/// Dibedakan karena kalimat yang pantas ditampilkan berbeda: yang satu selesai,
/// yang lain selesai **di ponsel ini saja** dan masih menunggu jaringan.
enum StatusSimpanProfil {
  /// Tersimpan di ponsel dan sudah sama dengan server.
  tersinkron,

  /// Tersimpan di ponsel saja — belum masuk, atau server tidak terjangkau.
  lokalSaja,
}

class ProfilRepository {
  const ProfilRepository({this.server, this.sesiLogin});

  /// Profil di sisi akun. null berarti aplikasi ini memang tidak bicara dengan
  /// server — dan itu keadaan yang sah, bukan kegagalan: seluruh aplikasi jalan
  /// penuh tanpa backend (§2 aturan 3). Beranda sengaja memakai bentuk tanpa
  /// server ini, karena ia memuat nama pada **setiap** build.
  final ProfilServerService? server;

  /// Sumber token. Tanpa token, tidak ada yang bisa ditanyakan ke server, dan
  /// itu pula yang terjadi sebelum pengguna masuk.
  final SesiLoginRepository? sesiLogin;

  // Kunci lama dipertahankan persis supaya profil yang sudah tersimpan di
  // perangkat tidak hilang saat aplikasi diperbarui.
  static const _kNama = 'user_name';
  static const _kTanggalLahir = 'user_dob';
  static const _kJenisKelamin = 'user_gender';
  static const _kTinggi = 'user_height';
  static const _kBerat = 'user_weight';
  static const _kGolonganDarah = 'user_blood_type';
  static const _kEmail = 'user_email';
  static const _kTelepon = 'user_phone';

  /// Kapan salinan lokal terakhir diubah. Kunci baru — profil lama tidak
  /// memilikinya, dan ketiadaannya dibaca sebagai "belum pernah disunting di
  /// ponsel ini", sehingga server yang menang.
  static const _kDiperbarui = 'user_updated_at';

  /// Email akun yang profil ini miliknya. Bukan [Profil.email] — yang itu
  /// diketik pengguna dan tidak ada di server (§5.1) — melainkan penanda
  /// kepemilikan, dipakai [sinkronSetelahMasuk] untuk mengenali pergantian
  /// pengguna di satu ponsel.
  static const _kEmailAkun = 'user_account_email';

  Future<Profil> muat() async {
    final prefs = await SharedPreferences.getInstance();

    // Nilai kosong diperlakukan sama dengan belum pernah diisi. Sebelumnya
    // hanya Beranda yang melakukannya, sehingga menyimpan nama kosong membuat
    // Beranda menyapa dengan nama bawaan sementara Profil menampilkan kosong.
    String ambil(String kunci) => prefs.getString(kunci) ?? '';

    return Profil(
      nama: ambil(_kNama),
      tanggalLahir: ambil(_kTanggalLahir),
      jenisKelamin: ambil(_kJenisKelamin),
      tinggi: ambil(_kTinggi),
      berat: ambil(_kBerat),
      golonganDarah: ambil(_kGolonganDarah),
      email: ambil(_kEmail),
      telepon: ambil(_kTelepon),
    );
  }

  /// Profil untuk ditampilkan, **setelah** disamakan dengan server.
  ///
  /// Aturannya satu, dan sama dengan §7.1 aturan 2: yang stempelnya lebih baru
  /// menang. Yang kalah bukan berarti hilang — kalau justru salinan lokal yang
  /// lebih baru, ia langsung didorong ke server, sehingga suntingan yang dibuat
  /// saat tanpa sinyal tetap sampai pada pembukaan halaman berikutnya.
  ///
  /// Tanpa server, tanpa token, atau tanpa jaringan, ia mengembalikan salinan
  /// lokal apa adanya. Halaman profil tidak boleh berubah menjadi layar galat
  /// hanya karena sedang di luar jangkauan.
  Future<Profil> muatSegar() async {
    final lokal = await muat();
    final layanan = server;
    final token = (await sesiLogin?.muat())?.token;
    if (layanan == null || token == null) return lokal;

    final dariServer = await layanan.ambil(token);
    if (dariServer == null) return lokal;

    final stempelLokal = await _stempelLokal();
    final stempelServer = dariServer.diperbaruiPada;
    if (stempelLokal != null &&
        (stempelServer == null || stempelLokal.isAfter(stempelServer))) {
      await layanan.kirim(token, lokal);
      return lokal;
    }

    // Email dan nomor HP tidak ada di §5.1, jadi jawaban server tidak pernah
    // menimpanya — kalau tidak, keduanya akan terhapus setiap kali profil
    // ditarik dari server.
    final gabungan = dariServer.profil.salin(
      email: lokal.email,
      telepon: lokal.telepon,
    );
    await _simpanLokal(gabungan, stempel: stempelServer);
    return gabungan;
  }

  /// Dipanggil sekali tepat setelah masuk berhasil.
  ///
  /// Ada dua alasannya, dan yang kedua tidak terlihat sampai ia terjadi.
  ///
  /// Yang pertama: pada pemasangan baru, salinan lokalnya kosong, sehingga
  /// Beranda menyapa tanpa nama dan Profil tampak belum diisi — padahal
  /// akunnya punya semua data itu. Menariknya baru saat halaman Informasi
  /// Pribadi dibuka berarti pengguna harus menemukan halaman itu sendiri lebih
  /// dulu.
  ///
  /// Yang kedua: satu ponsel bisa dipakai dua orang. Kalau [emailAkun] berbeda
  /// dari yang tersimpan, seluruh profil lokal **dibuang** lebih dulu — kalau
  /// tidak, field yang tidak ada di server (email dan nomor HP, §5.1) akan
  /// tetap menampilkan milik pengguna sebelumnya, dan penyamaan dengan server
  /// tidak akan pernah membersihkannya.
  Future<Profil> sinkronSetelahMasuk(String emailAkun) async {
    final prefs = await SharedPreferences.getInstance();
    final pemilikLama = prefs.getString(_kEmailAkun) ?? '';

    if (pemilikLama.isNotEmpty && pemilikLama != emailAkun) {
      await hapusLokal();
    }
    if (emailAkun.isNotEmpty) {
      await prefs.setString(_kEmailAkun, emailAkun);
      // Email akun dipakai sebagai isian awal supaya Profil tidak tampak
      // kosong; pengguna tetap bebas menggantinya.
      if ((prefs.getString(_kEmail) ?? '').isEmpty) {
        await prefs.setString(_kEmail, emailAkun);
      }
    }
    return muatSegar();
  }

  /// Mengosongkan salinan lokal. Tidak menyentuh server dan tidak menyentuh
  /// riwayat sesi — keduanya bukan milik halaman profil.
  Future<void> hapusLokal() async {
    final prefs = await SharedPreferences.getInstance();
    for (final kunci in const [
      _kNama,
      _kTanggalLahir,
      _kJenisKelamin,
      _kTinggi,
      _kBerat,
      _kGolonganDarah,
      _kEmail,
      _kTelepon,
      _kDiperbarui,
    ]) {
      await prefs.remove(kunci);
    }
  }

  Future<DateTime?> _stempelLokal() async {
    final prefs = await SharedPreferences.getInstance();
    return DateTime.tryParse(prefs.getString(_kDiperbarui) ?? '');
  }

  /// Menyimpan, lalu mengirimkannya ke server bila memungkinkan.
  ///
  /// Urutannya tidak boleh dibalik dan pengirimannya tidak boleh menghalangi:
  /// penyimpanan lokal harus selesai walau jaringan mati, karena di situlah
  /// aplikasi ini sebenarnya hidup.
  Future<StatusSimpanProfil> simpan(Profil profil) async {
    await _simpanLokal(profil, stempel: DateTime.now());

    final layanan = server;
    final token = (await sesiLogin?.muat())?.token;
    if (layanan == null || token == null) return StatusSimpanProfil.lokalSaja;

    final terkirim = await layanan.kirim(token, profil);
    return terkirim
        ? StatusSimpanProfil.tersinkron
        : StatusSimpanProfil.lokalSaja;
  }

  Future<void> _simpanLokal(Profil profil, {DateTime? stempel}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNama, profil.nama);
    await prefs.setString(_kTanggalLahir, profil.tanggalLahir);
    await prefs.setString(_kJenisKelamin, profil.jenisKelamin);
    await prefs.setString(_kTinggi, profil.tinggi);
    await prefs.setString(_kBerat, profil.berat);
    await prefs.setString(_kGolonganDarah, profil.golonganDarah);
    await prefs.setString(_kEmail, profil.email);
    await prefs.setString(_kTelepon, profil.telepon);
    if (stempel != null) {
      await prefs.setString(_kDiperbarui, stempel.toIso8601String());
    }
  }
}
