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
///
/// **Yang kedua adalah alarm, bukan notifikasi.** Ia berbunyi berulang-ulang
/// di aliran suara alarm sampai pengguna menekan "Oke, Jam Sudah Dipakai" di
/// `KonfirmasiPakaiJamPage` — apa pun keadaan jamnya. Tersambung tidak berarti
/// terpakai: jam yang tergeletak di meja tetap tersambung, dan pengukuran
/// otomatis padanya hanya menunggu 90 detik lalu gagal. Yang boleh membungkam
/// alarm hanya dua: orangnya sendiri, atau sampel titik itu yang benar-benar
/// masuk (sampel butuh nadi, jadi ia bukti jamnya menempel). Notifikasi biasa
/// berbunyi sekali dan lewat; untuk pengguna lansia yang ponselnya di meja
/// sebelah, itu sama dengan tidak diingatkan.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/jadwal_sesi.dart';

/// Alarm titik ukur yang diketuk pengguna: sesi mana, titik mana.
///
/// `sesiId` ikut dibawa supaya alarm yang tertinggal di laci notifikasi dari
/// sesi lain tidak membuka konfirmasi untuk sesi yang sedang berjalan.
@immutable
class AlarmTitik {
  const AlarmTitik({required this.sesiId, required this.index});

  final String sesiId;
  final int index;

  String keMuatan() => 'alarm:$sesiId:$index';

  static AlarmTitik? dariMuatan(String? muatan) {
    if (muatan == null || !muatan.startsWith('alarm:')) return null;
    final bagian = muatan.split(':');
    if (bagian.length != 3) return null;
    final index = int.tryParse(bagian[2]);
    if (index == null || bagian[1].isEmpty) return null;
    return AlarmTitik(sesiId: bagian[1], index: index);
  }

  @override
  bool operator ==(Object other) =>
      other is AlarmTitik && other.sesiId == sesiId && other.index == index;

  @override
  int get hashCode => Object.hash(sesiId, index);
}

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
  ///
  /// **Kecuali alarm yang sedang berbunyi** untuk titik yang masih kosong dan
  /// jendelanya masih terbuka. Penjadwalan ulang ini dipicu setiap kali jam
  /// tersambung, dan tersambung bukan konfirmasi: jam yang baru dinyalakan
  /// tidak boleh membungkam alarm yang menyuruh memakainya.
  Future<void> jadwalkan({
    required String sesiId,
    required DateTime t0,
    required List<TitikJadwal> titik,
    required DateTime sekarang,
  });

  Future<void> batalkanSemua();

  /// Membungkam alarm satu titik — hanya dipanggil dari konfirmasi pengguna.
  Future<void> hentikanAlarm(int index);

  /// Alarm yang diketuk selama aplikasi hidup.
  Stream<AlarmTitik> get alarmDiketuk;

  /// Alarm yang meluncurkan aplikasi dari keadaan mati, sekali saja.
  Future<AlarmTitik?> ambilAlarmPeluncuran();
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
    required String sesiId,
    required DateTime t0,
    required List<TitikJadwal> titik,
    required DateTime sekarang,
  }) async {}

  @override
  Future<void> batalkanSemua() async {}

  @override
  Future<void> hentikanAlarm(int index) async {}

  @override
  Stream<AlarmTitik> get alarmDiketuk => const Stream.empty();

  @override
  Future<AlarmTitik?> ambilAlarmPeluncuran() async => null;
}

