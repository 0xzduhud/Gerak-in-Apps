import 'package:flutter/material.dart';

import 'guess_move_screen.dart';
import 'quiz_screen.dart';

/// [GamesMenuScreen] - Menu Pilihan Game FitMate
/// Menampilkan pilihan mode permainan dengan desain modern, elegan, dan senada dengan tema aplikasi (Dark Mode & Aksen Oranye).
class GamesMenuScreen extends StatelessWidget {
  const GamesMenuScreen({super.key});

  // Tema Dark Mode & Aksen Oranye
  static const Color _bgColor = Color(0xFF171312);
  static const Color _primaryOrange = Color(0xFFE86524);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.white70,
          ),
          onPressed: () {
            if (Navigator.of(context).canPop()) {
              Navigator.of(context).pop();
            }
          },
        ),
        title: const Text(
          'FitMate Games',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            letterSpacing: 0.5,
          ),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 24.0,
              vertical: 24.0,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Header: Latar belakang hitam transparan dengan ikon controller berwarna oranye terang (tanpa efek glow merah)
                Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.4),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _primaryOrange.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: const Icon(
                    Icons.sports_esports_rounded,
                    color: _primaryOrange,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 20),

                // Judul & Subjudul
                const Text(
                  'Pilih Mode Permainan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Uji wawasan dan ketajaman kebugaranmu bersama FitMate!',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.65),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 36),

                // Card Menu 1: Kuis Pengetahuan
                _buildGameCard(
                  title: 'Kuis Pengetahuan',
                  subtitle:
                      'Jawab kuis wawasan nutrisi, kebugaran, dan recovery',
                  icon: Icons.quiz_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const QuizScreen(),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 16),

                // Card Menu 2: Tebak Gerakan
                _buildGameCard(
                  title: 'Tebak Gerakan',
                  subtitle:
                      'Tebak nama gerakan latihan berdasarkan visual dan petunjuk',
                  icon: Icons.fitness_center_rounded,
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const GuessMoveScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Card berdesain elegan dengan background Color(0xFF2A2A2A), border radius 16,
  /// ikon oranye di kiri dibungkus kontainer membulat, teks judul putih bold,
  /// teks deskripsi abu-abu terang, dan ikon chevron_right oranye di kanan.
  Widget _buildGameCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF383838),
          width: 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child: Row(
              children: [
                // Ikon fitur di kiri (warna oranye, dibungkus container membulat)
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: _primaryOrange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: _primaryOrange,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 16),

                // Teks Judul putih (bold) dan teks deskripsi abu-abu terang
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16.5,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.2,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          color: Color(0xFFB0B0B0),
                          fontSize: 12.5,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Ikon chevron_right warna oranye di pojok kanan
                const Icon(
                  Icons.chevron_right_rounded,
                  color: _primaryOrange,
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
