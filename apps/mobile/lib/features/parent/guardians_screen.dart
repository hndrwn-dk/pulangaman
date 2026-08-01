import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'child_avatar.dart';
import 'children_controller.dart';
import 'vr_sheet_chrome.dart';

const _playStoreUrl =
    'https://play.google.com/store/apps/details?id=com.tursinalabs.pulangaman';

class _GuardianRef {
  _GuardianRef({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    required this.childNames,
    this.isCoParent = false,
  });

  final String id;
  final String name;
  final String phone;
  final String status;
  final List<String> childNames;
  bool isCoParent;
}

String _guardianAccessLevel(Map<String, dynamic> g) {
  final raw = g['accessLevel']?.toString() ?? g['access_level']?.toString();
  return raw == 'co_parent' ? 'co_parent' : 'view';
}

bool _isCoParentGuardian(Map<String, dynamic> g) =>
    _guardianAccessLevel(g) == 'co_parent';

Widget _accessLevelBadge(BuildContext context, {required bool coParent, required bool refresh}) {
  final l10n = AppLocalizations.of(context);
  final label = coParent ? l10n.coParentBadge : l10n.waliBadge;
  final bg = coParent
      ? (refresh ? VisualRefreshColors.routeTint : const Color(0xFFE0E7FF))
      : (refresh ? VisualRefreshColors.tagMuted : const Color(0xFFE8ECF0));
  final fg = coParent
      ? (refresh ? VisualRefreshColors.routeText : const Color(0xFF3730A3))
      : (refresh ? VisualRefreshColors.textSecondary : AppColors.inkSoft);
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: fg,
        fontFamily: refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
      ),
    ),
  );
}

Widget _accessLevelPicker({
  required AppLocalizations l10n,
  required bool coParent,
  required ValueChanged<bool> onChanged,
  required bool refresh,
}) {
  final children = <Widget>[
    Text(
      l10n.guardianAccessSectionTitle,
      style: refresh
          ? GoogleFonts.plusJakartaSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: VisualRefreshColors.textSecondary,
            )
          : const TextStyle(fontWeight: FontWeight.w700),
    ),
    const SizedBox(height: 8),
    _AccessOptionTile(
      selected: !coParent,
      title: l10n.guardianAccessView,
      subtitle: l10n.guardianAccessViewHint,
      refresh: refresh,
      onTap: () => onChanged(false),
    ),
    const SizedBox(height: 8),
    _AccessOptionTile(
      selected: coParent,
      title: l10n.guardianAccessCoParent,
      subtitle: l10n.guardianAccessCoParentHint,
      refresh: refresh,
      onTap: () => onChanged(true),
    ),
  ];
  return Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: children,
  );
}

class _AccessOptionTile extends StatelessWidget {
  const _AccessOptionTile({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.onTap,
    required this.refresh,
  });

  final bool selected;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? (refresh ? VisualRefreshColors.accentTint : const Color(0xFFD8F5E8))
          : (refresh ? VisualRefreshColors.surface : Colors.white),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? (refresh ? VisualRefreshColors.accent : AppColors.teal)
                  : (refresh ? VisualRefreshColors.border : const Color(0xFFE5E7EB)),
              width: selected ? 1.4 : 0.5,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_off,
                size: 20,
                color: selected
                    ? (refresh ? VisualRefreshColors.accent : AppColors.teal)
                    : (refresh
                        ? VisualRefreshColors.textTertiary
                        : AppColors.inkSoft),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: refresh ? VisualRefreshColors.textPrimary : null,
                        fontFamily: refresh
                            ? GoogleFonts.plusJakartaSans().fontFamily
                            : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _hubCardDecoration(bool refresh) {
  if (refresh) {
    return BoxDecoration(
      color: VisualRefreshColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.vrCard),
      border: Border.all(
        color: VisualRefreshColors.border,
        width: 0.5,
      ),
    );
  }
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(18),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.05),
        blurRadius: 14,
        offset: const Offset(0, 5),
      ),
    ],
  );
}

