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

class ChildrenState {
  const ChildrenState({this.items = const [], this.loading = false, this.error});

  final List<ChildSummary> items;
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
    state = ChildrenState(items: state.items, loading: true);
    try {
      final api = _ref.read(apiClientProvider);
      final data = await api.get('/api/v1/children');
      final list = (data['children'] as List<dynamic>? ?? [])
          .cast<Map<String, dynamic>>()
          .map(ChildSummary.fromJson)
          .toList();
      state = ChildrenState(items: list);
    } catch (e) {
      state = ChildrenState(items: state.items, error: e.toString());
    }
  }

  Future<void> addChild({required String name, required String phone}) async {
    final api = _ref.read(apiClientProvider);
    await api.post('/api/v1/children', body: {
      'name': name.trim(),
      'phone': phone.trim(),
    });
    await refresh();
  }
}
