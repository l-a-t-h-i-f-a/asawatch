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
}

class ProfilRepository {
  const ProfilRepository();

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

  Future<void> simpan(Profil profil) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kNama, profil.nama);
    await prefs.setString(_kTanggalLahir, profil.tanggalLahir);
    await prefs.setString(_kJenisKelamin, profil.jenisKelamin);
    await prefs.setString(_kTinggi, profil.tinggi);
    await prefs.setString(_kBerat, profil.berat);
    await prefs.setString(_kGolonganDarah, profil.golonganDarah);
    await prefs.setString(_kEmail, profil.email);
    await prefs.setString(_kTelepon, profil.telepon);
  }
}
