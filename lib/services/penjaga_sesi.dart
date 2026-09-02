import 'package:flutter/material.dart';

import '../repositories/sesi_login_repository.dart';

/// Satu tempat yang memutuskan apa yang terjadi ketika server menolak token.
///
/// Sebelum ini, 401 hanya membuat permintaan yang bersangkutan gagal: unggahan
/// sesi berhenti diam-diam, profil tidak pernah tersegarkan, dan aplikasi tetap
/// menampilkan dirinya sebagai "sudah masuk" — sampai 30 hari kemudian saat
/// tokennya kedaluwarsa menurut jam ponsel. Tidak ada satu pun gejala yang bisa
/// ditindaklanjuti pengguna, karena tidak ada satu pun yang mengatakan bahwa ia
/// sebenarnya sudah tidak masuk.
///
/// Yang **tidak** boleh sampai ke sini: kredensial salah pada layar masuk. Itu
/// juga 401 (atau 422, tergantung backend), tetapi artinya "yang Anda ketik
/// salah", bukan "sesi Anda berakhir" — dan melempar orang ke halaman sambutan
/// karena salah ketik sandi akan terasa seperti aplikasi yang rusak. Karena itu
/// penjaga ini hanya dipasang pada layanan yang memakai token
/// ([ProfilServerService], [SesiServerService]), tidak pada `AuthService.masuk`.
class PenjagaSesi {
  PenjagaSesi({
    required this.sesiLogin,
    required this.navigatorKey,
    this.messengerKey,
  });

  final SesiLoginRepository sesiLogin;
  final GlobalKey<NavigatorState> navigatorKey;

  /// Untuk mengatakan **kenapa** halaman sambutan tiba-tiba muncul. Tanpa
  /// kalimat itu, pengguna hanya melihat dirinya terlempar keluar tanpa sebab.
  final GlobalKey<ScaffoldMessengerState>? messengerKey;

  /// Menahan agar sepuluh permintaan yang ditolak bersamaan — yang normal,
  /// karena seluruh riwayat dikirim ulang sekaligus — tidak menghasilkan
  /// sepuluh kali keluar dan sepuluh kalimat yang sama.
  bool _sedangKeluar = false;

  Future<void> tokenDitolak() async {
    if (_sedangKeluar) return;
    _sedangKeluar = true;
    try {
      await sesiLogin.hapus();

      final navigator = navigatorKey.currentState;
      // Aplikasi mungkin sedang di latar belakang, atau belum punya Navigator
      // sama sekali (permintaan pertama berjalan sebelum frame pertama). Token
      // sudah telanjur dihapus, jadi pembukaan berikutnya tetap mendarat di
      // halaman sambutan — hanya kalimatnya yang tidak sempat tampil.
      if (navigator == null) return;

      messengerKey?.currentState
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text('Sesi Anda sudah berakhir. Silakan masuk lagi.'),
            backgroundColor: Color(0xFF1E3A34),
          ),
        );
      navigator.pushNamedAndRemoveUntil('/welcome', (rute) => false);
    } finally {
      _sedangKeluar = false;
    }
  }
}
