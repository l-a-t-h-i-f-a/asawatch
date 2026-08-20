# Rancangan API Laravel — AsaWatch

Dokumen ini untuk developer yang akan mengerjakan backend-nya. Tidak perlu bisa Flutter untuk
membacanya — bagian 1 menjelaskan aplikasinya secukupnya.

Yang dibangun: REST API untuk aplikasi mobile AsaWatch, mencakup akun pengguna, penyimpanan
data di server, dan analisis nutrisi dari foto makanan.

---

## 1. Konteks aplikasi

AsaWatch adalah aplikasi kesehatan yang berpasangan dengan sebuah **jam tangan pintar** lewat
Bluetooth. Intinya satu konsep: **sesi makan**.

Satu sesi makan berjalan seperti ini:

1. Pengguna memotret makanannya di aplikasi. Saat itu juga jam mengukur gula darah
   **sebelum** makan (baseline).
2. Selesai makan, pengguna menekan tombol di jam. Momen itu disebut **t0**.
3. Jam mengukur lagi pada t0, lalu **+1 jam**, lalu **+2 jam**.
4. Jadi setiap sesi punya tepat **4 titik pengukuran**, dengan urutan yang selalu sama:

   | index | titik | kira-kira kapan |
   | --- | --- | --- |
   | 0 | Baseline | sebelum makan (nilai `detik_relatif_t0` negatif) |
   | 1 | Selesai makan | t0 |
   | 2 | +1 jam | t0 + 3600 detik |
   | 3 | +2 jam | t0 + 7200 detik |

   Tiap titik berisi gula darah, detak jantung, tekanan darah (sistolik/diastolik), dan SpO2.

5. Aplikasi lalu menampilkan kurva dan kesimpulan: seberapa tinggi lonjakan gula darahnya,
   berapa lama kembali normal.

Yang perlu diketahui backend:

- **Aplikasi sudah punya database sendiri (SQLite) dan sudah jalan penuh tanpa server.**
  Backend ini menambah: akun, cadangan data, sinkronisasi antar perangkat, dan analisis foto.
  Bukan menggantikan database lokalnya.
- **Jam tangan tidak punya jam dinding (RTC).** Semua urusan konversi waktu diselesaikan di
  aplikasi sebelum data dikirim ke server. Backend tidak pernah menyentuh masalah ini, kecuali
  satu flag yang dijelaskan di bagian 5.2 (`waktu_tidak_pasti`).
- Semua teks yang dilihat pengguna berbahasa Indonesia, dan penamaan di proyek ini juga
  Indonesia (`sesi`, `sampel`, `kalibrasi`, `riwayat`). API mengikuti kebiasaan itu — lihat
  bagian 3.

Dokumen ini dibuat mandiri — semua yang dibutuhkan untuk mengerjakan backend-nya ada di sini.
Kalau masih ada yang kurang jelas, tim aplikasi punya dokumen internal soal alur layar dan soal
protokol komunikasi dengan jam; tanyakan saja, jangan menebak.

---

## 2. Enam aturan utama

Kalau cuma sempat mengingat satu bagian, ingat yang ini.

1. **Server tidak menghitung nilai turunan.**
   Angka seperti "lonjakan puncak", "waktu pemulihan", "kualitas respons", "sarapan/makan
   siang" **tidak** disimpan dan **tidak** dikirim. Aplikasi menghitungnya sendiri dari 4
   sampel tadi.
   *Kenapa:* rumusnya sudah ada di aplikasi. Kalau ditulis ulang di PHP, cepat atau lambat
   dua sisi memberi angka berbeda untuk data yang sama, dan bug seperti itu sulit dilacak.
   Server menyimpan fakta hasil pengukuran; aplikasi yang menyimpulkan.

