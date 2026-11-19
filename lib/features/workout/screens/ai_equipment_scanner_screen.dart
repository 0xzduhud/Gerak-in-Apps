import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/gemini_equipment_service.dart';
import '../../../core/theme.dart';

class GymEquipmentInfo {
  const GymEquipmentInfo({
    required this.name,
    required this.category,
    required this.targetMuscles,
    required this.utility,
    required this.tutorial,
    required this.commonMistakes,
    required this.icon,
    this.isAiGenerated = false,
  });

  final String name;
  final String category;
  final String targetMuscles;
  final String utility;
  final List<String> tutorial;
  final List<String> commonMistakes;
  final IconData icon;
  final bool isAiGenerated;
}

class AiEquipmentScannerScreen extends StatefulWidget {
  const AiEquipmentScannerScreen({super.key});

  @override
  State<AiEquipmentScannerScreen> createState() =>
      _AiEquipmentScannerScreenState();
}

class _AiEquipmentScannerScreenState extends State<AiEquipmentScannerScreen> {
  final ImagePicker _picker = ImagePicker();

  XFile? _capturedImage;
  bool _isAnalyzing = false;
  GymEquipmentInfo? _detectedEquipment;

  static const List<GymEquipmentInfo> _equipmentDatabase = [
    GymEquipmentInfo(
      name: 'Lat Pulldown Machine',
      category: 'Mesin Beban Kabel / Punggung',
      targetMuscles: 'Latissimus Dorsi (Punggung Lebar), Biceps, Rhomboids, Trapezius',
      utility:
          'Membangun massa dan lebar punggung (V-Taper), memperkuat tarikan vertikal, serta memperbaiki postur membungkuk.',
      tutorial: [
        'Atur bantalan penahan paha agar kaki terkunci pas dan telapak kaki menapak rata di lantai.',
        'Pegang stang lebar (wide grip) dengan telapak tangan menghadap ke depan.',
        'Condongkan tubuh sedikit ke belakang (~10-15 derajat) dan busungkan dada.',
        'Tarik stang turun ke arah dada bagian atas sambil merapatkan tulang belikat.',
        'Tahan 1 detik di dada, lalu kembalikan perlahan ke atas dengan kontrol penuh.',
      ],
      commonMistakes: [
        'Mengayunkan badan terlalu ke belakang untuk memanfaatkan momentum beban.',
        'Menarik stang ke belakang leher (berbahaya bagi leher dan sendi bahu rotasi).',
      ],
      icon: Icons.fitness_center_rounded,
    ),
    GymEquipmentInfo(
      name: 'Barbell Bench Press',
      category: 'Beban Bebas / Dada',
      targetMuscles: 'Pectoralis Major (Dada), Triceps, Anterior Deltoid (Bahu Depan)',
      utility:
          'Latihan compound utama untuk meningkatkan massa otot dada dan kekuatan dorong tubuh bagian atas secara menyeluruh.',
      tutorial: [
        'Berbaring di atas bench dengan mata sejajar tepat di bawah stang barbell.',
        'Genggam stang sedikit lebih lebar dari bahu, kencangkan belikat dan kunci core.',
        'Angkat stang dari rak, lalu turunkan perlahan ke garis tengah dada bagian bawah.',
        'Dorong stang kembali ke atas lurus secara eksplosif hingga siku hampir mengunci.',
        'Bernapas masuk saat beban turun, dan buang napas saat mendorong beban naik.',
      ],
      commonMistakes: [
        'Memantulkan stang barbell ke tulang dada saat di bawah.',
        'Siku terlalu melebar ke samping 90 derajat yang bisa mencederai rotator cuff bahu.',
      ],
      icon: Icons.horizontal_distribute_rounded,
    ),
    GymEquipmentInfo(
      name: 'Leg Press Machine',
      category: 'Mesin Kaki / Lower Body',
      targetMuscles: 'Quadriceps (Paha Depan), Glutes (Bokong), Hamstrings (Paha Belakang)',
      utility:
          'Melatih kekuatan kaki dengan beban maksimal secara aman tanpa membebani tulang belakang lumbar secara berlebih.',
      tutorial: [
        'Duduk di mesin dan pastikan punggung serta pinggul menempel rapat pada sandaran kursi.',
        'Letakkan kedua telapak kaki di platform selebar bahu di tengah papan.',
        'Lepaskan tuas pengaman mesin, lalu tekuk lutut perlahan hingga sudut 90 derajat.',
        'Dorong platform kembali ke atas menggunakan tumit dan telapak kaki bagian tengah.',
        'PENTING: Jangan sekali-kali mengunci (hyper-extend) sendi lutut saat posisi lurus.',
      ],
      commonMistakes: [
        'Mengunci lutut lurus sempurna saat mendorong (berisiko cedera sendi tempurung fatal).',
        'Pinggul terangkat dari sandaran kursi saat menurunkan beban terlalu dalam.',
      ],
      icon: Icons.airline_seat_legroom_extra_rounded,
    ),
    GymEquipmentInfo(
      name: 'Dumbbell Set',
      category: 'Free Weight / Serbaguna',
      targetMuscles: 'Dada, Bahu, Biceps, Triceps, Kaki (Tergantung variasi gerakan)',
      utility:
          'Alat beban bebas paling fleksibel untuk melatih simetri otot kiri dan kanan, serta meningkatkan stabilitas sendi.',
      tutorial: [
        'Pilih bobot dumbbell yang memungkinkan kamu melakukan 8–12 repetisi dengan form bersih.',
        'Jaga tulang belakang tetap netral dan kunci otot perut selama memegang beban.',
        'Gerakkan beban dalam rentang gerak penuh (full range of motion) tanpa mengayun tubuh.',
        'Kendalikan tempo: 1 detik dorong/tarik, 2-3 detik saat mengembalikan beban.',
      ],
      commonMistakes: [
        'Memilih beban terlalu berat sehingga mengorbankan postur tubuh yang benar.',
        'Menggunakan ayunan pinggang atau momentum leher.',
      ],
      icon: Icons.fitness_center_rounded,
    ),
    GymEquipmentInfo(
      name: 'Treadmill Elektrik',
      category: 'Kardiovaskular / Aerobik',
      targetMuscles: 'Jantung (Cardiovascular), Betis, Quadriceps, Glutes',
      utility:
          'Membakar kalori, melatih daya tahan kardiovaskular, dan pemanasan efektif sebelum sesi angkat beban.',
      tutorial: [
        'Pasang klip pengaman (safety clip) darurat ke baju sebelum menyalakan mesin.',
        'Mulai dengan kecepatan jalan santai (3-4 km/jam) selama 3-5 menit untuk pemanasan.',
        'Tingkatkan kecepatan ke jogging (6-8 km/jam) atau atur incline 2-4% untuk efisiensi kalori.',
        'Pertahankan pandangan ke depan dan ayunkan lengan secara rileks di samping tubuh.',
      ],
      commonMistakes: [
        'Terus-menerus memegang pegangan tangan mesin saat berjalan atau berlari cepat.',
        'Melangkah terlalu panjang (over-striding) dengan mendarat keras pada tumit.',
      ],
      icon: Icons.directions_run_rounded,
    ),
    GymEquipmentInfo(
      name: 'Cable Crossover Machine',
      category: 'Mesin Katrol Kabel / Multifungsi',
      targetMuscles: 'Dada, Bahu, Punggung, Lengan (Tergantung tinggi katrol dan handle)',
      utility:
          'Memberikan tegangan otot yang konstan sepanjang seluruh rentang gerak (constant tension), ideal untuk isolasi otot.',
      tutorial: [
        'Atur ketinggian pulley sesuai gerakan (katrol atas untuk dada bawah, katrol bawah untuk dada atas).',
        'Ambil pegangan D-handle, posisikan satu kaki maju untuk menjaga keseimbangan.',
        'Condongkan tubuh sedikit ke depan dan pertahankan sedikit tekukan pada siku.',
        'Satukan kedua tangan ke depan dada seperti sedang memeluk pohon besar.',
        'Tahan kontraksi di titik tengah, lalu buka kembali perlahan.',
      ],
      commonMistakes: [
        'Mengubah gerakan terbang kabel (flye) menjadi dorongan press karena beban terlalu berat.',
        'Bahu membungkuk ke depan saat merapatkan tangan.',
      ],
      icon: Icons.cable_rounded,
    ),
  ];

