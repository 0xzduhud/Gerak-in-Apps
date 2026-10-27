import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/activity_model.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/sport_repository.dart';

/// [PBI-10.5] Menyaring riwayat berdasarkan olahraga. null = semua.
List<ActivitySummary> filterBySport(
  List<ActivitySummary> items,
  String? sportId,
) =>
    sportId == null
        ? items
        : items.where((a) => a.sportId == sportId).toList();

String _two(int v) => v.toString().padLeft(2, '0');
String _date(DateTime d) => '${_two(d.day)}/${_two(d.month)}/${d.year}';
String _dateTime(DateTime d) =>
    '${_date(d)}  ${_two(d.hour)}:${_two(d.minute)}';

String _duration(int seconds) {
  final m = seconds ~/ 60;
  return m > 0 ? '$m mnt' : '$seconds dtk';
}

// ============================================================================
// [PBI-10.4] HistorySection — daftar riwayat aktivitas di halaman Progress
// [PBI-10.5] Filter tanggal dan jenis olahraga
// ============================================================================
class HistorySection extends StatefulWidget {
  const HistorySection({super.key});

  @override
  State<HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends State<HistorySection> {
  static const int _maxShown = 50;

  final ActivityRepository _activities = ActivityRepository();
  final SportRepository _sports = SportRepository();

  late DateTimeRange _range;
  String? _sportId;
  List<ActivitySummary> _all = const [];
  Map<String, String> _sportNames = const {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    final end = DateTime(today.year, today.month, today.day);
    _range = DateTimeRange(
      start: end.subtract(const Duration(days: 29)),
      end: end,
    );
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await _activities.history(
        from: _range.start,
        to: _range.end,
      );
      var names = _sportNames;
      if (names.isEmpty) {
        try {
          final sports = await _sports.loadAll();
          names = {for (final s in sports) s.id: s.name};
        } catch (_) {
          // Nama olahraga tidak wajib; id akan ditampilkan apa adanya.
        }
      }
      if (!mounted) return;
      setState(() {
        _all = items;
        _sportNames = names;
        // Jika olahraga yang dipilih tidak ada di rentang baru, reset filter.
        if (_sportId != null && !items.any((a) => a.sportId == _sportId)) {
          _sportId = null;
        }
        _loading = false;
      });
    } catch (e) {
      debugPrint('Gagal memuat riwayat: $e');
      if (!mounted) return;
      setState(() {
        _error = 'Riwayat belum bisa dimuat.';
        _loading = false;
      });
    }
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year, now.month, now.day),
      initialDateRange: _range,
    );
    if (picked == null) return;
    _range = picked;
    await _load();
  }

  String _nameOf(String? id) {
    if (id == null) return 'Aktivitas bebas';
    return _sportNames[id] ?? id;
  }

  @override
  Widget build(BuildContext context) {
    final shownAll = filterBySport(_all, _sportId);
    final shown = shownAll.take(_maxShown).toList();
    final sportIds = <String>{
      for (final a in _all)
        if (a.sportId != null) a.sportId!,
    }.toList()
      ..sort((a, b) => _nameOf(a).compareTo(_nameOf(b)));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),
        Row(
          children: [
            const Expanded(
              child: Text(
                'Riwayat aktivitas',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Muat ulang',
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 8),
        // ---- Filter (PBI-10.5) ----
        Wrap(
          spacing: 10,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              onPressed: _pickRange,
              icon: const Icon(Icons.date_range_rounded, size: 18),
              label: Text('${_date(_range.start)} - ${_date(_range.end)}'),
            ),
            if (sportIds.isNotEmpty)
              DropdownButton<String?>(
                value: _sportId,
                hint: const Text('Semua olahraga'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Semua olahraga'),
                  ),
                  for (final id in sportIds)
                    DropdownMenuItem<String?>(
                      value: id,
                      child: Text(_nameOf(id)),
                    ),
                ],
                onChanged: (v) => setState(() => _sportId = v),
              ),
          ],
        ),
        const SizedBox(height: 12),
        // ---- Daftar (PBI-10.4) ----
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_error != null)
          Text(_error!, style: const TextStyle(color: AppColors.tertiary))
        else if (shown.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child: Text(
                'Belum ada aktivitas pada filter ini.',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          )
        else ...[
          for (final a in shown)
            _HistoryTile(item: a, title: _nameOf(a.sportId)),
          if (shownAll.length > _maxShown)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Menampilkan $_maxShown terbaru dari ${shownAll.length}. '
                'Persempit rentang tanggal untuk melihat lainnya.',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.item, required this.title});

  final ActivitySummary item;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.directions_run_rounded, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _dateTime(item.startedAt),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${item.steps} langkah',
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondary,
                ),
              ),
              Text(
                '${_duration(item.durationSeconds)} • '
                '${item.calories.round()} kkal',
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}