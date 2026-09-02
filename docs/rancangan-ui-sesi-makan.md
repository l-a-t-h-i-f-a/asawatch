# Rancangan Ulang UI/UX — Sesi Makan

Dokumen acuan untuk restrukturisasi arsitektur informasi `asawatch` menyusul perubahan
konsep dari **pemantauan kontinu** menjadi **sesi makan episodik**.

Status: **seluruh tujuh langkah §10 selesai.** Yang belum dikerjakan hanya hal-hal yang memang
di luar cakupan rancangan ini: BLE sungguhan, endpoint deteksi nutrisi sungguhan, kamera
sungguhan, dan penyimpanan data sesi/kalibrasi (semuanya masih hidup di memori lewat
`SesiMakanController` + `FakeBleService`/`FakeNutrisiService`). Lihat catatan tiap langkah di §10.

---

## 1. Konteks

Konsep baru aplikasi:

1. Sebelum makan, user memotret makanan untuk mendeteksi nutrisi yang masuk.
2. Saat selesai makan, user menekan tombol **di jam tangan** — momen ini menjadi **t0**,
   memakai jam milik jam tangan, bukan jam HP. Aplikasi tidak punya tombol yang setara.
3. Jam tangan mengukur pada **t0**, **t0+1 jam**, dan **t0+2 jam** (3 sampel), ditambah
   satu **baseline pra-makan** yang diambil otomatis saat shutter kamera ditekan.
4. Data dikirim ke aplikasi lewat BLE; jam menyimpan sampel di buffer bila HP tidak
   tersambung, sehingga data bisa datang terlambat.

Metrik per sampel: **gula darah, detak jantung, sistolik/diastolik, SpO2**.

### Keputusan yang sudah dikunci

| Keputusan | Nilai |
|---|---|
| Jam mengukur di luar sesi makan? | **Tidak.** Hanya saat sesi makan. |
| Siapa menetapkan t0? | **Tombol di jam**, satu-satunya sumber. Jam menolak tombolnya selama app belum mengabari ada foto makanan. |
| Cakupan perubahan UI | **Restrukturisasi informasi.** Palet, font, dan bentuk kartu dipertahankan. |
| Halaman auth (`welcome`/`login`/`register`) | Tidak disentuh. |
| Halaman profil & informasi pribadi | Tidak disentuh (kecuali penambahan status perangkat). |

---

## 2. Diagnosis: kenapa UI sekarang tidak cocok

UI yang ada dibangun di atas asumsi pemantauan kontinu. Model data yang baru episodik.
Lima titik benturannya:

1. **Tidak ada "sekarang".** [beranda_tab.dart](../lib/beranda_tab.dart) menampilkan
   nilai vital saat ini. Karena jam hanya mengukur saat sesi makan, angka tersebut akan
   basi hampir sepanjang waktu — kadang 5 menit, kadang 9 jam — dengan tampilan yang sama
   persis. Ini janji yang tidak bisa ditepati, bukan sekadar masalah tampilan.
2. **Unit datanya berubah** dari *pembacaan* menjadi *sesi*. `RiwayatItem` (satu metrik,
   satu nilai, satu status) tidak lagi bermakna sendirian: gula darah 140 tanpa konteks
   "1 jam setelah makan 60 g karbohidrat" tidak berarti apa-apa.
3. **Kurva harian akan bolong.** Painter yang ada menggambar kurva mulus sepanjang hari;
   data nyata adalah 4 titik dalam 2 jam, lalu kosong berjam-jam.
4. **Tombol kamera naik pangkat.** Saat ini ia hanya pintu ke satu halaman. Dalam konsep
   baru ia adalah pemicu seluruh siklus, dan maknanya berubah tergantung status sesi.
5. **Analisis mingguan/bulanan jadi tidak relevan** dibanding insight yang sekarang
   mungkin: hubungan karbohidrat terdeteksi ↔ kenaikan gula darah.

---

## 3. Pergeseran inti

> Dari **"dashboard kondisi tubuh"** menjadi **"siklus sesi makan"**.

Beranda berhenti menjawab *"bagaimana kondisimu sekarang"* dan mulai menjawab
*"sesi kamu sampai mana"*.