2. **ID dibuat aplikasi, bukan server.**
   Setiap sesi sudah punya UUID v4 dari aplikasi. Pakai UUID itu apa adanya sebagai primary
   key. Tidak ada `auto_increment`, tidak ada tabel pemetaan id-lokal ↔ id-server.
   *Kenapa:* aplikasi harus bisa membuat sesi saat offline. Efek sampingnya bagus: mengirim
   sesi yang sama dua kali otomatis aman.
   Konsekuensinya: **tidak ada `POST /sesi`**, yang ada `PUT /sesi/{id}` (upsert).

3. **Aplikasi harus tetap jalan penuh walau server mati.**
   Jangan bikin endpoint yang wajib sukses sebelum pengguna boleh melanjutkan. Semua operasi
   tulis dirancang bisa diulang (idempoten), karena aplikasi akan mengantre dan mengirim ulang.

4. **Sampel yang sudah terisi tidak boleh diubah.**
   Satu `(sesi_id, index)` yang statusnya `terisi` bersifat final. Itu hasil pengukuran alat,
   bukan sesuatu yang diedit.

5. **Foto makanan tidak boleh punya URL publik.**
   Simpan di storage privat, sajikan lewat pre-signed URL berumur pendek. Ini data kesehatan —
   lihat bagian 9 soal keamanan.

6. **Nama anggota enum adalah bagian dari kontrak.**
   `status` sesi dikirim sebagai string (`draft`, `berjalan`, `selesai`, …). Mengganti namanya
   = perubahan yang memutus aplikasi, jadi butuh koordinasi, bukan refactor sepihak.

---

## 3. Fondasi teknis

| Hal | Pilihan | Catatan |
| --- | --- | --- |
| Framework | Laravel 12, PHP 8.3+ | |
| Auth | **Sanctum**, personal access token | Kliennya aplikasi mobile, bukan SPA. Passport/OAuth2 berlebihan untuk sekarang. |
| Database | PostgreSQL 16 (MySQL 8 juga cukup) | Perlu tipe UUID dan soft delete. |
| Antrean | Redis + `queue:work` | Analisis foto wajib jalan di background (bagian 6). |
| Storage foto | S3-compatible, bucket privat | Lihat bagian 9 soal lokasi server. |
| Format | JSON. Unggah foto pakai `multipart/form-data` | |
| Versi API | Prefiks path `/api/v1` | Kalau ada perubahan yang memutus, naikkan jadi `/v2`. Jangan versioning lewat header. |
| Format waktu | ISO-8601 UTC: `2026-08-12T04:30:00.000000Z` | Selalu UTC. Aplikasi yang mengurus zona waktu tampilan. |
| Penamaan field | `snake_case` Bahasa Indonesia | `gula_darah`, `detik_relatif_t0`, `waktu_tidak_pasti`. Ikut istilah yang sudah dipakai aplikasi supaya tidak ada dua kamus. |

### 3.1 Bentuk respons

Sukses — pakai API Resource biasa:

```json
{ "data": { }, "meta": { } }
```

Galat — **selalu** bentuk ini, termasuk error validasi 422 (normalkan di exception handler):

```json
{
  "galat": {
    "kode": "validasi_gagal",
    "pesan": "Foto wajib diunggah.",
    "detail": { "foto": ["Foto wajib diunggah."] }
  }
}
```

- `kode` — string tetap, dipakai aplikasi untuk mencabang logika.
- `pesan` — Bahasa Indonesia, langsung ditampilkan ke pengguna. Tulis yang bisa dibaca orang
  awam.
- `detail` — opsional, per-field.

Daftar `kode` yang dipakai: `validasi_gagal`, `tidak_terautentikasi`, `token_kedaluwarsa`,
`tidak_diizinkan`, `tidak_ditemukan`, `konflik_versi`, `terlalu_sering`,
`layanan_nutrisi_gagal`, `galat_server`. Menambah kode baru boleh; mengganti arti kode lama
tidak.

---

## 4. Autentikasi

