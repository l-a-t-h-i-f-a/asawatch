# Rencana Menuju Produksi

Dokumen acuan untuk mengubah `asawatch` dari **prototipe UI** menjadi **aplikasi produksi**.

Status: **Tahap A (§3) selesai seluruhnya. Tahap B (§4) selesai di sisi aplikasi, menunggu
firmware.** Riwayat sesi bertahan di SQLite, profil punya satu pintu, dan data contoh sudah keluar
dari jalur produksi. Sejak Tahap B, jalur produksi memakai `BleAsliService` di atas
`flutter_blue_plus`: seluruh protokol §2–§9 terpasang, izin platform dideklarasikan, sesi yang masih
berjalan dipulihkan setelah aplikasi ditutup, dan sesi yang sampelnya tidak pernah datang berakhir
`tidakLengkap` lewat tenggatnya sendiri. Tahap C ke atas masih rencana.

> **Yang belum bisa diklaim selesai dari Tahap B: checklist integrasi.** Seluruh §11 protokol bagian
> "Aplikasi" sudah terpenuhi dan diuji, tetapi keempat butir "Integrasi" — termasuk satu sesi penuh
> dengan hardware sungguhan — menunggu firmware yang belum ada. Sampai itu dijalankan, yang terbukti
> baru bahwa aplikasi menuruti dokumen protokol, bukan bahwa kedua sisi cocok.

> Catatan untuk siapa pun yang menguji: menghapus kode penyemaian tidak menghapus baris yang
> terlanjur tertulis. Perangkat yang pernah menjalankan build A2/A3 masih menyimpan riwayat contoh
> sampai data aplikasinya dihapus.

Hubungan dengan dokumen lain:

- [rancangan-ui-sesi-makan.md](rancangan-ui-sesi-makan.md) mengunci **bentuk UI dan alur sesi**.
  Dokumen ini tidak mengubahnya. Bila terjadi benturan, rancangan UI menang untuk urusan
  tampilan/alur, dokumen ini menang untuk urusan infrastruktur.
- [../CLAUDE.md](../CLAUDE.md) menggambarkan keadaan **sekarang**. Setiap langkah di sini yang
  selesai mewajibkan pembaruan CLAUDE.md — lihat §11.

---

## 1. Titik berangkat

Yang sudah benar dan **tidak boleh dibongkar**:

| Aset | Alasan dipertahankan |
|---|---|
| Kontrak `BleService`, `NutrisiService` ([../lib/services/](../lib/services/)) | Sudah abstrak. Produksi = menambah implementasi, bukan mengubah kontrak. |
| `SesiMakanController` ([../lib/controllers/](../lib/controllers/)) | Aturan dedup, satu-sesi-aktif, jadwal dari `t0` absolut tetap berlaku dengan data nyata. |
| Semua `CustomPainter` (`KurvaSampelPainter`, `MiniSparklinePainter`) | Sudah digambar dari data, bukan literal. |
| `FakeBleService` / `FakeNutrisiService` | **Tetap dipakai untuk test.** Jangan dihapus, hanya dilepas dari jalur produksi. |
| Pola `Navigator.pop(true)` untuk refresh lintas halaman | Masih memadai di luar permukaan sesi. |

Yang membuat aplikasi ini belum bisa dipakai orang sungguhan, berurutan dari yang paling
mendasar:

1. ~~**Tidak ada data yang bertahan.**~~ **Selesai (Tahap A dan B).** Riwayat sesi, sesi yang masih
   berjalan, dan kalibrasi semuanya bertahan di SQLite.
2. ~~**Tidak ada jam tangan.**~~ **Selesai di sisi aplikasi (Tahap B).** `BleAsliService` yang dipakai
   jalur produksi; `FakeBleService` tinggal di belakang `--dart-define=PAKAI_JAM_PALSU=true`.
   Firmware-nya sendiri belum ada.
3. **Tidak ada kamera dan tidak ada analisis nutrisi.** Preview kamera adalah gambar, dan
   `FakeNutrisiService` mengembalikan angka yang sama untuk foto apa pun.
4. **Tidak ada akun.** Login hanya `validate()` lalu navigasi.
5. ~~**Tidak ada izin platform.**~~ **Selesai untuk Bluetooth (Tahap B).** Kamera dan notifikasi
   menyusul bersama Tahap C dan E.
6. **Tidak ada penanganan gagal.** Kegagalan penyimpanan (Tahap A), BLE, dan izin (Tahap B) sudah
   ditangani. Kamera dan jaringan belum.

---

## 2. Keputusan yang harus diambil sebelum menulis kode

Enam pertanyaan ini menentukan bentuk pekerjaan di bawah. Jangan mulai Tahap C ke atas
sebelum semuanya terjawab.