InputDecoration _vrFieldDecoration({Widget? prefixIcon}) {
  return InputDecoration(
    filled: true,
    fillColor: VisualRefreshColors.surface,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    prefixIcon: prefixIcon,
    prefixIconConstraints:
        prefixIcon == null ? null : const BoxConstraints(minWidth: 0, minHeight: 0),
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
  );
}

Widget _vrCountryPrefixChip(String code) {
  return Padding(
    padding: const EdgeInsets.only(left: 10, right: 6),
    child: UnconstrainedBox(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: VisualRefreshColors.tagMuted,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          code,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: VisualRefreshColors.textPrimary,
          ),
        ),
      ),
    ),
  );
}

String _composePhone(String raw, {required bool vrPrefixed}) {
  final trimmed = raw.trim();
  if (!vrPrefixed) return trimmed;
  final digits = trimmed.replaceAll(RegExp(r'[^\d]'), '');
  if (trimmed.startsWith('+')) return trimmed;
  if (digits.startsWith('62')) return '+$digits';
  if (digits.startsWith('0')) return '+62${digits.substring(1)}';
  return '+62$digits';
}

/// Hub Wali Terpercaya (dari tab Lainnya).
class GuardiansEntryScreen extends ConsumerStatefulWidget {
  const GuardiansEntryScreen({super.key});

  @override
  ConsumerState<GuardiansEntryScreen> createState() =>
      _GuardiansEntryScreenState();
}

