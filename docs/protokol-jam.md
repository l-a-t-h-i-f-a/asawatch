# Protokol Jam Tangan AsaWatch — BLE GATT

Kontrak antara firmware jam tangan dan aplikasi Flutter. Dokumen ini **normatif**: bila kode dan
dokumen ini berbeda, salah satunya bug.

Status: **v1.2 — terimplementasi di sisi aplikasi (Tahap B), firmware menyusul.**
Riwayat perubahan versi ada di §12; naikkan `versi_minor` setiap kali perilaku kawat berubah.
Codec-nya ada di [../lib/services/protokol_jam.dart](../lib/services/protokol_jam.dart) dan diuji
offset demi offset di [../test/protokol_jam_test.dart](../test/protokol_jam_test.dart); yang memakai
kabelnya adalah [../lib/services/ble_asli_service.dart](../lib/services/ble_asli_service.dart).

Konteks: [rencana-produksi.md](rencana-produksi.md) §4 (Tahap B) dan
[rancangan-ui-sesi-makan.md](rancangan-ui-sesi-makan.md) §12. Firmware dikembangkan sendiri
(keputusan K1), sehingga skema di bawah didikte dari kebutuhan aplikasi, bukan sebaliknya.

Pengarahan untuk mengerjakan sisi firmware-nya — stack, urutan, dan jebakan khusus ESP32 — ada di
[firmware-esp32.md](firmware-esp32.md). Berkas itu **tidak** mengulang tabel paket mana pun dari
sini; dokumen ini tetap satu-satunya sumber kebenaran untuk byte.

**Batasan perangkat keras yang membentuk seluruh dokumen ini: jam tidak punya RTC.** Ia tidak
punya cara apa pun untuk mengetahui jam berapa sekarang, dan kehilangan seluruh pengetahuan waktu
setiap kali daya putus. Konsekuensinya dijabarkan di §4 dan menyentuh hampir setiap paket.

---

## 1. Prinsip rancangan

Enam aturan yang menjelaskan hampir semua keputusan di dokumen ini:

1. **Jam adalah sensor + buffer + pencacah. Bukan tempat logika.**
   Verdict, kualitas respons, waktu pemulihan, dan tren dihitung di aplikasi
   ([../lib/models/sesi_makan.dart](../lib/models/sesi_makan.dart),
   [../lib/models/analisis_sesi.dart](../lib/models/analisis_sesi.dart)) dan tidak pernah disimpan.
   Firmware tidak perlu tahu apa itu "lonjakan". Ini bukan sekadar pembagian kerja: logika di
   firmware hanya bisa diperbaiki lewat OTA, logika di aplikasi lewat update biasa.
2. **Jam tidak pernah mengirim wall clock.** Ia hanya mengirim `uptime_s` — detik sejak boot — dan
   `boot_id`. Aplikasi yang menerjemahkannya ke waktu sungguhan (§4). Jam tanpa RTC yang berpura-pura
   tahu jam berapa akan berbohong setiap kali baterainya habis.
3. **Jam tetap satu-satunya sumber `t0`.** Aplikasi tidak boleh menghitung `t0` dari waktu pesan
   tiba — pesannya bisa datang berjam-jam terlambat lewat buffer. Yang datang dari jam adalah `t0`
   dalam satuan `uptime_s`; wall clock-nya diturunkan, bukan ditebak.

   **Aplikasi sekarang punya tombolnya, dan aturan ini tetap utuh** (v1.2). `MULAI_SESI` (§5.1)
   membawa `sesiId` saja, **tanpa satu byte waktu pun**: jam yang membaca pencacahnya sendiri lalu
   mengirim `TOMBOL_SELESAI_MAKAN` seperti biasa. Yang ditambahkan bukan sumber `t0` kedua,
   melainkan cara kedua menekan tombol yang sama. Kalau suatu hari ada yang tergoda menaruh epoch di
   payload-nya, seluruh §4 runtuh: `t0` versi jam dinding tidak sebanding dengan `uptime_s` sampel
   mana pun, dan `+1 jam`/`+2 jam` akan dijadwalkan dari titik yang tidak ada di garis waktu jam.
4. **Seluruh penjadwalan di jam memakai `uptime_s`, tidak pernah wall clock.** Justru karena tidak
   ada RTC, jadwal sesi (`t0+1 jam`, `t0+2 jam`) menjadi lebih sederhana dan lebih tahan banting.
5. **Pengiriman at-least-once dengan ack eksplisit.** Duplikat adalah perilaku normal, bukan error.
   Aplikasi sudah men-dedup dengan kunci `(sesiId, index)` di `SesiMakanController` — jangan
   menambahkan dedup kedua di layer BLE.
6. **Versi protokol dinegosiasikan sejak byte pertama.** App lama + firmware baru harus gagal dengan
   pesan jelas, bukan salah membaca byte.

---

## 2. Identitas dan penemuan perangkat

### 2.1 UUID

Base UUID kustom. **Generate sekali, lalu bekukan** — mengganti UUID setelah ada perangkat di
tangan pengguna berarti perangkat itu tidak akan pernah ditemukan lagi.

```
Service AsaWatch : A5A70001-6B4C-4E2A-9D31-0F8C2E5A7B10
```

Nibble ke-4..8 (`0001`) adalah slot karakteristik; sisanya tetap.

| Karakteristik | UUID (suffix `-6B4C-4E2A-9D31-0F8C2E5A7B10`) | Properti | Arah |
|---|---|---|---|
| Info & Handshake | `A5A70002` | Read, Write | ↔ |
| Kontrol | `A5A70003` | Write with response | App → Jam |
| Peristiwa (Event) | `A5A70004` | Notify | Jam → App |
| Sampel | `A5A70005` | Notify | Jam → App |
| Status | `A5A70006` | Read, Notify | Jam → App |

Battery Level memakai standar `0x180F` / `0x2A19`, bukan karakteristik kustom — pengisi
`StatusPerangkat.baterai`.

**Angkanya hanya berlaku selagi tersambung.** Baterai tidak ikut ditahan seperti sampel: begitu
tautan putus, `StatusPerangkat.baterai` menjadi null dan UI tidak menampilkan apa pun (bukan tanda
kosong, petaknya hilang). Jam yang dipakai seharian jauh dari ponsel akan tetap "100%" di layar
kalau angka terakhir ditahan, dan user memutuskan mengisi daya berdasarkan angka itu. Aturannya ada
di model (`StatusPerangkat.baterai` adalah getter, dan `salin` ikut membuang nilainya saat status
berubah jadi terputus), bukan di tiap halaman — jadi permukaan baru tidak bisa lupa. Nilai segar
datang lagi dari paket Status saat menyambung (§7) dan dari langganan `0x2A19`.

### 2.2 Iklan (advertising)

Paket iklan **wajib** memuat:

- Complete List of 128-bit Service UUIDs: service AsaWatch di atas. **Wajib di paket iklan itu
  sendiri, bukan di scan response** — lihat kotak di bawah.
- Complete Local Name: `AsaWatch <4 hex terakhir serial>` — mis. `AsaWatch 3F1A`.
- Manufacturer Specific Data: 1 byte versi protokol mayor (§3), agar app bisa menandai firmware
  yang terlalu tua **sebelum** menyambung.

> **Ketiganya tidak muat dalam satu paket iklan legacy.** Batasnya 31 byte, sedangkan UUID 128-bit
> memakan 18 byte (2 header + 16 data), nama `AsaWatch 3F1A` 15 byte, dan manufacturer data 5 byte —
> total 38. Nama dan manufacturer data karena itu **harus pindah ke scan response**; UUID-nya yang
> tetap tinggal di paket iklan.
>
> Urutan ini tidak bisa dibalik: aplikasi memakai filter service UUID di level OS
> (`FlutterBluePlus.startScan(withServices: …)`), dan filter itu bekerja pada paket iklan. Jam yang
> menaruh UUID-nya di scan response **tidak akan pernah terlihat sama sekali** — bukan muncul lalu
> ditolak, melainkan tidak muncul, dengan gejala yang di layar tidak bisa dibedakan dari jam yang
> mati.

`pindai()` di [../lib/services/ble_service.dart](../lib/services/ble_service.dart) memetakan hasil
scan ke `PerangkatDitemukan`:

- `id` = identifier perangkat dari OS (MAC di Android, UUID di iOS — **berbeda per platform dan
  tidak boleh diasumsikan stabil lintas platform**).
- `nama` = Complete Local Name.
- `kekuatanSinyal` = RSSI.
- `didukung` = true **hanya** bila service UUID AsaWatch ada di iklan.

