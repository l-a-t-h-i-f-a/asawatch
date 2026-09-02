/// Izin yang dibutuhkan sebelum memindai jam — docs/rencana-produksi.md §4.4.
///
/// Dipisahkan dari [BleAsliService] karena izin adalah urusan platform, bukan
/// protokol: jam yang sama, kabel yang sama, tetapi Android 11 ke bawah menuntut
/// izin lokasi sementara Android 12 ke atas menuntut dua izin Bluetooth yang
/// sebelumnya tidak ada.
///
/// Dua aturan yang menjelaskan bentuk berkas ini:
///
/// 1. **Diminta di titik yang masuk akal**, yaitu saat pengguna menekan "Pindai
///    Perangkat" — bukan saat aplikasi dibuka. Dialog izin yang muncul sebelum
///    pengguna tahu untuk apa hampir selalu ditolak.
/// 2. **Penolakan permanen punya jalan keluarnya sendiri.** Menampilkan layar
///    pemindaian yang tidak akan pernah menemukan apa pun adalah kebohongan;
///    yang benar adalah mengatakannya dan menawarkan Pengaturan sistem.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

enum HasilIzinBle {
  /// Boleh memindai.
  diberikan,

  /// Ditolak sekali. Boleh diminta lagi nanti.
  ditolak,

  /// Ditolak permanen ("jangan tanya lagi") atau dibatasi kebijakan perangkat.
  /// Satu-satunya jalan keluarnya lewat Pengaturan sistem.
  ditolakPermanen,

  /// Izinnya ada, tetapi Bluetooth-nya sendiri mati.
  bluetoothMati,
}

extension PesanIzinBle on HasilIzinBle {
  /// Kalimat yang siap ditampilkan. Tidak ada satu pun yang menyebut nama izin
  /// Android — yang perlu diketahui pengguna adalah apa yang tidak bisa
  /// dilakukan aplikasi dan apa yang bisa ia lakukan sekarang.
  String? get pesan => switch (this) {
    HasilIzinBle.diberikan => null,
    HasilIzinBle.ditolak =>
      'AsaWatch perlu izin Bluetooth untuk menemukan jam. Coba lagi dan pilih '
          'Izinkan.',
    HasilIzinBle.ditolakPermanen =>
      'Izin Bluetooth ditolak permanen, jadi jam tidak bisa ditemukan. Buka '
          'Pengaturan aplikasi untuk mengizinkannya.',
    HasilIzinBle.bluetoothMati =>
      'Bluetooth ponsel sedang mati, jadi jam tidak bisa ditemukan. Nyalakan '
          'Bluetooth, lalu pindai lagi.',
  };

  /// Hanya penolakan permanen yang butuh tombol ke Pengaturan; sisanya cukup
  /// "coba lagi", dan tombol Pengaturan pada kasus itu justru menyesatkan.
  bool get butuhPengaturan => this == HasilIzinBle.ditolakPermanen;
}

/// Hasil permintaan menyalakan Bluetooth.
///
/// Bukan `bool`, dengan alasan yang sama seperti [HasilSambung] dan
/// [HasilMasuk]: tiap sebab menuntut hal yang berbeda dari halaman. Pengguna
/// yang menekan "Jangan" pada dialog sistem sudah tahu apa yang terjadi dan
/// tidak perlu dimarahi; perangkat yang tidak mendukungnya sama sekali harus
/// diberi tahu bahwa Pengaturan adalah satu-satunya jalan.
enum HasilNyalakanBluetooth {
  /// Radionya sudah menyala sekarang.
  menyala,

  /// Pengguna menolak dialog sistem, atau menutupnya tanpa menjawab.
  ditolakPengguna,

  /// Platformnya tidak mengizinkan aplikasi menyalakan radio sendiri — iOS
  /// tidak punya padanan `ACTION_REQUEST_ENABLE` dan tidak akan pernah punya.
  tidakDidukung,

  /// Permintaannya sampai, tetapi radionya tidak juga menyala.
  gagal,
}

extension PesanNyalakanBluetooth on HasilNyalakanBluetooth {
  String? get pesan => switch (this) {
    HasilNyalakanBluetooth.menyala => null,
    HasilNyalakanBluetooth.ditolakPengguna =>
      'Bluetooth masih mati. Nyalakan untuk mencari jam.',
    HasilNyalakanBluetooth.tidakDidukung =>
      'Bluetooth harus dinyalakan lewat Pengaturan ponsel.',
    HasilNyalakanBluetooth.gagal =>
      'Bluetooth gagal dinyalakan. Coba nyalakan lewat Pengaturan ponsel.',
  };
}

/// Meminta izin yang dibutuhkan pemindaian, sesuai versi platformnya.
abstract class IzinBle {
  Future<HasilIzinBle> minta();

