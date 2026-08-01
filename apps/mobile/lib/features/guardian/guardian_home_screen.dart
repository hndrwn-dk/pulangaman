import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/network/ws_client.dart';
import '../../core/parse_coord.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../parent/children_controller.dart';
import '../parent/emergency_meeting_alert_screen.dart';
import '../parent/emergency_meeting_screen.dart';
import '../parent/guardians_screen.dart';
import '../parent/home_by_screen.dart';
import '../parent/reminders_screen.dart';
import '../parent/vr_sheet_chrome.dart';
import '../parent/zones_screen.dart';

class GuardianHomeScreen extends ConsumerStatefulWidget {
  const GuardianHomeScreen({super.key});

  @override
  ConsumerState<GuardianHomeScreen> createState() => _GuardianHomeScreenState();
}

class _GuardianHomeScreenState extends ConsumerState<GuardianHomeScreen> {
  final _ws = WsClient();
  List<Map<String, dynamic>> _invites = [];
  List<ChildSummary> _coParentChildren = [];
  String? _alertId;
  String? _childId;

  @override
  void initState() {
    super.initState();
    Future.microtask(_bootstrap);
  }

  Future<void> _bootstrap() async {
    await _loadInvites();
    await _loadCoParentChildren();
    final auth = ref.read(authControllerProvider);
    final token = auth.token;
    final userId = auth.userId;
    if (token != null && userId != null) {
      await _ws.connect(token);
      _ws.addHandler(_onWs);
      _ws.subscribe('guardian:$userId');
    }
    await ref.read(apiClientProvider).post('/api/v1/guardians/presence', body: {
      'status': 'ONLINE',
    });
  }

  Future<void> _loadCoParentChildren() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/api/v1/guardians/children');
      final list = (data['children'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .where((c) => c['access']?.toString() == 'co_parent')
          .map(ChildSummary.fromJson)
          .toList();
      if (!mounted) return;
      setState(() => _coParentChildren = list);
      if (list.isNotEmpty) {
        // Warm childrenController so Zones / EMP / Reminders / Home-by work.
        await ref.read(childrenControllerProvider.notifier).bootstrap();
      }
    } catch (_) {}
  }

  void _onWs(String event, Map<String, dynamic> payload) {
    if (event == 'guardian:alert_notify') {
      setState(() {
        _alertId = payload['alertId'] as String?;
        _childId = payload['childId'] as String?;
      });
    }
    if (event == 'guardian:emergency_meeting_alert') {
      unawaited(_openEmergencyMeeting(payload));
    }
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

  Future<void> _loadInvites() async {
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/api/v1/guardians/invites');
      setState(() {
        _invites = (data['invites'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
      });
    } catch (_) {}
  }

  Future<void> _accept(String childId) async {
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/guardians/accept', body: {'childId': childId});
    await _loadInvites();
    await _loadCoParentChildren();
  }

  Future<void> _redeemInviteCode() async {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);

    // Sheet/dialog owns its TextEditingController so it is not disposed while
    // the modal route is still animating out (that caused a red-screen assert).
    final String? code = refresh
        ? await showVrModalBottomSheet<String>(
            context: context,
            builder: (ctx) => const _EnterGuardianInviteCodeSheet(),
          )
        : await showDialog<String>(
            context: context,
            builder: (ctx) => const _EnterGuardianInviteCodeDialog(),
          );

    if (code == null || !mounted) return;
    final trimmed = code.trim();
    if (trimmed.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.guardianInviteInvalidCode)),
      );
      return;
    }

    try {
      final data = await ref.read(apiClientProvider).post(
        '/api/v1/guardian-invites/redeem',
        body: {'code': trimmed},
      );
      await _loadInvites();
      await _loadCoParentChildren();
      if (!mounted) return;
      final childName = data['childName']?.toString() ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            childName.isEmpty
                ? l10n.acceptInvite
                : l10n.guardianInviteRedeemed(childName),
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.guardianInviteInvalidCode)),
      );
    }
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

  @override
  void dispose() {
    _ws.removeHandler(_onWs);
    unawaited(_ws.disconnect());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final auth = ref.watch(authControllerProvider);
    final refresh = visualRefreshOf(context);

    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : null,
      appBar: AppBar(
        title: Text('${l10n.brand} · ${auth.name ?? ''}'),
        actions: [
          IconButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.guardianGuidance,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: refresh
                      ? VisualRefreshColors.textSecondary
                      : AppColors.ink.withValues(alpha: 0.85),
                  fontFamily:
                      refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
                ),
          ),
          if (_coParentChildren.isNotEmpty) ...[
            const SizedBox(height: 24),
            Text(
              l10n.coParentManageTitle,
              style: refresh
                  ? GoogleFonts.fraunces(
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      color: VisualRefreshColors.textPrimary,
                    )
                  : Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.coParentManageSubtitle,
              style: TextStyle(
                color: refresh
                    ? VisualRefreshColors.textSecondary
                    : AppColors.inkSoft,
                fontFamily:
                    refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
              ),
            ),
            const SizedBox(height: 12),
            _CoParentToolTile(
              refresh: refresh,
              icon: Icons.map_outlined,
              title: l10n.zonesTitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const PlacesEntryScreen(),
                ),
              ),
            ),
            _CoParentToolTile(
              refresh: refresh,
              icon: Icons.emergency_share_outlined,
              title: l10n.empTitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const EmergencyMeetingScreen(),
                ),
              ),
            ),
            _CoParentToolTile(
              refresh: refresh,
              icon: Icons.alarm_outlined,
              title: l10n.remindersTitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RemindersScreen()),
              ),
            ),
            _CoParentToolTile(
              refresh: refresh,
              icon: Icons.home_outlined,
              title: l10n.homeByTitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const HomeByScreen()),
              ),
            ),
            _CoParentToolTile(
              refresh: refresh,
              icon: Icons.people_outline,
              title: l10n.guardiansTitle,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const GuardiansEntryScreen(),
                ),
              ),
            ),
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
          const SizedBox(height: 8),
          if (_alertId == null)
            Text(
              l10n.noActiveAlerts,
              style: TextStyle(
                color: refresh
                    ? VisualRefreshColors.textSecondary
                    : null,
              ),
            )
          else ...[
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
                    if (_childId != null) Text(l10n.childIdLabel(_childId!)),
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
          const SizedBox(height: 24),
          Text(
            l10n.invitesSectionTitle,
            style: refresh
                ? GoogleFonts.fraunces(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: VisualRefreshColors.textPrimary,
                  )
                : Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          if (_invites.isEmpty)
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.noInvites,
                  style: TextStyle(
                    color: refresh
                        ? VisualRefreshColors.textSecondary
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _redeemInviteCode,
                  icon: const Icon(Icons.vpn_key_outlined),
                  label: Text(l10n.enterGuardianInviteCode),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: refresh
                        ? VisualRefreshColors.anchor
                        : AppColors.teal,
                    side: BorderSide(
                      color: refresh
                          ? VisualRefreshColors.border
                          : AppColors.teal,
                    ),
                  ),
                ),
              ],
            )
          else ...[
            ..._invites.map(
              (invite) {
                final access = invite['accessLevel']?.toString() ??
                    invite['access_level']?.toString() ??
                    'view';
                final accessLabel = access == 'co_parent'
                    ? l10n.guardianAccessCoParent
                    : l10n.guardianAccessView;
                return ListTile(
                  title: Text('${invite['child_name']}'),
                  subtitle: Text(
                    l10n.fromParentWithAccess(
                      '${invite['parent_name']}',
                      accessLabel,
                    ),
                  ),
                  trailing: FilledButton(
                    onPressed: () => _accept(invite['child_id'] as String),
                    style: FilledButton.styleFrom(
                      backgroundColor: refresh
                          ? VisualRefreshColors.anchor
                          : AppColors.teal,
                    ),
                    child: Text(l10n.acceptInvite),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _redeemInviteCode,
              icon: const Icon(Icons.vpn_key_outlined, size: 18),
              label: Text(l10n.enterGuardianInviteCode),
            ),
          ],
        ],
      ),
    );
  }
}