**Revisi Tahap B: perangkat non-AsaWatch tidak lagi ditampilkan sama sekali.** Rancangan awal
menampilkannya dengan `didukung: false` supaya pengguna punya bukti bahwa pemindaiannya jalan.
Penyaringan kini dilakukan di level OS demi baterai: paket iklan headset, TV, dan jam tetangga tidak
pernah membangunkan proses aplikasi, dan penghematan itu tidak bisa ditiru dengan menyaring di Dart.

Bukti yang hilang itu **wajib diganti dengan kalimat**, bukan dibiarkan hilang — halaman pemindaian
menyatakan bahwa hanya AsaWatch yang dicari, baik saat daftarnya kosong maupun tidak. Tanpa itu,
layar kosong terbaca sebagai aplikasi yang rusak. `PerangkatDitemukan.didukung` tetap dihitung dari
iklan dan tetap mengunci tombolnya, sebagai jaring kedua bila filternya suatu hari dilonggarkan.

**Interval iklan mengikuti ada-tidaknya bond, bukan tombol.**

| Keadaan jam | Interval |
|---|---|
| Tidak punya bond | 100 ms, **terus-menerus, tanpa batas waktu** |
| Punya bond, 30 detik pertama sesudah boot atau sesudah putus | 100 ms |
| Punya bond, sesudah itu | 1000 ms |

Baris tengah bukan sisa dari rancangan tombol pairing, dan jendelanya tidak boleh dipakai untuk
menghidupkannya kembali: ia melayani kasus yang berbeda, yaitu **jam yang baru saja terputus dan
membawa sampel di buffer-nya**. Ponsel yang kembali mendekat menemukannya dalam hitungan detik,
bukan puluhan detik, dan biayanya 30 detik iklan cepat per peristiwa putus.

> **Revisi: tidak ada "mode pairing".** Rancangan awal memakai iklan cepat selama 60 detik setelah
> tombol pairing ditekan. Itu dibatalkan karena penggunanya lansia
> (docs/alur-pemasangan-jam.md §3): tombol yang harus ditekan-tahan, dalam urutan yang harus
> dihafal, dengan tenggat 60 detik, adalah satu langkah penuh yang bisa dihapus tanpa kehilangan
> apa pun. Jam yang belum pernah tersandingkan tidak sedang mengerjakan hal lain, jadi tidak ada
> baterai yang perlu dihemat di sana.
>
> Konsekuensinya: **jam yang bond-nya dihapus harus kembali mengiklan cepat**, karena dalam segala
> hal ia kembali menjadi jam yang belum pernah dipasangkan.

---

## 3. Handshake dan versi

Karakteristik **Info & Handshake** (`A5A70002`) dibaca aplikasi segera setelah koneksi terbentuk,
sebelum operasi lain apa pun.

Read → 20 byte:

| Offset | Ukuran | Field | Catatan |
|---|---|---|---|
| 0 | 1 | `versi_mayor` | Naik saat ada perubahan yang tidak kompatibel. |
| 1 | 1 | `versi_minor` | Naik saat ada tambahan yang kompatibel mundur. |
| 2 | 6 | `serial` | Identitas perangkat yang stabil lintas platform. |
| 8 | 2 | `firmware_build` | uint16 LE. |
| 10 | 1 | `kapasitas_buffer` | Jumlah entri ring buffer (§6). |
| 11 | 1 | `kemampuan` | Bitfield: bit0 gula darah, bit1 tekanan darah, bit2 SpO2, bit3 OTA. |
| 12 | 2 | `boot_id` | uint16 LE. Naik satu setiap boot, disimpan di flash (§4.1). |
| 14 | 4 | `uptime_s` | uint32 LE, detik sejak boot. |
| 18 | 1 | `flag` | bit0: boot ini sudah punya anchor waktu tersimpan. |
| 19 | 1 | *reserved* | Nol. |

Aturan versi:

| Kondisi | Perilaku aplikasi |
|---|---|
| `versi_mayor` > yang didukung app | Tolak sambungan. Pesan: "Jam perlu aplikasi versi lebih baru." |
| `versi_mayor` < yang didukung app | Tolak sambungan. Pesan: "Firmware jam perlu diperbarui." |
| `versi_minor` berbeda | Lanjut. Field yang tidak dikenal diabaikan. |

`kemampuan` bukan hiasan: metrik yang bit-nya 0 harus disembunyikan dari UI, bukan ditampilkan
sebagai "—" seolah pengukurannya gagal. Bedanya bukan kosmetik — "—" berarti *diukur tetapi gagal*,
kalimat yang mengundang orang merapatkan tali jam dan mencoba lagi untuk sensor yang tidak pernah
dipasang di alatnya.

- [x] **Terpasang.** `KemampuanPerangkat` ([../lib/models/sesi_makan.dart](../lib/models/sesi_makan.dart))
      dibawa `StatusPerangkat.kemampuan` dan dihormati di timeline sesi, ringkasan sesi, pindai
      kesehatan, dan pintu halaman detail metrik. Dua aturan yang menyertainya, keduanya perlu:
      **null berarti belum diketahui dan artinya "semua boleh"** — menyembunyikan angka yang sudah
      ada di basis data karena aplikasi belum sempat handshake adalah kerugian yang pasti; dan
      **angka yang sudah ada tidak pernah disembunyikan** meski bitnya 0, karena sesi lama di riwayat
      bisa saja diukur jam lain.

**Detak jantung tidak punya bit**, dan itu disengaja: ia selalu dianggap ada. Jangan menambahkan bit
untuknya tanpa menaikkan `versi_minor` — aplikasi tidak akan pernah menyembunyikannya.

---

## 4. Waktu tanpa RTC

**Keputusan K2, direvisi: jam tidak menyimpan wall clock sama sekali.** Ia hanya punya pencacah
`uptime_s` yang berjalan sejak boot, dan `boot_id` yang membedakan satu masa hidup daya dari yang
lain. Aplikasi memegang seluruh pengetahuan tentang waktu sungguhan.

Ini bukan kompromi. Alternatifnya — jam menyimpan salinan wall clock di RAM — akan menghasilkan
stempel waktu yang **tampak sah tetapi salah** setiap kali daya sempat putus, dan kesalahan seperti
itu jauh lebih berbahaya daripada waktu yang jujur mengaku tidak diketahui.

### 4.1 `boot_id`

Disimpan di flash, dinaikkan satu setiap boot, tidak pernah direset. uint16 cukup: jam yang di-boot
sekali sehari baru berputar setelah ~180 tahun.

Fungsinya: menandai bahwa `uptime_s` dari dua entri boleh dibandingkan. Dua entri dengan `boot_id`
sama berada di garis waktu yang sama; `boot_id` berbeda berarti ada jeda daya yang **panjangnya
tidak diketahui siapa pun**.

### 4.2 Anchor

Pada **setiap koneksi**, setelah handshake, aplikasi menulis `ANCHOR_WAKTU` (opcode `0x01`, §5.1)
berisi epoch UTC saat itu dan `boot_id` yang baru saja dibacanya. Jam mencatat ke flash:

```
anchor = (boot_id, uptime_s saat perintah diterima, epoch_s dari aplikasi)
```

`boot_id` disertakan dalam perintah supaya jam bisa mem-`NAK` bila ia sempat reboot antara
handshake dan write — tanpa itu, anchor bisa terpasang pada garis waktu yang salah.

Konversi di aplikasi, untuk entri apa pun:

```
epoch_entri = anchor.epoch_s + (entri.uptime_s − anchor.uptime_s)
```

**Rumus ini berlaku juga untuk entri yang terjadi sebelum anchor dipasang**, karena `uptime_s`
monoton sejak boot dan selisihnya bisa negatif. Inilah yang menyelamatkan kasus paling umum: jam
menyala sendirian sepanjang siang, tombol ditekan, sampel terkumpul, lalu HP baru tersambung malam
harinya. Satu anchor di akhir sudah cukup untuk menerjemahkan seluruh isi buffer boot itu secara
akurat.

### 4.3 Kasus yang tidak bisa diselamatkan

Bila **satu boot penuh berlalu tanpa pernah sekali pun tersambung**, entri dari boot itu tidak punya
anchor dan tidak akan pernah punya — jam tidak tahu berapa lama ia mati sebelum boot berikutnya, dan
tidak ada di dunia ini yang tahu.

Jam menandainya sendiri: entri dari boot yang `flag` anchor-nya 0 dikirim dengan **flag bit1
(`waktu_tidak_pasti`)**.

