# Cara Kerja AsaWatch — Rangkuman

Dokumen ini merangkum *bagaimana* aplikasi bekerja dari ujung ke ujung. Ia bukan dokumen
normatif — yang mengikat tetap `docs/protokol-jam.md` (jam), `docs/jadwal-titik-ukur.md`
(jadwal), `docs/rancangan-ui-sesi-makan.md` (UI sesi), `docs/alur-pemasangan-jam.md`
(pemasangan), dan `docs/rancangan-api-laravel.md` (server). Bila rangkuman ini berselisih dengan
salah satunya, dokumen itulah yang benar.

## 1. Apa yang dilakukan aplikasi ini

AsaWatch adalah pendamping jam tangan pintar untuk memantau **respons gula darah terhadap
makanan**. Satu unit kerjanya adalah **sesi makan** (`SesiMakan`): pengguna memotret piring,
menekan tombol di jam saat selesai makan, lalu jam mengukur empat titik — sebelum makan
(baseline), tepat setelah makan (t0), +1 jam, dan +2 jam. Setiap titik membawa empat metrik
sekaligus (gula darah, detak jantung, tekanan darah, SpO₂). Dari empat titik itu aplikasi
menghitung puncak, delta, dan kualitas respons (landai / sedang / lonjakan), lalu
membandingkannya lintas sesi di tab Analisis.

Seluruh teks antarmuka dan penamaan kode memakai Bahasa Indonesia. Target satu-satunya adalah
Android.

## 2. Susunan lapisan

```
UI (lib/*.dart, lib/widgets/)
   │  membaca satu ChangeNotifier
   ▼
SesiMakanController (lib/controllers/)
   │  mengorkestrasi semuanya
   ├─► BleService        ── jam (BleAsliService | FakeBleService)
   ├─► KameraService     ── kamera (KameraAsliService | KameraPalsuService)
   ├─► NutrisiService    ── angka gizi (masih FakeNutrisiService)
   ├─► SesiServerService ── unggah/unduh sesi (SesiHttpService)
   ├─► PengingatTitikUkur── notifikasi lokal
   ├─► LayananLatar      ── foreground service Android
   └─► Repository (lib/repositories/) ── SQLite lewat drift
```

Tiga prinsip yang menjelaskan hampir semua bentuk kode:

1. **Tidak ada lapisan API umum.** Yang ada adalah *seam* per kebutuhan: setiap hal yang tidak
   bisa dijalankan di `flutter_test` (radio BLE, kamera, notifikasi, Google Sign-In, foreground
   service, HTTP) punya kontrak abstrak + implementasi asli + implementasi palsu. Yang palsu
   **tidak pernah dihapus** — ia tulang punggung test dan satu-satunya cara demo tanpa perangkat.
2. **Satu pengelola state saja**: `SesiMakanController`, disediakan lewat satu
   `ChangeNotifierProvider` di atas `MaterialApp`, karena sampel dari jam bisa tiba kapan saja
   dari tab mana pun. Di luar permukaan sesi, penyegaran antar-halaman dilakukan dengan
   `Navigator.pop(hasil)`, bukan state manager.
3. **Semua tersimpan lokal dulu, server menyusul.** Aplikasi harus tetap utuh tanpa akun dan
   tanpa sinyal. Server hanya menerima salinan.

## 3. Alur satu sesi makan

```
 [Foto]      [Tombol jam]      [+1 jam]       [+2 jam]      [tenggat]
 baseline ─► t0 ──────────────► index 2 ────► index 3 ────► selesai /
 (idx 0)    (idx 1)             ARM_TITIK      ARM_TITIK     tidakLengkap
 draft ──────► berjalan ─────────────────────────────────► riwayat
```

