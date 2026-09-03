# Alur pemasangan jam — rancangan UX

Dokumen ini merinci **satu alur saja**: dari user membuka "Menghubungkan Perangkat" sampai jam
tersandingkan dan tersambung untuk pertama kalinya. Ia melengkapi
[protokol-jam.md](protokol-jam.md) §8 (yang menetapkan *apa* yang wajib terjadi secara teknis)
dengan *bagaimana* itu terlihat oleh pengguna.

**Penggunanya lansia.** Itu bukan catatan tambahan, itu premis yang membentuk hampir setiap
keputusan di bawah. Tiga konsekuensi yang berlaku di seluruh dokumen:

1. **Satu layar, satu tindakan.** Tidak pernah ada dua hal yang bisa diketuk dan sama-sama terlihat
   penting.
2. **Waktu bukan tekanan.** Tidak ada hitungan mundur yang terlihat, dan tidak ada kegagalan yang
   terjadi karena user lambat.
3. **Kegagalan mengatakan langkah berikutnya, bukan penyebabnya.** "Gagal menyambung (error 133)"
   tidak berguna bagi siapa pun; "Dekatkan jam ke ponsel, lalu coba lagi" berguna.

---

## 1. Kenapa penyandingan tidak bisa dihilangkan

Karakteristik kustom jam wajib terenkripsi (§8), dan enkripsi BLE menuntut bonding. Tanpa itu, siapa
pun dalam jangkauan bukan sekadar bisa **membaca** sampel kesehatan, tetapi juga **menulis** ke jam:
`ANCHOR_WAKTU` palsu menggeser seluruh kalender sesi, `KALIBRASI` palsu mengubah angka tekanan darah
yang dibaca user sebagai fakta.

Yang perlu dipegang saat merancang copy: karena metodenya **Just Works** (§8 — jam tidak punya
layar), biaya seluruh keamanan itu bagi user adalah **satu ketukan, sekali seumur pemasangan.**
Tidak ada PIN, tidak ada kode, tidak ada angka yang dicocokkan.

> **Karena itu masalahnya bukan penyandingannya, melainkan kebisuan aplikasi saat ia terjadi.**
> Implementasi sekarang tidak menyentuh bonding sama sekali, jadi Android memicunya secara implisit
> di tengah operasi lain yang punya timeout ketat — dan user melihat "tidak dapat disambungkan"
> padahal yang sebenarnya terjadi adalah aplikasi tidak mau menunggunya.

---

## 2. Kosakata yang dipakai

Kata di aplikasi **harus sama persis** dengan kata di dialog sistem Android berbahasa Indonesia.
User yang membaca "hubungkan" di aplikasi lalu melihat tombol "Sandingkan" di dialog sistem akan
mengira itu dua hal berbeda.

| Dipakai | Tidak pernah dipakai |
|---|---|
| **Sandingkan** / penyandingan | pairing, bonding, pasangkan |
| **Sambungkan** / tersambung | connect, koneksi, terkoneksi |
| **Jam** | perangkat, device, wearable |
| **Ponsel** | HP, smartphone, handphone |

Istilah teknis yang **tidak boleh muncul di layar mana pun**: Bluetooth LE, BLE, GATT, MTU, bonding,
karakteristik, service UUID, error 133.

Satu-satunya kata teknis yang dipertahankan adalah **Bluetooth**, karena itu nama yang tertulis di
Pengaturan ponsel dan user harus bisa menemukannya di sana.

---

## 3. Prasyarat di firmware

Satu keputusan firmware menghapus satu langkah penuh dari alur user, dan sangat disarankan diambil:

> **Selama jam belum pernah tersandingkan dengan ponsel mana pun, ia mengiklan cepat terus-menerus**
> (interval 20–100 ms). Jam baru yang belum punya bond tidak sedang mengerjakan apa pun yang lain,
> jadi tidak ada baterai yang perlu dihemat di situ.

Konsekuensinya: **tidak ada "mode pairing" yang harus diaktifkan user.** Tidak ada tombol yang
harus ditekan-tahan, tidak ada urutan yang harus dihafal. Jam yang baru keluar kotak cukup dinyalakan.
Untuk lansia, satu langkah yang hilang jauh lebih berharga daripada penghematan baterai pada jam
yang memang belum dipakai.

