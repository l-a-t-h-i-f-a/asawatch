# Jadwal Titik Ukur, Jendela Toleransi, dan Mode Jadwal Uji

Dokumen ini **normatif untuk sisi aplikasi**. Ia melengkapi
[protokol-jam.md](protokol-jam.md) v1.3, yang memindahkan penjadwalan sesi dari firmware ke
aplikasi — dan karena itu memindahkan seluruh isi berkas ini ke sisi yang bisa diubah tanpa flash
ulang. Tidak ada satu pun aturan di sini yang punya wakil di kawat.

Bacalah [protokol-jam.md](protokol-jam.md) §12 (v1.3) lebih dulu: ia menjelaskan **kenapa** jadwal
pindah, dan tanpa itu setengah dari keputusan di bawah terlihat sewenang-wenang.

---

## 1. Jadwal adalah data per sesi, bukan konstanta

Skema sudah menyiapkannya sejak Tahap A dan tidak perlu migrasi:
[../lib/repositories/basis_data.dart](../lib/repositories/basis_data.dart) menyimpan `TabelSampel`
dengan kunci `(sesiId, index)` dan **`detikRelatifT0` sebagai kolom per baris**. Jumlah titik tidak
dikunci di mana pun. Yang mengunci angka empat hanyalah satu daftar literal di
[../lib/controllers/sesi_makan_controller.dart](../lib/controllers/sesi_makan_controller.dart), dan
daftar itulah yang diganti menjadi objek jadwal.

Di kawat pun tidak ada batas: `index` adalah 1 byte (protokol §5.1), jadi sampai 256 titik tidak
menuntut perubahan paket apa pun.

## 2. Jadwal normal — empat titik

Tidak berubah dari sebelum v1.3. Yang berubah hanya **siapa yang memicunya** (aplikasi, bukan timer
firmware) dan bahwa daftarnya kini data, bukan literal.

| index | Nama | `detikRelatifT0` | Jendela toleransi | Kenapa |
|---|---|---|---|---|
| 0 | baseline | negatif (saat shutter) | — | Diukur saat foto diambil, sebelum `t0` ada. Tidak punya jendela: waktunya ditentukan peristiwa, bukan jadwal. |
| 1 | `t0` | 0 | — | Diukur segera saat tombol "Selesai Makan" ditekan. |
| 2 | +1 jam | 3600 | **3300–4200** (55–70 mnt) | Sempit ke belakang: puncak sesungguhnya sering jatuh sebelum menit ke-60, jadi terlambat langsung merusak `deltaPuncak`. |
| 3 | +2 jam | 7200 | **6600–9000** (110–150 mnt) | Longgar: kurvanya sudah datar, telat 20 menit hampir tidak mengubah apa pun. |

### 2.1 Titik tambahan: mungkin, tidak aktif

Jadwal ini bisa menampung titik lain tanpa perubahan skema maupun kawat (§1). Yang paling sering
akan tergoda ditambahkan adalah **+30 menit**, karena gula darah pascamakan umumnya memuncak pada
menit ke-30–45 — dengan hanya `+1 jam`, `deltaPuncak` kadang menangkap sisi turunnya dan sesi
divonis lebih landai daripada kenyataan.

**Tidak diaktifkan, dan keputusan itu sadar.** Tiap titik tambahan berarti satu notifikasi lagi,
satu kali menyalakan jam lagi, dan satu tombol lagi yang harus ditekan tepat waktu — untuk pengguna
lansia dengan jam berbaterai ~50 menit, itu bukan biaya nol. Nilai klinisnya nyata tapi belum
terbukti cukup untuk membayar biaya itu.

Bila nanti diaktifkan, dua hal harus dikerjakan lebih dulu:

- **Bug `waktuPemulihan` di §5** — ia latent selama titiknya masih empat dan berurutan waktu, dan
  langsung salah pada titik pertama yang disisipkan.
- **Ukur dulu daya jam.** `+30` dan `+1 jam` hanya berjarak 30 menit, jadi bila jam sanggup menyala
  dari menit ke-27 sampai ke-70 (±43 menit, di bawah ~50 menit), keduanya dilayani dalam **satu**
  kali penyalaan dan beban penggunanya tetap tiga kali menyentuh jam. Kalau tidak sanggup, biayanya
  jadi empat kali dan pertimbangannya berubah.

