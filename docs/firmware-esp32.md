# Firmware Jam AsaWatch — ESP32

Berkas pengarahan untuk mengerjakan **firmware**-nya, bukan aplikasinya.

> **Sinkron dengan protokol v1.2.** Berkas ini hidup di dua tempat (lihat "Cara memakai berkas ini"),
> dan sudah dua kali bercabang diam-diam. Bila baris ini tidak sama dengan `Status:` di
> [protokol-jam.md](protokol-jam.md), atau tidak sama dengan salinan di repo firmware, **salah satu
> salinan tertinggal — periksa sebelum mengerjakan apa pun dari sini.** Perbarui baris ini setiap
> kali versinya naik.

## Cara memakai berkas ini

Firmware hidup di repo sendiri: **`/home/rad/Arduino/jam_ble_check`** — sketch Arduino, bukan repo
git, dan **bukan** di bawah `Project Enuma/`. Isinya `jam_ble_check.ino`, `ble_jam.cpp/h`,
`ring.cpp/h`, `penyimpanan.cpp/h`, `sensor_mock.cpp/h`, `protokol.h`, dan `docs/` yang memuat
salinan `protokol-jam.md`. F1–F4 selesai, F5 belum, sensor masih mock.

Kalau dokumen ini menyuruh memperbarui sesuatu "di kedua repo", repo kedua itu direktori tersebut.
Salinan di sana **mudah tertinggal** — pernah terjadi, dan gejalanya adalah firmware yang
mengimplementasikan rancangan yang sudah dibatalkan.

Salin dua berkas ke sana:

```
firmware-asawatch/
├── CLAUDE.md            ← berkas ini
├── docs/protokol-jam.md ← salin apa adanya dari repo aplikasi
└── src/…
```

**`protokol-jam.md` adalah satu-satunya sumber kebenaran untuk UUID, tata letak paket, opcode, dan
kode error.** Berkas ini tidak mengulang satu pun tabel dari sana, dengan sengaja: dua salinan tabel
byte akan berselisih, dan perselisihannya baru ketahuan sebagai paket yang salah dibaca di
pergelangan tangan orang. Kalau butuh offset, buka dokumen itu.

Yang ada di sini hanyalah hal-hal yang **tidak ada** di dokumen protokol: pilihan stack, urutan
pengerjaan, dan jebakan yang khusus muncul di ESP32.

Bila protokol perlu berubah setelah implementasi dimulai, naikkan `versi_minor` (atau `versi_mayor`
bila tidak kompatibel mundur) dan perbarui dokumennya **di PR yang sama** — di kedua repo.

## Apa yang sedang dibangun

Jam tangan pendamping aplikasi Flutter AsaWatch. Ia mengukur gula darah, detak jantung, tekanan
darah, dan SpO2 pada empat titik seputar satu sesi makan, lalu mengirimkannya lewat BLE.

**Aturan yang membentuk semua keputusan di bawah (protokol §1):**

> Jam adalah **sensor + buffer + pencacah**. Bukan tempat logika.

Verdict, kualitas respons, waktu pemulihan, tren, "lonjakan" — semuanya dihitung di aplikasi dan
tidak pernah disimpan. Firmware tidak perlu tahu satu pun konsep itu. Ini bukan sekadar pembagian
kerja: logika di firmware hanya bisa diperbaiki lewat OTA (yang belum ada), logika di aplikasi lewat
update biasa.

Kalau sebuah fitur terasa seperti "jam yang pintar", kemungkinan besar ia salah tempat.

## Stack

- **ESP32** (varian apa pun yang punya BLE; ESP32-C3/S3 sama saja untuk keperluan ini).
- **NimBLE-Arduino**, bukan stack BLE bawaan ESP32 Arduino. Untuk 5 karakteristik + bonding,
  selisih RAM dan flash-nya besar dan tidak ada yang hilang.
- **NVS** untuk `boot_id`, offset kalibrasi, **dan ring buffer** — satu blob 2,5 KB yang ditulis
  ulang utuh. Bukan partisi flash mentah; alasannya ada di F3, dan itu keputusan yang sudah diambil.

## Urutan pengerjaan

Dikerjakan berurutan. Setiap langkah punya "selesai bila" yang bisa diperiksa tanpa langkah
berikutnya.

### F1 — Iklan dan handshake

Iklan sesuai §2.2, karakteristik Info (§3) yang mengembalikan 20 byte.

