import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../core/services/location_service.dart';
import '../../core/theme.dart';
import '../../data/models/place_model.dart';
import '../../data/repositories/geocoding_repository.dart';
import 'maps_provider.dart';
import 'place_detail_screen.dart';
import 'place_search_delegate.dart';
import 'place_style.dart';

/// Ganti dengan applicationId aplikasi (lihat android/app/build.gradle).
/// OpenStreetMap meminta aplikasi mengenalkan dirinya saat mengambil tile.
const String _userAgentPackage = 'com.example.gerakin';

/// Pusat peta bawaan (Yogyakarta) saat lokasi pengguna belum tersedia.
const LatLng _defaultCenter = LatLng(-7.7956, 110.3695);

const Color _allColor = Color(0xFF5B6B8C);

class MapsScreen extends StatelessWidget {
  const MapsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<MapsProvider>(
      create: (_) => MapsProvider(),
      child: const _MapsView(),
    );
  }
}

class _MapsView extends StatefulWidget {
  const _MapsView();

  @override
  State<_MapsView> createState() => _MapsViewState();
}

class _MapsViewState extends State<_MapsView> {
  final MapController _controller = MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _moveTo(double lat, double lng, double zoom) {
    try {
      _controller.move(LatLng(lat, lng), zoom);
    } catch (e) {
      debugPrint('Peta belum siap: $e');
    }
  }

  Future<void> _locate() async {
    final provider = context.read<MapsProvider>();
    await provider.locate();
    if (!mounted) return;
    final user = provider.user;
    if (user != null) _moveTo(user.lat, user.lng, 15);
  }

  /// [PBI-11.4] Cari nama kota/area lalu muat tempat olahraga di sana.
  Future<void> _search() async {
    final provider = context.read<MapsProvider>();
    final result = await showSearch<GeoResult?>(
      context: context,
      delegate: PlaceSearchDelegate(),
    );
    if (result == null || !mounted) return;
    _moveTo(result.lat, result.lng, 14);
    await provider.searchHere(result);
  }

  void _focus(Place place) {
    context.read<MapsProvider>().select(place);
    _moveTo(place.lat, place.lng, 16);
  }

  void _openDetail(Place place) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlaceDetailScreen(place: place)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MapsProvider>();
    final user = p.user;
    final pin = p.searchCenter;
    final status = p.status;
    final failed = status != null && status != LocationStatus.ok;
    final selected = p.selected;

    final markers = <Marker>[
      for (final place in p.places)
        Marker(
          point: LatLng(place.lat, place.lng),
          width: place.id == selected?.id ? 52 : 34,
          height: place.id == selected?.id ? 52 : 34,
          child: GestureDetector(
            onTap: () => _focus(place),
            child: Opacity(
              // Saat ada yang dipilih, tempat lain dibuat lebih pudar.
              opacity: selected == null || place.id == selected.id ? 1.0 : 0.55,
              child: _PlaceDot(
                type: place.type,
                selected: place.id == selected?.id,
              ),
            ),
          ),
        ),
      if (pin != null)
        Marker(
          point: LatLng(pin.lat, pin.lng),
          width: 40,
          height: 40,
          alignment: Alignment.topCenter,
          child: const Icon(
            Icons.location_on_rounded,
            color: AppColors.tertiary,
            size: 40,
          ),
        ),
      if (user != null)
        Marker(
          point: LatLng(user.lat, user.lng),
          width: 28,
          height: 28,
          child: const _UserDot(),
        ),
    ];