- [x] **Ditetapkan dan terpasang (Tahap B).** `SesiMakan.waktuTidakPasti` menandainya, dan tiga
      pengecualian di rekomendasi dijalankan apa adanya: tidak ikut `sesiHariIni()`, `waktuMakan`
      menjadi **null** (bukan tebakan), dan `AnalisisSesi` tidak memasukkannya. Satu penyimpangan
      dari rekomendasi, dengan alasan: sesinya **tidak** otomatis berakhir `tidakLengkap`. Waktu yang
      tidak diketahui tidak membuat sampelnya hilang — kurvanya tetap benar karena `detikRelatifT0`
      hanya selisih dua pencacah (§5.3). Sesi seperti itu berjalan dan selesai seperti biasa, dengan
      penjelasan eksplisit di layar sesi berjalan bahwa waktunya tidak bisa dipastikan.
      `waktuTidakPasti` disimpan sebagai kolom, bukan dihitung: begitu sesinya berakhir, tidak ada
      lagi jejak yang bisa dipakai menurunkannya — anchor untuk boot itu tidak akan pernah ada.

Peluangnya kecil — perlu jam kehabisan daya, boot lagi, dipakai penuh satu sesi, lalu mati lagi,
semuanya tanpa HP pernah mendekat. Tapi ia harus punya jalur yang benar, bukan diserahkan ke
kebetulan.

### 4.4 Drift

Pencacah jam memakai osilator, bukan RTC terkompensasi suhu, jadi drift-nya bisa 50–100 ppm — sekitar
4–9 detik per hari. Untuk protokol ini, itu tidak berarti apa-apa: jadwal sesi berskala jam, dan
`detikRelatifT0` hanya dipakai untuk sumbu grafik.

Bila ternyata perlu presisi lebih:

- Aplikasi menyimpan **semua** anchor per `boot_id`, bukan hanya yang terbaru.
- Dua anchor dalam satu boot memberi laju sebenarnya osilator, dan konversinya bisa dikoreksi linear.

Jangan implementasikan ini di v1. Cukup pastikan skema penyimpanan anchor mengizinkan lebih dari satu
baris per boot, agar penyempurnaannya nanti tidak menuntut migrasi.

### 4.5 Konsekuensi untuk sisi aplikasi

- [x] ~~Anchor disimpan di DB lokal (Tahap A), bukan di memori.~~
- [x] ~~Tabel `anchor_waktu`~~ — tanpa `dibuat_pada`: kolom itu tidak pernah bisa berbeda dari
      `epoch`, dan kolom yang selalu menduplikasi kolom lain pada akhirnya akan berselisih karena bug.
- [x] ~~Konversi dilakukan satu kali saat entri masuk, lalu disimpan sebagai waktu absolut.~~
      `t0` disimpan sebagai `DateTime`, dan `detikRelatifT0` tiap sampel dihitung sebagai selisih
      `uptime_s` — bukan selisih dua waktu kalender, supaya bentuk kurvanya kebal terhadap anchor
      yang meleset (§5.3). Pasangan `(boot_id, uptime_s)` milik `t0` dibaca ulang dari kotak masuk
      saat aplikasi start, sehingga perhitungan itu tetap benar setelah restart.
- [x] ~~Jam tangan yang dipakai lintas HP tidak didukung di v1~~ — id perangkat yang disimpan pun
      berbeda per platform (MAC di Android, UUID di iOS), jadi ia tidak boleh ikut disinkronkan.

---

## 5. Karakteristik

### 5.1 Kontrol (`A5A70003`, Write with response)

Byte 0 = opcode, sisanya payload. Jam membalas lewat karakteristik Peristiwa dengan `ACK` atau
`NAK` yang membawa opcode asal — bukan lewat write response, karena beberapa perintah butuh waktu
(mis. pengukuran).

**Aplikasi tidak boleh menulis ke Kontrol sebelum langganan Peristiwa selesai** (CCCD ditulis).
Balasan datang sebagai notifikasi, dan notifikasi yang dikirim ke karakteristik yang belum
dilanggani lenyap tanpa jejak — `ACK`/`NAK` tidak masuk buffer dan tidak pernah dikirim ulang (§6).
Perintah yang balasannya hilang akan diulang tiga kali lalu menyerah, padahal jam sudah
menjalankannya sejak percobaan pertama.

Urutan yang benar setelah koneksi terbentuk: baca Info (§3) → langgani Peristiwa, Sampel, dan Status
→ **baru** `ANCHOR_WAKTU` dan perintah lain.

**Kecualinya tepat satu: `ACK_EVENT` (`0x08`) tidak pernah dibalas.** Meng-ack sebuah ack adalah
regresi tak berujung, dan menunggu balasannya akan menambah satu perjalanan pulang-pergi untuk
**setiap** entri yang masuk — pada buffer 64 entri yang baru tersinkronisasi, itu 64 perjalanan
tambahan berturut-turut. Jaminannya tidak hilang: `ACK_EVENT` yang lenyap di udara berarti jam
mengirim entrinya lagi, dan duplikat memang perilaku normal (§1 aturan 5).

| Opcode | Nama | Payload | Kontrak Dart |
|---|---|---|---|
| `0x01` | `ANCHOR_WAKTU` | 4B epoch UTC LE + 2B `boot_id` | (internal, §4.2) |
| `0x02` | `ARM_SESI` | 16B sesiId (UUID biner) | `siapkanSesi()` |
| `0x03` | `BATAL_SESI` | 16B sesiId | `batalkanSesi()` |
| `0x04` | `UKUR` | 16B sesiId + 1B index | `mintaUkur()` |
| `0x05` | `UKUR_SEKARANG` | — | `ukurSekarang()` |
| `0x06` | `SET_KALIBRASI` | 2B offset sistolik + 2B offset diastolik (int16 LE) | `kirimKalibrasi()` |
| `0x07` | `SINKRON` | 1B seq terakhir yang sudah diterima app | `sinkronkan()` |
| `0x08` | `ACK_EVENT` | 1B seq | (internal, §6) |
| `0x09` | `MULAI_SESI` | 16B sesiId | `mulaiSesi()` |

Catatan per opcode:

- **`ANCHOR_WAKTU` dikirim pada setiap koneksi, sebelum perintah lain.** Ia murah dan idempoten;
  mengirimnya terlalu sering tidak merugikan, melewatkannya sekali bisa membuat satu sesi penuh
  kehilangan waktunya.
- **`ARM_SESI`** adalah satu-satunya hal yang menyalakan tombol "Selesai Makan" di jam. Selama jam
  belum di-ARM, menekan tombolnya tidak menghasilkan apa-apa (opsional: getaran pendek + pesan di
  layar jam). Inilah mekanisme yang menjamin **tidak ada sesi tanpa foto makanan**.
- **`MULAI_SESI` adalah tombol "Selesai Makan" jam yang ditekan dari aplikasi** (v1.2). Payload-nya
  `sesiId` saja, dan ketiadaan waktu di dalamnya adalah seluruh isi perintah ini: jam membaca
  `uptime_s`-nya sendiri saat perintah tiba, berpindah ARMED → RUNNING, mengukur index 1, menjadwalkan
  `+1 jam`/`+2 jam`, lalu mengirim `TOMBOL_SELESAI_MAKAN` (§5.4) **persis seperti kalau tombol
  fisiknya yang ditekan**. Aplikasi tidak memperlakukannya sebagai jawaban: sesinya baru dimulai saat
  peristiwa itu sampai, lewat jalur yang sama sampai ke penulisan kotak masuk dan ack-nya.

  Kenapa dibuat begini, bukan aplikasi mengirim `t0`-nya sendiri: jam tidak punya RTC (§4), jadi
  satu-satunya `t0` yang bisa dibandingkan dengan `uptime_s` sampelnya adalah yang berasal dari
  pencacah yang sama.

  **Tombol fisik di jam tetap ada dan tetap yang utama.** Ia satu-satunya yang bekerja saat ponsel
  jauh, mati, atau tidak dipegang — dan itu justru keadaan yang paling lazim saat orang sedang makan.
  `MULAI_SESI` melayani keadaan sebaliknya: ponsel di tangan, jam di pergelangan, dan tidak ada
  alasan menyuruh orang mengingat tombol mana yang harus ditekan.

  Aturannya:

  - **Hanya dilayani dalam status ARMED**, dengan `sesiId` yang sama. IDLE → `NAK` `0x03`, sesi lain
    → `NAK` `0x04`. Ini yang menjaga "tidak ada sesi tanpa foto makanan" tetap berlaku untuk tombol
    baru ini juga.
  - **Tidak pernah ditolak karena sensor sedang sibuk.** Ini satu-satunya opcode pengukuran-adjacent
    yang tidak boleh menjawab `NAK` `0x05`, dan sebabnya ada di §9.1: `t0` adalah **stempel waktu,
    bukan pengukuran**. Keduanya kebetulan dipicu peristiwa yang sama, tetapi tidak punya kendala
    yang sama.

    Kasusnya bukan tepi melainkan urutan yang paling lazim: `UKUR` index 0 (baseline) dikirim saat
    shutter kamera ditekan, dan pengguna menekan tombol di layar beberapa detik kemudian — dengan
    sensor sungguhan, baseline itu masih berjalan. `NAK` `0x05` di situ membuat aplikasi mengulang
    5 detik lagi (§7), sehingga **`t0` bergeser 5 detik dari saat tombol benar-benar ditekan**, lalu
    bergeser lagi tiap pengulangan, lalu menyerah setelah percobaan ketiga sementara penggunanya
    sudah menekan dan mengira sesinya jalan.

    Yang benar: catat `t0`, pindah RUNNING, kirim `TOMBOL_SELESAI_MAKAN` — lalu **tunda index 1
    sampai sensor bebas**. Ini juga satu-satunya bacaan yang konsisten dengan aturan di atas bahwa
    peristiwanya tidak boleh dibedakan dari tombol fisik: tombol fisik tidak punya jalur "ditolak
    karena sibuk", jadi tombol dari aplikasi pun tidak boleh punya.
  - **Idempoten.** `MULAI_SESI` untuk sesi yang sudah RUNNING cukup di-`ACK` lalu diabaikan — jangan
    menetapkan `t0` kedua dan jangan mengirim `TOMBOL_SELESAI_MAKAN` lagi. ACK bisa hilang di udara
    dan aplikasi akan mengulang (§7); dua `t0` untuk satu sesi jauh lebih merusak daripada satu
    perintah yang terkirim dua kali.
  - **Peristiwa yang dikirimnya tidak dibedakan dari tombol fisik.** Tidak ada flag "dari aplikasi",
    dan memang tidak boleh ada: bagi seluruh sisa dokumen ini, keduanya adalah peristiwa yang sama.