1. **Foto** (`DeteksiMakananPage`). Kamera sungguhan; berkas disalin ke
   `<documents>/foto_makanan/` agar `fotoPath` tetap sah berbulan-bulan. Saat rana ditekan:
   sesi `draft` dibuat dan disimpan, baseline diminta ke jam (`mintaUkur` index 0), jam
   di-*arm* (`siapkanSesi`), dan — bila ada token — draft diunggah, foto diunggah, analisis gizi
   diminta ke server (`mintaAnalisis` menyembunyikan polling 202). Tanpa token,
   `NutrisiService` yang menjawab.
2. **t0 selalu milik jam.** Sesi mulai hanya ketika jam melaporkan tombol "Selesai Makan"
   ditekan. Tombol "Saya Sudah Selesai Makan" di aplikasi tidak menghitung t0 sendiri; ia
   mengirim `MULAI_SESI` yang membuat jam *menekan tombolnya sendiri*, sehingga t0 tetap di
   garis waktu pencacah jam dan sebanding dengan `uptime_s` setiap sampel. Kedua rute bertemu
   di satu widget: `PetunjukTombolJam`.
3. **Jadwal ada di aplikasi, bukan firmware** (protokol v1.3; `JadwalSesi` di
   `lib/models/jadwal_sesi.dart`). Jam tidak tahan menyala >50 menit, jadi aplikasi yang
   mengingatkan (dua notifikasi per titik: T−5 menit dan T), menyalakan tombol ukur jam
   satu titik pada satu waktu (`ARM_TITIK`), dan menjaga proses tetap hidup dengan foreground
   service (`LayananLatar`) selama sesi aktif. Tiap titik punya jendela toleransi; terlalu awal
   ditolak, terlalu telat ditandai `terlewat`.
4. **Sampel masuk** lewat `BleService.sampelMasuk`. Controller mencocokkan `(sesiId, index)`,
   menyimpan ke SQLite, lalu mengunggah ulang sesi aktif agar server bisa mengikutinya.
5. **Sesi berakhir** dengan salah satu: empat sampel lengkap (`selesai`), tenggat 30 menit
   setelah +2 jam lewat (`tidakLengkap` — ditunda selama jam terbukti sedang mengukur), pengguna
   memilih "Selesaikan Sesi" (`akhiriLebihAwal`, data yang ada disimpan), atau "Batalkan Sesi"
   (`batalkan`, baris jadi *tombstone* yang dikirim ke server sebagai `DELETE`).
6. **Ringkasan** (`RingkasanSesiPage`): kurva gula darah, tekanan darah, SpO₂ (bila bermakna),
   kartu gizi dengan foto, tabel per titik. Aturannya: satu angka, satu tempat.

## 4. Jam (BLE)

- `BleAsliService` di atas `flutter_blue_plus` (dipin 1.x karena lisensi 2.x). Byte ↔ Dart
  dipisah ke `protokol_jam.dart` yang murni dan diuji per offset.
- **Jam tidak punya RTC.** Ia hanya mengirim `uptime_s` + `boot_id`. Aplikasi menulis
  `ANCHOR_WAKTU` di setiap koneksi dan mengonversi lewat `AnchorWaktu.keWaktu`. Boot yang tak
  pernah tersambung tidak punya jangkar → sesi ditandai `waktuTidakPasti` (tetap ditampilkan,
  dikeluarkan dari analisis).
- **`detikRelatifT0` adalah selisih dua pencacah**, bukan dua waktu kalender, sehingga bentuk
  kurva selalu tepat meski jangkar meleset.
- **ACK hanya setelah baris tersimpan.** Jam menghapus entri begitu di-ACK, jadi urutannya
  `simpan → ack → emit`; `tabel_entri_jam` adalah kotak masuk mentahnya, dan yang belum
  diproses diputar ulang saat aplikasi mulai.
- **Pemasangan** (`PemindaianPerangkatPage`): izin dulu (`IzinBle`), pindai difilter ke UUID
  layanan AsaWatch di level OS, `createBond()` eksplisit sebelum `discoverServices()`.
  `sambungkan()` mengembalikan `HasilSambung` (bukan bool) karena tindak lanjut tiap sebab
  berbeda; hanya `bondBasi` yang menawarkan "lupakan penyandingan". Perangkat yang dipasangkan
  disimpan (`PerangkatRepository`) sehingga "belum pernah dipasang" dan "di luar jangkauan"
  bisa dibedakan. Penyandingan tidak pernah dimulai dari latar belakang.
