# Firmware Jam AsaWatch — ESP32

Berkas pengarahan untuk mengerjakan **firmware**-nya, bukan aplikasinya.

## Cara memakai berkas ini

Firmware hidup di repo sendiri. Salin dua berkas ke sana:

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
- **NVS** untuk `boot_id` dan offset kalibrasi.
- **Partisi flash mentah** untuk ring buffer — lihat catatannya di bawah.

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

**Selesai bila:** nRF Connect melihat `AsaWatch xxxx`, memfilternya dengan service UUID berhasil, dan
membaca karakteristik Info memberi 20 byte yang benar.

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

**Selesai bila:** entri bertahan melewati reset, `SINKRON` mengirim ulang dari seq yang diminta,
buffer penuh mengirim `BUFFER_PENUH` (bukan diam-diam menimpa), dan entri kirim-ulang menyalakan flag
`dariBuffer`.

### F4 — Mesin status sesi

IDLE → ARMED → RUNNING, persis §9.

Dua hal yang wajib dipegang:

1. **Jadwal dihitung dari `uptime_s` absolut milik `t0`**, tidak pernah dari "sisa waktu". Sisa waktu
   yang diakumulasikan akan hanyut setiap kali ada penundaan.
2. **Reboot saat RUNNING mengakhiri sesi.** `uptime_s` kembali nol dan `t0` lama tidak bisa
   dibandingkan lagi. Kembali ke IDLE; sampel yang terlanjur ada tetap di buffer dengan `boot_id`
   lamanya. **Jangan mencoba melanjutkan sesi lintas boot** — tanpa RTC itu tidak mungkin, dan yang
   dihasilkan hanya data yang tampak sah tetapi salah.

Seluruh siklus harus selesai walau HP tidak pernah tersambung sekali pun. Jam tidak menunggu
konfirmasi aplikasi untuk berpindah status.

**Selesai bila:** tombol "Selesai Makan" mati di IDLE dan hidup di ARMED, ARM timeout 4 jam
menghasilkan `SESI_KEDALUWARSA`, dan satu sesi penuh selesai dengan BLE dimatikan sepanjang waktu.

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

**Ketahanan tulis flash.** Entri buffer ditulis dan dihapus terus-menerus. NVS key-value bisa dipakai
tetapi ring di partisi mentah lebih mudah dikendalikan siklus tulisnya. Empat sampel per sesi bukan
angka besar — yang perlu diperhatikan adalah godaan menulis setiap perubahan status.

**Menulis flash sambil BLE aktif** bisa memblokir cukup lama untuk mengganggu jadwal koneksi.
Tulisannya kecil, tetapi ukur, jangan asumsikan.

**Antrean notifikasi bisa penuh** saat mengosongkan buffer 64 entri sekaligus setelah lama tidak
tersambung. Kirim berurutan dengan jeda, jangan menembakkan semuanya dalam satu loop.

**MTU** diminta 185 oleh aplikasi, minimum yang bisa dipakai 35 — sampel butuh 31 byte utuh dalam
satu notifikasi. Jangan memotong sampel menjadi dua paket.

**Bonding wajib, LE Secure Connections, enkripsi di semua karakteristik kustom** (§8). Ini data
kesehatan. Di NimBLE: `NimBLEDevice::setSecurityAuth(true, true, true)` dan izin `READ_ENC`/
`WRITE_ENC` di kelima karakteristik.

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