- **`ARM_SESI` menimpa sesi ARMED sebelumnya** yang belum ditekan. Hanya satu sesi ARMED pada satu
  waktu — cerminan aturan satu-sesi-aktif di `SesiMakanController`.
- **Timeout ARM: 4 jam `uptime_s`.** Lewat dari itu jam mengirim `SESI_KEDALUWARSA` dan kembali IDLE.
  Tanpa ini, foto sarapan yang tombolnya tidak pernah ditekan akan menyalakan tombol sampai malam.
- **`SET_KALIBRASI` mengirim offset, bukan nilai referensi.** `Kalibrasi.offsetSistolik` /
  `offsetDiastolik` sudah dihitung di Dart; jam hanya menambahkannya ke pembacaan mentah. Nilai
  referensi tensimeter tidak perlu diketahui firmware. Offset disimpan di flash agar bertahan
  melewati boot. Sejak alur kalibrasi memakai metode manset berulang, offset itu adalah **median
  dari tiga putaran** pengukuran berpasangan, bukan selisih satu pengukuran — seluruhnya dihitung di
  aplikasi, jadi paketnya tidak berubah sama sekali. `UKUR_SEKARANG` untuk kalibrasi kini dipicu
  **bersamaan** dengan manset di lengan seberang, jadi jamnya harus benar-benar mengukur saat itu
  juga, bukan menjawab dengan bacaan terakhir yang masih hangat di memori. Yang juga tidak berubah: **jam tidak mengenal
  masa berlaku kalibrasi.** Ia tidak punya jam dinding (§4), jadi ia terus memakai offset terakhir
  selamanya; "kalibrasi kedaluwarsa" sepenuhnya penilaian aplikasi, dan firmware tidak boleh
  mencoba membantu dengan menghapus offsetnya sendiri.
- **`UKUR` dipakai untuk baseline (index 0)** saat shutter kamera ditekan — sebelum `t0` ada. Karena
  itu ia membawa `sesiId` yang sama dengan `ARM_SESI`.
  **`ARM_SESI` harus mendahuluinya**, bukan menyusul: jam hanya melayani `UKUR` dalam status ARMED
  (§9), dan permintaan baseline yang tiba selagi jam masih IDLE ditolak. Kegagalan itu tidak
  bergema — ketiga titik lain tetap masuk dengan benar, dan sesinya baru terlihat salah dua jam
  kemudian, saat ia menggantung menunggu baseline yang tidak akan pernah datang.
- **`UKUR_SEKARANG` dijawab dengan paket Sampel biasa** (§5.2), dengan `sesiId` **16 byte nol** dan
  `index` 0. Ia memang terjadi di luar sesi mana pun. Aplikasi memperlakukan `sesiId` nol sebagai
  "bukan sesi": sampelnya diteruskan ke pemanggil `ukurSekarang()`, tetapi tidak pernah menunggu ada
  sesi yang memilikinya.
  ACK untuk opcode ini tetap dikirim seperti biasa, mendahului paket Sampel-nya.
- **`UKUR_SEKARANG` punya dua pemakai, dan keduanya dimulai oleh manusia** (v1.2): alur kalibrasi
  tekanan darah, dan **pindai kesehatan atas permintaan**
  ([../lib/pindai_kesehatan_page.dart](../lib/pindai_kesehatan_page.dart)) — pengguna yang ingin
  mengukur di luar jam makan. Di kawat keduanya perintah yang sama persis; yang berbeda hanya apa
  yang dilakukan aplikasi terhadap hasilnya. Karena itu penambahan fitur ini **tidak mengubah satu
  byte pun**.

  Dua akibatnya untuk firmware, keduanya baru di v1.2:

  1. **`UKUR_SEKARANG` dilayani di ketiga status** (§9), bukan hanya IDLE. Pengguna boleh menekan
     tombol pindai kapan saja, termasuk saat sesi makan sedang berjalan, dan menolaknya di ARMED/
     RUNNING berarti fitur ini mati justru pada dua jam ketika aplikasi paling sering dibuka.
  2. **Ia tidak boleh menyentuh mesin status maupun jadwal sesi.** Titik ukur `t0+1 jam` dan
     `t0+2 jam` tetap dijadwalkan dari `uptime_s` absolut milik `t0` seperti sebelumnya (§9 aturan
     1); pindai yang menyela tidak menggeser, membatalkan, atau menggantikan salah satunya. Bila jam
     memang sedang mengukur pada detik itu, jawabannya adalah **`NAK` `0x05`** — aplikasi mengulang
     setelah 5 detik (§7) — bukan pembacaan lama yang masih hangat di memori.

  Aplikasi v1.2 tetap bekerja dengan firmware v1.1 yang menolaknya di luar IDLE: yang muncul di layar
  adalah kalimat `NAK`-nya, dan pindai selagi sesi berjalan sekadar tidak tersedia.

### 5.2 Sampel (`A5A70005`, Notify) — 31 byte

| Offset | Ukuran | Field | Sentinel gagal |
|---|---|---|---|
| 0 | 1 | `seq` — nomor urut ring buffer (§6) | — |
| 1 | 16 | `sesiId` (UUID biner) | — |
| 17 | 1 | `index` (0..3, sesuai `labelTitikSampel`) | — |
| 18 | 1 | `flag` — bit0 `dariBuffer`, bit1 `waktu_tidak_pasti` | — |
| 19 | 2 | `boot_id` uint16 LE | — |
| 21 | 4 | `uptime_s` uint32 LE — waktu ukur di garis waktu boot itu | — |
| 25 | 2 | `gula_darah` uint16 LE, mg/dL | `0` |
| 27 | 1 | `detak_jantung` uint8, bpm | `0` |
| 28 | 1 | `sistolik` uint8, mmHg | `0` |
| 29 | 1 | `diastolik` uint8, mmHg | `0` |
| 30 | 1 | `spo2` uint8, % | `0` |

**Sentinel `0` = metrik gagal diukur.** Ini sudah diantisipasi di
[../lib/models/sesi_makan.dart](../lib/models/sesi_makan.dart): *"Protokol BLE memakai sentinel 0;
konversikan ke null saat decode, jangan bawa 0 sampai ke UI."* Nol aman karena tidak ada nilai
fisiologis nol yang sah untuk kelima metrik ini.

**Jam tidak mengirim sampel `menunggu` atau `terlewat`.** Kedua status itu diturunkan aplikasi dari
jadwal: sampel yang belum datang = `menunggu`, dan yang belum datang setelah tenggat = `terlewat`.
Firmware tidak perlu tahu keduanya.

### 5.3 Dari `uptime_s` ke `detikRelatifT0`

Kontrak Dart memakai `detikRelatifT0` (negatif untuk baseline). Konversinya di `BleAsliService`,
dua langkah:

```
detikRelatifT0 = sampel.uptime_s − t0.uptime_s        // butuh boot_id sama
waktuUkur      = epoch(t0) + detikRelatifT0            // via anchor, §4.2
```

Dua hal yang membuat ini bekerja rapi:

