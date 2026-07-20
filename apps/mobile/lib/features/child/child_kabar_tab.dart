import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/pa_widgets.dart';

class ChildMessagePreset {
  const ChildMessagePreset({
    required this.id,
    required this.label,
    required this.text,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final String text;
  final IconData icon;
  final Color color;
}

const childMessagePresets = [
  ChildMessagePreset(
    id: 'at_school',
    label: 'Sudah sampai sekolah',
    text: 'Sudah sampai sekolah!',
    icon: Icons.school,
    color: AppColors.teal,
  ),
  ChildMessagePreset(
    id: 'at_home',
    label: 'Sudah di rumah',
    text: 'Sudah sampai di rumah.',
    icon: Icons.home,
    color: AppColors.success,
  ),
  ChildMessagePreset(
    id: 'need_help',
    label: 'Butuh bantuan',
    text: 'Butuh bantuan — tolong hubungi saya.',
    icon: Icons.support_agent,
    color: AppColors.coral,
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
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Text(
          'Kabar ke orang tua',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Kirim pesan cepat tanpa mengetik. Orang tua akan mendapat notifikasi.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.inkSoft,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        ...childMessagePresets.map(
          (preset) => Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: _PresetButton(
              preset: preset,
              loading: sendingPresetId == preset.id,
              disabled: sendingPresetId != null && sendingPresetId != preset.id,
              onPressed: () => onSendPreset(preset),
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        PaSectionCard(
          color: AppColors.sky.withValues(alpha: 0.12),
          child: Row(
            children: [
              const Icon(Icons.info_outline, color: AppColors.teal),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Pesan dikirim ke orang tua yang terhubung. '
                  'Untuk darurat, gunakan tombol panik di Beranda.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PresetButton extends StatelessWidget {
  const _PresetButton({
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
    return PaSectionCard(
      color: preset.color.withValues(alpha: 0.1),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: disabled ? null : onPressed,
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: preset.color.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(16),
              ),
              child: loading
                  ? Padding(
                      padding: const EdgeInsets.all(14),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: preset.color,
                      ),
                    )
                  : Icon(preset.icon, color: preset.color, size: 28),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preset.label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  Text(
                    preset.text,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.inkSoft,
                        ),
                  ),
                ],
              ),
            ),
            Icon(Icons.send_rounded, color: preset.color),
          ],
        ),
      ),
    );
  }
}