| Method | Path | Keterangan |
| --- | --- | --- |
| POST | `/api/v1/auth/daftar` | `nama`, `email`, `kata_sandi`, `nama_perangkat`. Kirim email verifikasi. |
| POST | `/api/v1/auth/masuk` | Balas `token` + `profil`. Rate limit 5/menit per email + IP. |
| POST | `/api/v1/auth/keluar` | Cabut token yang sedang dipakai saja. |
| POST | `/api/v1/auth/keluar-semua` | Cabut semua token milik user. |
| POST | `/api/v1/auth/lupa-sandi` | Kirim tautan reset. Balas **selalu 202**, ada atau tidak email-nya. |
| POST | `/api/v1/auth/atur-ulang-sandi` | `token`, `email`, `kata_sandi`. Cabut semua token lama. |
| POST | `/api/v1/auth/kirim-ulang-verifikasi` | |
| GET | `/api/v1/auth/saya` | Data user + profil. |
| DELETE | `/api/v1/auth/akun` | Butuh `kata_sandi`. Jalankan `HapusAkunJob`. |

Beberapa hal yang gampang keliru:

- **`lupa-sandi` selalu 202.** Membalas 404 untuk email yang tidak terdaftar sama saja
  memberitahu penebak siapa saja yang punya akun.
- **`DELETE /auth/akun` itu wajib**, bukan opsional — Play Store dan App Store mensyaratkan
  penghapusan akun bisa dilakukan dari dalam aplikasi. Alurnya: cabut akses seketika (soft
  delete), hapus permanen setelah 7 hari, hapus juga file foto di storage, kirim email
  konfirmasi.
- **Token tanpa refresh token.** Set masa berlaku 30 hari di `config/sanctum.php`. Dengan satu
  klien mobile, token panjang + endpoint `keluar-semua` lebih sederhana dan lebih mudah
  dipastikan benar daripada rotasi token. Aplikasi menyimpannya di penyimpanan terenkripsi
  perangkat dan menangani 401 secara terpusat.

---

## 5. Endpoint sumber daya

### 5.1 Profil

| Method | Path |
| --- | --- |
| GET | `/api/v1/profil` |
| PUT | `/api/v1/profil` |

```json
{
  "data": {
    "nama": "Rara",
    "tanggal_lahir": "1998-04-17",
    "jenis_kelamin": "perempuan",
    "golongan_darah": "O",
    "tinggi_cm": 162,
    "berat_kg": 54.5,
    "diperbarui_pada": "2026-08-12T04:30:00.000000Z"
  }
}
```

**Semua field boleh null.** Di aplikasi, profil kosong itu sah — pengguna baru belum mengisi
apa-apa dan tetap bisa memakai aplikasinya. Jadi jangan bikin field wajib di sini.

Yang divalidasi hanya bentuknya: `tanggal_lahir` format ISO dan di masa lalu, `tinggi_cm`
50–250, `berat_kg` 2–400, `jenis_kelamin` ∈ {`laki-laki`, `perempuan`}, `golongan_darah` ∈
{A, B, AB, O}.

### 5.2 Sesi makan

Bentuk JSON-nya sama untuk baca dan tulis:

```json
{
  "id": "9f1c2b7e-4c1a-4b0e-9a6f-2d3e4f5a6b7c",
  "waktu_foto": "2026-08-12T04:12:31.000000Z",
  "t0": "2026-08-12T04:22:10.000000Z",
  "status": "selesai",
  "waktu_tidak_pasti": false,
  "sesi_uji": false,
  "foto": {
    "url": "https://cdn.asawatch.id/foto/9f1c...jpg?exp=...&sig=...",
    "kadaluarsa_pada": "2026-08-12T05:30:00.000000Z"
  },
  "sampel": [
    {
      "index": 0,
      "detik_relatif_t0": -580,
      "status": "terisi",
      "dari_buffer": false,
      "gula_darah": 96,
      "detak_jantung": 74,
      "sistolik": 118,
      "diastolik": 76,
      "spo2": 98
    }
  ],
  "hasil": {
    "indeks_glikemik_perkiraan": "sedang",
    "keyakinan": 0.82,
    "dikoreksi_user": true,
    "total": { "kalori": 640.0, "karbohidrat": 88.0, "protein": 24.0,
               "lemak": 18.0, "gula_total": 12.0, "serat": 5.0 },
    "makanan": [
      { "urutan": 0, "nama": "Nasi putih", "porsi": "1 piring",
        "estimasi_gram": 200.0,
        "nutrisi": { "kalori": 260.0, "karbohidrat": 57.0, "protein": 5.0,
                     "lemak": 0.5, "gula_total": 0.1, "serat": 0.6 } }
    ]
  },
  "diperbarui_pada": "2026-08-12T06:30:00.000000Z",
  "dihapus_pada": null
}
```