- **Baseline gratis.** Ia diukur sebelum tombol ditekan, jadi `uptime_s`-nya lebih kecil dari
  `t0.uptime_s` dan selisihnya negatif dengan sendirinya — persis yang diminta model. Firmware tidak
  perlu menahan sampel baseline sampai `t0` ada.
- **`detikRelatifT0` kebal terhadap anchor yang salah.** Ia hanya selisih dua pencacah. Anchor yang
  meleset menggeser posisi sesi di kalender, tetapi **bentuk kurvanya tetap benar** — dan bentuk
  kurva itulah isi seluruh halaman ringkasan sesi.

Bila `boot_id` sampel berbeda dari `boot_id` `t0`-nya, sampel itu **dibuang**. Jam yang reboot di
tengah sesi telah kehilangan garis waktunya; sesi berakhir `tidakLengkap`.

### 5.4 Peristiwa (`A5A70004`, Notify) — 26 byte

| Offset | Ukuran | Field |
|---|---|---|
| 0 | 1 | `seq` |
| 1 | 1 | `jenis` |
| 2 | 16 | `sesiId` (nol bila tidak relevan) |
| 18 | 2 | `boot_id` uint16 LE |
| 20 | 4 | `uptime_s` uint32 LE |
| 24 | 1 | `flag` — bit0 `dariBuffer`, bit1 `waktu_tidak_pasti` |
| 25 | 1 | payload/kode |

| `jenis` | Nama | Arti |
|---|---|---|
| `0x01` | `TOMBOL_SELESAI_MAKAN` | **Sumber tunggal `t0`.** `uptime_s` = saat tombol ditekan. |
| `0x02` | `SESI_KEDALUWARSA` | ARM timeout 4 jam terlewat. |
| `0x03` | `SESI_DIBATALKAN_JAM` | Dibatalkan dari jam (mis. baterai kritis). Payload = alasan. |
| `0x04` | `UKUR_GAGAL` | Payload = index sampel yang gagal. |
| `0x05` | `ACK` | Payload = opcode yang di-ack. |
| `0x06` | `NAK` | Payload = kode error (§7). |
| `0x07` | `BUFFER_PENUH` | Entri tertua dibuang. Aplikasi mencatat kemungkinan data hilang. |
| `0x08` | `BOOT` | `boot_id` baru. Memicu `ANCHOR_WAKTU` dan `SINKRON` di aplikasi. |

`TOMBOL_SELESAI_MAKAN` memetakan ke stream `selesaiMakanDitekan`, yang membawa `DateTime t0` —
hasil konversi §4.2, bukan `DateTime.now()`. Ia **wajib masuk ring buffer** seperti entri lain;
justru event inilah yang paling sering terjadi saat HP tidak tersambung.

`BOOT` dikirim segera setelah koneksi bila `boot_id` berbeda dari yang terakhir diketahui aplikasi.
Selama jam menyala tanpa HP, event ini juga menunggu di buffer — dan `boot_id`-nya sendiri yang
memberi tahu aplikasi bahwa ada garis waktu baru.

### 5.5 Status (`A5A70006`, Read + Notify) — 8 byte

| Offset | Ukuran | Field |
|---|---|---|
| 0 | 1 | `status_sesi` jam: 0 idle, 1 armed, 2 running |
| 1 | 1 | `sampel_tertunda` — jumlah entri belum di-ack di buffer |
| 2 | 1 | `baterai` % (duplikasi `0x2A19`, agar satu kali baca cukup) |
| 3 | 1 | `flag`: bit0 sedang mengukur, bit1 kalibrasi tersimpan, bit2 baterai kritis, bit3 boot ini sudah punya anchor |
| 4 | 4 | `uptime_s` uint32 LE |

Mengisi `StatusPerangkat.sampelTertunda`, yang ditampilkan apa adanya di
[../lib/sesi_berjalan_page.dart](../lib/sesi_berjalan_page.dart).

> **Aplikasi ikut mengurangi angka ini sendiri, satu per satu, setiap kali ia meng-ack sebuah
> entri** (`BleAsliService._kurangiTertunda`). Alasannya ada di definisi field-nya: `sampel_tertunda`
> adalah "entri yang belum di-ack", dan yang meng-ack adalah aplikasi — jadi aplikasi sudah tahu
> jawabannya tanpa perlu bertanya. Dokumen ini tidak pernah menjanjikan jam mengirim notifikasi
> Status setelah buffernya terkuras, dan tanpa pengurangan itu angka di layar hanya berubah kalau
> ada paket Status yang kebetulan datang: "3 sampel tertunda" tetap terpampang setelah ketiga
> sampelnya masuk, tersimpan, dan tampil di layar sesi. Yang terlihat pengguna adalah tombol
> Sinkronkan yang tidak bekerja.
>
> Paket Status tetap yang berkuasa — ia menimpa hitungan lokal itu apa adanya. **Firmware
> dianjurkan mengirim notifikasi Status setelah buffer terkuras**, tetapi aplikasi tidak boleh
> bergantung padanya.

---

## 6. Buffer dan pengiriman ulang

Jam menyimpan **ring buffer 64 entri di flash** (event + sampel bercampur, satu ruang seq).
Ukurannya menjawab K3: 64 entri cukup untuk ~16 sesi penuh tanpa sinkronisasi sama sekali.

> **`ACK` dan `NAK` tidak pernah masuk ring buffer.** Kalimat "event + sampel bercampur" di atas
> pernah terbaca seolah mencakup keduanya, dan bacaan itu merusak: ACK yang menunggu di-`ACK_EVENT`
> tidak akan pernah dibersihkan aplikasi — aplikasi memang tidak meng-ack balasan — sehingga buffer
> 64 entri terisi penuh oleh ACK basi dan mulai membuang **sampel sungguhan**. Gejalanya baru muncul
> setelah puluhan perintah, jauh dari penyebabnya.
>
> ACK/NAK adalah percakapan sesaat, bukan riwayat. Ia dikirim langsung, sekali, dan tidak pernah
> dikirim ulang: balasan yang tiba berjam-jam kemudian lewat buffer tidak punya siapa pun yang masih
> menunggunya. `seq`-nya diisi **0**, yang §6 aturan 1 memang sudah sisihkan sebagai "bukan entri
> buffer".

**Flash, bukan RAM** — dan tanpa RTC ini menjadi lebih penting, bukan kurang: buffer adalah satu-satunya
hal yang menyeberangi batas boot.

Aturan:

1. Setiap entri dapat `seq` 1..255, berputar. `0` tidak pernah dipakai (menandai "belum ada").
2. Entri **tidak dihapus saat dikirim**, hanya saat di-`ACK_EVENT`.
3. Saat tersambung, jam mengirim seluruh entri belum-di-ack secara berurutan, lalu entri baru secara
   realtime.
4. Entri yang dikirim ulang mendapat `flag` bit0 (`dariBuffer`) = 1. Ini yang mengisi
   `Sampel.dariBuffer`, dan UI memang membedakan sampel yang datang terlambat.
5. Buffer penuh → entri tertua dibuang + kirim `BUFFER_PENUH`.
6. `SINKRON` (`0x07`) memaksa pengiriman ulang dari seq tertentu, dipakai saat aplikasi curiga ada
   yang hilang.
7. Entri **lintas boot boleh hidup berdampingan** di buffer. Masing-masing membawa `boot_id`-nya
   sendiri; jangan dibersihkan saat boot.
8. Record anchor (§4.2) disimpan terpisah dari ring buffer dan tidak pernah ditimpa oleh entri baru.

**Aplikasi hanya boleh meng-ack setelah data tersimpan permanen di DB lokal**, bukan saat notifikasi
diterima. Ack sebelum menulis berarti kehilangan data bila aplikasi crash di antara keduanya —
inilah alasan Tahap A (persistensi) dikerjakan sebelum Tahap B.

**Satu pengecualian: entri yang tidak bisa dibaca sama sekali tetap di-ack lalu dibuang.** Kegagalan
decode bersifat tetap — byte yang sama akan gagal dibaca dengan cara yang sama selamanya. Menahan
ack-nya berarti jam menyimpannya seumur hidup, mengirimnya ulang pada setiap sinkronisasi, dan satu
slot buffer hilang permanen; kalau cukup banyak terkumpul, entri yang **sah** yang mulai terbuang.
`seq` tetap terbaca pada offset 0 meski sisa paketnya tidak, jadi ack-nya selalu bisa dikirim.
Byte mentahnya wajib dicatat sebelum dibuang.

Ini **tidak** berlaku untuk kegagalan *menyimpan* (basis data penuh, terkunci). Yang itu bersifat
sesaat, entrinya masih punya harapan diproses pada percobaan berikutnya, dan karena itu tetap tidak
boleh di-ack.

