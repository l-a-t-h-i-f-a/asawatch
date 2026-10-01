// PengingatLokal di atas plugin palsu: yang dipatok adalah alarm yang tidak
// boleh hilang oleh penjadwalan ulang — terutama yang jatuh tepat pada detik
// alarm itu sendiri, saat pengukuran otomatis dibangunkan.

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asawatch/models/jadwal_sesi.dart';
import 'package:asawatch/services/pengingat_titik_ukur.dart';

/// Hanya bagian plugin yang dipakai `PengingatLokal`; sisanya tidak dipanggil.
class _PluginPalsu implements FlutterLocalNotificationsPlugin {
  final Map<int, String?> terjadwal = {};
  final Map<int, String> tampil = {}; // id → kanal
  final List<int> dijadwalkan = [];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  T? resolvePlatformSpecificImplementation<
    T extends FlutterLocalNotificationsPlatform
  >() => null;

  @override
  Future<void> zonedSchedule({
    required int id,
    required dynamic scheduledDate,
    required NotificationDetails notificationDetails,
    required AndroidScheduleMode androidScheduleMode,
    String? title,
    String? body,
    String? payload,
    DateTimeComponents? matchDateTimeComponents,
  }) async {
    terjadwal[id] = payload;
    dijadwalkan.add(id);
  }

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => [
    for (final e in terjadwal.entries)
      PendingNotificationRequest(e.key, null, null, e.value),
  ];

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async => [
    for (final e in tampil.entries)
      ActiveNotification(id: e.key, channelId: e.value),
  ];

  @override
  Future<void> cancel({required int id, String? tag}) async {
    terjadwal.remove(id);
    tampil.remove(id);
  }

  @override
  Future<void> cancelAll() async {
    terjadwal.clear();
    tampil.clear();
  }

  /// Setiap `show` adalah bunyi baru — termasuk yang memasang ulang id yang
  /// sama, yang di Android dibisukan bila datang dalam satu detik.
  final List<int> ditampilkan = [];

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async {
    terjadwal.remove(id);
    tampil[id] = PengingatLokal.kanalAlarm;
    ditampilkan.add(id);
  }

  /// Sistem membunyikan yang terjadwal.
  void bunyikan(int id) {
    terjadwal.remove(id);
    tampil[id] = PengingatLokal.kanalAlarm;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  // Jendela `+1 jam` pada faktor 12: terbuka di detik 275, tutup di 350.
  const titik = TitikJadwal(
    index: 2,
    detikNominal: 300,
    label: '+1 jam',
    jendelaAwal: 275,
    jendelaAkhir: 350,
  );
  const titikBerikut = TitikJadwal(
    index: 3,
    detikNominal: 600,
    label: '+2 jam',
    jendelaAwal: 550,
    jendelaAkhir: 750,
  );
  final t0 = DateTime(2026, 10, 1, 10);
  DateTime pada(int detik) => t0.add(Duration(seconds: detik));
  final idAlarm = PengingatLokal.idAlarm(2);

  late _PluginPalsu plugin;
  late PengingatLokal pengingat;

  Future<void> jadwalkan(
    int detik, {
    List<TitikJadwal> daftar = const [titik],
  }) => pengingat.jadwalkan(
    sesiId: 'sesi-1',
    t0: t0,
    titik: daftar,
    sekarang: pada(detik),
  );

  setUp(() {
    plugin = _PluginPalsu();
    pengingat = PengingatLokal(plugin: plugin);
  });

  test('alarm dijadwalkan pada detik jendela terbuka, membawa sesi dan '
      'titiknya', () async {
    await jadwalkan(10);
    expect(plugin.terjadwal[idAlarm], 'alarm:sesi-1:2');
  });

  test('penjadwalan ulang yang sama persis tidak menyentuh apa pun', () async {
    await jadwalkan(10);
    plugin.dijadwalkan.clear();

    // Paket Status datang dua detik sekali selama jam mengukur.
    await jadwalkan(12);
    await jadwalkan(14);

    expect(plugin.dijadwalkan, isEmpty);
    expect(plugin.terjadwal.containsKey(idAlarm), isTrue);
  });

  test('penjadwalan ulang tepat pada detik alarm tidak menghapusnya', () async {
    await jadwalkan(10, daftar: const [titik, titikBerikut]);
    plugin.dijadwalkan.clear();

    // `_armTitikBerikutnya` dibangunkan pada detik yang sama dengan alarm,
    // sementara sistem belum sempat membunyikannya — dan daftarnya berubah,
    // sehingga penjadwalan ini benar-benar dijalankan.
    await jadwalkan(275);

    expect(plugin.terjadwal.containsKey(idAlarm), isTrue);
    expect(plugin.dijadwalkan, isNot(contains(idAlarm)));
  });

  test('alarm yang sedang berbunyi tidak dibungkam oleh penjadwalan ulang '
      '(jam yang tersambung bukan konfirmasi)', () async {
    await jadwalkan(10, daftar: const [titik, titikBerikut]);
    plugin.bunyikan(idAlarm);

    await jadwalkan(290);

    expect(plugin.tampil.containsKey(idAlarm), isTrue);
  });

  test('alarm yang sudah dikonfirmasi tidak dibunyikan lagi', () async {
    await jadwalkan(10);
    plugin.bunyikan(idAlarm);
    await pengingat.hentikanAlarm(2);

    await jadwalkan(300);

    expect(plugin.tampil, isEmpty);
    expect(plugin.terjadwal.containsKey(idAlarm), isFalse);
  });

  group('bunyikanSekarang', () {
    Future<void> bunyikanDariAplikasi() => pengingat.bunyikanSekarang(
      sesiId: 'sesi-1',
      titik: titik,
      sisaJendela: const Duration(seconds: 75),
    );

    test('aplikasi lebih dulu: cadangan terjadwal dibuang, alarm tampil '
        'sekali', () async {
      await jadwalkan(10);

      await bunyikanDariAplikasi();

      expect(plugin.terjadwal.containsKey(idAlarm), isFalse);
      expect(plugin.ditampilkan, [idAlarm]);
    });

    test('cadangan sistem lebih dulu: alarm yang sedang berbunyi tidak '
        'dibatalkan lalu dipasang ulang (dibisukan Android)', () async {
      await jadwalkan(10);
      plugin.bunyikan(idAlarm);

      await bunyikanDariAplikasi();

      expect(plugin.tampil.containsKey(idAlarm), isTrue);
      expect(plugin.ditampilkan, isEmpty);
    });
  });

  test('titik yang sudah terisi kehilangan alarmnya', () async {
    await jadwalkan(10);
    plugin.bunyikan(idAlarm);

    await jadwalkan(300, daftar: const []);

    expect(plugin.tampil, isEmpty);
  });
}
