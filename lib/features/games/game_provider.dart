import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// State untuk game kuis. (Mode Tebak Gerakan sudah dihapus;
/// game Tangkap Target punya provider sendiri di target_game_provider.dart.)
class GameProvider extends ChangeNotifier {
  int score = 0;
  int currentQuestionIndex = 0;
  int timeLeft = 15;
  bool isQuizFinished = false;
  List<dynamic> activeQuestions = [];
  int? selectedAnswerIndex;
  bool isAnswering = false;
  Timer? _timer;

  // Memuat data kuis dari JSON
  Future<void> loadTextQuizData() async {
    try {
      final String response = await rootBundle.loadString(
        'assets/data/quiz_bank.json',
      );
      final data = json.decode(response);
      if (data is List) {
        activeQuestions = data;
      } else if (data is Map) {
        activeQuestions = data['questions'] ?? [];
      } else {
        activeQuestions = [];
      }
      notifyListeners();
    } catch (e) {
      debugPrint("Error loading JSON: $e");
    }
  }

  // Memulai permainan (reset semua nilai)
  Future<void> startGame() async {
    _timer?.cancel();
    score = 0;
    currentQuestionIndex = 0;
    timeLeft = 15;
    isQuizFinished = false;
    activeQuestions = [];
    selectedAnswerIndex = null;
    isAnswering = false;

    await loadTextQuizData();

    _startTimer();
    notifyListeners();
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (timeLeft > 0) {
        timeLeft--;
        notifyListeners();
      } else {
        _nextQuestion();
      }
    });
  }

  void checkAnswer(int selectedIndex) {
    if (isAnswering || isQuizFinished || activeQuestions.isEmpty) return;

    isAnswering = true;
    selectedAnswerIndex = selectedIndex;
    notifyListeners();

    _timer?.cancel();

    int correctIndex = activeQuestions[currentQuestionIndex]['answer'];
    if (selectedIndex == correctIndex) {
      score += 10;
    }

    Future.delayed(const Duration(milliseconds: 1500), () {
      isAnswering = false;
      selectedAnswerIndex = null;
      _nextQuestion();
    });
  }

  void _nextQuestion() {
    _timer?.cancel();
    if (currentQuestionIndex < activeQuestions.length - 1) {
      currentQuestionIndex++;
      timeLeft = 15;
      _startTimer();
    } else {
      isQuizFinished = true;
    }
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
