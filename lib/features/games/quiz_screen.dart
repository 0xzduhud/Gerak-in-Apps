import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'game_provider.dart';

/// [QuizScreen] - Layar Kuis Fitness FitMate
/// Mengusung tema Dark Mode premium dengan aksen Oranye,
/// sepenuhnya terintegrasi dengan [GameProvider].
class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  // Konstanta Warna Tema Dark Mode & Aksen Oranye
  static const Color _bgColor = Color(0xFF171312);
  static const Color _cardColor = Color(0xFF1E1E1E);
  static const Color _cardBorderColor = Color(0xFF2C2C2C);
  static const Color _optionBgColor = Color(0xFF2A2A2A);
  static const Color _badgeBgColor = Color(0xFF3A3A3A);
  static const Color _primaryOrange = Color(0xFFE86524);
  static const Color _correctGreen = Color(0xFF00E676);

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (!mounted) return;
      context.read<GameProvider>().startGame(isGuessMove: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<GameProvider>();

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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Fitness Quiz',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 20,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          // Indikator Poin / Skor Saat Ini dengan Aksen Oranye
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _cardBorderColor),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: _primaryOrange,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  '${provider.score} Poin',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: provider.isQuizFinished
            ? _buildCompletionScreen(provider)
            : (provider.activeQuestions.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: _primaryOrange),
                    )
                  : _buildQuizContent(provider)),
      ),
    );
  }

  /// Konten Utama Kuis
  Widget _buildQuizContent(GameProvider provider) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Widget Timer Mundur Minimalis di Bagian Atas
          _buildTimerWidget(provider),

          const SizedBox(height: 16),

          // 2. Indikator Nomor Soal & Kategori dengan Aksen Oranye
          _buildQuestionProgressHeader(provider),

          const SizedBox(height: 20),

          // 3. Card Pertanyaan (Warna Color(0xFF1E1E1E), padding 24px, label "Pertanyaan" kecil abu-abu)
          _buildQuestionCard(provider),

          const SizedBox(height: 20),

          // 4. Pilihan Ganda (Container + Row, Color(0xFF2A2A2A), badge Color(0xFF3A3A3A), aktif oranye)
          _buildOptionsList(provider),
        ],
      ),
    );
  }

  /// Widget Timer Mundur Minimalis (tinggi 6px, value color oranye, background abu-abu sangat gelap)
  Widget _buildTimerWidget(GameProvider provider) {
    final double progress = (provider.timeLeft / 15).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_rounded, color: _primaryOrange, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Sisa Waktu',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '${provider.timeLeft}s',
                      style: const TextStyle(
                        color: _primaryOrange,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    backgroundColor: const Color(0xFF121216),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      _primaryOrange,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Indikator Nomor Soal dan Kategori (Aksen Oranye)
  Widget _buildQuestionProgressHeader(GameProvider provider) {
    final totalQuestions = provider.activeQuestions.length;
    final currentQuestion =
        provider.activeQuestions[provider.currentQuestionIndex];
    final category = currentQuestion['category'] ?? 'Fitness & Nutrisi';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _primaryOrange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _primaryOrange.withValues(alpha: 0.3)),
          ),
          child: Text(
            'Soal ${provider.currentQuestionIndex + 1}/$totalQuestions',
            style: const TextStyle(
              color: _primaryOrange,
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
        Text(
          category,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  /// Card Soal: Background Color(0xFF1E1E1E), padding 24px, tanpa garis tebal, teks "Pertanyaan" kecil warna abu-abu
  Widget _buildQuestionCard(GameProvider provider) {
    final currentQuestion =
        provider.activeQuestions[provider.currentQuestionIndex];
    final String questionText = currentQuestion['question'] ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _cardBorderColor, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Teks "Pertanyaan" kecil warna abu-abu (menggantikan ikon tanda tanya merah)
          const Text(
            'PERTANYAAN',
            style: TextStyle(
              color: Colors.grey,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            questionText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.45,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  /// Opsi Jawaban (A, B, C, D):
  /// - Container berisi Row
  /// - Background Color(0xFF2A2A2A)
  /// - Huruf A/B/C/D dalam kotak membulat Color(0xFF3A3A3A) dengan teks putih
  /// - Interaksi: Saat opsi dipilih/ditekan, border luar berubah oranye & latar belakang huruf A/B/C/D berubah oranye
  Widget _buildOptionsList(GameProvider provider) {
    final currentQuestion =
        provider.activeQuestions[provider.currentQuestionIndex];
    final int correctIndex = (currentQuestion['answer'] as num?)?.toInt() ?? 0;
    final int? selectedIndex = provider.selectedAnswerIndex;
    final List<dynamic> options =
        (currentQuestion['options'] as List<dynamic>?) ?? [];
    final optionLabels = ['A', 'B', 'C', 'D'];

    // Nonaktifkan klik saat sedang menjawab (agar tidak bisa ganti jawaban)
    final bool canTap = !provider.isAnswering && !provider.isQuizFinished;

    return Column(
      children: List.generate(options.length, (index) {
        final optionText = options[index].toString();
        final label = index < optionLabels.length
            ? optionLabels[index]
            : '${index + 1}';

        Color borderColor = Colors.transparent;
        Color badgeBg = _badgeBgColor;

        // Logika validasi jawaban saat opsi ditekan:
        if (selectedIndex != null) {
          if (index == correctIndex) {
            // Jika benar, atau menyorot opsi yang sebenarnya benar saat salah
            borderColor = Colors.green;
            badgeBg = Colors.green;
          } else if (index == selectedIndex) {
            // Jika salah: opsi yang dipilih menjadi Merah
            borderColor = Colors.red;
            badgeBg = Colors.red;
          }
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _optionBgColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: 1.8),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: canTap ? () => provider.checkAnswer(index) : null,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                child: Row(
                  children: [
                    // Kotak membulat huruf A/B/C/D
                    Container(
                      width: 36,
                      height: 36,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Teks Opsi Jawaban
                    Expanded(
                      child: Text(
                        optionText,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  /// Tampilan Skor / Selesai Kuis
  Widget _buildCompletionScreen(GameProvider provider) {
    final int totalQuestions = provider.activeQuestions.length;
    final int maxScore = totalQuestions * 10;
    final double percentage = maxScore > 0
        ? (provider.score / maxScore) * 100
        : 0;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ikon Piala dengan latar belakang gelap & aksen oranye (tanpa neon merah)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _optionBgColor,
                shape: BoxShape.circle,
                border: Border.all(
                  color: _primaryOrange.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: const Icon(
                Icons.emoji_events_rounded,
                color: _primaryOrange,
                size: 60,
              ),
            ),
            const SizedBox(height: 24),

            const Text(
              'Kuis Selesai',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              percentage >= 70
                  ? 'Luar biasa! Pengetahuan fitness kamu sangat tajam!'
                  : 'Bagus! Terus latih wawasan kebugaranmu!',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 28),

            // Card Hasil Skor
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _cardBorderColor),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildStatItem(
                        label: 'Total Skor',
                        value: '${provider.score}',
                        icon: Icons.check_circle_outline_rounded,
                        color: _correctGreen,
                      ),
                      Container(height: 40, width: 1, color: _cardBorderColor),
                      _buildStatItem(
                        label: 'Akurasi',
                        value: '${percentage.toInt()}%',
                        icon: Icons.percent_rounded,
                        color: _primaryOrange,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Tombol Main Lagi (Warna Oranye)
            ElevatedButton.icon(
              onPressed: () {
                provider.startGame(isGuessMove: false);
              },
              icon: const Icon(Icons.replay_rounded, color: Colors.white),
              label: const Text(
                'Main Lagi',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryOrange,
                minimumSize: const Size.fromHeight(52),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
            const SizedBox(height: 12),

            // Tombol Kembali
            OutlinedButton(
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.of(context).pop();
                }
              },
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
                side: const BorderSide(color: _cardBorderColor),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: const Text(
                'Kembali ke Menu',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper Widget Item Statistik di Layar Selesai
  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.5),
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