| # | Pertanyaan | Kenapa memblokir |
|---|---|---|
| K1 | ~~Firmware jam tangan: sudah ada, atau ikut dikembangkan?~~ | **✅ Terjawab: dikembangkan sendiri.** Protokol karena itu didikte dari kebutuhan aplikasi — lihat [protokol-jam.md](protokol-jam.md). |
| K2 | ~~Jam mengirim wall clock atau uptime pada `selesaiMakanDitekan`?~~ | **✅ Terjawab (protokol §4): uptime.** Jam **tidak punya RTC**, jadi ia tidak pernah mengirim wall clock — hanya `uptime_s` + `boot_id`. Aplikasi memasang *anchor* tiap koneksi dan menerjemahkannya sendiri. |
| K3 | ~~Berapa besar buffer sampel di jam, dan berapa lama tahan?~~ | **✅ Terjawab (protokol §6):** ring buffer 64 entri di flash, cukup ~16 sesi penuh tanpa sinkronisasi sama sekali. |
| K4 | Analisis nutrisi: model vision sendiri, layanan pihak ketiga, atau database makanan + input manual? | Menentukan bentuk backend (§5) dan biaya per foto. |
| K5 | Data hanya di perangkat, atau tersinkron lintas perangkat? | Kalau lintas perangkat, §3 (persistensi) harus langsung memakai skema yang sync-friendly (kolom `updatedAt`, id UUID, soft delete). |
| K6 | Target pasar dan klaim produk. | Menentukan beban regulasi (§10). Klaim "mengukur gula darah" jauh lebih berat daripada "mencatat estimasi". |

> **Rekomendasi untuk K5:** jawab **"hanya di perangkat"** untuk v1, tapi rancang skema DB
> sync-friendly sejak awal. Menambahkan sync ke skema yang siap jauh lebih murah daripada
> migrasi data pengguna nanti.

---

## 3. Tahap A — Persistensi lokal

**Dikerjakan pertama.** Alasannya: langkah ini mengubah bentuk `SesiMakanController`, dan jauh
lebih murah dilakukan sebelum BLE asli menempel di atasnya.

### 3.1 Basis data sesi

**✅ A4 selesai — Tahap A tuntas.** Data contoh dan identitas demo keluar dari jalur produksi:
`benihiBilaKosong()` dihapus, `Profil.demo` diganti `Profil.kosong`, dan ketiga foto Unsplash
(Beranda, Profil, Informasi Pribadi) diganti ikon. Keadaan pemasangan baru diuji di
[../test/pemasangan_baru_test.dart](../test/pemasangan_baru_test.dart).

Sebagian besar tampilan kosong ternyata **sudah ada** — rancangan sesi makan sudah
mengantisipasinya. Yang benar-benar perlu ditambah hanya sapaan Beranda tanpa nama dan kartu profil
yang belum diisi.

Dua penanganan error yang menggantung sejak A2 ikut selesai:

- **Basis data gagal dibuka** → `AplikasiGagalMulai` di [../lib/main.dart](../lib/main.dart), bukan
  layar kosong. Tidak ada tombol "lanjutkan saja": aplikasi tanpa basis datanya akan diam-diam
  kehilangan setiap sesi yang direkamnya.
- **Sesi gagal disimpan** → `SesiMakanController.galatPenyimpanan` + kartu peringatan di Beranda.
  Ditempatkan di layar, bukan SnackBar, karena akibatnya bertahan: sesinya masih terlihat tetapi
  akan hilang saat aplikasi ditutup.

Dua temuan yang tidak dicari:

- Ketiga avatar memuat foto orang asing dari Unsplash — dan **tidak akan pernah termuat di build
  rilis**, karena aplikasi ini tidak mendeklarasikan izin `INTERNET`.
- `DropdownButtonFormField` menuntut nilainya ada di dalam daftar itemnya, jadi "belum dipilih"
  tidak bisa diwakili string kosong. Jenis kelamin dan golongan darah kini nullable dengan hint.

**✅ A3 selesai** — dua hal yang tidak berhubungan, keduanya "satu pintu":

- **Anchor waktu**: tabel `tabel_anchor_waktu` (skema **v2**),
  [../lib/models/anchor_waktu.dart](../lib/models/anchor_waktu.dart) memuat rumus konversi §4.2,
  [../lib/repositories/anchor_repository.dart](../lib/repositories/anchor_repository.dart)
  menyimpannya. **Belum ada pemanggilnya** — penulisnya adalah `BleAsliService` di Tahap B. Tabelnya
  dibuat sekarang karena keputusan skema paling murah selagi belum ada data pengguna.
- **Profil**: [../lib/repositories/profil_repository.dart](../lib/repositories/profil_repository.dart)
  menjadi satu-satunya pintu ke `SharedPreferences`; tiga halaman dialihkan ke sana. Kunci `user_*`
  dipertahankan persis agar profil yang sudah tersimpan tidak hilang saat aplikasi diperbarui.

Migrasi v1→v2 ditulis dan **benar-benar dijalankan satu test** — jalur `onUpgrade` yang tidak
pernah diuji adalah jalur yang patah di perangkat pengguna.