Jendela toleransinya, bila dipakai: **1620–2220 detik** (27–37 menit) — paling sempit dari semuanya,
justru karena di menit ke-30 kurvanya paling curam dan telat 8 menit di sana menggeser angka jauh
lebih banyak daripada telat 8 menit di `+2 jam`.

## 3. Terlalu cepat dan terlalu lambat bukan kesalahan yang sama

Ini aturan yang membentuk seluruh perilaku tombol:

> **Terlalu cepat masih bisa diperbaiki. Terlalu lambat tidak.**

Titik yang diukur di menit ke-45 belum melewatkan menit ke-60 — pengguna masih bisa mengukur lagi.
Titik yang baru diukur di menit ke-85 telah kehilangan menit ke-60 selamanya.

| Keadaan | Perlakuan |
|---|---|
| **Sebelum jendela** | **Tunggu.** Tombol aplikasi mati dengan hitung mundur; tombol jam belum di-`ARM_TITIK`. Ini bukan galat dan tidak menghasilkan sampel bertanda. |
| **Di dalam jendela** | Normal. `detikRelatifT0` dinormalkan ke nilai nominal bila selisihnya di bawah 2 menit (§4). |
| **Sesudah jendela** | **Terima dan tandai telat.** Datanya nyata dan tidak ada penggantinya. |

Arah kesalahannya juga berlawanan, dan keduanya perlu diketahui: mengukur **terlalu cepat** menangkap
puncak, `deltaPuncak` membesar, sesi tampak **lebih buruk** dari kenyataan. Mengukur **terlalu
lambat** melewatkan puncak, sesi tampak **lebih baik**. Yang lambat lebih berbahaya — ia menenangkan
orang yang seharusnya waspada, dan tidak ada seorang pun yang akan curiga.

### 3.1 Sampel yang telanjur datang terlalu cepat

Bisa terjadi lewat `UKUR_SEKARANG`, yang memang dilayani kapan saja. Aturannya: **jangan biarkan ia
mengisi slot titik itu.** Slotnya masih bisa diisi dengan benar, dan mengisinya lebih awal mengunci
angka yang salah pada titik yang sebenarnya belum lewat.

Tempatnya sudah ada: jadikan ia hasil `pindaiTerakhir` — bacaan lepas tanpa `t0` dan tanpa titik
pembanding, yang memang sudah punya halamannya sendiri di
[../lib/pindai_kesehatan_page.dart](../lib/pindai_kesehatan_page.dart) dan memang sengaja tidak masuk
tabel sesi. Pengguna tetap melihat angkanya; sesinya tidak tercemar.

### 3.2 Jendela dijaga sepenuhnya di sisi aplikasi

Jam tidak tahu jam berapa sekarang dan tidak perlu tahu. Yang menjaga batas awal jendela adalah
**kapan aplikasi mengirim `ARM_TITIK`**: sebelum jendelanya terbuka perintah itu tidak dikirim sama
sekali, dan tombol yang belum di-ARM tidak menghasilkan apa-apa (protokol §5.1, aturan yang sama yang
sejak v1.0 menjaga "tidak ada sesi tanpa foto makanan").

Rancangan pertama v1.3 menitipkan penundaannya ke jam lewat `2B detik_tunda`, sehingga jam yang
menyalakan tombolnya sendiri saat jendela terbuka. Itu dibuang sebelum implementasi firmware, dan
alasannya ada di protokol §9: penundaan tersebut tidak pernah selamat melewati pemutusan daya —
dan pemutusan daya adalah keadaan normal di v1.3. Karena `ARM_TITIK` sama-sama menuntut koneksi
seperti `UKUR`, tidak ada yang hilang dengan mengirimnya belakangan.

Konsekuensinya di sisi ini: `SesiMakanController` memegang satu timer (`_timerArm`) yang membangunkan
`_armTitikBerikutnya()` saat jendela terbuka. Timer itu mati bersama proses aplikasi, dan itu memang
cukup — `ARM_TITIK` menuntut koneksi BLE yang juga mati bersama proses. Yang menjaga pengguna saat
aplikasi tertutup adalah notifikasi terjadwal (§6), bukan timer ini.

## 4. `_geser` dipersempit, tidak dihapus

`SesiMakanController._terimaSampel` menormalkan `detikRelatifT0` tiap titik ke nilai nominal
jadwalnya. Alasan aslinya benar: label di layar menjanjikan "+1 jam", bukan "+1 jam 40 detik", dan
penundaan berskala detik tidak perlu terlihat.