Karena setiap makan difoto, aplikasi memiliki **data nutrisi harian yang lengkap** —
data yang benar-benar ada setiap hari. Maka dashboard vital digantikan
**dashboard nutrisi + status sesi**, bukan dikosongkan.

---

## 4. Perubahan per layar

### 4.1 Beranda — [lib/beranda_tab.dart](../lib/beranda_tab.dart)

Perubahan terbesar. Beranda punya **tiga wajah** sesuai status sesi.

**A. Idle — tidak ada sesi berjalan (kondisi paling sering)**

- Sapaan + tanggal (dipertahankan, termasuk pemuatan nama user)
- **Ringkasan hari ini**: total kalori, karbohidrat, protein, lemak dari sesi hari ini,
  relatif terhadap target dari Tujuan Kesehatan
- **Kartu sesi terakhir**: thumbnail foto, jam, verdict respons
  (mis. "puncak +48 mg/dL · normal dalam 2 jam")
- **Sparkline puncak gula darah** beberapa sesi terakhir — pemakaian nyata pertama untuk
  [lib/widgets/sparkline.dart](../lib/widgets/sparkline.dart)
- **Status jam** ringkas di header: tersambung / baterai / jumlah sampel tertunda

**B. Sesi berjalan**

Timeline 4 titik mendominasi layar:

```
Baseline      ✓  92 mg/dL
Selesai makan ✓  98 mg/dL
+1 jam           42:17   ← hitung mundur
+2 jam           —
```

Di bawahnya: foto makanan dan ringkasan nutrisinya. Titik yang belum ada ditulis `—`,
**tidak pernah** diisi nilai lama.

**C. Sesi baru selesai**

Kartu hasil yang persisten sampai dibuka user: kurva respons, nilai puncak, delta dari
baseline, dan waktu pemulihan.

> **Catatan implementasi.** CLAUDE.md mencatat `BerandaTab.build()` memanggil `_loadNama()`
> yang async pada setiap build, dan pengecekan kesamaan di dalamnya yang mencegah rebuild
> tak berujung. Saat menambahkan listener state sesi, pastikan notifikasi tidak memicu
> jalur async tersebut berulang. Bungkus **hanya kartu sesi** dengan listener, bukan
> seluruh `BerandaTab`.

### 4.2 Riwayat — [lib/riwayat_tab.dart](../lib/riwayat_tab.dart)

- `RiwayatItem` diganti model `SesiMakan`.
- Entri daftar: thumbnail foto · nama & kalori · indikator respons · waktu.
- Filter berubah dari per-metrik (*Detak Jantung / Gula Darah / …*) menjadi
  **per waktu makan** (Sarapan / Makan Siang / Makan Malam / Camilan), atau per kualitas
  respons.
- Tap entri → `RingkasanSesiPage`.
- Pembacaan individual menjadi isi **di dalam** sesi, bukan entri sejajar.

### 4.3 Analisis — [lib/analisis_tab.dart](../lib/analisis_tab.dart)

Toggle Mingguan/Bulanan yang datanya hardcoded diganti pertanyaan yang datanya kini nyata:

- **Karbohidrat vs kenaikan gula darah** — scatter plot, satu titik per sesi. Ini insight
  paling kuat yang dimiliki aplikasi dan saat ini belum punya tempat di UI.
- Makanan yang paling memicu lonjakan.
- Apakah waktu pemulihan (kembali ke baseline) membaik dari waktu ke waktu.

Sesi dengan keyakinan deteksi nutrisi rendah dikecualikan atau ditandai berbeda pada
scatter plot, agar estimasi porsi yang meleset tidak mencemari korelasi.

### 4.4 Halaman detail metrik

Ketiganya tetap ada, tetapi berhenti menggambar kurva harian. Karena dashboard vital
hilang, ketiganya **tidak lagi dijangkau dari Beranda**, melainkan dari Analisis dan dari
Ringkasan Sesi.

| Halaman | Isi baru |
|---|---|
| [gula_darah_detail_page.dart](../lib/gula_darah_detail_page.dart) | Kurva respons **lintas sesi yang ditumpuk**, plus rata-rata puncak. Paling bernilai dari ketiganya. |
| [tekanan_darah_detail_page.dart](../lib/tekanan_darah_detail_page.dart) | Tren per sesi + **pintu masuk kalibrasi**, dengan status "terakhir dikalibrasi 12 hari lalu". |
| [detak_jantung_detail_page.dart](../lib/detak_jantung_detail_page.dart) | Paling tipis isinya (4 titik per sesi). Turunkan prominensinya, jangan dihapus. |

