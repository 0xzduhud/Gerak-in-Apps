import 'package:flutter/material.dart';

import '../../core/services/ai_recommendation_service.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/target_model.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/target_repository.dart';
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

  // Total aktivitas hari ini dan progres target harian.
  final ActivityRepository _activities = ActivityRepository();
  final TargetRepository _targets = TargetRepository();

  DailyTotals _today = DailyTotals.empty;
  TargetProgress? _progress;

  // Future rekomendasi dibuat sekali agar tidak meminta rekomendasi
  // AI berulang kali setiap Home dibangun ulang.
  Future<Map<String, dynamic>?>? _recommendationFuture;

  @override
  void initState() {
    super.initState();
    _loadToday();

    final userId = widget.user['id']?.toString() ?? '';
    if (userId.isNotEmpty) {
      _recommendationFuture = AiRecommendationService().getRecommendation(
        userId,
      );
    }
  }

  Future<void> _loadToday() async {
    try {
      final totals = await _activities.totalsForDay(DateTime.now());

      // Kegagalan membaca target tidak boleh menyembunyikan aktivitas.
      TargetProgress? progress;
      try {
        progress = TargetProgress.from(await _targets.load(), totals);
      } catch (error) {
        debugPrint('Gagal memuat target harian: $error');
      }

      if (!mounted) return;

      debugPrint(
        'Total hari ini: langkah=${totals.steps} '
        'detik=${totals.durationSeconds} '
        'kkal=${totals.calories.toStringAsFixed(1)}',
      );

      setState(() {
        _today = totals;
        _progress = progress;
      });
    } catch (error) {
      // Kegagalan membaca data tidak boleh merusak Home.
      debugPrint('Gagal memuat aktivitas hari ini: $error');
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
    await Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => page));

    // Data mungkin berubah saat pengguna berada di halaman lain.
    if (mounted) {
      await _loadToday();
    }
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
      // Home dan Community memiliki header sendiri.
      appBar: (isHomeTab || _selectedIndex == 3)
          ? null
          : AppBar(
              title: Text(
                _selectedIndex == 4 ? 'Profile' : 'Gerak-in',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
      body: SafeArea(
        child: IndexedStack(index: _selectedIndex, children: pages),
      ),

      // Tombol chatbot hanya muncul pada tab Home.
      floatingActionButton: isHomeTab
          ? FloatingActionButton(
              tooltip: 'Fitness Assistant',
              onPressed: () {
                Navigator.of(context).push(ChatScreen.route());
              },
              child: const Icon(Icons.smart_toy_rounded),
            )
          : null,

      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });

          if (index == 0) {
            _loadToday();
          }
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

  // Susunan halaman Home.
  Widget _buildHomePage() {
    final greeting = greetingByHour(DateTime.now().hour);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 96),
      children: [
        HomeHeader(
          greeting: greeting,
          name: firstNameOf(_displayName),
          onNotificationTap: () {
            _open(const NotificationScreen());
          },
        ),
        const SizedBox(height: 20),
        DailyActivityCard(
          steps: _today.steps,
          calories: _today.calories.round(),
          distanceKm: _today.distanceMeters / 1000,
          progress: _progress,
        ),
        const SizedBox(height: 16),

        // Rekomendasi AI dari service yang sudah ada.
        _buildAiRecommendationCard(),

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

        // Komunitas: tampilkan maksimal 3 postingan terbaru.
        // Tombol Lihat semua membuka tab Community.
        CommunityFeedCard(
          onSeeAll: () {
            setState(() {
              _selectedIndex = 3;
            });
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // Kartu rekomendasi AI.
  Widget _buildAiRecommendationCard() {
    final future = _recommendationFuture;

    if (future == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('ID Pengguna tidak ditemukan untuk rekomendasi AI.'),
        ),
      );
    }

    return FutureBuilder<Map<String, dynamic>?>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.error_outline, color: Colors.red),
              title: Text('Gagal memuat rekomendasi'),
              subtitle: Text('Silakan periksa koneksi atau coba lagi nanti.'),
            ),
          );
        }

        final data = snapshot.data!;
        final namaOlahraga = data['nama_olahraga']?.toString() ?? 'Istirahat';
        final alasan = data['alasan']?.toString() ?? '';

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFFE86524)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Hari ini: $namaOlahraga',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(alasan),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: FilledButton(
                    onPressed: () {
                      setState(() {
                        _selectedIndex = 2;
                      });
                    },
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFE86524),
                    ),
                    child: const Text('Mulai Workout'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
