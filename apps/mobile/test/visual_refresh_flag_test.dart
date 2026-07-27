import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pulangaman/core/config.dart';
import 'package:pulangaman/core/storage/session_store.dart';
import 'package:pulangaman/features/parent/visual_refresh_flag.dart';

class _MemorySessionStore extends SessionStore {
  final Map<String, String> _data = {};

  @override
  Future<void> save({
    required String token,
    required String userId,
    required String role,
    required String name,
  }) async {
    _data['auth_token'] = token;
    _data['user_id'] = userId;
    _data['role'] = role;
    _data['name'] = name;
  }

  @override
  Future<String?> token() async => _data['auth_token'];

  @override
  Future<String?> userId() async => _data['user_id'];

  @override
  Future<String?> role() async => _data['role'];

  @override
  Future<String?> name() async => _data['name'];

  @override
  Future<void> saveLocale(String languageCode) async {
    _data['locale_override'] = languageCode;
  }

  @override
  Future<String?> locale() async => _data['locale_override'];

  @override
  Future<void> saveVisualRefresh(bool enabled) async {
    _data['visual_refresh'] = enabled ? '1' : '0';
  }

  @override
  Future<bool?> visualRefresh() async {
    final raw = _data['visual_refresh'];
    if (raw == null) return null;
    return raw == '1';
  }

  @override
  Future<void> clearVisualRefresh() async {
    _data.remove('visual_refresh');
  }

  @override
  Future<void> clear() async {
    _data.remove('auth_token');
    _data.remove('user_id');
    _data.remove('role');
    _data.remove('name');
  }
}

void main() {
  test('visual refresh defaults off (compile-time false)', () {
    expect(AppConfig.visualRefresh, isFalse);
  });

  test('VisualRefreshController uses compile-time default when unset',
      () async {
    final store = _MemorySessionStore();
    final controller = VisualRefreshController(
      store: store,
      compileTimeDefault: false,
    );
    await controller.init();
    expect(controller.state, isFalse);
  });

  test('runtime preference overrides compile-time default', () async {
    final store = _MemorySessionStore();
    await store.saveVisualRefresh(true);
    final controller = VisualRefreshController(
      store: store,
      compileTimeDefault: false,
    );
    await controller.init();
    expect(controller.state, isTrue);

    await controller.setEnabled(false);
    expect(controller.state, isFalse);
    expect(await store.visualRefresh(), isFalse);
  });

  test('provider exposes controller state', () async {
    final store = _MemorySessionStore();
    final container = ProviderContainer(
      overrides: [
        sessionStoreProvider.overrideWithValue(store),
      ],
    );
    addTearDown(container.dispose);

    expect(container.read(visualRefreshEnabledProvider), isFalse);
    await container
        .read(visualRefreshEnabledProvider.notifier)
        .setEnabled(true);
    expect(container.read(visualRefreshEnabledProvider), isTrue);
  });
}
