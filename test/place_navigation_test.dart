import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports
import '../lib/data/models/place_model.dart';

void main() {
  group('PBI-11.6 navigationUri', () {
    test('menunjuk ke Google Maps dengan koordinat tujuan', () {
      final uri = navigationUri(-7.78, 110.37);
      expect(uri.scheme, 'https');
      expect(uri.host, 'www.google.com');
      expect(uri.queryParameters['api'], '1');
      expect(uri.queryParameters['destination'], '-7.78,110.37');
    });
  });
}