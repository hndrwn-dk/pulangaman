import 'package:flutter/material.dart';

import '../../core/day_period.dart';
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
    this.panicActive = false,
    required this.reminderCount,
    required this.exactAlarmOk,
    required this.onPanicTap,
    required this.onOpenUsageSettings,
    required this.onOpenAccessibilitySettings,
    required this.onOpenReminderPermissions,
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
  final VoidCallback onOpenUsageSettings;
  final VoidCallback onOpenAccessibilitySettings;
  final VoidCallback onOpenReminderPermissions;
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

  String _timeGreeting() => dayPeriodFor().shortId;

  @override
  Widget build(BuildContext context) {
    final period = dayPeriodFor();
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
                '${_timeGreeting()}, $childName!',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
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
        if (empConfigured || empActive) ...[
          const SizedBox(height: AppSpacing.md),
          _EmpKnowYourPointCard(
            active: empActive,
            placeName: empPlaceName ?? 'Titik kumpul',
            note: empNote,
            onOpen: onOpenEmp,
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
                      ? 'Sudah dikirim ke orang tua'
                      : 'Aku otw pulang',
                  style: const TextStyle(fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                if (!homeByAckSent) ...[
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: onHomeByAck,
                    child: const Text('Beri kabar ke orang tua'),
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
              Text(
                panicInFlight
                    ? 'Mengirim peringatan...'
                    : panicOnCooldown
                        ? 'Panik terkirim. Tunggu sebentar sebelum bisa dikirim lagi.'
                        : panicActive
                            ? 'Mode panik aktif — menunggu respons orang tua'
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
                if (!accessibility) ...[
                  OutlinedButton(
                    onPressed: onOpenAccessibilitySettings,
                    child: const Text('Aktifkan pemblokiran aplikasi'),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tombolnya terkunci ("Setelan dibatasi")? Buka Info aplikasi, '
                    'ketuk menu titik tiga di kanan atas, lalu pilih '
                    '"Izinkan setelan yang dibatasi". Setelah itu coba lagi.',
                    style: TextStyle(
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
                      child: const Text(
                        'Buka Info aplikasi',
                        style: TextStyle(fontWeight: FontWeight.w800),
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
}

class _EmpKnowYourPointCard extends StatelessWidget {
  const _EmpKnowYourPointCard({
    required this.active,
    required this.placeName,
    this.note,
    this.onOpen,
  });

  final bool active;
  final String placeName;
  final String? note;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final accent = active ? AppColors.danger : AppColors.tealDeep;
    final wash = active
        ? const Color(0xFFFFE8E6)
        : AppColors.teal.withValues(alpha: 0.10);

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpen,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(
              color: active
                  ? AppColors.danger.withValues(alpha: 0.35)
                  : const Color(0xFFE2E6EA),
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
                                    ? 'Darurat — segera ke sini'
                                    : 'Titik kumpul keluarga',
                                style: TextStyle(
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
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                active
                                    ? ((note != null && note!.trim().isNotEmpty)
                                        ? note!.trim()
                                        : 'Ikuti arahan orang tua')
                                    : 'Hafalkan tempat ini untuk kondisi darurat',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: AppColors.inkSoft,
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
                            color: AppColors.inkSoft.withValues(alpha: 0.8),
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
  });

  final bool active;
  final bool arrived;
  final String? toLabel;
  final double progress;
  final VoidCallback? onStart;
  final VoidCallback? onCancel;
  final VoidCallback? onArrive;

  @override
  Widget build(BuildContext context) {
    final title = arrived
        ? 'Tiba di ${toLabel ?? 'tujuan'}'
        : active
            ? (progress <= 0 && onStart != null
                ? 'Rute siap'
                : 'Menuju ${toLabel ?? 'tujuan'}')
            : 'Perjalanan';
    final subtitle = arrived
        ? 'Orang tua sudah diberi tahu'
        : active
            ? (onStart != null ? (toLabel ?? 'Siap dimulai') : 'Sedang berjalan')
            : 'Pilih tujuan aman ke tempat tersimpan';

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: !active && !arrived ? onStart : null,
        child: Ink(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE2E6EA)),
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
                        color: arrived
                            ? AppColors.teal.withValues(alpha: 0.14)
                            : const Color(0xFFE8F1FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        arrived
                            ? Icons.check_circle_rounded
                            : Icons.directions_walk_rounded,
                        color: arrived ? AppColors.tealDeep : AppColors.sky,
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
                            style: const TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.inkSoft,
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
                          foregroundColor: AppColors.tealDeep,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text(
                          'Mulai',
                          style: TextStyle(fontWeight: FontWeight.w800),
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
                      backgroundColor: const Color(0xFFE2E6EA),
                      color: AppColors.teal,
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
                              backgroundColor: AppColors.tealDeep,
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              visualDensity: VisualDensity.compact,
                            ),
                            child: const Text(
                              'Sudah sampai',
                              style: TextStyle(fontWeight: FontWeight.w800),
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
                            child: const Text('Batalkan'),
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
                          child: const Text('Mulai perjalanan'),
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
                            child: const Text('Batalkan'),
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