Setelah bond pertama terbentuk, interval iklan boleh turun ke nilai hemat sesuai §8.

Prasyarat kedua, yang sudah tercatat di §2.2 tetapi diulang di sini karena akibatnya terlihat persis
seperti "jam rusak": **service UUID wajib ada di paket iklan, bukan di scan response.** Pemindaian
disaring di level OS, jadi jam yang menaruhnya di scan response tidak akan pernah muncul di daftar.

---

## 4. Alur utama, layar per layar

### 4.1 Layar persiapan — `MenghubungkanPerangkatPage`

Langkah-langkahnya ditulis ulang menjadi enam, dengan penyandingan sebagai langkah yang **berdiri
sendiri** dan bukan tersembunyi di dalam "tunggu sampai selesai":

| # | Teks |
|---|---|
| 1 | Pastikan Bluetooth ponsel aktif |
| 2 | Nyalakan jam AsaWatch Anda |
| 3 | Dekatkan jam ke ponsel, dalam jarak satu meter |
| 4 | Ketuk "Pindai & Sambungkan", lalu pilih perangkat yang namanya diawali "AsaWatch" |
| 5 | Saat diminta, ketuk **Sandingkan**. Tidak ada kode atau PIN yang perlu dimasukkan |
| 6 | Tunggu sampai muncul "Jam Tersambung" |

Di bawahnya, satu kalimat penenang — ini yang mencegah user mengira ritualnya harus diulang setiap
kali makan:

> Pemasangan ini hanya dilakukan sekali. Setelah itu jam tersambung sendiri setiap kali berada di
> dekat ponsel.

### 4.2 Layar pemindaian — `PemindaianPerangkatPage`

Tidak berubah banyak, dengan dua catatan:

- Daftar hasil sudah disaring ke AsaWatch saja, dan halaman ini **sudah** mengatakannya dalam kata.
  Pertahankan copy itu: pada layar yang cuma menampilkan satu baris, user perlu tahu bahwa itu
  memang yang dicari, bukan sisa dari daftar yang gagal dimuat.
- Baris jam ditampilkan besar dan menjadi satu-satunya elemen yang bisa diketuk. Kekuatan sinyal
  boleh tetap ada sebagai batang kecil, tetapi tidak diberi label angka — RSSI tidak berarti apa pun
  bagi user.

### 4.3 Menyambung — empat keadaan, bukan satu

Ini inti perubahannya. `_idMenyambung` sekarang cuma menyatakan "sedang sibuk"; ia dipecah menjadi
empat keadaan karena masing-masing menuntut hal yang berbeda dari user.

| Keadaan | Judul di layar | Baris penjelas | Yang diminta | Batas waktu |
|---|---|---|---|---|
| `menyambung` | Menyambungkan ke AsaWatch X1… | Pastikan jam berada di dekat ponsel. | menunggu | 15 detik |
| `menyandingkan` | **Ketuk "Sandingkan" pada permintaan yang muncul** | Tidak ada kode yang perlu dimasukkan. Jangan tutup halaman ini. | satu ketukan | **tidak ada** (lihat di bawah) |
| `menyiapkan` | Menyiapkan jam… | Sebentar lagi selesai. | menunggu | 20 detik |
| `berhasil` | AsaWatch X1 tersambung | Selanjutnya jam akan tersambung sendiri. | — | — |

Aturan yang mengikat implementasi:

**Selama keadaan `menyandingkan`, hitung mundur berhenti sepenuhnya.** Yang ditunggu adalah jari
manusia, bukan radio. Batas praktisnya ada — sistem sendiri akan membatalkan permintaan yang tidak
dijawab — tetapi aplikasi tidak boleh menyerah lebih dulu, dan tidak boleh menampilkan hitungan
mundur apa pun. Lansia yang melihat angka berkurang akan panik, dan panik memperlambat, bukan
mempercepat.

**Keadaan `menyandingkan` ditampilkan penuh, bukan sebagai spinner kecil di baris daftar.** Ia satu-
satunya momen di seluruh alur yang menuntut tindakan dari user, dan momen itu harus mustahil
terlewat: judul besar, ilustrasi sederhana yang menunjukkan bentuk dialog sistemnya, dan tidak ada
tombol lain yang aktif selain "Batal".