class _GuardiansEntryScreenState extends ConsumerState<GuardiansEntryScreen> {
  final Map<String, List<Map<String, dynamic>>> _byChild = {};
  final Map<String, ChildGender> _genders = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(childrenControllerProvider.notifier).bootstrap();
      await _loadGenders();
      await _loadAll();
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

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final children = ref.read(childrenControllerProvider).items;
    final api = ref.read(apiClientProvider);
    final next = <String, List<Map<String, dynamic>>>{};
    for (final c in children) {
      try {
        final data = await api.get(
          '/api/v1/guardians',
          query: {'childId': c.id},
        );
        next[c.id] = (data['guardians'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
      } catch (_) {
        next[c.id] = [];
      }
    }
    if (!mounted) return;
    setState(() {
      _byChild
        ..clear()
        ..addAll(next);
      _loading = false;
    });
  }

  List<_GuardianRef> _activeGuardians(AppLocalizations l10n) {
    final map = <String, _GuardianRef>{};
    final children = ref.read(childrenControllerProvider).items;
    final nameById = {for (final c in children) c.id: c.name};
    for (final entry in _byChild.entries) {
      final childName = nameById[entry.key] ?? l10n.childFallbackName;
      for (final g in entry.value) {
        final status = g['status']?.toString() ?? '';
        if (status == 'revoked') continue;
        final id = g['guardian_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final existing = map[id];
        if (existing == null) {
          map[id] = _GuardianRef(
            id: id,
            name: g['name']?.toString() ?? l10n.guardianFallbackName,
            phone: g['phone']?.toString() ?? '',
            status: status,
            childNames: [childName],
            isCoParent: _isCoParentGuardian(g),
          );
        } else if (!existing.childNames.contains(childName)) {
          existing.childNames.add(childName);
          if (_isCoParentGuardian(g)) existing.isCoParent = true;
        } else if (_isCoParentGuardian(g)) {
          existing.isCoParent = true;
        }
      }
    }
    return map.values.toList();
  }

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'PA';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return ('${parts[0][0]}${parts[1][0]}').toUpperCase();
  }

  Future<void> _openChild(ChildSummary child) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GuardiansScreen(child: child)),
    );
    await _loadAll();
  }

  Future<void> _inviteFlow(String channel) async {
    final l10n = AppLocalizations.of(context);
    final children = ref.read(childrenControllerProvider).items;
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.addChildBeforeInvite)),
      );
      return;
    }

    final refresh = visualRefreshOf(context);
    ChildSummary selected = children.first;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: refresh ? '' : '+62');
    final emailCtrl = TextEditingController();
    var inviteAsCoParent = false;

    try {
      final bool? ok;
      if (refresh) {
        ok = await showVrModalBottomSheet<bool>(
          context: context,
          builder: (ctx) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: VrSheetShell(
                child: StatefulBuilder(
                  builder: (ctx, setLocal) {
                    final sheetL10n = AppLocalizations.of(ctx);
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          VrSheetTitle(
                            channel == 'whatsapp'
                                ? sheetL10n.inviteViaWhatsApp
                                : channel == 'email'
                                    ? sheetL10n.inviteViaEmail
                                    : sheetL10n.inviteViaLink,
                          ),
                          const SizedBox(height: 18),
                          Text(
                            sheetL10n.forChildLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: VisualRefreshColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                for (var i = 0; i < children.length; i++) ...[
                                  if (i > 0) const SizedBox(width: 8),
                                  _InviteChildChip(
                                    name: children[i].name,
                                    selected: children[i].id == selected.id,
                                    onTap: () => setLocal(() {
                                      selected = children[i];
                                    }),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            sheetL10n.guardianNameLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: VisualRefreshColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              color: VisualRefreshColors.textPrimary,
                            ),
                            decoration: _vrFieldDecoration(),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            sheetL10n.phoneWhatsAppLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: VisualRefreshColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              color: VisualRefreshColors.textPrimary,
                            ),
                            decoration: _vrFieldDecoration(
                              prefixIcon: _vrCountryPrefixChip(
                                sheetL10n.phoneCountryCode,
                              ),
                            ),
                          ),
                          if (channel == 'email') ...[
                            const SizedBox(height: 14),
                            Text(
                              sheetL10n.emailOptionalLabel,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: VisualRefreshColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            TextField(
                              controller: emailCtrl,
                              keyboardType: TextInputType.emailAddress,
                              style: GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w600,
                                color: VisualRefreshColors.textPrimary,
                              ),
                              decoration: _vrFieldDecoration(),
                            ),
                          ],
                          const SizedBox(height: 16),
                          _accessLevelPicker(
                            l10n: sheetL10n,
                            coParent: inviteAsCoParent,
                            refresh: true,
                            onChanged: (v) => setLocal(() {
                              inviteAsCoParent = v;
                            }),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: VisualRefreshColors.anchor,
                                foregroundColor: VisualRefreshColors.background,
                                elevation: 0,
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                sheetL10n.continueLabel,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      } else {
        ok = await showModalBottomSheet<bool>(
          context: context,
          isScrollControlled: true,
          builder: (ctx) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: StatefulBuilder(
                builder: (ctx, setLocal) {
                  final sheetL10n = AppLocalizations.of(ctx);
                  return SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          channel == 'whatsapp'
                              ? sheetL10n.inviteViaWhatsApp
                              : channel == 'email'
                                  ? sheetL10n.inviteViaEmail
                                  : sheetL10n.inviteViaLink,
                          style: const TextStyle(
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: selected.id,
                          decoration:
                              InputDecoration(labelText: sheetL10n.forChildLabel),
                          items: children
                              .map(
                                (c) => DropdownMenuItem(
                                  value: c.id,
                                  child: Text(c.name),
                                ),
                              )
                              .toList(),
                          onChanged: (id) {
                            if (id == null) return;
                            setLocal(() {
                              selected = children.firstWhere((c) => c.id == id);
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: InputDecoration(
                            labelText: sheetL10n.guardianNameLabel,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: phoneCtrl,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: sheetL10n.phoneWhatsAppLabel,
                          ),
                        ),
                        if (channel == 'email') ...[
                          const SizedBox(height: 8),
                          TextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: InputDecoration(
                              labelText: sheetL10n.emailOptionalLabel,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        _accessLevelPicker(
                          l10n: sheetL10n,
                          coParent: inviteAsCoParent,
                          refresh: false,
                          onChanged: (v) => setLocal(() {
                            inviteAsCoParent = v;
                          }),
                        ),
                        const SizedBox(height: 14),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.teal,
                          ),
                          child: Text(sheetL10n.continueLabel),
                        ),
                      ],
                    ),
                  );
                },
              ),
            );
          },
        );
      }

      if (ok != true || !mounted) return;
      final name = nameCtrl.text.trim();
      final phone = _composePhone(phoneCtrl.text, vrPrefixed: refresh);
      if (name.isEmpty || phone.length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.namePhoneRequired)),
        );
        return;
      }

      try {
        await ref.read(apiClientProvider).post(
          '/api/v1/guardians/invite',
          body: {
            'childId': selected.id,
            'guardianName': name,
            'guardianPhone': phone,
            'accessLevel': inviteAsCoParent ? 'co_parent' : 'view',
          },
        );
        await _loadAll();

        final message =
            l10n.guardianInviteBody(name, selected.name, _playStoreUrl);

        if (channel == 'whatsapp') {
          final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
          final uri = Uri.parse(
            'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
          );
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else if (channel == 'email') {
          final email = emailCtrl.text.trim();
          final uri = Uri(
            scheme: 'mailto',
            path: email.isEmpty ? null : email,
            queryParameters: {
              'subject': l10n.guardianInviteSubject,
              'body': message,
            },
          );
          await launchUrl(uri);
        } else {
          await Clipboard.setData(ClipboardData(text: message));
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.inviteLinkCopied)),
          );
        }
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.inviteFailedDetail('$e'))),
        );
      }
    } finally {
      nameCtrl.dispose();
      phoneCtrl.dispose();
      emailCtrl.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final children = ref.watch(childrenControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final guardians = _activeGuardians(l10n);
    final activeCount = guardians.length;
    final refresh = visualRefreshOf(context);
    final cardDecoration = _hubCardDecoration(refresh);

    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Column(
          children: [
            PaScreenHeader(
              title: l10n.guardiansTitle,
              subtitle: l10n.activeGuardiansCount(activeCount),
              crossAxisAlignment: CrossAxisAlignment.start,
              titleStyle: refresh
                  ? GoogleFonts.fraunces(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: VisualRefreshColors.textPrimary,
                    )
                  : null,
              subtitleStyle: refresh
                  ? GoogleFonts.plusJakartaSans(
                      color: VisualRefreshColors.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    )
                  : null,
            ),
            Expanded(
              child: RefreshIndicator(
                color: refresh ? VisualRefreshColors.accent : AppColors.teal,
                onRefresh: _loadAll,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: refresh
                            ? VisualRefreshColors.accentTint
                            : const Color(0xFFDCEBFF),
                        borderRadius: BorderRadius.circular(
                          refresh ? AppRadius.vrCard : 16,
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: refresh
                                ? VisualRefreshColors.accent
                                : const Color(0xFFE8913A),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              l10n.guardiansInviteHint,
                              style: TextStyle(
                                color: refresh
                                    ? VisualRefreshColors.accent
                                    : const Color(0xFF1E3A5F),
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                fontSize: 13.5,
                                fontFamily: refresh
                                    ? GoogleFonts.plusJakartaSans().fontFamily
                                    : null,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(l10n.activeGuardiansSection, refresh: refresh),
                    const SizedBox(height: 8),
                    Container(
                      decoration: cardDecoration,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: refresh
                                      ? VisualRefreshColors.anchor
                                      : AppColors.tealDeep,
                                  child: Text(
                                    _initials(auth.name),
                                    style: TextStyle(
                                      color: refresh
                                          ? VisualRefreshColors.background
                                          : Colors.white,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        auth.name ?? l10n.parentRoleFallback,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15.5,
                                          color: refresh
                                              ? VisualRefreshColors.textPrimary
                                              : null,
                                          fontFamily: refresh
                                              ? GoogleFonts.plusJakartaSans()
                                                  .fontFamily
                                              : null,
                                        ),
                                      ),
                                      Text(
                                        l10n.adminAllChildren,
                                        style: TextStyle(
                                          color: refresh
                                              ? VisualRefreshColors
                                                  .textSecondary
                                              : AppColors.inkSoft,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                          fontFamily: refresh
                                              ? GoogleFonts.plusJakartaSans()
                                                  .fontFamily
                                              : null,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: refresh
                                        ? VisualRefreshColors.accentTint
                                        : const Color(0xFFD8F5E8),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    l10n.youBadge,
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: refresh
                                          ? VisualRefreshColors.accent
                                          : AppColors.tealDeep,
                                      fontFamily: refresh
                                          ? GoogleFonts.plusJakartaSans()
                                              .fontFamily
                                          : null,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else
                            ...guardians.map((g) {
                              return Column(
                                children: [
                                  Divider(
                                    height: 1,
                                    thickness: refresh ? 0.5 : 1,
                                    indent: 14,
                                    endIndent: 14,
                                    color: refresh
                                        ? VisualRefreshColors.border
                                        : null,
                                  ),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      12,
                                      14,
                                      12,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor: refresh
                                              ? VisualRefreshColors.accentTint
                                              : const Color(0xFFDCEBFF),
                                          child: Text(
                                            _initials(g.name),
                                            style: TextStyle(
                                              color: refresh
                                                  ? VisualRefreshColors.accent
                                                  : const Color(0xFF2563EB),
                                              fontWeight: FontWeight.w900,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                g.name,
                                                style: TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 15,
                                                  color: refresh
                                                      ? VisualRefreshColors
                                                          .textPrimary
                                                      : null,
                                                  fontFamily: refresh
                                                      ? GoogleFonts
                                                              .plusJakartaSans()
                                                          .fontFamily
                                                      : null,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              _accessLevelBadge(
                                                context,
                                                coParent: g.isCoParent,
                                                refresh: refresh,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                g.status == 'invited'
                                                    ? l10n.waitingWithNames(
                                                        g.childNames
                                                            .join(', '),
                                                      )
                                                    : l10n.activeWithNames(
                                                        g.childNames
                                                            .join(', '),
                                                      ),
                                                style: TextStyle(
                                                  color: refresh
                                                      ? VisualRefreshColors
                                                          .textSecondary
                                                      : AppColors.inkSoft,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12.5,
                                                  fontFamily: refresh
                                                      ? GoogleFonts
                                                              .plusJakartaSans()
                                                          .fontFamily
                                                      : null,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _SectionLabel(l10n.accessPerChildSection, refresh: refresh),
                    const SizedBox(height: 8),
                    if (children.items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: cardDecoration,
                        child: Text(
                          l10n.noChildren,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: refresh
                                ? VisualRefreshColors.textSecondary
                                : AppColors.inkSoft,
                          ),
                        ),
                      )
                    else
                      Container(
                        decoration: cardDecoration,
                        child: Column(
                          children: [
                            for (var i = 0; i < children.items.length; i++) ...[
                              if (i > 0)
                                Divider(
                                  height: 1,
                                  thickness: refresh ? 0.5 : 1,
                                  indent: 70,
                                  endIndent: 14,
                                  color: refresh
                                      ? VisualRefreshColors.border
                                      : null,
                                ),
                              _ChildAccessRow(
                                child: children.items[i],
                                gender: _genders[children.items[i].id] ??
                                    ChildGenderStore.guessFromName(
                                      children.items[i].name,
                                    ),
                                guardians: (_byChild[children.items[i].id] ??
                                        const [])
                                    .where((g) => g['status'] != 'revoked')
                                    .toList(),
                                refresh: refresh,
                                onTap: () => _openChild(children.items[i]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    _SectionLabel(l10n.inviteNewSection, refresh: refresh),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      decoration: cardDecoration,
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: refresh
                                  ? VisualRefreshColors.accentTint
                                  : const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Icon(
                              Icons.person_add_alt_1_rounded,
                              color: refresh
                                  ? VisualRefreshColors.accent
                                  : const Color(0xFF7C3AED),
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            l10n.addTrustedGuardian,
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                              color: refresh
                                  ? VisualRefreshColors.textPrimary
                                  : null,
                              fontFamily: refresh
                                  ? GoogleFonts.plusJakartaSans().fontFamily
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            l10n.guardianInviteChannelHint,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: refresh
                                  ? VisualRefreshColors.textSecondary
                                  : AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                              fontFamily: refresh
                                  ? GoogleFonts.plusJakartaSans().fontFamily
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _InviteChannelButton(
                                  icon: Icons.chat_rounded,
                                  label: l10n.channelWhatsApp,
                                  bg: refresh
                                      ? VisualRefreshColors.accentTint
                                      : const Color(0xFFD8F5E8),
                                  fg: refresh
                                      ? VisualRefreshColors.accent
                                      : AppColors.tealDeep,
                                  onTap: () => _inviteFlow('whatsapp'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _InviteChannelButton(
                                  icon: Icons.email_outlined,
                                  label: l10n.channelEmail,
                                  bg: refresh
                                      ? VisualRefreshColors.routeTint
                                      : const Color(0xFFDCEBFF),
                                  fg: refresh
                                      ? VisualRefreshColors.routeText
                                      : const Color(0xFF2563EB),
                                  onTap: () => _inviteFlow('email'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _InviteChannelButton(
                                  icon: Icons.link_rounded,
                                  label: l10n.channelLink,
                                  bg: refresh
                                      ? VisualRefreshColors.tagMuted
                                      : const Color(0xFFE8ECF0),
                                  fg: refresh
                                      ? VisualRefreshColors.textPrimary
                                      : AppColors.ink,
                                  onTap: () => _inviteFlow('link'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteChildChip extends StatelessWidget {
  const _InviteChildChip({
    required this.name,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final bool selected;
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: selected
                ? null
                : Border.all(
                    color: VisualRefreshColors.border,
                    width: 0.5,
                  ),
          ),
          child: Text(
            name,
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: selected
                  ? VisualRefreshColors.background
                  : VisualRefreshColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text, {this.refresh = false});

  final String text;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: refresh
            ? VisualRefreshColors.textTertiary
            : AppColors.inkSoft,
        fontFamily:
            refresh ? GoogleFonts.plusJakartaSans().fontFamily : null,
      ),
    );
  }
}

class _ChildAccessRow extends StatelessWidget {
  const _ChildAccessRow({
    required this.child,
    required this.gender,
    required this.guardians,
    required this.onTap,
    this.refresh = false,
  });

  final ChildSummary child;
  final ChildGender gender;
  final List<Map<String, dynamic>> guardians;
  final VoidCallback onTap;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final names = guardians
        .map((g) => g['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .take(2)
        .join(', ');
    final subtitle = guardians.isEmpty
        ? l10n.zeroGuardiansAdd
        : names.isEmpty
            ? l10n.guardiansCountOnly(guardians.length)
            : l10n.guardiansCountNamed(guardians.length, names);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              if (refresh)
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: VisualRefreshColors.accentTint,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.person_outline_rounded,
                    color: VisualRefreshColors.accent,
                    size: 24,
                  ),
                )
              else
                ChildAvatar(name: child.name, gender: gender, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                        color: refresh
                            ? VisualRefreshColors.textPrimary
                            : null,
                        fontFamily: refresh
                            ? GoogleFonts.plusJakartaSans().fontFamily
                            : null,
                      ),
                    ),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: refresh
                            ? VisualRefreshColors.textSecondary
                            : AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
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

class _InviteChannelButton extends StatelessWidget {
  const _InviteChannelButton({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail wali untuk satu anak.
class GuardiansScreen extends ConsumerStatefulWidget {
  const GuardiansScreen({super.key, required this.child});

  final ChildSummary child;

  @override
  ConsumerState<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends ConsumerState<GuardiansScreen> {
  List<Map<String, dynamic>> _guardians = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/api/v1/guardians', query: {
        'childId': widget.child.id,
      });
      setState(() {
        _guardians = (data['guardians'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _invite() async {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: refresh ? '' : '+62');
    var inviteAsCoParent = false;

    try {
      final bool? ok;
      if (refresh) {
        ok = await showVrModalBottomSheet<bool>(
          context: context,
          builder: (ctx) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.viewInsetsOf(ctx).bottom,
              ),
              child: VrSheetShell(
                child: StatefulBuilder(
                  builder: (ctx, setLocal) {
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          VrSheetTitle(l10n.inviteGuardian),
                          const SizedBox(height: 18),
                          Text(
                            l10n.guardianNameLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: VisualRefreshColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: nameCtrl,
                            textCapitalization: TextCapitalization.words,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              color: VisualRefreshColors.textPrimary,
                            ),
                            decoration: _vrFieldDecoration(),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            l10n.phoneWhatsAppLabel,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: VisualRefreshColors.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w600,
                              color: VisualRefreshColors.textPrimary,
                            ),
                            decoration: _vrFieldDecoration(
                              prefixIcon: _vrCountryPrefixChip(
                                l10n.phoneCountryCode,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          _accessLevelPicker(
                            l10n: l10n,
                            coParent: inviteAsCoParent,
                            refresh: true,
                            onChanged: (v) => setLocal(() {
                              inviteAsCoParent = v;
                            }),
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            height: 52,
                            child: FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              style: FilledButton.styleFrom(
                                backgroundColor: VisualRefreshColors.anchor,
                                foregroundColor: VisualRefreshColors.background,
                                elevation: 0,
                                shape: const StadiumBorder(),
                              ),
                              child: Text(
                                l10n.save,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            );
          },
        );
      } else {
        ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setLocal) {
              return AlertDialog(
                title: Text(l10n.inviteGuardian),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextField(
                        controller: nameCtrl,
                        decoration:
                            InputDecoration(labelText: l10n.guardianNameLabel),
                      ),
                      TextField(
                        controller: phoneCtrl,
                        decoration: InputDecoration(
                          labelText: l10n.phoneWhatsAppLabel,
                        ),
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      _accessLevelPicker(
                        l10n: l10n,
                        coParent: inviteAsCoParent,
                        refresh: false,
                        onChanged: (v) => setLocal(() {
                          inviteAsCoParent = v;
                        }),
                      ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: Text(l10n.cancel),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style:
                        FilledButton.styleFrom(backgroundColor: AppColors.teal),
                    child: Text(l10n.save),
                  ),
                ],
              );
            },
          ),
        );
      }
      if (ok != true) return;

      try {
        final api = ref.read(apiClientProvider);
        await api.post('/api/v1/guardians/invite', body: {
          'childId': widget.child.id,
          'guardianName': nameCtrl.text.trim(),
          'guardianPhone': _composePhone(phoneCtrl.text, vrPrefixed: refresh),
          'accessLevel': inviteAsCoParent ? 'co_parent' : 'view',
        });
        await _load();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.failedGenericDetail('$e'))),
        );
      }
    } finally {
      nameCtrl.dispose();
      phoneCtrl.dispose();
    }
  }

  Future<void> _setAccessLevel({
    required String guardianId,
    required String name,
    required String nextLevel,
  }) async {
    final l10n = AppLocalizations.of(context);
    final promote = nextLevel == 'co_parent';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          promote ? l10n.promoteToCoParentTitle : l10n.demoteToGuardianTitle,
        ),
        content: Text(
          promote
              ? l10n.promoteToCoParentBody(name)
              : l10n.demoteToGuardianBody(name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: visualRefreshOf(context)
                  ? VisualRefreshColors.anchor
                  : AppColors.teal,
            ),
            child: Text(
              promote
                  ? l10n.confirmPromoteCoParent
                  : l10n.confirmDemoteGuardian,
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      final api = ref.read(apiClientProvider);
      await api.patch('/api/v1/guardians/access-level', body: {
        'childId': widget.child.id,
        'guardianId': guardianId,
        'accessLevel': nextLevel,
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.failedGenericDetail('$e'))),
      );
    }
  }

  Future<void> _revoke(String guardianId) async {
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/guardians/revoke', body: {
      'childId': widget.child.id,
      'guardianId': guardianId,
    });
    await _load();
  }

  String _firstLetter(String? name) {
    final t = (name ?? '').trim();
    if (t.isEmpty) return 'W';
    return t[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final active = _guardians.where((g) => g['status'] != 'revoked').toList();
    final refresh = visualRefreshOf(context);
    final cardDecoration = _hubCardDecoration(refresh);
    final showEmpty = !_loading && active.isEmpty;

    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : const Color(0xFFF0F2F5),
      floatingActionButton: refresh
          ? null
          : FloatingActionButton.extended(
              onPressed: _invite,
              backgroundColor: AppColors.teal,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: Text(l10n.inviteGuardian),
            ),
      body: SafeArea(
        child: Column(
          children: [
            PaScreenHeader(
              title: l10n.guardiansForChildTitle(widget.child.name),
              crossAxisAlignment: CrossAxisAlignment.start,
              titleStyle: refresh
                  ? GoogleFonts.fraunces(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      color: VisualRefreshColors.textPrimary,
                    )
                  : null,
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : refresh && showEmpty
                      ? PaVrEmptyState(
                          icon: Icons.person_add_alt_1_rounded,
                          message: l10n.noGuardiansForChild,
                          actionLabel: l10n.inviteGuardian,
                          actionIcon: Icons.person_add_alt_1_rounded,
                          onAction: _invite,
                        )
                      : RefreshIndicator(
                          color: refresh
                              ? VisualRefreshColors.accent
                              : AppColors.teal,
                          onRefresh: _load,
                          child: ListView(
                            padding: EdgeInsets.fromLTRB(
                              16,
                              8,
                              16,
                              refresh ? 28 : 100,
                            ),
                            children: [
                              if (active.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(24),
                                  decoration: cardDecoration,
                                  child: Text(
                                    l10n.noGuardiansForChild,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: AppColors.inkSoft,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              else ...[
                                ...active.map((g) {
                                  final status = g['status']?.toString() ?? '';
                                  final coParent = _isCoParentGuardian(g);
                                  final name =
                                      g['name']?.toString() ??
                                          l10n.guardianFallbackName;
                                  final guardianId =
                                      g['guardian_id'] as String;
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Container(
                                      padding: const EdgeInsets.fromLTRB(
                                        14,
                                        12,
                                        8,
                                        12,
                                      ),
                                      decoration: cardDecoration,
                                      child: Row(
                                        children: [
                                          CircleAvatar(
                                            radius: 22,
                                            backgroundColor: refresh
                                                ? VisualRefreshColors.accentTint
                                                : const Color(0xFFDCEBFF),
                                            child: Text(
                                              _firstLetter(name),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w900,
                                                color: refresh
                                                    ? VisualRefreshColors
                                                        .accent
                                                    : const Color(0xFF2563EB),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  name,
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.w900,
                                                    color: refresh
                                                        ? VisualRefreshColors
                                                            .textPrimary
                                                        : null,
                                                    fontFamily: refresh
                                                        ? GoogleFonts
                                                                .plusJakartaSans()
                                                            .fontFamily
                                                        : null,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                _accessLevelBadge(
                                                  context,
                                                  coParent: coParent,
                                                  refresh: refresh,
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${g['phone']} · $status',
                                                  style: TextStyle(
                                                    color: refresh
                                                        ? VisualRefreshColors
                                                            .textSecondary
                                                        : AppColors.inkSoft,
                                                    fontWeight: FontWeight.w600,
                                                    fontSize: 12.5,
                                                    fontFamily: refresh
                                                        ? GoogleFonts
                                                                .plusJakartaSans()
                                                            .fontFamily
                                                        : null,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: l10n.changeAccessLevel,
                                            icon: Icon(
                                              coParent
                                                  ? Icons.arrow_downward
                                                  : Icons.arrow_upward,
                                              color: refresh
                                                  ? VisualRefreshColors.accent
                                                  : AppColors.tealDeep,
                                            ),
                                            onPressed: () => _setAccessLevel(
                                              guardianId: guardianId,
                                              name: name,
                                              nextLevel: coParent
                                                  ? 'view'
                                                  : 'co_parent',
                                            ),
                                          ),
                                          IconButton(
                                            tooltip: l10n.revokeAccessTooltip,
                                            icon: Icon(
                                              Icons.block,
                                              color: refresh
                                                  ? VisualRefreshColors.danger
                                                  : AppColors.danger,
                                            ),
                                            onPressed: () =>
                                                _revoke(guardianId),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }),
                                if (refresh) ...[
                                  const SizedBox(height: 12),
                                  SizedBox(
                                    width: double.infinity,
                                    height: 52,
                                    child: FilledButton(
                                      onPressed: _invite,
                                      style: FilledButton.styleFrom(
                                        backgroundColor:
                                            VisualRefreshColors.anchor,
                                        foregroundColor:
                                            VisualRefreshColors.background,
                                        elevation: 0,
                                        shape: const StadiumBorder(),
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(
                                            Icons.person_add_alt_1_rounded,
                                            size: 20,
                                          ),
                                          const SizedBox(width: 8),
                                          Text(
                                            l10n.inviteGuardian,
                                            style:
                                                GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 15,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }
}