**Anggaran 31 byte paket iklan adalah butir paling mudah dilewatkan dan paling mahal akibatnya.**
UUID 128-bit memakan 18 byte, nama `AsaWatch 3F1A` 15 byte, manufacturer data 5 byte — totalnya 38.
Nama dan manufacturer data **harus** pindah ke scan response (`setScanResponseData`); UUID-nya yang
tetap di paket iklan.

Aplikasi memakai filter service UUID di level OS, dan filter itu bekerja pada paket iklan. Jam yang
menaruh UUID-nya di scan response **tidak akan pernah terlihat sama sekali** — bukan muncul lalu
gagal, melainkan tidak muncul, dengan gejala yang di layar tidak bisa dibedakan dari jam yang mati.

**Interval iklan mengikuti ada-tidaknya bond** (docs/alur-pemasangan-jam.md §3):

| Keadaan jam | Interval | Alasan |
|---|---|---|
| **Tidak punya bond** (`NimBLEDevice::getNumBonds() == 0`) | 100 ms, **terus-menerus, tanpa batas waktu** | pemasangan pertama |
| Punya bond, 30 detik pertama sesudah boot atau sesudah putus | 100 ms | sampel di buffer perlu cepat menyusul |
| Punya bond, sesudah itu | 1000 ms | hemat baterai |

Keputusannya dibaca dari jumlah bond, **bukan dari timer yang dipicu tombol**. Jendela 30 detik di
baris tengah bukan sisa rancangan tombol pairing dan tidak boleh dipakai untuk menghidupkannya
kembali — ia melayani jam yang baru terputus dan masih membawa sampel di buffer-nya.

Ini bukan pengaturan kenyamanan, melainkan **penghapus satu langkah penuh dari alur pengguna**. Jam
yang mengiklan cepat sejak dinyalakan tidak membutuhkan "mode pairing": tidak ada tombol yang harus
ditekan-tahan, tidak ada urutan yang harus dihafal, dan pengguna lansia cukup menyalakan jamnya.
Tidak ada baterai yang perlu dihemat pada jam yang memang belum dipakai untuk apa pun.

Android hanya bisa menyambung pada jendela iklan, jadi interval yang lambat membuat setiap percobaan
`connect` memakan detik demi detik dan sering kehabisan waktu — di layar itu terbaca sebagai
"pemasangan pertama selalu sulit", bukan sebagai iklan yang lambat.

**Selesai bila:** nRF Connect melihat `AsaWatch xxxx`, memfilternya dengan service UUID berhasil, dan
membaca karakteristik Info memberi 20 byte yang benar. Jam yang belum tersandingkan terlihat dalam
satu detik pertama pemindaian, dan jam yang sudah tersandingkan kembali ke interval hemat.

### F1b — Bonding

Bonding wajib, LE Secure Connections, **Just Works**, dengan enkripsi di kelima karakteristik kustom
(§8 protokol, termasuk kotak yang menjelaskan kenapa bukan passkey).

Dua hal yang berasal dari sisi aplikasi dan harus dipenuhi firmware:

1. **Bond bertahan di NVS.** Aplikasi menghentikan lingkaran sambung ulangnya begitu bond hilang, dan
   menampilkan "Jam Tidak Tersandingkan" — ia **tidak** akan menyandingkan ulang dari latar belakang.
   Jam yang kehilangan bond-nya sendiri setelah reboot karenanya tidak akan tersambung lagi sampai
   pengguna menyandingkannya secara manual.
2. **Jam yang bond-nya dihapus harus kembali mengiklan cepat**, sesuai tabel di F1. Setelah pengguna
   melepas pemasangan (dari aplikasi atau dari Pengaturan Bluetooth ponsel), jam kembali ke keadaan
   "belum pernah tersandingkan" dalam segala hal.
3. **Jam tidak pernah memulai security request sendiri.** Ia menerima penyandingan, tidak memintanya:
   biarkan ponsel yang memulai, dan jangan memanggil apa pun yang memicu pairing dari sisi jam saat
   koneksi terbentuk.

   Ini pasangan langsung dari aturan sisi aplikasi di butir 1
   ([alur-pemasangan-jam.md](alur-pemasangan-jam.md)): *"Penyandingan tidak pernah dimulai dari latar
   belakang."* Aplikasi sengaja berhenti dan menampilkan "Jam Tidak Tersandingkan" alih-alih
   menyambung lagi, justru supaya dialog penyandingan sistem tidak muncul entah kapan — saat
   penggunanya sedang menelepon atau sedang di aplikasi lain, tanpa ia sedang memasang apa pun.
   Jam yang meminta security sendiri **membatalkan seluruh kehati-hatian itu dari sisi seberang**,
   dan gejalanya identik: dialog yang mustahil dimengerti, yang paling mungkin ditolak.