    return Stack(
      children: [
        FlutterMap(
          mapController: _controller,
          options: const MapOptions(
            initialCenter: _defaultCenter,
            initialZoom: 13,
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: _userAgentPackage,
            ),
            MarkerLayer(markers: markers),
          ],
        ),
        // Atribusi OpenStreetMap (wajib sesuai lisensi data OSM).
        const Positioned(
          left: 8,
          top: 4,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Color(0xCCFFFFFF),
              borderRadius: BorderRadius.all(Radius.circular(4)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(
                '© OpenStreetMap contributors',
                style: TextStyle(fontSize: 10, color: Colors.black87),
              ),
            ),
          ),
        ),
        // Bar filter jenis tempat
        const Positioned(
          left: 8,
          right: 104,
          top: 28,
          child: _FilterBar(),
        ),
        // Tombol cari area
        Positioned(
          right: 56,
          top: 28,
          child: FloatingActionButton.small(
            heroTag: 'maps_search',
            onPressed: _search,
            tooltip: 'Cari kota atau area',
            child: const Icon(Icons.search_rounded),
          ),
        ),
        // Tombol lokasi saya
        Positioned(
          right: 8,
          top: 28,
          child: FloatingActionButton.small(
            heroTag: 'maps_my_location',
            onPressed: p.locating ? null : _locate,
            tooltip: 'Lokasi saya',
            child: p.locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Icon(Icons.my_location_rounded),
          ),
        ),
        // Pesan GPS mati / izin ditolak (PBI-11.10), atau kartu tempat terpilih
        if (failed && pin == null)
          Positioned(
            left: 12,
            right: 12,
            top: 76,
            child: _StatusBanner(
              status: status,
              busy: p.locating,
              onRetry: _locate,
              onOpenLocationSettings: p.openLocationSettings,
              onOpenAppSettings: p.openAppSettings,
            ),
          )
        else if (selected != null)
          Positioned(
            left: 12,
            right: 12,
            top: 76,
            child: _SelectedCard(
              place: selected,
              onDetail: () => _openDetail(selected),
              onClose: () => p.select(null),
            ),
          ),
        // Panel daftar tempat (PBI-11.5)
        DraggableScrollableSheet(
          initialChildSize: 0.3,
          minChildSize: 0.12,
          maxChildSize: 0.75,
          builder: (context, scrollController) => _PlacesSheet(
            controller: scrollController,
            onFocus: _focus,
          ),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar();

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MapsProvider>();
    final ready =
        p.hasCenter && !p.loadingPlaces && p.placesError == null;
    String label(String text, PlaceType? type) =>
        ready ? '$text ${p.countOf(type)}' : text;

    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _FilterChip(
            label: label('Semua', null),
            icon: Icons.apps_rounded,
            color: _allColor,
            selected: p.filter == null,
            onTap: () => p.setFilter(null),
          ),
          for (final t in PlaceType.values)
            _FilterChip(
              label: label(t.label, t),
              icon: placeIcon(t),
              color: placeColor(t),
              selected: p.filter == t,
              onTap: () => p.setFilter(t),
            ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: selected ? color : AppColors.surface,
        elevation: 3,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? Icons.check_rounded : icon,
                  size: 16,
                  color: selected ? Colors.white : color,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PlacesSheet extends StatelessWidget {
  const _PlacesSheet({required this.controller, required this.onFocus});

  final ScrollController controller;
  final ValueChanged<Place> onFocus;

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MapsProvider>();
    final failed = p.status != null && p.status != LocationStatus.ok;
    final places = p.places;

    String? message;
    if (!p.hasCenter) {
      message = failed
          ? 'Aktifkan lokasi, atau cari nama kota/area dengan ikon kaca '
              'pembesar di kanan atas.'
          : 'Mencari lokasimu...';
    } else if (p.placesError != null) {
      message = p.placesError;
    } else if (!p.loadingPlaces && places.isEmpty) {
      message = p.filter == null
          ? 'Tidak ada tempat ditemukan dalam radius ${p.radiusKm} km. '
              'Data OpenStreetMap di area ini mungkin masih sedikit.'
          : 'Tidak ada ${p.filter!.label} dalam radius ${p.radiusKm} km. '
              'Coba pilih "Semua".';
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [BoxShadow(color: Colors.black38, blurRadius: 12)],
      ),
      child: CustomScrollView(
        controller: controller,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppColors.outline,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tempat olahraga terdekat',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              p.placesSummary,
                              style: TextStyle(
                                fontSize: 12,
                                color: p.placesError != null
                                    ? AppColors.tertiary
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Muat ulang',
                        onPressed: (p.loadingPlaces || !p.hasCenter)
                            ? null
                            : () => p.loadPlaces(force: true),
                        icon: const Icon(Icons.refresh_rounded),
                      ),
                    ],
                  ),
                  if (p.stale)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Tidak ada internet. Menampilkan data dari '
                        'penyimpanan sementara.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  if (p.usingFallback)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: Text(
                        'Server data utama sedang sibuk. Memakai sumber '
                        'cadangan, jumlah tempat bisa lebih sedikit.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
          if (p.loadingPlaces)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (message != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  children: [
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    if (p.placesErrorDetail != null) ...[
                      const SizedBox(height: 8),
                      // Detail teknis: berguna untuk mencari penyebab masalah.
                      SelectableText(
                        'Detail: ${p.placesErrorDetail}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.tertiary,
                        ),
                      ),
                    ],
                    if (p.placesError != null) ...[
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: () => p.loadPlaces(force: true),
                        child: const Text('Coba lagi'),
                      ),
                    ],
                  ],
                ),
              ),
            )
          else
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _PlaceTile(
                  place: places[i],
                  selected: places[i].id == p.selected?.id,
                  onTap: () => onFocus(places[i]),
                ),
                childCount: places.length,
              ),
            ),
          const SliverToBoxAdapter(child: SizedBox(height: 16)),
        ],
      ),
    );
  }
}