Penjelasan field yang butuh penjelasan:

| Field | Aturan |
| --- | --- |
| `status` | `draft`, `menunggu_perangkat`, `berjalan`, `selesai`, `tidak_lengkap`, `dibatalkan`. |
| `t0` | `null` selama status `draft` / `menunggu_perangkat` — momen ini baru ada setelah pengguna menekan tombol di jam. |
| `sampel` | **Selalu 4 elemen, index 0..3**, walaupun sebagian masih `menunggu` atau `terlewat`. Jangan buang yang kosong; aplikasi mengaksesnya per index. |
| `sampel[].status` | `menunggu` (jadwalnya belum tiba), `terisi`, `terlewat`. |
| `sampel[].detik_relatif_t0` | Detik terhadap t0. Negatif untuk baseline. |
| `sampel[].dari_buffer` | `true` kalau data ini sempat tertahan di memori jam sebelum terkirim. Sekadar informasi. |
| Metrik (`gula_darah`, dst.) | `null` kalau gagal diukur. **Jangan pakai 0** sebagai penanda gagal. |
| `hasil` | `null` berarti analisis nutrisinya belum selesai — itu kondisi normal, bukan error. |
| `hasil.total` | **Simpan apa adanya, jangan dijumlahkan ulang dari `makanan`.** Sebelum dikoreksi pengguna, total dari layanan analisis memang tidak selalu persis sama dengan jumlah per-itemnya, dan menghitung ulang akan diam-diam mengubah angka yang sudah pernah dilihat pengguna. |
| `hasil.dikoreksi_user` | `true` kalau pengguna sudah mengoreksi porsinya sendiri. Koreksi pengguna tidak boleh ditimpa oleh hasil analisis, lihat bagian 6. |
| `sesi_uji` | Opsional saat menulis (bawaannya `false`), **selalu** dikembalikan saat membaca. Artinya sesi ini direkam dengan jadwal pengujian yang dimampatkan — empat titik dalam dua menit, bukan dua jam — atau dengan jam tangan palsu. **Penanda pasif: server menyimpan, mengembalikan, dan mengekspornya, tetapi tidak ada satu pun perilaku server yang bercabang atasnya.** Sejak 20 Agustus 2026 sesi uji **ikut dihitung** dalam dashboard, analitik, dan ekspor seperti sesi biasa (keputusan produk: panel harus menampilkan data uji selama pengembangan). Penyaringan diserahkan ke pembaca datanya — kolom `sesi_uji` ada di CSV (1/0) dan di JSON ekspor. Konsekuensi yang perlu diingat sebelum rilis: begitu ada pengguna sungguhan, rakitan uji apa pun yang mengunggah sesi akan menggeser angka agregat **tanpa gejala** — kalau pengecualian itu dihidupkan kembali, tempatnya di sisi server, bukan dengan menyaring di aplikasi. Aplikasi sengaja tetap mengunggah sesi uji: jalur unggah yang hanya bisa dilatih oleh sesi sungguhan menuntut 2,5 jam per percobaan, dan jalur seperti itu tidak pernah teruji sampai ia dipakai sungguhan. |
| `waktu_tidak_pasti` | Jarang, tapi penting. Artinya: sesi ini datanya benar, tapi jam berapa persisnya terjadi tidak diketahui dan tidak akan pernah bisa diketahui. **Server tidak pernah mengubah `true` jadi `false`.** Simpan apa adanya. |
| `foto.url` | Pre-signed URL, dibuat baru setiap kali dibaca. Jangan simpan URL permanen. |