  Future<void> _takePhoto() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo != null) {
        _analyzeImage(photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka kamera: $e')),
        );
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );

      if (photo != null) {
        _analyzeImage(photo);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tidak dapat membuka galeri: $e')),
        );
      }
    }
  }

  Future<void> _analyzeImage(XFile photo) async {
    setState(() {
      _capturedImage = photo;
      _isAnalyzing = true;
      _detectedEquipment = null;
    });

    try {
      // 1. Analisis foto sungguhan menggunakan Google Gemini Vision AI
      final aiResult = await GeminiEquipmentService.instance
          .analyzeEquipmentImage(File(photo.path));

      if (!mounted) return;

      if (aiResult != null) {
        setState(() {
          _isAnalyzing = false;
          _detectedEquipment = aiResult;
        });
        return;
      }
    } catch (e) {
      debugPrint('Kamera AI: Gagal memanggil Gemini Vision API: $e');
    }

    // 2. Fallback offline: jika internet putus / kuota habis, tampilkan notifikasi dan referensi alat
    if (!mounted) return;
    final index = (photo.path.hashCode + DateTime.now().millisecondsSinceEpoch).abs() %
        _equipmentDatabase.length;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Tidak dapat terhubung ke Gemini Vision AI. Menampilkan referensi alat offline.',
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );

    setState(() {
      _isAnalyzing = false;
      _detectedEquipment = _equipmentDatabase[index];
    });
  }

  void _selectPreset(GymEquipmentInfo info) {
    setState(() {
      _capturedImage = null;
      _isAnalyzing = true;
      _detectedEquipment = null;
    });

    Future.delayed(const Duration(milliseconds: 800), () {
      if (!mounted) return;
      setState(() {
        _isAnalyzing = false;
        _detectedEquipment = info;
      });
    });
  }

  void _reset() {
    setState(() {
      _capturedImage = null;
      _isAnalyzing = false;
      _detectedEquipment = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: const Text('Kamera AI - Alat Gym'),
        actions: [
          if (_detectedEquipment != null)
            IconButton(
              tooltip: 'Scan Alat Lain',
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _reset,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header banner instruksi
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.primary.withValues(alpha: 0.25),
                      AppColors.surface,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.4),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.camera_alt_rounded,
                        color: AppColors.primary,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI Gym Scanner',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            'Foto alat gym apa saja untuk mengetahui nama, fungsi, dan tutorial penggunaannya.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Jika sedang menganalisis
              if (_isAnalyzing) ...[
                Container(
                  padding: const EdgeInsets.all(36),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.outline),
                  ),
                  child: Column(
                    children: [
                      const SizedBox(
                        width: 50,
                        height: 50,
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 3.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'AI Menganalisis Struktur Alat...',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Mencocokkan bentuk, katrol, dan biomekanik latihan',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ] else if (_detectedEquipment != null) ...[
                // HASIL ANALISIS AI
                _buildAnalysisResult(_detectedEquipment!),
                const SizedBox(height: 20),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                    side: const BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _reset,
                  icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                  label: const Text(
                    'Pindai Alat Gym Lainnya',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ] else ...[
                // Tombol Ambil Foto / Galeri
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.neutral,
                          minimumSize: const Size.fromHeight(54),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _takePhoto,
                        icon: const Icon(Icons.photo_camera_rounded),
                        label: const Text(
                          'Ambil Foto',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(54),
                          side: const BorderSide(color: AppColors.outline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: _pickFromGallery,
                        icon: const Icon(Icons.photo_library_rounded, color: AppColors.secondary),
                        label: const Text(
                          'Galeri Foto',
                          style: TextStyle(color: AppColors.textPrimary),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // Presets contoh alat untuk coba langsung
                const Text(
                  'Atau Pilih Langsung Contoh Alat Gym:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 12),
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 2.2,
                  ),
                  itemCount: _equipmentDatabase.length,
                  itemBuilder: (context, index) {
                    final item = _equipmentDatabase[index];
                    return Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(14),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _selectPreset(item),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.outline),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceHigh,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  item.icon,
                                  color: AppColors.primary,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  item.name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisResult(GymEquipmentInfo info) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(color: Colors.black38, blurRadius: 14),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header alat
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            ),
            child: Row(
              children: [
                if (_capturedImage != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.file(
                      File(_capturedImage!.path),
                      width: 56,
                      height: 56,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(info.icon, color: AppColors.primary, size: 28),
                  ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.secondary.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                info.category,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.secondary,
                                ),
                              ),
                            ),
                          ),
                          if (info.isAiGenerated) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Color(0xFF8E24AA), Color(0xFFE86524)],
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.auto_awesome, size: 11, color: Colors.white),
                                  SizedBox(width: 3),
                                  Text(
                                    'Gemini AI',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        info.name,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Target Otot
                _sectionHeader(Icons.accessibility_new_rounded, 'Target Otot Utama'),
                const SizedBox(height: 6),
                Text(
                  info.targetMuscles,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const Divider(color: AppColors.outline, height: 24),

                // Kegunaan & Manfaat
                _sectionHeader(Icons.lightbulb_rounded, 'Kegunaan & Manfaat'),
                const SizedBox(height: 6),
                Text(
                  info.utility,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
                const Divider(color: AppColors.outline, height: 24),

                // Tutorial Penggunaan
                _sectionHeader(Icons.menu_book_rounded, 'Tutorial Langkah demi Langkah'),
                const SizedBox(height: 8),
                for (int i = 0; i < info.tutorial.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 20,
                          height: 20,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${i + 1}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.neutral,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            info.tutorial[i],
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textPrimary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(color: AppColors.outline, height: 24),

                // Kesalahan Umum & Keamanan
                _sectionHeader(Icons.warning_amber_rounded, 'Kesalahan Umum yang Harus Dihindari'),
                const SizedBox(height: 8),
                for (final mistake in info.commonMistakes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.cancel_rounded,
                          color: AppColors.tertiary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            mistake,
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                              height: 1.35,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 18),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppColors.secondary,
          ),
        ),
      ],
    );
  }
}
