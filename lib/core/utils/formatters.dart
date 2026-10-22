String greetingByHour(int hour) {
  if (hour >= 4 && hour < 11) return 'Selamat pagi';
  if (hour >= 11 && hour < 15) return 'Selamat siang';
  if (hour >= 15 && hour < 18) return 'Selamat sore';
  return 'Selamat malam';
}

String firstNameOf(String fullName) {
  final trimmed = fullName.trim();
  if (trimmed.isEmpty) return 'Pengguna';
  return trimmed.split(RegExp(r'\s+')).first;
}