### 4.4 Kalau permintaannya muncul sebagai notifikasi

Di sebagian ponsel — terutama bila aplikasi sedang tidak di depan — permintaan sandingkan tidak
muncul sebagai dialog di tengah layar, melainkan sebagai notifikasi di panel atas. User yang tidak
menariknya tidak akan pernah menyandingkan, dan dari sisi aplikasi hasilnya tidak bisa dibedakan
dari jam yang mati.

Setelah **8 detik** berada di keadaan `menyandingkan` tanpa jawaban, tambahkan baris kedua (jangan
mengganti yang pertama):

> Belum melihat permintaannya? Usap layar dari atas ke bawah, lalu ketuk **Permintaan penyandingan
> Bluetooth**.

Delapan detik dipilih supaya user yang menjawab dengan normal tidak pernah melihat kalimat ini —
instruksi tambahan yang muncul saat semuanya berjalan baik justru membuat ragu.

### 4.5 Melepas pemasangan

Dua jalan yang berbeda menuju keadaan yang sama, dan aplikasi tidak boleh menyamakan keduanya.

**Dari dalam aplikasi — "Lupakan Jam Ini".** Memutus koneksi, menghapus penyandingan di ponsel, dan
melupakan jamnya, sehingga aplikasi kembali ke keadaan "belum pernah dipasangkan" seutuhnya. Selalu
dikonfirmasi lebih dulu, karena akibatnya tidak terlihat dan tidak bisa dibatalkan: **sampel yang
masih menunggu di buffer jam tidak akan pernah sampai** setelah tidak ada lagi yang menyambunginya.
Dialognya menyebut jumlahnya apa adanya ("3 data yang masih tersimpan di jam…"), menyebut sesi yang
sedang berjalan bila ada, dan menutup dengan penegasan bahwa riwayat yang sudah tersimpan tetap aman
— tiga hal yang tidak bisa disimpulkan sendiri oleh siapa pun.

Tombolnya sengaja **tidak** berdampingan dengan "Putuskan" sebagai pilihan setara: keduanya
terdengar mirip, tetapi hanya satu yang bisa dibatalkan.

**Dari Pengaturan Bluetooth sistem, di luar aplikasi.** Aplikasi masih mengingat jamnya sementara
ponsel sudah tidak menyandingkannya. Aturan yang mengikat di sini:

> **Penyandingan tidak pernah dimulai dari latar belakang.**

Lingkaran sambung ulang memeriksa `bondState` lebih dulu; bila bond-nya hilang, ia **berhenti** dan
menandai `StatusPerangkat.penyandinganHilang`. Menyambung lagi pada keadaan itu akan memunculkan
dialog penyandingan sistem entah kapan saja — saat user sedang menelepon, sedang di aplikasi lain,
tanpa ia sedang memasang apa pun. Permintaan seperti itu mustahil dimengerti, dan yang paling
mungkin dilakukan user adalah menolaknya.

Yang ditampilkan pada keadaan itu berbeda dari "terputus" biasa di tiga tempat, karena tindak
lanjutnya memang bertolak belakang — yang terputus akan tersambung sendiri, yang ini tidak akan
pernah:

| | Terputus | Penyandingan hilang |
|---|---|---|
| Judul kartu | Jam Terputus | **Jam Tidak Tersandingkan** |
| Baris kedua | Sinkron terakhir … | **Dihapus dari Bluetooth ponsel** |
| Tombol | Sambungkan Ulang | **Sandingkan Ulang** |

Ragu diperlakukan sebagai "masih tersandingkan": pembacaan bond yang gagal bukan bukti bahwa
penyandingannya hilang, dan menghentikan sambung ulang atas dasar tebakan akan membuat jam yang
sehat terlihat lepas.

---

## 5. Jalur gagal

Setiap kegagalan punya kalimatnya sendiri. Menyeragamkannya menjadi "gagal menyambung, coba lagi"
adalah cara tercepat membuat user mencoba hal yang sama sepuluh kali.