**✅ A2 selesai** — riwayat sesi kini hidup di SQLite lewat drift:
[../lib/repositories/basis_data.dart](../lib/repositories/basis_data.dart) (skema v1, empat tabel)
dan [../lib/repositories/sesi_repository_drift.dart](../lib/repositories/sesi_repository_drift.dart),
diuji di [../test/sesi_repository_drift_test.dart](../test/sesi_repository_drift_test.dart) —
termasuk round-trip field demi field dan satu uji tutup-buka-ulang dengan berkas sungguhan.
`SesiRepositoryMemori` tetap ada sebagai repo test. **Android satu-satunya target**; web butuh
`sqlite3.wasm` + `drift_worker.js` yang tidak ikut di-commit.

Dua hal yang dipindahkan keluar dari A2, dengan alasannya:

- **Pemulihan sesi yang masih berjalan → Tahap B.** ✅ **Selesai di sana.** Alasan penundaannya
  terbukti benar: yang membuat pemulihan bermakna adalah buffer jam sungguhan. Sesi aktif kini
  ditulis sejak shutter ditekan dan pada tiap perubahan, dipisahkan dari riwayat oleh konstruktor
  controller, dan jadwalnya dihitung ulang dari `t0` **absolut** — bukan dari sisa waktu. Sesi yang
  dibatalkan dihapus (`SesiRepository.hapus`), supaya draft yang tidak jadi dijalani tidak hidup
  kembali sebagai sesi aktif.
- **Menghapus data contoh → tetap di A4**, bersama tampilan kosongnya. `benihiBilaKosong()` di
  [../lib/main.dart](../lib/main.dart) mengisi basis data kosong sekali saat pemasangan pertama,
  supaya A2 tidak diam-diam mengosongkan aplikasi yang layarnya belum siap kosong.

**✅ A1 selesai** — seam-nya berdiri, waktu itu masih di memori:
`SesiRepository` + `SesiRepositoryMemori` ([../lib/repositories/sesi_repository.dart](../lib/repositories/sesi_repository.dart)),
controller menulis sesi yang berakhir lewat `repo`, riwayat dimuat di `main()` sebelum `runApp`,
dan [../test/sesi_repository_test.dart](../test/sesi_repository_test.dart) menguji kontraknya —
berkas itu harus tetap hijau tanpa diubah setelah A2. Nol perubahan perilaku.

Sisa Tahap A:

- [x] ~~Tambah `drift`~~ — terpasang, `drift` + `drift_flutter`, codegen lewat `build_runner`.
- [x] ~~Tabel `sesi`, `sampel`, `hasil_deteksi`~~ — id memakai teks (`SesiMakan.id`), bukan
      autoincrement, sesuai K5.
- [x] ~~Tabel `kalibrasi`~~ — masuk di Tahap B (skema v3), persis seperti yang dijadwalkan: begitu
      `SET_KALIBRASI` benar-benar sampai ke flash jam, aplikasi yang lupa pernah mengalibrasi
      berbohong tentang keadaan jamnya sendiri. Disimpan sebagai riwayat, bukan satu baris yang
      ditimpa — offset yang melonjak antar kalibrasi adalah tanda salah satunya keliru, dan itu hanya
      terlihat bila yang lama masih ada.
- [x] ~~Tabel `anchor_waktu`~~ — kolom `dibuat_pada` yang sempat direncanakan **dibuang**: ia tidak
      pernah bisa berbeda dari `epoch`, dan kolom yang selalu menduplikasi kolom lain pada akhirnya
      akan berselisih karena bug. Urutan anchor ditentukan `uptime_s`, bukan waktu penulisan —
      uptime satu-satunya besaran yang pasti monoton dalam satu boot.
- [x] ~~`SesiRepositoryDrift` menggantikan `SesiRepositoryMemori` di `buatControllerBawaan()`~~ —
      `SesiRepositoryMemori` tetap ada sebagai repo test.
- [x] ~~Skema v1~~ — `onUpgrade` sengaja melempar `UnsupportedError`, sehingga `schemaVersion` tidak
      bisa dinaikkan tanpa migrasi yang benar-benar ditulis.
- [x] ~~Penanganan error saat basis data gagal dibuka~~ — `AplikasiGagalMulai`.
- [x] ~~Jalur pelaporan untuk `_simpan()` yang gagal~~ — `galatPenyimpanan` + kartu di Beranda.
- [x] ~~Hapus `contohRiwayatSesi()` dari jalur produksi~~ — `contoh_sesi.dart` kini hanya dipakai test.

**Selesai bila:** menutup dan membuka aplikasi mempertahankan seluruh riwayat sesi, dan pengguna
baru melihat riwayat **kosong** — bukan data contoh.

### 3.2 Profil

Sekarang kunci `user_*` dibaca/ditulis langsung di tiap call site dengan default hardcoded
("Lathifa", dst.), tersebar di [../lib/informasi_pribadi_page.dart](../lib/informasi_pribadi_page.dart),
[../lib/profil_tab.dart](../lib/profil_tab.dart), dan [../lib/beranda_tab.dart](../lib/beranda_tab.dart).

- [x] ~~Buat `ProfilRepository` sebagai satu-satunya pintu ke `SharedPreferences`.~~
- [x] ~~Hapus semua default demo~~ — `Profil.kosong` menggantikannya; profil yang belum diisi
      ditampilkan sebagai ajakan melengkapi. Onboarding sendiri masuk Tahap D bersama akun.
