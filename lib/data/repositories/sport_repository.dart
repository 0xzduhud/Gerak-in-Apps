import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../models/sport_model.dart';

class SportRepository {
  static const _seedPath = 'assets/data/sports_seed.json';

  List<Sport>? _cache;

  /// Sementara dari seed lokal. Setelah API master olahraga (Sprint 3)
  /// siap, tambahkan pengambilan dari server di sini.
  Future<List<Sport>> loadAll() async {
    final cached = _cache;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString(_seedPath);
    final result = parse(raw);
    _cache = result;
    return result;
  }

  static List<Sport> parse(String raw) {
    final list = jsonDecode(raw) as List<dynamic>;
    return list.map((e) => Sport.fromJson(e as Map<String, dynamic>)).toList();
  }
}
