/// Data palsu untuk Fase UI (§10: langkah 1 dikerjakan lebih dulu dengan data
/// palsu, tanpa menunggu BLE maupun endpoint deteksi nutrisi).
///
/// Angka nutrisinya sengaja sama dengan yang sudah tampil di
/// deteksi_makanan_page.dart hari ini (430 kcal, 45 g karbo, 28 g protein,
/// 15 g lemak), ditambah gula total dan serat sesuai §12.4.
library;

import 'sesi_makan.dart';

/// Foto contoh; sama dengan yang dipakai layar deteksi makanan.
const String contohFotoPath =
    'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=600';

HasilDeteksi contohHasilDeteksi() => const HasilDeteksi(
  makanan: [
    ItemMakanan(
      nama: 'Nasi merah',
      porsi: '1 centong',
      estimasiGram: 120,
      nutrisi: Nutrisi(
        kalori: 150,
        karbohidrat: 32,
        protein: 3,
        lemak: 1,
        gulaTotal: 0.5,
        serat: 2.5,
      ),
    ),
    ItemMakanan(
      nama: 'Ayam panggang',
      porsi: '1 potong',
      estimasiGram: 110,
      nutrisi: Nutrisi(
        kalori: 220,
        karbohidrat: 4,
        protein: 24,
        lemak: 12,
        gulaTotal: 1,
        serat: 0,
      ),
    ),
    ItemMakanan(
      nama: 'Tumis buncis',
      porsi: '1 mangkuk kecil',
      estimasiGram: 90,
      nutrisi: Nutrisi(
        kalori: 60,
        karbohidrat: 9,
        protein: 1,
        lemak: 2,
        gulaTotal: 3,
        serat: 3.5,
      ),
    ),
  ],
  total: Nutrisi(
    kalori: 430,
    karbohidrat: 45,
    protein: 28,
    lemak: 15,
    gulaTotal: 4.5,
    serat: 6,
  ),
  indeksGlikemikPerkiraan: 'sedang',
  keyakinan: 0.82,
);

/// Sesi yang sedang berjalan: baseline dan t0 sudah terisi, +1 jam / +2 jam
/// masih ditunggu.
SesiMakan contohSesiBerjalan({DateTime? sekarang}) {
  final now = sekarang ?? DateTime.now();
  final t0 = now.subtract(const Duration(minutes: 18));
  return SesiMakan(
    id: 'sesi-berjalan',
    fotoPath: contohFotoPath,
    waktuFoto: t0.subtract(const Duration(minutes: 25)),
    t0: t0,
    status: StatusSesi.berjalan,
    hasil: contohHasilDeteksi(),
    sampel: const [
      Sampel(
        index: 0,
        detikRelatifT0: -1500,
        status: StatusSampel.terisi,
        gulaDarah: 92,
        detakJantung: 74,
        sistolik: 116,
        diastolik: 76,
        spo2: 98,
      ),
      Sampel(
        index: 1,
        detikRelatifT0: 0,
        status: StatusSampel.terisi,
        gulaDarah: 98,
        detakJantung: 81,
        sistolik: 119,
        diastolik: 78,
        spo2: 98,
      ),
      Sampel.menunggu(index: 2, detikRelatifT0: 3600),
      Sampel.menunggu(index: 3, detikRelatifT0: 7200),
    ],
  );
}

/// Sesi yang sudah lengkap 4 sampel — untuk Ringkasan Sesi.
SesiMakan contohSesiSelesai({DateTime? sekarang}) {
  final now = sekarang ?? DateTime.now();
  final t0 = now.subtract(const Duration(hours: 3));
  return SesiMakan(
    id: 'sesi-selesai',
    fotoPath: contohFotoPath,
    waktuFoto: t0.subtract(const Duration(minutes: 25)),
    t0: t0,
    status: StatusSesi.selesai,
    hasil: contohHasilDeteksi(),
    sampel: const [
      Sampel(
        index: 0,
        detikRelatifT0: -1500,
        status: StatusSampel.terisi,
        gulaDarah: 92,
        detakJantung: 74,
        sistolik: 116,
        diastolik: 76,
        spo2: 98,
      ),
      Sampel(
        index: 1,
        detikRelatifT0: 0,
        status: StatusSampel.terisi,
        gulaDarah: 98,
        detakJantung: 81,
        sistolik: 119,
        diastolik: 78,
        spo2: 98,
      ),
      Sampel(
        index: 2,
        detikRelatifT0: 3600,
        status: StatusSampel.terisi,
        gulaDarah: 140,
        detakJantung: 88,
        sistolik: 124,
        diastolik: 80,
        spo2: 97,
      ),
      Sampel(
        index: 3,
        detikRelatifT0: 7200,
        status: StatusSampel.terisi,
        dariBuffer: true,
        gulaDarah: 99,
        detakJantung: 76,
        sistolik: 118,
        diastolik: 77,
        spo2: 98,
      ),
    ],
  );
}