**Selesai bila:** penyandingan pertama memunculkan konfirmasi Just Works tanpa permintaan PIN, bond
bertahan melintasi reboot jam, dan menghapus jam dari Pengaturan Bluetooth ponsel membuatnya kembali
mengiklan cepat.

### F2 — Waktu: `boot_id` dan `uptime_s`

Tidak ada satu pun paket yang boleh memuat wall clock. Baca §4 sebelum menulis baris pertama di sini
— seluruh bagian ini kontra-intuitif sampai alasannya masuk.

**Selesai bila:** `boot_id` naik tepat satu setiap kali daya diputus dan disambung lagi, bertahan di
NVS, dan `uptime_s` monoton naik dalam satu masa hidup daya.

### F3 — Ring buffer dan ack

64 entri di flash, event dan sampel bercampur dalam satu ruang `seq` (§6).

Aturan yang paling sering salah diimplementasikan: **entri tidak dihapus saat dikirim, hanya saat
di-`ACK_EVENT`.** Aplikasi baru meng-ack setelah entrinya tersimpan permanen di basis datanya. Jadi
duplikat adalah perilaku normal, bukan bug — jangan menambahkan mekanisme anti-duplikat di firmware.
Aplikasi sudah men-dedup dengan kunci `(sesiId, index)`.

`seq` berputar 1..255. **`0` tidak pernah dipakai** — aplikasi memakainya sebagai "belum pernah
menerima apa pun" saat mengirim `SINKRON`.

Entri lintas boot hidup berdampingan di buffer; masing-masing membawa `boot_id`-nya sendiri. Jangan
membersihkan buffer saat boot.

#### Penyimpanan: satu blob NVS, bukan partisi mentah

Terpasang sebagai `BlobRing` di `ring.cpp`: seluruh 64 entri ditulis ulang sekaligus lewat
`Preferences::putBytes` (`Entri` 40 byte x 64 = 2560, blob 2572). Jangan membalikkannya ke partisi
mentah tanpa membaca dua alasan ini.

- **`putBytes` tahan mati daya.** NVS menulis salinan baru lebih dulu, baru membatalkan yang lama.
  Erase-lalu-tulis di partisi mentah punya jendela ~50 ms yang, bila daya putus di dalamnya,
  menghapus **seluruh 64 entri**. Di perangkat yang kejadian pentingnya justru baterai habis, itu
  perbedaan yang menentukan.
- **Ausnya bukan masalah.** ~20-30 tulis/hari x 2,5 KB lewat partisi NVS 20 KB berarti tiap sektor
  kena erase beberapa kali sehari — 100.000 siklus habis dalam puluhan tahun. Baterai dan sensornya
  mati jauh lebih dulu.

Tiga aturan menempel pada keputusan itu.

1. **Penambahan entri ditulis segera; hanya ack yang boleh ditunda.** `JEDA_TULIS_MS` (3 detik)
   menggabungkan tulisan supaya pengurasan 64 entri tidak menjadi 64 tulis 2,5 KB berturut-turut —
   itu alasannya ada, dan jangan dihapus. Tetapi jeda itu **asimetris**: sampel yang baru diukur
   hidup hanya di RAM selama jendela itu, dan mati daya di dalamnya menghilangkannya **permanen**,
   sementara ack yang hilang cuma membuat entrinya terkirim ulang — yang §6 sebut perilaku normal
   dan yang sudah di-dedup aplikasi dengan `(sesiId, index)`. Jadi `ring_tambah_*` menulis seketika,
   `ring_ack` menunggu. Biayanya ~5 tulis tambahan per hari, dan yang menjadi alasan jeda itu ada
   tetap terlindungi, karena yang datang berombongan memang ack.

   **Protokol v1.3 memindahkan aturan ini dari kehati-hatian menjadi jalur utama.** Saat baris ini
   ditulis, jam menyala terus sepanjang sesi dan jendela 3 detik itu hampir tidak pernah tersentuh —
   perlu daya yang putus tepat di dalamnya. v1.3 mengunci pola pemakaian yang berbeda: pengguna
   menyalakan jam, mengukur satu titik, lalu **mematikannya lagi** untuk menghemat baterai
   (docs/protokol-jam.md §12). Tidak ada alasan bagi siapa pun untuk menunggu sesudah pengukurannya
   selesai, jadi mematikan jam dalam hitungan detik bukan kasus tepi melainkan yang diharapkan
   terjadi.

   Artinya sampel yang hilang di jendela itu bukan lagi kemungkinan kecil: ia titik ukur yang
   **tidak bisa diulang** — `t0+1 jam` cuma terjadi sekali — dan hilangnya tidak menghasilkan gejala
   apa pun selain titik yang tetap kosong. Kalau hanya satu butir dari berkas ini yang dikerjakan,
   butir inilah.