- [ ] Tinggalkan `SharedPreferences` untuk data kesehatan apa pun (tinggi/berat/gol. darah)
      bila §10 menuntut enkripsi at-rest — pindahkan ke DB terenkripsi.

**Selesai bila:** menambah satu field profil hanya menyentuh repository + satu halaman.

### 3.3 State kosong

- [x] ~~Setiap permukaan yang sebelumnya dijamin punya data seed perlu tampilan kosong~~ —
      sebagian besar sudah ada sejak rancangan sesi makan; diuji di `pemasangan_baru_test.dart`:
      Beranda (belum ada sesi), [../lib/riwayat_tab.dart](../lib/riwayat_tab.dart) (riwayat kosong,
      dan filter yang tidak menghasilkan apa-apa), [../lib/analisis_tab.dart](../lib/analisis_tab.dart)
      (`AnalisisSesi` dengan < 2 sesi — tren least-squares tidak terdefinisi), dan tiga halaman
      detail metrik (dipanggil tanpa sesi mana pun).

**Selesai bila:** aplikasi yang baru dipasang bisa dijelajahi seluruh tabnya tanpa satu pun
exception atau kotak kosong tanpa penjelasan.

---

## 4. Tahap B — BLE sungguhan

**✅ Selesai di sisi aplikasi.** Yang tersisa adalah integrasi dengan firmware yang belum ada —
lihat catatan di puncak dokumen dan §11 protokol.

Empat keputusan Tahap B yang tidak ada di rencana semula, karena baru terlihat saat menulisnya:

- **`flutter_blue_plus` dipatok ke `^1.35.5`, bukan 2.x.** Versi 2 berpindah ke lisensi yang
  **menuntut pembelian untuk penggunaan komersial**, dan AsaWatch adalah produk yang akan dijual
  (§10). 1.35.x masih BSD 3-Clause. Bila lisensi komersialnya dibeli, naik ke 2.x hanya menuntut satu
  argumen `license:` pada `connect()`.
- **`permission_handler` dipatok ke `^12.0.1`, bukan 13.x.** 13.x menarik
  `permission_handler_android` 14, yang menuntut `compileSdk 37`; Android Gradle Plugin di proyek ini
  berhenti di 36 dan build-nya gagal. API yang dipakai `IzinBle` sama persis di kedua versi. Patokan
  ini boleh dilepas begitu AGP-nya dinaikkan (§9.1).
- **Id sesi menjadi UUID v4.** Protokol membawa `sesiId` sebagai 16 byte biner (§5.1), dan id lama
  (`sesi-<mikrodetik>`) tidak muat. Sesi lama di riwayat tetap terbaca; ia hanya tidak pernah
  dikirim ke jam lagi (`idSesiValid()`).
- **Kontrak `BleService` berubah satu tempat**, sesuai izin yang tertulis di bawah: stream
  `selesaiMakanDitekan` kini membawa `waktuTidakPasti` (§4.3 protokol). Tanpa itu, tidak ada jalan
  bagi lapisan BLE memberitahu bahwa `t0` yang baru saja dikirimnya adalah tebakan.
  `FakeBleService` dan seluruh test ikut diperbarui di commit yang sama.
- **Pemindaian disaring ke AsaWatch saja, di level OS.** Rancangan semula menampilkan perangkat BLE
  lain dengan `didukung: false` sebagai bukti murah bahwa pemindaiannya jalan; penyaringan di level
  OS menghemat baterai dengan cara yang tidak bisa ditiru penyaringan di Dart. Bukti yang hilang
  diganti kalimat di halaman pemindaian, dan syarat barunya jatuh ke firmware: service UUID **wajib**
  ada di paket iklan, bukan scan response (protokol §2.2).
- **Sesi butuh tenggat.** Sampai Tahap A, satu-satunya jalan sebuah sesi berakhir `tidakLengkap`
  adalah user menekan "akhiri lebih awal". Dengan jam sungguhan itu tidak cukup: jam yang mati,
  di-reboot, atau sensornya gagal meninggalkan sesi yang menunggu selamanya.
  `SesiMakanController.tenggatSampelTerakhir` (30 menit setelah titik +2 jam) yang menutupnya.

### 4.1 Implementasi

- [x] ~~Tambah `flutter_blue_plus`~~ — plus `permission_handler` untuk §4.4.
- [x] ~~Buat `lib/services/ble_asli_service.dart`~~ — codec protokolnya dipisah ke
      [../lib/services/protokol_jam.dart](../lib/services/protokol_jam.dart), yang murni byte ↔ Dart
      dan karena itu **satu-satunya bagian Tahap B yang bisa diuji tuntas tanpa hardware**
      ([../test/protokol_jam_test.dart](../test/protokol_jam_test.dart), 36 test).
- [x] ~~Arahkan `buatControllerBawaan()` ke implementasi asli~~ — dengan
      `--dart-define=PAKAI_JAM_PALSU=true` sebagai jalan kembali ke jam palsu
      ([../lib/konfigurasi.dart](../lib/konfigurasi.dart)). `FakeBleService` tidak pernah dihapus.

