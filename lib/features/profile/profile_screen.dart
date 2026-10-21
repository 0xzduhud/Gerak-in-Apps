import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, required this.user, required this.onLogout});

  final Map<String, dynamic> user;
  final Future<void> Function() onLogout;

  String get _displayName {
    final fullName = user['full_name']?.toString().trim();
    final username = user['username']?.toString().trim();

    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    if (username != null && username.isNotEmpty) {
      return username;
    }

    return 'Pengguna';
  }

  @override
  Widget build(BuildContext context) {
    final email = user['email']?.toString() ?? '-';
    final username = user['username']?.toString() ?? '-';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Profil saya',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        const Center(
          child: CircleAvatar(
            radius: 48,
            backgroundColor: Color(0xFFD9EEE7),
            child: Icon(
              Icons.person_rounded,
              size: 54,
              color: Color(0xFF16856B),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _displayName,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: const Text('Nama lengkap'),
                subtitle: Text(_displayName),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.alternate_email),
                title: const Text('Username'),
                subtitle: Text(username),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.email_outlined),
                title: const Text('Email'),
                subtitle: Text(email),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Saran dan kesan mata kuliah '
          'Pemrograman Aplikasi Mobile',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bagian saran dan kesan dapat dilengkapi '
          'dengan formulir pada pengembangan berikutnya.',
          style: TextStyle(fontSize: 13),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: onLogout,
            icon: const Icon(Icons.logout_rounded),
            label: const Text('Logout'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFE86524),
              foregroundColor: const Color(0xFF24110A),
              minimumSize: const Size.fromHeight(50),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
