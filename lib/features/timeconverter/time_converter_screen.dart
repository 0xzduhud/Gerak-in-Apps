import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/utils/timezone_converter.dart';
import '../../shared/wheel_time_picker.dart';
import '../schedule/schedule_form_screen.dart';
import '../schedule/schedule_form_screen.dart';

// [PBI-12.x] Halaman khusus "Konversi Waktu".
// Alur 3 langkah: (1) jam asal -> (2) zona tujuan -> (3) hasil.
class TimeConverterScreen extends StatefulWidget {
  const TimeConverterScreen({
    super.key,
    this.initialWall,
    this.initialFrom,
    this.initialTo,
  });

  final DateTime? initialWall;
  final AppTimeZone? initialFrom;
  final AppTimeZone? initialTo;

  @override
  State<TimeConverterScreen> createState() => _TimeConverterScreenState();
}

class _TimeConverterScreenState extends State<TimeConverterScreen> {
  late AppTimeZone _from;
  late AppTimeZone _to;
  late DateTime _date;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final base = widget.initialWall ?? DateTime.now();
    _from = widget.initialFrom ?? TimezoneConverter.wib;
    _to = widget.initialTo ?? TimezoneConverter.wita;
    _date = DateTime(base.year, base.month, base.day);
    _time = TimeOfDay(hour: base.hour, minute: base.minute);
  }

  DateTime get _wall =>
      DateTime(_date.year, _date.month, _date.day, _time.hour, _time.minute);

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2024),
      lastDate: DateTime(2035),
      initialEntryMode: DatePickerEntryMode.calendarOnly,
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showWheelTimePicker(
      context: context,
      initialTime: _time,
      title: 'Jam di ${_from.code}',
    );
    if (picked != null) setState(() => _time = picked);
  }

  void _swap() => setState(() {
        final t = _from;
        _from = _to;
        _to = t;
      });

  @override
  Widget build(BuildContext context) {
    final conv = TimezoneConverter.convert(_wall, _from, _to);
    final shift = TimezoneConverter.dayShiftLabel(conv.dayShift);

    return Scaffold(
      appBar: AppBar(title: const Text('Konversi Waktu')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const _IntroCard(),
          const SizedBox(height: 16),
          _StepCard(
            number: '1',
            title: 'Jam asal',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ZoneDropdown(
                  label: 'Jam ini ada di zona',
                  value: _from,
                  onChanged: (z) => setState(() => _from = z),
                ),
                const SizedBox(height: 12),
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
                        label: Text(
                          '${TimezoneConverter.formatTime(_wall)} ${_from.code}',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Center(
            child: TextButton.icon(
              onPressed: _swap,
              icon: const Icon(Icons.swap_vert_rounded),
              label: const Text('Tukar asal & tujuan'),
            ),
          ),
          _StepCard(
            number: '2',
            title: 'Zona tujuan',
            child: _ZoneDropdown(
              label: 'Ingin tahu jamnya di zona',
              value: _to,
              onChanged: (z) => setState(() => _to = z),
            ),
          ),
          const SizedBox(height: 16),
          _ResultCard(
            from: _from,
            to: _to,
            wall: _wall,
            resultTime: TimezoneConverter.formatTime(conv.time),
            resultDate: TimezoneConverter.formatDate(conv.time),
            shift: shift,
          ),
                    const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: () => ScheduleFormScreen.openNew(
              context,
              startAt: _wall,
              zone: _from,
            ),
            icon: const Icon(Icons.event_available_rounded),
            label: Text(
              'Jadikan jadwal latihan '
              '(${TimezoneConverter.formatTime(_wall)} ${_from.code})',
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Jam yang sama di semua zona',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          for (final z in TimezoneConverter.all)
            _CompareRow(
              zone: z,
              result: TimezoneConverter.convert(_wall, _from, z),
              isSource: z.code == _from.code,
              isTarget: z.code == _to.code,
            ),
          const SizedBox(height: 16),
          const _GuideCard(),
        ],
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.public_rounded, color: AppColors.secondary),
          SizedBox(width: 12),
          Expanded(
            child: Text(
                                                                                                                                                                                                                                                     
              'Cocokkan jam latihan dengan teman atau komunitas di zona waktu '
              'berbeda.\n'
              'Contoh: latihan jam 19:00 WIB = 20:00 WITA = 21:00 WIT.\n'
              'Hasilnya bisa langsung dijadikan jadwal workout.',
              style: TextStyle(height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.number,
    required this.title,
    required this.child,
  });

  final String number;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    number,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _ZoneDropdown extends StatelessWidget {
  const _ZoneDropdown({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final AppTimeZone value;
  final ValueChanged<AppTimeZone> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      key: ValueKey('$label-${value.code}'),
      initialValue: value.code,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final z in TimezoneConverter.all)
          DropdownMenuItem(
            value: z.code,
            child: Text('${z.name} • ${z.utcLabel}'),
          ),
      ],
      onChanged: (code) {
        if (code != null) onChanged(TimezoneConverter.byCode(code));
      },
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.from,
    required this.to,
    required this.wall,
    required this.resultTime,
    required this.resultDate,
    required this.shift,
  });

  final AppTimeZone from;
  final AppTimeZone to;
  final DateTime wall;
  final String resultTime;
  final String resultDate;
  final String shift;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary, width: 1.5),
      ),
      child: Column(
        children: [
          const Text(
            'Hasil konversi',
            style: TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 6),
          Text(
            '$resultTime ${to.code}',
            style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w800),
          ),
          Text(
            '$resultDate${shift.isEmpty ? '' : '  •  $shift'}',
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            TimezoneConverter.resultSentence(wall, from, to),
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            TimezoneConverter.differenceSentence(from, to),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _CompareRow extends StatelessWidget {
  const _CompareRow({
    required this.zone,
    required this.result,
    required this.isSource,
    required this.isTarget,
  });

  final AppTimeZone zone;
  final ConvertedTime result;
  final bool isSource;
  final bool isTarget;

  @override
  Widget build(BuildContext context) {
    final shift = TimezoneConverter.dayShiftLabel(result.dayShift);
    final tag = isSource ? 'asal' : (isTarget ? 'tujuan' : null);
    return Card(
      color: isTarget ? AppColors.surfaceHigh : AppColors.surface,
      child: ListTile(
        dense: true,
        title: Text('${zone.name} • ${zone.utcLabel}'),
        subtitle: tag == null ? null : Text(tag),
        trailing: Text(
          '${TimezoneConverter.formatTime(result.time)}'
          '${shift.isEmpty ? '' : ' ($shift)'}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _GuideCard extends StatelessWidget {
  const _GuideCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      child: const ExpansionTile(
        leading: Icon(Icons.help_outline_rounded, color: AppColors.secondary),
        title: Text('Cara menggunakan'),
        childrenPadding: EdgeInsets.fromLTRB(16, 0, 16, 16),
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '1. Pilih zona dan jam asal (mis. 19:00 di WIB).\n'
            '2. Pilih zona tujuan (mis. WIT).\n'
            '3. Hasil tampil otomatis di kotak oranye.\n'
            '4. Tombol "Tukar" membalik asal dan tujuan.\n\n'
            'Panduan cepat Indonesia:\n'
            '• WIB = UTC+7 (Jakarta)\n'
            '• WITA = UTC+8 (Makassar), 1 jam lebih cepat dari WIB\n'
            '• WIT = UTC+9 (Jayapura), 2 jam lebih cepat dari WIB\n\n'
            'Jika hasil berganti hari, muncul tanda "+1 hari" atau "-1 hari".\n'
            'Zona dengan daylight saving (London, New York, Sydney) '
            'belum didukung.',
            style: TextStyle(height: 1.5),
          ),
        ],
      ),
    );
  }
}