class _PlaceTile extends StatelessWidget {
  const _PlaceTile({
    required this.place,
    required this.selected,
    required this.onTap,
  });

  final Place place;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final distance = place.distanceMeters;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? placeColor(place.type) : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: placeColor(place.type),
              child: Icon(placeIcon(place.type), color: Colors.white, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    place.address == null
                        ? place.type.label
                        : '${place.type.label} • ${place.address}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            if (distance != null)
              Text(
                formatDistance(distance),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: AppColors.secondary,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SelectedCard extends StatelessWidget {
  const _SelectedCard({
    required this.place,
    required this.onDetail,
    required this.onClose,
  });

  final Place place;
  final VoidCallback onDetail;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final distance = place.distanceMeters;
    return Material(
      color: AppColors.surface,
      elevation: 6,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: placeColor(place.type),
              child: Icon(placeIcon(place.type), color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    place.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    distance == null
                        ? place.type.label
                        : '${place.type.label} • ${formatDistance(distance)}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onDetail, child: const Text('Detail')),
            IconButton(
              tooltip: 'Tutup',
              onPressed: onClose,
              icon: const Icon(Icons.close_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlaceDot extends StatelessWidget {
  const _PlaceDot({required this.type, required this.selected});

  final PlaceType type;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: placeColor(type),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: selected ? 4 : 2),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 6)],
      ),
      child: Icon(
        placeIcon(type),
        color: Colors.white,
        size: selected ? 24 : 16,
      ),
    );
  }
}

class _UserDot extends StatelessWidget {
  const _UserDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E88E5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({
    required this.status,
    required this.busy,
    required this.onRetry,
    required this.onOpenLocationSettings,
    required this.onOpenAppSettings,
  });

  final LocationStatus status;
  final bool busy;
  final VoidCallback onRetry;
  final VoidCallback onOpenLocationSettings;
  final VoidCallback onOpenAppSettings;

  String get _message => switch (status) {
        LocationStatus.serviceDisabled =>
          'GPS sedang nonaktif. Aktifkan lokasi agar tempat olahraga '
              'terdekat bisa ditampilkan.',
        LocationStatus.denied =>
          'Izin lokasi ditolak. Izinkan akses lokasi untuk melihat posisimu '
              'di peta.',
        LocationStatus.deniedForever =>
          'Izin lokasi ditolak permanen. Aktifkan lewat pengaturan aplikasi.',
        _ => 'Lokasi belum bisa diambil. Coba lagi.',
      };

  @override
  Widget build(BuildContext context) {
    final VoidCallback primaryAction;
    final String primaryLabel;
    switch (status) {
      case LocationStatus.serviceDisabled:
        primaryAction = onOpenLocationSettings;
        primaryLabel = 'Aktifkan GPS';
      case LocationStatus.deniedForever:
        primaryAction = onOpenAppSettings;
        primaryLabel = 'Buka pengaturan';
      default:
        primaryAction = onRetry;
        primaryLabel = 'Coba lagi';
    }

    return Material(
      color: AppColors.surface,
      elevation: 4,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_off_rounded, color: AppColors.tertiary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _message,
                    style: const TextStyle(color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (status == LocationStatus.serviceDisabled)
                  TextButton(
                    onPressed: busy ? null : onRetry,
                    child: const Text('Coba lagi'),
                  ),
                FilledButton(
                  onPressed: busy ? null : primaryAction,
                  child: Text(primaryLabel),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}