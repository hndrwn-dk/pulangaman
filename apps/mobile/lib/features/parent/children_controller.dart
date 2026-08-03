import 'dart:async';

import 'package:firebase_analytics/firebase_analytics.dart';
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
    this.access,
  });

  final String id;
  final String name;
  final String? phone;
  final String? lastSeenAt;
  final String? commuteStatus;

  /// `primary` | `co_parent` | `view` from list endpoints; null when unknown.
  final String? access;

  bool get canManageFeatures =>
      access == 'primary' || access == 'co_parent';

  bool get isViewOnlyAccess => access == 'view';

  factory ChildSummary.fromJson(Map<String, dynamic> json) {
    final rawAccess = json['access']?.toString() ??
        json['accessLevel']?.toString() ??
        json['access_level']?.toString();
    return ChildSummary(
      id: json['id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String?,
      lastSeenAt: json['last_seen_at']?.toString() ?? json['lastSeenAt']?.toString(),
      commuteStatus:
          json['commute_status'] as String? ?? json['commuteStatus'] as String?,
      access: rawAccess,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'phone': phone,
        'last_seen_at': lastSeenAt,
        'commute_status': commuteStatus,
        if (access != null) 'access': access,
      };
}

class ChildInvite {
  ChildInvite({
    required this.id,
    required this.code,
    required this.status,
    required this.expiresAt,
    this.createdAt,
    this.childDisplayName,
    this.relinkChildId,
  });

  static const maxTtl = Duration(hours: 24);

  final String id;
  final String code;
  final String status;
  final DateTime expiresAt;
  final DateTime? createdAt;
  final String? childDisplayName;
  final String? relinkChildId;

  /// Pending and not past expiresAt; also hard-caps at [maxTtl] from createdAt
  /// when known (guards bad/far-future expires_at). Missing/unparseable expiry
  /// is treated as already expired.
  bool get isStillValid {
    if (status != 'pending') return false;
    final now = DateTime.now().toUtc();
    if (!expiresAt.toUtc().isAfter(now)) return false;
    if (createdAt != null) {
      final hardCap = createdAt!.toUtc().add(maxTtl);
      if (!hardCap.isAfter(now)) return false;
    }
    return true;
  }

  /// Parses API/cache timestamps; naive values are treated as UTC.
  /// Returns null when missing or unparseable.
  static DateTime? tryParseUtc(Object? raw) {
    if (raw == null) return null;
    if (raw is DateTime) return raw.toUtc();
    final s = raw.toString().trim();
    if (s.isEmpty || s == 'null') return null;
    try {
      final parsed = DateTime.parse(s);
      final hasZone =
          s.endsWith('Z') || RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(s);
      if (!hasZone) {
        return DateTime.utc(
          parsed.year,
          parsed.month,
          parsed.day,
          parsed.hour,
          parsed.minute,
          parsed.second,
          parsed.millisecond,
          parsed.microsecond,
        );
      }
      return parsed.toUtc();
    } catch (_) {
      return null;
    }
  }

  /// Parses API/cache expiry; naive timestamps are treated as UTC.
  static DateTime parseExpiresAt(Object? raw) {
    return tryParseUtc(raw) ??
        DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  }

  factory ChildInvite.fromJson(Map<String, dynamic> json) {
    final expiresRaw = json['expires_at'] ?? json['expiresAt'];
    final createdRaw = json['created_at'] ?? json['createdAt'];
    final createdAt = tryParseUtc(createdRaw);
    var expiresAt = tryParseUtc(expiresRaw);
    // Unparseable/missing expiry: force-expire (or fall back to created+TTL).
    expiresAt ??= createdAt != null
        ? createdAt.add(maxTtl)
        : DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    return ChildInvite(
      id: json['id'] as String,
      code: json['code'] as String,
      status: json['status'] as String? ?? 'pending',
      expiresAt: expiresAt,
      createdAt: createdAt,
      childDisplayName:
          json['child_display_name'] as String? ?? json['childDisplayName'] as String?,
      relinkChildId:
          json['relink_child_id'] as String? ?? json['relinkChildId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'status': status,
        'expires_at': expiresAt.toUtc().toIso8601String(),
        if (createdAt != null) 'created_at': createdAt!.toUtc().toIso8601String(),
        'child_display_name': childDisplayName,
        'relink_child_id': relinkChildId,
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

  /// Pending invites that have not expired (safe for UI).
  List<ChildInvite> get pendingInvites =>
      invites.where((i) => i.isStillValid).toList();

  bool get hasData => items.isNotEmpty || pendingInvites.isNotEmpty;
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
          invites: cached.invites.where((i) => i.isStillValid).toList(),
          fromCache: true,
        );
      }
    }
    await refresh();
  }

  Future<void> refresh({bool force = false}) {
    // Drop time-expired codes even when we skip a network round-trip.
    _pruneExpiredInvites();
    if (!force &&
        _lastOkAt != null &&
        DateTime.now().difference(_lastOkAt!) < _minRefreshGap &&
        state.hasData &&
        _inFlight == null) {
      return Future.value();
    }
    return _inFlight ??= _refreshBody().whenComplete(() => _inFlight = null);
  }

  void _pruneExpiredInvites() {
    final kept = state.pendingInvites;
    if (kept.length == state.invites.length) return;
    state = ChildrenState(
      items: state.items,
      invites: kept,
      loading: state.loading,
      refreshing: state.refreshing,
      fromCache: state.fromCache,
      error: state.error,
    );
  }

  Future<void> _refreshBody() async {
    // Always start from a pruned list so a failed/slow request cannot
    // keep showing codes past TTL (e.g. "coba" after 24h).
    final prunedInvites = state.pendingInvites;
    final showBlockingLoader = !state.hasData;
    state = ChildrenState(
      items: state.items,
      invites: prunedInvites,
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
          .where((invite) => invite.isStillValid)
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
      // Keep children list visible; never keep time-expired invites.
      final keptInvites = state.pendingInvites;
      state = ChildrenState(
        items: state.items,
        invites: keptInvites,
        fromCache: state.fromCache || state.items.isNotEmpty || keptInvites.isNotEmpty,
        error: (state.items.isNotEmpty || keptInvites.isNotEmpty)
            ? null
            : e.toString(),
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
      expiresAt: ChildInvite.parseExpiresAt(data['expiresAt']),
      createdAt: ChildInvite.tryParseUtc(data['createdAt']) ??
          DateTime.now().toUtc(),
      childDisplayName: data['childDisplayName'] as String?,
      relinkChildId:
          data['relinkChildId'] as String? ?? relinkChildId,
    );
    final nameKey = invite.childDisplayName?.trim().toLowerCase();
    final remaining = state.invites.where((it) {
      if (it.code == invite.code) return false;
      if (invite.relinkChildId != null &&
          it.relinkChildId == invite.relinkChildId) {
        return false;
      }
      if (invite.relinkChildId == null &&
          nameKey != null &&
          it.relinkChildId == null &&
          it.childDisplayName?.trim().toLowerCase() == nameKey) {
        return false;
      }
      return it.isStillValid;
    }).toList();
    state = ChildrenState(
      items: state.items,
      invites: [invite, ...remaining],
    );
    final role = _ref.read(authControllerProvider).role;
    if (role != null && role != AppRole.child) {
      unawaited(
        FirebaseAnalytics.instance.logEvent(name: 'child_invite_created'),
      );
    }
    unawaited(refresh(force: true));
    return invite;
  }

  /// True when a still-valid pending invite already exists for this child.
  bool hasPendingInviteForChild(ChildSummary child) {
    return state.invites.any(
      (it) =>
          it.isStillValid &&
          (it.relinkChildId == child.id ||
              (it.relinkChildId == null &&
                  it.childDisplayName?.trim().toLowerCase() ==
                      child.name.trim().toLowerCase())),
    );
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

  /// Revoke a pending invite so it disappears from PENDING CODES immediately.
  Future<void> revokeInvite(String inviteId) async {
    final api = _ref.read(apiClientProvider);
    await api.post('/api/v1/child-invites/$inviteId/revoke');
    final kept = state.invites.where((i) => i.id != inviteId).toList();
    state = ChildrenState(
      items: state.items,
      invites: kept,
      fromCache: false,
    );
    final key = _cacheKey;
    if (key != null) {
      unawaited(
        ChildrenLocalCache.instance.write(
          parentKey: key,
          items: state.items,
          invites: kept,
        ),
      );
    }
  }

  Future<void> clearCache() async {
    final key = _cacheKey;
    if (key != null) await ChildrenLocalCache.instance.clear(key);
  }
}
