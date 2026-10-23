import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/theme.dart';
import '../../../data/models/sport_model.dart';
import '../../../data/repositories/sport_repository.dart';
import '../widgets/sport_card.dart';
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilter() {
    _searchController.clear();
    context.read<WorkoutProvider>().resetFilter();
  }

    void _onSportTap(Sport sport) {
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

  List<Widget> _buildResults(WorkoutProvider provider, List<Sport> sports) {
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

    return [
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
      const SizedBox(height: 4),
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
          (sport) => SportCard(sport: sport, onTap: () => _onSportTap(sport)),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WorkoutProvider>();
    final filter = provider.filter;
    final sports = provider.sports;

    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          const Text(
            'Workout',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Cari dan pilih latihan yang sesuai targetmu.',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _searchController,
            onChanged: provider.setQuery,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Cari nama, otot, atau alat',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: filter.query.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        provider.setQuery('');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 16),
          _sectionLabel('Kelompok otot'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Semua', filter.category == null,
                    () => provider.setCategory(null)),
                for (final c in provider.categories)
                  _chip(c, filter.category == c, () => provider.setCategory(c)),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _sectionLabel('Tingkat kesulitan'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('Semua', filter.difficulty == null,
                    () => provider.setDifficulty(null)),
                for (final d in Difficulty.values)
                  _chip(d.label, filter.difficulty == d,
                      () => provider.setDifficulty(d)),
              ],
            ),
          ),
          const SizedBox(height: 16),
          ..._buildResults(provider, sports),
        ],
      ),
    );
  }
}