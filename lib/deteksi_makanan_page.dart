import 'package:flutter/material.dart';

class DeteksiMakananPage extends StatelessWidget {
  const DeteksiMakananPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 1. Cameraview Finder Background (Placeholder Food Image)
          Positioned.fill(
            child: Opacity(
              opacity: 0.85,
              child: Image.network(
                'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?auto=format&fit=crop&q=80&w=600',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF1E3A34),
                    child: const Center(
                      child: Icon(Icons.restaurant_menu, color: Colors.white, size: 80),
                    ),
                  );
                },
              ),
            ),
          ),

          // 2. Camera Viewfinder Overlay bounds (Corners)
          Positioned.fill(
            child: Center(
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Stack(
                  children: [
                    // Corner Top-Left
                    Positioned(
                      top: 0,
                      left: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.white, width: 4),
                            left: BorderSide(color: Colors.white, width: 4),
                          ),
                          borderRadius: BorderRadius.only(topLeft: Radius.circular(12)),
                        ),
                      ),
                    ),
                    // Corner Top-Right
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          border: Border(
                            top: BorderSide(color: Colors.white, width: 4),
                            right: BorderSide(color: Colors.white, width: 4),
                          ),
                          borderRadius: BorderRadius.only(topRight: Radius.circular(12)),
                        ),
                      ),
                    ),
                    // Corner Bottom-Left
                    Positioned(
                      bottom: 0,
                      left: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white, width: 4),
                            left: BorderSide(color: Colors.white, width: 4),
                          ),
                          borderRadius: BorderRadius.only(bottomLeft: Radius.circular(12)),
                        ),
                      ),
                    ),
                    // Corner Bottom-Right
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: const BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.white, width: 4),
                            right: BorderSide(color: Colors.white, width: 4),
                          ),
                          borderRadius: BorderRadius.only(bottomRight: Radius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 3. Header Arrow Back
          Positioned(
            top: MediaQuery.of(context).padding.top + 16,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black.withValues(alpha: 0.4),
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          // Title
          Positioned(
            top: MediaQuery.of(context).padding.top + 22,
            left: 0,
            right: 0,
            child: const Center(
              child: Text(
                'Deteksi Makanan',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ),

          // 4. Camera controls (Gallery, Shutter, Flash)
          Positioned(
            bottom: 280,
            left: 40,
            right: 40,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Gallery button
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: const Icon(Icons.image_outlined, color: Colors.white, size: 24),
                ),
                // Main Camera Shutter button
                Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black, width: 3),
                      color: const Color(0xFF0EAD69),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.photo_camera_rounded, color: Colors.white, size: 28),
                  ),
                ),
                // Flash button
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  child: const Icon(Icons.flash_on_rounded, color: Colors.white, size: 24),
                ),
              ],
            ),
          ),

          // 5. Sliding/Floating bottom analysis card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Title and "Sehat" status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Hasil Analisis',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E3A34),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE2F6F0),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: const [
                            Icon(Icons.check_circle, color: Color(0xFF0EAD69), size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Sehat',
                              style: TextStyle(
                                color: Color(0xFF0EAD69),
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Nutrition table row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildNutrientItem('Kalori', '430', ' kcal'),
                      _buildNutrientItem('Karbohidrat', '45', ' g'),
                      _buildNutrientItem('Protein', '28', ' g'),
                      _buildNutrientItem('Lemak', '15', ' g'),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Food status info (Rendah Gula)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE2F6F0),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: const [
                              Text(
                                'Makanan ini',
                                style: TextStyle(fontSize: 11, color: Color(0xFF8FA7A1)),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Rendah Gula',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1E3A34),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Cute leaf monster character represented as text + circle
                        Container(
                          width: 40,
                          height: 40,
                          decoration: const BoxDecoration(
                            color: Color(0xFF8AE8CD),
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: const Text('👾', style: TextStyle(fontSize: 22)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNutrientItem(String label, String value, String unit) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Color(0xFF8FA7A1)),
        ),
        const SizedBox(height: 4),
        RichText(
          text: TextSpan(
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E3A34),
            ),
            children: [
              TextSpan(text: value),
              TextSpan(
                text: unit,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.normal,
                  color: Color(0xFF6B807B),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