2. **Nilai balik `putBytes` wajib diperiksa.** Mengabaikannya lalu menurunkan flag `kotor` berarti
   buffer berhenti persisten **diam-diam** saat NVS penuh atau gagal, tanpa gejala apa pun sampai
   jam reboot dan seluruh isinya lenyap. Bila gagal: `kotor` tetap menyala supaya percobaan
   berikutnya mengulangnya, dan kegagalan yang berulang harus terlihat, bukan sekadar tercatat.
3. **Anggaran partisi NVS diukur, bukan diasumsikan.** Saat menulis, salinan lama dan baru hidup
   berdampingan (~5,2 KB), ditambah `boot_id` dan offset kalibrasi, dan NVS masih butuh satu halaman
   kosong untuk garbage collection. Default Arduino `nvs` = 0x5000 (20 KB) muat, tetapi periksa
   sekali dengan `nvs_get_stats()`.

**Selesai bila:** entri bertahan melewati reset, `SINKRON` mengirim ulang dari seq yang diminta,
buffer penuh mengirim `BUFFER_PENUH` (bukan diam-diam menimpa), entri kirim-ulang menyalakan flag
`dariBuffer`, sebuah entri baru selamat dari daya yang dicabut sedetik sesudahnya, dan `putBytes`
yang gagal tidak menurunkan `kotor`.

### F4 — Mesin status sesi

IDLE → ARMED → RUNNING, persis §9.

Lima hal yang wajib dipegang:

1. **Jadwal dihitung dari `uptime_s` absolut milik `t0`**, tidak pernah dari "sisa waktu". Sisa waktu
   yang diakumulasikan akan hanyut setiap kali ada penundaan.
2. **Reboot saat RUNNING mengakhiri sesi.** `uptime_s` kembali nol dan `t0` lama tidak bisa
   dibandingkan lagi. Kembali ke IDLE; sampel yang terlanjur ada tetap di buffer dengan `boot_id`
   lamanya. **Jangan mencoba melanjutkan sesi lintas boot** — tanpa RTC itu tidak mungkin, dan yang
   dihasilkan hanya data yang tampak sah tetapi salah.
3. **`MULAI_SESI` di ARMED sama persis dengan tombol fisik ditekan** (v1.2). Aplikasi kini punya
   tombol "Selesai Makan" sendiri, dan ia bekerja dengan meminta jam menekan tombolnya — bukan
   dengan mengirim waktu. Jadi: baca `uptime_s` sendiri, pindah ke RUNNING, ukur index 1, jadwalkan
   `+1 jam`/`+2 jam`, kirim `TOMBOL_SELESAI_MAKAN`. **Peristiwanya tidak boleh dibedakan dari tombol
   fisik** — tidak ada flag "dari aplikasi", dan tidak boleh ada. **Idempoten**: perintah yang sama
   untuk sesi yang sudah RUNNING cukup di-ACK lalu diabaikan, karena ACK bisa hilang di udara dan
   aplikasi akan mengulang. Dua `t0` untuk satu sesi adalah kerusakan yang tidak bisa diperbaiki
   siapa pun sesudahnya.

   **Jangan pernah menjawabnya `NAK 0x05` karena sensor sibuk** (§9.1). Justru urutan yang paling
   lazim membuatnya tiba selagi baseline masih diukur: shutter kamera memicu `UKUR` index 0, lalu
   pengguna menekan tombol di layar beberapa detik kemudian. `t0` adalah stempel waktu, bukan
   pengukuran — catat dulu, kirim peristiwanya, baru tunda index 1 sampai sensor bebas. Panggil
   `tekan_tombol()` yang sudah ada, jangan menyalin jalurnya: jalur kembar adalah cara paling pasti
   membuat keduanya lambat laun berbeda.

