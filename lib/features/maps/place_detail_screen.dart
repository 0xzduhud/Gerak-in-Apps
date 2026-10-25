import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/models/place_model.dart';
import 'place_style.dart';

// [PBI-11.6] Halaman detail tempat + tombol navigasi ke aplikasi peta.
// [PBI-11.8] Kalkulator biaya akan ditambahkan di sini (hanya jika ada info biaya).
class PlaceDetailScreen extends StatelessWidget {
  const PlaceDetailScreen({super.key, required this.place});

  final Place place;

  Future<void> _openNavigation(BuildContext context) async {
    var opened = false;
    try {
      opened = await launchUrl(
        navigationUri(place.lat, place.lng),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      debugPrint('Gagal membuka peta: $e');
    }
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak bisa membuka aplikasi peta.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = placeColor(place.type);
    final distance = place.distanceMeters;

    return Scaffold(
      appBar: AppBar(title: const Text('Detail tempat')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: color,
                  child: Icon(placeIcon(place.type), color: Colors.white),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        place.type.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: color,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _InfoRow(
              icon: Icons.near_me_rounded,
              label: 'Jarak dari kamu',
              value: distance == null ? 'Belum diketahui' : formatDistance(distance),
            ),
            _InfoRow(
              icon: Icons.place_rounded,
              label: 'Alamat',
              value: place.address ?? 'Alamat belum tersedia di OpenStreetMap',
            ),
            _InfoRow(
              icon: Icons.schedule_rounded,
              label: 'Jam buka',
              value: place.openingHours ?? 'Belum tersedia',
            ),
            _InfoRow(
              icon: Icons.my_location_rounded,
              label: 'Koordinat',
              value: '${place.lat.toStringAsFixed(5)}, '
                  '${place.lng.toStringAsFixed(5)}',
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () => _openNavigation(context),
              icon: const Icon(Icons.directions_rounded),
              label: const Text('Buka di aplikasi peta'),
            ),
            const SizedBox(height: 10),
            const Text(
              'Data tempat berasal dari OpenStreetMap dan bisa saja belum '
              'lengkap atau berubah.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(color: AppColors.textPrimary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}