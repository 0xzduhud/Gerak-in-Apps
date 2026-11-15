import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/services/location_service.dart';
import '../../core/services/road_routing_service.dart';
import '../../core/theme.dart';
import '../../data/models/place_model.dart';
import '../../data/repositories/geocoding_repository.dart';
import 'maps_provider.dart';
import 'place_detail_screen.dart';
import 'place_style.dart';

const String _userAgentPackage = 'com.example.gerakin';
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
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _cardsScrollController = ScrollController();

  String _searchQuery = '';
  Place? _routePlace;
  List<LatLng> _roadRoutePoints = [];
  bool _isLoadingRoute = false;
  String? _routeSummary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _locate());
  }

  @override
  void dispose() {
    _controller.dispose();
    _searchController.dispose();
    _cardsScrollController.dispose();
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
    if (user != null) {
      _moveTo(user.lat, user.lng, 15);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lokasi kamu sekarang ada di tengah peta.'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _focus(Place place, {int? index}) {
    context.read<MapsProvider>().select(place);
    _moveTo(place.lat, place.lng, 16);

    if (index != null && _cardsScrollController.hasClients) {
      final targetOffset = index * 296.0;
      _cardsScrollController.animateTo(
        targetOffset.clamp(
          0.0,
          _cardsScrollController.position.maxScrollExtent,
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _openDetail(Place place) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PlaceDetailScreen(place: place)),
    );
  }

  Future<void> _startRoute(Place place) async {
    setState(() {
      _routePlace = place;
      _isLoadingRoute = true;
      _roadRoutePoints = [];
      _routeSummary = 'Menghitung rute jalan raya...';
    });

    final provider = context.read<MapsProvider>();
    final user = provider.user;

    if (user != null) {
      final userLatLng = LatLng(user.lat, user.lng);
      final destLatLng = LatLng(place.lat, place.lng);

      // Panggil OSRM API rute jalan raya sesungguhnya (Revisi 5)
      final roadResult = await RoadRoutingService.instance.fetchRoadRoute(
        start: userLatLng,
        destination: destLatLng,
      );

      if (!mounted) return;

      if (roadResult != null && roadResult.points.isNotEmpty) {
        setState(() {
          _roadRoutePoints = roadResult.points;
          _isLoadingRoute = false;
          _routeSummary = '${roadResult.formattedDistance} • ${roadResult.formattedDuration}';
        });

        final centerLat = (user.lat + place.lat) / 2;
        final centerLng = (user.lng + place.lng) / 2;
        _moveTo(centerLat, centerLng, 14);
        return;
      }
    }

    if (!mounted) return;
    setState(() {
      _isLoadingRoute = false;
      _roadRoutePoints = [
        if (user != null) LatLng(user.lat, user.lng),
        LatLng(place.lat, place.lng),
      ];
      _routeSummary = place.distanceMeters != null
          ? formatDistance(place.distanceMeters!)
          : 'Petunjuk arah siap';
    });

    if (user != null) {
      _moveTo((user.lat + place.lat) / 2, (user.lng + place.lng) / 2, 14);
    }
  }

  void _clearRoute() {
    setState(() {
      _routePlace = null;
      _roadRoutePoints = [];
      _routeSummary = null;
      _isLoadingRoute = false;
    });
  }

  Future<void> _openGoogleMapsRoute(Place place) async {
    try {
      await launchUrl(
        navigationUri(place.lat, place.lng),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Tidak dapat membuka aplikasi peta.')),
        );
      }
    }
  }

  List<Place> _filterPlaces(List<Place> rawPlaces) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return rawPlaces;

    return rawPlaces.where((p) {
      final name = p.name.toLowerCase();
      final address = (p.address ?? '').toLowerCase();
      final type = p.type.label.toLowerCase();
      return name.contains(query) ||
          address.contains(query) ||
          type.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<MapsProvider>();
    final user = p.user;
    final pin = p.searchCenter;
    final status = p.status;
    final failed = status != null && status != LocationStatus.ok;
    final selected = p.selected;

    final displayedPlaces = _filterPlaces(p.places);

    final markers = <Marker>[
      for (int i = 0; i < displayedPlaces.length; i++) ...[
        Marker(
          point: LatLng(displayedPlaces[i].lat, displayedPlaces[i].lng),
          width: displayedPlaces[i].id == selected?.id ? 54 : 36,
          height: displayedPlaces[i].id == selected?.id ? 54 : 36,
          child: GestureDetector(
            onTap: () => _focus(displayedPlaces[i], index: i),
            child: Opacity(
              opacity: selected == null || displayedPlaces[i].id == selected.id
                  ? 1.0
                  : 0.6,
              child: _PlaceDot(
                type: displayedPlaces[i].type,
                selected: displayedPlaces[i].id == selected?.id,
              ),
            ),
          ),
        ),
      ],
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

    // Fitur Rute Jalan Raya (Revisi 5: Mengikuti jalan raya nyata via OSRM)
    final polylines = <Polyline>[];
    if (_routePlace != null && _roadRoutePoints.isNotEmpty) {
      polylines.add(
        Polyline(
          points: _roadRoutePoints,
          color: AppColors.primary,
          strokeWidth: 5.5,
          borderColor: Colors.white,
          borderStrokeWidth: 1.8,
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.neutral,
      body: Stack(
        children: [
          // 1. Peta OpenStreetMap
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
              if (polylines.isNotEmpty) PolylineLayer(polylines: polylines),
              MarkerLayer(markers: markers),
            ],
          ),

          // 2. Attribution OSM
          const Positioned(
            left: 8,
            top: 6,
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

          // 3. Search Bar di atas sendiri & Tombol Refresh (Revisi 12, 14, 18)
          Positioned(
            top: 24,
            left: 16,
            right: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    // Search bar inline
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: TextField(
                          controller: _searchController,
                          onChanged: (val) {
                            setState(() {
                              _searchQuery = val;
                            });
                          },
                          onSubmitted: (val) async {
                            if (val.trim().length >= 3) {
                              try {
                                final mapsProvider = context.read<MapsProvider>();
                                final results = await GeocodingRepository.shared
                                    .search(val.trim());
                                if (results.isNotEmpty && mounted) {
                                  final first = results.first;
                                  _moveTo(first.lat, first.lng, 14);
                                  await mapsProvider.searchHere(first);
                                }
                              } catch (_) {}
                            }
                          },
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Cari tempat olahraga...',
                            hintStyle: const TextStyle(
                              color: Colors.white38,
                              fontSize: 13.5,
                            ),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: Colors.white38,
                              size: 20,
                            ),
                            suffixIcon: _searchController.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(
                                      Icons.clear,
                                      color: Colors.white38,
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() => _searchQuery = '');
                                    },
                                  )
                                : null,
                            filled: true,
                            fillColor: AppColors.surface,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 0,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.outline,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.outline,
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Tombol refresh di kanan atas (Revisi 14)
                    Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: (p.loadingPlaces || !p.hasCenter)
                            ? null
                            : () => p.loadPlaces(force: true),
                        child: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.outline),
                          ),
                          child: p.loadingPlaces
                              ? const Center(
                                  child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.refresh_rounded,
                                  color: AppColors.primary,
                                  size: 22,
                                ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Di bawah Search Bar: Menu Kategori & Tombol Lokasi Saya (Revisi 12)
                Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _CategoryChip(
                              label: 'Semua',
                              selected: p.filter == null,
                              icon: Icons.apps_rounded,
                              color: _allColor,
                              onTap: () => p.setFilter(null),
                            ),
                            for (final t in PlaceType.values)
                              _CategoryChip(
                                label: t.label,
                                selected: p.filter == t,
                                icon: placeIcon(t),
                                color: placeColor(t),
                                onTap: () => p.setFilter(t),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),

                    // Tombol Lokasi Saya di sebelah menu (Revisi 12)
                    Material(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(20),
                      elevation: 3,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: p.locating ? null : _locate,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.outline),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.my_location_rounded,
                                color: AppColors.primary,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Lokasi Saya',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 4. Banner Rute jika sedang aktif (Revisi 15)
          if (_routePlace != null)
            Positioned(
              left: 16,
              right: 16,
              top: 140,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceHigh,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                  boxShadow: const [
                    BoxShadow(color: Colors.black45, blurRadius: 10),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.alt_route_rounded,
                        color: AppColors.neutral,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Rute ke ${_routePlace!.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _routeSummary ??
                                (_routePlace!.distanceMeters != null
                                    ? 'Jarak: ${formatDistance(_routePlace!.distanceMeters!)}'
                                    : 'Petunjuk arah siap'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _openGoogleMapsRoute(_routePlace!),
                      child: const Text('Buka Maps'),
                    ),
                    IconButton(
                      tooltip: 'Tutup Rute',
                      icon: const Icon(Icons.close_rounded, size: 20),
                      onPressed: _clearRoute,
                    ),
                  ],
                ),
              ),
            ),

          // 5. Pesan Status jika lokasi gagal
          if (failed && pin == null)
            Positioned(
              left: 16,
              right: 16,
              top: 140,
              child: _StatusBanner(
                status: status,
                busy: p.locating,
                onRetry: _locate,
                onOpenLocationSettings: p.openLocationSettings,
                onOpenAppSettings: p.openAppSettings,
              ),
            ),

          // 6. Carousel Card Tempat Olahraga Horizontal (Revisi 13)
          Positioned(
            left: 0,
            right: 0,
            bottom: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (displayedPlaces.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 20, bottom: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.outline),
                      ),
                      child: Text(
                        '${displayedPlaces.length} Tempat Ditemukan • Geser Kanan/Kiri',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.secondary,
                        ),
                      ),
                    ),
                  ),
                SizedBox(
                  height: 185,
                  child: displayedPlaces.isEmpty
                      ? Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(horizontal: 20),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.outline),
                            ),
                            child: Text(
                              p.loadingPlaces
                                  ? 'Sedang mencari tempat olahraga...'
                                  : 'Tidak ada tempat olahraga yang sesuai.',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _cardsScrollController,
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: displayedPlaces.length,
                          itemBuilder: (context, index) {
                            final place = displayedPlaces[index];
                            final isSelected = place.id == selected?.id;

                            return _HorizontalPlaceCard(
                              place: place,
                              isSelected: isSelected,
                              onTap: () => _focus(place, index: index),
                              onDetail: () => _openDetail(place),
                              onRoute: () => _startRoute(place),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.selected,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected ? color : AppColors.surface,
        elevation: 3,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: selected ? Colors.white : AppColors.outline,
                width: selected ? 1.5 : 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 15,
                  color: selected ? Colors.white : color,
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.5,
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

class _HorizontalPlaceCard extends StatelessWidget {
  const _HorizontalPlaceCard({
    required this.place,
    required this.isSelected,
    required this.onTap,
    required this.onDetail,
    required this.onRoute,
  });

  final Place place;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback onDetail;
  final VoidCallback onRoute;

  @override
  Widget build(BuildContext context) {
    final color = placeColor(place.type);
    final distance = place.distanceMeters;

    return Container(
      width: 288,
      margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isSelected ? AppColors.primary : AppColors.outline,
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.25)
                : Colors.black26,
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        placeIcon(place.type),
                        color: Colors.white,
                        size: 18,
                      ),
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
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            place.type.label,
                            style: TextStyle(
                              fontSize: 12,
                              color: color,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (distance != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceHigh,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          formatDistance(distance),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.secondary,
                          ),
                        ),
                      ),
                  ],
                ),
                Text(
                  place.address ?? 'Tersedia di area terdekat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(34),
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          side: const BorderSide(color: AppColors.outline),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: onDetail,
                        child: const Text(
                          'Detail',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.neutral,
                          minimumSize: const Size.fromHeight(34),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        onPressed: onRoute,
                        icon: const Icon(Icons.alt_route_rounded, size: 14),
                        label: const Text(
                          'Rute',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
        border: Border.all(color: Colors.white, width: selected ? 3.5 : 2),
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
                const Icon(
                  Icons.location_off_rounded,
                  color: AppColors.tertiary,
                ),
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
