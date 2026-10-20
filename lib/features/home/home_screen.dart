import 'package:flutter/material.dart';

import '../../data/repositories/auth_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.user,
    required this.repository,
    required this.onLogout,
  });

  final Map<String, dynamic> user;
  final AuthRepository repository;
  final Future<void> Function() onLogout;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  String get _displayName {
    final fullName = widget.user['full_name']?.toString().trim();
    final username = widget.user['username']?.toString().trim();

    if (fullName != null && fullName.isNotEmpty) return fullName;
    if (username != null && username.isNotEmpty) return username;
    return 'Pengguna';
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      _buildDashboard(),
      _buildActivityPage(),
      _buildProfilePage(),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Gerak-in',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Keluar',
            onPressed: () async {
              final shouldLogout = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Keluar dari akun?'),
                  content: const Text(
                    'Kamu perlu login kembali untuk menggunakan akun ini.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const Text('Batal'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const Text('Keluar'),
                    ),
                  ],
                ),
              );

              if (shouldLogout == true) {
                await widget.onLogout();
              }
            },
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() => _selectedIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.directions_run_outlined),
            selectedIcon: Icon(Icons.directions_run_rounded),
            label: 'Aktivitas',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }

  Widget _buildDashboard() {
    const green = Color(0xFF16856B);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Halo, $_displayName! 👋',
          style: const TextStyle(
            fontSize: 25,
            fontWeight: FontWeight.bold,
            color: Color(0xFF19332D),
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Mulai bergerak, jaga kesehatan.',
          style: TextStyle(fontSize: 15),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: green,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.favorite_rounded, color: Colors.white, size: 32),
              SizedBox(height: 12),
              Text(
                'Setiap langkah berarti!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 21,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Catat aktivitasmu dan capai target '
                'kebugaranmu bersama Gerak-in.',
                style: TextStyle(color: Colors.white, fontSize: 14),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Ringkasan aktivitas',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                icon: Icons.directions_walk_rounded,
                title: 'Langkah',
                value: '0',
                subtitle: 'Belum ada data',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard(
                icon: Icons.timer_outlined,
                title: 'Durasi',
                value: '0 mnt',
                subtitle: 'Belum ada data',
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Mulai dari sini',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.directions_run_rounded),
            ),
            title: const Text('Aktivitas olahraga'),
            subtitle: const Text('Lihat dan catat aktivitasmu'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => setState(() => _selectedIndex = 1),
          ),
        ),
        Card(
          child: ListTile(
            leading: const CircleAvatar(
              child: Icon(Icons.person_outline_rounded),
            ),
            title: const Text('Profil saya'),
            subtitle: const Text('Lihat informasi akun'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => setState(() => _selectedIndex = 2),
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Catatan: ringkasan di atas masih berupa nilai awal. '
          'Data langkah dan durasi akan dihubungkan ke fitur '
          'pemantauan aktivitas pada tahap berikutnya.',
          style: TextStyle(fontSize: 12, color: Colors.black54),
        ),
      ],
    );
  }

  Widget _summaryCard({
    required IconData icon,
    required String title,
    required String value,
    required String subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 28, color: const Color(0xFF16856B)),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 14)),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(fontSize: 11, color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityPage() {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Aktivitas olahraga',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Bagian ini akan menjadi tempat untuk '
          'mencatat dan memantau aktivitas fisik.',
        ),
        const SizedBox(height: 20),
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.directions_walk_rounded,
              color: Color(0xFF16856B),
            ),
            title: const Text('Pemantauan langkah'),
            subtitle: const Text('Akan dihubungkan ke sensor perangkat'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(
              Icons.fitness_center_rounded,
              color: Color(0xFF16856B),
            ),
            title: const Text('Catatan olahraga'),
            subtitle: const Text('Akan dikembangkan pada tahap berikutnya'),
          ),
        ),
        Card(
          child: ListTile(
            leading: const Icon(Icons.flag_outlined, color: Color(0xFF16856B)),
            title: const Text('Target aktivitas'),
            subtitle: const Text('Akan dilengkapi pengaturan target'),
          ),
        ),
      ],
    );
  }

  Widget _buildProfilePage() {
    final email = widget.user['email']?.toString() ?? '-';
    final username = widget.user['username']?.toString() ?? '-';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Profil saya',
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 24),
        const CircleAvatar(
          radius: 42,
          backgroundColor: Color(0xFFD9EEE7),
          child: Icon(Icons.person_rounded, size: 48, color: Color(0xFF16856B)),
        ),
        const SizedBox(height: 16),
        Center(
          child: Text(
            _displayName,
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
        const SizedBox(height: 16),
        const Text(
          'Pengaturan profil dan fitur saran serta kesan '
          'mata kuliah akan ditambahkan berikutnya.',
          style: TextStyle(fontSize: 13),
        ),
      ],
    );
  }
}
