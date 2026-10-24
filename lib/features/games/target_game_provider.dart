import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:gerakinapps/core/services/game_local_db.dart';

enum TargetKind { healthy, junk, bomb }

/// Satu target di layar. [dx] dan [dy] berupa pecahan 0..1 dari area main,
/// sehingga logika tidak bergantung pada ukuran layar.
class GameTarget {
  const GameTarget({
    required this.id,
    required this.kind,
    required this.emoji,
    required this.dx,
    required this.dy,
    required this.expiresAt,
  });

  final int id;
  final TargetKind kind;
  final String emoji;
  final double dx;
  final double dy;
  final DateTime expiresAt;
}

/// Logika game Tangkap Target.
/// Aturan: sentuh makanan sehat untuk skor; makanan tidak sehat dan bom
/// mengurangi 1 nyawa (total 3 nyawa). Makanan sehat yang hilang sendiri
/// tidak berpengaruh. Level naik tiap 10 makanan sehat yang tertangkap.
class TargetGameProvider extends ChangeNotifier {
  TargetGameProvider({required this.userId, GameLocalDb? db})
    : _db = db ?? GameLocalDb();

  static const String gameKey = 'target';
  static const int maxLives = 3;
  static const int _catchPerLevel = 10;
  static const int _bombStartLevel = 3;
  static const Duration _endingDelay = Duration(seconds: 1);

  static const List<String> _healthyEmoji = [
    '🍎',
    '🥦',
    '🥕',
    '🍌',
    '🥑',
    '🍇',
    '🥗',
    '🍊',
  ];
  static const List<String> _junkEmoji = ['🍔', '🍟', '🍩', '🍕', '🥤', '🍭'];
  static const String _bombEmoji = '💣';

  final String userId;
  final GameLocalDb _db;
  final Random _rng = Random();

  int score = 0;
  int lives = maxLives;
  int level = 1;
  int caught = 0;
  int combo = 0;

  /// Skor tertinggi sebelum permainan ini dimulai.
  int bestScore = 0;

  /// Nyawa habis, menunggu jeda sebelum layar hasil.
  bool isEnding = false;
  bool isGameOver = false;
  List<GameTarget> targets = [];

  Timer? _ticker;
  DateTime _nextSpawn = DateTime.now();
  int _nextId = 0;
  bool _disposed = false;

  bool get isNewRecord => score > 0 && score > bestScore;

  // Parameter kesulitan per level.
  Duration get _spawnInterval =>
      Duration(milliseconds: max(450, 1100 - (level - 1) * 100));
  Duration get _lifetime =>
      Duration(milliseconds: max(900, 2200 - (level - 1) * 150));
  int get _maxOnScreen => min(6, 3 + level ~/ 2);
  double get _junkChance => min(0.5, 0.25 + (level - 1) * 0.04);
  double get _bombChance =>
      level >= _bombStartLevel ? min(0.15, 0.05 + (level - 3) * 0.02) : 0.0;

  bool get bombsActive => level >= _bombStartLevel;

  void start() {
    _ticker?.cancel();
    score = 0;
    lives = maxLives;
    level = 1;
    caught = 0;
    combo = 0;
    isEnding = false;
    isGameOver = false;
    targets = [];
    _nextSpawn = DateTime.now().add(const Duration(milliseconds: 600));
    _ticker = Timer.periodic(const Duration(milliseconds: 100), _tick);
    _loadBest();
    notifyListeners();
  }

  Future<void> _loadBest() async {
    try {
      final best = await _db.getHighScore(userId, gameKey);
      if (_disposed) return;
      bestScore = best;
      notifyListeners();
    } catch (e) {
      debugPrint('Gagal memuat high score: $e');
    }
  }

  void _tick(Timer timer) {
    final now = DateTime.now();
    var changed = false;

    final before = targets.length;
    targets = targets.where((t) => t.expiresAt.isAfter(now)).toList();
    if (targets.length != before) changed = true;

    if (!now.isBefore(_nextSpawn) && targets.length < _maxOnScreen) {
      _spawn(now);
      changed = true;
    }

    if (changed) notifyListeners();
  }

  void _spawn(DateTime now) {
    final roll = _rng.nextDouble();
    final TargetKind kind;
    final String emoji;

    if (roll < _bombChance) {
      kind = TargetKind.bomb;
      emoji = _bombEmoji;
    } else if (roll < _bombChance + _junkChance) {
      kind = TargetKind.junk;
      emoji = _junkEmoji[_rng.nextInt(_junkEmoji.length)];
    } else {
      kind = TargetKind.healthy;
      emoji = _healthyEmoji[_rng.nextInt(_healthyEmoji.length)];
    }

    targets = [
      ...targets,
      GameTarget(
        id: _nextId++,
        kind: kind,
        emoji: emoji,
        dx: _rng.nextDouble(),
        dy: _rng.nextDouble(),
        expiresAt: now.add(_lifetime),
      ),
    ];
    _nextSpawn = now.add(_spawnInterval);
  }

  /// Dipanggil saat target disentuh. Mengembalikan jenis target
  /// (untuk getaran/feedback), atau null bila target sudah hilang.
  TargetKind? tap(int id) {
    if (isEnding || isGameOver) return null;
    final index = targets.indexWhere((t) => t.id == id);
    if (index < 0) return null;

    final target = targets[index];
    targets = [...targets]..removeAt(index);

    if (target.kind == TargetKind.healthy) {
      combo++;
      score += 10 + min(combo - 1, 5) * 2;
      caught++;
      if (caught % _catchPerLevel == 0) level++;
    } else {
      combo = 0;
      lives--;
      if (lives <= 0) {
        lives = 0;
        _endGame();
      }
    }

    notifyListeners();
    return target.kind;
  }

  void _endGame() {
    isEnding = true;
    _ticker?.cancel();
    Future.delayed(_endingDelay, () {
      if (_disposed) return;
      isGameOver = true;
      targets = [];
      notifyListeners();
    });
  }

  /// Menyimpan hasil ke SQLite. Tidak melempar error agar demo di web tetap jalan.
  Future<void> saveResult() async {
    try {
      await _db.insertScore(
        userId,
        game: gameKey,
        score: score,
        level: level,
        extra: caught,
      );
    } catch (e) {
      debugPrint('Gagal menyimpan skor game: $e');
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    super.dispose();
  }
}
