import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pulangaman/features/parent/trip_route_card.dart';

void main() {
  testWidgets('TripRouteCard fills progress bar partially', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: TripRouteCard(
            fromLabel: 'Sekolah',
            toLabel: 'Mall',
            meta: '2.1 km · Estimasi 25 menit',
            progress: 0.4,
            status: 'active',
          ),
        ),
      ),
    );

    expect(find.text('Sekolah → Mall'), findsOneWidget);
    expect(find.text('2.1 km · Estimasi 25 menit'), findsOneWidget);

    final fraction = tester.widget<FractionallySizedBox>(
      find.byType(FractionallySizedBox),
    );
    expect(fraction.widthFactor, closeTo(0.4, 0.001));
  });

  testWidgets('TripRouteCard shows start button when planned', (tester) async {
    var started = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TripRouteCard(
            fromLabel: 'Rumah',
            toLabel: 'Sekolah',
            meta: 'Direncanakan',
            progress: 0,
            status: 'planned',
            onStart: () => started = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Mulai pantau'));
    expect(started, isTrue);
  });
}
