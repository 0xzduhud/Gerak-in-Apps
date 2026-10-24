import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gerakinapps/core/services/game_local_db.dart';
import 'package:provider/provider.dart';

import 'shake_to_save.dart';
import 'target_game_provider.dart';

/// [TargetGameScreen] - Game Tangkap Target.
/// Provider dibuat di sini (lokal), jadi tidak perlu mendaftarkan apa pun
/// di main.dart.
class TargetGameScreen extends StatelessWidget {
  const TargetGameScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => TargetGameProvider(userId: currentGameUserId())..start(),
      child: const _TargetGameView(),
    );
  }
}

class _TargetGameView extends StatelessWidget {
  const _TargetGameView();

  static const Color _bgColor = Color(0xFF171312);
  static const Color _cardColor = Color(0xFF1E1E1E);
  static const Color _cardBorderColor = Color(0xFF2C2C2C);
  static const Color _primaryOrange = Color(0xFFE86524);
  static const double _targetSize = 64;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<TargetGameProvider>();

    // Setelah game selesai, pemain wajib menggoyang HP dulu (tidak bisa back).
    return PopScope(
      canPop: !p.isGameOver,
      child: Scaffold(
        backgroundColor: _bgColor,
        appBar: AppBar(
          backgroundColor: _bgColor,
          elevation: 0,
          centerTitle: true,
          automaticallyImplyLeading: false,
          leading: p.isGameOver
              ? null
              : IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white70,
                  ),
                  onPressed: () => Navigator.of(context).maybePop(),
                ),
          title: const Text(
            'Tangkap Target',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 20,
              letterSpacing: 0.5,
            ),
          ),
        ),
        body: SafeArea(
          child: p.isGameOver
              ? _buildResult(context, p)
              : _buildPlay(context, p),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------- bermain

  Widget _buildPlay(BuildContext context, TargetGameProvider p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              _chip(Icons.local_fire_department_rounded, '${p.score} Poin'),
              const SizedBox(width: 8),
              _chip(Icons.trending_up_rounded, 'Level ${p.level}'),
              const Spacer(),
              Row(
                children: List.generate(TargetGameProvider.maxLives, (i) {
                  final alive = i < p.lives;
                  return Padding(
                    padding: const EdgeInsets.only(left: 2),
                    child: Icon(
                      alive
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: alive ? Colors.redAccent : Colors.white24,
                      size: 24,
                    ),
                  );
                }),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: _primaryOrange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _primaryOrange.withValues(alpha: 0.3)),
            ),
            child: Text(
              p.bombsActive
                  ? 'Sentuh makanan sehat 🥦. Hindari junk food 🍔 dan bom 💣!'
                  : 'Sentuh makanan sehat 🥦. Hindari junk food 🍔!',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _cardBorderColor),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final maxLeft = max(0.0, box.maxWidth - _targetSize);
                    final maxTop = max(0.0, box.maxHeight - _targetSize);
                    return Stack(
                      children: [
                        for (final t in p.targets)
                          Positioned(
                            key: ValueKey(t.id),
                            left: t.dx * maxLeft,
                            top: t.dy * maxTop,
                            child: _TargetBubble(
                              emoji: t.emoji,
                              size: _targetSize,
                              onTap: () {
                                final kind = p.tap(t.id);
                                if (kind == TargetKind.healthy) {
                                  HapticFeedback.selectionClick();
                                } else if (kind != null) {
                                  HapticFeedback.heavyImpact();
                                }
                              },
                            ),
                          ),
                        if (p.isEnding)
                          Container(
                            color: Colors.black54,
                            alignment: Alignment.center,
                            child: const Text(
                              'Nyawa habis!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cardBorderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _primaryOrange, size: 16),
          const SizedBox(width: 4),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ hasil

  Widget _buildResult(BuildContext context, TargetGameProvider p) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2A),
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
            const SizedBox(height: 20),
            const Text(
              'Game Selesai',
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (p.isNewRecord) ...[
              const SizedBox(height: 8),
              const Text(
                'Rekor baru!',
                style: TextStyle(
                  color: _primaryOrange,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _cardColor,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: _cardBorderColor),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _stat('Skor', '${p.score}'),
                  _stat('Level', '${p.level}'),
                  _stat('Tertangkap', '${p.caught}'),
                  _stat('Rekor', '${p.isNewRecord ? p.score : p.bestScore}'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ShakeToSaveCard(
              onShaken: () async {
                await p.saveResult();
                if (!context.mounted) return;
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String label, String value) {
    return Column(
      children: [
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

/// Target berbentuk lingkaran dengan emoji. Warnanya sengaja sama untuk semua
/// jenis, sehingga pemain harus mengenali makanannya.
class _TargetBubble extends StatelessWidget {
  const _TargetBubble({
    required this.emoji,
    required this.size,
    required this.onTap,
  });

  final String emoji;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 150),
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => onTap(),
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: const Color(0xFF2A2A2A),
            shape: BoxShape.circle,
            border: Border.all(
              color: const Color(0xFFE86524).withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 32)),
        ),
      ),
    );
  }
}
