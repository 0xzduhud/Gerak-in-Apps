import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../data/models/sport_model.dart';

class SportCard extends StatelessWidget {
  const SportCard({super.key, required this.sport, required this.onTap});

  final Sport sport;
  final VoidCallback onTap;

  String get _kcalLabel {
    final v = sport.kcalPerMinute;
    return '~${v.toStringAsFixed(v % 1 == 0 ? 0 : 1)} kkal/mnt';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon sementara pengganti gambar, bisa diganti nanti.
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(sport.icon, color: AppColors.primary, size: 28),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            sport.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _AccessBadge(isPremium: sport.isPremium),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${sport.equipment} • ${sport.sets} set × ${sport.reps}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        _Tag(icon: Icons.category_rounded, label: sport.category),
                        _Tag(
                          icon: Icons.signal_cellular_alt_rounded,
                          label: sport.difficulty.label,
                        ),
                        _Tag(
                          icon: Icons.local_fire_department_rounded,
                          label: _kcalLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.secondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// Penanda status Free / Premium (PBI-7.1).
/// Penguncian fitur premium dikerjakan di Sprint 19.
class _AccessBadge extends StatelessWidget {
  const _AccessBadge({required this.isPremium});

  final bool isPremium;

  @override
  Widget build(BuildContext context) {
    final color = isPremium ? AppColors.secondary : AppColors.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPremium
            ? AppColors.secondary.withValues(alpha: 0.18)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isPremium) ...[
            Icon(Icons.workspace_premium_rounded, size: 13, color: color),
            const SizedBox(width: 3),
          ],
          Text(
            isPremium ? 'Premium' : 'Free',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}