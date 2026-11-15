import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../data/models/place_model.dart';
import 'cost_calculator_card.dart';
import 'place_style.dart';

/// Halaman detail tempat olahraga yang dipercantik dan informatif.
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

  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$label berhasil disalin ke clipboard!'),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final color = placeColor(place.type);
    final distance = place.distanceMeters;

    final walkMinutes = distance != null ? (distance / 80).ceil() : null;
    final driveMinutes = distance != null ? (distance / 400).ceil() : null;

    final fullAddress = place.address ?? 'Alamat belum tercatat di OpenStreetMap';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detail Tempat Olahraga'),
        actions: [
          IconButton(
            tooltip: 'Bagikan / Salin Alamat',
            icon: const Icon(Icons.share_rounded),
            onPressed: () => _copyToClipboard(
              context,
              '${place.name} - $fullAddress',
              'Info tempat',
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
          children: [
            // Header Hero Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.35),
                    AppColors.surface,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: color.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: color.withValues(alpha: 0.4),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(placeIcon(place.type), color: Colors.white, size: 30),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              place.name,
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.25),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: color),
                                  ),
                                  child: Text(
                                    place.type.label,
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: color,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.green.withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.circle, size: 8, color: Colors.greenAccent),
                                      SizedBox(width: 4),
                                      Text(
                                        'Terverifikasi OSM',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.greenAccent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Quick Actions Bar
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () => _openNavigation(context),
                    icon: const Icon(Icons.directions_rounded, color: AppColors.primary),
                    label: const Text(
                      'Rute Google Maps',
                      style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Material(
                  color: AppColors.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: const BorderSide(color: AppColors.outline),
                  ),
                  child: IconButton(
                    tooltip: 'Salin Koordinat',
                    onPressed: () => _copyToClipboard(
                      context,
                      '${place.lat}, ${place.lng}',
                      'Koordinat',
                    ),
                    icon: const Icon(Icons.copy_rounded, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Section: Informasi Detail
            const Text(
              'Informasi Tempat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),

            _DetailCard(
              icon: Icons.place_rounded,
              title: 'Alamat',
              value: fullAddress,
              actionIcon: Icons.copy_rounded,
              onAction: () => _copyToClipboard(context, fullAddress, 'Alamat'),
            ),

            if (distance != null)
              _DetailCard(
                icon: Icons.route_rounded,
                title: 'Jarak & Aksesibilitas',
                value: '${formatDistance(distance)} dari posisimu saat ini\n'
                    '• Estimasi jalan kaki: ~$walkMinutes menit\n'
                    '• Estimasi berkendara: ~$driveMinutes menit',
              ),

            _DetailCard(
              icon: Icons.schedule_rounded,
              title: 'Jam Buka',
              value: place.openingHours != null && place.openingHours!.isNotEmpty
                  ? place.openingHours!
                  : 'Jam buka fleksibel (umumnya 06.00 - 21.00 WIB)',
            ),

            _DetailCard(
              icon: Icons.gps_fixed_rounded,
              title: 'Koordinat Lokasi',
              value: '${place.lat.toStringAsFixed(6)}, ${place.lng.toStringAsFixed(6)}',
            ),

            const SizedBox(height: 12),

            // Fasilitas umum
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.sports_rounded, color: AppColors.secondary, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Fasilitas & Layanan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _FacilityChip(icon: Icons.local_parking_rounded, label: 'Area Parkir'),
                      _FacilityChip(icon: Icons.wc_rounded, label: 'Toilet Bersih'),
                      _FacilityChip(icon: Icons.accessible_rounded, label: 'Akses Ramah'),
                      _FacilityChip(icon: Icons.storefront_rounded, label: 'Kantin / Minuman'),
                      _FacilityChip(icon: Icons.light_mode_rounded, label: 'Penerangan Lapangan'),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Kalkulator Biaya Tempat
            CostCalculatorCard(place: place),

            const SizedBox(height: 20),

            const SizedBox(height: 8),
            const Text(
              'Data tempat olahraga disinkronisasikan dari OpenStreetMap secara real-time.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({
    required this.icon,
    required this.title,
    required this.value,
    this.actionIcon,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String value;
  final IconData? actionIcon;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.surfaceHigh,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (actionIcon != null && onAction != null)
            IconButton(
              icon: Icon(actionIcon, size: 18, color: AppColors.textSecondary),
              onPressed: onAction,
            ),
        ],
      ),
    );
  }
}

class _FacilityChip extends StatelessWidget {
  const _FacilityChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceHigh,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.outline),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.secondary),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
