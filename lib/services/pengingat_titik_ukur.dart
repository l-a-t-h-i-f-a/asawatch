/// Pengingat titik ukur — docs/jadwal-titik-ukur.md §6.
///
/// **Ini bukan fitur tambahan, ini bagian dari jadwal.** Sampai protokol v1.2,
/// jam yang menjadwalkan titik ukurnya sendiri: ia bergetar dan mengukur tanpa
/// perlu ada yang mengingat apa pun. v1.3 mencabut penjadwal itu karena jam
/// tidak bertahan lebih dari ~50 menit menyala (§9, §12) — dan begitu ia
/// dicabut, **tidak ada lagi yang mengingatkan selain aplikasi.**
///
/// Dua pengingat per titik, bukan satu:
///
/// 1. **T−5 menit** — "siapkan jam". Menyalakan jam dan memasangnya di
///    pergelangan butuh waktu.
/// 2. **T** — "ukur sekarang".
///
/// Pengingat yang baru berbunyi tepat pada detik jatuh temponya sudah pasti
/// menghasilkan pengukuran yang telat, dan titik yang telat tidak punya
/// pengganti (§3).
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/jadwal_sesi.dart';

/// Seam yang dipakai controller, supaya test tidak menyentuh platform channel.
abstract class PengingatTitikUkur {
  /// Menyiapkan kanal notifikasi dan **meminta izinnya**, sekali saja.
  ///
  /// Dipanggil saat pengguna pertama kali masuk ke aplikasi (`MyHomePage`),
  /// bukan saat pengingat pertama dijadwalkan. Sebelumnya izin baru diminta di
  /// dalam [jadwalkan] — yaitu tepat pada detik sesi dimulai, saat pengguna
  /// sedang berdiri di depan piringnya dan baru saja menekan tombol jam.
  /// Dialog sistem yang muncul di saat itu ditolak karena menghalangi, dan
  /// yang hilang bukan dialognya melainkan empat titik ukur yang tidak ada
  /// lagi yang mengingatkan (§6).
  ///
  /// Aman dipanggil berkali-kali: hanya yang pertama yang bekerja.
  Future<void> siapkan();

  /// Menjadwalkan ulang **seluruh** pengingat sesi ini.
  ///
  /// Selalu menghapus dulu, tidak pernah menambah di atas yang lama: satu-satunya
  /// pemanggilnya adalah perubahan keadaan sesi, dan pengingat lama untuk titik
  /// yang sudah terisi adalah pengingat yang menyuruh mengukur sesuatu yang
  /// sudah diukur.
  Future<void> jadwalkan({
    required DateTime t0,
    required List<TitikJadwal> titik,
    required DateTime sekarang,
  });

  Future<void> batalkanSemua();
}

/// Tidak melakukan apa-apa. Bawaan untuk test dan untuk platform yang tidak
/// didukung — jauh lebih baik daripada seam yang null-able dan harus dijaga di
/// setiap pemanggilan.
class PengingatDiam implements PengingatTitikUkur {
  const PengingatDiam();

  @override
  Future<void> siapkan() async {}

  @override
  Future<void> jadwalkan({
    required DateTime t0,
    required List<TitikJadwal> titik,
    required DateTime sekarang,
  }) async {}

  @override
  Future<void> batalkanSemua() async {}
}

class PengingatLokal implements PengingatTitikUkur {
  PengingatLokal({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _siap = false;

  /// Berapa lama sebelum jendela terbuka pengingat pertama berbunyi.
  static const Duration ancang = Duration(minutes: 5);

  static const _detail = NotificationDetails(
    android: AndroidNotificationDetails(
      'titik_ukur',
      'Pengingat Pengukuran',
      channelDescription:
          'Mengingatkan kapan harus menyalakan jam dan mengambil pengukuran '
          'sesi makan.',
      importance: Importance.max,
      priority: Priority.high,
    ),
  );

  @override
  Future<void> siapkan() async {
    if (_siap) return;
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
    );

    // **Izin runtime, bukan cuma manifest.** Sejak Android 13,
    // `POST_NOTIFICATIONS` harus diminta ke pengguna; tanpa itu
    // `zonedSchedule` di bawah **berhasil tanpa keluhan** dan notifikasinya
    // tidak pernah muncul. Kegagalan yang tidak bergejala seperti itu persis
    // yang paling mahal di sini: yang hilang bukan notifikasinya melainkan
    // titik ukur yang tidak diambil karena tidak ada yang mengingatkan.
    //
    // Ditolaknya izin **tidak** dianggap galat. Kedua tombol tetap bekerja dan
    // layar sesi tetap menunjukkan hitung mundurnya; yang hilang hanya
    // pengingat saat aplikasi tertutup.
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    await android?.requestNotificationsPermission();

    // Titik ukur punya jendela toleransi semenit-menitan, jadi pengingatnya
    // tidak boleh digeser Doze ke waktu yang nyaman bagi sistem. Di Android 14+
    // ini membuka layar pengaturan, jadi ia diminta sekali di sini dan bukan
    // di setiap penjadwalan.
    await android?.requestExactAlarmsPermission();

    _siap = true;
  }

  @override
  Future<void> jadwalkan({
    required DateTime t0,
    required List<TitikJadwal> titik,
    required DateTime sekarang,
  }) async {
    try {
      await siapkan();
      await batalkanSemua();

      for (final t in titik) {
        if (!t.berjendela) continue;
        final jatuhTempo = t0.add(Duration(seconds: t.jendelaAwal!));

        await _satu(
          id: t.index * 2,
          kapan: jatuhTempo.subtract(ancang),
          sekarang: sekarang,
          judul: 'Siapkan jam — ${t.label}',
          isi:
              'Pengukuran ${t.label} sebentar lagi. Nyalakan jam dan pakai di '
              'pergelangan.',
        );
        await _satu(
          id: t.index * 2 + 1,
          kapan: jatuhTempo,
          sekarang: sekarang,
          judul: 'Saatnya pengukuran ${t.label}',
          isi: 'Buka AsaWatch dan ambil pengukuran ${t.label} sekarang.',
        );
      }
    } catch (e) {
      // Notifikasi yang gagal dijadwalkan **tidak** menggagalkan sesi. Kedua
      // tombolnya tetap bekerja dan layar sesi tetap menunjukkan hitung
      // mundurnya; yang hilang hanyalah pengingat saat aplikasi tertutup.
      debugPrint('Pengingat titik ukur gagal dijadwalkan: $e');
    }
  }

  Future<void> _satu({
    required int id,
    required DateTime kapan,
    required DateTime sekarang,
    required String judul,
    required String isi,
  }) async {
    // Yang sudah lewat tidak dijadwalkan. Notifikasi masa lalu tidak pernah
    // berbunyi, tetapi ia juga tidak jujur: sesi yang dipulihkan setelah
    // aplikasi tertutup dua jam akan menjadwalkan empat pengingat yang semuanya
    // sudah kedaluwarsa.
    if (!kapan.isAfter(sekarang)) return;

    await _plugin.zonedSchedule(
      id: id,
      title: judul,
      body: isi,
      scheduledDate: tz.TZDateTime.from(kapan, tz.local),
      notificationDetails: _detail,
      // `Timer` mati bersama prosesnya, dan proses Flutter dibunuh Doze jauh
      // sebelum dua jam berlalu. Penjadwalan tingkat sistem adalah satu-satunya
      // yang bertahan sampai titiknya jatuh tempo.
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Future<void> batalkanSemua() async {
    try {
      await siapkan();
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Pengingat titik ukur gagal dibatalkan: $e');
    }
  }
}