| Sebab | Yang ditampilkan | Tombol |
|---|---|---|
| Jam tidak ditemukan saat memindai | Jam tidak ditemukan. Pastikan jam menyala dan berada dalam jarak satu meter dari ponsel. | Pindai lagi |
| Connect gagal / di luar jangkauan | AsaWatch X1 belum bisa disambungkan. Dekatkan jam ke ponsel, lalu coba lagi. | Coba lagi |
| User menolak penyandingan | Penyandingan dibatalkan. Jam perlu disandingkan sekali agar datanya terkirim dengan aman. | Coba lagi |
| Permintaan tidak dijawab | Permintaan penyandingan belum dijawab. Coba lagi, lalu ketuk "Sandingkan" saat permintaan itu muncul. | Coba lagi |
| **Bond basi** (jam di-reset / firmware diganti) | AsaWatch X1 pernah disandingkan dengan data yang sudah tidak berlaku, jadi ponsel dan jam tidak lagi saling mengenali. | **Coba Lagi**, lalu **Sandingkan ulang jam ini** |
| Versi protokol tidak cocok | *(sudah ada — `GalatVersiJam.pesanPengguna`)* | Sesuai pesan |
| Bluetooth ponsel mati | *(sudah ada — `HasilIzinBle.bluetoothMati`)* | Nyalakan Bluetooth |
| Izin ditolak permanen | *(sudah ada — `HasilIzinBle.ditolakPermanen`)* | Buka Pengaturan |

Bond basi adalah **satu-satunya kegagalan di tabel ini yang tidak akan pernah pulih dengan mencoba
lagi**, karena kunci enkripsi lama masih tersimpan di ponsel sementara jam sudah tidak mengenalinya.
Ia ditangani bertingkat, dan urutannya disengaja:

1. **"Coba Lagi" tetap tombol utamanya.** Sisi aplikasi hanya bisa *menduga* kunci basi — jam yang
   menjauh di detik yang keliru terlihat sangat mirip. Menaruh penghapusan penyandingan sebagai
   tindakan utama berarti merusak pemasangan yang sebenarnya sehat atas dasar tebakan.
2. **"Sandingkan ulang jam ini"** memanggil `removeBond()` lalu menyambung lagi — jalan keluar yang
   tidak menuntut pengguna membuka Pengaturan sistem sama sekali.
3. **Kalau `removeBond()` ditolak** (sebagian versi Android tidak mengizinkannya dari aplikasi),
   barulah muncul petunjuk manual: Pengaturan → Bluetooth → jam → Lupakan. Petunjuk itu harus
   menyebut **Pengaturan Bluetooth**, bukan Pengaturan aplikasi, yang tidak memuat daftar perangkat
   tersandingkan.

**"Nyalakan Bluetooth" pada baris itu adalah tombol sungguhan, bukan kalimat perintah.** Ia memanggil
`IzinBle.nyalakanBluetooth()`, yang di Android memunculkan dialog sistem `ACTION_REQUEST_ENABLE` di
atas halaman pemindaian; begitu radionya hidup, pemindaian dimulai lagi sendiri tanpa ketukan kedua.
Tiga hal membatasi janji itu, dan ketiganya terlihat di layar:

- **Ini bukan "menyalakan diam-diam".** Sejak Android 13 `BluetoothAdapter.enable()` dicabut, jadi
  persetujuan tetap milik pengguna. Yang dihemat adalah perjalanan ke Pengaturan dan — bagian yang
  paling sering berakhir di tempat lain untuk pengguna yang dituju dokumen ini — jalan kembalinya.
- **Tombolnya hanya muncul di platform yang bisa memenuhinya** (`bisaMenyalakanBluetooth`). iOS tidak
  punya padanannya dan tidak akan punya, jadi di sana kartunya tetap menunjuk ke Pengaturan ponsel.
- **Menolak dialog bukan jalan buntu.** `HasilNyalakanBluetooth.ditolakPengguna` mengembalikan
  halaman ke keadaan semula dengan tombol yang masih bisa ditekan — bukan pesan kesalahan, karena
  tidak ada yang salah: pengguna baru saja memutuskan sesuatu yang memang haknya.

