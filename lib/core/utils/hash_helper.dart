import 'dart:convert';

import 'package:crypto/crypto.dart';

/// Fungsi hash yang dipakai rantai blok achievement.
class HashHelper {
  HashHelper._();

  /// SHA-256 dari [input], dikembalikan sebagai 64 karakter heksadesimal.
  static String sha256Hex(String input) {
    return sha256.convert(utf8.encode(input)).toString();
  }
}