**Alasan itu berbalik pada skala menit.** Menyembunyikan keterlambatan 25 menit bukan merapikan
label, itu memalsukan sumbu x. Aturannya jadi:

- Selisih **< 2 menit** → normalkan ke nilai nominal, label tetap "+1 jam".
- Selisih **≥ 2 menit** → simpan nilai sebenarnya, dan **labelnya ikut jujur**: "+1 jam 24 mnt".

Nilai sebenarnya sekarang gratis: aplikasi memegang `t0` sebagai `DateTime` dan tahu persis kapan ia
memerintahkan `UKUR`, jadi `detikRelatifT0` adalah selisih dua jam dinding (protokol §5.3).

## 5. Bug yang harus dibetulkan sebelum titik kelima ditambahkan

[../lib/models/sesi_makan.dart](../lib/models/sesi_makan.dart), di `waktuPemulihan`:

```dart
if (s.index <= puncak.index || !s.terisi || s.gulaDarah == null) continue;
```

Baris ini memakai **`index` sebagai pengganti urutan waktu**. Aman selama indeks 0–3 kebetulan
berurutan waktu — jadi hari ini ia **latent, bukan aktif**. Ia meledak pada titik pertama yang
disisipkan: menambahkan `+30 mnt` sebagai `index: 4` membuat titik itu terbaca sebagai "sesudah
+2 jam", dan waktu pemulihan salah dihitung **tanpa gejala apa pun**.

Diperbaiki sekarang, selagi belum ada yang bergantung padanya, karena jebakan ini justru menunggu
orang yang berikutnya menambah titik — yaitu orang yang paling tidak akan mengira ada yang rusak.

Perbaikannya: bandingkan `detikRelatifT0`, bukan `index`. Itu memang yang dimaksud kalimatnya, indeks
sesi lama tidak perlu disentuh, dan penambahan titik berikutnya tidak akan mengulang jebakan yang
sama. Menyisipkan titik baru di tengah dan menggeser indeks sisanya adalah alternatif yang
**ditolak**: ia mengubah arti indeks pada baris yang sudah tersimpan.

Ikut menyesuaikan:

- **`AnalisisSesi`** mencocokkan titik lintas sesi berdasarkan `detikRelatifT0`, bukan `index`, dan
  hanya membandingkan titik yang ada di **kedua** sesi. Ini tidak mengubah apa pun hari ini, dan
  itulah gunanya: sesi lama tetap sebanding pada saat sebuah titik ditambahkan nanti.
- **Sesi dengan titik telat dikeluarkan dari tren lintas sesi**, atau minimal ditandai di sana.
  Membandingkan puncak yang diukur di menit ke-60 dengan yang diukur di menit ke-85 menghasilkan
  garis tren yang mengukur ketepatan pengguna menekan tombol, bukan kesehatannya.
- **Label sumbu x** di `KurvaSampelPainter` akan lebih sering bertabrakan bila titik bertambah.
  Mekanisme turun ke baris kedua sudah ada, tapi perlu dicek ulang di layar sempit saat itu terjadi.

## 6. Notifikasi jadi bagian yang tidak bisa dilepas

Jendela ±10 menit hanya masuk akal bila pengguna diberi tahu tepat waktu, dan sejak jam tidak lagi
menjadwalkan sendiri, **tidak ada yang mengingatkan selain aplikasi**. Dua notifikasi per titik:

1. **T−5 menit** — "siapkan jam, nyalakan sekarang". Menyalakan jam dan memasangnya butuh waktu.
2. **T** — "ukur sekarang".

Notifikasi yang baru berbunyi tepat di detik ke-3600 sudah pasti menghasilkan pengukuran yang telat.

Konsekuensi teknis: dependensi baru (`flutter_local_notifications`), izin `POST_NOTIFICATIONS` di
Android 13+, dan penjadwalannya harus tahan aplikasi ditutup — jadi `zonedSchedule`, bukan `Timer`.

## 7. Mode jadwal uji

Menguji sesi penuh tidak boleh menuntut menunggu dua jam. Mode ini mengecilkan **jadwal**, bukan
memalsukan apa pun yang lain — jendela toleransi, tenggat, `ARM_TITIK`, dan seluruh alur BLE berjalan
apa adanya, hanya dengan angka yang dibagi 60.

