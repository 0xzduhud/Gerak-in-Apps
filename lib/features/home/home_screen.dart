import 'package:flutter/material.dart';

import '../../data/repositories/auth_repository.dart';
import '../auth/login_screen.dart';
import '../profile/profile_screen.dart';
import '../maps/maps_screen.dart';
import '../workout/screens/workout_list_screen.dart';
import '../community/community_screen.dart';
import '../games/games_menu_screen.dart';

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

    if (fullName != null && fullName.isNotEmpty) {
      return fullName;
    }

    if (username != null && username.isNotEmpty) {
      return username;
    }

    return 'Pengguna';
  }

  Future<void> _handleLogout() async {
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

    if (shouldLogout != true || !mounted) return;

    try {
      await widget.onLogout();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Gagal logout: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      _buildHomePage(),
      const MapsScreen(),
      const WorkoutListScreen(),
      const CommunityScreen(),
      ProfileScreen(user: widget.user, onLogout: _handleLogout),
    ];

    return Scaffold(
      appBar: _selectedIndex == 3
          ? null
          : AppBar(
              title: const Text(
                'Gerak-in',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.map_outlined),
            selectedIcon: Icon(Icons.map_rounded),
            label: 'Maps',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center_rounded),
            label: 'Workout',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_rounded),
            label: 'Community',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _buildHomePage() {
    const primary = Color(0xFFE86524);
    const green = Color(0xFF16856B);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Halo, $_displayName!',
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text('Mulai bergerak, jaga kesehatan.'),
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
                style: TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Menu utama',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.25,
          children: [
            _menuCard(
              icon: Icons.calendar_month_rounded,
              title: 'Schedule',
              onTap: () => _showComingSoon('Schedule'),
            ),
            _menuCard(
              icon: Icons.trending_up_rounded,
              title: 'Progress',
              onTap: () => _showComingSoon('Progress'),
            ),
            _menuCard(
              icon: Icons.games_rounded,
              title: 'Games',
              onTap: () {
                Navigator.push(
                  context,
                  // Ubah bagian bawah ini dari QuizScreen menjadi GamesMenuScreen
                  MaterialPageRoute(
                    builder: (context) => const GamesMenuScreen(),
                  ),
                );
              },
            ),
            _menuCard(
              icon: Icons.emoji_events_rounded,
              title: 'Achievement',
              onTap: () => _showComingSoon('Achievement'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text(
          'Aktivitas harian',
          style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.directions_walk_rounded, color: primary),
            title: const Text('Daily Activity'),
            subtitle: const Text(
              'Pemantauan langkah akan dihubungkan '
              'dengan sensor pada sprint berikutnya.',
            ),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () {
              setState(() {
                _selectedIndex = 2;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _menuCard({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 34, color: const Color(0xFFE86524)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature akan dikembangkan pada sprint berikutnya.'),
      ),
    );
  }
}
