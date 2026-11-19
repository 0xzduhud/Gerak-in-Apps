import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../../../data/models/sport_model.dart';
import '../../../data/repositories/sport_repository.dart';
import '../../premium/premium_screen.dart';
import '../../premium/subscription_provider.dart';
import '../widgets/sport_card.dart';
import 'ai_equipment_scanner_screen.dart';
import 'workout_detail_screen.dart';
import '../workout_provider.dart';

class WorkoutListScreen extends StatelessWidget {
  const WorkoutListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Provider dipasang di sini supaya app.dart tidak perlu diubah.
    return ChangeNotifierProvider<WorkoutProvider>(
      create: (_) {
        final repository = SportRepository();
        return WorkoutProvider(
          repository: repository,
          store: SharedPrefsWorkoutPlanStore(repository: repository),
        )..load();
      },
      child: const _WorkoutListView(),
    );
  }
}

class _WorkoutListView extends StatefulWidget {
  const _WorkoutListView();

  @override
  State<_WorkoutListView> createState() => _WorkoutListViewState();
}

class _WorkoutListViewState extends State<_WorkoutListView> {
  final TextEditingController _searchController = TextEditingController();
  bool _isBannerDismissed = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilter() {
    _searchController.clear();
    context.read<WorkoutProvider>().resetFilter();
  }

