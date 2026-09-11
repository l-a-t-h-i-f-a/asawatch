/// Foreground service yang menjaga aplikasi tetap hidup selama sesi berjalan —
/// docs/rencana-produksi.md §7.1.
///
/// **Ini prasyarat, bukan pemanis.** Sesi makan berlangsung ~2,5 jam dan
/// pengguna pasti meninggalkan aplikasi di tengahnya. Android membunuh proses
/// Flutter jauh sebelum titik `+1 jam` jatuh tempo, dan tiga hal mati
/// bersamanya sekaligus:
///
/// - `_timerArm` yang membangunkan `ARM_TITIK` saat jendela terbuka,
/// - lingkaran sambung ulang BLE,
/// - dan — begitu pengukuran otomatis menyala — perintah `UKUR` itu sendiri.
///
/// Proses yang mati tidak bisa memerintahkan apa pun. Tanpa service ini,
/// satu-satunya yang tersisa adalah notifikasi terjadwal yang menyuruh pengguna
/// membuka aplikasi sendiri, dan pengguna aplikasi ini lansia.
///
/// Nilai keduanya tidak kalah penting: **notifikasi persistennya adalah
/// permukaan yang selalu terlihat.** Satu baris di lockscreen yang menyebut
/// berapa menit lagi titik berikutnya jauh lebih sulit terlewat daripada banner
/// yang berbunyi sekali lalu tertimbun.
///
/// **Hanya hidup selama ada sesi aktif**, dan itu keputusan sadar. Notifikasi
/// permanen yang menyala 22 jam sehari tanpa mengatakan apa pun akan diabaikan
/// — atau lebih buruk, channel-nya dimatikan pengguna, dan channel yang mati
/// tetap mati saat titik ukur tiba. Di luar sesi juga tidak ada satu pun hal
/// yang harus terjadi tepat waktu: sampel yang belum tersalin aman di ring
/// buffer jam (protokol §6), dan `kembaliKeDepan()` menariknya saat aplikasi
/// dibuka.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Seam yang dipakai controller, supaya test tidak menyentuh platform channel.
///
/// Perannya sama persis dengan [PengingatTitikUkur] dan `KameraService`:
/// `flutter_test` tidak punya kanal platform untuk service Android, jadi tanpa
/// yang diam tidak satu pun test sesi bisa berjalan.
abstract class LayananLatar {
  /// Menyalakan service bila belum jalan, atau memperbarui isi notifikasinya
  /// bila sudah.
  ///
  /// **Satu metode, bukan `mulai` + `perbarui` terpisah, dan itu disengaja.**
  /// Pemanggilnya adalah setiap perubahan keadaan sesi — sampel masuk, hitung
  /// mundur bergerak, sesi dipulihkan dari basis data — dan tak satu pun dari
  /// mereka tahu apakah service-nya sudah menyala. Seam yang menuntut
  /// pemanggilnya mengingat itu adalah keadaan kedua yang bisa berselisih
  /// dengan yang pertama.
  Future<void> pastikanJalan({required String judul, required String isi});

  /// Menghentikan service. Aman dipanggil saat ia memang tidak jalan.
  Future<void> hentikan();
}

/// Tidak melakukan apa-apa. Bawaan untuk test dan untuk platform yang tidak
/// didukung — jauh lebih baik daripada seam null-able yang harus dijaga di
/// setiap pemanggilan.
class LayananLatarDiam implements LayananLatar {
  const LayananLatarDiam();

  @override
  Future<void> pastikanJalan({
    required String judul,
    required String isi,
  }) async {}

  @override
  Future<void> hentikan() async {}
}

/// Yang sungguhan, di atas `flutter_foreground_task`.
class LayananLatarAndroid implements LayananLatar {
  LayananLatarAndroid();

  /// Id service. Tetap, supaya `pastikanJalan` yang dipanggil dua kali tidak
  /// pernah menghasilkan dua notifikasi.
  static const int _idService = 1001;

  bool _siap = false;

  /// Isi notifikasi yang terakhir benar-benar terkirim.
  ///
  /// `updateService` menyeberangi kanal platform, dan pemanggilnya adalah
  /// `notifyListeners()` yang bisa berbunyi puluhan kali per menit selama
  /// sampel masuk. Menyaring yang tidak berubah di sini membuat pemanggilnya
  /// bebas memanggil sesering apa pun.
  String? _judulTerkirim;
  String? _isiTerkirim;

