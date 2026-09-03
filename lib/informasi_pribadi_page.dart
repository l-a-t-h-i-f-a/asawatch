import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'repositories/profil_repository.dart';
import 'utils/format_waktu.dart';

class InformasiPribadiPage extends StatefulWidget {
  const InformasiPribadiPage({
    super.key,
    this.profil = const ProfilRepository(),
  });

  /// Pintu ke profil. Bawaannya bentuk **tanpa server**, jadi halaman ini tetap
  /// bekerja apa adanya di test dan saat aplikasi dipakai tanpa akun;
  /// `MyHomePage` yang menyuntikkan bentuk yang tersambung.
  final ProfilRepository profil;

  @override
  State<InformasiPribadiPage> createState() => _InformasiPribadiPageState();
}

class _InformasiPribadiPageState extends State<InformasiPribadiPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _emailController = TextEditingController();

  // null berarti belum dipilih; string kosong tidak bisa dipakai karena
  // DropdownButtonFormField menuntut nilainya ada di dalam daftar itemnya.
  String? _selectedGender;
  String? _selectedBloodType;

  /// Tanggal lahir disimpan sebagai tanggal, bukan teks yang diketik.
  ///
  /// Dulu ia `TextFormField` bebas, sehingga "21 Mei 2004", "21/05/2004", dan
  /// "kemarin" sama-sama diterima — dan tidak satu pun bisa dipakai menghitung
  /// usia, yang justru satu-satunya alasan menanyakannya di aplikasi kesehatan.
  DateTime? _tanggalLahir;

  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    // Versi segar, bukan sekadar salinan lokal: halaman inilah tempat orang
    // datang untuk memastikan datanya benar, jadi di sinilah selisih dengan
    // server paling pantas diselesaikan.
    final profil = await widget.profil.muatSegar();
    if (!mounted) return;
    setState(() {
      _nameController.text = profil.nama;
      _tanggalLahir = DateTime.tryParse(profil.tanggalLahir);
      _selectedGender = profil.jenisKelamin.isEmpty
          ? null
          : profil.jenisKelamin;
      _heightController.text = _hanyaAngka(profil.tinggi);
      _weightController.text = _hanyaAngka(profil.berat);
      _selectedBloodType = profil.golonganDarah.isEmpty
          ? null
          : profil.golonganDarah;
      _emailController.text = profil.email;
      _isLoading = false;
    });
  }

  /// Membuang satuan dari nilai lama seperti "160 cm" → "160".
  ///
  /// Sebelum perubahan ini satuannya ikut diketik ke dalam field, sehingga yang
  /// tersimpan adalah teks. Sekarang satuan menjadi hiasan field dan yang
  /// disimpan hanya angkanya — bentuk yang bisa dihitung, bukan hanya
  /// ditampilkan.
  static String _hanyaAngka(String nilai) =>
      nilai.replaceAll(RegExp(r'[^0-9.]'), '');

  Future<StatusSimpanProfil> _saveData() async {
    final lahir = _tanggalLahir;
    return widget.profil.simpan(
      Profil(
        nama: _nameController.text.trim(),
        // ISO 8601, bukan "21 Mei 2004": yang disimpan harus bisa diurai
        // kembali. Tampilan berbahasa Indonesia dirakit saat menampilkan.
        tanggalLahir: lahir == null
            ? ''
            : '${lahir.year.toString().padLeft(4, '0')}-'
                  '${lahir.month.toString().padLeft(2, '0')}-'
                  '${lahir.day.toString().padLeft(2, '0')}',
        jenisKelamin: _selectedGender ?? '',
        tinggi: _heightController.text.trim(),
        berat: _weightController.text.trim(),
        golonganDarah: _selectedBloodType ?? '',
        email: _emailController.text.trim(),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFF1E3A34)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Informasi Pribadi',
          style: TextStyle(
            color: Color(0xFF1E3A34),
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: _isLoading
                ? null
                : () async {
                    if (_formKey.currentState!.validate()) {
                      final messenger = ScaffoldMessenger.of(context);
                      final navigator = Navigator.of(context);
                      setState(() {
                        _isLoading = true;
                      });
                      final status = await _saveData();
                      // Kalimatnya mengikuti apa yang benar-benar terjadi.
                      // "Berhasil disimpan" untuk sesuatu yang belum sampai ke
                      // server membuat orang mengira datanya sudah aman di
                      // akunnya, lalu kehilangannya saat ganti ponsel.
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text(
                            status == StatusSimpanProfil.tersinkron
                                ? 'Perubahan berhasil disimpan!'
                                : 'Tersimpan di ponsel ini. Akan disamakan '
                                      'dengan akun Anda saat ada koneksi.',
                          ),
                          backgroundColor: const Color(0xFF0EAD69),
                        ),
                      );
                      navigator.pop(true); // Return true to indicate saved data
                    }
                  },
            child: const Text(
              'Simpan',
              style: TextStyle(
                color: Color(0xFF0EAD69),
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _isLoading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EAD69)),
                ),
              )
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Profile Photo Stack
                        Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 100,
                              height: 100,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 12,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              // Foto orang asing dari Unsplash dihapus bersama sisa
                              // identitas demo (rencana-produksi.md §3.2). Ia juga tidak
                              // pernah termuat di rilis: izin INTERNET tidak dideklarasikan.
                              child: const CircleAvatar(
                                radius: 46,
                                backgroundColor: Color(0xFFE0F2F1),
                                child: Icon(
                                  Icons.person,
                                  color: Color(0xFF0EAD69),
                                  size: 46,
                                ),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Ubah foto profil belum tersedia.',
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                padding: const EdgeInsets.all(6),
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0EAD69),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.camera_alt_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Form Fields
                        _buildTextField(
                          label: 'Nama Lengkap',
                          controller: _nameController,
                          icon: Icons.person_outline_rounded,
                          capitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 16),

                        _buildDateField(),
                        const SizedBox(height: 16),

                        _buildDropdownField(
                          label: 'Jenis Kelamin',
                          value: _selectedGender,
                          items: ['Laki-laki', 'Perempuan'],
                          icon: Icons.wc_rounded,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedGender = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          label: 'Tinggi Badan',
                          controller: _heightController,
                          icon: Icons.straighten_rounded,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          formatters: [_formatterAngka],
                          suffix: 'cm',
                          validator: (nilai) =>
                              _validasiUkuran(nilai, 'Tinggi', 60, 250),
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          label: 'Berat Badan',
                          controller: _weightController,
                          icon: Icons.monitor_weight_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          formatters: [_formatterAngka],
                          suffix: 'kg',
                          validator: (nilai) =>
                              _validasiUkuran(nilai, 'Berat', 20, 300),
                        ),
                        const SizedBox(height: 16),

                        _buildDropdownField(
                          label: 'Golongan Darah',
                          value: _selectedBloodType,
                          items: ['A', 'B', 'AB', 'O'],
                          icon: Icons.bloodtype_outlined,
                          onChanged: (val) {
                            if (val != null) {
                              setState(() {
                                _selectedBloodType = val;
                              });
                            }
                          },
                        ),
                        const SizedBox(height: 16),

                        _buildTextField(
                          label: 'Email',
                          controller: _emailController,
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          // Autocorrect mengubah alamat email menjadi kata lain, dan
                          // huruf besar otomatis di awal adalah sumber galat klasik.
                          autocorrect: false,
                          capitalization: TextCapitalization.none,
                          validator: _validasiEmail,
                        ),
                        const SizedBox(height: 24),

                        // Personalize Info Card Banner
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE8F8F5),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: const Color(0xFFD0EBE0),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.shield_outlined,
                                color: Color(0xFF0EAD69),
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  'Lengkapi informasi untuk pengalaman yang lebih personal',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF1E3A34),
                                    fontWeight: FontWeight.bold,
                                    height: 1.3,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  /// Angka positif dengan paling banyak satu koma desimal.
  static final _formatterAngka = FilteringTextInputFormatter.allow(
    RegExp(r'^\d*\.?\d*'),
  );

  /// Semua field boleh dikosongkan.
  ///
  /// Sebelum A4 setiap field wajib diisi, dan itu tidak pernah terasa karena
  /// nilai demo sudah mengisi semuanya. Begitu identitas demo dihapus, aturan
  /// itu berubah menjadi jebakan: pengguna baru tidak bisa menyimpan namanya
  /// saja tanpa sekalian mengarang golongan darahnya. Yang divalidasi sekarang
  /// hanya **bentuknya**, dan hanya bila diisi.
  String? _validasiUkuran(String? nilai, String label, num min, num maks) {
    final teks = nilai?.trim() ?? '';
    if (teks.isEmpty) return null;

    final angka = double.tryParse(teks);
    if (angka == null) return '$label harus berupa angka';
    if (angka < min || angka > maks) return '$label wajar antara $min–$maks';
    return null;
  }

  String? _validasiEmail(String? nilai) {
    final teks = nilai?.trim() ?? '';
    if (teks.isEmpty) return null;
    // Sengaja longgar: memvalidasi email secara ketat lewat regex adalah
    // masalah yang tidak pernah selesai, dan yang benar-benar membuktikan
    // alamatnya sah hanyalah mengirim surat ke sana (Tahap D).
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(teks)) {
      return 'Format email belum benar';
    }
    return null;
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    List<TextInputFormatter>? formatters,
    String? suffix,
    String? Function(String?)? validator,
    TextCapitalization capitalization = TextCapitalization.sentences,
    bool autocorrect = true,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          inputFormatters: formatters,
          textCapitalization: capitalization,
          autocorrect: autocorrect,
          style: const TextStyle(
            color: Color(0xFF1E3A34),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          validator: validator,
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF6B807B), size: 20),
            // Satuan menjadi bagian field, bukan sesuatu yang ikut diketik.
            suffixText: suffix,
            suffixStyle: const TextStyle(
              color: Color(0xFF6B807B),
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF0EAD69),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE2EBE8),
                width: 1.5,
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  /// Tanggal lahir: dipilih, tidak diketik.
  ///
  /// `InkWell` di atas `InputDecorator` — bukan `TextFormField` yang dibuat
  /// `readOnly` — supaya papan ketik tidak pernah sempat muncul dan tidak ada
  /// kursor yang berkedip di field yang tidak bisa disunting.
  Widget _buildDateField() {
    final lahir = _tanggalLahir;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tanggal Lahir',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        const SizedBox(height: 6),
        InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _pilihTanggalLahir,
          child: InputDecorator(
            decoration: InputDecoration(
              prefixIcon: const Icon(
                Icons.calendar_month_outlined,
                color: Color(0xFF6B807B),
                size: 20,
              ),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: Color(0xFFE2EBE8),
                  width: 1.5,
                ),
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              lahir == null ? 'Belum dipilih' : formatTanggal(lahir),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: lahir == null
                    ? const Color(0xFF9CB1AC)
                    : const Color(0xFF1E3A34),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pilihTanggalLahir() async {
    final sekarang = DateTime.now();
    final pilihan = await showDatePicker(
      context: context,
      initialDate: _tanggalLahir ?? DateTime(sekarang.year - 25),
      // Batas atas hari ini: tanggal lahir di masa depan tidak pernah sah, dan
      // memblokirnya di pemilih lebih baik daripada menolaknya setelah diisi.
      firstDate: DateTime(sekarang.year - 120),
      lastDate: sekarang,
      helpText: 'Pilih tanggal lahir',
      cancelText: 'Batal',
      confirmText: 'Pilih',
    );

    if (pilihan == null) return;
    setState(() => _tanggalLahir = pilihan);
  }

  /// [value] boleh null — artinya belum dipilih.
  ///
  /// `DropdownButtonFormField` menuntut nilainya ada di dalam [items], jadi
  /// "belum diisi" tidak bisa diwakili string kosong: ia harus null, dengan
  /// [hint] sebagai gantinya.
  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required IconData icon,
    required ValueChanged<String?> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1E3A34),
          ),
        ),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          onChanged: onChanged,
          hint: const Text(
            'Belum dipilih',
            style: TextStyle(color: Color(0xFF9CB1AC), fontSize: 14),
          ),
          style: const TextStyle(
            color: Color(0xFF1E3A34),
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF6B807B),
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF6B807B), size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFF0EAD69),
                width: 1.5,
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: Color(0xFFE2EBE8),
                width: 1.5,
              ),
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(value: value, child: Text(value));
          }).toList(),
        ),
      ],
    );
  }
}