  /// Apakah aplikasi boleh menawarkan tombol "Nyalakan Bluetooth" sama sekali.
  ///
  /// Android saja. Menawarkannya di tempat yang tidak bisa memenuhinya hanya
  /// memindahkan kebuntuan satu ketukan lebih jauh.
  bool get bisaMenyalakanBluetooth;

  /// Meminta sistem menyalakan Bluetooth.
  ///
  /// Bukan "menyalakan sendiri diam-diam": sejak Android 13 `enable()` dicabut,
  /// jadi yang terjadi adalah dialog sistem yang tetap dijawab pengguna. Yang
  /// dihemat adalah perjalanan ke Pengaturan dan kembali lagi — bukan
  /// persetujuannya, yang memang bukan milik aplikasi ini.
  Future<HasilNyalakanBluetooth> nyalakanBluetooth();

  /// Membuka halaman Pengaturan aplikasi. Dipakai hanya saat izinnya ditolak
  /// permanen.
  Future<bool> bukaPengaturan();
}

class IzinBlePermissionHandler implements IzinBle {
  const IzinBlePermissionHandler();

  @override
  Future<HasilIzinBle> minta() async {
    // iOS hanya punya satu izin Bluetooth dan tidak pernah memakai lokasi.
    final diminta = defaultTargetPlatform == TargetPlatform.android
        ? [
            Permission.bluetoothScan,
            Permission.bluetoothConnect,
            // Android 11 ke bawah menurunkan pemindaian BLE ke izin lokasi.
            // Pada Android 12+ permintaan ini selesai sendiri tanpa dialog,
            // karena manifest membatasinya dengan `maxSdkVersion="30"`.
            Permission.locationWhenInUse,
          ]
        : [Permission.bluetooth];

    final hasil = await diminta.request();

    // Lokasi tidak ikut memblokir: pada Android 12+ ia memang tidak diminta,
    // dan pemindaian sudah dideklarasikan `neverForLocation`.
    final wajib = defaultTargetPlatform == TargetPlatform.android
        ? [Permission.bluetoothScan, Permission.bluetoothConnect]
        : [Permission.bluetooth];

    for (final izin in wajib) {
      final status = hasil[izin];
      if (status == null || status.isGranted) continue;
      if (status.isPermanentlyDenied || status.isRestricted) {
        return HasilIzinBle.ditolakPermanen;
      }
      return HasilIzinBle.ditolak;
    }

    // Izin lengkap tetapi radionya mati adalah kegagalan yang sama sekali
    // berbeda, dan pesannya juga: yang perlu dilakukan pengguna adalah
    // menyalakan Bluetooth, bukan mengizinkan apa pun.
    if (!await FlutterBluePlus.isSupported) return HasilIzinBle.bluetoothMati;
    final keadaan = await FlutterBluePlus.adapterState.first;
    if (keadaan != BluetoothAdapterState.on) return HasilIzinBle.bluetoothMati;

    return HasilIzinBle.diberikan;
  }

  @override
  bool get bisaMenyalakanBluetooth =>
      defaultTargetPlatform == TargetPlatform.android;

  @override
  Future<HasilNyalakanBluetooth> nyalakanBluetooth() async {
    if (!bisaMenyalakanBluetooth) return HasilNyalakanBluetooth.tidakDidukung;
    try {
      // `turnOn()` menunggu sampai radionya benar-benar `on`, bukan sampai
      // dialognya dijawab — jadi begitu ini selesai, pemindaian boleh langsung
      // dimulai tanpa menunggu `adapterState` lagi.
      await FlutterBluePlus.turnOn();
      return HasilNyalakanBluetooth.menyala;
    } on FlutterBluePlusException catch (galat) {
      // Menolak dialog bukan kesalahan aplikasi dan kalimatnya pun berbeda.
      // Batas waktu (dialog yang tidak pernah dijawab) diperlakukan sama:
      // keduanya berakhir dengan radio yang masih mati atas kemauan pengguna.
      return galat.code == FbpErrorCode.userRejected.index ||
              galat.code == FbpErrorCode.timeout.index
          ? HasilNyalakanBluetooth.ditolakPengguna
          : HasilNyalakanBluetooth.gagal;
    } catch (_) {
      return HasilNyalakanBluetooth.gagal;
    }
  }

  @override
  Future<bool> bukaPengaturan() => openAppSettings();
}

/// Izin yang selalu diberikan — untuk test dan untuk jalur jam palsu, yang tidak
/// menyentuh radio sama sekali.
class IzinBleSelaluBoleh implements IzinBle {
  const IzinBleSelaluBoleh();

  @override
  Future<HasilIzinBle> minta() async => HasilIzinBle.diberikan;

  @override
  bool get bisaMenyalakanBluetooth => false;

  @override
  Future<HasilNyalakanBluetooth> nyalakanBluetooth() async =>
      HasilNyalakanBluetooth.menyala;

  @override
  Future<bool> bukaPengaturan() async => false;
}