Seluruh painter (`SplinePainter`, `BloodSugarSplinePainter`, `BloodPressureSplinePainter`,
`DashboardSplinePainter`) diubah menerima `List<Sampel>` alih-alih bezier hardcoded.

### 4.5 Deteksi Makanan — [lib/deteksi_makanan_page.dart](../lib/deteksi_makanan_page.dart)

Dua perubahan wajib:

1. **Kartu hasil harus bisa diedit.** Saat ini read-only. Estimasi porsi dari satu foto
   bisa meleset 30–50%, dan angka karbohidrat itulah yang nanti dikorelasikan dengan
   respons glukosa. User harus dapat mengoreksi nama dan porsi
   ("1 piring" → "setengah piring") sebelum sesi dimulai. Momen ini justru paling akurat:
   piringnya masih di depan mata.
2. **Tombol "Selesai Makan & Pantau"** di kartu hasil — inilah yang menetapkan t0 dan
   memulai sesi.

Field nutrisi diperluas dari 4 makro menjadi termasuk **gula total** dan **serat**, karena
keduanya yang menjelaskan perbedaan respons antar makanan berkarbohidrat sama.

### 4.6 Tujuan Kesehatan — dihapus

Halaman ini **dihapus** (2026-09-02), beserta entri menunya di Profil. Isinya tidak pernah
lebih dari target literal yang tidak seorang pun pernah memilih dan tidak pernah tersimpan;
rencana menyambungkannya ke ringkasan harian tidak pernah dikerjakan. Bila target kalori
sungguhan jadi dibuat, halamannya ditulis ulang dari nol.

### 4.7 Profil & Perangkat

- [profil_tab.dart](../lib/profil_tab.dart): tambah entri menu status perangkat dan
  kalibrasi tekanan darah. Struktur `Material` + `ListTile.shape` yang sudah ada
  dipertahankan.
- [menghubungkan_perangkat_page.dart](../lib/menghubungkan_perangkat_page.dart): diperluas
  agar juga menampilkan baterai jam, waktu sinkronisasi terakhir, dan jumlah sampel yang
  masih tertahan di buffer jam.

---

## 5. Layar baru

| Layar | Fungsi |
|---|---|
| `SesiBerjalanPage` | Tampilan penuh sesi aktif: timeline 4 titik, foto, nutrisi, status jam, opsi batalkan sesi. |
| `RingkasanSesiPage` | Hasil satu sesi: kurva respons, puncak, delta dari baseline, waktu pemulihan, verdict berbahasa Indonesia. |
| `KalibrasiTekananDarahPage` | Prosedur bertahap: persiapan + pilih pergelangan → tiga putaran (manset di lengan seberang, diukur bersamaan dengan jam, jeda 60 detik antar putaran) → ringkasan, lalu median selisihnya dikirim ke jam. Pembacaan jam disembunyikan sampai hasil tensimeter diketik. Kalibrasi berlaku 4 minggu. |

---

## 6. Bottom nav dan tombol tengah

Struktur 5 tab dengan tombol tengah timbul **dipertahankan**, termasuk carve-out index 2
di [main.dart](../lib/main.dart) (index 2 melakukan `push`, bukan berpindah tab, dan
`IndexedStack` di-clamp). Yang berubah hanya **makna tombol tengah**, yang kini kontekstual:

| Status sesi | Tombol tengah |
|---|---|
| Idle | "Foto Makanan" → `DeteksiMakananPage` |
| Foto sudah diambil, t0 belum diset | Membuka `SesiBerjalanPage`, yang menawarkan tombol "Saya Sudah Selesai Makan" dan menerangkan bahwa tombol di jam melakukan hal yang sama |
| Sesi berjalan | Membuka `SesiBerjalanPage`; memulai sesi baru menawarkan "akhiri sesi berjalan" lebih dulu |

Hanya satu sesi aktif pada satu waktu.