Endpoint-nya:

| Method | Path | Keterangan |
| --- | --- | --- |
| GET | `/api/v1/sesi` | Daftar, pagination cursor. Filter opsional: `sejak`, `status`, `limit`. |
| GET | `/api/v1/sesi/{id}` | |
| PUT | `/api/v1/sesi/{id}` | Upsert. Ini sekaligus endpoint "buat". |
| DELETE | `/api/v1/sesi/{id}` | Soft delete (isi `dihapus_pada`), supaya penghapusan ikut tersinkron ke perangkat lain. |
| POST | `/api/v1/sesi/{id}/foto` | `multipart`, field `foto`. Dipisah dari PUT supaya gagal-unggah bisa diulang tanpa mengirim ulang seluruh sesi. |

### 5.3 Kalibrasi tekanan darah

Pengguna mengukur tekanan darah dengan tensimeter biasa, jam mengukur bersamaan, selisihnya
jadi koreksi untuk pembacaan jam.

| Method | Path |
| --- | --- |
| GET | `/api/v1/kalibrasi` |
| POST | `/api/v1/kalibrasi` |

Body: `waktu`, `sistolik_referensi`, `diastolik_referensi`, `sistolik_jam`, `diastolik_jam`.
Nilai offset-nya tidak dikirim — itu hasil pengurangan, dan aplikasi yang
menghitungnya sendiri (aturan pertama di bagian 2).

Simpan sebagai **riwayat**, jangan satu baris yang ditimpa terus. Offset yang tiba-tiba
melonjak antar kalibrasi adalah tanda salah satu pengukurannya keliru, dan itu cuma kelihatan
kalau yang lama masih ada.

### 5.4 Perangkat terpasang

| Method | Path | Body |
| --- | --- | --- |
| GET | `/api/v1/perangkat` | |
| PUT | `/api/v1/perangkat/{id_ble}` | `nama`, `terakhir_tersambung`, `firmware`, `baterai_terakhir` |
| DELETE | `/api/v1/perangkat/{id_ble}` | |

Gunanya untuk dukungan pengguna ("jam-nya firmware versi berapa?"). Ini **bukan** prasyarat
pairing — pairing sepenuhnya lewat Bluetooth dan tetap jalan tanpa internet.

### 5.5 Target harian

`GET` / `PUT /api/v1/target-harian` — target kalori, karbohidrat, langkah, dsb. Fiturnya di
aplikasi belum jadi, jadi endpoint ini boleh dikerjakan paling akhir. Disebut di sini supaya
tidak dilupakan.

---

## 6. Analisis nutrisi dari foto

Ini alasan paling kuat backend ini ada: **kunci API layanan analisis foto tidak boleh
ditempel di aplikasi.** APK yang sudah dirilis bisa dibongkar siapa saja dan kuncinya diambil.
Jadi aplikasi kirim foto ke sini, backend yang memanggil layanan vision-nya.

Alurnya asinkron, karena analisis gambar makan waktu beberapa detik dan pengguna tidak
menunggu di layar loading:

```
POST /api/v1/sesi/{id}/analisis
  → 202 { "status": "antre", "id_pekerjaan": "..." }

GET  /api/v1/sesi/{id}/analisis
  → 200 { "status": "antre" | "selesai" | "gagal", "kode": null, "hasil": { } | null }
```

Aplikasi menyimpan `id_pekerjaan` lalu polling dengan backoff (2s → 4s → 8s, berhenti di 60s).

Yang perlu diperhatikan:

- **Bungkus panggilan vision di balik satu interface** (`LayananVisionNutrisi`) dengan satu
  implementasi konkret. Penyedianya belum final — bisa layanan pihak ketiga, model sendiri,
  atau database makanan + input manual. Ganti penyedia jangan sampai menyentuh controller.
- **Job-nya**: `tries: 3`, backoff eksponensial, timeout 30 detik per percobaan.
- **Cache berdasarkan hash isi foto** (`sha256`). Foto yang sama cukup dianalisis sekali. Ini
  langsung memotong biaya per foto, yang jadi salah satu pertimbangan besar di fitur ini.
- **Gagal itu status, bukan HTTP 500.** Balas 200 dengan `status: "gagal"` plus `kode`:
  `foto_tidak_dikenali`, `layanan_nutrisi_gagal`, atau `waktu_habis`. Aplikasi butuh itu untuk
  menampilkan tombol "Coba Lagi" yang tepat.
- **Sesi tanpa hasil nutrisi tetap sah.** Kalau analisisnya gagal permanen, sesinya tidak
  rusak — data gula darahnya tetap lengkap dan tetap ditampilkan. Jangan menggagalkan sesi
  gara-gara analisis foto gagal.
- **Koreksi pengguna menang.** Kalau sesi sudah punya `hasil.dikoreksi_user: true`, job yang
  baru selesai belakangan **tidak boleh** menimpanya.
- Rate limit 20 analisis/jam/user. Ini bukan untuk melindungi server, tapi tagihan.

---

## 7. Sinkronisasi

> Bagian ini baru dikerjakan kalau diputuskan data harus tersinkron antar perangkat. Kalau
> untuk v1 jawabannya "cukup satu perangkat", lewati bagian ini — tapi tetap sediakan
> kolom `updated_at` dan `deleted_at` di skema (bagian 8), karena menambahkannya belakangan
> berarti migrasi data pengguna.

Modelnya sederhana: delta dua arah dengan kursor waktu. Bukan CRDT — satu pengguna dengan satu
jam nyaris tidak pernah benar-benar bentrok.

```
GET  /api/v1/sinkron?sejak=2026-08-12T04:00:00.000000Z&limit=200
POST /api/v1/sinkron
```

`GET` mengembalikan semua yang berubah setelah `sejak`, termasuk yang dihapus:

```json
{
  "data": { "sesi": [], "kalibrasi": [], "profil": null },
  "meta": { "kursor_berikutnya": "2026-08-12T06:31:02.000000Z", "ada_lagi": false }
}
```

`POST` menerima batch dengan bentuk yang sama, membalas hasil per item:

```json
{
  "data": {
    "diterima": ["9f1c...", "a2b3..."],
    "ditolak": [{ "id": "c4d5...", "kode": "konflik_versi", "pesan": "..." }]
  }
}
```

### 7.1 Aturan konflik

Empat aturan, taruh semuanya di satu kelas (`PenggabungSesi`) — jangan disebar ke controller.

1. **Sampel yang sudah `terisi` tidak pernah ditimpa.** Kalau datang nilai berbeda untuk
   `(sesi_id, index)` yang sama, abaikan dan catat di log. Jangan balas error — aplikasi yang
   mengirim ulang batch lama tidak sedang melakukan kesalahan.
2. **Sisanya last-write-wins per sesi**, dibandingkan pakai `diperbarui_pada` dari klien. Yang
   lebih tua kalah dan dibalas `konflik_versi`, supaya aplikasi tahu harus menarik versi
   server.
3. **Penghapusan menang atas pembaruan.** Sesi yang `dihapus_pada`-nya sudah terisi tidak boleh
   hidup lagi karena `PUT` yang lebih tua. Sesi yang dibatalkan pengguna harus benar-benar
   hilang, tidak muncul lagi belakangan.
4. **`waktu_tidak_pasti` tidak pernah dicabut server.** Sekali `true`, selamanya `true`.

### 7.2 Kapan aplikasi menyinkronkan

