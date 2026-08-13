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
      'Bluetooth ponsel sedang mati. Nyalakan Bluetooth, lalu pindai lagi.',
  };

  /// Hanya penolakan permanen yang butuh tombol ke Pengaturan; sisanya cukup
  /// "coba lagi", dan tombol Pengaturan pada kasus itu justru menyesatkan.
  bool get butuhPengaturan => this == HasilIzinBle.ditolakPermanen;
}

/// Meminta izin yang dibutuhkan pemindaian, sesuai versi platformnya.
abstract class IzinBle {
  Future<HasilIzinBle> minta();

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
  Future<bool> bukaPengaturan() => openAppSettings();
}

/// Izin yang selalu diberikan — untuk test dan untuk jalur jam palsu, yang tidak
/// menyentuh radio sama sekali.
class IzinBleSelaluBoleh implements IzinBle {
  const IzinBleSelaluBoleh();

  @override
  Future<HasilIzinBle> minta() async => HasilIzinBle.diberikan;

  @override
  Future<bool> bukaPengaturan() async => false;
}