```bash
flutter run --dart-define=PAKAI_JADWAL_UJI=true
```

Faktor 60 dipilih supaya setiap "menit" jadwal normal menjadi satu detik, sehingga angkanya bisa
dibaca langsung tanpa aritmetika:

| Titik | Normal | Uji |
|---|---|---|
| +1 jam | 3600 s, jendela 3300–4200 | 60 s, jendela 55–70 |
| +2 jam | 7200 s, jendela 6600–9000 | 120 s, jendela 110–150 |
| Tenggat sampel terakhir | +30 mnt | +30 s |

Sesi penuh selesai dalam **dua menit**. Titik tambahan apa pun ikut mengecil dengan faktor yang sama.

**Firmware tidak perlu tahu apa-apa tentang mode ini.** `ARM_TITIK` membawa `detik_tunda` yang
dihitung aplikasi, jadi tunda 30 detik dilayani persis seperti tunda 1800 detik. Itu berarti mode uji
bekerja dengan **jam sungguhan**, bukan hanya dengan `FakeBleService` — dan itulah nilai utamanya:
integrasi hardware bisa diuji end-to-end berkali-kali dalam satu sore.

`FakeBleService(percepatan:)` adalah hal yang berbeda dan tetap ada: ia mempercepat perilaku jam
palsu, sedangkan mode ini mengecilkan jadwal sesi. Keduanya boleh dipakai bersamaan.

### 7.0 Faktor 60 lahir dari jam palsu — dengan jam sungguhan, kecilkan faktornya

```bash
flutter run --dart-define=PAKAI_JADWAL_UJI=true --dart-define=FAKTOR_JADWAL_UJI=12
```

Dengan `FakeBleService` jawaban datang seketika, jadi jendela 55–70 detik untuk `+1 jam` masuk akal.
**Pengukuran sungguhan tidak begitu**: lantainya saja `UKUR_MIN_MS` 10 detik, praktiknya puluhan
detik, dan nadi yang sulit ditemukan membuatnya jauh lebih lama (batas keras firmware 5 menit). Tiga
akibatnya pada faktor 60, ketiganya terlihat seperti kerusakan aplikasi padahal jadwalnya yang
terlalu rapat:

- pengukuran yang dimulai **tepat waktu** selesai setelah jendelanya tutup, lalu ditandai terlambat;
- titik berikutnya jatuh tempo selagi titik sekarang masih diukur, dan jam men-`NAK` yang kedua
  dengan `0x05` (`sedang mengukur`);
- tenggat sesi (150 detik sesudah t0) jatuh sebelum pengukuran terakhir sempat menjawab.

Yang ketiga sudah **tidak lagi merusak data** sejak tenggat belajar menunda selama jamnya terbukti
sedang mengukur (§7.2), tetapi dua yang pertama tetap membuat hasil ujinya menyesatkan.

Faktor 12 memberi `+1 jam` pada menit ke-5 dengan jendela 4,6–5,8 menit dan sesi penuh 10 menit —
lapang untuk satu pengukuran sungguhan, masih jauh lebih cepat daripada 2,5 jam. Bawaannya tetap 60,
karena mayoritas pemakaian mode ini adalah dengan jam palsu.

### 7.2 Tenggat mengalah pada pengukuran yang sedang berjalan

Tenggat sesi jatuh pada waktu jam dinding; pengukuran memakan puluhan detik. Menutup sesi tepat pada
detik jam sedang mengukur berarti membuang pengukuran yang beberapa detik lagi selesai — dan
sampelnya kemudian tiba ke sesi yang sudah tidak aktif, hilang tanpa satu pun gejala di layar.

Karena itu `_lewatTenggat()` bertanya lebih dulu: `BleService.jamSedangMengukur()` **membaca**
karakteristik Status (§5.5 bit0). Jawaban "ya" menunda pemeriksaan 30 detik dan mengulanginya.

Dua hal menjaga penundaan itu tetap jujur:

- **Yang menahan adalah bukti, bukan asumsi.** Pembacaan yang gagal — jam mati, di luar jangkauan —
  menjawab false, dan tenggatnya berjalan seperti biasa. Justru itulah keadaan yang tenggatnya
  dirancang untuk menutup.