Saat masuk, saat aplikasi kembali ke depan, dan setelah sebuah sesi berakhir. Bukan setiap
sampel masuk. Artinya untuk backend: request sinkron datang jarang tapi berisi beberapa sesi
sekaligus — optimalkan untuk itu, bukan untuk request kecil bertubi-tubi.

---

## 8. Skema database

Migrasi Laravel. Ini cerminan struktur database lokal aplikasi, ditambah `user_id` dan kolom
sinkronisasi.

```
users                 id, nama, email(unique), password, email_verified_at,
                      deleted_at, timestamps

profil                user_id(pk, fk), tanggal_lahir(date, null), jenis_kelamin(null),
                      golongan_darah(null), tinggi_cm(null), berat_kg(null), timestamps

sesi                  id(uuid, pk), user_id(fk, index), foto_disk_path(null),
                      foto_hash(null, index), waktu_foto(timestamptz),
                      t0(timestamptz, null), status(string),
                      waktu_tidak_pasti(bool, default false),
                      created_at, updated_at, deleted_at
                      INDEX (user_id, updated_at)     ← untuk kursor sinkron
                      INDEX (user_id, t0)             ← untuk daftar riwayat

sampel                sesi_id(fk cascade), index(smallint), detik_relatif_t0(int),
                      status(string), dari_buffer(bool),
                      gula_darah / detak_jantung / sistolik / diastolik / spo2 (int, null)
                      PRIMARY KEY (sesi_id, index)

hasil_deteksi         sesi_id(pk, fk cascade), indeks_glikemik_perkiraan(string),
                      keyakinan(float), dikoreksi_user(bool),
                      total_kalori / total_karbohidrat / total_protein /
                      total_lemak / total_gula_total / total_serat (float)

item_makanan          sesi_id(fk cascade), urutan(smallint), nama, porsi,
                      estimasi_gram(float),
                      kalori / karbohidrat / protein / lemak / gula_total / serat (float)
                      PRIMARY KEY (sesi_id, urutan)

kalibrasi             id(uuid, pk), user_id(fk), waktu(timestamptz),
                      sistolik_referensi, diastolik_referensi,
                      sistolik_jam, diastolik_jam, timestamps
                      UNIQUE (user_id, waktu)

perangkat             id(uuid, pk), user_id(fk), id_ble(string), nama,
                      firmware(null), baterai_terakhir(null),
                      terakhir_tersambung(null), timestamps
                      UNIQUE (user_id, id_ble)

pekerjaan_analisis    id(uuid, pk), sesi_id(fk), status, kode_galat(null),
                      percobaan(int), timestamps
```

Catatan:

- **Tidak ada kolom untuk nilai turunan** (aturan pertama di bagian 2). Kalau tergoda menambah kolom
  `lonjakan_puncak` atau `kualitas_respons`, jangan.
- **`urutan` di `item_makanan` wajib dipertahankan.** Judul kartu di aplikasi dirangkai dari
  nama makanan sesuai urutan ini; kalau berubah-ubah, pengguna melihatnya sebagai bug.
- `sampel`, `hasil_deteksi`, `item_makanan` sengaja tidak punya `user_id` — kepemilikannya
  lewat `sesi`.
- **Otorisasi lewat `SesiPolicy` + global scope**, supaya tidak ada satu pun query daftar yang
  bisa lupa memfilter per user. Ini data kesehatan; kebocoran antar-akun bukan bug biasa.

---

## 9. Keamanan dan kepatuhan

- **UU PDP.** Gula darah, tekanan darah, foto makanan, dan identitas termasuk data pribadi
  yang bersifat spesifik. Ini juga alasan memilih server sendiri ketimbang Firebase: lokasi
  penyimpanan bisa dipastikan di Indonesia.
