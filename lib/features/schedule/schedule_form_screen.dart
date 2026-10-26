import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/utils/timezone_converter.dart';
import '../../data/models/schedule_model.dart';
import 'schedule_provider.dart';

// [PBI-12.x] Form tambah/ubah jadwal + pratinjau konversi zona waktu.
class ScheduleFormScreen extends StatefulWidget {
  const ScheduleFormScreen({super.key, this.initial});

  final WorkoutSchedule? initial;

  @override
  State<ScheduleFormScreen> createState() => _ScheduleFormScreenState();
}

class _ScheduleFormScreenState extends State<ScheduleFormScreen> {
  late final TextEditingController _title;
  late final TextEditingController _note;
  late DateTime _date;
  late TimeOfDay _time;
  late AppTimeZone _zone;
  late double _duration;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final s = widget.initial;
    final base = s?.startAt ?? DateTime.now().add(const Duration(hours: 1));
    _title = TextEditingController(text: s?.title ?? '');
    _note = TextEditingController(text: s?.note ?? '');
    _date = DateTime(base.year, base.month, base.day);
    _time = TimeOfDay(hour: base.hour, minute: base.minute);
    _zone = s?.zone ?? context.read<ScheduleProvider>().displayZone;
    _duration = (s?.durationMinutes ?? 30).toDouble();
  }

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  DateTime get _wall =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _save() async {
    final provider = context.read<ScheduleProvider>();
    final schedule = WorkoutSchedule(
      id: widget.initial?.id,
      title: _title.text,
      startAt: _wall,
      zoneCode: _zone.code,
      durationMinutes: _duration.round(),
      note: _note.text.trim(),
      done: widget.initial?.done ?? false,
    );
    setState(() => _saving = true);
    final ok = await provider.save(schedule);
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(provider.lastSaveError ?? 'Gagal menyimpan.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final display = context.watch<ScheduleProvider>().displayZone;
    final conv = TimezoneConverter.convert(_wall, _zone, display);
    final shift = TimezoneConverter.dayShiftLabel(conv.dayShift);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.initial == null ? 'Tambah Jadwal' : 'Ubah Jadwal'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Judul (mis. Lari pagi)',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(TimezoneConverter.formatDate(_date)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickTime,
                  icon: const Icon(Icons.schedule_rounded, size: 18),
                  label: Text(TimezoneConverter.formatTime(_wall)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _zone.code,
            decoration: const InputDecoration(labelText: 'Zona waktu jadwal'),
            items: [
              for (final z in TimezoneConverter.all)
                DropdownMenuItem(
                  value: z.code,
                  child: Text('${z.name} • ${z.utcLabel}'),
                ),
            ],
            onChanged: (code) {
              if (code != null) {
                setState(() => _zone = TimezoneConverter.byCode(code));
              }
            },
          ),
          if (_zone.code != display.code) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surfaceHigh,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(Icons.swap_horiz_rounded,
                      color: AppColors.secondary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Di ${display.code}: '
                      '${TimezoneConverter.formatTime(conv.time)}'
                      '${shift.isEmpty ? '' : ' ($shift)'}',
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Text('Durasi: ${_duration.round()} menit'),
          Slider(
            value: _duration,
            min: WorkoutSchedule.minDuration.toDouble(),
            max: WorkoutSchedule.maxDuration.toDouble(),
            divisions: 47,
            onChanged: (v) => setState(() => _duration = v),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _note,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Catatan (opsional)'),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Menyimpan...' : 'Simpan'),
          ),
        ],
      ),
    );
  }
}