Pemetaan per anggota kontrak:

| Anggota | Catatan implementasi |
|---|---|
| `pindai()` | Filter service UUID AsaWatch **di level OS** (`startScan(withServices: …)`), demi baterai: iklan perangkat lain tidak pernah membangunkan proses aplikasi. Ini merevisi rencana semula yang menampilkan perangkat non-AsaWatch dengan `didukung: false` — lihat catatan revisi di protokol §2.2, termasuk syarat firmware yang menyertainya. **Tetap `StreamController`, bukan `async*`** — membatalkan langganan harus menghentikan scan seketika. |
| `sambungkan()` | Simpan `idPerangkat` ke penyimpanan agar bertahan lintas start. Ini yang membuat `StatusPerangkat.namaPerangkat` bisa membedakan "belum pernah dipasangkan" dari "di luar jangkauan" — semantik yang sudah dipakai UI. |
| `statusPerangkat` | Termasuk level baterai (characteristic Battery Service 0x180F) dan status koneksi. Emit segera saat berubah; `statusTerakhir` harus selalu terisi supaya UI tidak kosong. |
| `sampelMasuk` | Notify characteristic. Parsing paket biner → `Sampel`. Pengiriman **at-least-once**, jadi duplikat itu normal — dedup `(sesiId, index)` di controller sudah menanganinya, jangan dedup dua kali. |
| `selesaiMakanDitekan` | Sumber tunggal `t0`. Bila jam mengirim uptime (K2), konversi memakai offset yang diukur saat pairing, bukan `DateTime.now()` saat pesan tiba. |
| `siapkanSesi()` | Write + tunggu ack. Kembalikan `false` bila tidak tersambung — UI sudah menampilkan petunjuk yang benar untuk kasus itu. |
| `mintaUkur()`, `batalkanSesi()`, `kirimKalibrasi()` | Write dengan timeout + retry terbatas. |
| `sinkronkan()` | Tarik buffer jam. Panggil otomatis pada setiap reconnect dan pada `AppLifecycleState.resumed`. |
| `ukurSekarang()` | Pengukuran satu kali untuk alur kalibrasi ([../lib/kalibrasi_tekanan_darah_page.dart](../lib/kalibrasi_tekanan_darah_page.dart)). Butuh timeout — jam bisa saja tidak menjawab. |
| `dispose()` | Batalkan seluruh langganan dan timer. |

### 4.2 Protokol

**Sudah dirancang:** [protokol-jam.md](protokol-jam.md) (v1, belum diimplementasikan di kedua sisi).
Dokumen itu normatif untuk UUID, format paket, sinkronisasi waktu, buffer, kode error, dan mesin
status firmware — termasuk checklist kesesuaian yang harus dicentang kedua tim sebelum integrasi
dinyatakan selesai.

Sisi firmware-nya belum dimulai. Pengarahannya — stack (ESP32 + NimBLE), urutan pengerjaan F1–F5,
dan jebakan yang khusus muncul di ESP32 — ada di [firmware-esp32.md](firmware-esp32.md), dirancang
untuk disalin ke repo firmware sebagai `CLAUDE.md` bersama [protokol-jam.md](protokol-jam.md).

Dua hal dari protokol yang mengubah rencana di sini:

- **Ack hanya boleh dikirim setelah data tersimpan di DB** (protokol §6), sehingga Tahap A benar-benar
  memblokir Tahap B — bukan sekadar lebih murah didahulukan.
- **Firmware dan aplikasi dikerjakan paralel** terhadap dokumen protokol yang sama. Perubahan
  protokol setelah implementasi dimulai wajib menaikkan `versi_minor` (atau `versi_mayor` bila tidak
  kompatibel) dan diperbarui di dokumen dalam PR yang sama.

### 4.3 Ketahanan

- [x] ~~Reconnect otomatis dengan backoff~~ — 1s → 2s → … → maks 60s (§8 protokol), ditambah satu
      sinkronisasi paksa saat aplikasi kembali ke depan (`AppLifecycleState.resumed`).
- [x] ~~Perilaku saat koneksi putus **di tengah sesi**~~ — sesi tidak disentuh, dan
      [../lib/sesi_berjalan_page.dart](../lib/sesi_berjalan_page.dart) menyatakannya dengan kalimat
      sendiri, bukan hanya lencana "Jam terputus". Yang terakhir itu wajar dibaca sebagai sesi gagal,
      dan pengguna akan membatalkannya sendiri padahal datanya aman.
- [x] ~~Perilaku saat sampel tidak pernah datang~~ — tenggat di controller (lihat catatan di atas),
      diuji di [../test/pemulihan_sesi_test.dart](../test/pemulihan_sesi_test.dart).
- [x] ~~Baterai jam habis di tengah sesi~~ — sampel dengan `boot_id` berbeda dari `t0`-nya dibuang
      di `BleAsliService` (§5.3), sampel sebelum reboot tetap masuk, dan sesinya berakhir
      `tidakLengkap` lewat tenggat.
