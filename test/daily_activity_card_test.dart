import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/data/models/target_model.dart';
// ignore: avoid_relative_lib_imports
import '../lib/data/repositories/activity_repository.dart' show DailyTotals;
// ignore: avoid_relative_lib_imports
import '../lib/features/home/home_widgets.dart';

Widget _wrap(Widget child) =>
    MaterialApp(home: Scaffold(body: SingleChildScrollView(child: child)));

void main() {
  const target = DailyTarget(
    steps: 8000,
    durationMinutes: 30,
    calories: 300,
    reps: 50,
  );

  testWidgets('menampilkan menit, kalori, repetisi, dan jumlah sesi',
      (tester) async {
    await tester.pumpWidget(
      _wrap(
        const DailyActivityCard(
          durationMinutes: 25,
          calories: 120,
          reps: 40,
          sessions: 2,
        ),
      ),
    );
    expect(find.text('25'), findsOneWidget);
    expect(find.text('120'), findsOneWidget);
    expect(find.text('40'), findsOneWidget);
    expect(find.text('Menit latihan'), findsOneWidget);
    expect(find.text('Repetisi'), findsOneWidget);
    expect(find.text('2 sesi'), findsOneWidget);
  });

  testWidgets('belum ada latihan', (tester) async {
    await tester.pumpWidget(_wrap(const DailyActivityCard()));
    expect(find.text('Belum ada latihan hari ini'), findsOneWidget);
  });

  testWidgets('langkah dan jarak hanya tampil bila ada', (tester) async {
    await tester.pumpWidget(
      _wrap(const DailyActivityCard(sessions: 1, durationMinutes: 5)),
    );
    expect(find.textContaining('langkah'), findsNothing);

    await tester.pumpWidget(
      _wrap(
        const DailyActivityCard(
          sessions: 1,
          steps: 1200,
          distanceKm: 0.9,
        ),
      ),
    );
    expect(find.text('1 sesi • 1200 langkah • 0.9 km'), findsOneWidget);
  });

  testWidgets('tanpa progress: indikator tidak tampil', (tester) async {
    await tester.pumpWidget(
      _wrap(const DailyActivityCard(durationMinutes: 10)),
    );
    expect(find.textContaining('target tercapai'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('tanpa target aktif: indikator disembunyikan', (tester) async {
    final p = TargetProgress.from(
      const DailyTarget(steps: 0, durationMinutes: 0, calories: 0, reps: 0),
      const DailyTotals(reps: 10),
    );
    await tester.pumpWidget(_wrap(DailyActivityCard(progress: p)));
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('sebagian target tercapai', (tester) async {
    final p = TargetProgress.from(
      target,
      const DailyTotals(durationSeconds: 1800),
    );
    await tester.pumpWidget(
      _wrap(DailyActivityCard(durationMinutes: 30, progress: p)),
    );
    expect(find.text('1 dari 4 target tercapai'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('semua target tercapai', (tester) async {
    final p = TargetProgress.from(
      target,
      const DailyTotals(
        steps: 8000,
        durationSeconds: 1800,
        calories: 300,
        reps: 50,
      ),
    );
    await tester.pumpWidget(
      _wrap(DailyActivityCard(durationMinutes: 30, calories: 300, progress: p)),
    );
    expect(find.text('Target hari ini tercapai!'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });
}