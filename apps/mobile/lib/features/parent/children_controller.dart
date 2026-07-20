import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';

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
      lastSeenAt: json['last_seen_at']?.toString(),
      commuteStatus: json['commute_status'] as String?,
    );
  }
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
    return ChildInvite(
      id: json['id'] as String,
      code: json['code'] as String,
      status: json['status'] as String,
      expiresAt: DateTime.parse(json['expires_at'] as String),
      childDisplayName: json['child_display_name'] as String?,
    );
  }
}

class ChildrenState {
  const ChildrenState({
    this.items = const [],
    this.invites = const [],
    this.loading = false,
    this.error,
  });

  final List<ChildSummary> items;
  final List<ChildInvite> invites;
  final bool loading;
  final String? error;
}

final childrenControllerProvider =
    StateNotifierProvider<ChildrenController, ChildrenState>((ref) {
  return ChildrenController(ref);
});

class ChildrenController extends StateNotifier<ChildrenState> {
  ChildrenController(this._ref) : super(const ChildrenState());

  final Ref _ref;

  Future<void> refresh() async {
    state = ChildrenState(
      items: state.items,
      invites: state.invites,
      loading: true,
    );
    try {
      final api = _ref.read(apiClientProvider);
      final data = await api.get('/api/v1/children');
      final list = (data['children'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(ChildSummary.fromJson)
          .toList();
      final invitesData = await api.get('/api/v1/child-invites');
      final invites = (invitesData['invites'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(ChildInvite.fromJson)
          .where((invite) => invite.status == 'pending')
          .toList();
      state = ChildrenState(items: list, invites: invites);
    } catch (e) {
      state = ChildrenState(
        items: state.items,
        invites: state.invites,
        error: e.toString(),
      );
    }
  }

  Future<ChildInvite> createInvite({String? childDisplayName}) async {
    final api = _ref.read(apiClientProvider);
    final data = await api.post('/api/v1/child-invites', body: {
      if (childDisplayName != null && childDisplayName.trim().isNotEmpty)
        'childDisplayName': childDisplayName.trim(),
    });
    final invite = ChildInvite(
      id: data['id'] as String,
      code: data['code'] as String,
      status: 'pending',
      expiresAt: DateTime.parse(data['expiresAt'] as String),
      childDisplayName: data['childDisplayName'] as String?,
    );
    await refresh();
    return invite;
  }
}