**Setelah gagal, jangan lempar user kembali ke awal.** Tombol "Coba lagi" mengulang penyambungan ke
jam yang sama, tanpa memindai ulang. Memaksa memindai lagi berarti mengulang seluruh ritual untuk
kesalahan yang sering kali hanya berarti "jamnya sedikit terlalu jauh".

---

## 6. Detail yang khusus untuk lansia

- **Ukuran sentuh minimal 56 dp** untuk baris jam dan seluruh tombol di alur ini — di atas 48 dp yang
  jadi anjuran umum Material. Ketepatan jari menurun jauh lebih cepat daripada penglihatan.
- **Teks instruksi minimal 16 sp, judul keadaan minimal 22 sp.** Jangan andalkan warna sebagai satu-
  satunya pembeda antara "sedang berjalan" dan "gagal" — sertakan ikon dan kata.
- **Umpan balik saat berhasil harus lebih dari sekadar teks**: getaran singkat dan tanda centang yang
  bertahan beberapa detik. Perubahan yang hanya berupa teks berganti sering tidak tertangkap.
- **Jangan pernah menutup halaman secara otomatis** setelah berhasil sebelum user sempat membaca
  konfirmasinya. Beri jeda, atau minta ketukan "Selesai".
- **Tidak ada gestur** di alur ini: tidak ada geser-untuk-menyegarkan, tidak ada tekan-tahan. Hanya
  ketukan.
- **Satu jalan keluar yang jelas di setiap layar.** Tombol kembali milik halaman sendiri sudah ada di
  seluruh aplikasi; pastikan ia tetap terlihat, termasuk saat sedang menyambung.

---

## 7. Keadaan implementasi

Sisi aplikasi **sudah dikerjakan**; yang tersisa ada di firmware.

| Berkas | Perubahan | Status |
|---|---|---|
| [lib/services/ble_service.dart](../lib/services/ble_service.dart) | `TahapSambung`, `HasilSambung` + pesannya, `tahapSambung`, `lupakanPenyandingan`; `PenyandinganPalsu` di `FakeBleService` | selesai |
| [lib/services/ble_asli_service.dart](../lib/services/ble_asli_service.dart) | `createBond()` eksplisit sesudah `connect()` dan **sebelum** `discoverServices()`; klasifikasi hangus vs ditolak; dugaan kunci basi | selesai |
| [lib/controllers/sesi_makan_controller.dart](../lib/controllers/sesi_makan_controller.dart) | meneruskan tahap, hasil, dan `lupakanPenyandingan` | selesai |
| [lib/pemindaian_perangkat_page.dart](../lib/pemindaian_perangkat_page.dart) | layar penyambungan penuh, petunjuk notifikasi 8 detik, pesan gagal per sebab | selesai |
| [lib/menghubungkan_perangkat_page.dart](../lib/menghubungkan_perangkat_page.dart) | enam langkah §4.1, kalimat penenang, "Lupakan Jam Ini" + konfirmasinya, keadaan penyandingan hilang | selesai |
| [lib/models/sesi_makan.dart](../lib/models/sesi_makan.dart) | `StatusPerangkat.penyandinganHilang` dan `StatusPerangkat.kosong` | selesai |
| [test/penyandingan_test.dart](../test/penyandingan_test.dart) | dua belas test menutupi §4.3–§5 | selesai |
| **Firmware** | **iklan cepat selama belum ada bond (§3)** | **belum** |

`FakeBleService.penyandingan` memodelkan kelima perilakunya, termasuk dialog yang **tidak pernah
dijawab** dan kunci yang **basi** — dua keadaan yang tidak bisa dipesan pada jam sungguhan, sementara
justru merekalah yang paling membingungkan pengguna. Tanpa tiruan itu, seluruh copy di dokumen ini
baru terlihat pertama kali di tangan pengguna.

> **Catatan untuk test.** Jeda `FakeBleService` ikut dipercepat, sedangkan `jedaPetunjukNotifikasi`
> (8 detik) tidak — ia timer UI. Test yang menguji petunjuk itu karenanya memakai `percepatan: 1`;
> dengan 3600 yang biasa dipakai test lain, seluruh penyandingan mampat menjadi sepersekian detik dan
> tidak ada yang bisa diamati.
