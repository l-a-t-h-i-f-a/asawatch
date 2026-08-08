# Rancangan Ulang UI/UX — Sesi Makan

Dokumen acuan untuk restrukturisasi arsitektur informasi `asawatch` menyusul perubahan
konsep dari **pemantauan kontinu** menjadi **sesi makan episodik**.

Status: rancangan, belum diimplementasikan.

---

## 1. Konteks

Konsep baru aplikasi:

1. Sebelum makan, user memotret makanan untuk mendeteksi nutrisi yang masuk.
2. Saat selesai makan, user menekan tombol — momen ini menjadi **t0**.
3. Jam tangan mengukur pada **t0**, **t0+1 jam**, dan **t0+2 jam** (3 sampel), ditambah
   satu **baseline pra-makan** yang diambil otomatis saat shutter kamera ditekan.
4. Data dikirim ke aplikasi lewat BLE; jam menyimpan sampel di buffer bila HP tidak
   tersambung, sehingga data bisa datang terlambat.

Metrik per sampel: **gula darah, detak jantung, sistolik/diastolik, SpO2**.

### Keputusan yang sudah dikunci

| Keputusan | Nilai |
|---|---|
| Jam mengukur di luar sesi makan? | **Tidak.** Hanya saat sesi makan. |
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

### 4.6 Tujuan Kesehatan — [lib/tujuan_kesehatan_page.dart](../lib/tujuan_kesehatan_page.dart)

Halaman ini **naik nilainya**. Karena setiap makan difoto, target kalori/karbohidrat harian
kini benar-benar bisa dilacak, bukan dekoratif. Sambungkan ke ringkasan harian di Beranda.

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
| `KalibrasiTekananDarahPage` | User memasukkan hasil tensimeter, aplikasi meminta jam mengukur bersamaan, lalu mengirim koefisien kalibrasi ke jam. |

---

## 6. Bottom nav dan tombol tengah

Struktur 5 tab dengan tombol tengah timbul **dipertahankan**, termasuk carve-out index 2
di [main.dart](../lib/main.dart) (index 2 melakukan `push`, bukan berpindah tab, dan
`IndexedStack` di-clamp). Yang berubah hanya **makna tombol tengah**, yang kini kontekstual:

| Status sesi | Tombol tengah |
|---|---|
| Idle | "Foto Makanan" → `DeteksiMakananPage` |
| Foto sudah diambil, t0 belum diset | "Selesai Makan" → menetapkan t0 |
| Sesi berjalan | Membuka `SesiBerjalanPage`; memulai sesi baru menawarkan "akhiri sesi berjalan" lebih dulu |

Hanya satu sesi aktif pada satu waktu.

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

1. `RingkasanSesiPage` + `SesiBerjalanPage` — layar baru, tidak merusak apa pun yang ada
2. Beranda tiga wajah + penghapusan dashboard vital
3. Riwayat berbasis sesi (`RiwayatItem` → `SesiMakan`)
4. Painter menjadi data-driven
5. Analisis + halaman detail metrik
6. Deteksi Makanan menjadi dapat diedit
7. Kalibrasi tekanan darah & status perangkat

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