**t0 tidak pernah *dihitung* di app** — dan itu tetap berlaku, tetapi bentuknya di layar
sudah berubah dua kali; yang di bawah ini yang berlaku sekarang.

Mula-mula tombol "Selesai Makan & Pantau" dihapus seluruhnya dan diganti `PetunjukTombolJam`
([lib/widgets/petunjuk_tombol_jam.dart](../lib/widgets/petunjuk_tombol_jam.dart)), karena
t0 hanya boleh datang dari jam. Itu benar soal t0-nya, tetapi **terlalu jauh soal tombolnya**:
pengguna yang sedang memegang ponselnya jadi harus mengingat tombol mana di jam yang harus
ditekan, untuk sesuatu yang layarnya sedang menunggu.

Sekarang widget yang sama memuat **keduanya**: kalimat tentang tombol jam, dan tombol
"Saya Sudah Selesai Makan" di bawahnya. Yang membuat itu tidak melanggar aturan t0 adalah
bentuk perintahnya — `MULAI_SESI` (docs/protokol-jam.md §5.1) berisi `sesiId` saja, **tanpa
waktu sama sekali**. Jam yang membaca pencacahnya sendiri lalu mengirim
`TOMBOL_SELESAI_MAKAN` seperti biasa, jadi yang ditambahkan bukan sumber t0 kedua melainkan
cara kedua menekan tombol yang sama. Sesi baru berpindah ke `berjalan` saat peristiwa itu
sampai, bukan saat tombolnya diketuk.

Tombol jam **tetap disebut lebih dulu dan tidak boleh dihapus**: ia satu-satunya yang bekerja
saat ponselnya tidak dipegang — keadaan yang justru paling lazim saat orang sedang makan.
Kejujuran soal jam yang belum tersambung juga tetap, dan sekarang ia sekaligus mematikan
tombol di layar: perintahnya berjalan lewat BLE, jadi tanpa tautan tidak ada tombol mana pun
yang bisa dipakai.

Tombol tengah tetap hanya punya dua aksi (foto / buka sesi).

---

## 7. Yang dihapus

Eksplisit, agar tidak ambigu saat implementasi:

- Kartu vital "sekarang" di Beranda (detak jantung / gula darah / tekanan darah saat ini)
- Filter per-metrik di Riwayat
- Toggle Mingguan/Bulanan di Analisis
- Semua path bezier hardcoded di seluruh `CustomPainter` data (painter dekoratif di
  welcome/login tetap)
- Model `RiwayatItem`

---

## 8. Prinsip UI yang mengikat

