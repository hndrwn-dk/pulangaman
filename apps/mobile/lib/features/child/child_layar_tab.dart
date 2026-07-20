import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
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
      color: AppColors.teal,
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
            'Waktu layar',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lihat berapa lama kamu main HP hari ini.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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
                'Aplikasi',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              const Spacer(),
              if (!loading && apps.isNotEmpty)
                Text(
                  '${apps.length} app',
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w700,
                      ),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFE8F8F2), Color(0xFFFFF1D6)],
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.85),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.hourglass_disabled_rounded,
              size: 36,
              color: AppColors.teal,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'Akses pemakaian belum aktif',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Izinkan PulangAman melihat pemakaian layar agar statistik muncul di sini.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.inkSoft,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onOpenUsageSettings,
              child: const Text('Buka pengaturan izin'),
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
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(AppRadius.pill),
        border: Border.all(color: const Color(0x14075A4F)),
      ),
      child: Row(
        children: UsagePeriod.values.map((p) {
          final selected = p == period;
          return Expanded(
            child: GestureDetector(
              onTap: () => onChanged(p),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? AppColors.teal : Colors.transparent,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                ),
                child: Text(
                  p.shortLabel,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: selected ? Colors.white : AppColors.inkSoft,
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
    const dailyGoalSeconds = 2 * 3600;
    final goal = switch (period) {
      UsagePeriod.today => dailyGoalSeconds,
      UsagePeriod.week => dailyGoalSeconds * 7,
      UsagePeriod.month => dailyGoalSeconds * 30,
    };
    final progress = (totalSeconds / goal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A8F7A), Color(0xFF07584E)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
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
            child: CustomPaint(
              painter: _RingPainter(
                progress: loading ? 0 : progress,
                trackColor: Colors.white.withValues(alpha: 0.18),
                progressColor: AppColors.amber,
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
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              fontSize: 28,
                              height: 1.05,
                              letterSpacing: -0.8,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            period.label,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.75),
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: _HeroStat(
                  label: 'Total',
                  value: loading ? '...' : formatDuration(totalSeconds),
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              Expanded(
                child: _HeroStat(
                  label: 'Aplikasi',
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
                  label: 'Target',
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
    return Column(
      children: [
        Text(
          value,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.65),
            fontSize: 11,
            fontWeight: FontWeight.w600,
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
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.sand.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        children: [
          Icon(Icons.phone_android_rounded, size: 40, color: AppColors.teal),
          const SizedBox(height: 10),
          Text(
            'Belum ada data',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Gunakan HP seperti biasa — statistik akan muncul di sini.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
    final fraction = maxSeconds > 0 ? app.durationSeconds / maxSeconds : 0.0;
    final name = friendlyAppName(app.packageName, appLabel: app.appLabel);
    final accent = appAccentForPackage(app.packageName);
    final icon = appIconForPackage(app.packageName);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x10075A4F)),
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
                    color: accent.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent, size: 24),
                ),
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    width: 20,
                    height: 20,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: rank <= 3 ? AppColors.amber : AppColors.mint,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      '$rank',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: rank <= 3 ? AppColors.ink : AppColors.tealDeep,
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
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formatDuration(app.durationSeconds),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: accent,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0.04, 1.0),
                      minHeight: 7,
                      backgroundColor: accent.withValues(alpha: 0.12),
                      color: accent,
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