- **Pengukuran dibuktikan oleh denyut**, bukan oleh perintah yang terkirim: Status 10 byte
  dikirim tiap 2 detik selama mengukur (`KemajuanUkur`), dan bila denyut berhenti aplikasi
  *membaca* karakteristik Status sebelum menyerah. `PesanUkur` punya kalimat berbeda untuk
  delapan kejadian.
- **Baterai kritis** (<10%, ambang milik firmware) membuat jam menolak mengukur;
  `alasanJamTidakBisaUkur` adalah satu kalimat yang dipakai empat permukaan.
- `KemampuanPerangkat` dari handshake menentukan metrik mana yang ditampilkan — metrik yang tak
  ada sensornya *dihilangkan*, bukan ditulis `—`; null berarti "tampilkan semua"; nilai yang
  sudah ada tak pernah disembunyikan.
- **Pindai kesehatan** di luar sesi (`PindaiKesehatanPage`) memakai `UKUR_SEKARANG`, menunggu
  sampel ber-`sesiId` nol, dan hasilnya hanya di memori.
- **Kalibrasi tekanan darah**: metode manset berpasangan, **satu putaran**, manset di lengan
  yang berlawanan dan diukur bersamaan; angka jam disembunyikan sampai angka manset diketik;
  koreksi >30 mmHg (`masukAkal`) dianggap pengukuran gagal; kedaluwarsa 4 minggu adalah
  penilaian aplikasi (jam hanya menerima dua offset lewat `SET_KALIBRASI`).

## 5. Penyimpanan lokal

| Data | Tempat | Catatan |
| --- | --- | --- |
| Sesi, sampel, gizi, item makanan | SQLite (drift), `SesiRepositoryDrift` | skema **v7**; enum via `textEnum` → mengganti nama anggota = migrasi |
| Jangkar waktu jam | `tabel_anchor_waktu` | milik perangkat keras, tidak dihapus saat ganti akun |
| Kotak masuk mentah jam | `tabel_entri_jam` | kolom berupa angka protokol, bukan `textEnum` |
| Kalibrasi + putaran | `tabel_kalibrasi`, `tabel_putaran_kalibrasi` | per orang, dihapus saat ganti akun |
| Profil | `SharedPreferences` (`user_*`) lewat `ProfilRepository` | separuh offline dari §5.1 server |
| Jam yang dipasangkan | `SharedPreferences` (`PerangkatRepository`) | |
| Token login | `flutter_secure_storage` (`SesiLoginRepositoryAman`) | bukan preferences: ini kunci data kesehatan |

Aturan yang menentukan bentuknya:

- `main()` memuat riwayat **sebelum** `runApp` dan memberikannya sebagai `riwayatAwal`, jadi
  tidak ada layar sesi yang perlu state "memuat". Controller memisahkan sesi yang masih
  berjalan saat aplikasi ditutup dan menghitung ulang jadwalnya dari `t0` absolut.
- `onUpgrade` berjalan satu versi per langkah dengan cabang `default` yang melempar — versi
  skema tidak bisa naik tanpa migrasi tertulis. Langkah v3→v4 memeriksa `PRAGMA table_info`
  karena `createTable` di langkah lebih awal membuat bentuk *hari ini*.
- Nilai turunan (verdict, kualitas respons) tidak punya kolom; dihitung saat dimuat.
- `diperbaruiPada` distempel oleh repository, bukan pemanggil, dan `simpan()` mengembalikan
  stempelnya untuk diterapkan ke salinan di memori — inilah yang mencegah 409 `konflik_versi`.
- Basis data gagal dibuka → `AplikasiGagalMulai`; sesi gagal disimpan →
  `galatPenyimpanan` sebagai kartu peringatan tetap di Beranda.