Duplikat tetap mungkin (ack hilang di udara). Itu normal; dedup `(sesiId, index)` di controller
menanganinya.

---

## 7. Kode error (payload `NAK`)

| Kode | Arti | Perilaku aplikasi |
|---|---|---|
| `0x01` | Opcode tidak dikenal | Bug versi. Catat, jangan retry. |
| `0x02` | Payload tidak valid | Bug. Catat, jangan retry. |
| `0x03` | Jam belum di-ARM | `siapkanSesi()` gagal → sesi jadi `menungguPerangkat`. |
| `0x04` | Sesi tidak dikenal | Sesi sudah kedaluwarsa di jam. Batalkan di aplikasi. |
| `0x05` | Sedang mengukur | Retry setelah 5 detik. |
| `0x06` | Baterai terlalu rendah | Tampilkan ke pengguna; jangan retry. |
| `0x07` | Sensor gagal | Tampilkan; sampel jadi `terlewat`. |
| `0x08` | Kalibrasi belum ada | Tekanan darah dikirim tanpa koreksi — tandai di UI. |
| `0x09` | `boot_id` tidak cocok | Jam reboot di tengah perintah. Baca ulang handshake, anchor ulang, ulangi perintah. |

Semua write memakai timeout 5 detik dan maksimal 3 percobaan, kecuali yang dilarang retry di atas.

---

## 8. Koneksi

| Parameter | Nilai | Alasan |
|---|---|---|
| MTU | minta 185, terima ≥ 35 | Sampel butuh 31 byte dalam satu notifikasi. |
| Connection interval | 30–50 ms saat sesi berjalan, 200–500 ms saat idle | Hemat baterai di luar sesi. |
| Bonding | Wajib, LE Secure Connections, **Just Works** | Data kesehatan; lihat §10 rencana produksi dan kotak di bawah. |
| Enkripsi | Wajib pada semua karakteristik kustom | — |
| Reconnect | Backoff 1s → 2s → 4s → … → maks 60s | — |

> **Kenapa Just Works, bukan passkey.** Jam tidak punya layar, jadi satu-satunya passkey yang bisa
> dipakainya adalah angka yang dipatok di firmware. Angka seperti itu **bukan perlindungan MITM,
> melainkan tampilannya saja**: ia tertulis di firmware, di dokumen ini, dan di setiap salinan
> keduanya. Yang dibelinya hanya satu dialog tambahan yang tidak dipahami pengguna, dengan imbalan
> jaminan yang tidak benar-benar ada.
>
> Just Works menyatakan dengan jujur apa yang sebenarnya didapat: **tautan terenkripsi dan bonding
> yang bertahan, tanpa perlindungan terhadap MITM pada saat pairing.** Itu keadaan yang bisa ditulis
> apa adanya di inventaris data §10, dan yang tidak diam-diam salah.
>
> Yang **tidak** ikut turun: bonding tetap wajib, LE Secure Connections tetap wajib, dan enkripsi
> tetap wajib di kelima karakteristik kustom. Yang dilepas hanya otentikasi pairing-nya.
>
> Ini bisa ditinjau ulang **hanya bila jam punya layar** — passkey acak yang ditampilkan di jam
> memberi perlindungan sungguhan. Sampai saat itu, jangan "memperbaiki" ini kembali menjadi passkey
> tetap: hasilnya lebih buruk, bukan lebih baik.

Jam **tidak** memutus koneksi sendiri saat idle — biarkan OS mengelolanya. Setiap koneksi yang
terbentuk adalah kesempatan memasang anchor, jadi koneksi yang sering justru menguntungkan.

---

## 9. Mesin status di firmware

```
     ┌──────┐  ARM_SESI          ┌───────┐  tombol ditekan   ┌─────────┐
     │ IDLE │ ─────────────────▶ │ ARMED │ ────────────────▶ │ RUNNING │
     └──────┘                    └───────┘  atau MULAI_SESI  └─────────┘
        ▲                            │  timeout 4 jam            │
        │                            │  / BATAL_SESI             │ sampel index 3
        └────────────────────────────┴───────────────────────────┘  terkirim

     ANCHOR_WAKTU boleh masuk di status mana pun — ia tidak menyentuh mesin ini.
```

- Di **IDLE**: tombol "Selesai Makan" tidak berfungsi.
- Di **ARMED**: tombol aktif, dan `MULAI_SESI` (§5.1) melakukan hal yang sama persis dengan
  menekannya. `UKUR` index 0 (baseline) dilayani.
- Di **RUNNING**: jam menjadwalkan sendiri index 2 pada `t0.uptime_s + 3600` dan index 3 pada
  `+ 7200`. Index 1 diukur segera saat tombol ditekan.
- Sesi selesai → IDLE. Sampel yang belum terkirim tetap di buffer.

**`UKUR_SEKARANG` boleh masuk di ketiga status** (v1.2) dan, seperti `ANCHOR_WAKTU`, tidak menyentuh
mesin ini sama sekali: tidak memindahkan status, tidak menggeser jadwal, tidak menghabiskan satu
index pun. Ia sepenuhnya di luar diagram di atas.

### 9.1 Perebutan sensor

Sejak ada dua hal yang bisa meminta sensor pada saat yang sama — titik ukur sesi yang jatuh tempo
sendiri, dan permintaan yang dipicu jari manusia — urutan menangnya harus tertulis, bukan diserahkan
ke siapa yang kebetulan lebih dulu.

Satu kalimat yang mengatur semuanya:

> **Titik ukur sesi selalu menang. Ia ditunda, tidak pernah dibatalkan.**

Alasannya asimetri nilainya, bukan asimetri teknis: titik ukur sesi adalah data produknya dan
**tidak bisa diulang** — `t0+1 jam` cuma terjadi sekali. Pindai atas permintaan bisa diminta lagi
kapan saja, dan pengguna yang memintanya sedang memegang ponselnya. Membiarkan yang kedua membuat
yang pertama terlewat berarti menukar data yang tidak tergantikan dengan data yang tergantikan.

| Yang tiba | Sensor sedang sibuk | Perilaku |
|---|---|---|
| `MULAI_SESI` | apa pun | **Selalu diterima.** `t0` dicatat, `TOMBOL_SELESAI_MAKAN` dikirim, index 1 ditunda sampai sensor bebas. Tidak pernah `NAK` `0x05` (§5.1). |
| Titik ukur sesi jatuh tempo | `UKUR_SEKARANG` berjalan | **Ditunda, lalu diambil segera setelah sensor bebas.** Jangan dibatalkan, dan jangan biarkan pengukuran yang sedang jalan menabraknya. |
| `UKUR_SEKARANG` | titik ukur sesi berjalan | `NAK` `0x05`; aplikasi mengulang setelah 5 detik. **Satu-satunya yang boleh ditolak.** |
| `UKUR` index 0 (baseline) | apa pun | `NAK` `0x05`; aplikasi tidak mengulang selamanya dan menandai baseline `terlewat` (§7). |

> **Catatan silang, supaya tidak ada yang mengandalkan yang salah.** `uptime_s` sampel yang tertunda
> memang jujur mencatat kapan ia benar-benar diukur, dan itu benar untuk disimpan — tetapi
> **aplikasi tidak menampilkannya**: `SesiMakanController._terimaSampel` menormalkan
> `detikRelatifT0` tiap titik ke slot jadwalnya (`0` / `3600` / `7200`), karena label di layar
> memang menjanjikan "+1 jam" dan bukan "+1 jam 40 detik". Penundaan berskala detik karena itu tidak
> terlihat di mana pun, dan memang tidak perlu terlihat. Yang tidak boleh terjadi bukan penundaannya,
> melainkan titiknya hilang.

Dua hal yang wajib dipegang firmware:

1. **Jadwal dihitung dari `uptime_s` absolut milik `t0`, tidak pernah dari "sisa waktu".** Sama
   seperti aturan di `SesiMakanController`, dan karena alasan yang sama: sisa waktu yang
   diakumulasikan akan hanyut setiap kali ada penundaan.
2. **Reboot di tengah RUNNING mengakhiri sesi.** `uptime_s` kembali nol dan `t0` lama menjadi tidak
   bisa dibandingkan. Firmware kembali ke IDLE; sampel yang terlanjur ada tetap di buffer dengan
   `boot_id` lamanya, dan aplikasi menutup sesi itu sebagai `tidakLengkap` (§5.3). Jangan mencoba
   melanjutkan sesi lintas boot.

Seluruh siklus harus selesai walau HP tidak pernah tersambung sekali pun. Jam **tidak** menunggu
konfirmasi aplikasi untuk berpindah status.

---

## 10. Yang sengaja tidak ada di v1

Ditulis eksplisit supaya tidak diam-diam masuk:

| Ditunda | Alasan |
|---|---|
| OTA firmware | Butuh infrastruktur sendiri. Bit `kemampuan` sudah disediakan. |
| Koreksi drift osilator | §4.4. Skema anchor sudah menyiapkan tempatnya. |
| Satu jam dipakai lintas HP | Anchor hidup di satu HP. Butuh sinkronisasi anchor lewat backend (K5). |
| Melanjutkan sesi lintas reboot | Tidak mungkin tanpa RTC (§9). |
| Pengukuran **terjadwal** di luar sesi | Keputusan produk yang sudah dikunci: jam tidak pernah mengukur atas kemauannya sendiri di luar sesi makan. Yang **tidak** dilarang oleh baris ini adalah pengukuran atas permintaan pengguna (`UKUR_SEKARANG`, §5.1) — yang memicunya jari manusia, bukan timer di firmware, jadi tidak ada baterai yang terkuras diam-diam dan tidak ada angka yang muncul tanpa ada yang memintanya. |
| Notifikasi dari HP ke jam | Bukan bagian dari konsep produk. |
| Multi-sesi bersamaan | `SesiMakanController` mengizinkan tepat satu sesi aktif. |
| Data mentah PPG | Volumenya jauh melampaui BLE dan tidak dipakai UI mana pun. |

---

## 11. Checklist kesesuaian

Dipakai kedua tim sebelum integrasi dinyatakan selesai.

**Firmware**

- [ ] Setiap opcode dibalas `ACK`/`NAK` lewat karakteristik Peristiwa — **kecuali `ACK_EVENT`, yang
      tidak dibalas sama sekali** (§5.1). Perintah yang tidak dibalas membuat aplikasi mengulanginya
      tiga kali lalu menyerah, dan di layar itu terlihat seperti jam yang tidak merespons.
- [ ] `ACK`/`NAK` **tidak masuk ring buffer**, ber-`seq` 0, dan tidak pernah dikirim ulang (§6).
- [ ] Pengurasan buffer **baru dimulai setelah aplikasi berlangganan** karakteristik Sampel dan
      Peristiwa (CCCD ditulis), bukan begitu koneksi terbentuk. Notifikasi yang dikirim sebelum itu
      hilang tanpa jejak, dan entri yang terlanjur ditandai "sudah dikirim" tidak akan datang lagi
      sampai ada `SINKRON` berikutnya.
- [ ] `UKUR_SEKARANG` dijawab paket Sampel ber-`sesiId` 16 byte nol, `index` 0 (§5.1).
- [ ] `UKUR_SEKARANG` dilayani di **IDLE, ARMED, maupun RUNNING**, dan tidak menggeser jadwal titik
      ukur sesi (§9). Bila sensornya sedang sibuk, jawabannya `NAK` `0x05` — bukan pembacaan lama.
- [ ] Iklan memuat service UUID, nama, dan versi mayor.
- [ ] **Service UUID ada di paket iklan, bukan di scan response** (§2.2). Ini butir paling mudah
      dilewatkan dan paling mahal akibatnya: jam yang salah menaruhnya tidak akan pernah terlihat
      oleh aplikasi, dan gejalanya sama persis dengan jam yang mati.
- [ ] Handshake mengembalikan 20 byte sesuai §3.
- [ ] `boot_id` naik satu setiap boot dan bertahan di flash.
- [ ] Tidak ada satu pun paket yang memuat wall clock.
- [ ] `ANCHOR_WAKTU` dengan `boot_id` yang tidak cocok di-NAK dengan `0x09`.
- [ ] Record anchor bertahan melewati reboot, terpisah dari ring buffer.
- [ ] Entri dari boot tanpa anchor dikirim dengan flag `waktu_tidak_pasti`.
- [ ] Tombol "Selesai Makan" tidak berfungsi di IDLE dan berfungsi di ARMED.
- [ ] `MULAI_SESI` di ARMED menghasilkan peristiwa `TOMBOL_SELESAI_MAKAN` yang **tidak bisa
      dibedakan** dari tombol fisik, dan di IDLE di-`NAK` `0x03`.
- [ ] `MULAI_SESI` yang diulang untuk sesi yang sudah RUNNING di-`ACK` lalu **diabaikan** — bukan
      `t0` kedua, bukan peristiwa kedua.
- [ ] `MULAI_SESI` yang tiba **selagi baseline masih diukur** tetap diterima: `t0` tercatat pada
      detik perintahnya tiba, dan index 1 menyusul setelah sensor bebas. Tidak ada `NAK` `0x05` untuk
      opcode ini (§5.1, §9.1). Ini urutan yang paling lazim, bukan kasus tepi.
- [ ] Titik ukur sesi yang jatuh tempo selagi `UKUR_SEKARANG` berjalan **ditunda, bukan terlewat**,
      dan diambil segera setelah sensor bebas (§9.1). Penjaga "sedang mengukur" wajib ada di
      penjadwalnya — tanpa sensor sungguhan, ketiadaannya tidak menimbulkan gejala apa pun.
- [ ] ARM timeout 4 jam menghasilkan `SESI_KEDALUWARSA`.
- [ ] Reboot saat RUNNING → kembali IDLE, sampel lama tetap di buffer dengan `boot_id` lama.
- [ ] Siklus sesi penuh selesai tanpa HP tersambung sama sekali.
- [ ] Ring buffer bertahan melewati reset dan memuat entri lintas boot.
- [ ] Entri kirim-ulang menyalakan flag `dariBuffer`.
- [ ] Metrik gagal dikirim sebagai `0`, bukan nilai terakhir yang diketahui.
- [ ] Buffer penuh mengirim `BUFFER_PENUH`, bukan diam-diam menimpa.
- [ ] Offset kalibrasi bertahan melewati boot.
- [ ] Pairing memakai **Just Works** dengan LE Secure Connections — bukan passkey tetap (§8).

**Aplikasi** — seluruhnya selesai di Tahap B; yang di dalam kurung adalah tempat pembuktiannya.

- [x] Menolak versi mayor yang tidak cocok dengan pesan yang bisa dipahami pengguna
      (`InfoJam.periksaVersi`, `protokol_jam_test.dart`).
- [x] `ANCHOR_WAKTU` dikirim pada setiap koneksi, sebelum perintah lain
      (`BleAsliService._sambungkan`).
- [x] Anchor disimpan di DB, bukan memori, dan bertahan melewati restart aplikasi
      (`AnchorRepositoryDrift`, `anchor_repository_test.dart`).
- [x] Konversi `uptime_s` → epoch benar untuk entri **sebelum** anchor dipasang (selisih negatif).
- [x] Entri `waktu_tidak_pasti` tidak masuk `sesiHariIni()`, `WaktuMakan`, maupun `AnalisisSesi`
      (`sesi_makan_controller_test.dart`, `analisis_test.dart`).
- [x] Sampel dengan `boot_id` berbeda dari `t0`-nya dibuang (`BleAsliService._emitSampel`); sesinya
      berakhir `tidakLengkap` lewat tenggat di controller, bukan dibatalkan dari layer BLE.
- [x] Sentinel `0` dikonversi ke `null` sebelum meninggalkan layer BLE (`bacaSampel`), dan yang null
      ditulis "Tidak terbaca" di halaman pindai — bukan `—` di tempat angka (`pindai_kesehatan_test.dart`).
- [x] Bit `kemampuan` (§3) dihormati: metrik yang tidak dimiliki jam **hilang dari layar**, bukan
      menjadi `—` (`metrik_sesi_test.dart`). Dibaca dari handshake pertama **dan** dari handshake
      ulang sesudah jam menyala lagi, karena firmware-nya bisa saja sudah berganti.
- [x] Keempat metrik terlihat **selama sesi berjalan**, bukan hanya setelah selesai — detak, tekanan,
      dan SpO2 di tiap titik timeline yang sudah terisi (`metrik_sesi_test.dart`). Sebelumnya
      ketiganya sudah diukur di setiap titik sejak awal tetapi baru muncul di halaman ringkasan.
- [x] `ukurSekarang()` menunggu sampel ber-`sesiId` **nol**, bukan sampel berikutnya apa pun
      (`BleAsliService.ukurSekarang`). Perintahnya boleh dikirim selagi sesi berjalan dan selagi
      buffer terkuras, jadi sampel berikutnya di stream bisa milik sesi yang sama sekali lain.
- [x] `detikRelatifT0` dihitung dari selisih `uptime_s`, termasuk baseline yang negatif.
- [x] Ack dikirim **setelah** menulis ke DB (`BleAsliService._simpanLaluAck`,
      `entri_jam_repository_test.dart`). Gagal menulis berarti **tidak** meng-ack: entrinya tetap di
      buffer jam dan dikirim lagi.