**Kejujuran soal data basi.** Setiap angka wajib membawa waktu ukurnya ("diukur 3 jam
lalu"). Angka yang belum ada ditampilkan sebagai `—`, tidak pernah diisi nilai sebelumnya.
Ini pembeda antara aplikasi kesehatan yang dipercaya dan yang tidak.

**Sesi tidak pernah "gagal" hanya karena telat.** Jam menyimpan sampel di buffer; data bisa
datang terlambat, bahkan berjam-jam. Status sampel adalah `menunggu` sampai jam melaporkan
bahwa ia memang tidak berhasil mengukur — baru kemudian `terlewat`, dan sesi menjadi
`tidakLengkap`, bukan gagal total.

**Jeda 2 jam harus terasa hidup tanpa membohongi.** Hitung mundur ke sampel berikutnya,
foto makanan yang tetap terlihat, dan status jam yang apa adanya sudah cukup. Jangan isi
dengan animasi kosong.

**Hitung mundur ditangani lokal.** Controller sesi hanya memberi notifikasi ~4 kali seumur
sesi. Detik-detikan hitung mundur adalah `Timer.periodic` + state lokal milik kartu itu
sendiri, agar tidak me-rebuild seluruh pendengar tiap detik.

---

## 9. Yang dipertahankan

- Palet warna (lihat tabel di CLAUDE.md) — tidak ada warna baru
- Montserrat 400/500/600/700
- Bentuk kartu, radius, dan gaya inline `TextStyle`/`BoxDecoration`
- Pendekatan `CustomPainter` untuk semua grafik — tidak ada paket charting
- Bottom nav buatan tangan dengan tombol tengah timbul
- Pola `Navigator.pop(true)` untuk refresh lintas halaman pada alur profil
- Seluruh alur auth

Ini restrukturisasi arsitektur informasi, **bukan** redesign visual.

---

## 10. Urutan pengerjaan

1. ~~`RingkasanSesiPage` + `SesiBerjalanPage` — layar baru, tidak merusak apa pun yang ada~~
   **selesai** — model di [lib/models/sesi_makan.dart](../lib/models/sesi_makan.dart), data
   palsu di [lib/models/contoh_sesi.dart](../lib/models/contoh_sesi.dart). Kedua halaman
   masih menerima `SesiMakan` lewat argumen; `SesiMakanController` menyusul di langkah 2.
2. ~~Beranda tiga wajah + penghapusan dashboard vital~~ **selesai** — `SesiMakanController`
   ([lib/controllers/](../lib/controllers/)) + `FakeBleService`/`FakeNutrisiService`
   ([lib/services/](../lib/services/)) disediakan lewat satu `ChangeNotifierProvider` di
   [main.dart](../lib/main.dart); tombol tengah sudah kontekstual (§6); shutter kamera membuat
   sesi draft (kartu hasil yang bisa diedit tetap menunggu langkah 6); target kalori/karbohidrat
   sempat memakai `lib/models/target_harian.dart`, yang kemudian **dihapus** — angka bawaannya
   tidak pernah dipilih pengguna, jadi ringkasan harian sekarang menampilkan jumlah tanpa
   pembanding sampai Tujuan Kesehatan disambungkan (§4.6). `MiniSparklinePainter` sudah data-driven.
3. ~~Riwayat berbasis sesi (`RiwayatItem` → `SesiMakan`)~~ **selesai** — `RiwayatItem` dihapus;
   daftar membaca `SesiMakanController.riwayat`, dikelompokkan per tanggal, dan tiap entri
   membuka `RingkasanSesiPage`. Waktu makan dan kualitas respons diturunkan di
   [lib/models/sesi_makan.dart](../lib/models/sesi_makan.dart) (`waktuMakan`,
   `kualitasRespons`), tidak pernah dipilih user.
4. ~~Painter menjadi data-driven~~ **selesai** — satu painter generik
   [lib/widgets/kurva_sampel.dart](../lib/widgets/kurva_sampel.dart) (`KurvaSampelPainter` +
   `SeriMetrik`) menggantikan `SplinePainter`, `BloodSugarSplinePainter`,
   `BloodPressureSplinePainter`, dan `KurvaResponsPainter`. Ketiga halaman detail metrik kini
   menerima `SesiMakan` (default: sesi terakhir dari controller) dan menggambar sampelnya
   sendiri; isi lanjutan per halaman pada tabel §4.4 tetap milik langkah 5 dan 7.
5. ~~Analisis + halaman detail metrik~~ **selesai** — perhitungan lintas sesi ada di
   [lib/models/analisis_sesi.dart](../lib/models/analisis_sesi.dart) (sebaran, garis tren,
   pemicu, rekap pemulihan), sebarannya digambar
   [lib/widgets/sebaran_karbo.dart](../lib/widgets/sebaran_karbo.dart), dan kurva lintas sesi
   yang ditumpuk oleh `KurvaTumpukSesi`. Halaman detail dijangkau dari Analisis dan Ringkasan
   Sesi. Pintu kalibrasi sudah ada beserta statusnya; alur kalibrasinya sendiri langkah 7.
6. ~~Deteksi Makanan menjadi dapat diedit~~ **selesai** — kartu hasil kini menampilkan tiap
   `ItemMakanan` dengan tombol Koreksi (nama, teks porsi, dan berat; nutrisinya ikut terskala
   mengikuti berat), tombol "Selesai Makan & Pantau" menetapkan t0, dan "Ambil ulang foto"
   membuang draft. Koreksi user menandai `dikoreksiUser`, sehingga sesi berkeyakinan rendah
   tetap ikut diplot di Analisis (§4.3).
7. ~~Kalibrasi tekanan darah & status perangkat~~ **selesai** —
   [lib/kalibrasi_tekanan_darah_page.dart](../lib/kalibrasi_tekanan_darah_page.dart) mengunci
   urutan tensimeter → jam → kirim koefisien (`BleService.ukurSekarang` dan `kirimKalibrasi`).
   **Metodenya kemudian disamakan dengan alat sejenis (Samsung Health Monitor):** manset di lengan
   yang berlawanan dengan jam dan keduanya diukur **bersamaan**, tiga putaran dengan jeda 60 detik,
   koreksi diambil median, putaran yang saling bertentangan ditolak, dan kalibrasi kedaluwarsa
   setelah 4 minggu serta terikat pada satu pergelangan. Karena pengukurannya bersamaan, urutan
   "tensimeter dulu" tidak lagi bisa dipakai untuk mencegah user menyesuaikan angka; penggantinya
   adalah menyembunyikan pembacaan jam sampai angka tensimeter masuk.
   Rinciannya di CLAUDE.md dan di komentar `Kalibrasi`;
   [menghubungkan_perangkat_page.dart](../lib/menghubungkan_perangkat_page.dart) menampilkan
   baterai, sinkronisasi terakhir, dan jumlah sampel tertahan di buffer; Profil menautkan
   keduanya. Kalibrasi tersimpan di memori controller — belum ada penyimpanan untuk data
   perangkat.

   **Tambahan di luar rancangan awal: alur pemasangan jam.** Rancangan ini menganggap jam
   sudah terpasang, sehingga tidak ada layar yang menjelaskan bagaimana jam pertama kali
   disambungkan. [pemindaian_perangkat_page.dart](../lib/pemindaian_perangkat_page.dart)
   mengisi lubang itu: pindai → pilih → sambungkan, dengan perangkat tak didukung tetap
   terlihat tetapi tidak bisa dipilih, dan kegagalan menyambung tidak menutup halaman.
   Kontrak `BleService` bertambah `pindai()`, `sambungkan()`, dan `putuskan()`; `StatusPerangkat`
   bertambah `namaPerangkat` agar "belum pernah dipasangkan" bisa dibedakan dari "terputus"
   — yang pertama menawarkan pemindaian, yang kedua penyambungan ulang sambil menjelaskan
   sampel yang masih tertahan di buffer (§8). BLE-nya tetap palsu: `FakeBleService` menjawab
   dari katalog tetap berisi tiga perangkat, jadi ini bentuk alur, bukan implementasi radio.

Langkah 1 dapat dikerjakan lebih dulu dengan data palsu, tanpa menunggu BLE maupun
endpoint deteksi nutrisi.

---

## 11. Dampak ke test

[test/widget_test.dart](../test/widget_test.dart) menjalankan alur nyata
welcome → login → tab, sehingga ia **akan pecah** pada langkah 2. Rencanakan
pembaruannya sebagai bagian dari langkah tersebut, bukan belakangan.

Yang tetap berlaku dan harus dipertahankan di test baru:

- `loadMontserrat()` di `setUpAll` — tanpa ini muncul `RenderFlex` overflow palsu
- Viewport 412×915; bottom nav memang overflow di bawah ~370 px logis
- `SharedPreferences.setMockInitialValues(...)` sebelum pump
- Tombol kembali digambar sendiri, jadi `tester.pageBack()` tidak bekerja — ketuk
  `Icons.arrow_back`

Tambahan untuk konsep baru: `FakeBleService` dengan interval dipercepat (mis. 10 detik
alih-alih 1 jam) agar sesi berjalan dan sesi selesai dapat diuji secara deterministik.

---

## 12. Lampiran — definisi minimal untuk memulai

Bentuk **minimal yang dibutuhkan UI**, bukan kode final. Boleh ditambah, tapi field di
bawah ini jangan dihilangkan — masing-masing ada layar yang memakainya. Semua nama tetap
Bahasa Indonesia sesuai konvensi repo.

### 12.1 Status

```dart
enum StatusSesi {
  draft,             // foto sudah diambil, tombol di jam menyala, t0 ditunggu
  menungguPerangkat, // foto sudah diambil tetapi jam belum tersambung, jadi
                     // tombolnya belum bisa dinyalakan
  berjalan,          // t0 diterima dari jam, menunggu sampel +1 jam / +2 jam
  selesai,           // 4 sampel lengkap
  tidakLengkap,      // sesi berakhir dengan sampel terlewat
  dibatalkan,
}

enum StatusSampel { menunggu, terisi, terlewat }
```

Index sampel bersifat tetap dan bermakna:

| index | Titik | Kapan |
|---|---|---|
| 0 | Baseline pra-makan | otomatis saat shutter kamera ditekan |
| 1 | Selesai makan (t0) | saat user menekan tombol "Selesai Makan" **di jam** |
| 2 | +1 jam | t0 + 3600 detik |
| 3 | +2 jam | t0 + 7200 detik |

### 12.2 Sampel

```dart
class Sampel {
  final int index;               // 0..3, lihat tabel di atas
  final int detikRelatifT0;      // negatif untuk baseline
  final StatusSampel status;
  final bool dariBuffer;         // true bila dikirim jam setelah tertunda

  // null = metrik tidak berhasil diukur. JANGAN pakai 0 sebagai penanda di UI;
  // protokol BLE memakai sentinel 0, konversikan ke null saat decode.
  final int? gulaDarah;          // mg/dL
  final int? detakJantung;       // bpm
  final int? sistolik;           // mmHg
  final int? diastolik;          // mmHg
  final int? spo2;               // %
}
```

`waktuUkur` diturunkan, tidak disimpan: `sesi.t0.add(Duration(seconds: detikRelatifT0))`.
Ini yang dipakai untuk label "diukur 3 jam lalu" (lihat §8).

### 12.3 Sesi makan

```dart
class SesiMakan {
  final String id;
  final String fotoPath;
  final DateTime waktuFoto;
  final DateTime? t0;            // null selama status == draft
  final StatusSesi status;
  final HasilDeteksi? hasil;     // null bila analisis nutrisi belum selesai
  final List<Sampel> sampel;     // selalu 4 elemen, index 0..3
}
```

Nilai turunan yang dipakai Ringkasan Sesi dan Analisis — hitung, jangan simpan:
`baseline`, `sampelBerikutnya`, `puncakGulaDarah`, `deltaPuncak` (puncak − baseline),
`waktuPemulihan`, dan `verdict` (kalimat Bahasa Indonesia untuk kartu hasil).

> `hasil == null` adalah kondisi normal, bukan error: foto bisa diambil saat offline dan
> analisis nutrisi menyusul belakangan. Sesi tetap boleh dimulai dan t0 tetap akurat.
> UI menampilkan "Menganalisis…" pada slot nutrisi, dan sesi tetap berjalan normal.

### 12.4 Hasil deteksi nutrisi

```dart
class Nutrisi {
  final double kalori, karbohidrat, protein, lemak, gulaTotal, serat;
}

class ItemMakanan {
  final String nama;
  final String porsi;            // "1 piring", teks yang bisa diedit user
  final double estimasiGram;
  final Nutrisi nutrisi;
}

class HasilDeteksi {
  final List<ItemMakanan> makanan;
  final Nutrisi total;
  final String indeksGlikemikPerkiraan; // "rendah" | "sedang" | "tinggi"
  final double keyakinan;               // 0..1
  final bool dikoreksiUser;
}
```

`gulaTotal` dan `serat` wajib ada — keduanya yang menjelaskan perbedaan respons antar
makanan berkarbohidrat sama, dan tanpanya scatter plot di Analisis (§4.3) tidak bisa
dibangun. `keyakinan` dan `dikoreksiUser` menentukan apakah sesi ikut diplot.

### 12.5 Service (abstract, agar UI bisa dites tanpa hardware)

```dart
abstract class BleService {
  Stream<StatusPerangkat> get statusPerangkat; // tersambung, baterai, sampelTertunda
  Stream<({String sesiId, Sampel sampel})> get sampelMasuk;

  // Tombol "Selesai Makan" ditekan; t0 memakai jam milik jam tangan. Sumbernya
  // bisa tombol fisik atau MULAI_SESI dari app — tidak dibedakan, dan memang
  // tidak boleh dibedakan.
  Stream<({String sesiId, DateTime t0})> get selesaiMakanDitekan;

  Future<bool> siapkanSesi(String sesiId);          // nyalakan tombol di jam
  Future<bool> mulaiSesi(String sesiId);            // tekan tombol jam dari app
  Future<void> mintaUkur(String sesiId, int index); // baseline
  Future<void> batalkanSesi(String sesiId);
  Future<void> sinkronkan();                        // tarik buffer jam
}

abstract class NutrisiService {
  Future<HasilDeteksi> analisis(String fotoPath);
}
```

Implementasi palsu yang dipakai selama Fase UI:

- `FakeBleService(percepatan: 360)` — interval 1 jam menjadi 10 detik, memancarkan sampel
  index 2 lalu 3. Sediakan juga mode yang sengaja melewatkan satu sampel untuk menguji
  status `tidakLengkap`. Karena tidak ada jam sungguhan untuk ditekan selama Fase UI, ia
  juga menekan tombolnya sendiri (`otomatisSelesaiMakan`, default 10 menit tersimulasi)
  supaya demo tidak buntu di draft; test mematikannya dan memanggil `tekanSelesaiMakan()`
  sendiri.
- `FakeNutrisiService` — kembalikan angka yang sudah ada di
  [deteksi_makanan_page.dart](../lib/deteksi_makanan_page.dart) hari ini (430 kcal,
  45 g karbohidrat, 28 g protein, 15 g lemak), ditambah `gulaTotal`, `serat`, dan
  `keyakinan`.

### 12.6 Controller dan state

Satu `SesiMakanController extends ChangeNotifier`, disediakan lewat satu
`ChangeNotifierProvider` di atas `MaterialApp`.

```dart
class SesiMakanController extends ChangeNotifier {
  SesiMakan? get sesiAktif;                       // null bila idle

  Future<void> mulaiDraft(String fotoPath);       // shutter ditekan
  Future<void> batalkan();
  // t0 tidak punya method: ia masuk lewat langganan `selesaiMakanDitekan`.
}
```

Aturan yang mengikat:

- **Hanya satu sesi aktif.** Memotret saat ada sesi berjalan harus menawarkan
  "akhiri sesi berjalan" lebih dulu (§6).
- **t0 dipakai apa adanya dari jam.** Peristiwa tombolnya bisa sampai berjam-jam
  belakangan lewat buffer; menghitung ulang t0 dengan jam HP saat pesannya tiba akan
  menggeser seluruh jadwal sesi (§8). Ini **tidak berubah** ketika tombolnya ditekan dari
  app: `mulaiSesiDariApp()` mengirim `MULAI_SESI` lalu tidak menyentuh `_sesiAktif` sama
  sekali — yang memulai sesi tetap peristiwa balasan dari jam.
- **Jam disiapkan saat draft dibuat, dan disiapkan ulang tiap kali jam tersambung
  kembali.** Selama penyiapannya belum sampai, sesi berdiri di `menungguPerangkat` dan
  tombol di jam tetap menolak — itulah yang menjamin sesi tidak pernah mulai tanpa foto.
- **Controller memberi notifikasi ~4 kali seumur sesi.** Hitung mundur detik-detikan
  adalah `Timer.periodic` + state lokal milik kartunya sendiri, bukan `notifyListeners()`
  tiap detik (§8).
- **Sampel di-dedup** dengan kunci `(sesiId, index)` — pengiriman dari jam bersifat
  at-least-once, jadi sampel yang sama bisa datang dua kali.
- **Jadwal dihitung ulang dari t0 absolut** saat aplikasi dibuka kembali. Jangan pernah
  menyimpan "sisa waktu".

### 12.7 Pengecualian terhadap CLAUDE.md

CLAUDE.md menyatakan *"Follow that pattern rather than introducing a state manager."*
Aturan itu tetap berlaku untuk seluruh alur auth, [profil_tab.dart](../lib/profil_tab.dart),
dan [informasi_pribadi_page.dart](../lib/informasi_pribadi_page.dart), yang tetap memakai
`Navigator.pop(true)` dan tidak disentuh.

Pengecualian hanya untuk permukaan yang menyentuh sesi makan — kartu sesi di Beranda,
Deteksi Makanan, Sesi Berjalan, Ringkasan Sesi, dan entri sesi di Riwayat — karena sampel
dapat masuk dari BLE kapan saja, dari tab mana pun. Paket yang dipakai `provider`, bukan
Riverpod: yang dibutuhkan hanya satu objek hidup dan kemampuan menyuntikkan
`FakeBleService` saat test.
