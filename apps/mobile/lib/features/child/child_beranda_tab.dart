import 'package:flutter/material.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';
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
    required this.reminderCount,
    required this.exactAlarmOk,
    required this.onPanicTap,
    required this.onOpenUsageSettings,
    required this.onOpenAccessibilitySettings,
    required this.onOpenReminderPermissions,
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
  final int reminderCount;
  final bool exactAlarmOk;
  final VoidCallback onPanicTap;
  final VoidCallback onOpenUsageSettings;
  final VoidCallback onOpenAccessibilitySettings;
  final VoidCallback onOpenReminderPermissions;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Hai, $childName!',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const Text('Tetap aman, kumpulkan poin, dan beri kabar keluarga.'),
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            PaStatusPill(
              label: tracking ? 'Lokasi aktif' : 'Lokasi mati',
              icon: tracking ? Icons.location_on : Icons.location_off,
              color: tracking ? AppColors.success : AppColors.danger,
            ),
            PaStatusPill(
              label: '$points poin · $streak hari',
              icon: Icons.star,
              color: AppColors.coral,
            ),
            PaStatusPill(
              label: usageAccess && accessibility
                  ? 'Aturan layar aktif'
                  : 'Izin layar belum lengkap',
              icon: Icons.hourglass_bottom,
              color: AppColors.lavender,
            ),
            GestureDetector(
              onTap: exactAlarmOk ? null : onOpenReminderPermissions,
              child: PaStatusPill(
                label: !exactAlarmOk
                    ? 'Izin alarm belum lengkap'
                    : reminderCount > 0
                        ? 'Pengingat aktif ($reminderCount)'
                        : 'Belum ada pengingat',
                icon: Icons.alarm_rounded,
                color: exactAlarmOk ? AppColors.sky : AppColors.amber,
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.md),
        _QuickStatsRow(todayUsageSeconds: todayUsageSeconds, points: points),
        const SizedBox(height: AppSpacing.lg),
        PaSectionCard(
          color: AppColors.coral.withValues(alpha: 0.12),
          child: Column(
            children: [
              SizedBox(
                height: 180,
                child: FilledButton(
                  onPressed: (panicInFlight || panicOnCooldown) ? null : onPanicTap,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    shape: const CircleBorder(),
                  ),
                  child: Text(
                    AppStrings.panicButton,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ),
              const Text(AppStrings.panicConfirm, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(status ?? '', textAlign: TextAlign.center),
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
                const Text(
                  'Aktifkan perlindungan waktu layar',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 6),
                const Text(
                  'PulangAman, Telepon, dan Pesan tidak pernah diblokir.',
                ),
                const SizedBox(height: 10),
                if (!usageAccess)
                  OutlinedButton(
                    onPressed: onOpenUsageSettings,
                    child: const Text('Izinkan akses pemakaian'),
                  ),
                if (!accessibility)
                  OutlinedButton(
                    onPressed: onOpenAccessibilitySettings,
                    child: const Text('Aktifkan pemblokiran aplikasi'),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickStatsRow extends StatelessWidget {
  const _QuickStatsRow({
    required this.todayUsageSeconds,
    required this.points,
  });

  final int todayUsageSeconds;
  final int points;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: PaSectionCard(
            color: AppColors.sky.withValues(alpha: 0.14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.schedule, color: AppColors.teal),
                const SizedBox(height: 8),
                Text(
                  formatDuration(todayUsageSeconds),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.teal,
                      ),
                ),
                const Text('Layar hari ini'),
              ],
            ),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: PaSectionCard(
            color: AppColors.amber.withValues(alpha: 0.18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.emoji_events, color: AppColors.coral),
                const SizedBox(height: 8),
                Text(
                  '$points',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: AppColors.coral,
                      ),
                ),
                const Text('Poin kamu'),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
