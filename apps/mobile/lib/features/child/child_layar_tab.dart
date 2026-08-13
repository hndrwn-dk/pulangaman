import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import 'child_usage_utils.dart';

class ChildLayarTab extends StatelessWidget {
  const ChildLayarTab({
    super.key,
    required this.usageAccess,
    required this.period,
    required this.apps,
    required this.loading,
    required this.onPeriodChanged,
    required this.onRefresh,
    required this.onOpenUsageSettings,
  });

  final bool usageAccess;
  final UsagePeriod period;
  final List<UsageAppEntry> apps;
  final bool loading;
  final ValueChanged<UsagePeriod> onPeriodChanged;
  final VoidCallback onRefresh;
  final VoidCallback onOpenUsageSettings;

  int get totalSeconds =>
      apps.fold(0, (sum, app) => sum + app.durationSeconds);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    if (!usageAccess) {
      return ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _PermissionGate(onOpenUsageSettings: onOpenUsageSettings),
        ],
      );
    }

    final maxSeconds = apps.isEmpty ? 1 : apps.first.durationSeconds;

    return RefreshIndicator(
      color: refresh ? VisualRefreshColors.accent : AppColors.teal,
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.xl,
        ),
        children: [
          Text(
            l10n.screenTimeTitle,
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
            l10n.screenTimeSubtitle,
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
          const SizedBox(height: AppSpacing.md),
          _PeriodChips(period: period, onChanged: onPeriodChanged),
          const SizedBox(height: AppSpacing.lg),
          _HeroUsageCard(
            totalSeconds: totalSeconds,
            period: period,
            loading: loading,
            appCount: apps.length,
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Text(
                refresh
                    ? l10n.appsLabel.toUpperCase()
                    : l10n.appsLabel,
                style: refresh
                    ? GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                        letterSpacing: 0.8,
                        color: VisualRefreshColors.textSecondary,
                      )
                    : Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
              ),
              const Spacer(),
              if (!loading && apps.isNotEmpty)
                Text(
                  l10n.appCountLabel(apps.length),
                  style: refresh
                      ? GoogleFonts.plusJakartaSans(
                          color: VisualRefreshColors.textSecondary,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        )
                      : Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: AppColors.inkSoft,
                            fontWeight: FontWeight.w700,
                          ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (loading)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Center(
                child: CircularProgressIndicator(
                  color: refresh
                      ? VisualRefreshColors.accent
                      : AppColors.teal,
                ),
              ),
            )
          else if (apps.isEmpty)
            const _EmptyUsage()
          else
            ...apps.asMap().entries.map(
                  (entry) => _AppUsageRow(
                    app: entry.value,
                    rank: entry.key + 1,
                    maxSeconds: maxSeconds,
                  ),
                ),
        ],
      ),
    );
  }
}

class _PermissionGate extends StatelessWidget {
  const _PermissionGate({required this.onOpenUsageSettings});

