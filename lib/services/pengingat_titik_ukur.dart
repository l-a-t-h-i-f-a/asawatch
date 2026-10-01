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

  /// Membunyikan alarm satu titik **sekarang juga**, dari aplikasi yang sedang
  /// hidup.
  ///
  /// **Ini jalur utama; jadwal sistem di [jadwalkan] hanya cadangan.** Selama
  /// sesi berjalan, foreground service (`LayananLatar`, dengan wakelock)
  /// menjaga proses tetap hidup, dan controller bangun tepat saat jendela
  /// terbuka. Menampilkan notifikasi dari proses yang hidup terbukti bekerja
  /// di HyperOS, sedangkan alarm `AlarmManager` di sana bisa ditahan tanpa
  /// gejala apa pun — dan itu yang terjadi di ponsel uji. Jadwal sistem tetap
  /// dipasang untuk proses yang benar-benar mati.
  ///
  /// [sisaJendela] menjadi batas bunyinya: setelah jendela tertutup titik itu
  /// sudah terlewat.
  Future<void> bunyikanSekarang({
    required String sesiId,
    required TitikJadwal titik,
    required Duration sisaJendela,
  });

  /// Membungkam alarm satu titik — hanya dipanggil dari konfirmasi pengguna.
  Future<void> hentikanAlarm(int index);

  /// Alarm yang diketuk selama aplikasi hidup.
  Stream<AlarmTitik> get alarmDiketuk;

  /// Alarm yang meluncurkan aplikasi dari keadaan mati, sekali saja.
  Future<AlarmTitik?> ambilAlarmPeluncuran();

  /// **Alat uji, hanya untuk build debug**: menampilkan alarm sekarang juga,
  /// tanpa menunggu jadwal sesi. Mengembalikan laporan singkat — izin, dan
  /// galat bila tampilnya gagal — karena kegagalan menampilkan notifikasi
  /// tidak bergejala apa pun di layar.
  ///
  /// [suaraAlarm] false memakai kanal uji tersendiri dengan suara notifikasi
  /// bawaan, untuk memisahkan "nada alarm yang ditolak ponsel" dari "notifikasi
  /// yang tidak tampil sama sekali".
  Future<String> ujiAlarm({required bool suaraAlarm});

  /// Alat uji debug: menjadwalkan alarm [jeda] dari sekarang lewat jalur yang
  /// sama dengan alarm sesi (`zonedSchedule`), supaya alarm yang berbunyi
  /// saat aplikasi di latar belakang bisa diperiksa tanpa menjalankan sesi.
  Future<String> ujiAlarmTerjadwal(Duration jeda);
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
  Future<void> bunyikanSekarang({
    required String sesiId,
    required TitikJadwal titik,
    required Duration sisaJendela,
  }) async {}

  @override
  Future<void> hentikanAlarm(int index) async {}

  @override
  Stream<AlarmTitik> get alarmDiketuk => const Stream.empty();

  @override
  Future<AlarmTitik?> ambilAlarmPeluncuran() async => null;

  @override
  Future<String> ujiAlarm({required bool suaraAlarm}) async =>
      'Pengingat dimatikan di build ini.';

  @override
  Future<String> ujiAlarmTerjadwal(Duration jeda) async =>
      'Pengingat dimatikan di build ini.';
}

class PengingatLokal implements PengingatTitikUkur {
  PengingatLokal({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  Future<void>? _persiapan;
  bool _peluncuranDiambil = false;

  /// Penjadwalan dijalankan berurutan, tidak pernah bertumpuk. Pemanggilnya
  /// dipicu setiap paket Status jam — dua detik sekali selama jam mengukur —
  /// dan dua penjadwalan yang saling menyela bisa membaca daftar terjadwal
  /// sebelum yang lain selesai menulisnya, lalu menghapus alarm yang baru
  /// saja dijadwalkan.
  Future<void> _antrean = Future.value();

  /// Penjadwalan terakhir yang berhasil. Yang sama persis tidak diulang:
  /// menghapus dan menjadwalkan ulang alarm yang sama setiap dua detik tidak
  /// mengubah apa pun selain membuka celah di detik alarm itu berbunyi.
  String? _jadwalTerakhir;
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
  }) {
    final jadwal =
        '$sesiId|${t0.toIso8601String()}|${titik.map((t) => t.index).join(',')}';
    return _antrean = _antrean.then((_) async {
      if (jadwal == _jadwalTerakhir) return;
      if (await _jadwalkanSekali(
        sesiId: sesiId,
        t0: t0,
        titik: titik,
        sekarang: sekarang,
      )) {
        _jadwalTerakhir = jadwal;
      }
    });
  }