  void _siapkan() {
    if (_siap) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'sesi_berjalan',
        channelName: 'Sesi Makan Berjalan',
        channelDescription:
            'Menjaga AsaWatch tetap terhubung ke jam selama sesi makan '
            'berlangsung, dan menampilkan hitung mundur ke pengukuran '
            'berikutnya.',
        // **Sengaja rendah, bisu, dan tanpa getar.** Notifikasi ini menemani
        // pengguna selama 2,5 jam; yang berbunyi adalah pengingat titik ukur
        // (`PengingatLokal`), yang memang hanya berbunyi empat kali. Kalau
        // yang ini ikut berbunyi tiap kali hitung mundurnya berubah, ia akan
        // dimatikan pengguna dalam satu sesi.
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        enableVibration: false,
        playSound: false,
        onlyAlertOnce: true,
        // Terlihat di lockscreen. Itu justru gunanya: lansia yang tidak
        // membuka ponselnya tetap membaca berapa menit lagi.
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(),
      foregroundTaskOptions: ForegroundTaskOptions(
        // **Tanpa `TaskHandler`, jadi tanpa isolate kedua.** Yang dibutuhkan
        // dari service ini hanyalah menahan proses utama tetap hidup; seluruh
        // logika sesi, koneksi BLE, dan basis data sudah ada di isolate utama
        // dan tidak boleh punya salinan kedua yang membuka drift untuk kedua
        // kalinya.
        eventAction: ForegroundTaskEventAction.nothing(),
        // Radio harus tetap boleh bekerja saat layar mati — itu seluruh
        // gunanya.
        allowWakeLock: true,
        // Sesi harus selamat melewati aplikasi yang digeser dari daftar
        // recent, yang justru paling lazim selama dua jam menunggu.
        autoRunOnBoot: false,
        allowAutoRestart: true,
      ),
    );
    _siap = true;
  }

  @override
  Future<void> pastikanJalan({
    required String judul,
    required String isi,
  }) async {
    try {
      _siapkan();

      if (await FlutterForegroundTask.isRunningService) {
        if (judul == _judulTerkirim && isi == _isiTerkirim) return;
        await FlutterForegroundTask.updateService(
          notificationTitle: judul,
          notificationText: isi,
        );
      } else {
        await FlutterForegroundTask.startService(
          serviceId: _idService,
          serviceTypes: [ForegroundServiceTypes.connectedDevice],
          notificationTitle: judul,
          notificationText: isi,
        );
      }
      _judulTerkirim = judul;
      _isiTerkirim = isi;
    } catch (e) {
      // **Service yang gagal jalan tidak boleh menggagalkan sesi.** Yang hilang
      // adalah jaminan proses tetap hidup — sesinya sendiri, jamnya, dan
      // seluruh datanya tetap utuh, dan pengingat terjadwal (§6) tetap
      // memanggil pengguna seperti sebelum service ini ada.
      debugPrint('Layanan latar gagal dijalankan: $e');
    }
  }

  @override
  Future<void> hentikan() async {
    _judulTerkirim = null;
    _isiTerkirim = null;
    try {
      if (await FlutterForegroundTask.isRunningService) {
        await FlutterForegroundTask.stopService();
      }
    } catch (e) {
      debugPrint('Layanan latar gagal dihentikan: $e');
    }
  }
}

/// Yang mencatat, untuk test.
///
/// [LayananLatarDiam] cukup untuk test yang hanya perlu tidak meledak;
/// yang ini ada karena pertanyaan sesungguhnya adalah **kapan** service
/// dinyalakan dan dihentikan, dan itu tidak terlihat di layar mana pun.
class LayananLatarPalsu implements LayananLatar {
  bool jalan = false;

  /// Setiap isi notifikasi yang pernah dikirim, berurutan.
  final List<(String, String)> catatan = [];

  int jumlahHenti = 0;

  @override
  Future<void> pastikanJalan({
    required String judul,
    required String isi,
  }) async {
    jalan = true;
    catatan.add((judul, isi));
  }

  @override
  Future<void> hentikan() async {
    jalan = false;
    jumlahHenti++;
  }
}