- **TLS wajib**, HSTS aktif, tidak ada endpoint HTTP polos.
- **Foto tanpa URL publik.** Storage privat + pre-signed URL berumur maksimal 1 jam.
- **Enkripsi at-rest** untuk bucket foto.
- **Rate limit** per user dan per IP. `masuk` dan `lupa-sandi` lebih ketat dari yang lain.
- **Log tidak boleh memuat** nilai metrik, isi foto, atau token. `LOG_LEVEL` produksi
  `warning`.
- **Ekspor data** (`GET /api/v1/akun/ekspor` → job → tautan unduh) dan **hapus akun** adalah
  hak pengguna, bukan fitur tambahan.
- **CORS tolak semua** secara default. Tidak ada klien web.

---

## 10. Struktur kode dan pengujian

```
routes/api.php                    # semua rute v1, dikelompokkan per middleware
app/Http/Controllers/Api/V1/      # Auth, Profil, Sesi, Analisis, Kalibrasi,
                                  # Perangkat, Sinkron
app/Http/Requests/                # satu FormRequest per aksi tulis — validasi jangan
                                  # ditaruh di controller
app/Http/Resources/               # SesiResource, SampelResource, HasilDeteksiResource, ...
app/Models/
app/Policies/SesiPolicy.php
app/Jobs/AnalisisNutrisiJob.php
app/Services/Nutrisi/             # interface LayananVisionNutrisi + implementasinya
app/Services/Sinkron/PenggabungSesi.php   # satu-satunya tempat aturan konflik hidup
tests/Feature/
```

Middleware: `auth:sanctum` + `verified` untuk semua kecuali grup `auth`; `throttle:api`
global; throttle khusus untuk `masuk`, `lupa-sandi`, dan `analisis`.

**Pengujian** — yang paling penting diuji adalah yang paling gampang salah:

- `PUT /sesi/{id}` dua kali dengan body sama harus menghasilkan keadaan yang sama.
- Sampel `terisi` tidak bisa ditimpa.
- Sesi yang sudah dihapus tidak bisa hidup lagi lewat PUT lama.
- `waktu_tidak_pasti: true` tidak pernah berubah jadi `false`.
- `hasil.dikoreksi_user: true` tidak tertimpa job analisis yang telat.
- Endpoint daftar tidak pernah membocorkan data user lain.

`PenggabungSesi` diuji sebagai unit terpisah dari HTTP — aturan konflik bisa diuji habis tanpa
request, dan justru kasus langka yang paling sering luput.

`LayananVisionNutrisi` selalu di-fake dalam tes. Tidak ada tes yang memanggil penyedia asli.

**Kontrak dengan aplikasi:** simpan contoh JSON tiap resource sebagai file fixture, dan pakai
file yang sama di tes Laravel maupun tes aplikasi. Kalau bentuknya berubah sepihak, dua tes
gagal bersamaan — jauh lebih baik daripada ketahuan di produksi.

---

## 11. Urutan pengerjaan

1. **Kerangka**: Laravel + migrasi + model + Sanctum. Belum ada endpoint domain.
2. **Auth lengkap** (bagian 4), termasuk hapus akun. Jangan ditunda — menambahkannya belakangan
   menyentuh hampir semua tabel.
3. **Profil** (bagian 5.1). Sumber daya paling kecil, gunanya membuktikan jalur aplikasi ↔ server
   hidup dari ujung ke ujung.
4. **Sesi CRUD + unggah foto** (bagian 5.2), belum pakai sinkronisasi. Aplikasi memakainya sebagai
   cadangan satu arah dulu.
5. **Analisis nutrisi** (bagian 6). Ini bagian yang paling ditunggu, dan bisa dirilis sebelum
   sinkronisasi ada.
6. **Sinkronisasi dua arah** (bagian 7) + antrean kirim di sisi aplikasi.
7. **Kalibrasi, perangkat, target harian** (bagian 5.3–5.5).

Butir 1–5 sudah cukup untuk membuat aplikasi punya akun dan analisis foto yang berfungsi.
Butir 6 tergantung keputusan produk soal multi-perangkat — lihat catatan di awal bagian 7.
