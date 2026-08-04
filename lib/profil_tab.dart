import 'package:flutter/material.dart';
import 'informasi_pribadi_page.dart';
import 'tujuan_kesehatan_page.dart';

import 'package:shared_preferences/shared_preferences.dart';

class ProfilTab extends StatefulWidget {
  const ProfilTab({super.key});

  @override
  State<ProfilTab> createState() => _ProfilTabState();
}

class _ProfilTabState extends State<ProfilTab> {
  String _name = 'Lathifa';
  String _email = 'lathifa@gmail.com';
  String _phone = '+62 812-3456-7890';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _name = prefs.getString('user_name') ?? 'Lathifa';
      _email = prefs.getString('user_email') ?? 'lathifa21@email.com';
      _phone = prefs.getString('user_phone') ?? '0812-3456-7890';
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4FAF7),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: const Text(
          'Profil Pengguna',
          style: TextStyle(color: Color(0xFF1E3A34), fontWeight: FontWeight.bold, fontSize: 18),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0EAD69)),
              ),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                children: [
                  // Profile Card/Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: const Color(0xFFE2EBE8), width: 1.5),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: const Color(0xFFE0F2F1),
                          child: ClipOval(
                            child: Image.network(
                              'https://images.unsplash.com/photo-1544005313-94ddf0286df2?auto=format&fit=crop&q=80&w=150',
                              fit: BoxFit.cover,
                              width: 72,
                              height: 72,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.person, color: Color(0xFF0EAD69), size: 36);
                              },
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _name,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A34),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _email,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF7E9A94),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _phone,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF7E9A94),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Profile menu items
                  _buildProfileMenu(
                    icon: Icons.person_outline_rounded,
                    title: 'Informasi Pribadi',
                    onTap: () async {
                      final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const InformasiPribadiPage()),
                      );
                      if (updated == true) {
                        _loadProfileData();
                      }
                    },
                  ),
            _buildProfileMenu(
              icon: Icons.track_changes_rounded,
              title: 'Tujuan Kesehatan',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const TujuanKesehatanPage()),
                );
              },
            ),
            _buildProfileMenu(
              icon: Icons.logout_rounded,
              title: 'Keluar',
              color: Colors.redAccent,
              onTap: () {
                // Logout to Welcome Page
                Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileMenu({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color color = const Color(0xFF1E3A34),
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2EBE8), width: 1.2),
      ),
      child: ListTile(
        onTap: onTap,
        leading: Icon(icon, color: color),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        trailing: Icon(Icons.chevron_right_rounded, color: color.withValues(alpha: 0.5)),
      ),
    );
  }
}