- [x] Duplikat sampel tidak menghasilkan entri ganda (dedup `(sesiId, index)` di controller, ikut
      dipulihkan setelah restart — `pemulihan_sesi_test.dart`).
- [x] Putus koneksi di tengah sesi tidak membatalkan sesi, dan layar sesi berjalan mengatakannya.
- [x] Tombol "Selesai Makan" di aplikasi mengirim `MULAI_SESI` dan **tidak** menetapkan `t0` sendiri:
      jam yang menerima perintahnya lalu diam meninggalkan sesi tetap `draft`
      (`SesiMakanController.mulaiSesiDariApp`, `sesi_pages_test.dart`, `sesi_makan_controller_test.dart`).
- [x] `tulisMulaiSesi` tidak memuat satu byte waktu pun (`protokol_jam_test.dart`).

**Integrasi**

- [ ] Satu sesi penuh (baseline → t0 → +1 jam → +2 jam) dengan hardware nyata.
- [ ] Bluetooth HP dimatikan **sebelum** foto diambil dan baru dinyalakan setelah +2 jam → seluruh
      sesi diterjemahkan dengan benar dari satu anchor di akhir. Ini uji inti dari §4.2.
- [ ] Jam di-reboot di tengah sesi → sesi berakhir `tidakLengkap`, sampel sebelum reboot tetap masuk
      dengan waktu yang benar.
- [ ] Jam kehabisan daya, boot, dipakai satu sesi penuh, mati lagi, baru tersambung → sesi itu
      ditandai `waktu_tidak_pasti` dan diperlakukan sesuai §4.3.
- [ ] Aplikasi di-kill paksa di tengah sesi → sesi dipulihkan dari DB dengan `t0` yang sama.
- [ ] Sesi dimulai dari tombol di aplikasi → `t0` di layar sama persis dengan `uptime_s` jam saat
      perintah diterima, dan `+1 jam`/`+2 jam` datang tepat pada jadwalnya. Jam palsu tidak bisa
      membuktikan ini: ia tidak punya pencacah yang terpisah dari jam dinding HP.
- [ ] Tombol di aplikasi ditekan **dan** tombol fisik ditekan hampir bersamaan → satu `t0`, satu
      sesi. Ini uji idempotensi §5.1.
- [ ] Pindai kesehatan ditekan **di tengah sesi yang berjalan** → hasilnya keluar, dan ketiga titik
      ukur sesi tetap datang pada `t0+0`, `t0+1 jam`, dan `t0+2 jam` seperti semula. Ini uji inti
      dari aturan v1.2 di §9; jam palsu tidak bisa membuktikannya karena ia tidak punya satu sensor
      yang harus dibagi.
- [ ] Jam menyimpan beberapa entri selagi HP jauh, lalu HP mendekat → angka "tertunda" di layar
      **turun sampai nol** seiring sampelnya masuk, tanpa menunggu paket Status. `FakeBleService`
      mengosongkannya seketika saat perintah `SINKRON` dikirim, jadi jalur ini tidak terbukti oleh
      test mana pun — hanya hardware yang bisa membuktikannya.

---

## 12. Riwayat versi

`versi_minor` dinaikkan setiap kali perilaku kawat berubah **setelah** implementasi salah satu sisi
dimulai — aturannya ada di [rencana-produksi.md](rencana-produksi.md) §4.2. Firmware melaporkan versi
yang diimplementasikannya di byte 0–1 handshake (§3).

Bagian ini adalah satu-satunya tempat yang memberi arti pada angka itu. Tanpanya, `versi_minor` cuma
bilangan yang naik.

### v1.2

Dua perubahan, keduanya lahir dari pengamatan yang sama: aplikasi selama ini hanya bisa **menunggu**
jam, tanpa satu pun cara memintanya melakukan sesuatu yang pengguna sedang inginkan sekarang.

| Perubahan | Bagian |
|---|---|
| **`MULAI_SESI` (`0x09`) baru**: tombol "Selesai Makan" jam ditekan dari aplikasi. Payload `sesiId` saja, **tanpa waktu** — jam yang mencatat `t0` dari pencacahnya sendiri lalu mengirim `TOMBOL_SELESAI_MAKAN` seperti biasa, jadi §4 tidak tersentuh. Hanya dilayani di ARMED, dan idempoten terhadap sesi yang sudah RUNNING. | §5.1, §9 |
| **`UKUR_SEKARANG` (`0x05`) dilayani di ketiga status**, bukan hanya IDLE, dan tidak boleh menggeser jadwal titik ukur sesi. Pemakainya bertambah satu: pindai kesehatan atas permintaan pengguna, di samping alur kalibrasi. Jam yang sensornya sedang sibuk menjawab `NAK` `0x05`, bukan pembacaan lama. | §5.1, §9 |
| **§9.1 baru — perebutan sensor.** Dengan dua pemicu pengukuran yang bisa bertabrakan, urutan menangnya ditulis: titik ukur sesi selalu menang dan **ditunda, tidak pernah dibatalkan**; `MULAI_SESI` tidak pernah ditolak karena sensor sibuk (ia stempel waktu, bukan pengukuran); hanya `UKUR_SEKARANG` yang boleh dijawab `NAK` `0x05`. | §9.1 |

Satu opcode baru, satu pelonggaran status. Tidak ada paket lama yang berubah bentuk, jadi setiap
byte yang sudah pernah ditulis atau dibaca tetap berarti persis sama.

Firmware v1.2 tidak melakukan apa pun yang membingungkan aplikasi v1.1: aplikasi lama tidak pernah
mengirim `0x09` dan tidak pernah mengirim `0x05` di luar IDLE. Aplikasi v1.2 dengan firmware v1.1
kehilangan dua kenyamanan, dan **keduanya punya jalan keluar yang sudah ada di layar**: `MULAI_SESI`
dijawab `NAK` `0x01` (opcode tidak dikenal) sehingga tombol di aplikasi melapor gagal — dan
kalimatnya memang menunjuk ke tombol jam, yang tetap bekerja seperti biasa; pindai selagi sesi
berjalan dijawab `NAK` yang kalimatnya muncul apa adanya.

Yang **tidak** berubah, dan sengaja disebut di sini supaya tidak ada yang mengira sebaliknya: `t0`
tetap hanya berasal dari jam (§1 aturan 3), penjadwalan `+1 jam`/`+2 jam` tetap sepenuhnya di jam
(§9), dan seluruh siklus sesi tetap harus selesai walau HP tidak pernah tersambung sekali pun.

Baris §10 tentang "pengukuran terjadwal di luar sesi" **tidak** dicabut. Yang tetap dilarang adalah
jam yang mengukur atas kemauannya sendiri; yang dibuka di sini adalah pengukuran yang dimulai jari
manusia.

### v1.1

Tiga perubahan, semuanya lahir dari implementasi pertama di kedua sisi — dan ketiganya adalah
**penajaman hal yang sebelumnya ambigu**, bukan penambahan fitur. Kompatibel mundur dari sudut
pandang aplikasi: tidak ada satu pun yang membuatnya salah membaca firmware v1.0.

| Perubahan | Bagian |
|---|---|
| `ACK_EVENT` (`0x08`) tidak pernah dibalas. Meng-ack sebuah ack adalah regresi tak berujung, dan menunggunya menambah satu perjalanan pulang-pergi untuk setiap entri. | §5.1 |
| `ACK`/`NAK` tidak masuk ring buffer, ber-`seq` 0, tidak pernah dikirim ulang. Sebelumnya §6 terbaca seolah keduanya ikut menunggu di-`ACK_EVENT` — dan aplikasi tidak pernah meng-ack balasan, sehingga buffer akan terisi penuh oleh ACK basi lalu membuang sampel sungguhan. | §6 |
| `UKUR_SEKARANG` (`0x05`) dijawab paket Sampel ber-`sesiId` 16 byte nol, `index` 0. Sebelumnya bentuk balasannya tidak didefinisikan sama sekali. | §5.1 |

Aplikasi **tidak** membaca `seq` pada paket ACK/NAK — keduanya dialihkan ke jalur balasan internal
sebelum menyentuh jalur simpan-lalu-ack. Karena itu firmware v1.0 yang mengirim ACK ber-`seq` 1..255
tetap bekerja dengan aplikasi v1.1; yang rusak hanya buffer-nya sendiri, dan hanya setelah puluhan
perintah.

Perubahan pairing (passkey tetap → Just Works, §8) **tidak** menaikkan `versi_minor`: ia tidak
mengubah satu byte pun di kawat, dan ketidakcocokannya — bila ada — ditangani stack Bluetooth OS,
bukan protokol ini.

### v1.0

Rancangan awal. Belum pernah ada firmware v1.0 di tangan siapa pun.