## 6. Akun dan server

- **Masuk**: `AuthService.masuk()` mengembalikan `HasilMasuk` yang *sealed* (`KredensialSalah`,
  `TidakAdaJaringan`, `ServerBermasalah`, `WaktuHabis`, `EmailSudahDipakai`), masing-masing
  dengan salinan dan aturan "bisa diulang"-nya sendiri. `galat.kode` dibaca sebelum status HTTP
  karena kata sandi salah dijawab 422. Masuk dengan Google lewat `GoogleMasukService` menukar ID
  token (bukan access token) ke server. Daftar langsung mengembalikan token — tidak ada langkah
  "sekarang masuk".
- **Token** Sanctum 30 hari tanpa refresh. `muat()` menghapus sesi kedaluwarsa. 401 dari
  endpoint ber-token mana pun (kecuali `masuk`) memicu `PenjagaSesi`: token dihapus, kembali ke
  `/welcome`. Keluar mencabut token di server dulu, tapi tetap berhasil tanpa sinyal.
- **Ganti akun di satu ponsel**: `ProfilRepository.sinkronSetelahMasuk()` mendeteksinya dan
  `hapusDataLokal()` membuang riwayat sesi, berkas foto, kalibrasi, dan kotak masuk jam —
  **sebelum** unggahan pertama, agar makanan orang sebelumnya tidak masuk ke akun baru. Jam dan
  jangkar waktunya tetap. Keluar biasa tidak menghapus apa pun.
- **Unggah sesi** (`PUT /sesi/{id}`, upsert): saat draft dibuat, tiap titik terisi, saat
  selesai, dan sapuan seluruh riwayat (`kirimRiwayatKeServer`) di awal, saat kembali ke depan,
  dan setelah masuk. Tidak ada kolom "terkirim" — id adalah UUID dan kirim ulang gratis.
  Kegagalan hanya `debugPrint`. Sesi uji ikut diunggah dengan `sesi_uji: true`.
- **Unduh** (`GET /sesi`, mengikuti `next_cursor`): sesi yang sudah ada lokal tidak pernah
  ditimpa, sesi yang masih berjalan di server dilewati, gagal mengambil = `null` bukan daftar
  kosong. Offset baseline dihitung ulang dari `waktuFoto − t0`, tidak dipercaya dari kawat.
  Foto diunduh lewat URL bertanda tangan (kedaluwarsa satu jam, terikat host, tetap butuh token)
  dan hanya berkasnya yang disimpan.
- **Batal** = tombstone (`dihapus_pada`) yang disapu lebih dulu sebelum unggah dan unduh; 404
  dihitung berhasil.
- Nama status di kawat `snake_case` (`statusKeKawat`/`statusDariKawat`), bukan `StatusSesi.name`.
- Jaringan: `INTERNET` ada di manifest rilis; HTTP polos hanya diizinkan per-alamat di
  `network_security_config.xml` debug.

## 7. Gizi

`Nutrisi` punya enam angka `double?` — **tidak diketahui bukan nol**. `null + null` tetap null,
`null × faktor` tetap null, dan `zatTidakLengkap` menandai jumlah parsial (ditulis `≥ 459`).
`AnalisisSesi` membuang sesi yang karbohidratnya tak diketahui. Spinner di kartu gizi hanya
muncul saat permintaan analisis benar-benar berjalan (`sedangMenganalisis`), selebihnya
"Rincian makanan tidak tersedia". Angka gizi masih dari `FakeNutrisiService`; deteksi
sungguhan (model Gemini di layanan Python) tinggal disambungkan lewat seam `NutrisiService`.

## 8. Navigasi dan tampilan

- Rute bernama hanya untuk cangkang auth (`/welcome`, `/login`, `/register`, `/home`);
  selebihnya `MaterialPageRoute` anonim. `LoginPage` memakai `pushAndRemoveUntil` sehingga
  Beranda adalah dasar tumpukan; `PopScope` di `MyHomePage` mengembalikan ke Beranda dulu dari
  tab lain.