/// Sesi yang berakhir dengan satu sampel terlewat — untuk menguji bahwa UI
/// menulis `—`, bukan mengisi nilai lama (§8).
SesiMakan contohSesiTidakLengkap({DateTime? sekarang}) {
  final now = sekarang ?? DateTime.now();
  final t0 = now.subtract(const Duration(hours: 5));
  return SesiMakan(
    id: 'sesi-tidak-lengkap',
    fotoPath: contohFotoPath,
    waktuFoto: t0.subtract(const Duration(minutes: 20)),
    t0: t0,
    status: StatusSesi.tidakLengkap,
    hasil: contohHasilDeteksi(),
    sampel: const [
      Sampel(
        index: 0,
        detikRelatifT0: -1200,
        status: StatusSampel.terisi,
        gulaDarah: 95,
        detakJantung: 72,
        sistolik: 118,
        diastolik: 78,
        spo2: 98,
      ),
      Sampel(
        index: 1,
        detikRelatifT0: 0,
        status: StatusSampel.terisi,
        gulaDarah: 104,
        detakJantung: 84,
        sistolik: 121,
        diastolik: 79,
        spo2: 97,
      ),
      Sampel(
        index: 2,
        detikRelatifT0: 3600,
        status: StatusSampel.terisi,
        gulaDarah: 158,
        detakJantung: 92,
        sistolik: 128,
        diastolik: 83,
        spo2: 97,
      ),
      Sampel(index: 3, detikRelatifT0: 7200, status: StatusSampel.terlewat),
    ],
  );
}

/// Beberapa menu contoh dengan kandungan karbohidrat yang berbeda-beda.
///
/// Variasi ini yang membuat scatter "karbohidrat vs kenaikan gula darah" di
/// Analisis (§4.3) punya isi: kalau semua sesi memakai angka nutrisi yang
/// sama, sebarannya cuma satu kolom tegak dan tidak menjelaskan apa pun.
HasilDeteksi contohHasilMenu(
  int indeks, {
  double keyakinan = 0.82,
  bool dikoreksiUser = false,
}) {
  const menu = [
    (
      nama: 'Salad buah',
      porsi: '1 mangkuk',
      gram: 180.0,
      nutrisi: Nutrisi(
        kalori: 160,
        karbohidrat: 22,
        protein: 3,
        lemak: 5,
        gulaTotal: 16,
        serat: 4,
      ),
    ),
    (
      nama: 'Roti gandum & telur',
      porsi: '2 lembar',
      gram: 150.0,
      nutrisi: Nutrisi(
        kalori: 280,
        karbohidrat: 30,
        protein: 16,
        lemak: 11,
        gulaTotal: 4,
        serat: 5,
      ),
    ),
    (
      nama: 'Nasi merah & ayam panggang',
      porsi: '1 piring',
      gram: 320.0,
      nutrisi: Nutrisi(
        kalori: 430,
        karbohidrat: 45,
        protein: 28,
        lemak: 15,
        gulaTotal: 4.5,
        serat: 6,
      ),
    ),
    (
      nama: 'Bubur ayam',
      porsi: '1 mangkuk',
      gram: 350.0,
      nutrisi: Nutrisi(
        kalori: 380,
        karbohidrat: 55,
        protein: 14,
        lemak: 11,
        gulaTotal: 3,
        serat: 2,
      ),
    ),
    (
      nama: 'Nasi putih & rendang',
      porsi: '1 piring',
      gram: 340.0,
      nutrisi: Nutrisi(
        kalori: 620,
        karbohidrat: 68,
        protein: 26,
        lemak: 28,
        gulaTotal: 5,
        serat: 3,
      ),
    ),
    (
      nama: 'Mie goreng',
      porsi: '1 porsi',
      gram: 300.0,
      nutrisi: Nutrisi(
        kalori: 590,
        karbohidrat: 75,
        protein: 15,
        lemak: 24,
        gulaTotal: 8,
        serat: 3,
      ),
    ),
  ];

  final m = menu[indeks % menu.length];
  return HasilDeteksi(
    makanan: [
      ItemMakanan(
        nama: m.nama,
        porsi: m.porsi,
        estimasiGram: m.gram,
        nutrisi: m.nutrisi,
      ),
    ],
    total: m.nutrisi,
    indeksGlikemikPerkiraan: (m.nutrisi.karbohidrat ?? 0) >= 60
        ? 'tinggi'
        : (m.nutrisi.karbohidrat ?? 0) >= 35
        ? 'sedang'
        : 'rendah',
    keyakinan: keyakinan,
    dikoreksiUser: dikoreksiUser,
  );
}