- **Penundaannya berujung**: 12 x 30 detik = 6 menit, sedikit melampaui batas keras pengukuran di
  firmware (5 menit). Pengukuran yang sah tidak pernah menyentuh batas itu; firmware yang lupa
  mencabut bit0 selalu.

### 7.1 Tiga pengaman, dan kenapa ketiganya perlu

1. **Gerbang saat kompilasi.** `bool.fromEnvironment` dievaluasi saat kompilasi
   ([../lib/konfigurasi.dart](../lib/konfigurasi.dart)), jadi rakitan rilis biasa tidak menyeret satu
   baris pun jadwal uji. Pola yang sama dengan `pakaiJamPalsu` dan `pakaiAuthPalsu`, dan alasan yang
   sama: rakitan rilis yang diam-diam memakai jadwal dua menit adalah kegagalan yang tidak terlihat
   sampai terlambat.
2. **Spanduk permanen di layar** selama mode aktif. Bukan SnackBar — konsekuensinya hidup selama
   seluruh sesi, sama seperti `galatPenyimpanan` di Beranda.
3. **Kolom `sesiUji` di `tabel_sesi`** (skema v5, butuh migrasi). Ini yang paling penting dan paling
   mudah dikira berlebihan.

Kenapa kolom, bukan diturunkan: alasannya sama persis dengan `waktuTidakPasti` — begitu sesinya
tersimpan, tidak ada lagi jejak yang bisa dipakai menurunkannya dengan pasti. Sesi uji berdurasi dua
menit memang mencurigakan, tetapi sesi sungguhan yang semua titiknya terlewat terlihat mirip. Dan
yang menentukan: **rakitan tanpa flag itu tetap harus bisa membaca baris yang ditulis rakitan yang
punya flag.** Sesi uji akan tetap ada di basis data tester lama setelah build ujinya diganti.

Konsekuensi `sesiUji == true`:

- **Dikeluarkan dari `AnalisisSesi`** — angka gula darah dari sesi dua menit yang ikut masuk garis
  tren adalah pencemaran yang tidak akan terlihat lagi besok.
- **Dikeluarkan dari `sesiHariIni()`**.
- **Tetap tampil di Riwayat, dengan lencana jelas.** Menyembunyikannya akan membuat mustahil
  memverifikasi bahwa persistensinya bekerja — yang justru salah satu hal yang sedang diuji.
- **Tersedia "Hapus Semua Sesi Uji"** di Profil, supaya tester bisa membersihkan sendiri tanpa
  menghapus data aplikasi (yang juga akan menghapus penyandingan jamnya).

### 7.2 Notifikasi di mode uji

`zonedSchedule` tidak dapat diandalkan pada jarak 30 detik, dan Doze memperburuknya. Di mode uji,
pengingat memakai `Timer` dalam aplikasi. Ini berarti **jalur notifikasi yang sesungguhnya tidak ikut
teruji oleh mode ini** — ia harus diuji terpisah dengan jadwal normal, dan itu memang tidak bisa
dipercepat.

---

## 8. Status pengerjaan

**Seluruh sisi aplikasi selesai; sisi firmware belum disentuh** dan menunggu
komunikasi terpisah. Checklist firmware ada di [protokol-jam.md](protokol-jam.md) §11.

| # | Langkah | Status |
|---|---|---|
| 1 | `waktuPemulihan` memakai urutan waktu, bukan `index` | selesai |
| 2 | `JadwalSesi`/`TitikJadwal`, `jadwalNormal`/`jadwalUji`, `jadwalBawaan` | selesai |
| 3 | Skema v5: kolom `sesi_uji` + migrasi v4→v5 | selesai |
| 4 | `detikRelatifT0` dari jam dinding, `_geser` dipersempit | selesai |
| 5 | `ARM_TITIK` di `protokol_jam.dart`, `BleService`, `BleAsliService`, `FakeBleService` | selesai |
| 6 | `PetunjukTombolUkur` + `ukurTitikSekarang()` | selesai |
| 7 | Pengingat terjadwal (`flutter_local_notifications`) | selesai |
| 8 | Penyaringan `sesiUji` + "Hapus Semua Sesi Uji" | selesai |

Tiga hal yang ditemukan **saat mengerjakannya**, tidak ada di rencana, dan
masing-masing mengubah kode di luar daftar di atas:

- **`SesiMakanController` sekarang menerima jamnya lewat konstruktor** (`jam`,
  bawaan `DateTime.now`). `tester.pump(Duration)` memajukan timer tanpa memajukan
  `DateTime.now()`, jadi tanpa seam ini jendela toleransi, hitung mundur, dan
  penundaan `ARM_TITIK` adalah tiga hal yang tidak satu pun test bisa memeriksanya
  — dan ketiganya justru inti v1.3. `JamPalsu` + `majuBersama` di
  [../test/helpers.dart](../test/helpers.dart) yang memakainya.
- **`FakeBleService.armTitik` sengaja tidak lewat `percepatan`.** Faktor itu
  memampatkan jadwal yang dipegang *jam*; penundaan `ARM_TITIK` datang dari
  aplikasi dan sudah dalam basis waktu aplikasi. Memampatkannya lagi menyalakan
  tombol jauh sebelum jendelanya terbuka — persis keadaan yang perintah ini ada
  untuk mencegah.
- **Sesi yang berakhir kini melepas ARM tombol ukur** (`ble.batalkanSesi` di
  `_selesaikan`). Tanpa itu tombol fisik jam tertinggal menyala untuk titik yang
  tidak akan pernah diminta lagi, dan menekannya menyalakan sensor tanpa ada yang
  memintanya — pada perangkat yang tidak bertahan lima puluh menit.

## 8.1 Urutan pengerjaan

1. `waktuPemulihan` → bandingkan `detikRelatifT0`, bukan `index`. **Dulu, sendirian**: ia perbaikan
   yang benar bahkan bila tidak ada satu pun langkah lain yang dikerjakan.
2. Objek `JadwalSesi` + `TitikJadwal` (nominal, jendela, label), `jadwalNormal` dan `jadwalUji`;
   `konfigurasi.dart` memilih di antaranya. Daftar literal empat titik di controller diganti.
3. Skema v5: kolom `sesiUji`, dengan migrasi v4→v5 yang ditulis, bukan `schemaVersion` yang dinaikkan
   diam-diam (`onUpgrade` akan melempar, sesuai rancangan).
4. `t0` sebagai `DateTime` aplikasi + `detikRelatifT0` dari jam dinding + `_geser` dipersempit.
5. `armTitik()` di `BleService`, `FakeBleService`, dan `protokol_jam.dart` (+ tes offset demi offset).
6. `PetunjukTombolUkur` — tombol aplikasi disebut lebih dulu, tombol jam kalimat kedua. Alasan urutan
   yang berbeda dari `PetunjukTombolJam` ada di §9 di bawah.
7. Notifikasi terjadwal.
8. Penyaringan `sesiUji` di `AnalisisSesi`, `sesiHariIni()`, lencana Riwayat, "Hapus Semua Sesi Uji".

## 9. Kenapa urutan copy-nya dibalik

[../lib/widgets/petunjuk_tombol_jam.dart](../lib/widgets/petunjuk_tombol_jam.dart) menyebut tombol
jam lebih dulu ("Selesai makan? Tekan tombol di jam") dan menaruh tombol aplikasi sebagai "sama
saja". Itu benar untuk `t0`: orang sedang makan dan ponselnya ada di meja lain.

Untuk titik ukur, keadaannya kebalikan. Yang membuat pengguna bertindak adalah **notifikasi yang baru
berbunyi di ponselnya** — ponselnya sudah pasti di tangan. Menyebut tombol jam lebih dulu menyuruh
dia mencari tombol yang lebih jauh daripada yang sedang dipegangnya.

Yang **tidak** berubah: tombol jam tetap wajib disebut. Aturan yang sebenarnya bukan "jam harus
disebut duluan" melainkan "jam tidak boleh dihilangkan" — kalimat yang hilang membuat pengguna
mengira sesi hanya bisa dijalankan dari layar. Itu berlaku di kedua widget.

Keduanya tetap dua widget bersaudara, bukan satu dengan parameter: yang lama mengirim `MULAI_SESI`
dan menunggu `TOMBOL_SELESAI_MAKAN`, yang baru mengirim `UKUR` dan menunggu paket Sampel; kondisi
disabled-nya pun berbeda.

Rangkap dari dua tombol tidak perlu ditangani ulang: `SesiMakanController` sudah men-dedup dengan
kunci `(sesiId, index)`, jadi yang kedua dibuang diam-diam — dan memang tidak boleh ada balapan yang
terlihat pengguna.
