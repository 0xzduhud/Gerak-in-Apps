import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils/timezone_converter.dart';
import '../../data/models/schedule_model.dart';
import 'schedule_form_screen.dart';
import 'schedule_provider.dart';

// [PBI-12.x] Daftar jadwal workout dengan pilihan zona waktu tampilan.
class ScheduleScreen extends StatelessWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ScheduleProvider>(
      create: (_) => ScheduleProvider()..load(),
      child: const _ScheduleView(),
    );
  }
}

class _ScheduleView extends StatelessWidget {
  const _ScheduleView();

  void _openForm(BuildContext context, [WorkoutSchedule? initial]) {
    final provider = context.read<ScheduleProvider>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ChangeNotifierProvider<ScheduleProvider>.value(
          value: provider,
          child: ScheduleFormScreen(initial: initial),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WorkoutSchedule s) async {
    final provider = context.read<ScheduleProvider>();
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus jadwal?'),
        content: Text(s.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (yes == true) await provider.delete(s);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<ScheduleProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule'),
        actions: [
          PopupMenuButton<AppTimeZone>(
            tooltip: 'Zona waktu tampilan',
            icon: const Icon(Icons.public_rounded),
            onSelected: p.setDisplayZone,
            itemBuilder: (_) => [
              for (final z in TimezoneConverter.all)
                CheckedPopupMenuItem(
                  value: z,
                  checked: z.code == p.displayZone.code,
                  child: Text('${z.name} • ${z.utcLabel}'),
                ),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Jadwal'),
      ),
      body: _body(context, p),
    );
  }

  Widget _body(BuildContext context, ScheduleProvider p) {
    if (p.loading) return const Center(child: CircularProgressIndicator());
    if (p.error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(p.error!),
            const SizedBox(height: 8),
            OutlinedButton(onPressed: p.load, child: const Text('Coba lagi')),
          ],
        ),
      );
    }
    if (p.items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Belum ada jadwal.\nKetuk "+ Jadwal" untuk menambahkan.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      itemCount: p.items.length + 1,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        if (i == 0) {
          return Text(
            'Waktu ditampilkan dalam ${p.displayZone.name} '
            '(${p.displayZone.utcLabel})',
            style: const TextStyle(color: AppColors.textSecondary),
          );
        }
        final s = p.items[i - 1];
        final conv = TimezoneConverter.convert(
          s.startAt,
          s.zone,
          p.displayZone,
        );
        final shift = TimezoneConverter.dayShiftLabel(conv.dayShift);
        final sameZone = s.zone.code == p.displayZone.code;

        return Card(
          color: AppColors.surface,
          child: ListTile(
            onTap: () => _openForm(context, s),
            leading: Checkbox(
              value: s.done,
              onChanged: (_) => p.toggleDone(s),
            ),
            title: Text(
              s.title,
              style: TextStyle(
                decoration: s.done ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Text(
              '${TimezoneConverter.formatDate(conv.time)} • '
              '${TimezoneConverter.formatTime(conv.time)} '
              '${p.displayZone.code}'
              '${shift.isEmpty ? '' : ' ($shift)'} • ${s.durationMinutes} mnt'
              '${sameZone ? '' : '\nAsli: ${TimezoneConverter.formatTime(s.startAt)} ${s.zone.code}'}',
            ),
            isThreeLine: !sameZone,
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => _confirmDelete(context, s),
            ),
          ),
        );
      },
    );
  }
}