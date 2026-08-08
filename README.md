# AsaWatch

Aplikasi Flutter pendamping smartwatch untuk memantau kesehatan harian: detak jantung, gula darah, tekanan darah, dan tidur — dilengkapi alur deteksi makanan lewat kamera.

Seluruh antarmuka berbahasa Indonesia.

> **Status: prototipe UI.** Belum ada backend. Seluruh angka kesehatan masih data tiruan yang ditulis langsung di kode, proses masuk/daftar hanya memvalidasi form tanpa memeriksa kredensial, dan satu-satunya data yang benar-benar tersimpan adalah profil pengguna melalui `SharedPreferences`.

## Fitur

| Layar | Isi |
| --- | --- |
| Welcome / Masuk / Daftar | Alur onboarding dan autentikasi (masih tiruan) |
| Beranda | Ringkasan metrik harian + grafik ringkas |
| Riwayat | Daftar pengukuran, dapat difilter per jenis |
| Analisis | Rata-rata mingguan/bulanan beserta indikator progres |
| Profil | Informasi pribadi dan tujuan kesehatan yang tersimpan di perangkat |
| Deteksi Makanan | Layar kamera yang dibuka dari tombol tengah navigasi bawah |

## Menjalankan

Butuh Flutter SDK stable dengan Dart `^3.12.0`.

```bash
flutter pub get
flutter run              # perangkat/emulator yang terhubung
flutter run -d chrome    # versi web
```

## Pengembangan

```bash
flutter analyze                              # lint (flutter_lints)
flutter test                                 # seluruh widget test
flutter test test/widget_test.dart           # satu file
flutter test --plain-name "nama test"        # satu test
flutter build apk                            # rilis Android
```

## Struktur

```
lib/
  main.dart              # MaterialApp, rute, shell navigasi bawah
  *_tab.dart             # empat tab utama
  *_page.dart            # layar penuh (auth, detail metrik, pengaturan)
  widgets/sparkline.dart # satu-satunya widget bersama
assets/fonts/            # Montserrat (OFL, lihat assets/fonts/OFL.txt)
test/widget_test.dart    # widget test alur welcome -> login -> tab
```

Grafik digambar dengan `CustomPainter` buatan sendiri, tanpa paket charting.

## Lisensi font

Montserrat didistribusikan di bawah SIL Open Font License 1.1. Salinan lisensinya ada di [assets/fonts/OFL.txt](assets/fonts/OFL.txt).
