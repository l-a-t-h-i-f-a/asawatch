import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class InformasiPribadiPage extends StatefulWidget {
  const InformasiPribadiPage({super.key});

  @override
  State<InformasiPribadiPage> createState() => _InformasiPribadiPageState();
}

class _InformasiPribadiPageState extends State<InformasiPribadiPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _dobController = TextEditingController();
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  
  String _selectedGender = 'Perempuan';
  String _selectedBloodType = 'B';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedData();
  }

  Future<void> _loadSavedData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nameController.text = prefs.getString('user_name') ?? 'Lathifa';
      _dobController.text = prefs.getString('user_dob') ?? '21 Mei 2004';
      _selectedGender = prefs.getString('user_gender') ?? 'Perempuan';
      _heightController.text = prefs.getString('user_height') ?? '160 cm';
      _weightController.text = prefs.getString('user_weight') ?? '52 kg';
      _selectedBloodType = prefs.getString('user_blood_type') ?? 'B';
      _emailController.text = prefs.getString('user_email') ?? 'lathifa21@email.com';
      _phoneController.text = prefs.getString('user_phone') ?? '0812-3456-7890';
      _isLoading = false;
    });
  }

  Future<void> _saveData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('user_name', _nameController.text.trim());
    await prefs.setString('user_dob', _dobController.text.trim());
    await prefs.setString('user_gender', _selectedGender);
    await prefs.setString('user_height', _heightController.text.trim());
    await prefs.setString('user_weight', _weightController.text.trim());
    await prefs.setString('user_blood_type', _selectedBloodType);
    await prefs.setString('user_email', _emailController.text.trim());
    await prefs.setString('user_phone', _phoneController.text.trim());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
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
                      await _saveData();
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text('Perubahan berhasil disimpan!'),
                          backgroundColor: Color(0xFF0EAD69),
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
      body: _isLoading
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
                        border: Border.all(color: Colors.white, width: 4),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const CircleAvatar(
                        radius: 46,
                        backgroundImage: NetworkImage(
                          'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&q=80&w=150',
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Ubah foto profil belum tersedia.')),
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
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: 'Tanggal Lahir',
                  controller: _dobController,
                  icon: Icons.calendar_month_outlined,
                ),
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
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: 'Berat Badan',
                  controller: _weightController,
                  icon: Icons.monitor_weight_outlined,
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
                ),
                const SizedBox(height: 16),

                _buildTextField(
                  label: 'Nomor HP',
                  controller: _phoneController,
                  icon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 24),

                // Personalize Info Card Banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFE8F8F5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFD0EBE0), width: 1),
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
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
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
          style: const TextStyle(color: Color(0xFF1E3A34), fontSize: 14, fontWeight: FontWeight.w600),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return '$label tidak boleh kosong';
            }
            return null;
          },
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF6B807B), size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0EAD69), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2EBE8), width: 1.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
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

  Widget _buildDropdownField({
    required String label,
    required String value,
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
          style: const TextStyle(color: Color(0xFF1E3A34), fontSize: 14, fontWeight: FontWeight.w600),
          icon: const Icon(Icons.keyboard_arrow_down_rounded, color: Color(0xFF6B807B)),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: const Color(0xFF6B807B), size: 20),
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF0EAD69), width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFFE2EBE8), width: 1.5),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          items: items.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ],
    );
  }
}
