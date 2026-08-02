import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  Map<String, dynamic>? _empActivation;
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
      unawaited(_loadEmpActivation());
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
    await _loadEmpActivation();
    await _loadMessages();
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

  void _openTrustedGuardians() {
    _openTool(screen: const GuardiansEntryScreen(readOnly: true));
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
    if (event == 'guardian:emergency_meeting_alert') {
      unawaited(_loadEmpActivation());
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
    if (mounted) await _loadEmpActivation();
  }

  void _openTool({required Widget screen}) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  Future<void> _openEmpTool() async {
    final selected = _selected;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EmergencyMeetingScreen(
          lockedChild: selected,
          readOnly: !_canManageSelected,
        ),
      ),
    );
    if (mounted) await _loadEmpActivation();
  }

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'WA';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return ('${parts[0][0]}${parts[1][0]}').toUpperCase();
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
    final empActive = _empActivation != null;

    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : const Color(0xFFF0F2F5),
      body: SafeArea(
        child: RefreshIndicator(
          color: refresh ? VisualRefreshColors.accent : AppColors.teal,
          onRefresh: () async {
            await _loadChildren();
            await _loadLocations();
            await _loadEmpActivation();
            await _loadMessages();
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
            children: [
              _GuardianHeader(
                greeting: period.greeting(l10n),
                greetingIcon: period.icon,
                name: auth.name ?? l10n.greetingDefaultName,
                initials: _initials(auth.name),
                accessPill: canManage
                    ? l10n.coParentAccessPill
                    : l10n.viewOnlyAccessPill,
                showAccessPill: selected != null,
                notificationCount: unreadCount,
                onNotifications: () => _openInbox(),
                onAvatar: _openTrustedGuardians,
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
                if (empActive) ...[
                  _EmpActiveBanner(onOpen: () => unawaited(_openEmpTool())),
                  const SizedBox(height: 14),
                ],
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
                  _ToolsGrid(
                    canManage: canManage,
                    onZones: () => _openTool(
                      screen: PlacesEntryScreen(
                        lockedChild: selected,
                        readOnly: !canManage,
                      ),
                    ),
                    onMeeting: () => unawaited(_openEmpTool()),
                    onReminders: () => _openTool(
                      screen: RemindersScreen(
                        initialChildId: selected.id,
                        lockChild: true,
                        readOnly: !canManage,
                      ),
                    ),
                    onHomeTime: () => _openTool(
                      screen: HomeByScreen(
                        lockedChild: selected,
                        readOnly: !canManage,
                      ),
                    ),
                  ),
                ],
              ],
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
    required this.initials,
    required this.accessPill,
    required this.showAccessPill,
    required this.notificationCount,
    required this.onNotifications,
    required this.onAvatar,
  });

  final String greeting;
  final IconData greetingIcon;
  final String name;
  final String initials;
  final String accessPill;
  final bool showAccessPill;
  final int notificationCount;
  final VoidCallback onNotifications;
  final VoidCallback onAvatar;

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
              color: refresh ? VisualRefreshColors.anchor : AppColors.tealDeep,
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onAvatar,
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
        ),
      ],
    );
  }
}

class _EmpActiveBanner extends StatelessWidget {
  const _EmpActiveBanner({required this.onOpen});

  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
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
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: refresh
                  ? VisualRefreshColors.dangerTintBorder
                  : AppColors.danger.withValues(alpha: 0.25),
              width: 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.warning_amber_rounded,
                size: 22,
                color: refresh
                    ? VisualRefreshColors.danger
                    : AppColors.danger,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.guardianEmpActiveBannerTitle,
                      style: refresh
                          ? GoogleFonts.fraunces(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: VisualRefreshColors.danger,
                            )
                          : const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: AppColors.danger,
                            ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.guardianEmpActiveBannerBody,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: refresh
                            ? VisualRefreshColors.textPrimary
                            : AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
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

class _ToolsGrid extends StatelessWidget {
  const _ToolsGrid({
    required this.canManage,
    required this.onZones,
    required this.onMeeting,
    required this.onReminders,
    required this.onHomeTime,
  });

  final bool canManage;
  final VoidCallback onZones;
  final VoidCallback onMeeting;
  final VoidCallback onReminders;
  final VoidCallback onHomeTime;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final tiles = [
      (
        icon: Icons.map_outlined,
        label: l10n.guardianToolZonesLabel,
        sub: l10n.guardianToolZonesSub,
        onTap: onZones,
      ),
      (
        icon: Icons.emergency_share_outlined,
        label: l10n.guardianToolMeetingLabel,
        sub: l10n.guardianToolMeetingSub,
        onTap: onMeeting,
      ),
      (
        icon: Icons.alarm_outlined,
        label: l10n.guardianToolRemindersLabel,
        sub: l10n.guardianToolRemindersSub,
        onTap: onReminders,
      ),
      (
        icon: Icons.home_outlined,
        label: l10n.guardianToolHomeTimeLabel,
        sub: l10n.guardianToolHomeTimeSub,
        onTap: onHomeTime,
      ),
    ];

    Widget row(int a, int b) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: _ToolTile(
              icon: tiles[a].icon,
              label: tiles[a].label,
              subtitle: tiles[a].sub,
              canManage: canManage,
              onTap: tiles[a].onTap,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _ToolTile(
              icon: tiles[b].icon,
              label: tiles[b].label,
              subtitle: tiles[b].sub,
              canManage: canManage,
              onTap: tiles[b].onTap,
            ),
          ),
        ],
      );
    }

    return Column(
      children: [
        row(0, 1),
        const SizedBox(height: 12),
        row(2, 3),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.canManage,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String subtitle;
  final bool canManage;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(14);
    final tileBg = canManage
        ? VisualRefreshColors.accentTint
        : VisualRefreshColors.surface;
    final iconCircleBg = canManage
        ? VisualRefreshColors.surface
        : VisualRefreshColors.tagMuted;
    final iconColor = canManage
        ? VisualRefreshColors.accent
        : VisualRefreshColors.textSecondary;

    return Material(
      color: tileBg,
      borderRadius: radius,
      child: InkWell(
        onTap: onTap,
        borderRadius: radius,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: canManage
                ? null
                : Border.all(
                    color: VisualRefreshColors.border,
                    width: 1,
                  ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
            child: SizedBox(
              width: double.infinity,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: iconCircleBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      icon,
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      height: 1.15,
                      color: VisualRefreshColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w500,
                      fontSize: 10.5,
                      height: 1.15,
                      color: VisualRefreshColors.textSecondary,
                    ),
                  ),
                ],
              ),
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
