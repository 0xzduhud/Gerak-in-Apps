import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class GameProvider extends ChangeNotifier {
  int score = 0;
  int currentQuestionIndex = 0;
  int timeLeft = 15;
  bool isQuizFinished = false;
  bool isGuessMoveMode = false;
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

  // Memuat data dummy untuk tebak gerakan
  void loadGuessMoveData() {
    activeQuestions = [
      {
        "question":
            "Apa nama gerakan mendorong tubuh ke atas dengan tumpuan telapak tangan ini?",
        "image_url":
            "https://media.giphy.com/media/KzJxl2IjVyBRz2l492/giphy.gif",
        "options": ["Push-up", "Pull-up", "Sit-up", "Plank"],
        "answer": 0,
      },
      {
        "question":
            "Gerakan melipat lutut dan menurunkan pinggul seperti duduk disebut apa?",
        "image_url":
            "https://media.giphy.com/media/xT8qBvH1pAhtfLl52s/giphy.gif",
        "options": ["Jumping Jack", "Burpee", "Squat", "Lunges"],
        "answer": 2,
      },
      {
        "question":
            "Latihan menahan posisi tubuh sejajar lurus secara isometrik ini adalah?",
        "image_url":
            "https://media.giphy.com/media/3o7TKrEzvPNBgVA9iM/giphy.gif",
        "options": ["Crunches", "Plank", "Mountain Climber", "Russian Twist"],
        "answer": 1,
      },
      {
        "question":
            "Latihan melompat membuka-tutup tangan dan kaki secara ritmis dinamakan apa?",
        "image_url":
            "https://media.giphy.com/media/3o6Zt8sbgF4pB5Y2lq/giphy.gif",
        "options": ["High Knees", "Jumping Jack", "Burpee", "Box Jump"],
        "answer": 1,
      },
      {
        "question":
            "Gerakan melangkah satu kaki ke depan dan menekuk kedua lutut dikenal sebagai?",
        "image_url":
            "https://media.giphy.com/media/l41lM4oXWqNn0K1vW/giphy.gif",
        "options": ["Calf Raise", "Deadlift", "Leg Curl", "Lunges"],
        "answer": 3,
      },
    ];
    notifyListeners();
  }

  // Memulai permainan (reset semua nilai)
  Future<void> startGame({required bool isGuessMove}) async {
    _timer?.cancel();
    score = 0;
    currentQuestionIndex = 0;
    timeLeft = 15;
    isQuizFinished = false;
    isGuessMoveMode = isGuessMove;
    activeQuestions = [];
    selectedAnswerIndex = null;
    isAnswering = false;

    if (isGuessMoveMode) {
      loadGuessMoveData();
    } else {
      await loadTextQuizData();
    }

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
