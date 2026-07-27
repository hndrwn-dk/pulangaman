import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/locale_controller.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_web_screen.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import '../auth/auth_controller.dart';
import 'visual_refresh_flag.dart';

class AccountSettingsScreen extends ConsumerStatefulWidget {
  const AccountSettingsScreen({super.key});

  static const _privacyUrl = 'https://www.tursinalabs.com/privacy';
  static const _termsUrl = 'https://www.tursinalabs.com/terms';
  static const _playStoreUrl =
      'https://play.google.com/store/apps/details?id=com.tursinalabs.pulangaman';

  /// Keep in sync with pubspec.yaml `version:`.
  static const _versionName = '0.2.0';
  static const _versionCode = '1';

  @override
  ConsumerState<AccountSettingsScreen> createState() =>
      _AccountSettingsScreenState();
}

class _AccountSettingsScreenState extends ConsumerState<AccountSettingsScreen> {
  bool _languageOpen = false;
  bool _aboutOpen = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final locale = ref.watch(localeControllerProvider);
    final visualRefresh = ref.watch(visualRefreshEnabledProvider);
    final refresh = visualRefreshOf(context);
    final l10n = AppLocalizations.of(context);
    final currentLabel = locale.languageCode == 'en'
        ? l10n.settingsLanguageEn
        : l10n.settingsLanguageId;
    final displayName = auth.name ?? l10n.parentFallbackName;