class PengingatLokal implements PengingatTitikUkur {
  PengingatLokal({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _persiapan;
  bool _peluncuranDiambil = false;
  final _diketuk = StreamController<AlarmTitik>.broadcast();

  /// Berapa lama sebelum jendela terbuka pengingat pertama berbunyi.
  static const Duration ancang = Duration(minutes: 5);

  static const kanalAlarm = 'titik_ukur_alarm';
  static const _kanalSiapkan = 'titik_ukur';

  static int idSiapkan(int index) => index * 2;
  static int idAlarm(int index) => index * 2 + 1;

  /// `FLAG_INSISTENT` Android: suaranya diulang sampai notifikasinya dibuang.
  static const _flagInsistent = 4;

  static const _detailSiapkan = NotificationDetails(
    android: AndroidNotificationDetails(
      _kanalSiapkan,
      'Pengingat Pengukuran',
      channelDescription:
          'Mengingatkan kapan harus menyalakan jam dan mengambil pengukuran '
          'sesi makan.',
      importance: Importance.max,
      priority: Priority.high,
    ),
  );

  /// Detail alarm. **Kanalnya baru, bukan `titik_ukur` yang diubah**: Android
  /// membekukan suara dan kepentingan sebuah kanal begitu ia dibuat, jadi
  /// mengubah detail kanal lama tidak berpengaruh apa pun di ponsel yang
  /// sudah pernah menerima pengingat.
  ///
  /// [lebar] adalah lebar jendela titiknya: setelah jendela tertutup titik itu
  /// sudah terlewat, dan alarm yang terus berbunyi untuk sesuatu yang tidak
  /// bisa lagi dikerjakan hanya mengajari orang untuk mematikan suara.
  static NotificationDetails _detailAlarm(Duration lebar) =>
      NotificationDetails(
        android: AndroidNotificationDetails(
          kanalAlarm,
          'Alarm Pengukuran',
          channelDescription:
              'Berbunyi terus saat waktunya mengukur, sampai dikonfirmasi di '
              'aplikasi bahwa jam sudah dipakai.',
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          // Aliran alarm, bukan notifikasi: tetap terdengar walau suara
          // notifikasi ponsel dimatikan.
          audioAttributesUsage: AudioAttributesUsage.alarm,
          sound: const UriAndroidNotificationSound(
            'content://settings/system/alarm_alert',
          ),
          vibrationPattern: Int64List.fromList([0, 800, 600, 800]),
          additionalFlags: Int32List.fromList([_flagInsistent]),
          // Tidak bisa digeser hilang dan tidak hilang saat diketuk: yang
          // mengakhirinya adalah tombol konfirmasi di aplikasi.
          ongoing: true,
          autoCancel: false,
          timeoutAfter: lebar.inMilliseconds,
        ),
      );

  @override
  Stream<AlarmTitik> get alarmDiketuk => _diketuk.stream;

  @override
  Future<void> siapkan() {
    // Satu persiapan untuk semua pemanggil yang datang bersamaan — dua
    // `initialize` berarti dua dialog izin.
    return _persiapan ??= _siapkan().catchError((Object e) {
      _persiapan = null;
      throw e;
    });
  }

  Future<void> _siapkan() async {
    tzdata.initializeTimeZones();
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveNotificationResponse: (respons) {
        final alarm = AlarmTitik.dariMuatan(respons.payload);
        if (alarm != null) _diketuk.add(alarm);
      },
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
  }

  @override
  Future<AlarmTitik?> ambilAlarmPeluncuran() async {
    if (_peluncuranDiambil) return null;
    _peluncuranDiambil = true;
    try {
      await siapkan();
      final rincian = await _plugin.getNotificationAppLaunchDetails();
      if (rincian?.didNotificationLaunchApp != true) return null;
      return AlarmTitik.dariMuatan(rincian!.notificationResponse?.payload);
    } catch (e) {
      debugPrint('Alarm peluncuran gagal dibaca: $e');
      return null;
    }
  }

  @override
  Future<void> jadwalkan({
    required String sesiId,
    required DateTime t0,
    required List<TitikJadwal> titik,
    required DateTime sekarang,
  }) async {
    try {
      await siapkan();
      await _batalkanKecuali(
        await _alarmYangMasihBerlaku(t0: t0, titik: titik, sekarang: sekarang),
      );

      for (final t in titik) {
        if (!t.berjendela) continue;
        final jatuhTempo = t0.add(Duration(seconds: t.jendelaAwal!));

        await _satu(
          id: idSiapkan(t.index),
          kapan: jatuhTempo.subtract(ancang),
          sekarang: sekarang,
          judul: 'Siapkan jam — ${t.label}',
          isi:
              'Pengukuran ${t.label} sebentar lagi. Nyalakan jam dan pakai di '
              'pergelangan.',
          detail: _detailSiapkan,
        );
        await _satu(
          id: idAlarm(t.index),
          kapan: jatuhTempo,
          sekarang: sekarang,
          judul: 'Saatnya pengukuran ${t.label}',
          isi:
              'Pakai jam di pergelangan, lalu buka AsaWatch dan tekan '
              '"Oke, Jam Sudah Dipakai".',
          detail: _detailAlarm(
            Duration(seconds: t.jendelaAkhir! - t.jendelaAwal!),
          ),
          muatan: AlarmTitik(sesiId: sesiId, index: t.index).keMuatan(),
        );
      }
    } catch (e) {
      // Notifikasi yang gagal dijadwalkan **tidak** menggagalkan sesi. Kedua
      // tombolnya tetap bekerja dan layar sesi tetap menunjukkan hitung
      // mundurnya; yang hilang hanyalah pengingat saat aplikasi tertutup.
      debugPrint('Pengingat titik ukur gagal dijadwalkan: $e');
    }
  }

  /// Id alarm yang sedang berbunyi untuk titik yang masih kosong dan masih
  /// dalam jendelanya — yang tidak boleh ikut terhapus oleh penjadwalan ulang.
  Future<Set<int>> _alarmYangMasihBerlaku({
    required DateTime t0,
    required List<TitikJadwal> titik,
    required DateTime sekarang,
  }) async {
    final aktif = {
      for (final n in await _plugin.getActiveNotifications())
        if (n.channelId == kanalAlarm && n.id != null) n.id!,
    };
    return {
      for (final t in titik)
        if (t.berjendela &&
            aktif.contains(idAlarm(t.index)) &&
            !sekarang.isBefore(t0.add(Duration(seconds: t.jendelaAwal!))) &&
            sekarang.isBefore(t0.add(Duration(seconds: t.jendelaAkhir!))))
          idAlarm(t.index),
    };
  }

  /// Menghapus semua pengingat milik layanan ini, kecuali [tetap].
  ///
  /// Bukan `cancelAll`, yang juga akan membungkam alarm yang sedang berbunyi.
  /// Yang terjadwal dihapus semuanya (hanya layanan ini yang menjadwalkan);
  /// yang sedang tampil hanya yang berasal dari kedua kanalnya.
  Future<void> _batalkanKecuali(Set<int> tetap) async {
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (!tetap.contains(p.id)) await _plugin.cancel(id: p.id);
    }
    for (final n in await _plugin.getActiveNotifications()) {
      final id = n.id;
      if (id == null || tetap.contains(id)) continue;
      if (n.channelId == kanalAlarm || n.channelId == _kanalSiapkan) {
        await _plugin.cancel(id: id);
      }
    }
  }

  Future<void> _satu({
    required int id,
    required DateTime kapan,
    required DateTime sekarang,
    required String judul,
    required String isi,
    required NotificationDetails detail,
    String? muatan,
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
      notificationDetails: detail,
      payload: muatan,
      // `Timer` mati bersama prosesnya, dan proses Flutter dibunuh Doze jauh
      // sebelum dua jam berlalu. Penjadwalan tingkat sistem adalah satu-satunya
      // yang bertahan sampai titiknya jatuh tempo.
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
    );
  }

  @override
  Future<void> hentikanAlarm(int index) async {
    try {
      await siapkan();
      await _plugin.cancel(id: idAlarm(index));
    } catch (e) {
      debugPrint('Alarm titik ukur gagal dihentikan: $e');
    }
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
