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

## Mode build (`--dart-define`)

Perilaku aplikasi bisa diubah saat build dengan `--dart-define`. Semuanya mati kalau tidak disebut, jadi `flutter run` dan `flutter build apk` biasa memakai jam sungguhan, kamera sungguhan, server sungguhan, dan jadwal sesi normal.

| Define | Nilai | Fungsi |
| --- | --- | --- |
| `PAKAI_JAM_PALSU` | `true` | Memakai jam tiruan, bukan jam Bluetooth sungguhan. Jam tiruan selalu tersambung (baterai 68%), menekan tombol Selesai Makan sendiri sekitar 2 detik setelah foto, dan langsung menjawab perintah ukur. Untuk demo atau uji tanpa perangkat keras. |
| `PAKAI_KAMERA_PALSU` | `true` | Kamera tidak dibuka. Tombol potret langsung menghasilkan foto contoh. Untuk emulator tanpa kamera, atau supaya tidak perlu memotret piring setiap kali menguji. Sesi, kartu gizi, dan alur jam tetap berjalan seperti biasa. |
| `PAKAI_AUTH_PALSU` | `true` | Masuk/daftar tanpa server. Akun demo: `test@email.com` / `rahasia123`. |
| `BASIS_URL_API` | URL tanpa `/` di ujung | Alamat server API. Bawaannya `https://asawatch.enumatechnology.com`. Untuk server lokal: `http://10.0.2.2:8080` dari emulator, atau `http://<IP-laptop>:8080` dari HP fisik di WiFi yang sama. Alamat `http://` harus terdaftar di `android/app/src/debug/res/xml/network_security_config.xml`. Kalau tidak, aplikasi melapor "Tidak ada koneksi internet" walau servernya hidup. |
| `PAKAI_JADWAL_UJI` | `true` | Mempercepat jadwal sesi (titik +1 jam dan +2 jam, batas waktu tiap titik, tenggat) supaya satu sesi tidak perlu ditunggu 2,5 jam. Berlaku untuk sesi makan dan sesi puasa, dan bisa dipakai dengan jam sungguhan. Sesi yang dibuat dalam mode ini ditandai sebagai sesi uji. |
| `FAKTOR_JADWAL_UJI` | angka, bawaan `60` | Seberapa cepat jadwal uji. Hanya berlaku bersama `PAKAI_JADWAL_UJI`. `60`: +1 jam jadi 1 menit, sesi penuh ±2,5 menit. Cocok untuk jam palsu. `12`: +1 jam jadi 5 menit, sesi penuh ±12 menit. Pakai ini untuk jam sungguhan dan untuk menguji alarm. |
| `ID_KLIEN_GOOGLE` | client ID **Web** dari Google Cloud | Mengaktifkan tombol masuk dengan Google. Sudah ada nilai bawaannya. Isi kosong (`ID_KLIEN_GOOGLE=`) untuk menyembunyikan tombolnya. Jangan diisi client ID Android: pemilih akun tetap muncul, tapi proses masuknya diam tanpa hasil. |

Nilai-nilai ini dibaca **saat aplikasi di-build**. Mengubahnya butuh `flutter run` ulang; hot reload dan hot restart tidak cukup.

### Kombinasi yang sering dipakai

```bash
# Demo lengkap tanpa perangkat keras dan tanpa server
flutter run --dart-define=PAKAI_JAM_PALSU=true --dart-define=PAKAI_KAMERA_PALSU=true --dart-define=PAKAI_AUTH_PALSU=true

# Uji sesi dan alarm pengukuran dengan jam palsu (alarm +1 jam ±4,5 menit setelah mulai)
flutter run --dart-define=PAKAI_JAM_PALSU=true --dart-define=PAKAI_KAMERA_PALSU=true --dart-define=PAKAI_JADWAL_UJI=true --dart-define=FAKTOR_JADWAL_UJI=12

# Uji sesi dengan jam sungguhan, jadwal dipercepat 12x
flutter run --dart-define=PAKAI_JADWAL_UJI=true --dart-define=FAKTOR_JADWAL_UJI=12

# Jam sungguhan + server Laravel lokal dari HP fisik
flutter run --dart-define=BASIS_URL_API=http://192.168.1.10:8080
```

### Menguji alarm pengukuran

Dengan `FAKTOR_JADWAL_UJI=12`, alarm titik +1 jam berbunyi **saat hitung mundur di layar sesi mencapai 0** (4 menit 35 detik setelah sesi mulai), dan alarm +2 jam sekitar menit ke-9:10. Alarm berbunyi terus sampai notifikasinya diketuk dan **"Oke, Jam Sudah Dipakai"** ditekan, atau sampai batas waktu titik itu habis. Beberapa hal yang perlu diperhatikan:

- Mulai **sesi baru** setelah build. Sesi yang dimulai di build lama lalu dilanjutkan di build baru tidak bisa dipakai untuk menilai alarm.
- Tinggalkan aplikasi dengan tombol **Home** atau kunci layar. Di ponsel Xiaomi, menggeser aplikasi dari daftar aplikasi terbaru bisa ikut membatalkan alarmnya.
- Jangan menekan tombol "Ukur … sekarang" di layar sesi. Tombol itu juga dihitung sebagai konfirmasi, jadi alarmnya ikut mati.
- Volume **alarm** ponsel harus di atas 0. Alarm memakai volume alarm, bukan volume media atau dering.
- Android 15 meredam notifikasi beruntun dari aplikasi yang sama. Kalau dua tes berdekatan dan yang kedua tidak bergetar, tunggu 2–3 menit lalu coba lagi.
- Di build debug, **Profil → Status Perangkat** punya kotak "Uji alarm (debug)" untuk memunculkan alarm seketika tanpa menjalankan sesi.

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
