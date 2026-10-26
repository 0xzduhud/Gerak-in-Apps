import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/place_model.dart';

// Warna dan ikon per jenis tempat, dipakai peta, daftar, dan halaman detail.
Color placeColor(PlaceType type) => switch (type) {
      PlaceType.gym => AppColors.primary,
      PlaceType.park => const Color(0xFF2E9E5B),
      PlaceType.field => AppColors.secondary,
    };

IconData placeIcon(PlaceType type) => switch (type) {
      PlaceType.gym => Icons.fitness_center_rounded,
      PlaceType.park => Icons.park_rounded,
      PlaceType.field => Icons.sports_soccer_rounded,
    };