- [x] ~~Sesi dengan flag `waktu_tidak_pasti`~~ — `SesiMakan.waktuTidakPasti` (kolom, bukan turunan:
      begitu sesinya berakhir tidak ada lagi jejak untuk menurunkannya). Dikecualikan dari
      `sesiHariIni()`, `waktuMakan` menjadi null, dan `AnalisisSesi` tidak memasukkannya. Ditampilkan
      apa adanya dengan penjelasan, bukan dibuang diam-diam.

**Selesai bila:** satu sesi penuh (baseline → t0 → +1 jam → +2 jam) selesai dengan hardware
sungguhan, termasuk satu kali HP sengaja dimatikan Bluetooth-nya di tengah sesi. **Belum tercapai —
firmware-nya belum ada.** Yang sudah tercapai adalah seluruh butir "Aplikasi" di §11 protokol.

Satu hal yang lahir di sini dan tidak diramalkan rencana: **kotak masuk entri jam**
([../lib/repositories/entri_jam_repository.dart](../lib/repositories/entri_jam_repository.dart),
tabel `tabel_entri_jam`, skema v3). Aturan protokol §6 "ack hanya setelah data tersimpan permanen"
menuntut tempat menyimpan entri **sebelum** ia menjadi bagian sebuah sesi, karena jam menghapus
miliknya begitu di-ack. Barisnya ditandai selesai di dalam transaksi yang sama dengan penulisan
sesinya, dan yang tersisa saat aplikasi start diputar ulang seolah jam baru mengirimkannya.

### 4.4 Izin platform

[../android/app/src/main/AndroidManifest.xml](../android/app/src/main/AndroidManifest.xml) dan
[../ios/Runner/Info.plist](../ios/Runner/Info.plist) saat ini tidak mendeklarasikan izin apa pun.

- [x] ~~Android: `BLUETOOTH_SCAN` (`neverForLocation`), `BLUETOOTH_CONNECT`, `ACCESS_FINE_LOCATION`
      (`maxSdkVersion="30"`)~~ — plus `uses-feature bluetooth_le required="true"`, supaya Play Store
      menyembunyikan aplikasi ini dari perangkat yang tidak punya BLE alih-alih membiarkannya
      terpasang lalu gagal. `CAMERA` menyusul di Tahap C; `POST_NOTIFICATIONS` dan
      `FOREGROUND_SERVICE*` di Tahap E; `INTERNET` di Tahap C/D, dan sampai saat itu ketiadaannya
      adalah fitur, bukan kelalaian.
- [x] ~~iOS: `NSBluetoothAlwaysUsageDescription` dan `UIBackgroundModes: [bluetooth-central]`~~ —
      ditambah `NSBluetoothPeripheralUsageDescription` untuk iOS 12 ke bawah. Alasannya ditulis dalam
      Bahasa Indonesia dan menyebut manfaatnya. Izin kamera menyusul di Tahap C.
- [x] ~~Naikkan `minSdkVersion`~~ — ternyata tidak perlu dinaikkan: bawaan Flutter sudah **24**,
      di atas 23 tempat izin runtime mulai ada. Menuliskannya sebagai angka justru berbahaya —
      `flutter build` menjalankan migrasi yang menulis ulang baris itu kembali ke
      `flutter.minSdkVersion` pada setiap build, jadi angka yang ditulis tangan hilang diam-diam.
- [x] ~~Tambah `permission_handler` dan minta izin di titik yang masuk akal~~ —
      [../lib/services/izin_ble.dart](../lib/services/izin_ble.dart), dipanggil dari
      `PemindaianPerangkatPage` saat pemindaian benar-benar akan dimulai.
- [x] ~~Tangani izin ditolak permanen~~ — tiga jalan buntu dibedakan (ditolak sekali, ditolak
      permanen, Bluetooth mati), masing-masing dengan kalimat dan tombolnya sendiri. Yang permanen
      menawarkan Pengaturan; dua lainnya menawarkan "Coba Lagi", karena tombol Pengaturan di kasus
      itu justru menyesatkan.

---

## 5. Tahap C — Kamera dan analisis nutrisi

### 5.1 Kamera

[../lib/deteksi_makanan_page.dart](../lib/deteksi_makanan_page.dart) menggambar preview palsu, dan
`fotoPath` ([../lib/models/sesi_makan.dart](../lib/models/sesi_makan.dart)) hanya string tanpa file
di baliknya.

- [ ] Tambah `camera` (preview in-app, sesuai desain sekarang) atau `image_picker` (lebih
      sederhana, tapi mengubah tampilan).
- [ ] Simpan file ke direktori dokumen aplikasi, **bukan** cache — foto adalah bagian dari rekam
      sesi dan tidak boleh dihapus sistem.
- [ ] Kompresi sebelum diunggah (`flutter_image_compress`); simpan juga thumbnail untuk riwayat.
- [ ] Kaitkan penghapusan sesi dengan penghapusan filenya, agar tidak ada file yatim.
- [ ] Tangani: izin ditolak, kamera tidak tersedia (emulator), pengambilan dibatalkan,
      penyimpanan penuh.
