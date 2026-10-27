import 'package:flutter_test/flutter_test.dart';
import 'package:gerakinapps/data/models/sport_model.dart';
import 'package:gerakinapps/features/workout/guided_session_provider.dart';
import 'package:gerakinapps/features/workout/session_spec.dart';

const _sport = Sport(
  id: 'bench-press',
  name: 'Bench Press',
  category: 'Dada',
  difficulty: Difficulty.pemula,
  equipment: 'Barbell',
  sets: 3,
  reps: '8–12',
  kcalPerMinute: 6,
  description: '',
  youtubeQuery: '',
);

const _repsSpec = SessionSpec(
  kind: SessionKind.reps,
  sets: 3,
  restSeconds: 60,
  targetReps: 12,
);

const _timedSpec = SessionSpec(
  kind: SessionKind.timed,
  sets: 2,
  restSeconds: 30,
  targetSeconds: 30,
);

void main() {
  late DateTime now;
  late int cues;

  GuidedSessionProvider make(SessionSpec spec) {
    final p = GuidedSessionProvider(
      sport: _sport,
      spec: spec,
      now: () => now,
      onCue: () => cues++,
    );
    addTearDown(p.dispose);
    return p;
  }

  void advance(int seconds) => now = now.add(Duration(seconds: seconds));

  setUp(() {
    now = DateTime(2026, 11, 3, 8);
    cues = 0;
  });

  group('PBI-7 sesi repetisi', () {
    test('mulai -> fase kerja, set 1', () {
      final p = make(_repsSpec);
      expect(p.phase, GuidedPhase.ready);
      p.start();
      expect(p.phase, GuidedPhase.work);
      expect(p.setNumber, 1);
      expect(p.setReps, 0);
    });

    test('hitung manual dan tidak bisa di bawah 0', () {
      final p = make(_repsSpec)..start();
      p.adjustReps(3);
      expect(p.setReps, 3);
      p.adjustReps(-10);
      expect(p.setReps, 0);
    });

    test('selesai set -> istirahat dengan hitung mundur', () {
      final p = make(_repsSpec)..start();
      p.adjustReps(10);
      p.completeSet();
      expect(p.phase, GuidedPhase.rest);
      expect(p.doneReps, [10]);
      expect(p.setNumber, 2);
      expect(p.remainingSeconds, 60);
      advance(20);
      expect(p.remainingSeconds, 40);
    });

    test('repetisi tidak bisa diubah saat istirahat', () {
      final p = make(_repsSpec)..start();
      p.completeSet();
      p.adjustReps(5);
      expect(p.setReps, 10 * 0);
    });

    test('istirahat habis -> otomatis set berikutnya dan berbunyi', () {
      final p = make(_repsSpec)..start();
      p.adjustReps(10);
      p.completeSet();
      advance(61);
      p.tick();
      expect(p.phase, GuidedPhase.work);
      expect(p.setNumber, 2);
      expect(p.setReps, 0);
      expect(cues, 1);
    });

    test('lewati istirahat dan atur sisa istirahat', () {
      final p = make(_repsSpec)..start();
      p.completeSet();
      p.adjustRest(15);
      expect(p.remainingSeconds, 75);
      p.skipRest();
      expect(p.phase, GuidedPhase.work);
      expect(cues, 0);
    });

    test('set terakhir selesai -> sesi selesai dan ringkasan benar', () {
      final p = make(_repsSpec)..start();
      p.adjustReps(10);
      advance(60);
      p.completeSet(); // set 1 selesai, istirahat mulai di detik 60
      advance(61);
      p.tick(); // masuk set 2
      p.adjustReps(8);
      advance(60);
      p.completeSet(); // istirahat
      p.skipRest(); // set 3
      p.adjustReps(5);
      advance(30);
      p.completeSet(); // set terakhir
      expect(p.phase, GuidedPhase.finished);
      final s = p.toSummary()!;
      expect(s.reps, 23);
      expect(s.durationSeconds, 211);
      expect(s.sportId, 'bench-press');
      expect(s.motionType, isNull);
      expect(s.steps, 0);
      expect(s.calories, closeTo(6 * 211 / 60, 1e-9));
    });

    test('akhiri lebih awal: repetisi set berjalan ikut dihitung', () {
      final p = make(_repsSpec)..start();
      p.adjustReps(7);
      advance(40);
      p.finish();
      expect(p.phase, GuidedPhase.finished);
      expect(p.toSummary()!.reps, 7);
    });

    test('tanpa repetisi dan < 5 detik -> tidak ada ringkasan', () {
      final p = make(_repsSpec)..start();
      advance(2);
      p.finish();
      expect(p.toSummary(), isNull);
    });

    test('belum selesai -> tidak ada ringkasan', () {
      final p = make(_repsSpec)..start();
      expect(p.toSummary(), isNull);
    });
  });

  group('PBI-7 jeda', () {
    test('waktu berhenti saat jeda dan lanjut saat dilanjutkan', () {
      final p = make(_repsSpec)..start();
      advance(10);
      p.pause();
      advance(100);
      expect(p.elapsed.inSeconds, 10);
      p.resume();
      advance(5);
      expect(p.elapsed.inSeconds, 15);
    });

    test('hitung mundur istirahat ikut berhenti saat jeda', () {
      final p = make(_repsSpec)..start();
      p.completeSet();
      advance(20);
      p.pause();
      advance(500);
      p.tick(); // tidak boleh pindah fase saat jeda
      expect(p.phase, GuidedPhase.rest);
      expect(p.remainingSeconds, 40);
    });

    test('repetisi tidak berubah saat jeda', () {
      final p = make(_repsSpec)..start();
      p.pause();
      p.adjustReps(3);
      expect(p.setReps, 0);
    });
  });

  group('PBI-7 sesi berwaktu', () {
    test('set berakhir otomatis saat hitung mundur habis', () {
      final p = make(_timedSpec)..start();
      expect(p.remainingSeconds, 30);
      advance(31);
      p.tick();
      expect(p.phase, GuidedPhase.rest);
      expect(cues, 1);
      expect(p.doneReps, [0]);
    });

    test('selesai semua set -> ringkasan tanpa repetisi tapi ada durasi', () {
      final p = make(_timedSpec)..start();
      advance(31);
      p.tick(); // set 1 selesai, istirahat
      advance(31);
      p.tick(); // set 2
      advance(31);
      p.tick(); // set 2 selesai -> selesai
      expect(p.phase, GuidedPhase.finished);
      final s = p.toSummary()!;
      expect(s.reps, 0);
      expect(s.durationSeconds, 93);
    });
  });
}