- Bilah bawah dirakit sendiri di atas `IndexedStack` lima tab; indeks 2 adalah tombol bulat
  yang selalu *mendorong* halaman (kamera saat idle, Sesi Berjalan saat ada sesi) — bukan tab.
- Beranda punya dua tingkat kartu (`_dekorasiUtama` untuk satu hal yang meminta perhatian,
  `_dekorasiSekunder` untuk yang sekadar tersedia), tiap kartu utama satu angka hero 36 px,
  dan tanpa target harian bawaan — perbandingan kembali hanya bila pengguna bisa menetapkan
  targetnya sendiri.
- Semua grafik adalah `CustomPainter` (`KurvaSampelPainter` dikonfigurasi `SeriMetrik`);
  sumbu x diturunkan dari sampel, tidak pernah dari literal; setiap `TextStyle` di painter wajib
  `fontFamily: fontPainter`.
- Gaya: `Scaffold` + `SingleChildScrollView`, satu berkas per layar, `TextStyle`/`BoxDecoration`
  literal dengan palet hex tetap (hijau utama `0xFF0EAD69`, teks `0xFF1E3A34`, latar
  `0xFFF4FAF7`). Font Montserrat dibundel.
- Gaya bilah sistem terang dipasang di `MyApp.builder` lewat `AnnotatedRegion`, agar layar
  kamera yang gelap tidak meninggalkan bilah hitam setelah ditutup.

## 9. Mode pengembangan

| `--dart-define` | Efek |
| --- | --- |
| `PAKAI_JAM_PALSU=true` | `FakeBleService`, tanpa perangkat keras; `percepatan: 360` |
| `PAKAI_JADWAL_UJI=true` (+ `FAKTOR_JADWAL_UJI=12`) | jadwal dipadatkan; sesi ditandai `sesi_uji` |
| `PAKAI_KAMERA_PALSU=true` | `KameraPalsuService`, kamera tidak dibuka |
| `PAKAI_AUTH_PALSU=true` | `FakeAuthService`, akun demo `test@email.com` / `rahasia123` |
| `BASIS_URL_API=…` | alamat server (emulator: `http://10.0.2.2:8080`) |

Perintah inti: `flutter pub get`, `flutter run`, `dart run build_runner build` (setelah ubah
skema), `flutter analyze`, `flutter test`, `flutter build apk`.

## 10. Pengujian

`test/widget_test.dart` menjalankan alur sungguhan (welcome → login → tab). Setiap test sesi
memakai `pumpHalaman`/`buatControllerUji` di `test/helpers.dart` (controller + `FakeBleService`
`percepatan: 3600`, tombol jam ditekan lewat `tekanTombolJam`), memuat Montserrat lewat
`loadMontserrat()`, memakai viewport 412×915, membungkus `BerandaTab` dalam `Scaffold`, dan
menghentikan sesi (`hentikanSesi`) sebelum test berakhir karena `flutter_test` memeriksa timer
tertunda. Semua yang menyentuh platform channel diberi tiruannya: `FakeAuthService`,
`KameraPalsuService`, `IzinBleSelaluBoleh`, `GoogleMasukPalsu`, pengingat dan layanan latar
diam. `BleAsliService` sengaja tanpa unit test — semua yang bisa dipisahkan dari radio sudah
dipindah ke `protokol_jam.dart`, repository, dan controller; sisanya diuji lewat daftar
integrasi protokol §11 dengan firmware.

## 11. Yang belum ada

- Backend deteksi makanan belum tersambung (`FakeNutrisiService`).
- Firmware v1.3 (jadwal di aplikasi) dirancang tetapi belum diimplementasi di sisi jam.
- Sinkronisasi kursor §7 dan sinkronisasi kalibrasi ke server belum ditulis.
- Target kalori pengguna (Tahap F) belum ada, jadi Beranda tidak membandingkan asupan.
- iOS dideklarasikan tetapi belum pernah dibangun; web tidak bisa membuka basis data.