- [ ] Ingat urutan yang dikunci rancangan UI: **baseline diambil saat shutter ditekan**, dan
      `siapkanSesi()` dipanggil setelah foto ada. Jangan menukar urutannya.

### 5.2 Analisis nutrisi

- [ ] Buat `NutrisiApiService implements NutrisiService`.
- [ ] **Panggil lewat backend, bukan langsung dari aplikasi.** API key yang ditempel di app
      bisa diambil siapa pun dari APK.
- [ ] `analisis()` sekarang tidak pernah gagal. Tambahkan ke kontrak/UI: timeout, kegagalan
      jaringan, foto tidak dikenali, dan antrean bila offline (analisis bisa menyusul — sesi tetap
      valid tanpa hasil nutrisi, karena `totalNutrisiHariIni` sudah melewati sesi tanpa hasil).
- [ ] UI status: sedang menganalisis (sudah ada lewat `hasil == null`), **gagal + tombol coba
      lagi** (belum ada), dan koreksi manual porsi — halaman deteksi sudah menyebut estimasi bisa
      meleset 30–50%, jadi koreksi manual bukan fitur tambahan melainkan konsekuensi dari klaim itu.
- [ ] Simpan `keyakinan` dan tampilkan bila rendah.

**Selesai bila:** memotret tiga makanan berbeda menghasilkan tiga hasil berbeda yang masuk akal,
dan mematikan jaringan menghasilkan pesan yang jelas, bukan spinner selamanya.

---

## 6. Tahap D — Akun dan backend

> Bentuk backend-nya dirancang di [rancangan-api-laravel.md](rancangan-api-laravel.md) —
> Laravel + Sanctum, mencakup §5.2 (proxy analisis nutrisi) sekaligus bagian ini.

[../lib/login_page.dart](../lib/login_page.dart) dan [../lib/register_page.dart](../lib/register_page.dart)
hanya menjalankan `validate()` lalu navigasi.

- [ ] Pilih backend (Firebase Auth / Supabase / server sendiri). Firebase paling cepat; server
      sendiri lebih mudah bila §10 menuntut data kesehatan tinggal di Indonesia.
- [ ] Token di `flutter_secure_storage`, **bukan** `SharedPreferences`.
- [ ] Refresh token + penanganan 401 terpusat.
- [ ] Lupa password, verifikasi email, dan hapus akun (disyaratkan Play Store & App Store).
- [ ] Logout sekarang hanya `pushNamedAndRemoveUntil`. Harus juga: hapus token, hapus/kunci data
      lokal, hentikan sesi aktif, dan putuskan jam.
- [ ] Onboarding profil untuk pengguna baru, menggantikan default demo yang dihapus di §3.2.

---

## 7. Tahap E — Perilaku latar belakang

### 7.1 Sesi berjalan saat app tidak di depan

Sesi berlangsung ~2 jam. Pengguna pasti akan meninggalkan aplikasi.

- [ ] Android: foreground service selama ada sesi aktif (`flutter_foreground_task`), dengan
      notifikasi persisten yang menampilkan hitung mundur ke sampel berikutnya.
- [x] ~~iOS: andalkan buffer jam + `sinkronkan()` pada `AppLifecycleState.resumed`~~ — sudah
      terpasang di Tahap B (`BleAsliService.kembaliKeDepan()`, dipanggil dari `MyApp`). Ini membuat
      K3 menjadi persyaratan firmware, bukan preferensi.
- [x] ~~Uji app di-kill paksa di tengah sesi~~ — dipulihkan dari DB dengan jadwal dihitung ulang dari
      `t0` absolut, diuji di [../test/pemulihan_sesi_test.dart](../test/pemulihan_sesi_test.dart).
      Yang tersisa di sini murni Android: foreground service.

### 7.2 Notifikasi

- [ ] Tambah `flutter_local_notifications`.
- [ ] Peristiwa yang layak diberitahukan: sesi dimulai (tombol jam terdeteksi), sampel +1 jam dan
      +2 jam masuk, sesi selesai & hasil siap, sesi berakhir `tidakLengkap`.
- [ ] Tap notifikasi membuka halaman yang tepat (`SesiBerjalanPage` atau `RingkasanSesiPage`).
- [ ] Hormati `hasilBelumDibaca` — jangan memberi notifikasi ulang untuk hasil yang sudah dibuka.

---

## 8. Tahap F — Data yang masih literal

Bagian ini tidak memblokir rilis, tapi setiap itemnya adalah janji yang belum ditepati aplikasi.

- [ ] [../lib/tujuan_kesehatan_page.dart](../lib/tujuan_kesehatan_page.dart): target harian harus
      bisa diatur pengguna dan disimpan. `target_harian.dart` beserta angka bawaannya
      (2000 kcal / 250 g / 60 g / 65 g) **sudah dihapus**, bukan dibiarkan menunggu: Beranda
      menampilkannya sebagai pembanding lengkap dengan bar kemajuan, padahal tidak seorang pun
      pernah memilih angka itu. Sampai halaman ini punya target kalori sungguhan, ringkasan harian
      di Beranda menampilkan jumlah tanpa penyebut.