class _CoParentToolTile extends StatelessWidget {
  const _CoParentToolTile({
    required this.icon,
    required this.title,
    required this.onTap,
    required this.refresh,
  });

  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
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
              boxShadow: refresh
                  ? null
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: refresh ? VisualRefreshColors.accent : AppColors.teal,
                ),
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
                Icon(
                  Icons.chevron_right,
                  color: refresh
                      ? VisualRefreshColors.textTertiary
                      : AppColors.inkSoft,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Owns the invite-code [TextEditingController] for the VR bottom-sheet lifetime.
class _EnterGuardianInviteCodeSheet extends StatefulWidget {
  const _EnterGuardianInviteCodeSheet();

  @override
  State<_EnterGuardianInviteCodeSheet> createState() =>
      _EnterGuardianInviteCodeSheetState();
}

class _EnterGuardianInviteCodeSheetState
    extends State<_EnterGuardianInviteCodeSheet> {
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _codeCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: VrSheetShell(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              VrSheetTitle(l10n.enterGuardianInviteCode),
              const SizedBox(height: 10),
              VrSheetBody(l10n.enterGuardianInviteCodeHint),
              const SizedBox(height: 18),
              TextField(
                controller: _codeCtrl,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                onSubmitted: (_) => _submit(),
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                  fontSize: 20,
                  color: VisualRefreshColors.textPrimary,
                ),
                decoration: InputDecoration(
                  hintText: 'ABC123',
                  filled: true,
                  fillColor: VisualRefreshColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: VisualRefreshColors.border,
                      width: 0.5,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: VisualRefreshColors.border,
                      width: 0.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: VisualRefreshColors.accent,
                      width: 1.2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                height: 52,
                child: FilledButton(
                  onPressed: _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: VisualRefreshColors.anchor,
                    foregroundColor: VisualRefreshColors.background,
                    elevation: 0,
                    shape: const StadiumBorder(),
                  ),
                  child: Text(
                    l10n.acceptInvite,
                    style: GoogleFonts.plusJakartaSans(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
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

/// Owns the invite-code [TextEditingController] for the legacy dialog lifetime.
class _EnterGuardianInviteCodeDialog extends StatefulWidget {
  const _EnterGuardianInviteCodeDialog();

  @override
  State<_EnterGuardianInviteCodeDialog> createState() =>
      _EnterGuardianInviteCodeDialogState();
}

class _EnterGuardianInviteCodeDialogState
    extends State<_EnterGuardianInviteCodeDialog> {
  final _codeCtrl = TextEditingController();

  @override
  void dispose() {
    _codeCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.pop(context, _codeCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.enterGuardianInviteCode),
      content: TextField(
        controller: _codeCtrl,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: l10n.inviteCodeLabel,
          hintText: l10n.enterGuardianInviteCodeHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
          child: Text(l10n.acceptInvite),
        ),
      ],
    );
  }
}
