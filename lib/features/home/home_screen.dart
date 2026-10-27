import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../data/repositories/auth_repository.dart';
import '../achievement/achievement_screen.dart';
import '../auth/login_screen.dart';
import '../chatbot/chat_screen.dart';
import '../community/community_screen.dart';
import '../games/games_menu_screen.dart';
import '../maps/maps_screen.dart';
import '../notifications/notification_screen.dart';
import '../profile/profile_screen.dart';
import '../progress/progress_screen.dart';
import '../schedule/schedule_screen.dart';
import '../workout/screens/workout_list_screen.dart';
import 'home_widgets.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/models/target_model.dart';
import '../../data/repositories/target_repository.dart';

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


    // PBI-8.7: total aktivitas hari ini untuk card Daily Activity.
  // PBI-10.8: ditambah target harian untuk indikator progres.
  final ActivityRepository _activities = ActivityRepository();
  final TargetRepository _targets = TargetRepository();
  DailyTotals _today = DailyTotals.empty;
  TargetProgress? _progress;

  @override
  void initState() {
    super.initState();
    _loadToday();
  }

  Future<void> _loadToday() async {
    try {
      final totals = await _activities.totalsForDay(DateTime.now());

      // Gagal membaca target tidak boleh menyembunyikan angka aktivitas.
      TargetProgress? progress;
      try {
        progress = TargetProgress.from(await _targets.load(), totals);
      } catch (e) {
        debugPrint('Gagal memuat target harian: $e');
      }

      if (!mounted) return;
      setState(() {
        _today = totals;
        _progress = progress;
      });
    } catch (e) {
      // Gagal membaca data tidak boleh merusak Home; tetap tampil nol.
      debugPrint('Gagal memuat aktivitas hari ini: $e');
    }
  }
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

   Future<void> _open(Widget page) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => page),
    );
    // Data bisa berubah (workout selesai, target diubah) saat di halaman lain.
    if (mounted) _loadToday();
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

    final isHomeTab = _selectedIndex == 0;

    return Scaffold(
           // Home dan Community punya header sendiri, jadi AppBar bawaan disembunyikan
      appBar: (isHomeTab || _selectedIndex == 3)
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
      // PBI-6.7: tombol melayang chatbot di kanan bawah (khusus Home)
      floatingActionButton: isHomeTab
          ? FloatingActionButton(
              tooltip: 'Fitness Assistant',
              onPressed: () => _open(const ChatScreen()),
              child: const Icon(Icons.smart_toy_rounded),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
          // Kembali ke Home: muat ulang total (sesi baru mungkin baru selesai).
          if (index == 0) _loadToday();
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

  // PBI-6.1: susunan halaman Home
  Widget _buildHomePage() {
    final greeting = greetingByHour(DateTime.now().hour);

    return ListView(
      // padding bawah besar supaya card terakhir tidak tertutup tombol chatbot
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      children: [
        HomeHeader(
          greeting: greeting,
          name: firstNameOf(_displayName),
          onNotificationTap: () => _open(const NotificationScreen()),
        ),
        const SizedBox(height: 20),
        DailyActivityCard(
          durationMinutes: (_today.durationSeconds / 60).round(),
          calories: _today.calories.round(),
          reps: _today.reps,
          sessions: _today.sessions,
          steps: _today.steps,
          distanceKm: _today.distanceMeters / 1000,
          progress: _progress,
        ),
        const SizedBox(height: 16),
        const AiRecommendationCard(),
        const SizedBox(height: 24),
        RoundMenuRow(
          items: [
            HomeMenuItem(
              icon: Icons.calendar_month_rounded,
              label: 'Schedule',
              onTap: () => _open(const ScheduleScreen()),
            ),
            HomeMenuItem(
              icon: Icons.sports_esports_rounded,
              label: 'Games',
              onTap: () => _open(const GamesMenuScreen()),
            ),
            HomeMenuItem(
              icon: Icons.trending_up_rounded,
              label: 'Progress',
              onTap: () => _open(const ProgressScreen()),
            ),
            HomeMenuItem(
              icon: Icons.emoji_events_rounded,
              label: 'Achievement',
              onTap: () => _open(const AchievementScreen()),
            ),
          ],
        ),
        const SizedBox(height: 24),
        CommunityFeedCard(
          onSeeAll: () => setState(() => _selectedIndex = 3),
        ),
      ],
    );
  }
}