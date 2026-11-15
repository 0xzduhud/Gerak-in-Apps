import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/models/achievement_model.dart';
import '../premium/subscription_provider.dart';
import 'block.dart';

class AchievementDetailScreen extends StatelessWidget {
  const AchievementDetailScreen({
    super.key,
    required this.achievement,
    required this.stats,
    required this.block,
  });

  final AchievementDef achievement;
  final AchievementStats stats;
  final Block? block;

  String _formatDate(int timestampMs) {
    final date = DateTime.fromMillisecondsSinceEpoch(
      timestampMs,
      isUtc: true,
    ).toLocal();

    String two(int value) => value.toString().padLeft(2, '0');

    return '${two(date.day)}/${two(date.month)}/${date.year} • ${two(date.hour)}:${two(date.minute)} WIB';
  }

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin.'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isPremium = context.watch<SubscriptionProvider>().isPremium;
    final isLocked = achievement.isPremium && !isPremium;
    final progress = achievement.progress(stats).clamp(0.0, 1.0);
    final isUnlocked = block != null;

    final badgeColor = achievement.isPremium
        ? const Color(0xFFFFB300)
        : AppColors.primary;

    return Scaffold(
      backgroundColor: AppColors.neutral,
      appBar: AppBar(
        title: const Text('Detail Achievement'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            // 1. Kartu Lencana Utama (Medali & Judul)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: isUnlocked
                      ? badgeColor.withValues(alpha: 0.5)
                      : AppColors.outline,
                ),
                boxShadow: [
                  if (isUnlocked)
                    BoxShadow(
                      color: badgeColor.withValues(alpha: 0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isUnlocked
                          ? LinearGradient(
                              colors: [
                                badgeColor.withValues(alpha: 0.3),
                                badgeColor.withValues(alpha: 0.1),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isUnlocked ? null : AppColors.surfaceHigh,
                      border: Border.all(
                        color: isUnlocked
                            ? badgeColor.withValues(alpha: 0.6)
                            : AppColors.outline,
                        width: 2,
                      ),
                    ),
                    child: Icon(
                      isLocked
                          ? Icons.lock_rounded
                          : isUnlocked
                              ? Icons.emoji_events_rounded
                              : Icons.military_tech_outlined,
                      size: 40,
                      color: isUnlocked ? badgeColor : Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    achievement.title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    achievement.description,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: (isUnlocked
                                  ? Colors.green
                                  : AppColors.outline)
                              .withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isUnlocked
                                ? Colors.greenAccent.withValues(alpha: 0.5)
                                : AppColors.outline,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              isUnlocked
                                  ? Icons.check_circle_rounded
                                  : Icons.lock_outline_rounded,
                              size: 13,
                              color: isUnlocked
                                  ? Colors.greenAccent
                                  : Colors.white54,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              isUnlocked ? 'Terbuka' : 'Terkunci',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: isUnlocked
                                    ? Colors.greenAccent
                                    : Colors.white54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (achievement.isPremium) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFB300), Color(0xFFE86524)],
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.workspace_premium_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                              SizedBox(width: 4),
                              Text(
                                'PREMIUM',
                                style: TextStyle(
                                  fontSize: 10.5,
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
                ],
              ),
            ),
            const SizedBox(height: 16),

            // 2. Status Progres Latihan
            if (isLocked)
              _PremiumNoticeCard()
            else
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.outline),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Target Pencapaian',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${(progress * 100).round()}%',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: isUnlocked ? Colors.greenAccent : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: progress,
                        minHeight: 7,
                        backgroundColor: AppColors.surfaceHigh,
                        color: isUnlocked ? Colors.greenAccent : badgeColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      isUnlocked
                          ? 'Selamat! Persyaratan achievement ini telah dipenuhi dan dicatat permanen.'
                          : 'Lakukan aktivitas olahraga untuk melengkapi target achievement ini.',
                      style: const TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 16),

            // 3. Sertifikat Blockchain Sepolia
            if (block != null)
              _BlockchainCertificateCard(
                block: block!,
                formatDate: _formatDate,
                onCopy: (val, label) => _copyToClipboard(context, val, label),
              ),
          ],
        ),
      ),
    );
  }
}

class _PremiumNoticeCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFFFB300).withValues(alpha: 0.3)),
      ),
      child: const Row(
        children: [
          Icon(Icons.workspace_premium_rounded, color: Color(0xFFFFB300), size: 28),
          SizedBox(width: 14),
          Expanded(
            child: Text(
              'Achievement ini adalah fitur FitMate Plus. Upgrade akunmu untuk membuka dan mencatat pencapaian ini di Sepolia.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }
}

class _BlockchainCertificateCard extends StatelessWidget {
  const _BlockchainCertificateCard({
    required this.block,
    required this.formatDate,
    required this.onCopy,
  });

  final Block block;
  final String Function(int timestampMs) formatDate;
  final void Function(String text, String label) onCopy;

  Future<void> _openEtherscan(BuildContext context) async {
    final uri = Uri.parse(block.etherscanUrl);
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka browser.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF627EEA).withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF627EEA).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.verified_rounded,
                  color: Color(0xFF627EEA),
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sertifikat Ethereum Sepolia',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Terverifikasi On-Chain (SBT Standard)',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF627EEA),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Grid Data Blockchain
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.outline),
            ),
            child: Column(
              children: [
                _MetaRow(
                  label: 'Jaringan',
                  value: Block.networkName,
                ),
                const Divider(color: AppColors.outline, height: 16),
                _MetaRow(
                  label: 'Chain ID',
                  value: '${Block.sepoliaChainId}',
                ),
                const Divider(color: AppColors.outline, height: 16),
                _MetaRow(
                  label: 'Nomor Blok',
                  value: '#${block.sepoliaBlockNumber}',
                ),
                const Divider(color: AppColors.outline, height: 16),
                _MetaRow(
                  label: 'Waktu Minting',
                  value: formatDate(block.timestampMs),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Smart Contract Address
          _AddressBox(
            label: 'Alamat Smart Contract (SBT)',
            value: Block.sepoliaContractAddress,
            onCopy: () => onCopy(Block.sepoliaContractAddress, 'Alamat Smart Contract'),
          ),
          const SizedBox(height: 10),

          // Transaction Hash
          _AddressBox(
            label: 'Transaction Hash',
            value: block.txHash,
            onCopy: () => onCopy(block.txHash, 'Transaction Hash'),
          ),
          const SizedBox(height: 18),

          // Tombol Buka di Sepolia Etherscan (Membuka Address Kontrak Sepolia Terverifikasi)
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Color(0xFF627EEA)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: () => _openEtherscan(context),
              icon: const Icon(
                Icons.open_in_new_rounded,
                size: 16,
                color: Color(0xFF627EEA),
              ),
              label: const Text(
                'Buka di Sepolia Etherscan',
                style: TextStyle(
                  color: Color(0xFF627EEA),
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetaRow extends StatelessWidget {
  const _MetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}

class _AddressBox extends StatelessWidget {
  const _AddressBox({
    required this.label,
    required this.value,
    required this.onCopy,
  });

  final String label;
  final String value;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.outline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              InkWell(
                onTap: onCopy,
                borderRadius: BorderRadius.circular(6),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.copy_rounded, size: 12, color: AppColors.secondary),
                      SizedBox(width: 3),
                      Text(
                        'Salin',
                        style: TextStyle(fontSize: 11, color: AppColors.secondary),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            style: const TextStyle(
              fontSize: 12,
              fontFamily: 'monospace',
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}
