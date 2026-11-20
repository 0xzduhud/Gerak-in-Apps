import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils/timezone_converter.dart';
import '../../data/models/schedule_model.dart';
import 'schedule_form_screen.dart';
import 'schedule_provider.dart';
import '../../core/services/notification_service.dart';
import '../timeconverter/time_converter_screen.dart';

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
      body: Column(
        children: [
          if (!p.notificationsEnabled) const _NotificationOffBanner(),
          const _ConverterBanner(),
          Expanded(child: _body(context, p)),
        ],
      ),
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
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.public_rounded, color: AppColors.secondary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Jam ditampilkan dalam ${p.displayZone.name} '
                    '(${p.displayZone.utcLabel}).\n'
                    'Ubah lewat ikon globe di kanan atas.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
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
            leading: Checkbox(value: s.done, onChanged: (_) => p.toggleDone(s)),
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
              trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                  TextButton.icon(
                  icon: const Icon(Icons.swap_horiz_rounded, size: 18),
                  label: const Text('Konversi'),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => TimeConverterScreen(
                        initialWall: s.startAt,
                        initialFrom: s.zone,
                        initialTo: sameZone
                            ? TimezoneConverter.all
                                .firstWhere((z) => z.code != s.zone.code)
                            : p.displayZone,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () => _confirmDelete(context, s),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// [PBI-13B] Peringatan jika izin notifikasi dimatikan.
class _NotificationOffBanner extends StatelessWidget {
  const _NotificationOffBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.surfaceHigh,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.notifications_off_rounded,
            color: AppColors.secondary,
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Notifikasi dimatikan, pengingat tidak akan berbunyi.',
              style: TextStyle(fontSize: 13),
            ),
          ),
          TextButton(
            onPressed: () => NotificationService.instance.openSettings(),
            child: const Text('Aktifkan'),
          ),
        ],
      ),
    );
  }
}

class _ConverterBanner extends StatelessWidget {
  const _ConverterBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => const TimeConverterScreen(),
            ),
          ),
          child: const Padding(
            padding: EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(Icons.swap_horiz_rounded, color: AppColors.secondary),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Konversi Waktu',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Cek jam latihan ini di WIB, WITA, atau WIT '
                        'untuk teman di zona lain.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}