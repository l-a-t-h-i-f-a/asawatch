/// Sakelar rakitan aplikasi — docs/rencana-produksi.md §4.1.
///
/// Satu-satunya isinya adalah pilihan antara jam sungguhan dan jam palsu.
/// Diperlukan karena `FakeBleService` **tidak pernah dihapus** (§11 aturan 4):
/// ia tulang punggung test, dan satu-satunya cara mendemokan aplikasi ini di
/// perangkat yang jamnya belum ada di tangan.
///
/// ```bash
/// flutter run --dart-define=PAKAI_JAM_PALSU=true
/// ```
///
/// `bool.fromEnvironment` dievaluasi saat kompilasi, jadi build rilis biasa
/// tidak menyeret satu baris pun kode demo ke dalam jalur produksinya.
library;

import 'services/izin_ble.dart';

const bool pakaiJamPalsu = bool.fromEnvironment('PAKAI_JAM_PALSU');

/// Izin yang dipakai alur pemindaian.
///
/// Jam palsu tidak menyentuh radio sama sekali, jadi memintanya izin Bluetooth
/// hanya menghasilkan dialog yang tidak berhubungan dengan apa pun yang akan
/// terjadi berikutnya.
const IzinBle izinBleBawaan = pakaiJamPalsu
    ? IzinBleSelaluBoleh()
    : IzinBlePermissionHandler();