/// Beberapa sesi lampau untuk mengisi Beranda (kartu sesi terakhir, ringkasan
/// nutrisi hari ini, sparkline puncak) dan Riwayat selama Fase UI.
///
/// Urut terbaru → terlama, sesuai urutan yang dipakai controller.
List<SesiMakan> contohRiwayatSesi({DateTime? sekarang}) {
  final now = sekarang ?? DateTime.now();
  final hariIni = DateTime(now.year, now.month, now.day);

  SesiMakan buat({
    required String id,
    required DateTime t0,
    required int baseline,
    required int setelahMakan,
    required int satuJam,
    required int duaJam,
    required HasilDeteksi hasil,
  }) {
    return SesiMakan(
      id: id,
      fotoPath: contohFotoPath,
      waktuFoto: t0.subtract(const Duration(minutes: 22)),
      t0: t0,
      status: StatusSesi.selesai,
      hasil: hasil,
      sampel: [
        Sampel(
          index: 0,
          detikRelatifT0: -1320,
          status: StatusSampel.terisi,
          gulaDarah: baseline,
          detakJantung: 73,
          sistolik: 117,
          diastolik: 77,
          spo2: 98,
        ),
        Sampel(
          index: 1,
          detikRelatifT0: 0,
          status: StatusSampel.terisi,
          gulaDarah: setelahMakan,
          detakJantung: 82,
          sistolik: 120,
          diastolik: 78,
          spo2: 98,
        ),
        Sampel(
          index: 2,
          detikRelatifT0: 3600,
          status: StatusSampel.terisi,
          gulaDarah: satuJam,
          detakJantung: 88,
          sistolik: 124,
          diastolik: 81,
          spo2: 97,
        ),
        Sampel(
          index: 3,
          detikRelatifT0: 7200,
          status: StatusSampel.terisi,
          gulaDarah: duaJam,
          detakJantung: 77,
          sistolik: 118,
          diastolik: 77,
          spo2: 98,
        ),
      ],
    );
  }

  // Sengaja beragam waktu makan dan kualitas respons, agar kedua filter di
  // Riwayat (§4.2) ada isinya.
  // Kenaikan gula darahnya sengaja mengikuti kandungan karbohidrat menunya,
  // supaya sebaran di Analisis memperlihatkan hubungan yang memang ada — satu
  // sesi berkeyakinan rendah disisipkan sebagai titik yang harus ditandai
  // berbeda dan dikeluarkan dari garis tren (§4.3).
  return [
    buat(
      id: 'riwayat-0',
      t0: hariIni.add(const Duration(hours: 16, minutes: 15)),
      hasil: contohHasilMenu(0), // salad buah, 22 g karbo
      baseline: 92,
      setelahMakan: 97,
      satuJam: 112, // delta 20 — landai
      duaJam: 94,
    ),
    buat(
      id: 'riwayat-1',
      t0: hariIni.add(const Duration(hours: 12, minutes: 40)),
      hasil: contohHasilMenu(2), // nasi merah & ayam, 45 g
      baseline: 94,
      setelahMakan: 101,
      satuJam: 142, // delta 48
      duaJam: 100,
    ),
    buat(
      id: 'riwayat-2',
      t0: hariIni.add(const Duration(hours: 7, minutes: 30)),
      hasil: contohHasilMenu(1), // roti gandum & telur, 30 g
      baseline: 90,
      setelahMakan: 96,
      satuJam: 118, // delta 28
      duaJam: 95,
    ),
    buat(
      id: 'riwayat-3',
      t0: hariIni.subtract(const Duration(hours: 5)),
      hasil: contohHasilMenu(5), // mie goreng, 75 g
      baseline: 96,
      setelahMakan: 104,
      satuJam: 172, // delta 76 — lonjakan, belum pulih dalam 2 jam
      duaJam: 118,
    ),
    buat(
      id: 'riwayat-4',
      t0: hariIni.subtract(const Duration(hours: 11)),
      hasil: contohHasilMenu(3, keyakinan: 0.45), // bubur ayam, porsi ragu
      baseline: 91,
      setelahMakan: 97,
      satuJam: 133, // delta 42
      duaJam: 99,
    ),
    buat(
      id: 'riwayat-5',
      t0: hariIni.subtract(const Duration(days: 1, hours: 4)),
      hasil: contohHasilMenu(4), // nasi putih & rendang, 68 g
      baseline: 93,
      setelahMakan: 99,
      satuJam: 155, // delta 62 — lonjakan
      duaJam: 108,
    ),
  ];
}

const StatusPerangkat contohPerangkatTersambung = StatusPerangkat(
  tersambung: true,
  baterai: 68,
  sampelTertunda: 0,
  namaPerangkat: 'AsaWatch X1',
);

/// Jam yang sudah dipasangkan tetapi sedang putus — bukan hal yang sama dengan
/// [contohPerangkatBelumDipasangkan], karena sampelnya masih menunggu di
/// buffer dan namanya sudah dikenal.
const StatusPerangkat contohPerangkatTerputus = StatusPerangkat(
  tersambung: false,
  baterai: 41,
  sampelTertunda: 2,
  namaPerangkat: 'AsaWatch X1',
);

/// Belum pernah ada jam yang dipasangkan: UI harus menawarkan pemindaian.
const StatusPerangkat contohPerangkatBelumDipasangkan = StatusPerangkat(
  tersambung: false,
);