4. **`UKUR_SEKARANG` dilayani di ketiga status** (v1.2) — di kode sekarang handler-nya memang sudah
   tidak memeriksa `status_sesi`, jadi ini tinggal dipastikan — dan **tidak menyentuh mesin ini sama
   sekali** — tidak memindahkan status, tidak menggeser jadwal, tidak menghabiskan index. Pengguna
   bisa menekan "Pindai Kesehatan" kapan saja, termasuk di tengah sesi. Kalau sensornya kebetulan
   sedang mengerjakan titik ukur sesi, jawabannya `NAK` `0x05` — bukan pembacaan lama yang masih
   hangat di memori.

5. **Titik ukur sesi selalu menang saat berebut sensor** (§9.1) — dan ini **belum ada** di kode
   sekarang. `putar_sesi()` butuh penjaga "sedang mengukur"; hari ini ia aman semata-mata karena
   sensor mock-nya sinkron dan selesai seketika. Begitu F5 masuk, tanpa penjaga itu `ukur(2)` akan
   menabrak `UKUR_SEKARANG` yang sedang jalan.

   Titik ukur sesi yang bertabrakan **ditunda, tidak pernah dibatalkan**: `t0+1 jam` cuma terjadi
   sekali dan tidak bisa diminta ulang, sedangkan pindai atas permintaan bisa diminta lagi kapan
   saja. Bentuk `putar_sesi()` yang memakai `sekarang >= t0_uptime + 3600` dengan bitmask
   `index_selesai` sudah benar untuk ini — penundaannya otomatis dicoba lagi di iterasi berikutnya.

Seluruh siklus harus selesai walau HP tidak pernah tersambung sekali pun. Jam tidak menunggu
konfirmasi aplikasi untuk berpindah status — butir 3 adalah cara kedua menekan tombol yang sama,
bukan pengganti jadwal jam sendiri.

**Selesai bila:** tombol "Selesai Makan" mati di IDLE dan hidup di ARMED, ARM timeout 4 jam
menghasilkan `SESI_KEDALUWARSA`, satu sesi penuh selesai dengan BLE dimatikan sepanjang waktu, dan
sesi yang dimulai lewat `MULAI_SESI` berjalan sama persis dengan yang dimulai lewat tombol — termasuk
saat perintahnya dikirim dua kali.

### F5 — Sensor

**Kerjakan paling akhir, dan pakai nilai palsu sampai F1–F4 tuntas.**

Hampir semua yang bisa salah di sini adalah soal waktu, buffer, dan ack — bukan soal sensor. Kalau
keduanya dikembangkan bersamaan, setiap kegagalan punya dua tersangka dan waktu habis untuk menebak
yang mana. Keempat butir "Integrasi" di §11 semuanya bisa dicentang dengan sensor stub.

Metrik yang gagal diukur dikirim sebagai **`0`**, bukan nilai terakhir yang diketahui. Aplikasi
mengubahnya menjadi "tidak terukur" dan menampilkannya apa adanya; nilai basi yang dikirim seolah
segar akan ditafsirkan pengguna sebagai pengukuran sungguhan.

Bit `kemampuan` di handshake harus jujur: metrik yang bitnya 0 disembunyikan aplikasi dari UI, dan
itu jauh lebih baik daripada menampilkan "—" seolah pengukurannya gagal.

## Jebakan khusus ESP32

**Deep sleep me-reset `esp_timer`.** Bangun dari deep sleep adalah reset bagi CPU:
`esp_timer_get_time()` kembali dari nol, sedangkan pencacah RTC terus berjalan. Kalau firmware ini
memakai deep sleep, `uptime_s` **wajib** diturunkan dari pencacah RTC, bukan `esp_timer` — dan
`boot_id` **tidak boleh** naik saat bangun dari deep sleep, karena itu masih masa hidup daya yang
sama. Salah satu dari keduanya cukup untuk membuat setiap sesi yang melintasi tidur menjadi salah
waktu, dan salahnya tidak akan terlihat sampai ada yang membandingkan dengan jam dinding.

Cara paling aman di v1: **jangan pakai deep sleep sama sekali.** Light sleep tidak punya masalah ini.

**RTC memory bukan tempat `boot_id`.** Ia selamat dari deep sleep tetapi tidak dari baterai habis —
dan justru baterai habis itulah kejadian yang `boot_id` ada untuk menandainya. NVS.