    if (refresh) {
      return _buildVisualRefresh(
        context,
        auth: auth,
        locale: locale,
        visualRefresh: visualRefresh,
        l10n: l10n,
        currentLabel: currentLabel,
        displayName: displayName,
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: Text(l10n.settingsAccountTitle),
        backgroundColor: const Color(0xFFF0F2F5),
        surfaceTintColor: Colors.transparent,
        leadingWidth: PaScreenHeader.appBarLeadingWidth,
        titleSpacing: PaScreenHeader.appBarTitleSpacing,
        // Explicit pop only — never logout.
        leading: paAppBarLeading(context),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SectionTitle(l10n.settingsSectionAccount),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.tealDeep,
                  child: Text(
                    _initials(auth.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.parentAccountSubtitle,
                        style: const TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(l10n.settingsLanguage),
          _AccordionCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.language_rounded),
                  title: Text(
                    l10n.settingsLanguage,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(
                    _languageOpen
                        ? l10n.settingsLanguageHint
                        : currentLabel,
                  ),
                  trailing: Icon(
                    _languageOpen
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                  onTap: () => setState(() {
                    _languageOpen = !_languageOpen;
                    if (_languageOpen) _aboutOpen = false;
                  }),
                ),
                if (_languageOpen) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  _LanguageOption(
                    label: l10n.settingsLanguageId,
                    selected: locale.languageCode == 'id',
                    onTap: () {
                      unawaited(
                        ref
                            .read(localeControllerProvider.notifier)
                            .setLocale(const Locale('id')),
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _LanguageOption(
                    label: l10n.settingsLanguageEn,
                    selected: locale.languageCode == 'en',
                    onTap: () {
                      unawaited(
                        ref
                            .read(localeControllerProvider.notifier)
                            .setLocale(const Locale('en')),
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          _AccordionCard(
            child: SwitchListTile(
              secondary: const Icon(Icons.palette_outlined),
              title: Text(
                l10n.settingsVisualRefresh,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(l10n.settingsVisualRefreshHint),
              value: visualRefresh,
              activeThumbColor: AppColors.teal,
              onChanged: (value) {
                unawaited(
                  ref
                      .read(visualRefreshEnabledProvider.notifier)
                      .setEnabled(value),
                );
              },
            ),
          ),
          const SizedBox(height: 20),
          _SectionTitle(l10n.settingsSectionApp),
          _AccordionCard(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline_rounded),
                  title: Text(
                    l10n.settingsAbout,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: Text(l10n.settingsAboutHint),
                  trailing: Icon(
                    _aboutOpen
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                  ),
                  onTap: () => setState(() {
                    _aboutOpen = !_aboutOpen;
                    if (_aboutOpen) _languageOpen = false;
                  }),
                ),
                if (_aboutOpen) ...[
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.tag_rounded),
                    title: Text(
                      l10n.settingsVersion,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      l10n.settingsVersionValue(
                        AccountSettingsScreen._versionName,
                        AccountSettingsScreen._versionCode,
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _AboutLinkTile(
                    icon: Icons.ios_share_rounded,
                    title: l10n.settingsShare,
                    subtitle: l10n.settingsShareHint,
                    trailing: Icons.chevron_right,
                    onTap: () => unawaited(_shareApp(l10n)),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _AboutLinkTile(
                    icon: Icons.star_outline_rounded,
                    title: l10n.settingsRate,
                    subtitle: l10n.settingsRateHint,
                    trailing: Icons.chevron_right,
                    onTap: () => unawaited(
                      _openExternal(AccountSettingsScreen._playStoreUrl),
                    ),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _AboutLinkTile(
                    icon: Icons.privacy_tip_outlined,
                    title: l10n.settingsPrivacy,
                    subtitle: l10n.settingsPrivacyHint,
                    trailing: Icons.open_in_new_rounded,
                    onTap: () => _openWebPage(
                      context,
                      l10n.settingsPrivacy,
                      AccountSettingsScreen._privacyUrl,
                    ),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _AboutLinkTile(
                    icon: Icons.description_outlined,
                    title: l10n.settingsTerms,
                    subtitle: l10n.settingsTermsHint,
                    trailing: Icons.open_in_new_rounded,
                    onTap: () => _openWebPage(
                      context,
                      l10n.settingsTerms,
                      AccountSettingsScreen._termsUrl,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          _AccordionCard(
            child: ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: Text(
                l10n.settingsNotifications,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(l10n.settingsNotificationsHint),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _openNotificationSettings(context),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: auth.loading
                ? null
                : () async {
                    await ref.read(authControllerProvider.notifier).logout();
                  },
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: Text(
              l10n.logout,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVisualRefresh(
    BuildContext context, {
    required AuthState auth,
    required Locale locale,
    required bool visualRefresh,
    required AppLocalizations l10n,
    required String currentLabel,
    required String displayName,
  }) {
    return Scaffold(
      backgroundColor: VisualRefreshColors.background,
      body: SafeArea(
        child: Column(
          children: [
            PaScreenHeader(
              title: l10n.settingsAccountTitle,
              showBack: Navigator.of(context).canPop(),
              titleStyle: GoogleFonts.fraunces(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: VisualRefreshColors.textPrimary,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  _VrSectionLabel(l10n.settingsSectionAccount),
                  const SizedBox(height: 8),
                  _VrCard(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: VisualRefreshColors.anchor,
                          child: Text(
                            _initials(auth.name),
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16.5,
                                  color: VisualRefreshColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.parentAccountSubtitle,
                                style: GoogleFonts.plusJakartaSans(
                                  color: VisualRefreshColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _VrSectionLabel(l10n.settingsLanguage),
                  const SizedBox(height: 8),
                  _VrCard(
                    child: Column(
                      children: [
                        InkWell(
                          onTap: () => setState(() {
                            _languageOpen = !_languageOpen;
                          }),
                          borderRadius: BorderRadius.circular(AppRadius.vrCard),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 12, 14),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.language_rounded,
                                  color: VisualRefreshColors.textSecondary,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        l10n.settingsLanguage,
                                        style: GoogleFonts.plusJakartaSans(
                                          fontWeight: FontWeight.w700,
                                          fontSize: 15.5,
                                          color: VisualRefreshColors.textPrimary,
                                        ),
                                      ),
                                      if (!_languageOpen) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          currentLabel,
                                          style: GoogleFonts.plusJakartaSans(
                                            color: VisualRefreshColors
                                                .textSecondary,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Icon(
                                  _languageOpen
                                      ? Icons.expand_less_rounded
                                      : Icons.expand_more_rounded,
                                  color: VisualRefreshColors.textTertiary,
                                ),
                              ],
                            ),
                          ),
                        ),
                        if (_languageOpen) ...[
                          const Divider(
                            height: 1,
                            indent: 14,
                            endIndent: 14,
                            color: VisualRefreshColors.border,
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                            child: Column(
                              children: [
                                _VrLanguageOption(
                                  label: l10n.settingsLanguageId,
                                  selected: locale.languageCode == 'id',
                                  onTap: () {
                                    unawaited(
                                      ref
                                          .read(
                                            localeControllerProvider.notifier,
                                          )
                                          .setLocale(const Locale('id')),
                                    );
                                  },
                                ),
                                const SizedBox(height: 4),
                                _VrLanguageOption(
                                  label: l10n.settingsLanguageEn,
                                  selected: locale.languageCode == 'en',
                                  onTap: () {
                                    unawaited(
                                      ref
                                          .read(
                                            localeControllerProvider.notifier,
                                          )
                                          .setLocale(const Locale('en')),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  _VrCard(
                    padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.palette_outlined,
                          color: VisualRefreshColors.textSecondary,
                          size: 22,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l10n.settingsVisualRefresh,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15.5,
                                  color: VisualRefreshColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                l10n.settingsVisualRefreshHint,
                                style: GoogleFonts.plusJakartaSans(
                                  color: VisualRefreshColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: visualRefresh,
                          activeThumbColor: Colors.white,
                          activeTrackColor: VisualRefreshColors.accent,
                          onChanged: (value) {
                            unawaited(
                              ref
                                  .read(visualRefreshEnabledProvider.notifier)
                                  .setEnabled(value),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  _VrSectionLabel(l10n.settingsSectionApp),
                  const SizedBox(height: 8),
                  _VrCard(
                    child: Column(
                      children: [
                        _VrNavRow(
                          icon: Icons.info_outline_rounded,
                          title: l10n.settingsAbout,
                          subtitle: l10n.settingsAboutHint,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => const _AboutScreen(),
                              ),
                            );
                          },
                        ),
                        const Divider(
                          height: 1,
                          indent: 48,
                          endIndent: 14,
                          color: VisualRefreshColors.border,
                        ),
                        _VrNavRow(
                          icon: Icons.notifications_outlined,
                          title: l10n.settingsNotifications,
                          subtitle: l10n.settingsNotificationsHint,
                          onTap: () => _openNotificationSettings(context),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton.icon(
                      onPressed: auth.loading
                          ? null
                          : () async {
                              await ref
                                  .read(authControllerProvider.notifier)
                                  .logout();
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: VisualRefreshColors.danger,
                        side: const BorderSide(
                          color: VisualRefreshColors.danger,
                          width: 1,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 20),
                      label: Text(
                        l10n.logout,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 15.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareApp(AppLocalizations l10n) async {
    await Share.share(l10n.settingsShareMessage);
  }

  Future<void> _openExternal(String url) async {
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(url)),
      );
    }
  }

  static void _openWebPage(BuildContext context, String title, String url) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaWebScreen(title: title, url: url),
      ),
    );
  }

  static Future<void> _openNotificationSettings(BuildContext context) async {
    final opened = await openAppSettings();
    if (opened || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor:
          refresh ? VisualRefreshColors.surface : null,
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.notificationsSheetTitle,
                style: refresh
                    ? GoogleFonts.fraunces(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                        color: VisualRefreshColors.textPrimary,
                      )
                    : const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.notificationsSheetBody,
                style: TextStyle(
                  color: refresh
                      ? VisualRefreshColors.textSecondary
                      : AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  fontFamily: refresh
                      ? GoogleFonts.plusJakartaSans().fontFamily
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  style: refresh
                      ? FilledButton.styleFrom(
                          backgroundColor: VisualRefreshColors.anchor,
                          foregroundColor: VisualRefreshColors.background,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                        )
                      : null,
                  child: Text(
                    l10n.understood,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontFamily: refresh
                          ? GoogleFonts.plusJakartaSans().fontFamily
                          : null,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'PA';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return ('${parts[0][0]}${parts[1][0]}').toUpperCase();
  }
}

class _AboutScreen extends StatelessWidget {
  const _AboutScreen();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);

    Future<void> shareApp() async {
      await Share.share(l10n.settingsShareMessage);
    }

    Future<void> openExternal(String url) async {
      final uri = Uri.parse(url);
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(url)),
        );
      }
    }

    void openWeb(String title, String url) {
      Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PaWebScreen(title: title, url: url),
        ),
      );
    }

    if (!refresh) {
      return Scaffold(
        backgroundColor: const Color(0xFFF0F2F5),
        appBar: AppBar(
          title: Text(l10n.settingsAbout),
          leadingWidth: PaScreenHeader.appBarLeadingWidth,
          titleSpacing: PaScreenHeader.appBarTitleSpacing,
          leading: paAppBarLeading(context),
        ),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _AccordionCard(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.tag_rounded),
                    title: Text(
                      l10n.settingsVersion,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                    subtitle: Text(
                      l10n.settingsVersionValue(
                        AccountSettingsScreen._versionName,
                        AccountSettingsScreen._versionCode,
                      ),
                    ),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _AboutLinkTile(
                    icon: Icons.ios_share_rounded,
                    title: l10n.settingsShare,
                    subtitle: l10n.settingsShareHint,
                    trailing: Icons.chevron_right,
                    onTap: () => unawaited(shareApp()),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _AboutLinkTile(
                    icon: Icons.star_outline_rounded,
                    title: l10n.settingsRate,
                    subtitle: l10n.settingsRateHint,
                    trailing: Icons.chevron_right,
                    onTap: () => unawaited(
                      openExternal(AccountSettingsScreen._playStoreUrl),
                    ),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _AboutLinkTile(
                    icon: Icons.privacy_tip_outlined,
                    title: l10n.settingsPrivacy,
                    subtitle: l10n.settingsPrivacyHint,
                    trailing: Icons.open_in_new_rounded,
                    onTap: () => openWeb(
                      l10n.settingsPrivacy,
                      AccountSettingsScreen._privacyUrl,
                    ),
                  ),
                  const Divider(height: 1, indent: 56, endIndent: 16),
                  _AboutLinkTile(
                    icon: Icons.description_outlined,
                    title: l10n.settingsTerms,
                    subtitle: l10n.settingsTermsHint,
                    trailing: Icons.open_in_new_rounded,
                    onTap: () => openWeb(
                      l10n.settingsTerms,
                      AccountSettingsScreen._termsUrl,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: VisualRefreshColors.background,
      body: SafeArea(
        child: Column(
          children: [
            PaScreenHeader(
              title: l10n.settingsAbout,
              showBack: Navigator.of(context).canPop(),
              titleStyle: GoogleFonts.fraunces(
                fontSize: 22,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.4,
                color: VisualRefreshColors.textPrimary,
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                children: [
                  _VrCard(
                    child: Column(
                      children: [
                        _VrNavRow(
                          icon: Icons.tag_rounded,
                          title: l10n.settingsVersion,
                          subtitle: l10n.settingsVersionValue(
                            AccountSettingsScreen._versionName,
                            AccountSettingsScreen._versionCode,
                          ),
                          showChevron: false,
                        ),
                        const Divider(
                          height: 1,
                          indent: 48,
                          endIndent: 14,
                          color: VisualRefreshColors.border,
                        ),
                        _VrNavRow(
                          icon: Icons.ios_share_rounded,
                          title: l10n.settingsShare,
                          subtitle: l10n.settingsShareHint,
                          onTap: () => unawaited(shareApp()),
                        ),
                        const Divider(
                          height: 1,
                          indent: 48,
                          endIndent: 14,
                          color: VisualRefreshColors.border,
                        ),
                        _VrNavRow(
                          icon: Icons.star_outline_rounded,
                          title: l10n.settingsRate,
                          subtitle: l10n.settingsRateHint,
                          onTap: () => unawaited(
                            openExternal(AccountSettingsScreen._playStoreUrl),
                          ),
                        ),
                        const Divider(
                          height: 1,
                          indent: 48,
                          endIndent: 14,
                          color: VisualRefreshColors.border,
                        ),
                        _VrNavRow(
                          icon: Icons.privacy_tip_outlined,
                          title: l10n.settingsPrivacy,
                          subtitle: l10n.settingsPrivacyHint,
                          trailingIcon: Icons.open_in_new_rounded,
                          onTap: () => openWeb(
                            l10n.settingsPrivacy,
                            AccountSettingsScreen._privacyUrl,
                          ),
                        ),
                        const Divider(
                          height: 1,
                          indent: 48,
                          endIndent: 14,
                          color: VisualRefreshColors.border,
                        ),
                        _VrNavRow(
                          icon: Icons.description_outlined,
                          title: l10n.settingsTerms,
                          subtitle: l10n.settingsTermsHint,
                          trailingIcon: Icons.open_in_new_rounded,
                          onTap: () => openWeb(
                            l10n.settingsTerms,
                            AccountSettingsScreen._termsUrl,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VrSectionLabel extends StatelessWidget {
  const _VrSectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 2),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.plusJakartaSans(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.1,
          color: VisualRefreshColors.textTertiary,
        ),
      ),
    );
  }
}

class _VrCard extends StatelessWidget {
  const _VrCard({required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: VisualRefreshColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.vrCard),
        border: Border.all(
          color: VisualRefreshColors.border,
          width: 0.5,
        ),
      ),
      child: child,
    );
  }
}

class _VrLanguageOption extends StatelessWidget {
  const _VrLanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? VisualRefreshColors.accentTint : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    color: selected
                        ? VisualRefreshColors.accent
                        : VisualRefreshColors.textPrimary,
                  ),
                ),
              ),
              _VrRadioDot(selected: selected),
            ],
          ),
        ),
      ),
    );
  }
}

class _VrRadioDot extends StatelessWidget {
  const _VrRadioDot({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 22,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? VisualRefreshColors.accent
              : VisualRefreshColors.border,
          width: 1.5,
        ),
      ),
      child: selected
          ? Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: VisualRefreshColors.accent,
              ),
            )
          : null,
    );
  }
}

class _VrNavRow extends StatelessWidget {
  const _VrNavRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.onTap,
    this.showChevron = true,
    this.trailingIcon,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback? onTap;
  final bool showChevron;
  final IconData? trailingIcon;

  @override
  Widget build(BuildContext context) {
    final trailing = trailingIcon ??
        (showChevron ? Icons.chevron_right_rounded : null);
    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
      child: Row(
        children: [
          Icon(icon, color: VisualRefreshColors.textSecondary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    fontSize: 15.5,
                    color: VisualRefreshColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: VisualRefreshColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null)
            Icon(trailing, color: VisualRefreshColors.textTertiary),
        ],
      ),
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.vrCard),
        child: content,
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.tealDeep,
          fontWeight: FontWeight.w800,
          fontSize: 13,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

class _AccordionCard extends StatelessWidget {
  const _AccordionCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: child,
    );
  }
}

class _LanguageOption extends StatelessWidget {
  const _LanguageOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        Icons.translate_rounded,
        color: selected ? AppColors.tealDeep : AppColors.inkSoft,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
      trailing: selected
          ? const Icon(Icons.check_circle_rounded, color: AppColors.teal)
          : const Icon(Icons.circle_outlined, color: Color(0xFFD0D5DA)),
      onTap: onTap,
    );
  }
}

class _AboutLinkTile extends StatelessWidget {
  const _AboutLinkTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final IconData trailing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      subtitle: Text(subtitle),
      trailing: Icon(trailing, color: AppColors.inkSoft),
      onTap: onTap,
    );
  }
}
