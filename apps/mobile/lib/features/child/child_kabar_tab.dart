import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

class ChildMessagePreset {
  const ChildMessagePreset({
    required this.id,
    required this.label,
    required this.text,
    required this.icon,
    required this.color,
    required this.subtitle,
  });

  final String id;
  final String label;
  final String text;
  final String subtitle;
  final IconData icon;
  final Color color;

  bool get isUrgent => id == 'need_help';
}

List<ChildMessagePreset> childMessagePresets(AppLocalizations l10n) => [
      ChildMessagePreset(
        id: 'at_school',
        label: l10n.presetAtSchoolLabel,
        text: l10n.presetAtSchoolText,
        subtitle: l10n.presetAtSchoolSubtitle,
        icon: Icons.school_rounded,
        color: const Color(0xFF0A8F7A),
      ),
      ChildMessagePreset(
        id: 'at_home',
        label: l10n.presetAtHomeLabel,
        text: l10n.presetAtHomeText,
        subtitle: l10n.presetAtHomeSubtitle,
        icon: Icons.home_rounded,
        color: const Color(0xFF249B72),
      ),
      ChildMessagePreset(
        id: 'need_help',
        label: l10n.presetNeedHelpLabel,
        text: l10n.presetNeedHelpText,
        subtitle: l10n.presetNeedHelpSubtitle,
        icon: Icons.support_agent_rounded,
        color: const Color(0xFFFF746C),
      ),
    ];

class ChildKabarTab extends StatelessWidget {
  const ChildKabarTab({
    super.key,
    required this.sendingPresetId,
    required this.onSendPreset,
  });

  final String? sendingPresetId;
  final Future<void> Function(ChildMessagePreset preset) onSendPreset;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        Text(
          l10n.kabarTitle,
          style: refresh
              ? GoogleFonts.fraunces(
                  fontSize: 28,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.5,
                  color: VisualRefreshColors.textPrimary,
                  height: 1.15,
                )
              : Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.5,
                  ),
        ),
        const SizedBox(height: 4),
        Text(
          l10n.kabarSubtitle,
          style: refresh
              ? GoogleFonts.plusJakartaSans(
                  color: VisualRefreshColors.textSecondary,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                )
              : Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkSoft,
                  ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _KabarHero(),
        const SizedBox(height: AppSpacing.lg),
        ...childMessagePresets(l10n).map(
          (preset) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _PresetCard(
              preset: preset,
              loading: sendingPresetId == preset.id,
              disabled: sendingPresetId != null && sendingPresetId != preset.id,
              onPressed: () => onSendPreset(preset),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _KabarInfoNote(text: l10n.kabarInfoNote),
      ],
    );
  }
}

class _KabarHero extends StatelessWidget {
  const _KabarHero();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: refresh ? VisualRefreshColors.praiseBtn : null,
        gradient: refresh
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFFF8A7A), Color(0xFFFFC857)],
              ),
        borderRadius: BorderRadius.circular(refresh ? AppRadius.vrHero : 28),
        boxShadow: refresh
            ? null
            : [
                BoxShadow(
                  color: AppColors.coral.withValues(alpha: 0.28),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.kabarHeroTitle,
                  style: refresh
                      ? GoogleFonts.fraunces(
                          color: VisualRefreshColors.anchor,
                          fontWeight: FontWeight.w600,
                          fontSize: 22,
                          height: 1.2,
                        )
                      : Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                          ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.kabarHeroSubtitle,
                  style: refresh
                      ? GoogleFonts.plusJakartaSans(
                          color: VisualRefreshColors.anchor
                              .withValues(alpha: 0.78),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                          fontSize: 14,
                        )
                      : TextStyle(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w600,
                          height: 1.35,
                        ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: refresh
                  ? Colors.white.withValues(alpha: 0.35)
                  : Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_rounded,
              color: refresh ? VisualRefreshColors.anchor : Colors.white,
              size: 30,
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({
    required this.preset,
    required this.loading,
    required this.disabled,
    required this.onPressed,
  });

  final ChildMessagePreset preset;
  final bool loading;
  final bool disabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    final dimmed = disabled && !loading;

    final Color iconSquareBg;
    final Color sendBg;
    final Color sendIcon;
    final Color borderColor;

    if (refresh) {
      if (preset.isUrgent) {
        iconSquareBg = VisualRefreshColors.danger;
        sendBg = VisualRefreshColors.dangerTint;
        sendIcon = VisualRefreshColors.danger;
        borderColor = VisualRefreshColors.border;
      } else {
        iconSquareBg = VisualRefreshColors.accent;
        sendBg = VisualRefreshColors.accentTint;
        sendIcon = VisualRefreshColors.accent;
        borderColor = VisualRefreshColors.border;
      }
    } else {
      iconSquareBg = preset.color;
      sendBg = preset.color.withValues(alpha: 0.12);
      sendIcon = preset.color;
      borderColor = preset.color.withValues(alpha: 0.22);
    }

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: dimmed ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(
            refresh ? AppRadius.vrCard : 24,
          ),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(
                refresh ? AppRadius.vrCard : 24,
              ),
              border: Border.all(
                color: borderColor,
                width: refresh ? 0.5 : 1.5,
              ),
              boxShadow: refresh
                  ? null
                  : [
                      BoxShadow(
                        color: preset.color.withValues(alpha: 0.1),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
            ),
            child: Row(
              children: [
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    color: refresh ? iconSquareBg : null,
                    gradient: refresh
                        ? null
                        : LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              preset.color,
                              preset.color.withValues(alpha: 0.75),
                            ],
                          ),
                    borderRadius: BorderRadius.circular(
                      refresh ? AppRadius.vrChip : 18,
                    ),
                  ),
                  child: loading
                      ? const Padding(
                          padding: EdgeInsets.all(16),
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : Icon(preset.icon, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        preset.label,
                        style: refresh
                            ? GoogleFonts.plusJakartaSans(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                color: VisualRefreshColors.textPrimary,
                              )
                            : Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        preset.subtitle,
                        style: refresh
                            ? GoogleFonts.plusJakartaSans(
                                color: VisualRefreshColors.textSecondary,
                                fontWeight: FontWeight.w500,
                                height: 1.3,
                                fontSize: 13,
                              )
                            : Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppColors.inkSoft,
                                  height: 1.3,
                                ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: sendBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: sendIcon,
                    size: 18,
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

class _KabarInfoNote extends StatelessWidget {
  const _KabarInfoNote({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: refresh
            ? VisualRefreshColors.routeTint
            : AppColors.sand.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(
          refresh ? AppRadius.vrCard : 20,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (refresh)
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(
                Icons.info_outline_rounded,
                color: VisualRefreshColors.routeText,
                size: 20,
              ),
            )
          else
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.info_outline_rounded,
                color: AppColors.teal,
                size: 20,
              ),
            ),
          SizedBox(width: refresh ? 10 : 12),
          Expanded(
            child: Text(
              text,
              style: refresh
                  ? GoogleFonts.plusJakartaSans(
                      color: VisualRefreshColors.routeText,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                      fontSize: 13.5,
                    )
                  : Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                        height: 1.4,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}
