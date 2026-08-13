import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/day_period.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
import '../../l10n/app_localizations.dart';
import 'child_usage_utils.dart';

class ChildBerandaTab extends StatelessWidget {
  const ChildBerandaTab({
    super.key,
    required this.childName,
    required this.tracking,
    required this.points,
    required this.streak,
    required this.usageAccess,
    required this.accessibility,
    required this.todayUsageSeconds,
    required this.status,
    required this.panicInFlight,
    required this.panicOnCooldown,
    this.panicActive = false,
    required this.reminderCount,
    required this.exactAlarmOk,
    required this.onPanicTap,
    this.onPanicHoldComplete,
    required this.onOpenUsageSettings,
    required this.onOpenAccessibilitySettings,
    required this.onOpenReminderPermissions,
    required this.onOpenScreenTab,
    required this.onOpenRewards,
    required this.onOpenRemindersSheet,
    required this.onOpenScreenPermissionSetup,
    this.onOpenAppInfo,
    this.homeByAckVisible = false,
    this.homeByAckSent = false,
    this.onHomeByAck,
    this.tripActive = false,
    this.tripArrived = false,
    this.tripToLabel,
    this.tripProgress = 0,
    this.onStartTrip,
    this.onCancelTrip,
    this.onArriveTrip,
    this.empConfigured = false,
    this.empActive = false,
    this.empPlaceName,
    this.empNote,
    this.onOpenEmp,
  });

  final String childName;
  final bool tracking;
  final int points;
  final int streak;
  final bool usageAccess;
  final bool accessibility;
  final int todayUsageSeconds;
  final String? status;
  final bool panicInFlight;
  final bool panicOnCooldown;
  final bool panicActive;
  final int reminderCount;
  final bool exactAlarmOk;
  final VoidCallback onPanicTap;
  /// Visual Refresh: press-and-hold completed — fires the same panic cascade.
  final VoidCallback? onPanicHoldComplete;
  final VoidCallback onOpenUsageSettings;
  final VoidCallback onOpenAccessibilitySettings;
  final VoidCallback onOpenReminderPermissions;
  final VoidCallback onOpenScreenTab;
  final VoidCallback onOpenRewards;
  final VoidCallback onOpenRemindersSheet;
  final VoidCallback onOpenScreenPermissionSetup;
  final VoidCallback? onOpenAppInfo;
  final bool homeByAckVisible;
  final bool homeByAckSent;
  final VoidCallback? onHomeByAck;
  final bool tripActive;
  final bool tripArrived;
  final String? tripToLabel;
  final double tripProgress;
  final VoidCallback? onStartTrip;
  final VoidCallback? onCancelTrip;
  final VoidCallback? onArriveTrip;
  /// Parent has saved a meeting point for this child (show even when not activated).
  final bool empConfigured;
  final bool empActive;
  final String? empPlaceName;
  final String? empNote;
  final VoidCallback? onOpenEmp;

  String _timeGreeting(AppLocalizations l10n) =>
      dayPeriodFor().shortLabel(l10n);

  @override
  Widget build(BuildContext context) {
    if (visualRefreshOf(context)) {
      return _buildVisualRefresh(context);
    }
    return _buildClassic(context);
  }