  void _openPremium() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => const PremiumScreen()));
  }

  void _showDifficultyFilter(BuildContext context, WorkoutProvider provider) {
    final current = provider.filter.difficulty;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.outline,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                Row(
                  children: [
                    const Text(
                      'Tingkat Kesulitan',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    if (current != null)
                      TextButton(
                        onPressed: () {
                          provider.setDifficulty(null);
                          Navigator.pop(ctx);
                        },
                        child: const Text('Reset'),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: current == null
                      ? AppColors.surfaceHigh
                      : Colors.transparent,
                  title: const Text('Semua Tingkat Kesulitan'),
                  trailing: current == null
                      ? const Icon(Icons.check_rounded, color: AppColors.primary)
                      : null,
                  onTap: () {
                    provider.setDifficulty(null);
                    Navigator.pop(ctx);
                  },
                ),
                for (final d in Difficulty.values)
                  ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    tileColor: current == d
                        ? AppColors.surfaceHigh
                        : Colors.transparent,
                    title: Text(d.label),
                    trailing: current == d
                        ? const Icon(Icons.check_rounded, color: AppColors.primary)
                        : null,
                    onTap: () {
                      provider.setDifficulty(d);
                      Navigator.pop(ctx);
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// PBI-19.5: latihan premium hanya bisa dibuka pelanggan Plus.
  void _onSportTap(Sport sport) {
    final isPremiumUser = context.read<SubscriptionProvider>().isPremium;

    if (sport.isPremium && !isPremiumUser) {
      _showUpsell(sport);
      return;
    }

    final provider = context.read<WorkoutProvider>();
    provider.selectSport(sport);
    // Provider yang sama dibagikan ke halaman detail.
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider<WorkoutProvider>.value(
          value: provider,
          child: const WorkoutDetailScreen(),
        ),
      ),
    );
  }

  /// Lembar ajakan berlangganan untuk latihan yang terkunci.
  Future<void> _showUpsell(Sport sport) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.16),
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  color: AppColors.primary,
                  size: 30,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Latihan khusus FitMate Plus',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${sport.name} hanya tersedia untuk pelanggan Plus. '
                'Berlangganan untuk membuka semua jenis workout.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(sheetContext);
                  _openPremium();
                },
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Lihat FitMate Plus'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => Navigator.pop(sheetContext),
                child: const Text('Nanti saja'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        showCheckmark: false,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary.withValues(alpha: 0.28),
        backgroundColor: AppColors.surface,
        side: BorderSide(
          color: selected ? AppColors.primary : AppColors.outline,
        ),
        labelStyle: TextStyle(
          color: selected ? AppColors.textPrimary : AppColors.textSecondary,
          fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }

  /// Banner jumlah latihan terkunci, khusus pengguna Free dengan tombol silang (Revisi 21).
  Widget _buildUpgradeBanner(int lockedCount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_outline_rounded, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$lockedCount latihan terkunci. Berlangganan FitMate Plus untuk membukanya.',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
          TextButton(onPressed: _openPremium, child: const Text('Lihat')),
          IconButton(
            tooltip: 'Tutup Peringatan',
            icon: const Icon(Icons.close_rounded, size: 18),
            onPressed: () {
              setState(() {
                _isBannerDismissed = true;
              });
            },
          ),
        ],
      ),
    );
  }

  List<Widget> _buildResults(
    WorkoutProvider provider,
    List<Sport> sports, {
    required bool isPremiumUser,
  }) {
    if (provider.loading) {
      return const [
        Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        ),
      ];
    }

    if (provider.loadError != null) {
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline_rounded,
                size: 48,
                color: AppColors.tertiary,
              ),
              const SizedBox(height: 12),
              Text(
                provider.loadError!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
              TextButton(
                onPressed: provider.load,
                child: const Text('Coba lagi'),
              ),
            ],
          ),
        ),
      ];
    }

    final filter = provider.filter;
    final lockedCount = isPremiumUser
        ? 0
        : sports.where((sport) => sport.isPremium).length;

    return [
      // Peringatan latihan terkunci dengan tombol silang di kanan atas (Revisi 21)
      if (lockedCount > 0 && !_isBannerDismissed)
        _buildUpgradeBanner(lockedCount),

      // Tulisan 22 latihan berada di bawah peringatan (Revisi 21)
      Row(
        children: [
          Text(
            '${sports.length} latihan',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const Spacer(),
          if (filter.isActive)
            TextButton(onPressed: _resetFilter, child: const Text('Reset')),
        ],
      ),
      const SizedBox(height: 8),

      if (sports.isEmpty)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Icon(
                Icons.search_off_rounded,
                size: 56,
                color: AppColors.textSecondary,
              ),
              const SizedBox(height: 12),
              const Text(
                'Tidak ada latihan yang cocok',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Coba kata kunci atau filter lain.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
              TextButton(
                onPressed: _resetFilter,
                child: const Text('Reset filter'),
              ),
            ],
          ),
        )
      else
        ...sports.map(
          (sport) => _SportEntry(
            sport: sport,
            locked: sport.isPremium && !isPremiumUser,
            onTap: () => _onSportTap(sport),
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final isPremiumUser = context.watch<SubscriptionProvider>().isPremium;
    final filter = provider.filter;
    final sports = provider.sports;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          // Searchbar (bentuk disamakan komunitas) + Tombol Filter + Kamera AI (Revisi 18, 19, 20)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _searchController,
                    onChanged: provider.setQuery,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Cari nama, otot, atau alat...',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 13.5,
                      ),
                      prefixIcon: const Icon(
                        Icons.search,
                        color: Colors.white38,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear,
                                color: Colors.white38,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                provider.setQuery('');
                                setState(() {});
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.surface,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 0,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.outline),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.outline),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: AppColors.primary),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Tombol Filter Kesulitan (Revisi 19)
              Material(
                color: filter.difficulty != null
                    ? AppColors.primary
                    : AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _showDifficultyFilter(context, provider),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: filter.difficulty != null
                            ? AppColors.primary
                            : AppColors.outline,
                      ),
                    ),
                    child: Icon(
                      Icons.tune_rounded,
                      color: filter.difficulty != null
                          ? AppColors.neutral
                          : AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Tombol Kamera AI (Revisi 20)
              Material(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const AiEquipmentScannerScreen(),
                      ),
                    );
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.outline),
                    ),
                    child: const Icon(
                      Icons.camera_alt_rounded,
                      color: AppColors.secondary,
                      size: 22,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Kelompok Otot (Tingkat kesulitan di bawahnya sudah dihapus dan dijadikan tombol filter)
          _sectionLabel('Kelompok otot'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip(
                  'Semua',
                  filter.category == null,
                  () => provider.setCategory(null),
                ),
                for (final c in provider.categories)
                  _chip(c, filter.category == c, () => provider.setCategory(c)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._buildResults(provider, sports, isPremiumUser: isPremiumUser),
        ],
      ),
    );
  }
}

/// Kartu latihan. Jika terkunci: agak redup dengan ikon gembok di pojok.
/// Ketukan tetap diteruskan ke kartu, lalu ditangani oleh [onTap].
class _SportEntry extends StatelessWidget {
  const _SportEntry({
    required this.sport,
    required this.locked,
    required this.onTap,
  });

  final Sport sport;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Opacity(
          opacity: locked ? 0.6 : 1,
          child: SportCard(sport: sport, onTap: onTap),
        ),
        if (locked)
          Positioned(
            top: 12,
            right: 12,
            child: IgnorePointer(
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                ),
                child: const Icon(
                  Icons.lock_rounded,
                  size: 16,
                  color: Color(0xFF24110A),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
