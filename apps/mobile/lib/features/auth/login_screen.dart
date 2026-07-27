import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/config.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import '../parent/visual_refresh_flag.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+62812');
  final _inviteCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  AppRole _role = AppRole.parent;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _inviteCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final auth = ref.read(authControllerProvider);
    final notifier = ref.read(authControllerProvider.notifier);

    if (_role == AppRole.child) {
      notifier.joinWithInvite(
        name: _nameCtrl.text,
        inviteCode: _inviteCtrl.text,
      );
      return;
    }

    if (auth.awaitingOtp && !AppConfig.useDevAuth) {
      notifier.confirmOtp(_otpCtrl.text);
      return;
    }

    notifier.login(
      name: _nameCtrl.text,
      phone: _phoneCtrl.text,
      role: _role,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    // Provider starts from compile-time VISUAL_REFRESH, then SessionStore
    // preference (if set) wins once loaded — so login honors dart-define
    // even before preference finishes loading.
    final refresh = ref.watch(visualRefreshEnabledProvider);
    final showOtp = auth.awaitingOtp &&
        _role != AppRole.child &&
        !AppConfig.useDevAuth;

    return Scaffold(
      backgroundColor:
          refresh ? VisualRefreshColors.background : AppColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, refresh ? 28 : 20, 20, 28),
          children: [
            _BrandHeader(refresh: refresh),
            if (!refresh) ...[
              const SizedBox(height: 14),
              const _FeatureRow(),
            ],
            SizedBox(height: refresh ? 28 : 20),
            _LoginCard(
              refresh: refresh,
              role: _role,
              nameCtrl: _nameCtrl,
              phoneCtrl: _phoneCtrl,
              inviteCtrl: _inviteCtrl,
              otpCtrl: _otpCtrl,
              showOtp: showOtp,
              error: auth.error,
              loading: auth.loading,
              onRoleChanged: (role) {
                if (auth.awaitingOtp) {
                  ref.read(authControllerProvider.notifier).cancelOtp();
                  _otpCtrl.clear();
                }
                setState(() => _role = role);
              },
              onSubmit: _submit,
              onResendOtp: () =>
                  ref.read(authControllerProvider.notifier).resendOtp(),
              onChangeNumber: () {
                ref.read(authControllerProvider.notifier).cancelOtp();
                _otpCtrl.clear();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader({required this.refresh});

  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final content = Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(refresh ? 14 : 16),
          child: Image.asset(
            'assets/images/app_icon.png',
            width: refresh ? 56 : 58,
            height: refresh ? 56 : 58,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.brand,
                style: refresh
                    ? GoogleFonts.fraunces(
                        fontSize: 26,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.4,
                        height: 1.15,
                        color: VisualRefreshColors.textPrimary,
                      )
                    : Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: AppColors.tealDeep,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          height: 1.1,
                        ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.tagline,
                style: refresh
                    ? GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        height: 1.35,
                        color: VisualRefreshColors.textSecondary,
                      )
                    : Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSoft,
                          height: 1.35,
                        ),
              ),
            ],
          ),
        ),
      ],
    );

    if (refresh) return content;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDeep.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: content,
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Row(
      children: [
        Expanded(
          child: _FeatureCard(
            label: l10n.featureCheckIn,
            icon: Icons.school_rounded,
            background: const Color(0xFFD6EEFC),
            iconBackground: const Color(0xFF3B8FD9),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FeatureCard(
            label: l10n.featureRewards,
            icon: Icons.star_rounded,
            background: const Color(0xFFFFF0C2),
            iconBackground: const Color(0xFFE8A820),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _FeatureCard(
            label: l10n.featureScreenTime,
            icon: Icons.hourglass_bottom_rounded,
            background: const Color(0xFFE8DFFB),
            iconBackground: const Color(0xFF8B6FD4),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.label,
    required this.icon,
    required this.background,
    required this.iconBackground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.refresh,
    required this.role,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.inviteCtrl,
    required this.otpCtrl,
    required this.showOtp,
    required this.error,
    required this.loading,
    required this.onRoleChanged,
    required this.onSubmit,
    required this.onResendOtp,
    required this.onChangeNumber,
  });

  final bool refresh;
  final AppRole role;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController inviteCtrl;
  final TextEditingController otpCtrl;
  final bool showOtp;
  final String? error;
  final bool loading;
  final ValueChanged<AppRole> onRoleChanged;
  final VoidCallback onSubmit;
  final VoidCallback onResendOtp;
  final VoidCallback onChangeNumber;

  InputDecoration _fieldDecoration({
    required String hint,
    bool counterHidden = false,
  }) {
    if (!refresh) {
      return InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: Color(0xFFB0BDB9)),
        counterText: counterHidden ? '' : null,
      );
    }
    return InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.plusJakartaSans(
        color: VisualRefreshColors.textTertiary,
        fontWeight: FontWeight.w500,
        fontSize: 15,
      ),
      filled: true,
      fillColor: VisualRefreshColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      counterText: counterHidden ? '' : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: VisualRefreshColors.hairline,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: VisualRefreshColors.hairline,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(
          color: VisualRefreshColors.accent,
          width: 1.2,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final primaryLabel = role == AppRole.child
        ? l10n.loginAction
        : showOtp
            ? l10n.verifyOtpAction
            : (AppConfig.useDevAuth ? l10n.loginAction : l10n.sendOtpAction);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              width: refresh ? 40 : 36,
              height: refresh ? 40 : 36,
              decoration: BoxDecoration(
                color: refresh
                    ? VisualRefreshColors.accentTint
                    : AppColors.sky.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(refresh ? 12 : 10),
              ),
              child: Icon(
                Icons.lock_outline_rounded,
                color: refresh
                    ? VisualRefreshColors.accent
                    : AppColors.tealDeep,
                size: refresh ? 22 : 20,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              l10n.loginTitle,
              style: refresh
                  ? GoogleFonts.fraunces(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: VisualRefreshColors.textPrimary,
                    )
                  : Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: AppColors.tealDeep,
                        fontWeight: FontWeight.w900,
                      ),
            ),
          ],
        ),
        SizedBox(height: refresh ? 24 : 22),
        if (!showOtp) ...[
          _LoginField(
            refresh: refresh,
            label: l10n.nameLabel,
            child: TextField(
              controller: nameCtrl,
              textCapitalization: TextCapitalization.words,
              style: refresh
                  ? GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: VisualRefreshColors.textPrimary,
                    )
                  : null,
              decoration: _fieldDecoration(hint: l10n.nameHint),
            ),
          ),
          const SizedBox(height: 16),
          if (role == AppRole.child)
            _LoginField(
              refresh: refresh,
              label: l10n.inviteCodeLabel,
              helper: Row(
                children: [
                  Icon(
                    Icons.info_outline_rounded,
                    size: 15,
                    color: refresh
                        ? VisualRefreshColors.accent
                        : AppColors.amber.withValues(alpha: 0.95),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      l10n.inviteCodeHintChild,
                      style: refresh
                          ? GoogleFonts.plusJakartaSans(
                              color: VisualRefreshColors.textSecondary,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              height: 1.35,
                            )
                          : Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.inkSoft,
                                fontSize: 13,
                              ),
                    ),
                  ),
                ],
              ),
              child: TextField(
                controller: inviteCtrl,
                textCapitalization: TextCapitalization.characters,
                style: refresh
                    ? GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: VisualRefreshColors.textPrimary,
                      )
                    : null,
                decoration: _fieldDecoration(hint: l10n.inviteCodeLabel),
              ),
            )
          else
            _LoginField(
              refresh: refresh,
              label: l10n.phoneLabel,
              child: TextField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                style: refresh
                    ? GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: VisualRefreshColors.textPrimary,
                      )
                    : null,
                decoration: _fieldDecoration(hint: l10n.phoneHint),
              ),
            ),
          SizedBox(height: refresh ? 18 : 20),
          if (refresh)
            _LoginField(
              refresh: true,
              label: l10n.roleLabel,
              child: _RoleSelector(
                refresh: true,
                selected: role,
                onChanged: onRoleChanged,
              ),
            )
          else ...[
            Text(
              l10n.roleLabel,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            _RoleSelector(
              refresh: false,
              selected: role,
              onChanged: onRoleChanged,
            ),
          ],
        ] else ...[
          Text(
            l10n.otpSentHint,
            style: refresh
                ? GoogleFonts.plusJakartaSans(
                    color: VisualRefreshColors.textSecondary,
                    height: 1.35,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  )
                : Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                      height: 1.35,
                    ),
          ),
          const SizedBox(height: 8),
          Text(
            phoneCtrl.text.trim(),
            style: refresh
                ? GoogleFonts.plusJakartaSans(
                    color: VisualRefreshColors.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 17,
                  )
                : Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.tealDeep,
                      fontWeight: FontWeight.w800,
                    ),
          ),
          const SizedBox(height: 16),
          _LoginField(
            refresh: refresh,
            label: l10n.otpLabel,
            child: TextField(
              controller: otpCtrl,
              keyboardType: TextInputType.number,
              maxLength: 6,
              style: refresh
                  ? GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: VisualRefreshColors.textPrimary,
                    )
                  : null,
              decoration: _fieldDecoration(
                hint: l10n.otpHint,
                counterHidden: true,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              TextButton(
                onPressed: loading ? null : onResendOtp,
                style: refresh
                    ? TextButton.styleFrom(
                        foregroundColor: VisualRefreshColors.accent,
                      )
                    : null,
                child: Text(l10n.resendOtp),
              ),
              TextButton(
                onPressed: loading ? null : onChangeNumber,
                style: refresh
                    ? TextButton.styleFrom(
                        foregroundColor: VisualRefreshColors.accent,
                      )
                    : null,
                child: Text(l10n.changeNumber),
              ),
            ],
          ),
        ],
        if (error != null) ...[
          const SizedBox(height: 14),
          Text(
            error!,
            style: TextStyle(
              color: refresh ? VisualRefreshColors.danger : AppColors.danger,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
        if (loading && showOtp) ...[
          const SizedBox(height: 12),
          Text(
            l10n.otpVerifyingHint,
            style: refresh
                ? GoogleFonts.plusJakartaSans(
                    color: VisualRefreshColors.textSecondary,
                    height: 1.35,
                    fontSize: 13,
                  )
                : Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      height: 1.35,
                    ),
          ),
        ],
        if (loading && !showOtp) ...[
          const SizedBox(height: 12),
          Text(
            l10n.otpSendingHint,
            style: refresh
                ? GoogleFonts.plusJakartaSans(
                    color: VisualRefreshColors.textSecondary,
                    height: 1.35,
                    fontSize: 13,
                  )
                : Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                      height: 1.35,
                    ),
          ),
        ],
        SizedBox(height: refresh ? 24 : 22),
        FilledButton(
          onPressed: loading ? null : onSubmit,
          style: FilledButton.styleFrom(
            backgroundColor:
                refresh ? VisualRefreshColors.anchor : AppColors.teal,
            disabledBackgroundColor: (refresh
                    ? VisualRefreshColors.anchor
                    : AppColors.teal)
                .withValues(alpha: 0.5),
            foregroundColor:
                refresh ? VisualRefreshColors.background : Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(refresh ? AppRadius.pill : 18),
            ),
            elevation: 0,
          ),
          child: Text(
            loading
                ? (showOtp ? l10n.connecting : l10n.sending)
                : primaryLabel,
            style: refresh
                ? GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  )
                : const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
          ),
        ),
      ],
    );

    if (refresh) return body;

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDeep.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: body,
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.refresh,
    required this.label,
    this.helper,
    required this.child,
  });

  final bool refresh;
  final String label;
  final Widget child;
  final Widget? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          refresh ? label.toUpperCase() : label,
          style: refresh
              ? GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                  color: VisualRefreshColors.textTertiary,
                )
              : Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w800,
                  ),
        ),
        const SizedBox(height: 8),
        child,
        if (helper != null) ...[
          const SizedBox(height: 8),
          helper!,
        ],
      ],
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.refresh,
    required this.selected,
    required this.onChanged,
  });

  final bool refresh;
  final AppRole selected;
  final ValueChanged<AppRole> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final options = [
      (AppRole.parent, l10n.roleParentShort),
      (AppRole.child, l10n.roleChildShort),
      (AppRole.guardian, l10n.roleGuardianShort),
    ];
    return Container(
      padding: EdgeInsets.all(refresh ? 4 : 5),
      decoration: BoxDecoration(
        color: refresh
            ? VisualRefreshColors.tagMuted
            : const Color(0xFFF0F3F2),
        borderRadius: BorderRadius.circular(refresh ? 999 : 18),
        border: refresh
            ? Border.all(color: VisualRefreshColors.border, width: 0.5)
            : null,
      ),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) SizedBox(width: refresh ? 2 : 4),
            Expanded(
              child: _RoleOption(
                refresh: refresh,
                label: options[i].$2,
                selected: selected == options[i].$1,
                onTap: () => onChanged(options[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.refresh,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final bool refresh;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (refresh) {
      return Material(
        color: selected ? VisualRefreshColors.accentTint : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(999),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (selected) ...[
                  const Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: VisualRefreshColors.accent,
                  ),
                  const SizedBox(width: 4),
                ],
                Flexible(
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? VisualRefreshColors.accent
                          : VisualRefreshColors.textSecondary,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.tealDeep.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected ? AppColors.tealDeep : AppColors.inkSoft,
                    height: 1.2,
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