- [ ] Kotak "rentang normal" di tiga halaman detak/gula/tekanan masih teks tetap. Idealnya
      diturunkan dari profil (usia, kondisi, arahan dokter) — dan bila tidak, kalimatnya harus
      berhenti terdengar seperti nasihat medis personal.
- [ ] Langkah how-to di [../lib/menghubungkan_perangkat_page.dart](../lib/menghubungkan_perangkat_page.dart)
      harus cocok dengan hardware sungguhan.
- [ ] `AnalisisSesi` ([../lib/models/analisis_sesi.dart](../lib/models/analisis_sesi.dart)): tetapkan
      jumlah sesi minimum sebelum tren, pemicu lonjakan, dan tally pemulihan ditampilkan. Garis tren
      dari dua titik adalah kebohongan statistik.

---

## 9. Tahap G — Kesiapan rilis

### 9.1 Build

- [ ] Ganti `applicationId` / bundle ID dari `com.example.*`.
- [ ] Keystore Android + `key.properties` (di luar git), provisioning profile iOS.
- [ ] Ikon aplikasi dan splash screen.
- [ ] `flutter build appbundle --release`; verifikasi R8/ProGuard tidak merusak refleksi plugin.
- [ ] Skema versi dan proses build number.

### 9.2 Observability

Sekarang nol.

- [ ] Crash reporting (Sentry atau Firebase Crashlytics).
- [ ] Log peristiwa BLE ke buffer lokal yang bisa diekspor — kegagalan BLE hampir mustahil
      didiagnosis dari laporan pengguna saja.
- [ ] Analitik funnel minimal: pairing berhasil/gagal, sesi dimulai, sesi selesai vs `tidakLengkap`.
      Semuanya harus mematuhi §10.

### 9.3 Kualitas

- [ ] `flutter analyze` bersih.
- [ ] Test yang ada tetap hijau memakai `FakeBleService`/`FakeNutrisiService`, plus test baru untuk
      repository dan parsing paket BLE.
- [ ] Uji perangkat nyata pada layar sempit — bottom nav memang overflow di bawah ~370 px logis.
- [ ] CI: `analyze` + `test` pada setiap PR.

---

## 10. Regulasi, privasi, dan klaim

**Bagian ini bukan formalitas.** Aplikasi ini menampilkan gula darah dan tekanan darah dari
smartwatch non-invasif.

- [ ] **Tetapkan klaim produk secara tertulis (K6).** "Estimasi untuk pemantauan gaya hidup"
      dan "pengukuran gula darah" adalah dua produk yang berbeda secara hukum.
- [ ] Konsultasikan status alat kesehatan (Kemenkes/BPOM untuk Indonesia; regulator setempat bila
      dijual ke luar). Ini bisa memakan waktu berbulan-bulan — mulai sejajar dengan Tahap A, bukan
      setelah Tahap G.
- [ ] Disclaimer eksplisit di dalam aplikasi: bukan alat diagnosis, jangan dipakai untuk keputusan
      pengobatan, temui dokter. Tempatkan di onboarding **dan** di halaman detail metrik.
- [ ] Kebijakan privasi dan persetujuan pemrosesan data kesehatan (UU PDP).
- [ ] Enkripsi data at-rest (`sqlcipher`/`drift` terenkripsi) dan TLS untuk seluruh trafik.
- [ ] Ekspor data dan hapus akun + data.
- [ ] Data Safety form (Play Store) dan Privacy Nutrition Label (App Store) — keduanya menuntut
      inventaris data yang akurat, jadi catat sejak sekarang setiap data yang dikumpulkan.

---

## 11. Urutan pengerjaan

| Tahap | Isi | Blokir | Boleh paralel dengan |
|---|---|---|---|
| ✅ A | Persistensi lokal (§3) | — | §10 (konsultasi regulasi), K1–K6 |
| ✅ B | BLE sungguhan + izin (§4) | A | — |
| C | Kamera + analisis nutrisi (§5) | A | B |
| D | Akun & backend (§6) | A | B, C |
| E | Latar belakang & notifikasi (§7) | B | D |
| F | Data literal tersisa (§8) | A | mana saja |
| G | Kesiapan rilis (§9) | semua | — |

Aturan main supaya tetap terkontrol:

1. **Satu tahap, satu branch, satu PR.** Jangan mencampur A dan B.
2. **Setiap tahap selesai dengan tiga hal:** kode, test, dan pembaruan
   [../CLAUDE.md](../CLAUDE.md) — karena setiap tahap membatalkan sebagian deskripsi arsitektur di
   sana (mis. "data hidup di memori", "auth palsu", "satu-satunya persistensi adalah
   SharedPreferences").
3. **Perbarui baris Status di puncak dokumen ini** setiap kali satu tahap selesai.
4. `FakeBleService` dan `FakeNutrisiService` **tidak pernah dihapus** — keduanya adalah tulang
   punggung test dan satu-satunya cara mendemokan aplikasi tanpa hardware.
5. Setiap tahap yang menambah kegagalan baru (jaringan, izin, hardware) wajib menambahkan
   tampilan error dan tampilan kosongnya dalam PR yang sama, bukan menyusul.
