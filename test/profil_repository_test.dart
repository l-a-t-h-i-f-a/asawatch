// Test untuk ProfilRepository (rencana-produksi.md §3.2, Tahap A3).

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:asawatch/repositories/profil_repository.dart';

void main() {
  const repo = ProfilRepository();

  test('perangkat kosong memberi profil kosong, bukan identitas demo', () async {
    // A4: pengguna baru tidak lagi disodori data orang lain. Tinggi dan berat
    // badan ikut menentukan angka yang ditafsirkan pengguna, jadi nilai bawaan
    // di sini bukan sekadar tampilan sementara yang salah.
    SharedPreferences.setMockInitialValues({});

    final profil = await repo.muat();

    expect(profil.nama, isEmpty);
    expect(profil.email, isEmpty);
    expect(profil.telepon, isEmpty);
    expect(profil.belumDiisi, isTrue);
  });

  test('menyimpan lalu memuat mengembalikan nilai yang sama', () async {
    SharedPreferences.setMockInitialValues({});

    const baru = Profil(
      nama: 'Rara',
      tanggalLahir: '1 Januari 2000',
      jenisKelamin: 'Laki-laki',
      tinggi: '175 cm',
      berat: '70 kg',
      golonganDarah: 'O',
      email: 'rara@contoh.id',
      telepon: '0899-0000-1111',
    );
    await repo.simpan(baru);
    final kembali = await repo.muat();

    expect(kembali.nama, baru.nama);
    expect(kembali.tanggalLahir, baru.tanggalLahir);
    expect(kembali.jenisKelamin, baru.jenisKelamin);
    expect(kembali.tinggi, baru.tinggi);
    expect(kembali.berat, baru.berat);
    expect(kembali.golonganDarah, baru.golonganDarah);
    expect(kembali.email, baru.email);
    expect(kembali.telepon, baru.telepon);
  });

  test('kunci lama di perangkat tetap terbaca', () async {
    // Kunci `user_*` dipertahankan persis; pengguna yang memperbarui aplikasi
    // tidak boleh kehilangan profilnya.
    SharedPreferences.setMockInitialValues({
      'user_name': 'Rara',
      'user_email': 'rara@contoh.id',
      'user_blood_type': 'AB',
    });

    final profil = await repo.muat();

    expect(profil.nama, 'Rara');
    expect(profil.email, 'rara@contoh.id');
    expect(profil.golonganDarah, 'AB');
    // Yang tidak tersimpan tetap kosong.
    expect(profil.tinggi, isEmpty);
    expect(profil.belumDiisi, isFalse);
  });

  test('nilai kosong tersimpan tetap terbaca sebagai kosong', () async {
    SharedPreferences.setMockInitialValues({'user_name': '', 'user_email': ''});

    final profil = await repo.muat();

    expect(profil.nama, isEmpty);
    expect(profil.email, isEmpty);
  });

}