  Future<bool> _jadwalkanSekali({
    required String sesiId,
    required DateTime t0,
    required List<TitikJadwal> titik,
    required DateTime sekarang,
  }) async {
    try {
      await siapkan();
      final tetap = await _alarmYangMasihBerlaku(
        t0: t0,
        titik: titik,
        sekarang: sekarang,
      );
      await _batalkanKecuali(tetap);

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
        // Yang dipertahankan tidak dijadwalkan ulang: ia sudah ada, entah
        // sedang berbunyi atau tinggal beberapa milidetik lagi.
        if (tetap.contains(idAlarm(t.index))) {
          debugPrint('Alarm ${t.label} dipertahankan (sudah ada).');
          continue;
        }
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
      return true;
    } catch (e) {
      // Notifikasi yang gagal dijadwalkan **tidak** menggagalkan sesi. Kedua
      // tombolnya tetap bekerja dan layar sesi tetap menunjukkan hitung
      // mundurnya; yang hilang hanyalah pengingat saat aplikasi tertutup.
      debugPrint('Pengingat titik ukur gagal dijadwalkan: $e');
      return false;
    }
  }

  /// Id alarm untuk titik yang masih kosong dan **jendelanya sudah terbuka**,
  /// yang masih ada — sedang berbunyi, atau masih terjadwal — dan karena itu
  /// tidak boleh ikut terhapus oleh penjadwalan ulang.
  ///
  /// **Yang masih terjadwal ikut dihitung, dan itu bukan kelengkapan.**
  /// Penjadwalan ulang yang paling pasti terjadi justru jatuh tepat pada detik
  /// alarm itu sendiri: `_armTitikBerikutnya` dibangunkan saat jendela terbuka
  /// untuk memulai pengukuran otomatis, dan alarm dijadwalkan pada detik yang
  /// sama. Bila yang dipertahankan hanya yang sudah tampil, alarm yang tinggal
  /// beberapa milidetik lagi dihapus, lalu tidak dijadwalkan ulang karena
  /// waktunya "sudah lewat" — dan yang terlihat di ponsel hanya jam yang
  /// tiba-tiba mengukur, tanpa satu bunyi pun.
  Future<Set<int>> _alarmYangMasihBerlaku({
    required DateTime t0,
    required List<TitikJadwal> titik,
    required DateTime sekarang,
  }) async {
    final ada = {
      for (final p in await _plugin.pendingNotificationRequests()) p.id,
      for (final n in await _plugin.getActiveNotifications())
        if (n.channelId == kanalAlarm && n.id != null) n.id!,
    };
    return {
      for (final t in titik)
        if (t.berjendela &&
            ada.contains(idAlarm(t.index)) &&
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
    if (!kapan.isAfter(sekarang)) {
      debugPrint('Pengingat $id dilewati: $kapan sudah lewat.');
      return;
    }
    debugPrint('Pengingat $id dijadwalkan pada $kapan.');

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
  Future<void> bunyikanSekarang({
    required String sesiId,
    required TitikJadwal titik,
    required Duration sisaJendela,
  }) async {
    try {
      await siapkan();
      // Cadangan yang terjadwal untuk detik yang sama dibuang dulu, supaya ia
      // tidak menyusul beberapa milidetik kemudian dan membunyikan ulang
      // notifikasi yang sama.
      await _plugin.cancel(id: idAlarm(titik.index));
      await _plugin.show(
        id: idAlarm(titik.index),
        title: 'Saatnya pengukuran ${titik.label}',
        body:
            'Pakai jam di pergelangan, lalu buka AsaWatch dan tekan '
            '"Oke, Jam Sudah Dipakai".',
        notificationDetails: _detailAlarm(sisaJendela),
        payload: AlarmTitik(sesiId: sesiId, index: titik.index).keMuatan(),
      );
      debugPrint('Alarm ${titik.label} dibunyikan dari aplikasi.');
    } catch (e) {
      // Cadangan terjadwal masih ada; yang gagal di sini hanya jalur utamanya.
      debugPrint('Alarm ${titik.label} gagal dibunyikan: $e');
    }
  }

  @override
  Future<String> ujiAlarm({required bool suaraAlarm}) async {
    final laporan = <String>[];
    try {
      await siapkan();
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      laporan.add(
        'notifikasi diizinkan: ${await android?.areNotificationsEnabled()}',
      );
      laporan.add(
        'alarm tepat diizinkan: ${await android?.canScheduleExactNotifications()}',
      );
      await _plugin.show(
        id: 999,
        title: 'Tes alarm AsaWatch',
        body: suaraAlarm
            ? 'Nada alarm, berulang. Geser laci notifikasi untuk membuangnya.'
            : 'Suara notifikasi bawaan, kanal uji.',
        notificationDetails: suaraAlarm
            ? _detailAlarm(const Duration(seconds: 30))
            : NotificationDetails(
                android: AndroidNotificationDetails(
                  'titik_ukur_alarm_uji',
                  'Uji Alarm (debug)',
                  importance: Importance.max,
                  priority: Priority.max,
                  category: AndroidNotificationCategory.alarm,
                  audioAttributesUsage: AudioAttributesUsage.alarm,
                  additionalFlags: Int32List.fromList([_flagInsistent]),
                  timeoutAfter: 30000,
                ),
              ),
      );
      laporan.add('tampil: berhasil dikirim ke sistem');
    } catch (e) {
      laporan.add('GAGAL: $e');
    }
    final teks = laporan.join(' · ');
    debugPrint('Uji alarm (suaraAlarm=$suaraAlarm): $teks');
    return teks;
  }

  @override
  Future<String> ujiAlarmTerjadwal(Duration jeda) async {
    try {
      await siapkan();
      final kapan = DateTime.now().add(jeda);
      await _plugin.zonedSchedule(
        id: 998,
        title: 'Tes alarm terjadwal AsaWatch',
        body: 'Alarm ini dijadwalkan ${jeda.inSeconds} detik sebelumnya.',
        scheduledDate: tz.TZDateTime.from(kapan, tz.local),
        notificationDetails: _detailAlarm(const Duration(seconds: 60)),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
      final teks =
          'Alarm uji dijadwalkan pukul '
          '${kapan.hour.toString().padLeft(2, '0')}.'
          '${kapan.minute.toString().padLeft(2, '0')}.'
          '${kapan.second.toString().padLeft(2, '0')}. Tutup aplikasinya '
          'sekarang.';
      debugPrint('Uji alarm terjadwal: $teks');
      return teks;
    } catch (e) {
      debugPrint('Uji alarm terjadwal GAGAL: $e');
      return 'GAGAL: $e';
    }
  }

  @override
  Future<void> hentikanAlarm(int index) async {
    try {
      await siapkan();
      await _plugin.cancel(id: idAlarm(index));
      debugPrint('Alarm titik $index dihentikan (dikonfirmasi).');
    } catch (e) {
      debugPrint('Alarm titik ukur gagal dihentikan: $e');
    }
  }

  @override
  Future<void> batalkanSemua() async {
    _jadwalTerakhir = null;
    try {
      await siapkan();
      await _plugin.cancelAll();
    } catch (e) {
      debugPrint('Pengingat titik ukur gagal dibatalkan: $e');
    }
  }
}
