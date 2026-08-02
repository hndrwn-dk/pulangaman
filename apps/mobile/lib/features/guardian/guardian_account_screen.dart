import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import '../parent/vr_sheet_chrome.dart';

/// Minimal guardian Account: optional invite redeem (first join only) + sign out.
class GuardianAccountScreen extends ConsumerStatefulWidget {
  const GuardianAccountScreen({
    super.key,
    this.allowRedeemInvite = true,
  });

  /// When false (already linked to children), hide invite redeem UI so
  /// co-parents / wali cannot pile on more children via codes.
  final bool allowRedeemInvite;

  @override
  ConsumerState<GuardianAccountScreen> createState() =>
      _GuardianAccountScreenState();
}

class _GuardianAccountScreenState extends ConsumerState<GuardianAccountScreen> {
  List<Map<String, dynamic>> _invites = [];
  bool _loadingInvites = true;

  @override
  void initState() {
    super.initState();
    if (widget.allowRedeemInvite) {
      Future.microtask(_loadInvites);
    } else {
      _loadingInvites = false;
    }
  }

  Future<void> _loadInvites() async {
    if (!widget.allowRedeemInvite) return;
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/api/v1/guardians/invites');
      if (!mounted) return;
      setState(() {
        _invites = (data['invites'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        _loadingInvites = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingInvites = false);
    }
  }

  Future<void> _accept(String childId) async {
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/guardians/accept', body: {'childId': childId});
    await _loadInvites();
  }

  Future<void> _redeemInviteCode() async {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);

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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);

    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(l10n.guardianAccountTitle),
        backgroundColor: refresh ? VisualRefreshColors.background : null,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: [
          if (widget.allowRedeemInvite) ...[
            Text(
              l10n.invitesSectionTitle,
              style: refresh
                  ? GoogleFonts.fraunces(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: VisualRefreshColors.textPrimary,
                    )
                  : Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              l10n.guardianAccountInviteSubtitle,
              style: TextStyle(
                color: refresh
                    ? VisualRefreshColors.textSecondary
                    : AppColors.inkSoft,
                fontFamily:
                    refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
              ),
            ),
            const SizedBox(height: 14),
            if (_loadingInvites)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_invites.isEmpty)
              Text(
                l10n.noInvites,
                style: TextStyle(
                  color: refresh ? VisualRefreshColors.textSecondary : null,
                ),
              )
            else
              ..._invites.map((invite) {
                final access = invite['accessLevel']?.toString() ??
                    invite['access_level']?.toString() ??
                    'view';
                final accessLabel = access == 'co_parent'
                    ? l10n.guardianAccessCoParent
                    : l10n.guardianAccessView;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
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
              }),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _redeemInviteCode,
              icon: const Icon(Icons.vpn_key_outlined),
              label: Text(l10n.enterGuardianInviteCode),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    refresh ? VisualRefreshColors.anchor : AppColors.teal,
                side: BorderSide(
                  color: refresh ? VisualRefreshColors.border : AppColors.teal,
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
            const SizedBox(height: 28),
          ],
          TextButton.icon(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
            icon: Icon(
              Icons.logout,
              color: refresh
                  ? VisualRefreshColors.textTertiary
                  : AppColors.inkSoft,
            ),
            label: Text(
              l10n.logout,
              style: TextStyle(
                color: refresh
                    ? VisualRefreshColors.textTertiary
                    : AppColors.inkSoft,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
