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
  const target = DailyTarget(steps: 8000, durationMinutes: 30, calories: 300);

  testWidgets('tanpa progress: indikator tidak tampil', (tester) async {
    await tester.pumpWidget(_wrap(const DailyActivityCard(steps: 100)));
    expect(find.textContaining('target tercapai'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('sebagian target tercapai', (tester) async {
    final p = TargetProgress.from(target, const DailyTotals(steps: 8000));
    await tester.pumpWidget(
      _wrap(DailyActivityCard(steps: 8000, progress: p)),
    );
    expect(find.text('1 dari 3 target tercapai'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('semua target tercapai', (tester) async {
    final p = TargetProgress.from(
      target,
      const DailyTotals(steps: 8000, durationSeconds: 1800, calories: 300),
    );
    await tester.pumpWidget(
      _wrap(DailyActivityCard(steps: 8000, calories: 300, progress: p)),
    );
    expect(find.text('Target hari ini tercapai!'), findsOneWidget);
    expect(find.text('100%'), findsOneWidget);
  });
}