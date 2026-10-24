import 'package:flutter_test/flutter_test.dart';
import 'package:gerakinapps/core/utils/formatters.dart';

void main() {
  test('sapaan sesuai jam', () {
    expect(greetingByHour(5), 'Selamat pagi');
    expect(greetingByHour(12), 'Selamat siang');
    expect(greetingByHour(16), 'Selamat sore');
    expect(greetingByHour(20), 'Selamat malam');
    expect(greetingByHour(2), 'Selamat malam');
  });

  test('nama depan', () {
    expect(firstNameOf('Muhammad Chusna'), 'Muhammad');
    expect(firstNameOf('   '), 'Pengguna');
  });
}