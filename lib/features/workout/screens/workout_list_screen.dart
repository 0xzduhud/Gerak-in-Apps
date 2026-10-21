import 'package:flutter/material.dart';

class WorkoutListScreen extends StatelessWidget {
  const WorkoutListScreen({super.key});

  static const Color _primary = Color(0xFFE86524);

  static const List<Map<String, dynamic>> _muscleGroups = [
    {
      'name': 'Dada',
      'subtitle': 'Latihan otot dada',
      'icon': Icons.fitness_center_rounded,
      'exercises': [
        {
          'name': 'Bench Press',
          'equipment': 'Barbell',
          'sets': 4,
          'reps': '8–12',
          'description': 'Latihan compound untuk melatih otot dada, triceps, dan bahu depan.',
          'videoUrl': 'https://www.youtube.com/results?search_query=bench+press+proper+form',
        },
        {
          'name': 'Incline Dumbbell Press',
          'equipment': 'Dumbbell',
          'sets': 3,
          'reps': '10–12',
          'description': 'Variasi press dengan bangku miring untuk menargetkan bagian atas dada.',
          'videoUrl': 'https://www.youtube.com/results?search_query=incline+dumbbell+press+proper+form',
        },
        {
          'name': 'Chest Fly',
          'equipment': 'Dumbbell',
          'sets': 3,
          'reps': '12–15',
          'description': 'Gerakan isolasi untuk melatih otot dada melalui gerakan membuka dan menutup lengan.',
          'videoUrl': 'https://www.youtube.com/results?search_query=dumbbell+chest+fly+proper+form',
        },
      ],
    },
    {
      'name': 'Punggung',
      'subtitle': 'Latihan otot punggung',
      'icon': Icons.accessibility_new_rounded,
      'exercises': [
        {
          'name': 'Lat Pulldown',
          'equipment': 'Mesin kabel',
          'sets': 3,
          'reps': '10–12',
          'description': 'Melatih otot punggung, terutama latissimus dorsi.',
          'videoUrl': 'https://www.youtube.com/results?search_query=lat+pulldown+proper+form',
        },
        {
          'name': 'Seated Cable Row',
          'equipment': 'Mesin kabel',
          'sets': 3,
          'reps': '10–12',
          'description':
              'Melatih punggung bagian tengah dan membantu kekuatan tarikan.',
          'videoUrl': 'https://www.youtube.com/results?search_query=seated+cable+row+proper+form',
        },
        {
          'name': 'Dumbbell Row',
          'equipment': 'Dumbbell',
          'sets': 3,
          'reps': '10–12 per sisi',
          'description': 'Latihan tarikan satu sisi untuk melatih punggung.',
          'videoUrl': 'https://www.youtube.com/results?search_query=one+arm+dumbbell+row+proper+form',
        },
      ],
    },
    {
      'name': 'Bahu',
      'subtitle': 'Latihan otot bahu',
      'icon': Icons.sports_gymnastics_rounded,
      'exercises': [
        {
          'name': 'Shoulder Press',
          'equipment': 'Dumbbell',
          'sets': 3,
          'reps': '8–12',
          'description': 'Latihan dorong untuk melatih otot bahu.',
          'videoUrl': 'https://www.youtube.com/results?search_query=dumbbell+shoulder+press+proper+form',
        },
        {
          'name': 'Lateral Raise',
          'equipment': 'Dumbbell',
          'sets': 3,
          'reps': '12–15',
          'description': 'Latihan isolasi untuk bagian samping otot bahu.',
          'videoUrl': 'https://www.youtube.com/results?search_query=dumbbell+lateral+raise+proper+form',
        },
      ],
    },
    {
      'name': 'Biceps',
      'subtitle': 'Latihan otot lengan depan',
      'icon': Icons.sports_handball_rounded,
      'exercises': [
        {
          'name': 'Dumbbell Curl',
          'equipment': 'Dumbbell',
          'sets': 3,
          'reps': '10–12',
          'description': 'Melatih otot biceps melalui gerakan menekuk siku.',
          'videoUrl': 'https://www.youtube.com/results?search_query=dumbbell+biceps+curl+proper+form',
        },
        {
          'name': 'Hammer Curl',
          'equipment': 'Dumbbell',
          'sets': 3,
          'reps': '10–12',
          'description':
              'Variasi curl dengan posisi telapak tangan saling berhadapan.',
          'videoUrl': 'https://www.youtube.com/results?search_query=hammer+curl+proper+form',
        },
      ],
    },
    {
      'name': 'Triceps',
      'subtitle': 'Latihan otot lengan belakang',
      'icon': Icons.fitness_center_rounded,
      'exercises': [
        {
          'name': 'Triceps Pushdown',
          'equipment': 'Mesin kabel',
          'sets': 3,
          'reps': '10–15',
          'description': 'Melatih otot triceps dengan gerakan meluruskan siku.',
          'videoUrl': 'https://www.youtube.com/results?search_query=triceps+pushdown+proper+form',
        },
        {
          'name': 'Overhead Triceps Extension',
          'equipment': 'Dumbbell',
          'sets': 3,
          'reps': '10–12',
          'description': 'Latihan triceps dengan beban di atas kepala.',
          'videoUrl': 'https://www.youtube.com/results?search_query=overhead+dumbbell+triceps+extension+proper+form',
        },
      ],
    },
    {
      'name': 'Kaki',
      'subtitle': 'Latihan otot kaki',
      'icon': Icons.directions_walk_rounded,
      'exercises': [
        {
          'name': 'Squat',
          'equipment': 'Barbell atau berat badan',
          'sets': 3,
          'reps': '8–12',
          'description': 'Latihan tubuh bagian bawah untuk paha dan bokong.',
          'videoUrl':
              'https://www.youtube.com/results?search_query=squat+proper+form',
        },
        {
          'name': 'Leg Press',
          'equipment': 'Mesin leg press',
          'sets': 3,
          'reps': '10–12',
          'description': 'Latihan dorong kaki menggunakan mesin.',
          'videoUrl': 'https://www.youtube.com/results?search_query=leg+press+proper+form',
        },
        {
          'name': 'Romanian Deadlift',
          'equipment': 'Barbell atau dumbbell',
          'sets': 3,
          'reps': '8–12',
          'description':
              'Melatih hamstring, bokong, dan pola gerakan hip hinge.',
          'videoUrl': 'https://www.youtube.com/results?search_query=romanian+deadlift+proper+form',
        },
      ],
    },
    {
      'name': 'Perut',
      'subtitle': 'Latihan otot inti',
      'icon': Icons.self_improvement_rounded,
      'exercises': [
        {
          'name': 'Crunch',
          'equipment': 'Berat badan',
          'sets': 3,
          'reps': '12–15',
          'description': 'Latihan dasar untuk otot perut.',
          'videoUrl': 'https://www.youtube.com/results?search_query=abdominal+crunch+proper+form',
        },
        {
          'name': 'Plank',
          'equipment': 'Berat badan',
          'sets': 3,
          'reps': '30–45 detik',
          'description':
              'Melatih kestabilan otot inti dengan posisi tubuh lurus.',
          'videoUrl':
              'https://www.youtube.com/results?search_query=plank+proper+form',
        },
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Workout',
              style: TextStyle(fontSize: 27, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Pilih kelompok otot dan temukan latihan yang sesuai.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: _primary,
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.fitness_center_rounded,
                    color: Colors.white,
                    size: 38,
                  ),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Build your strength',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 19,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Pelajari teknik latihan sebelum mulai mengangkat beban.',
                          style: TextStyle(color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Kelompok otot',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ..._muscleGroups.map((group) {
              final exercises =
                  group['exercises'] as List<Map<String, dynamic>>;

              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                clipBehavior: Clip.antiAlias,
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: _primary.withValues(alpha: 0.12),
                    child: Icon(group['icon'] as IconData, color: _primary),
                  ),
                  title: Text(
                    group['name'] as String,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${group['subtitle']} • ${exercises.length} latihan',
                  ),
                  children: exercises.map((exercise) {
                    return ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(24, 4, 16, 4),
                      leading: const Icon(
                        Icons.play_circle_outline_rounded,
                        color: _primary,
                        size: 30,
                      ),
                      title: Text(exercise['name'] as String),
                      subtitle: Text(
                        '${exercise['equipment']} • '
                        '${exercise['sets']} set × ${exercise['reps']}',
                      ),
                      trailing: const Icon(Icons.chevron_right_rounded),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => WorkoutExerciseDetailPage(
                              exercise: exercise,
                              muscleGroup: group['name'] as String,
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class WorkoutExerciseDetailPage extends StatelessWidget {
  const WorkoutExerciseDetailPage({
    super.key,
    required this.exercise,
    required this.muscleGroup,
  });

  final Map<String, dynamic> exercise;
  final String muscleGroup;

  static const Color _primary = Color(0xFFE86524);

  Future<void> _openVideo(BuildContext context) async {
    final url = exercise['videoUrl'] as String;

    // Membuka hasil pencarian video YouTube di browser.
    // Belum memerlukan package pemutar video tambahan.
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Membuka video YouTube...')));

    // URL akan dibuka pada tahap integrasi pemutar/browser.
    // Gunakan tombol ini untuk menampilkan instruksi sementara.
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Video demonstrasi'),
        content: SelectableText(url),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detail Latihan')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            height: 190,
            decoration: BoxDecoration(
              color: _primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Center(
              child: Icon(
                Icons.play_circle_fill_rounded,
                size: 76,
                color: _primary,
              ),
            ),
          ),
          const SizedBox(height: 22),
          Text(
            muscleGroup.toUpperCase(),
            style: const TextStyle(
              color: _primary,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            exercise['name'] as String,
            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(exercise['description'] as String),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _InfoCard(label: 'Set', value: '${exercise['sets']}'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _InfoCard(
                  label: 'Repetisi',
                  value: '${exercise['reps']}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _InfoCard(label: 'Peralatan', value: exercise['equipment'] as String),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _openVideo(context),
            icon: const Icon(Icons.smart_display_rounded),
            label: const Text('Lihat video demonstrasi'),
            style: FilledButton.styleFrom(
              backgroundColor: _primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Tips latihan',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '• Mulai dengan beban yang dapat kamu kendalikan.\n'
            '• Utamakan teknik gerakan yang benar.\n'
            '• Hentikan latihan jika merasakan nyeri yang tidak biasa.',
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 6),
            Text(
              value,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