  final VoidCallback onOpenUsageSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: refresh ? VisualRefreshColors.accentTint : null,
        gradient: refresh
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFFE8F8F2), Color(0xFFFFF1D6)],
              ),
        borderRadius: BorderRadius.circular(refresh ? AppRadius.vrHero : 28),
        border: refresh
            ? Border.all(color: VisualRefreshColors.border, width: 0.5)
            : null,
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: refresh
                  ? VisualRefreshColors.surface
                  : Colors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.hourglass_disabled_rounded,
              size: 36,
              color: refresh ? VisualRefreshColors.accent : AppColors.teal,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            l10n.usageAccessInactiveTitle,
            textAlign: TextAlign.center,
            style: refresh
                ? GoogleFonts.fraunces(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: VisualRefreshColors.textPrimary,
                  )
                : Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.usageAccessInactiveBody,
            textAlign: TextAlign.center,
            style: refresh
                ? GoogleFonts.plusJakartaSans(
                    color: VisualRefreshColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    height: 1.4,
                  )
                : Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.inkSoft,
                    ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onOpenUsageSettings,
              style: refresh
                  ? FilledButton.styleFrom(
                      backgroundColor: VisualRefreshColors.anchor,
                      foregroundColor: VisualRefreshColors.background,
                      elevation: 0,
                    )
                  : null,
              child: Text(l10n.openPermissionSettings),
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodChips extends StatelessWidget {
  const _PeriodChips({
    required this.period,
    required this.onChanged,
  });

  final UsagePeriod period;
  final ValueChanged<UsagePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: refresh ? VisualRefreshColors.tagMuted : Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: refresh
            ? null
            : Border.all(color: const Color(0x14075A4F)),
      ),
      child: Row(
        children: UsagePeriod.values.map((p) {
          final selected = p == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: Semantics(
                button: true,
                selected: selected,
                label: p.shortLabel(l10n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? (refresh
                            ? VisualRefreshColors.anchor
                            : AppColors.teal)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    p.shortLabel(l10n),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                      color: selected
                          ? (refresh
                              ? VisualRefreshColors.background
                              : Colors.white)
                          : (refresh
                              ? VisualRefreshColors.textSecondary
                              : AppColors.inkSoft),
                      fontFamily: refresh
                          ? GoogleFonts.plusJakartaSans().fontFamily
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _HeroUsageCard extends StatelessWidget {
  const _HeroUsageCard({
    required this.totalSeconds,
    required this.period,
    required this.loading,
    required this.appCount,
  });

  final int totalSeconds;
  final UsagePeriod period;
  final bool loading;
  final int appCount;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    const dailyGoalSeconds = 2 * 3600;
    final goal = switch (period) {
      UsagePeriod.today => dailyGoalSeconds,
      UsagePeriod.week => dailyGoalSeconds * 7,
      UsagePeriod.month => dailyGoalSeconds * 30,
    };
    final overTarget = !loading && totalSeconds >= goal;
    final progress = (totalSeconds / goal).clamp(0.0, 1.0);
    final ringColor = refresh
        ? (overTarget
            ? VisualRefreshColors.danger
            : VisualRefreshColors.accent)
        : AppColors.amber;
    final periodLabel = period.label(l10n);
    final statusLabel = refresh && overTarget
        ? l10n.screenTimeOverTargetStatus(periodLabel)
        : periodLabel;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        color: refresh ? VisualRefreshColors.anchor : null,
        gradient: refresh
            ? null
            : const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF0A8F7A), Color(0xFF07584E)],
              ),
        borderRadius: BorderRadius.circular(refresh ? AppRadius.vrHero : 28),
        boxShadow: refresh
            ? null
            : [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.28),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
      ),
      child: Column(
        children: [
          SizedBox(
            width: 148,
            height: 148,
            child: Semantics(
              label: loading
                  ? l10n.screenTimeRingLoading
                  : l10n.screenTimeRingSummary(
                      formatDurationCompact(totalSeconds),
                      statusLabel,
                    ),
              child: ExcludeSemantics(
                child: CustomPaint(
                  painter: _RingPainter(
                    progress: loading ? 0 : progress,
                    trackColor: Colors.white.withValues(alpha: 0.18),
                    progressColor: ringColor,
                    strokeWidth: 12,
                  ),
                  child: Center(
                    child: loading
                        ? const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: Colors.white,
                            ),
                          )
                        : Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                formatDurationCompact(totalSeconds),
                                textAlign: TextAlign.center,
                                style: refresh
                                    ? GoogleFonts.fraunces(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 28,
                                        height: 1.05,
                                        letterSpacing: -0.8,
                                      )
                                    : const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 28,
                                        height: 1.05,
                                        letterSpacing: -0.8,
                                      ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                statusLabel,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
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
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: l10n.totalLabel,
                  value: loading ? '...' : formatDuration(l10n, totalSeconds),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _HeroStat(
                  label: l10n.appsLabel,
                  value: loading ? '...' : '$appCount',
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _HeroStat(
                  label: l10n.targetLabel,
                  value: formatDurationCompact(goal),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroStat extends StatelessWidget {
  const _HeroStat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final refresh = visualRefreshOf(context);
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
            fontFamily: refresh
                ? GoogleFonts.plusJakartaSans().fontFamily
                : null,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 11,
            fontWeight: FontWeight.w600,
            fontFamily: refresh
                ? GoogleFonts.plusJakartaSans().fontFamily
                : null,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, track);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      2 * math.pi * progress,
      false,
      fill,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

class _EmptyUsage extends StatelessWidget {
  const _EmptyUsage();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: refresh
            ? VisualRefreshColors.warmTint
            : AppColors.sand.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(refresh ? AppRadius.vrCard : 24),
        border: refresh
            ? Border.all(color: VisualRefreshColors.border, width: 0.5)
            : null,
      ),
      child: Column(
        children: [
          Icon(
            Icons.phone_android_rounded,
            size: 40,
            color: refresh ? VisualRefreshColors.accent : AppColors.teal,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.noDataYet,
            style: refresh
                ? GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    color: VisualRefreshColors.textPrimary,
                  )
                : Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.useAsUsualStatsAppear,
            textAlign: TextAlign.center,
            style: refresh
                ? GoogleFonts.plusJakartaSans(
                    color: VisualRefreshColors.textSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  )
                : Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.inkSoft,
                    ),
          ),
        ],
      ),
    );
  }
}

class _AppUsageRow extends StatelessWidget {
  const _AppUsageRow({
    required this.app,
    required this.rank,
    required this.maxSeconds,
  });

  final UsageAppEntry app;
  final int rank;
  final int maxSeconds;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final refresh = visualRefreshOf(context);
    final fraction = maxSeconds > 0 ? app.durationSeconds / maxSeconds : 0.0;
    final name = friendlyAppName(app.packageName, appLabel: app.appLabel);
    final classicAccent = appAccentForPackage(app.packageName);
    final icon = appIconForPackage(app.packageName);
    final iconBg = refresh
        ? VisualRefreshColors.accentTint
        : classicAccent.withValues(alpha: 0.14);
    final iconColor =
        refresh ? VisualRefreshColors.accent : classicAccent;
    final barColor =
        refresh ? VisualRefreshColors.anchor : classicAccent;
    final timeColor =
        refresh ? VisualRefreshColors.accent : classicAccent;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(
            refresh ? AppRadius.vrCard : 20,
          ),
          border: Border.all(
            color: refresh
                ? VisualRefreshColors.border
                : const Color(0x10075A4F),
            width: refresh ? 0.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(
                      refresh ? AppRadius.vrChip : 14,
                    ),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: refresh
                          ? VisualRefreshColors.tagMuted
                          : (rank <= 3
                              ? AppColors.amber
                              : AppColors.mint),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: refresh
                            ? VisualRefreshColors.textSecondary
                            : (rank <= 3
                                ? AppColors.ink
                                : AppColors.tealDeep),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: refresh
                                ? VisualRefreshColors.textPrimary
                                : null,
                            fontFamily: refresh
                                ? GoogleFonts.plusJakartaSans().fontFamily
                                : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formatDuration(l10n, app.durationSeconds),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: timeColor,
                          fontSize: 13,
                          fontFamily: refresh
                              ? GoogleFonts.plusJakartaSans().fontFamily
                              : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0.04, 1.0),
                      minHeight: refresh ? 6 : 7,
                      backgroundColor: refresh
                          ? VisualRefreshColors.tagMuted
                          : classicAccent.withValues(alpha: 0.12),
                      color: barColor,
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
