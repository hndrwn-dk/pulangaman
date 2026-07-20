import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../parent/zones_screen.dart';

/// Legacy entry — digabung ke Lokasi penting (rumah + sekolah + rute).
class SafeRouteScreen extends ConsumerWidget {
  const SafeRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const PlacesEntryScreen();
  }
}
