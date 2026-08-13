# Protokol Jam Tangan AsaWatch — BLE GATT

Kontrak antara firmware jam tangan dan aplikasi Flutter. Dokumen ini **normatif**: bila kode dan
dokumen ini berbeda, salah satunya bug.

Status: **v1.1 — terimplementasi di sisi aplikasi (Tahap B), firmware menyusul.**
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
3. **Jam tetap satu-satunya sumber `t0`.** Aplikasi tidak punya tombol yang setara, dan tidak boleh
   menghitung `t0` dari waktu pesan tiba — pesannya bisa datang berjam-jam terlambat lewat buffer.
   Yang datang dari jam adalah `t0` dalam satuan `uptime_s`; wall clock-nya diturunkan, bukan
   ditebak.
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

Interval iklan: 100 ms selama 60 detik pertama setelah tombol pairing ditekan, lalu 1000 ms.

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
sebagai "—" seolah pengukurannya gagal.

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

Catatan per opcode:

- **`ANCHOR_WAKTU` dikirim pada setiap koneksi, sebelum perintah lain.** Ia murah dan idempoten;
  mengirimnya terlalu sering tidak merugikan, melewatkannya sekali bisa membuat satu sesi penuh
  kehilangan waktunya.
- **`ARM_SESI`** adalah satu-satunya hal yang menyalakan tombol "Selesai Makan" di jam. Selama jam
  belum di-ARM, menekan tombolnya tidak menghasilkan apa-apa (opsional: getaran pendek + pesan di
  layar jam). Inilah mekanisme yang menjamin **tidak ada sesi tanpa foto makanan**.
- **`ARM_SESI` menimpa sesi ARMED sebelumnya** yang belum ditekan. Hanya satu sesi ARMED pada satu
  waktu — cerminan aturan satu-sesi-aktif di `SesiMakanController`.
- **Timeout ARM: 4 jam `uptime_s`.** Lewat dari itu jam mengirim `SESI_KEDALUWARSA` dan kembali IDLE.
  Tanpa ini, foto sarapan yang tombolnya tidak pernah ditekan akan menyalakan tombol sampai malam.
- **`SET_KALIBRASI` mengirim offset, bukan nilai referensi.** `Kalibrasi.offsetSistolik` /
  `offsetDiastolik` sudah dihitung di Dart; jam hanya menambahkannya ke pembacaan mentah. Nilai
  referensi tensimeter tidak perlu diketahui firmware. Offset disimpan di flash agar bertahan
  melewati boot.
- **`UKUR` dipakai untuk baseline (index 0)** saat shutter kamera ditekan — sebelum `t0` ada. Karena
  itu ia membawa `sesiId` yang sama dengan `ARM_SESI`.
  **`ARM_SESI` harus mendahuluinya**, bukan menyusul: jam hanya melayani `UKUR` dalam status ARMED
  (§9), dan permintaan baseline yang tiba selagi jam masih IDLE ditolak. Kegagalan itu tidak
  bergema — ketiga titik lain tetap masuk dengan benar, dan sesinya baru terlihat salah dua jam
  kemudian, saat ia menggantung menunggu baseline yang tidak akan pernah datang.
- **`UKUR_SEKARANG` dijawab dengan paket Sampel biasa** (§5.2), dengan `sesiId` **16 byte nol** dan
  `index` 0. Ia memang terjadi di luar sesi mana pun — alur kalibrasi tekanan darah, bukan sesi
  makan. Aplikasi memperlakukan `sesiId` nol sebagai "bukan sesi": sampelnya diteruskan ke pemanggil
  `ukurSekarang()`, tetapi tidak pernah menunggu ada sesi yang memilikinya.
  ACK untuk opcode ini tetap dikirim seperti biasa, mendahului paket Sampel-nya.

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

Mengisi `StatusPerangkat.sampelTertunda`, yang sudah ditampilkan apa adanya di
[../lib/sesi_berjalan_page.dart](../lib/sesi_berjalan_page.dart).

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
     └──────┘                    └───────┘                   └─────────┘
        ▲                            │  timeout 4 jam            │
        │                            │  / BATAL_SESI             │ sampel index 3
        └────────────────────────────┴───────────────────────────┘  terkirim

     ANCHOR_WAKTU boleh masuk di status mana pun — ia tidak menyentuh mesin ini.
```

- Di **IDLE**: tombol "Selesai Makan" tidak berfungsi. `UKUR_SEKARANG` (kalibrasi) tetap boleh.
- Di **ARMED**: tombol aktif. `UKUR` index 0 (baseline) dilayani.
- Di **RUNNING**: jam menjadwalkan sendiri index 2 pada `t0.uptime_s + 3600` dan index 3 pada
  `+ 7200`. Index 1 diukur segera saat tombol ditekan.
- Sesi selesai → IDLE. Sampel yang belum terkirim tetap di buffer.

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
| Pengukuran terjadwal di luar sesi | Keputusan produk yang sudah dikunci: jam **hanya** mengukur saat sesi makan. |
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
- [x] Sentinel `0` dikonversi ke `null` sebelum meninggalkan layer BLE (`bacaSampel`).
- [x] `detikRelatifT0` dihitung dari selisih `uptime_s`, termasuk baseline yang negatif.
- [x] Ack dikirim **setelah** menulis ke DB (`BleAsliService._simpanLaluAck`,
      `entri_jam_repository_test.dart`). Gagal menulis berarti **tidak** meng-ack: entrinya tetap di
      buffer jam dan dikirim lagi.
- [x] Duplikat sampel tidak menghasilkan entri ganda (dedup `(sesiId, index)` di controller, ikut
      dipulihkan setelah restart — `pemulihan_sesi_test.dart`).
- [x] Putus koneksi di tengah sesi tidak membatalkan sesi, dan layar sesi berjalan mengatakannya.

**Integrasi**

- [ ] Satu sesi penuh (baseline → t0 → +1 jam → +2 jam) dengan hardware nyata.
- [ ] Bluetooth HP dimatikan **sebelum** foto diambil dan baru dinyalakan setelah +2 jam → seluruh
      sesi diterjemahkan dengan benar dari satu anchor di akhir. Ini uji inti dari §4.2.
- [ ] Jam di-reboot di tengah sesi → sesi berakhir `tidakLengkap`, sampel sebelum reboot tetap masuk
      dengan waktu yang benar.
- [ ] Jam kehabisan daya, boot, dipakai satu sesi penuh, mati lagi, baru tersambung → sesi itu
      ditandai `waktu_tidak_pasti` dan diperlakukan sesuai §4.3.
- [ ] Aplikasi di-kill paksa di tengah sesi → sesi dipulihkan dari DB dengan `t0` yang sama.

---

## 12. Riwayat versi

`versi_minor` dinaikkan setiap kali perilaku kawat berubah **setelah** implementasi salah satu sisi
dimulai — aturannya ada di [rencana-produksi.md](rencana-produksi.md) §4.2. Firmware melaporkan versi
yang diimplementasikannya di byte 0–1 handshake (§3).

Bagian ini adalah satu-satunya tempat yang memberi arti pada angka itu. Tanpanya, `versi_minor` cuma
bilangan yang naik.

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