  Widget _buildClassic(BuildContext context) {
    final period = dayPeriodFor();
    final l10n = AppLocalizations.of(context);
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: period.accent.withValues(alpha: 0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(period.icon, color: period.accent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${_timeGreeting(l10n)}, $childName!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(l10n.homeSubtitleTagline),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PaStatusPill(
              label: tracking ? l10n.pillLocationOn : l10n.pillLocationOff,
              icon: tracking ? Icons.location_on : Icons.location_off,
              color: tracking ? AppColors.success : AppColors.danger,
            ),
            GestureDetector(
              onTap: usageAccess && accessibility
                  ? null
                  : onOpenScreenPermissionSetup,
              child: Semantics(
                button: !(usageAccess && accessibility),
                hint: (usageAccess && accessibility)
                    ? null
                    : l10n.screenPermissionIncompleteHint,
                child: PaStatusPill(
                  label: usageAccess && accessibility
                      ? l10n.screenRulesActive
                      : l10n.screenPermissionIncomplete,
                  icon: Icons.hourglass_bottom,
                  color: usageAccess && accessibility
                      ? AppColors.lavender
                      : AppColors.amber,
                ),
              ),
            ),
            if (!exactAlarmOk)
              GestureDetector(
                onTap: onOpenReminderPermissions,
                child: Semantics(
                  button: true,
                  hint: l10n.alarmPermissionIncompleteHint,
                  child: PaStatusPill(
                    label: l10n.alarmPermissionIncomplete,
                    icon: Icons.alarm_rounded,
                    color: AppColors.amber,
                  ),
                ),
              )
            else if (reminderCount > 0)
              GestureDetector(
                onTap: onOpenRemindersSheet,
                child: Semantics(
                  button: true,
                  hint: l10n.reminderActiveHint,
                  child: PaStatusPill(
                    label: l10n.reminderActiveCount(reminderCount),
                    icon: Icons.alarm_rounded,
                    color: AppColors.sky,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _QuickStatsRow(
          todayUsageSeconds: todayUsageSeconds,
          points: points,
          streak: streak,
          refresh: false,
          onOpenScreenTab: onOpenScreenTab,
          onOpenRewards: onOpenRewards,
        ),
        if (empConfigured || empActive) ...[
          const SizedBox(height: AppSpacing.md),
          _EmpKnowYourPointCard(
            active: empActive,
            placeName: empPlaceName ?? l10n.empDefaultPlaceName,
            note: empNote,
            onOpen: onOpenEmp,
            refresh: false,
          ),
        ],
        if (homeByAckVisible || homeByAckSent) ...[
          const SizedBox(height: AppSpacing.md),
          PaSectionCard(
            color: AppColors.teal.withValues(alpha: 0.12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  homeByAckSent
                      ? l10n.homeByChildAckSent
                      : l10n.homeByChildAckButton,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                if (!homeByAckSent) ...[
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: onHomeByAck,
                    child: Text(l10n.homeByChildAckTitle),
                  ),
                ],
              ],
            ),
          ),
        ],
        if (tripActive || tripArrived || onStartTrip != null) ...[
          const SizedBox(height: AppSpacing.md),
          _TripActionCard(
            active: tripActive,
            arrived: tripArrived,
            toLabel: tripToLabel,
            progress: tripProgress,
            onStart: onStartTrip,
            onCancel: onCancelTrip,
            onArrive: onArriveTrip,
            refresh: false,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        PaSectionCard(
          color: AppColors.coral.withValues(alpha: 0.12),
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: FilledButton(
                  onPressed:
                      (panicInFlight || panicOnCooldown) ? null : onPanicTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    shape: const CircleBorder(),
                  ),
                  child: Text(
                    l10n.panicButton,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ),
              Text(l10n.panicConfirm, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(
                panicInFlight
                    ? l10n.sendingAlert
                    : panicOnCooldown
                        ? l10n.panicCooldownMessage
                        : panicActive
                            ? l10n.panicModeActiveWaiting
                            : (status ?? ''),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: panicActive || panicOnCooldown
                      ? AppColors.danger
                      : AppColors.inkSoft,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!usageAccess || !accessibility) ...[
          const SizedBox(height: AppSpacing.md),
          PaSectionCard(
            color: AppColors.lavender.withValues(alpha: 0.16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.enableScreenProtectionTitle,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                Text(l10n.neverBlockedAppsNote),
                const SizedBox(height: 10),
                if (!usageAccess)
                  OutlinedButton(
                    onPressed: onOpenUsageSettings,
                    child: Text(l10n.allowUsageAccess),
                  ),
                if (!accessibility) ...[
                  OutlinedButton(
                    onPressed: onOpenAccessibilitySettings,
                    child: Text(l10n.enableAppBlocking),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.restrictedSettingsHelp,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: AppColors.inkSoft,
                    ),
                  ),
                  if (onOpenAppInfo != null) ...[
                    const SizedBox(height: 6),
                    TextButton(
                      onPressed: onOpenAppInfo,
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.tealDeep,
                      ),
                      child: Text(
                        l10n.openAppInfo,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildVisualRefresh(BuildContext context) {
    final period = dayPeriodFor();
    final l10n = AppLocalizations.of(context);
    final jakarta = GoogleFonts.plusJakartaSans().fontFamily;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: period.accent.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(period.icon, color: period.accent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_timeGreeting(l10n)}, $childName!',
                    style: GoogleFonts.fraunces(
                      fontSize: 28,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -0.4,
                      height: 1.15,
                      color: VisualRefreshColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.homeSubtitleTagline,
                    style: TextStyle(
                      fontFamily: jakarta,
                      fontSize: 13.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: VisualRefreshColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _VrStatusPill(
              label: tracking ? l10n.pillLocationOn : l10n.pillLocationOff,
              icon: tracking ? Icons.location_on : Icons.location_off,
            ),
            if (!(usageAccess && accessibility))
              _VrStatusPill(
                label: l10n.screenPermissionIncomplete,
                icon: Icons.hourglass_bottom,
                warning: true,
                showChevron: true,
                hint: l10n.screenPermissionIncompleteHint,
                onTap: onOpenScreenPermissionSetup,
              )
            else
              _VrStatusPill(
                label: l10n.screenRulesActive,
                icon: Icons.hourglass_bottom,
              ),
            if (!exactAlarmOk)
              _VrStatusPill(
                label: l10n.alarmPermissionIncomplete,
                icon: Icons.alarm_rounded,
                warning: true,
                showChevron: true,
                hint: l10n.alarmPermissionIncompleteHint,
                onTap: onOpenReminderPermissions,
              )
            else if (reminderCount > 0)
              _VrStatusPill(
                label: l10n.reminderActiveCount(reminderCount),
                icon: Icons.alarm_rounded,
                showChevron: true,
                hint: l10n.reminderActiveHint,
                onTap: onOpenRemindersSheet,
              ),
          ],
        ),
        const SizedBox(height: 16),
        _QuickStatsRow(
          todayUsageSeconds: todayUsageSeconds,
          points: points,
          streak: streak,
          refresh: true,
          onOpenScreenTab: onOpenScreenTab,
          onOpenRewards: onOpenRewards,
        ),
        if (empConfigured || empActive) ...[
          const SizedBox(height: 14),
          _EmpKnowYourPointCard(
            active: empActive,
            placeName: empPlaceName ?? l10n.empDefaultPlaceName,
            note: empNote,
            onOpen: onOpenEmp,
            refresh: true,
          ),
        ],
        if (homeByAckVisible || homeByAckSent) ...[
          const SizedBox(height: 14),
          Material(
            color: VisualRefreshColors.accentTint,
            borderRadius: BorderRadius.circular(AppRadius.vrCard),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    homeByAckSent
                        ? l10n.homeByChildAckSent
                        : l10n.homeByChildAckButton,
                    style: TextStyle(
                      fontFamily: jakarta,
                      fontWeight: FontWeight.w700,
                      color: VisualRefreshColors.accent,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  if (!homeByAckSent) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: onHomeByAck,
                      child: Text(l10n.homeByChildAckTitle),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        if (tripActive || tripArrived || onStartTrip != null) ...[
          const SizedBox(height: 14),
          _TripActionCard(
            active: tripActive,
            arrived: tripArrived,
            toLabel: tripToLabel,
            progress: tripProgress,
            onStart: onStartTrip,
            onCancel: onCancelTrip,
            onArrive: onArriveTrip,
            refresh: true,
          ),
        ],
        const SizedBox(height: 20),
        _VrPanicSection(
          enabled: !panicInFlight && !panicOnCooldown,
          panicInFlight: panicInFlight,
          panicOnCooldown: panicOnCooldown,
          panicActive: panicActive,
          status: status,
          onHoldComplete: onPanicHoldComplete ?? onPanicTap,
        ),
        if (!usageAccess || !accessibility) ...[
          const SizedBox(height: 14),
          Material(
            color: VisualRefreshColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.vrCard),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppRadius.vrCard),
                border: Border.all(
                  color: VisualRefreshColors.border,
                  width: 0.5,
                ),
              ),
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.enableScreenProtectionTitle,
                    style: TextStyle(
                      fontFamily: jakarta,
                      fontWeight: FontWeight.w800,
                      color: VisualRefreshColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.neverBlockedAppsNote,
                    style: TextStyle(
                      fontFamily: jakarta,
                      color: VisualRefreshColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (!usageAccess)
                    OutlinedButton(
                      onPressed: onOpenUsageSettings,
                      child: Text(l10n.allowUsageAccess),
                    ),
                  if (!accessibility) ...[
                    OutlinedButton(
                      onPressed: onOpenAccessibilitySettings,
                      child: Text(l10n.enableAppBlocking),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.restrictedSettingsHelp,
                      style: TextStyle(
                        fontFamily: jakarta,
                        fontSize: 12.5,
                        height: 1.4,
                        color: VisualRefreshColors.textSecondary,
                      ),
                    ),
                    if (onOpenAppInfo != null) ...[
                      const SizedBox(height: 6),
                      TextButton(
                        onPressed: onOpenAppInfo,
                        style: TextButton.styleFrom(
                          foregroundColor: VisualRefreshColors.accent,
                        ),
                        child: Text(
                          l10n.openAppInfo,
                          style: TextStyle(
                            fontFamily: jakarta,
                            fontWeight: FontWeight.w800,
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
      ],
    );
  }
}

class _VrStatusPill extends StatelessWidget {
  const _VrStatusPill({
    required this.label,
    required this.icon,
    this.warning = false,
    this.showChevron = false,
    this.hint,
    this.onTap,
  });

  final String label;
  final IconData icon;
  final bool warning;
  final bool showChevron;
  final String? hint;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final bg = warning
        ? VisualRefreshColors.routeTint
        : VisualRefreshColors.accentTint;
    final fg = warning
        ? VisualRefreshColors.routeText
        : VisualRefreshColors.accent;

    final pill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: fg),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: fg,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
          if (showChevron) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded, size: 18, color: fg),
          ],
        ],
      ),
    );

    if (onTap == null) return pill;
    return Semantics(
      button: true,
      hint: hint,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.pill),
          child: pill,
        ),
      ),
    );
  }
}

class _VrPanicSection extends StatelessWidget {
  const _VrPanicSection({
    required this.enabled,
    required this.panicInFlight,
    required this.panicOnCooldown,
    required this.panicActive,
    required this.status,
    required this.onHoldComplete,
  });

  final bool enabled;
  final bool panicInFlight;
  final bool panicOnCooldown;
  final bool panicActive;
  final String? status;
  final VoidCallback onHoldComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final jakarta = GoogleFonts.plusJakartaSans().fontFamily;
    final statusText = panicInFlight
        ? l10n.sendingAlert
        : panicOnCooldown
            ? l10n.panicCooldownMessage
            : panicActive
                ? l10n.panicModeActiveWaiting
                : (status ?? '');

    return Material(
      color: VisualRefreshColors.dangerTint,
      borderRadius: BorderRadius.circular(AppRadius.vrHero),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 24),
        child: Column(
          children: [
            _VrPanicHoldButton(
              enabled: enabled,
              label: l10n.panicButton,
              onHoldComplete: onHoldComplete,
            ),
            const SizedBox(height: 16),
            Text(
              l10n.panicHoldConfirm,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: jakarta,
                fontWeight: FontWeight.w700,
                fontSize: 14,
                color: VisualRefreshColors.danger,
              ),
            ),
            if (statusText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                statusText,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: jakarta,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                  color: panicActive || panicOnCooldown
                      ? VisualRefreshColors.dangerTintText
                      : VisualRefreshColors.dangerTintText,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Press-and-hold panic control with a filling progress ring (~3s).
class _VrPanicHoldButton extends StatefulWidget {
  const _VrPanicHoldButton({
    required this.enabled,
    required this.label,
    required this.onHoldComplete,
  });

  final bool enabled;
  final String label;
  final VoidCallback onHoldComplete;

  @override
  State<_VrPanicHoldButton> createState() => _VrPanicHoldButtonState();
}

class _VrPanicHoldButtonState extends State<_VrPanicHoldButton>
    with SingleTickerProviderStateMixin {
  static const _holdDuration = Duration(milliseconds: 3000);

  late final AnimationController _controller;
  bool _fired = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _holdDuration)
      ..addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(covariant _VrPanicHoldButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _controller.isAnimating) {
      _cancelHold();
    }
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !_fired) {
      _fired = true;
      HapticFeedback.heavyImpact();
      widget.onHoldComplete();
      _controller.reset();
      _fired = false;
    }
  }

  void _startHold() {
    if (!widget.enabled || _fired) return;
    _controller.forward(from: 0);
  }

  void _cancelHold() {
    if (_fired) return;
    _controller.stop();
    _controller.reset();
  }

  @override
  void dispose() {
    _controller.removeStatusListener(_onStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const size = 168.0;
    const ringWidth = 6.0;
    final l10n = AppLocalizations.of(context);

    return Semantics(
      button: true,
      label: widget.label,
      hint: l10n.panicHoldSemanticsHint,
      onLongPress: widget.enabled ? widget.onHoldComplete : null,
      child: Listener(
        onPointerDown: (_) => _startHold(),
        onPointerUp: (_) => _cancelHold(),
        onPointerCancel: (_) => _cancelHold(),
        child: SizedBox(
          width: size,
          height: size,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                painter: _PanicRingPainter(
                  progress: _controller.value,
                  trackColor: VisualRefreshColors.danger.withValues(alpha: 0.22),
                  progressColor: VisualRefreshColors.danger,
                  strokeWidth: ringWidth,
                ),
                child: child,
              );
            },
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Material(
                color: widget.enabled
                    ? VisualRefreshColors.danger
                    : VisualRefreshColors.danger.withValues(alpha: 0.45),
                shape: const CircleBorder(),
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                        height: 1.2,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PanicRingPainter extends CustomPainter {
  _PanicRingPainter({
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
    final radius = (size.shortestSide - strokeWidth) / 2;
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
    if (progress > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -1.57079632679, // top
        progress * 6.28318530718,
        false,
        fill,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PanicRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.progressColor != progressColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

class _EmpKnowYourPointCard extends StatelessWidget {
  const _EmpKnowYourPointCard({
    required this.active,
    required this.placeName,
    this.note,
    this.onOpen,
    this.refresh = false,
  });

  final bool active;
  final String placeName;
  final String? note;
  final VoidCallback? onOpen;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final accent = active
        ? (refresh ? VisualRefreshColors.danger : AppColors.danger)
        : (refresh ? VisualRefreshColors.accent : AppColors.tealDeep);
    final wash = active
        ? (refresh
            ? VisualRefreshColors.dangerTint
            : const Color(0xFFFFE8E6))
        : (refresh
            ? VisualRefreshColors.accentTint
            : AppColors.teal.withValues(alpha: 0.10));
    final border = refresh
        ? (active
            ? VisualRefreshColors.dangerTintBorder
            : VisualRefreshColors.border)
        : (active
            ? AppColors.danger.withValues(alpha: 0.35)
            : const Color(0xFFE2E6EA));
    final jakarta = GoogleFonts.plusJakartaSans().fontFamily;

    return Material(
      color: refresh ? VisualRefreshColors.surface : Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(
              color: border,
              width: refresh ? 0.5 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(width: 4, color: accent),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 10, 12),
                    child: Row(
                      children: [
                        Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: wash,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            active
                                ? Icons.notifications_active_rounded
                                : Icons.place_outlined,
                            color: accent,
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                active
                                    ? l10n.empActiveNowLabel
                                    : l10n.empFamilyMeetingPoint,
                                style: TextStyle(
                                  fontFamily: refresh ? jakarta : null,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                  color: accent,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                placeName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: refresh ? jakarta : null,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                  color: refresh
                                      ? VisualRefreshColors.textPrimary
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                active
                                    ? ((note != null && note!.trim().isNotEmpty)
                                        ? note!.trim()
                                        : l10n.followParentInstructions)
                                    : l10n.memorizeEmpPlace,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: refresh ? jakarta : null,
                                  color: refresh
                                      ? VisualRefreshColors.textSecondary
                                      : AppColors.inkSoft,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (onOpen != null)
                          Icon(
                            Icons.chevron_right_rounded,
                            color: refresh
                                ? VisualRefreshColors.textSecondary
                                : AppColors.inkSoft.withValues(alpha: 0.8),
                          ),
                      ],
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

/// Compact trip control — one row when idle, slim progress when active.
class _TripActionCard extends StatelessWidget {
  const _TripActionCard({
    required this.active,
    required this.arrived,
    this.toLabel,
    required this.progress,
    this.onStart,
    this.onCancel,
    this.onArrive,
    this.refresh = false,
  });

  final bool active;
  final bool arrived;
  final String? toLabel;
  final double progress;
  final VoidCallback? onStart;
  final VoidCallback? onCancel;
  final VoidCallback? onArrive;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final destination = toLabel ?? l10n.destinationFallback;
    final title = arrived
        ? l10n.tripArrivedAt(destination)
        : active
            ? (progress <= 0 && onStart != null
                ? l10n.tripRouteReady
                : l10n.tripChildActiveTo(destination))
            : l10n.tripGenericLabel;
    final subtitle = arrived
        ? l10n.tripParentNotified
        : active
            ? (onStart != null
                ? (toLabel ?? l10n.tripReadyToStart)
                : l10n.tripInProgress)
            : l10n.tripChooseSafeDestination;
    final jakarta = GoogleFonts.plusJakartaSans().fontFamily;
    final iconBg = arrived
        ? (refresh
            ? VisualRefreshColors.accentTint
            : AppColors.teal.withValues(alpha: 0.14))
        : (refresh
            ? VisualRefreshColors.accentTint
            : const Color(0xFFE8F1FF));
    final iconColor = arrived
        ? (refresh ? VisualRefreshColors.accent : AppColors.tealDeep)
        : (refresh ? VisualRefreshColors.accent : AppColors.sky);

    return Material(
      color: refresh ? VisualRefreshColors.surface : Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: !active && !arrived ? onStart : null,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(
              color: refresh
                  ? VisualRefreshColors.border
                  : const Color(0xFFE2E6EA),
              width: refresh ? 0.5 : 1,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: iconBg,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        arrived
                            ? Icons.check_circle_rounded
                            : Icons.directions_walk_rounded,
                        color: iconColor,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontFamily: refresh ? jakarta : null,
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                              color: refresh
                                  ? VisualRefreshColors.textPrimary
                                  : null,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: refresh ? jakarta : null,
                              color: refresh
                                  ? VisualRefreshColors.textSecondary
                                  : AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!active && !arrived && onStart != null)
                      TextButton(
                        onPressed: onStart,
                        style: TextButton.styleFrom(
                          foregroundColor: refresh
                              ? VisualRefreshColors.accent
                              : AppColors.tealDeep,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          l10n.startAction,
                          style: TextStyle(
                            fontFamily: refresh ? jakarta : null,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                  ],
                ),
                if (active && onStart == null) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: refresh
                          ? VisualRefreshColors.border
                          : const Color(0xFFE2E6EA),
                      color: refresh
                          ? VisualRefreshColors.accent
                          : AppColors.teal,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      if (onArrive != null)
                        Expanded(
                          child: FilledButton(
                            onPressed: onArrive,
                            style: FilledButton.styleFrom(
                              backgroundColor: refresh
                                  ? VisualRefreshColors.anchor
                                  : AppColors.tealDeep,
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(
                              l10n.tripArrived,
                              style: const TextStyle(fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      if (onArrive != null && onCancel != null)
                        const SizedBox(width: 8),
                      if (onCancel != null)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onCancel,
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(l10n.tripCancel),
                          ),
                        ),
                    ],
                  ),
                ],
                if (active && onStart != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: onStart,
                          style: FilledButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            visualDensity: VisualDensity.compact,
                          ),
                          child: Text(l10n.tripChildStart),
                        ),
                      ),
                      if (onCancel != null) ...[
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: onCancel,
                            style: OutlinedButton.styleFrom(
                              padding:
                                  const EdgeInsets.symmetric(vertical: 10),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: Text(l10n.tripCancel),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.todayUsageSeconds,
    required this.points,
    required this.streak,
    required this.onOpenScreenTab,
    required this.onOpenRewards,
    this.refresh = false,
  });

  final int todayUsageSeconds;
  final int points;
  final int streak;
  final VoidCallback onOpenScreenTab;
  final VoidCallback onOpenRewards;
  final bool refresh;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final jakarta = GoogleFonts.plusJakartaSans().fontFamily;

    if (refresh) {
      return IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: _VrStatTile(
                icon: Icons.schedule,
                iconColor: VisualRefreshColors.accent,
                background: VisualRefreshColors.accentTint,
                value: formatDuration(l10n, todayUsageSeconds),
                label: l10n.screenTimeToday,
                valueColor: VisualRefreshColors.accent,
                fontFamily: jakarta,
                onTap: onOpenScreenTab,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: _VrStatTile(
                icon: Icons.emoji_events,
                iconColor: VisualRefreshColors.routeText,
                background: VisualRefreshColors.routeTint,
                value: '$points',
                label: l10n.yourPoints,
                valueColor: VisualRefreshColors.routeText,
                fontFamily: jakarta,
                onTap: onOpenRewards,
                footer: Row(
                  children: [
                    Icon(
                      Icons.local_fire_department_rounded,
                      size: 14,
                      color: VisualRefreshColors.routeText,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        l10n.dayStreakCaption(streak),
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: VisualRefreshColors.routeText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        Expanded(
          child: Material(
            color: AppColors.sky.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onOpenScreenTab,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.schedule, color: AppColors.teal),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.teal.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      formatDuration(l10n, todayUsageSeconds),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.teal,
                          ),
                    ),
                    Text(l10n.screenTimeToday),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Material(
            color: AppColors.amber.withValues(alpha: 0.18),
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: onOpenRewards,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.emoji_events, color: AppColors.coral),
                        const Spacer(),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: AppColors.coral.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '$points',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.coral,
                          ),
                    ),
                    Text(l10n.yourPoints),
                    const SizedBox(height: 4),
                    Text(
                      l10n.dayStreakCaption(streak),
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                        color: AppColors.coral,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _VrStatTile extends StatelessWidget {
  const _VrStatTile({
    required this.icon,
    required this.iconColor,
    required this.background,
    required this.value,
    required this.label,
    required this.valueColor,
    required this.fontFamily,
    required this.onTap,
    this.footer,
  });

  final IconData icon;
  final Color iconColor;
  final Color background;
  final String value;
  final String label;
  final Color valueColor;
  final String? fontFamily;
  final VoidCallback onTap;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(AppRadius.vrCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.vrCard),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: iconColor, size: 22),
                  const Spacer(),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: valueColor.withValues(alpha: 0.75),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: GoogleFonts.fraunces(
                  fontWeight: FontWeight.w600,
                  fontSize: 26,
                  height: 1.1,
                  color: valueColor,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontFamily: fontFamily,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                  color: VisualRefreshColors.textSecondary,
                ),
              ),
              if (footer != null) ...[
                const SizedBox(height: 8),
                footer!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}
