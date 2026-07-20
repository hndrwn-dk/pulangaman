import 'package:flutter/material.dart';

import '../../core/theme.dart';

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
}

const childMessagePresets = [
  ChildMessagePreset(
    id: 'at_school',
    label: 'Sudah sampai sekolah',
    text: 'Sudah sampai sekolah!',
    subtitle: 'Beri tahu ortu kamu sudah aman di sekolah',
    icon: Icons.school_rounded,
    color: Color(0xFF0A8F7A),
  ),
  ChildMessagePreset(
    id: 'at_home',
    label: 'Sudah di rumah',
    text: 'Sudah sampai di rumah.',
    subtitle: 'Kabari kalau kamu sudah pulang',
    icon: Icons.home_rounded,
    color: Color(0xFF249B72),
  ),
  ChildMessagePreset(
    id: 'need_help',
    label: 'Butuh bantuan',
    text: 'Butuh bantuan — tolong hubungi saya.',
    subtitle: 'Minta ortu segera menghubungi kamu',
    icon: Icons.support_agent_rounded,
    color: Color(0xFFFF746C),
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
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      children: [
        Text(
          'Kabar ke ortu',
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: -0.5,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ketuk sekali — pesan langsung terkirim.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.inkSoft,
              ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _KabarHero(),
        const SizedBox(height: AppSpacing.lg),
        ...childMessagePresets.map(
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
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.sand.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Pesan dikirim ke orang tua yang terhubung. '
                  'Untuk darurat, gunakan tombol panik di Beranda.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                        height: 1.4,
                      ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _KabarHero extends StatelessWidget {
  const _KabarHero();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF8A7A), Color(0xFFFFC857)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
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
                  'Kirim kabar cepat',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Tidak perlu mengetik. Pilih salah satu pesan di bawah.',
                  style: TextStyle(
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
              color: Colors.white.withValues(alpha: 0.22),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.chat_bubble_rounded,
              color: Colors.white,
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
    final dimmed = disabled && !loading;

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 180),
      opacity: dimmed ? 0.45 : 1,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: disabled ? null : onPressed,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: preset.color.withValues(alpha: 0.22),
                width: 1.5,
              ),
              boxShadow: [
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
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        preset.color,
                        preset.color.withValues(alpha: 0.75),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(18),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        preset.subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
                    color: preset.color.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.send_rounded,
                    color: preset.color,
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
