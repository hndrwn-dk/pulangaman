import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/day_period.dart';
import '../../core/locale_controller.dart';
import '../../core/network/ws_client.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../screentime/screen_time_screen.dart';
import 'account_settings_screen.dart';
import 'child_avatar.dart';
import 'child_detail_screen.dart';
import 'child_home_map_card.dart';
import 'children_controller.dart';
import 'emergency_meeting_screen.dart';
import 'kabar_inbox_screen.dart';
import 'kabar_models.dart';
import 'kabar_read_store.dart';
import 'live_map_screen.dart';
import 'more_screen.dart';
import 'remove_child_sheet.dart';
import 'sign_in_code_sheet.dart';
import 'zones_screen.dart';
import 'zone_alert_host.dart';

class ParentHomeScreen extends ConsumerStatefulWidget {
  const ParentHomeScreen({super.key});

  @override
  ConsumerState<ParentHomeScreen> createState() => _ParentHomeScreenState();
}

class _ParentHomeScreenState extends ConsumerState<ParentHomeScreen>
    with WidgetsBindingObserver {
  final _ws = WsClient();
  final _kabarRead = KabarReadStore();
  final List<ChildKabarMessage> _messages = [];
  Set<String> _subscribedChildren = {};
  final Map<String, ChildGender> _genders = {};
  final Map<String, LatLng> _positions = {};
  final Map<String, int?> _batteryLevels = {};
  final Map<String, bool> _batteryCharging = {};
  final Map<String, bool> _staleByChild = {};
  final Map<String, DateTime?> _updatedAt = {};
  String? _selectedChildId;
  Map<String, dynamic>? _activitySummary;
  Map<String, dynamic>? _empActivation;
  Timer? _locationPoll;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    Future.microtask(() async {
      await _kabarRead.load();
      await ref.read(childrenControllerProvider.notifier).bootstrap();
      await _loadGenders();
      await _loadMessages();
      await _loadLocations();
      await _loadEmpActivation();
      await _connectWs();
      _locationPoll?.cancel();
      _locationPoll = Timer.periodic(
        const Duration(seconds: 20),
        (_) {
          unawaited(_loadLocations());
          unawaited(_loadEmpActivation());
        },
      );
    });
  }

  Future<void> _loadGenders() async {
    final children = ref.read(childrenControllerProvider).items;
    final map = <String, ChildGender>{};
    for (final c in children) {
      var g = await ChildGenderStore.instance.get(c.id);
      if (g == ChildGender.unknown) {
        g = ChildGenderStore.guessFromName(c.name);
      }
      map[c.id] = g;
    }
    if (!mounted) return;
    setState(() {
      _genders
        ..clear()
        ..addAll(map);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _locationPoll?.cancel();
    _ws.removeHandler(_onWs);
    unawaited(_ws.disconnect());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(childrenControllerProvider.notifier).refresh();
      unawaited(_loadMessages());
      unawaited(_loadLocations());
      unawaited(_connectWs());
    }
  }

  Future<void> _loadEmpActivation() async {
    try {
      final data = await ref
          .read(apiClientProvider)
          .get('/api/v1/emergency-meeting-points/activation');
      if (!mounted) return;
      final activation = data['activation'];
      setState(() {
        _empActivation =
            activation is Map<String, dynamic> ? activation : null;
      });
    } catch (_) {}
  }

  Future<void> _loadLocations() async {
    final children = ref.read(childrenControllerProvider).items;
    if (children.isEmpty) return;
    final api = ref.read(apiClientProvider);
    final nextPos = <String, LatLng>{..._positions};
    final nextBat = <String, int?>{..._batteryLevels};
    final nextCharge = <String, bool>{..._batteryCharging};
    final nextStale = <String, bool>{..._staleByChild};
    final nextAt = <String, DateTime?>{..._updatedAt};

    await Future.wait(children.map((c) async {
      try {
        final data = await api.get('/api/v1/children/${c.id}/location');
        final loc = data['location'] as Map<String, dynamic>?;
        final lat = (loc?['lat'] as num?)?.toDouble();
        final lng = (loc?['lng'] as num?)?.toDouble();
        final recorded = loc?['recordedAt'] as String?;
        nextStale[c.id] = data['isStale'] == true;
        nextBat[c.id] = (data['batteryLevel'] as num?)?.toInt() ??
            (loc?['batteryLevel'] as num?)?.toInt();
        nextCharge[c.id] =
            data['batteryCharging'] == true || loc?['batteryCharging'] == true;
        if (recorded != null) {
          nextAt[c.id] = DateTime.tryParse(recorded)?.toLocal();
        }
        if (lat != null && lng != null) {
          nextPos[c.id] = LatLng(lat, lng);
        }
      } catch (_) {}
    }));
    if (!mounted) return;
    setState(() {
      _positions
        ..clear()
        ..addAll(nextPos);
      _batteryLevels
        ..clear()
        ..addAll(nextBat);
      _batteryCharging
        ..clear()
        ..addAll(nextCharge);
      _staleByChild
        ..clear()
        ..addAll(nextStale);
      _updatedAt
        ..clear()
        ..addAll(nextAt);
    });
  }

  Future<void> _loadActivityFor(String childId) async {
    try {
      final data =
          await ref.read(apiClientProvider).get('/api/v1/children/$childId/activity');
      if (!mounted || _selectedChildId != childId) return;
      setState(() {
        _activitySummary = data['summary'] as Map<String, dynamic>?;
      });
    } catch (_) {
      if (!mounted || _selectedChildId != childId) return;
      setState(() => _activitySummary = null);
    }
  }

  void _selectChild(String childId) {
    if (_selectedChildId == childId) return;
    setState(() {
      _selectedChildId = childId;
      _activitySummary = null;
    });
    unawaited(_loadActivityFor(childId));
  }

  Future<void> _loadMessages() async {
    try {
      final data = await ref.read(apiClientProvider).get('/api/v1/messages');
      final list = (data['messages'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChildKabarMessage.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _messages
          ..clear()
          ..addAll(list);
      });
    } catch (_) {}
  }

  Future<void> _connectWs() async {
    final token = ref.read(authControllerProvider).token;
    if (token == null) return;
    try {
      if (!_ws.isConnected) {
        await _ws.connect(token);
        _ws.addHandler(_onWs);
      }
      _syncSubscriptions();
    } catch (_) {}
  }

  void _syncSubscriptions() {
    final children = ref.read(childrenControllerProvider).items;
    final ids = children.map((c) => c.id).toSet();
    for (final id in ids.difference(_subscribedChildren)) {
      _ws.subscribe('child:$id');
    }
    _subscribedChildren = ids;
  }

  void _onWs(String event, Map<String, dynamic> payload) {
    if (event == 'child:location_update') {
      final childId = payload['childId'] as String?;
      final lat = (payload['lat'] as num?)?.toDouble();
      final lng = (payload['lng'] as num?)?.toDouble();
      if (childId != null && lat != null && lng != null && mounted) {
        setState(() {
          _positions[childId] = LatLng(lat, lng);
          _staleByChild[childId] = false;
          _updatedAt[childId] = DateTime.now();
          final bl = (payload['batteryLevel'] as num?)?.toInt();
          if (bl != null) _batteryLevels[childId] = bl;
          if (payload.containsKey('batteryCharging')) {
            _batteryCharging[childId] = payload['batteryCharging'] == true;
          }
        });
      }
      return;
    }
    if (event == 'child:panic_triggered' ||
        event == 'child:panic_acked' ||
        event == 'child:panic_resolved') {
      unawaited(_loadMessages());
      return;
    }
    if (event != 'child:message') return;
    final msg = ChildKabarMessage.fromJson({
      'id': payload['id'] ??
          '${payload['childId']}-${payload['sentAt']}-${payload['text']}',
      'childId': payload['childId'],
      'childName': payload['childName'],
      'text': payload['text'],
      'preset': payload['preset'],
      'sentAt': payload['sentAt'] ?? DateTime.now().toIso8601String(),
    });
    if (!mounted) return;
    setState(() {
      _messages.removeWhere((m) => m.id == msg.id);
      _messages.insert(0, msg);
      if (_messages.length > 50) {
        _messages.removeRange(50, _messages.length);
      }
    });
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${msg.childName}: ${msg.text}'),
        backgroundColor: msg.isUrgent ? AppColors.coral : AppColors.tealDeep,
      ),
    );
  }

  Future<void> _markAllKabarRead() async {
    DateTime? newest;
    for (final m in _messages) {
      if (newest == null || m.sentAt.isAfter(newest)) {
        newest = m.sentAt;
      }
    }
    await _kabarRead.markAllRead(newest ?? DateTime.now());
    if (mounted) setState(() {});
  }

  void _openInbox({String? childId}) {
    unawaited(_loadMessages().then((_) {
      if (!mounted) return;
      final children = ref.read(childrenControllerProvider).items;
      final names = {for (final c in children) c.id: c.name};
      final unreadIds = {
        for (final m in _messages)
          if (_kabarRead.isUnread(m)) m.id,
      };
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => KabarInboxScreen(
            messages: List<ChildKabarMessage>.from(_messages),
            initialChildId: childId,
            childNames: names,
            unreadIds: unreadIds,
            onMarkAllRead: _markAllKabarRead,
          ),
        ),
      ).then((_) {
        if (mounted) setState(() {});
      });
    }));
  }

  String _greeting(AppLocalizations l10n) => dayPeriodFor().greeting(l10n);

  IconData _greetingIcon() => dayPeriodFor().icon;

  Color _greetingIconColor() => dayPeriodFor().accent;

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'PA';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return ('${parts[0][0]}${parts[1][0]}').toUpperCase();
  }

  String? _stayDurationLabel() {
    final places = (_activitySummary?['places'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .toList();
    if (places.isEmpty) return null;
    final sec = (places.first['durationSeconds'] as num?)?.toInt() ?? 0;
    if (sec <= 0) return null;
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    if (h > 0) return '${h}j ${m}m';
    return '${m}m';
  }

  void _openChildDetail(ChildSummary child) {
    final gender =
        _genders[child.id] ?? ChildGenderStore.guessFromName(child.name);
    Navigator.of(context)
        .push(
      MaterialPageRoute(
        builder: (_) => ChildDetailScreen(
          child: child,
          gender: gender,
          initialKabar: List<ChildKabarMessage>.from(_messages),
        ),
      ),
    )
        .then((_) {
      if (mounted) unawaited(_loadGenders());
    });
  }

  Future<void> _editChildGender(ChildSummary child) async {
    final current =
        _genders[child.id] ?? ChildGenderStore.guessFromName(child.name);
    final picked = await showChildGenderPicker(
      context: context,
      childName: child.name,
      current: current,
    );
    if (picked == null || !mounted) return;
    await ChildGenderStore.instance.set(child.id, picked);
    if (!mounted) return;
    setState(() => _genders[child.id] = picked);
  }

  void _openLiveMap(ChildSummary child) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => LiveMapScreen(child: child)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final children = ref.watch(childrenControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final unread = _kabarRead.unreadOf(_messages);
    final urgent = _kabarRead.unreadUrgentOf(_messages);
    final items = children.items;

    if (items.isNotEmpty) {
      final ids = items.map((c) => c.id).toSet();
      if (_selectedChildId == null || !ids.contains(_selectedChildId)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final id = items.first.id;
          setState(() => _selectedChildId = id);
          unawaited(_loadActivityFor(id));
        });
      }
    }

    if (items.isNotEmpty && _genders.length < items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadGenders());
    }
    if (items.isNotEmpty && _positions.length < items.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadLocations());
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (items.isNotEmpty) _syncSubscriptions();
    });

    final selected = items.isEmpty
        ? null
        : items.firstWhere(
            (c) => c.id == _selectedChildId,
            orElse: () => items.first,
          );
    final placeCount = _activitySummary?['placeCount'] as int? ??
        ((_activitySummary?['places'] as List?)?.length ?? 0);
    final distM =
        (_activitySummary?['totalDistanceM'] as num?)?.toDouble() ?? 0.0;
    final distLabel = distM >= 1000
        ? '${(distM / 1000).toStringAsFixed(1)} km'
        : '${distM.round()} m';

    return Scaffold(
      backgroundColor: visualRefreshOf(context)
          ? VisualRefreshColors.background
          : const Color(0xFFF0F2F5),
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.teal,
          onRefresh: () async {
            await ref
                .read(childrenControllerProvider.notifier)
                .refresh(force: true);
            await _loadGenders();
            await _loadMessages();
            await _loadLocations();
            final id = _selectedChildId;
            if (id != null) await _loadActivityFor(id);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _HomeHeader(
                greeting: _greeting(l10n),
                greetingIcon: _greetingIcon(),
                greetingIconColor: _greetingIconColor(),
                name: auth.name ?? l10n.parentFallbackName,
                initials: _initials(auth.name),
                notificationCount: unread.length,
                onNotifications: () => _openInbox(),
                onAccount: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const AccountSettingsScreen(),
                  ),
                ),
              ),
              if (_empActivation != null) ...[
                const SizedBox(height: 14),
                _EmpActiveBanner(
                  activation: _empActivation!,
                  onOpen: () async {
                    await Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const EmergencyMeetingScreen(),
                      ),
                    );
                    await _loadEmpActivation();
                  },
                ),
              ],
              if (urgent.isNotEmpty) ...[
                const SizedBox(height: 14),
                ...urgent.take(2).map(
                      (msg) => _UrgentBanner(
                        msg: msg,
                        onOpen: () => _openInbox(childId: msg.childId),
                        onDismiss: () async {
                          await _kabarRead.markReadThrough(msg);
                          if (mounted) setState(() {});
                        },
                      ),
                    ),
                Align(
                  alignment: Alignment.centerRight,
                    child: TextButton(
                    onPressed: () => unawaited(_markAllKabarRead()),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.coral,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      l10n.markAllReadAction,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 18),
              if (children.loading && !children.hasData)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (items.isEmpty) ...[
                PaEmptyState(
                  icon: Icons.child_care,
                  title: l10n.noChildrenTitle,
                  message: l10n.parentHomeNoChildrenMessage,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => _showRecoverChildren(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.tealDeep,
                    side: const BorderSide(color: AppColors.teal),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text(l10n.recoverChildrenButton),
                ),
              ] else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.childLocationSectionTitle,
                        style: visualRefreshOf(context)
                            ? GoogleFonts.fraunces(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.2,
                                color: VisualRefreshColors.textPrimary,
                              )
                            : const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.2,
                              ),
                      ),
                    ),
                    if (selected != null)
                      TextButton(
                        onPressed: () => _openLiveMap(selected),
                        style: TextButton.styleFrom(
                          foregroundColor: visualRefreshOf(context)
                              ? VisualRefreshColors.accent
                              : AppColors.teal,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          l10n.viewMapAction,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontFamily: visualRefreshOf(context)
                                ? GoogleFonts.plusJakartaSans().fontFamily
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 42,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final c = items[i];
                      final selectedChip = c.id == selected?.id;
                      final online = _staleByChild[c.id] != true &&
                          _positions.containsKey(c.id);
                      return _ChildChip(
                        name: c.name,
                        selected: selectedChip,
                        online: online,
                        gender: _genders[c.id] ??
                            ChildGenderStore.guessFromName(c.name),
                        onTap: () => _selectChild(c.id),
                        onLongPress: () => unawaited(_editChildGender(c)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 14),
                if (selected != null)
                  ChildHomeMapCard(
                    child: selected,
                    gender: _genders[selected.id] ??
                        ChildGenderStore.guessFromName(selected.name),
                    position: _positions[selected.id],
                    batteryLevel: _batteryLevels[selected.id],
                    batteryCharging: _batteryCharging[selected.id] == true,
                    stale: _staleByChild[selected.id] ?? true,
                    updatedAt: _updatedAt[selected.id],
                    stayDurationLabel: _stayDurationLabel(),
                    onRelinkCode: () => _showRelinkInvite(context, selected),
                    onRemove: () => _confirmRemoveChild(context, selected),
                    onOpenMap: () => _openChildDetail(selected),
                  ),
                const SizedBox(height: 22),
                Text(
                  l10n.todaySummaryTitle,
                  style: visualRefreshOf(context)
                      ? GoogleFonts.fraunces(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.2,
                          color: VisualRefreshColors.textPrimary,
                        )
                      : const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        value: '$placeCount',
                        label: l10n.placesVisitedLabel,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _SummaryCard(
                        value: distLabel,
                        label: l10n.totalTripDistanceLabel,
                      ),
                    ),
                  ],
                ),
              ],
              if (children.pendingInvites.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text(
                  visualRefreshOf(context)
                      ? l10n.pendingCodesTitle.toUpperCase()
                      : l10n.pendingCodesTitle,
                  style: visualRefreshOf(context)
                      ? const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                          color: VisualRefreshColors.textTertiary,
                        )
                      : const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                ),
                const SizedBox(height: 10),
                ...children.pendingInvites.map((invite) {
                  final refresh = visualRefreshOf(context);
                  final codeLabel = refresh
                      ? SignInCodeSheet.formatSpacedCode(invite.code)
                      : invite.code;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: refresh
                          ? VisualRefreshColors.surface
                          : Colors.white,
                      borderRadius: BorderRadius.circular(
                        refresh ? AppRadius.vrCard : 16,
                      ),
                      border: refresh
                          ? Border.all(
                              color: VisualRefreshColors.border,
                              width: 0.5,
                            )
                          : null,
                      boxShadow: refresh
                          ? null
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.vpn_key,
                          color: refresh
                              ? VisualRefreshColors.accent
                              : AppColors.teal,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                codeLabel,
                                style: TextStyle(
                                  fontSize: refresh ? 22 : 26,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: refresh ? 2.5 : 3,
                                  fontFamily: refresh ? 'monospace' : null,
                                  color: refresh
                                      ? VisualRefreshColors.textPrimary
                                      : null,
                                ),
                              ),
                              if (invite.childDisplayName != null)
                                Text(
                                  invite.childDisplayName!,
                                  style: TextStyle(
                                    color: refresh
                                        ? VisualRefreshColors.textSecondary
                                        : AppColors.inkSoft,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: l10n.dismissPendingCodeTooltip,
                          visualDensity: VisualDensity.compact,
                          onPressed: () =>
                              _dismissPendingInvite(context, invite),
                          icon: Icon(
                            Icons.close,
                            size: 22,
                            color: refresh
                                ? VisualRefreshColors.textPrimary
                                : AppColors.ink,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
              if (children.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  children.error!,
                  style: const TextStyle(color: AppColors.danger, fontSize: 15),
                ),
              ],
              const SizedBox(height: 18),
              _AddChildButton(onTap: () => _showCreateInvite(context)),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showRecoverChildren(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final phoneCtrl = TextEditingController(text: '+628126281233300011');
    final previous = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.recoverChildrenTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.recoverChildrenPrompt),
            const SizedBox(height: 12),
            TextField(
              controller: phoneCtrl,
              keyboardType: TextInputType.phone,
              decoration: InputDecoration(
                labelText: l10n.oldPhoneNumberLabel,
                hintText: '+62812...',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, phoneCtrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            child: Text(l10n.recoverAction),
          ),
        ],
      ),
    );
    // Dispose after the dialog route is fully gone (avoids red-screen assertion).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      phoneCtrl.dispose();
    });
    if (previous == null || previous.isEmpty || !context.mounted) return;

    try {
      final count = await ref
          .read(authControllerProvider.notifier)
          .recoverChildrenFromPhone(previous);
      if (!context.mounted) return;
      await ref.read(childrenControllerProvider.notifier).refresh();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            count > 0
                ? l10n.recoverChildrenSuccess(count)
                : l10n.recoverChildrenNone,
          ),
        ),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.recoverChildrenFailed('$e'))),
      );
    }
  }

  Future<void> _dismissPendingInvite(
    BuildContext context,
    ChildInvite invite,
  ) async {
    final l10n = AppLocalizations.of(context);
    final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) {
            final refresh = visualRefreshOf(ctx);
            return AlertDialog(
              backgroundColor: refresh ? VisualRefreshColors.surface : null,
              shape: refresh
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    )
                  : null,
              title: Text(l10n.dismissPendingCodeTooltip),
              content: Text(l10n.dismissPendingCodeConfirm),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: refresh
                        ? VisualRefreshColors.anchor
                        : AppColors.teal,
                  ),
                  child: Text(l10n.dismissPendingCodeTooltip),
                ),
              ],
            );
          },
        ) ==
        true;
    if (!ok || !context.mounted) return;
    try {
      await ref
          .read(childrenControllerProvider.notifier)
          .revokeInvite(invite.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.pendingCodeDismissedSnack)),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.dismissPendingCodeFailed('$e'))),
      );
    }
  }

  Future<void> _showRelinkInvite(BuildContext context, ChildSummary child) async {
    final l10n = AppLocalizations.of(context);
    final hasPending = ref
        .read(childrenControllerProvider.notifier)
        .hasPendingInviteForChild(child);
    if (hasPending) {
      final proceed = await showDialog<bool>(
            context: context,
            builder: (ctx) {
              final refresh = visualRefreshOf(ctx);
              return AlertDialog(
                backgroundColor:
                    refresh ? VisualRefreshColors.surface : null,
                shape: refresh
                    ? RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      )
                    : null,
                title: Text(
                  l10n.relinkCodeTitle(child.name),
                  style: refresh
                      ? GoogleFonts.fraunces(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: VisualRefreshColors.textPrimary,
                        )
                      : null,
                ),
                content: Text(
                  l10n.relinkReplaceConfirmBody(child.name),
                  style: refresh
                      ? const TextStyle(
                          color: VisualRefreshColors.textSecondary,
                          height: 1.35,
                        )
                      : null,
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: refresh
                          ? VisualRefreshColors.anchor
                          : AppColors.teal,
                    ),
                    child: Text(l10n.generateNewCodeAction),
                  ),
                ],
              );
            },
          ) ==
          true;
      if (!proceed || !context.mounted) return;
    }

    try {
      final invite =
          await ref.read(childrenControllerProvider.notifier).createInvite(
                childDisplayName: child.name,
                relinkChildId: child.id,
              );
      if (!context.mounted) return;
      if (visualRefreshOf(context)) {
        await showSignInCodeSheet(
          context: context,
          childName: child.name,
          code: invite.code,
          expiresAt: invite.expiresAt,
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.relinkCodeTitle(child.name)),
            content: Text(
              invite.code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: AppColors.tealDeep,
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                child: Text(l10n.okAction),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.createCodeFailed('$e'))),
      );
    }
  }

  Future<void> _confirmRemoveChild(
    BuildContext context,
    ChildSummary child,
  ) async {
    final l10n = AppLocalizations.of(context);
    final bool ok;
    if (visualRefreshOf(context)) {
      ok = await showRemoveChildSheet(
        context: context,
        childName: child.name,
      );
    } else {
      ok = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(l10n.removeChildConfirmTitle(child.name)),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(l10n.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style:
                      FilledButton.styleFrom(backgroundColor: AppColors.coral),
                  child: Text(l10n.delete),
                ),
              ],
            ),
          ) ==
          true;
    }
    if (!ok || !context.mounted) return;
    try {
      await ref.read(childrenControllerProvider.notifier).unlinkChild(child.id);
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.childRemoved(child.name))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.deleteFailedWithDetail('$e'))),
      );
    }
  }

  Future<void> _showCreateInvite(BuildContext context) async {
    final l10n = AppLocalizations.of(context);
    final nameCtrl = TextEditingController();
    final refresh = visualRefreshOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: refresh ? VisualRefreshColors.surface : null,
        surfaceTintColor: refresh ? Colors.transparent : null,
        shape: refresh
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(24))
            : null,
        title: Text(
          l10n.addChildTitle,
          style: refresh
              ? GoogleFonts.fraunces(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: VisualRefreshColors.textPrimary,
                )
              : null,
        ),
        content: TextField(
          controller: nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: l10n.nameLabel,
            filled: refresh,
            fillColor: refresh ? VisualRefreshColors.surface : null,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: refresh
                ? TextButton.styleFrom(
                    foregroundColor: VisualRefreshColors.textPrimary,
                  )
                : null,
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor:
                  refresh ? VisualRefreshColors.anchor : AppColors.teal,
              foregroundColor:
                  refresh ? VisualRefreshColors.background : null,
              shape: refresh ? const StadiumBorder() : null,
            ),
            child: Text(l10n.createCodeAction),
          ),
        ],
      ),
    );
    final name = nameCtrl.text;
    nameCtrl.dispose();
    if (ok != true || !context.mounted) return;

    try {
      final invite =
          await ref.read(childrenControllerProvider.notifier).createInvite(
                childDisplayName: name,
              );
      if (!context.mounted) return;
      final displayName = name.trim().isEmpty
          ? invite.childDisplayName ?? invite.code
          : name.trim();
      if (visualRefreshOf(context)) {
        await showSignInCodeSheet(
          context: context,
          childName: displayName,
          code: invite.code,
          expiresAt: invite.expiresAt,
        );
      } else {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(l10n.codeTitle),
            content: Text(
              invite.code,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
                color: AppColors.tealDeep,
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(ctx),
                style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
                child: Text(l10n.okAction),
              ),
            ],
          ),
        );
      }
      if (context.mounted) {
        await ref.read(childrenControllerProvider.notifier).refresh(force: true);
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.createCodeFailed('$e'))),
      );
    }
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({
    required this.greeting,
    required this.greetingIcon,
    required this.greetingIconColor,
    required this.name,
    required this.initials,
    required this.notificationCount,
    required this.onNotifications,
    required this.onAccount,
  });

  final String greeting;
  final IconData greetingIcon;
  final Color greetingIconColor;
  final String name;
  final String initials;
  final int notificationCount;
  final VoidCallback onNotifications;
  final VoidCallback onAccount;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: refresh
                ? VisualRefreshColors.weatherTint
                : greetingIconColor.withValues(alpha: 0.16),
            shape: BoxShape.circle,
          ),
          child: Icon(
            greetingIcon,
            color: refresh
                ? VisualRefreshColors.anchor
                : greetingIconColor,
            size: 24,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$greeting,',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: refresh
                      ? VisualRefreshColors.textSecondary
                      : AppColors.inkSoft,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: refresh
                    ? GoogleFonts.fraunces(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        color: VisualRefreshColors.textPrimary,
                      )
                    : const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                        color: AppColors.ink,
                      ),
              ),
            ],
          ),
        ),
        Stack(
          clipBehavior: Clip.none,
          children: [
            Material(
              color: refresh ? VisualRefreshColors.surface : Colors.white,
              shape: CircleBorder(
                side: refresh
                    ? const BorderSide(
                        color: VisualRefreshColors.border,
                        width: 0.5,
                      )
                    : BorderSide.none,
              ),
              elevation: refresh ? 0 : 1,
              shadowColor: Colors.black12,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onNotifications,
                child: SizedBox(
                  width: 42,
                  height: 42,
                  child: Icon(
                    Icons.notifications_none_rounded,
                    size: 22,
                    color: refresh
                        ? VisualRefreshColors.textPrimary
                        : null,
                  ),
                ),
              ),
            ),
            if (notificationCount > 0)
              Positioned(
                right: -2,
                top: -2,
                child: Container(
                  constraints: const BoxConstraints(minWidth: 18),
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  height: 18,
                  decoration: BoxDecoration(
                    color: refresh
                        ? VisualRefreshColors.danger
                        : AppColors.coral,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    notificationCount > 9 ? '9+' : '$notificationCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(width: 8),
        Material(
          color: refresh ? VisualRefreshColors.anchor : AppColors.tealDeep,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onAccount,
            child: SizedBox(
              width: 40,
              height: 40,
              child: Center(
                child: Text(
                  initials,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                    fontFamily: refresh
                        ? GoogleFonts.plusJakartaSans().fontFamily
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ChildChip extends StatelessWidget {
  const _ChildChip({
    required this.name,
    required this.selected,
    required this.online,
    required this.gender,
    required this.onTap,
    this.onLongPress,
  });

  final String name;
  final bool selected;
  final bool online;
  final ChildGender gender;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    final selectedFill =
        refresh ? VisualRefreshColors.anchor : AppColors.tealDeep;
    final selectedFg =
        refresh ? VisualRefreshColors.background : Colors.white;
    final unselectedFg =
        refresh ? VisualRefreshColors.anchor : AppColors.ink;
    return Material(
      color: selected ? selectedFill : (refresh ? VisualRefreshColors.surface : Colors.white),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 4, 12, 4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? null
                : Border.all(
                    color: refresh
                        ? VisualRefreshColors.border
                        : const Color(0xFFE2E6EA),
                    width: refresh ? 0.5 : 1,
                  ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  ChildAvatar(name: name, gender: gender, size: 30),
                  Positioned(
                    right: -1,
                    bottom: -1,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: online
                            ? (refresh
                                ? VisualRefreshColors.accent
                                : const Color(0xFF22C55E))
                            : (refresh
                                ? VisualRefreshColors.textSecondary
                                : const Color(0xFFFBBF24)),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected
                              ? selectedFill
                              : (refresh
                                  ? VisualRefreshColors.surface
                                  : Colors.white),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13.5,
                  color: selected ? selectedFg : unselectedFg,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: refresh ? VisualRefreshColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(refresh ? AppRadius.vrCard : 20),
        border: refresh
            ? Border.all(color: VisualRefreshColors.border, width: 0.5)
            : null,
        boxShadow: refresh
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: refresh
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            value,
            textAlign: refresh ? TextAlign.center : TextAlign.start,
            style: refresh
                ? GoogleFonts.fraunces(
                    fontSize: 28,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.8,
                    height: 1.05,
                    color: VisualRefreshColors.textPrimary,
                  )
                : const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.8,
                    height: 1.05,
                    color: AppColors.teal,
                  ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: refresh ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: refresh
                  ? VisualRefreshColors.textSecondary
                  : AppColors.inkSoft,
              fontFamily: refresh
                  ? GoogleFonts.plusJakartaSans().fontFamily
                  : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _AddChildButton extends StatelessWidget {
  const _AddChildButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final fill = refresh
        ? VisualRefreshColors.accentTint
        : const Color(0xFFE8F6F1);
    final dash = refresh
        ? VisualRefreshColors.dashedAction
        : AppColors.teal.withValues(alpha: 0.55);
    final fg = refresh ? VisualRefreshColors.anchor : AppColors.tealDeep;
    final radius = refresh ? AppRadius.pill : 16.0;
    return Material(
      color: fill,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: CustomPaint(
          painter: _DashedBorderPainter(
            color: dash,
            radius: radius,
          ),
          child: SizedBox(
            height: 54,
            width: double.infinity,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_rounded, color: fg),
                const SizedBox(width: 8),
                Text(
                  l10n.addChildTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: fg,
                    fontFamily: refresh
                        ? GoogleFonts.plusJakartaSans().fontFamily
                        : null,
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

class _DashedBorderPainter extends CustomPainter {
  _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.8, 0.8, size.width - 1.6, size.height - 1.6),
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      const dash = 6.0;
      const gap = 4.0;
      while (distance < metric.length) {
        final next = (distance + dash).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(distance, next), paint);
        distance = next + gap;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.radius != radius;
}

class _EmpActiveBanner extends StatelessWidget {
  const _EmpActiveBanner({required this.activation, required this.onOpen});

  final Map<String, dynamic> activation;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final children = (activation['children'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .where((c) => c['notified'] == true)
        .toList();
    final arrived = children.where((c) => c['arrived'] == true).length;
    final pending = children
        .where((c) => c['arrived'] != true)
        .map((c) => c['childName'] as String? ?? '')
        .where((n) => n.isNotEmpty)
        .toList();
    final subtitle = children.isEmpty
        ? l10n.tapToViewStatus
        : pending.isEmpty
            ? l10n.allChildrenArrived
            : l10n.arrivedWaitingSummary(
                arrived,
                children.length,
                pending.join(', '),
              );

    final radius = BorderRadius.circular(refresh ? AppRadius.vrCard : 16);

    return Material(
      color: refresh
          ? VisualRefreshColors.dangerTint
          : const Color(0xFFFFE8E6),
      borderRadius: radius,
      child: InkWell(
        onTap: onOpen,
        borderRadius: radius,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: refresh
              ? BoxDecoration(
                  borderRadius: radius,
                  border: Border.all(
                    color: VisualRefreshColors.dangerTintBorder,
                    width: 0.5,
                  ),
                )
              : null,
          child: Row(
            children: [
              Icon(
                refresh
                    ? Icons.notifications_outlined
                    : Icons.notifications_active_rounded,
                color: refresh
                    ? VisualRefreshColors.danger
                    : AppColors.danger,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.empBannerActiveTitle,
                      style: refresh
                          ? GoogleFonts.fraunces(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                              color: VisualRefreshColors.danger,
                            )
                          : const TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppColors.danger,
                            ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                        color: refresh
                            ? VisualRefreshColors.dangerTintText
                            : AppColors.ink,
                        fontFamily: refresh
                            ? GoogleFonts.plusJakartaSans().fontFamily
                            : null,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: refresh
                    ? VisualRefreshColors.textTertiary
                    : AppColors.inkSoft,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UrgentBanner extends StatelessWidget {
  const _UrgentBanner({
    required this.msg,
    required this.onOpen,
    required this.onDismiss,
  });

  final ChildKabarMessage msg;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: const Color(0xFFFFE8E6),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onOpen,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: const BoxDecoration(
                    color: AppColors.coral,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.priority_high_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.childNeedsHelp(msg.childName),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: AppColors.coral,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.withTapDetail(kabarRelativeTime(l10n, msg.sentAt)),
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF9A3B35),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: l10n.markReadAction,
                  onPressed: onDismiss,
                  icon: const Icon(Icons.close, color: AppColors.coral),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Selected tab index for [ParentShell]'s bottom navigation.
///
/// Exposed as a provider so routes pushed on top of the shell (e.g. child
/// detail) can switch tabs and pop back to the shell chrome instead of
/// leaving the user on a bare, dead-end screen.
final parentShellTabProvider = StateProvider<int>((ref) => 0);

class ParentShell extends ConsumerStatefulWidget {
  const ParentShell({super.key});

  @override
  ConsumerState<ParentShell> createState() => _ParentShellState();
}

class _ParentShellState extends ConsumerState<ParentShell> {
  @override
  Widget build(BuildContext context) {
    final locale = ref.watch(localeControllerProvider);
    final l10n = AppLocalizations.of(context);
    final index = ref.watch(parentShellTabProvider);
    final refresh = visualRefreshOf(context);
    final pages = [
      const ParentHomeScreen(),
      const ScreenTimeScreen(),
      const PlacesEntryScreen(),
      const MoreScreen(),
    ];
    return ParentZoneAlertHost(
      child: Scaffold(
        body: IndexedStack(index: index, children: pages),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: refresh
                ? VisualRefreshColors.surface
                : Colors.white,
            border: refresh
                ? const Border(
                    top: BorderSide(
                      color: VisualRefreshColors.border,
                      width: 0.5,
                    ),
                  )
                : null,
          ),
          child: NavigationBar(
            key: ValueKey('parent-nav-${locale.languageCode}'),
            selectedIndex: index,
            onDestinationSelected: (value) {
              ref.read(parentShellTabProvider.notifier).state = value;
              if (value == 0) {
                unawaited(
                  ref.read(childrenControllerProvider.notifier).refresh(),
                );
              }
            },
            destinations: [
              NavigationDestination(
                icon: const Icon(Icons.family_restroom_outlined),
                selectedIcon: Icon(
                  refresh
                      ? Icons.family_restroom_outlined
                      : Icons.family_restroom,
                ),
                label: l10n.navChildrenLabel,
              ),
              NavigationDestination(
                icon: const Icon(Icons.timer_outlined),
                selectedIcon: Icon(
                  refresh ? Icons.timer_outlined : Icons.timer,
                ),
                label: l10n.featureScreenTime,
              ),
              NavigationDestination(
                icon: const Icon(Icons.home_work_outlined),
                selectedIcon: Icon(
                  refresh ? Icons.home_work_outlined : Icons.home_work,
                ),
                label: l10n.navZonesLabel,
              ),
              NavigationDestination(
                icon: const Icon(Icons.grid_view_outlined),
                selectedIcon: Icon(
                  refresh ? Icons.grid_view_outlined : Icons.grid_view,
                ),
                label: l10n.navMoreLabel,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
