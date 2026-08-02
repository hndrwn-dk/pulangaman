import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/day_period.dart';
import '../../core/network/ws_client.dart';
import '../../core/parse_coord.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../parent/child_avatar.dart';
import '../parent/child_home_map_card.dart';
import '../parent/children_controller.dart';
import '../parent/emergency_meeting_alert_screen.dart';
import '../parent/emergency_meeting_screen.dart';
import '../parent/guardians_screen.dart';
import '../parent/home_by_screen.dart';
import '../parent/kabar_inbox_screen.dart';
import '../parent/kabar_models.dart';
import '../parent/kabar_read_store.dart';
import '../parent/live_map_screen.dart';
import '../parent/reminders_screen.dart';
import '../parent/zones_screen.dart';
import 'guardian_account_screen.dart';

class GuardianHomeScreen extends ConsumerStatefulWidget {
  const GuardianHomeScreen({super.key});

  @override
  ConsumerState<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends ConsumerState<GuardianHomeScreen> {
  final _ws = WsClient();
  final _kabarRead = KabarReadStore();
  final List<ChildKabarMessage> _messages = [];
  List<ChildSummary> _children = [];
  String? _selectedChildId;
  final Map<String, LatLng> _positions = {};
  final Map<String, int?> _batteryLevels = {};
  final Map<String, bool> _batteryCharging = {};
  final Map<String, bool> _staleByChild = {};
  final Map<String, DateTime?> _updatedAt = {};
  final Map<String, ChildGender> _genders = {};
  Timer? _locationPoll;
  String? _alertId;
  String? _alertChildId;
  bool _loadingChildren = true;

  ChildSummary? get _selected {
    if (_children.isEmpty) return null;
    return _children.firstWhere(
      (c) => c.id == _selectedChildId,
      orElse: () => _children.first,
    );
  }

  bool get _canManageSelected {
    final c = _selected;
    if (c == null) return false;
    return c.canManageFeatures;
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
    _locationPoll = Timer.periodic(const Duration(seconds: 20), (_) {
      unawaited(_loadLocations());
    });
  }

  Future<void> _bootstrap() async {
    await _kabarRead.load();
    await _loadChildren();
    final auth = ref.read(authControllerProvider);
    final token = auth.token;
    final userId = auth.userId;
    if (token != null && userId != null) {
      await _ws.connect(token);
      _ws.addHandler(_onWs);
      _ws.subscribe('guardian:$userId');
      _syncChildSubscriptions();
    }
    await ref.read(apiClientProvider).post('/api/v1/guardians/presence', body: {
      'status': 'ONLINE',
    });
    await _loadLocations();
    await _loadMessages();
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
      final names = {for (final c in _children) c.id: c.name};
      final unreadIds = {
        for (final m in _messages)
          if (_kabarRead.isUnread(m)) m.id,
      };
      Navigator.of(context)
          .push(
        MaterialPageRoute(
          builder: (_) => KabarInboxScreen(
            messages: List<ChildKabarMessage>.from(_messages),
            initialChildId: childId ?? _selectedChildId,
            childNames: names,
            unreadIds: unreadIds,
            onMarkAllRead: _markAllKabarRead,
          ),
        ),
      )
          .then((_) {
        if (mounted) setState(() {});
      });
    }));
  }

  void _openInviteRedeem() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const GuardianAccountScreen(
          allowRedeemInvite: true,
        ),
      ),
    ).then((_) {
      if (mounted) unawaited(_loadChildren());
    });
  }

  Future<void> _confirmLogout() async {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text(l10n.logout),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(
                backgroundColor: refresh
                    ? VisualRefreshColors.danger
                    : AppColors.coral,
              ),
              child: Text(l10n.logout),
            ),
          ],
        );
      },
    );
    if (ok != true || !mounted) return;
    await ref.read(authControllerProvider.notifier).logout();
  }

  Future<void> _loadChildren() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/api/v1/guardians/children');
      final list = (data['children'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(ChildSummary.fromJson)
          .toList();
      if (!mounted) return;
      setState(() {
        _children = list;
        _loadingChildren = false;
        if (list.isNotEmpty &&
            (_selectedChildId == null ||
                !list.any((c) => c.id == _selectedChildId))) {
          _selectedChildId = list.first.id;
        }
      });
      if (list.isNotEmpty) {
        await ref.read(childrenControllerProvider.notifier).bootstrap();
        await _loadGenders();
        _syncChildSubscriptions();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingChildren = false);
    }
  }

  Future<void> _loadGenders() async {
    for (final c in _children) {
      _genders[c.id] = await ChildGenderStore.instance.get(c.id);
    }
    if (mounted) setState(() {});
  }

  void _syncChildSubscriptions() {
    for (final c in _children) {
      _ws.subscribe('child:${c.id}');
    }
  }

  Future<void> _loadLocations() async {
    if (_children.isEmpty) return;
    final api = ref.read(apiClientProvider);
    for (final c in _children) {
      try {
        final data = await api.get('/api/v1/children/${c.id}/location');
        final loc = data['location'] as Map<String, dynamic>?;
        if (loc == null) continue;
        final lat = parseCoord(loc['lat']);
        final lng = parseCoord(loc['lng']);
        if (lat == null || lng == null) continue;
        final recorded = loc['recordedAt']?.toString() ??
            loc['timestamp']?.toString();
        if (!mounted) return;
        setState(() {
          _positions[c.id] = LatLng(lat, lng);
          _batteryLevels[c.id] = data['batteryLevel'] as int? ??
              (loc['batteryLevel'] as num?)?.toInt();
          _batteryCharging[c.id] = data['batteryCharging'] == true ||
              loc['batteryCharging'] == true;
          _staleByChild[c.id] = data['isStale'] == true;
          _updatedAt[c.id] =
              recorded != null ? DateTime.tryParse(recorded)?.toLocal() : null;
        });
      } catch (_) {}
    }
  }

  void _onWs(String event, Map<String, dynamic> payload) {
    if (event == 'guardian:alert_notify') {
      setState(() {
        _alertId = payload['alertId'] as String?;
        _alertChildId = payload['childId'] as String?;
      });
    }
    if (event == 'guardian:emergency_meeting_alert') {
      unawaited(_openEmergencyMeeting(payload));
    }
    if (event == 'child:location_update') {
      final childId = payload['childId']?.toString();
      final lat = parseCoord(payload['lat']);
      final lng = parseCoord(payload['lng']);
      if (childId == null || lat == null || lng == null) return;
      setState(() {
        _positions[childId] = LatLng(lat, lng);
        _staleByChild[childId] = false;
        _updatedAt[childId] = DateTime.now();
        if (payload['batteryLevel'] is num) {
          _batteryLevels[childId] = (payload['batteryLevel'] as num).toInt();
        }
        if (payload.containsKey('batteryCharging')) {
          _batteryCharging[childId] = payload['batteryCharging'] == true;
        }
      });
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
  }

  Future<void> _openEmergencyMeeting(Map<String, dynamic> payload) async {
    final name = payload['meetingPointName'] as String? ?? 'Titik kumpul';
    final lat = parseCoord(payload['lat']);
    final lng = parseCoord(payload['lng']);
    if (lat == null || lng == null || !mounted) return;
    final namesRaw = payload['childNames'];
    final names = namesRaw is List
        ? namesRaw.map((e) => '$e').toList()
        : (namesRaw is String && namesRaw.isNotEmpty
            ? namesRaw.split(',').map((e) => e.trim()).toList()
            : <String>[]);
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmergencyMeetingAlertScreen(
          placeName: name,
          lat: lat,
          lng: lng,
          note: payload['note'] as String?,
          childNames: names,
        ),
      ),
    );
  }

  Future<void> _ack() async {
    if (_alertId == null) return;
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/panic/$_alertId/guardian-ack');
  }

  Future<void> _shareLocation() async {
    if (_alertId == null) return;
    final pos = await Geolocator.getCurrentPosition();
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/guardians/share-location', body: {
      'alertId': _alertId,
      'lat': pos.latitude,
      'lng': pos.longitude,
    });
  }

  Future<void> _needBackup() async {
    if (_alertId == null) return;
    final l10n = AppLocalizations.of(context);
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/panic/$_alertId/need-backup', body: {
      'notes': l10n.needExtraHelpNote,
    });
  }

  void _openTool({required Widget screen}) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  @override
  void dispose() {
    _locationPoll?.cancel();
    _ws.removeHandler(_onWs);
    unawaited(_ws.disconnect());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final refresh = visualRefreshOf(context);
    final selected = _selected;
    final canManage = _canManageSelected;
    final period = dayPeriodFor();
    final unreadCount = _kabarRead.unreadOf(_messages).length;

    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : const Color(0xFFF0F2F5),
      body: SafeArea(
        child: RefreshIndicator(
          color: refresh ? VisualRefreshColors.accent : AppColors.teal,
          onRefresh: () async {
            await _loadChildren();
            await _loadLocations();
            await _loadMessages();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _GuardianHeader(
                greeting: period.greeting(l10n),
                greetingIcon: period.icon,
                name: auth.name ?? l10n.greetingDefaultName,
                accessPill: canManage
                    ? l10n.coParentAccessPill
                    : l10n.viewOnlyAccessPill,
                showAccessPill: selected != null,
                notificationCount: unreadCount,
                onNotifications: () => _openInbox(),
                onLogout: () => unawaited(_confirmLogout()),
              ),
              const SizedBox(height: 18),
              if (_loadingChildren)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 48),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_children.isEmpty) ...[
                Text(
                  l10n.guardianNoLinkedChildren,
                  style: TextStyle(
                    color: refresh
                        ? VisualRefreshColors.textSecondary
                        : AppColors.inkSoft,
                  ),
                ),
                const SizedBox(height: 14),
                OutlinedButton.icon(
                  onPressed: _openInviteRedeem,
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: Text(l10n.enterGuardianInviteCode),
                  style: OutlinedButton.styleFrom(
                    foregroundColor:
                        refresh ? VisualRefreshColors.anchor : AppColors.teal,
                    side: BorderSide(
                      color: refresh
                          ? VisualRefreshColors.border
                          : AppColors.teal,
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ]
              else ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        l10n.childLocationSectionTitle,
                        style: refresh
                            ? GoogleFonts.fraunces(
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: VisualRefreshColors.textPrimary,
                              )
                            : Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    if (selected != null)
                      TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => LiveMapScreen(child: selected),
                          ),
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: refresh
                              ? VisualRefreshColors.accent
                              : AppColors.teal,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          l10n.viewMapAction,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFamily: refresh
                                ? GoogleFonts.plusJakartaSans().fontFamily
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
                if (_children.length > 1) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 40,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _children.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final c = _children[i];
                        final selectedChip = c.id == selected?.id;
                        final online = !(_staleByChild[c.id] ?? true) &&
                            _positions.containsKey(c.id);
                        return _ChildChip(
                          name: c.name,
                          selected: selectedChip,
                          online: online,
                          onTap: () => setState(() => _selectedChildId = c.id),
                        );
                      },
                    ),
                  ),
                ],
                if (selected != null) ...[
                  const SizedBox(height: 12),
                  ChildHomeMapCard(
                    child: selected,
                    gender: _genders[selected.id] ??
                        ChildGenderStore.guessFromName(selected.name),
                    position: _positions[selected.id],
                    batteryLevel: _batteryLevels[selected.id],
                    batteryCharging: _batteryCharging[selected.id] ?? false,
                    stale: _staleByChild[selected.id] ?? true,
                    updatedAt: _updatedAt[selected.id],
                    onOpenMap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => LiveMapScreen(child: selected),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AccessInfoBanner(
                    canManage: canManage,
                    childName: selected.name,
                  ),
                  const SizedBox(height: 22),
                  _SectionLabel(
                    canManage
                        ? l10n.sectionManageLabel
                        : l10n.sectionViewLabel,
                  ),
                  const SizedBox(height: 10),
                  _ToolRow(
                    icon: Icons.map_outlined,
                    title: l10n.zonesTitle,
                    canManage: canManage,
                    onTap: () => _openTool(
                      screen: PlacesEntryScreen(
                        lockedChild: selected,
                        readOnly: !canManage,
                      ),
                    ),
                  ),
                  _ToolRow(
                    icon: Icons.emergency_share_outlined,
                    title: l10n.empTitle,
                    canManage: canManage,
                    onTap: () => _openTool(
                      screen: EmergencyMeetingScreen(
                        lockedChild: selected,
                        readOnly: !canManage,
                      ),
                    ),
                  ),
                  _ToolRow(
                    icon: Icons.alarm_outlined,
                    title: l10n.remindersTitle,
                    canManage: canManage,
                    onTap: () => _openTool(
                      screen: RemindersScreen(
                        initialChildId: selected.id,
                        lockChild: true,
                        readOnly: !canManage,
                      ),
                    ),
                  ),
                  _ToolRow(
                    icon: Icons.home_outlined,
                    title: l10n.homeByTitle,
                    canManage: canManage,
                    onTap: () => _openTool(
                      screen: HomeByScreen(
                        lockedChild: selected,
                        readOnly: !canManage,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  _SectionLabel(l10n.sectionAccountLabel),
                  const SizedBox(height: 10),
                  _ToolRow(
                    icon: Icons.people_outline,
                    title: l10n.guardiansTitle,
                    // Roster invite/promote/revoke is primary-only; co-parent is view.
                    canManage: false,
                    onTap: () => _openTool(
                      screen: const GuardiansEntryScreen(readOnly: true),
                    ),
                  ),
                ],
              ],
              const SizedBox(height: 24),
              Text(
                l10n.activeAlerts,
                style: refresh
                    ? GoogleFonts.fraunces(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: VisualRefreshColors.textPrimary,
                      )
                    : Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 10),
              if (_alertId == null)
                _AlertsEmptyState(message: l10n.noActiveAlerts)
              else
                Card(
                  color: refresh
                      ? VisualRefreshColors.dangerTint
                      : const Color(0xFFFEE4E2),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(l10n.alertLabelWithId(_alertId!)),
                        if (_alertChildId != null)
                          Text(l10n.childIdLabel(_alertChildId!)),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: _ack,
                          child: Text(l10n.ackAlert),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _shareLocation,
                          child: Text(l10n.shareLocation),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton(
                          onPressed: _needBackup,
                          child: Text(l10n.needBackup),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GuardianHeader extends StatelessWidget {
  const _GuardianHeader({
    required this.greeting,
    required this.greetingIcon,
    required this.name,
    required this.accessPill,
    required this.showAccessPill,
    required this.notificationCount,
    required this.onNotifications,
    required this.onLogout,
  });

  final String greeting;
  final IconData greetingIcon;
  final String name;
  final String accessPill;
  final bool showAccessPill;
  final int notificationCount;
  final VoidCallback onNotifications;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: refresh
                ? VisualRefreshColors.weatherTint
                : VisualRefreshColors.accentTint,
            shape: BoxShape.circle,
          ),
          child: Icon(
            greetingIcon,
            color: refresh
                ? VisualRefreshColors.anchor
                : VisualRefreshColors.accent,
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
                  fontFamily:
                      refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
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
                      ),
              ),
              if (showAccessPill) ...[
                const SizedBox(height: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: VisualRefreshColors.tagMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    accessPill,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      color: VisualRefreshColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Material(
                  color: refresh ? VisualRefreshColors.surface : Colors.white,
                  shape: CircleBorder(
                    side: BorderSide(
                      color: refresh
                          ? VisualRefreshColors.border
                          : const Color(0xFFE2E6EA),
                      width: 0.5,
                    ),
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onNotifications,
                    child: SizedBox(
                      width: 40,
                      height: 40,
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
              color: refresh ? VisualRefreshColors.surface : Colors.white,
              shape: CircleBorder(
                side: BorderSide(
                  color: refresh
                      ? VisualRefreshColors.border
                      : const Color(0xFFE2E6EA),
                  width: 0.5,
                ),
              ),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onLogout,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    refresh ? Icons.logout_outlined : Icons.logout,
                    size: 20,
                    color: refresh
                        ? VisualRefreshColors.textPrimary
                        : null,
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _AccessInfoBanner extends StatelessWidget {
  const _AccessInfoBanner({
    required this.canManage,
    required this.childName,
  });

  final bool canManage;
  final String childName;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final message = canManage
        ? l10n.guardianCoParentInfoBanner(childName)
        : l10n.guardianViewOnlyInfoBanner(childName);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: VisualRefreshColors.accentTint,
        borderRadius: BorderRadius.circular(AppRadius.vrCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 20,
            color: VisualRefreshColors.accent,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                height: 1.35,
                fontWeight: FontWeight.w600,
                color: VisualRefreshColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
        color: VisualRefreshColors.textTertiary,
      ),
    );
  }
}

class _ToolRow extends StatelessWidget {
  const _ToolRow({
    required this.icon,
    required this.title,
    required this.canManage,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool canManage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: refresh ? VisualRefreshColors.surface : Colors.white,
        borderRadius: BorderRadius.circular(refresh ? AppRadius.vrCard : 14),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(refresh ? AppRadius.vrCard : 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              borderRadius:
                  BorderRadius.circular(refresh ? AppRadius.vrCard : 14),
              border: refresh
                  ? Border.all(color: VisualRefreshColors.border, width: 0.5)
                  : null,
            ),
            child: Row(
              children: [
                if (canManage)
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: VisualRefreshColors.accentTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: VisualRefreshColors.accent),
                  )
                else
                  Icon(icon, color: VisualRefreshColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: refresh ? VisualRefreshColors.textPrimary : null,
                      fontFamily: refresh
                          ? GoogleFonts.plusJakartaSans().fontFamily
                          : null,
                    ),
                  ),
                ),
                if (canManage)
                  Icon(
                    Icons.chevron_right,
                    color: VisualRefreshColors.textTertiary,
                  )
                else
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: VisualRefreshColors.tagMuted,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      l10n.viewPillLabel,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: VisualRefreshColors.textSecondary,
                      ),
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

class _ChildChip extends StatelessWidget {
  const _ChildChip({
    required this.name,
    required this.selected,
    required this.online,
    required this.onTap,
  });

  final String name;
  final bool selected;
  final bool online;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? VisualRefreshColors.anchor
          : VisualRefreshColors.surface,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? null
                : Border.all(color: VisualRefreshColors.border, width: 0.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: online
                      ? (selected
                          ? VisualRefreshColors.background
                          : VisualRefreshColors.accent)
                      : VisualRefreshColors.textTertiary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                name,
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: selected
                      ? VisualRefreshColors.background
                      : VisualRefreshColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AlertsEmptyState extends StatelessWidget {
  const _AlertsEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: VisualRefreshColors.tagMuted,
        borderRadius: BorderRadius.circular(AppRadius.vrCard),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: const BoxDecoration(
              color: VisualRefreshColors.accentTint,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 16,
              color: VisualRefreshColors.accent,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w600,
                color: VisualRefreshColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