**Ketahanan tulis flash.** Entri buffer ditulis dan dihapus terus-menerus, tetapi volumenya kecil:
empat sampel per sesi. Sudah diputuskan — satu blob NVS ditulis ulang utuh, dengan penundaan yang
menggabungkan tulisan; alasannya dan tiga aturan yang menempel padanya ada di F3. Yang perlu
diperhatikan bukan ausnya, melainkan dua godaan: menulis setiap perubahan status, dan menunda
tulisan yang membawa data baru.

**Menulis flash sambil BLE aktif** bisa memblokir cukup lama untuk mengganggu jadwal koneksi.
Tulisannya kecil, tetapi ukur, jangan asumsikan.

**Antrean notifikasi bisa penuh** saat mengosongkan buffer 64 entri sekaligus setelah lama tidak
tersambung. Kirim berurutan dengan jeda, jangan menembakkan semuanya dalam satu loop.

**MTU** diminta 185 oleh aplikasi, minimum yang bisa dipakai 35 — sampel butuh 31 byte utuh dalam
satu notifikasi. Jangan memotong sampel menjadi dua paket.

**Bonding wajib, LE Secure Connections, enkripsi di semua karakteristik kustom** (§8). Ini data
kesehatan. Di NimBLE:

```cpp
NimBLEDevice::setSecurityAuth(true, false, true);            // bond, MITM, SC
NimBLEDevice::setSecurityIOCap(BLE_HS_IO_NO_INPUT_OUTPUT);   // Just Works
```

plus izin `READ_ENC`/`WRITE_ENC` di kelima karakteristik.

**Argumen tengahnya `false`, dan itu bukan kelalaian.** Jam tidak punya layar maupun tombol angka,
jadi IOCap-nya NoInputNoOutput — dan dengan IOCap itu **MITM tidak akan pernah tercapai**. Memintanya
berarti menuntut jaminan yang tidak bisa dipenuhi perangkat kerasnya, dan yang dibeli hanya risiko
pairing ditolak. `(true, false, true)` menyatakan dengan jujur apa yang sebenarnya didapat: tautan
terenkripsi dan bond yang bertahan, tanpa perlindungan MITM pada saat pairing. Itulah persis yang
ditulis §8 protokol sebagai **Just Works**, dan §10 rencana produksi mencatatnya apa adanya di
inventaris data.

**Jangan "memperbaikinya" kembali menjadi `true`.** Ini ditinjau ulang hanya bila jam suatu hari
punya layar — passkey acak yang ditampilkan di jam memberi perlindungan sungguhan; angka yang
dipatok di firmware tidak.

## Menguji

**Tanpa aplikasi:** nRF Connect (Android/iOS) cukup untuk F1–F3. Ia bisa membaca handshake, menulis
opcode mentah ke karakteristik Kontrol, dan melihat notifikasi masuk. Sebagian besar bug byte-level
tertangkap di sini, jauh lebih cepat daripada lewat aplikasi.

**Dengan aplikasi:** repo aplikasi berjalan dengan jam sungguhan secara bawaan (`flutter run`). Kalau
perlu membandingkan dengan perilaku yang sudah benar, `flutter run --dart-define=PAKAI_JAM_PALSU=true`
menjalankan jam palsu yang menuruti protokol yang sama.

**Definisi selesai** adalah checklist §11 di `protokol-jam.md`: bagian "Firmware" seluruhnya, lalu
keempat butir "Integrasi". Bagian "Aplikasi" sudah dicentang dan diuji.

Butir integrasi yang paling banyak menemukan bug, dan karena itu jangan ditinggalkan terakhir:

> Bluetooth HP dimatikan **sebelum** foto diambil dan baru dinyalakan setelah +2 jam → seluruh sesi
> diterjemahkan dengan benar dari satu anchor di akhir.

Ia menguji buffer, `uptime_s`, anchor, dan mesin status sekaligus — dan ia adalah kasus pemakaian
yang sebenarnya, bukan kasus tepi: orang meninggalkan HP-nya.

## Yang sengaja tidak ada di v1

Ditulis eksplisit supaya tidak diam-diam masuk. Daftar lengkapnya di §10 dokumen protokol, tetapi
empat yang paling sering menggoda:

- **OTA firmware** — butuh infrastruktur sendiri. Bit `kemampuan`-nya sudah disediakan.
- **Melanjutkan sesi lintas reboot** — tidak mungkin tanpa RTC.
- **Pengukuran terjadwal di luar sesi** — keputusan produk yang sudah dikunci: jam **hanya** mengukur
  saat sesi makan.
- **Notifikasi dari HP ke jam** — bukan bagian dari konsep produk.
