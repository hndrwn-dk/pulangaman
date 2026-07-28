import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pulangaman/core/config.dart';
import 'package:pulangaman/features/parent/visual_refresh_flag.dart';

void main() {
  test('visual refresh is always on', () {
    expect(AppConfig.visualRefresh, isTrue);
  });

  test('provider always returns true', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(visualRefreshEnabledProvider), isTrue);
  });
}
