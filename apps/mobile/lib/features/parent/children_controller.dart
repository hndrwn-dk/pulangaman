import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import 'children_local_cache.dart';

class ChildSummary {
  ChildSummary({
    required this.id,
    required this.name,
    this.phone,
    this.lastSeenAt,
    this.commuteStatus,
  });

  final String id;
  final String name;
  final String? phone;
  final String? lastSeenAt;
  final String? commuteStatus;

  factory ChildSummary.fromJson(Map<String, dynamic> json) {
    return ChildSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      lastSeenAt: json['last_seen_at']?.toString() ?? json['lastSeenAt']?.toString(),
      commuteStatus:
          json['commute_status'] as String? ?? json['commuteStatus'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'last_seen_at': lastSeenAt,
        'commute_status': commuteStatus,
      };
}

class ChildInvite {
  ChildInvite({
    required this.id,
    required this.code,
    required this.status,
    required this.expiresAt,
    this.childDisplayName,
  });

  final String id;
  final String code;
  final String status;
  final DateTime expiresAt;
  final String? childDisplayName;

  factory ChildInvite.fromJson(Map<String, dynamic> json) {
    final expires = json['expires_at'] ?? json['expiresAt'];
    return ChildInvite(
      id: json['id'] as String,
      code: json['code'] as String,
      status: json['status'] as String? ?? 'pending',
      expiresAt: DateTime.parse(expires as String),
      childDisplayName:
          json['child_display_name'] as String? ?? json['childDisplayName'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'status': status,
        'expires_at': expiresAt.toIso8601String(),
        'child_display_name': childDisplayName,
      };
}

class ChildrenState {
  const ChildrenState({
    this.items = const [],
    this.invites = const [],
    this.loading = false,
    this.refreshing = false,
    this.error,
    this.fromCache = false,
  });

  final List<ChildSummary> items;
  final List<ChildInvite> invites;

  /// True only on first load when there is nothing to show yet.
  final bool loading;

  /// Background revalidation; UI should keep showing [items].
  final bool refreshing;
  final String? error;
  final bool fromCache;

  bool get hasData => items.isNotEmpty || invites.isNotEmpty;
}

final childrenControllerProvider =
    StateNotifierProvider<ChildrenController, ChildrenState>((ref) {
  return ChildrenController(ref);
});

class ChildrenController extends StateNotifier<ChildrenState> {
  ChildrenController(this._ref) : super(const ChildrenState());

  final Ref _ref;
  Future<void>? _inFlight;
  DateTime? _lastOkAt;
  static const _minRefreshGap = Duration(seconds: 8);
  static const _requestTimeout = Duration(seconds: 25);

  String? get _cacheKey {
    final auth = _ref.read(authControllerProvider);
    return auth.userId ?? auth.token;
  }

  /// Show disk cache immediately, then refresh from network.
  Future<void> bootstrap() async {
    final key = _cacheKey;
    if (key != null && !state.hasData) {
      final cached = await ChildrenLocalCache.instance.read(key);
      if (cached != null && (cached.items.isNotEmpty || cached.invites.isNotEmpty)) {
        state = ChildrenState(
          items: cached.items,
          invites: cached.invites,
          fromCache: true,
        );
      }
    }
    await refresh();
  }

  Future<void> refresh({bool force = false}) {
    if (!force &&
        _lastOkAt != null &&
        DateTime.now().difference(_lastOkAt!) < _minRefreshGap &&
        state.hasData &&
        _inFlight == null) {
      return Future.value();
    }
    return _inFlight ??= _refreshBody().whenComplete(() => _inFlight = null);
  }

  Future<void> _refreshBody() async {
    final showBlockingLoader = !state.hasData;
    state = ChildrenState(
      items: state.items,
      invites: state.invites,
      loading: showBlockingLoader,
      refreshing: !showBlockingLoader,
      fromCache: state.fromCache,
      error: null,
    );

    try {
      final api = _ref.read(apiClientProvider);
      final results = await Future.wait([
        api.get('/api/v1/children').timeout(_requestTimeout),
        api.get('/api/v1/child-invites').timeout(_requestTimeout),
      ]);

      final list = (results[0]['children'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(ChildSummary.fromJson)
          .toList();
      final invites = (results[1]['invites'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(ChildInvite.fromJson)
          .where((invite) => invite.status == 'pending')
          .toList();

      state = ChildrenState(items: list, invites: invites);
      _lastOkAt = DateTime.now();

      final key = _cacheKey;
      if (key != null) {
        unawaited(
          ChildrenLocalCache.instance.write(
            parentKey: key,
            items: list,
            invites: invites,
          ),
        );
      }
    } catch (e) {
      // Keep stale list visible; only surface error if we have nothing.
      state = ChildrenState(
        items: state.items,
        invites: state.invites,
        fromCache: state.fromCache || state.hasData,
        error: state.hasData ? null : e.toString(),
      );
    }
  }

  Future<ChildInvite> createInvite({
    String? childDisplayName,
    String? relinkChildId,
  }) async {
    final api = _ref.read(apiClientProvider);
    final data = await api.post('/api/v1/child-invites', body: {
      if (childDisplayName != null && childDisplayName.trim().isNotEmpty)
        'childDisplayName': childDisplayName.trim(),
      if (relinkChildId != null && relinkChildId.isNotEmpty)
        'relinkChildId': relinkChildId,
    });
    final invite = ChildInvite(
      id: data['id'] as String,
      code: data['code'] as String,
      status: 'pending',
      expiresAt: DateTime.parse(data['expiresAt'] as String),
      childDisplayName: data['childDisplayName'] as String?,
    );
    final existing = state.invites.where((it) => it.code != invite.code).toList();
    state = ChildrenState(
      items: state.items,
      invites: [invite, ...existing],
    );
    unawaited(refresh(force: true));
    return invite;
  }

  Future<void> unlinkChild(String childId) async {
    final api = _ref.read(apiClientProvider);
    await api.delete('/api/v1/children/$childId');
    state = ChildrenState(
      items: state.items.where((c) => c.id != childId).toList(),
      invites: state.invites,
      fromCache: false,
    );
    unawaited(refresh(force: true));
  }

  Future<void> clearCache() async {
    final key = _cacheKey;
    if (key != null) await ChildrenLocalCache.instance.clear(key);
  }
}
