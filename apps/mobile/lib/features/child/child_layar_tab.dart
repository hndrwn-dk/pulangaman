import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
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
          PaEmptyState(
            icon: Icons.hourglass_disabled,
            title: 'Akses pemakaian belum aktif',
            message:
                'Izinkan PulangAman melihat pemakaian layar agar statistik muncul di sini.',
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton(
            onPressed: onOpenUsageSettings,
            child: const Text('Buka pengaturan izin'),
          ),
        ],
      );
    }

    final maxSeconds = apps.isEmpty ? 1 : apps.first.durationSeconds;

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Text(
            'Waktu layar',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          _PeriodToggle(period: period, onChanged: onPeriodChanged),
          const SizedBox(height: AppSpacing.lg),
          _UsageRing(
            totalSeconds: totalSeconds,
            periodLabel: period.label,
            loading: loading,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Aplikasi',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: AppSpacing.sm),
          if (loading)
            const Padding(
              padding: EdgeInsets.all(AppSpacing.xl),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (apps.isEmpty)
            const PaEmptyState(
              icon: Icons.phone_android,
              title: 'Belum ada data',
              message: 'Gunakan HP seperti biasa — statistik akan muncul di sini.',
            )
          else
            ...apps.map(
              (app) => _AppUsageTile(
                app: app,
                maxSeconds: maxSeconds,
              ),
            ),
        ],
      ),
    );
  }
}

class _PeriodToggle extends StatelessWidget {
  const _PeriodToggle({
    required this.period,
    required this.onChanged,
  });

  final UsagePeriod period;
  final ValueChanged<UsagePeriod> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<UsagePeriod>(
      segments: UsagePeriod.values
          .map(
            (p) => ButtonSegment(
              value: p,
              label: Text(p.label),
            ),
          )
          .toList(),
      selected: {period},
      onSelectionChanged: (selected) => onChanged(selected.first),
    );
  }
}

class _UsageRing extends StatelessWidget {
  const _UsageRing({
    required this.totalSeconds,
    required this.periodLabel,
    required this.loading,
  });

  final int totalSeconds;
  final String periodLabel;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    const dailyGoalSeconds = 2 * 3600;
    final progress = (totalSeconds / dailyGoalSeconds).clamp(0.0, 1.0);

    return PaSectionCard(
      color: AppColors.mint.withValues(alpha: 0.35),
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: loading ? null : progress,
                  strokeWidth: 10,
                  backgroundColor: Colors.white.withValues(alpha: 0.6),
                  color: AppColors.teal,
                ),
                if (!loading)
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        formatDuration(totalSeconds),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  periodLabel,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  loading
                      ? 'Memuat data...'
                      : 'Total pemakaian layar di periode ini.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkSoft,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppUsageTile extends StatelessWidget {
  const _AppUsageTile({
    required this.app,
    required this.maxSeconds,
  });

  final UsageAppEntry app;
  final int maxSeconds;

  @override
  Widget build(BuildContext context) {
    final fraction = maxSeconds > 0 ? app.durationSeconds / maxSeconds : 0.0;
    final name = friendlyAppName(app.packageName);
    final icon = appIconForPackage(app.packageName);

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: PaSectionCard(
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.lavender.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.tealDeep),
            ),
            const SizedBox(width: AppSpacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        formatDuration(app.durationSeconds),
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.teal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                    child: LinearProgressIndicator(
                      value: fraction.clamp(0.05, 1.0),
                      minHeight: 8,
                      backgroundColor: AppColors.mint.withValues(alpha: 0.4),
                      color: AppColors.teal,
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
