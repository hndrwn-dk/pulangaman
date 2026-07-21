import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import '../parent/child_avatar.dart';
import '../parent/children_controller.dart';

class RewardsScreen extends ConsumerStatefulWidget {
  const RewardsScreen({super.key});

  @override
  ConsumerState<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends ConsumerState<RewardsScreen> {
  String? _childId;
  Map<String, dynamic> _balance = {};
  List<Map<String, dynamic>> _ledger = [];
  bool _loading = false;
  final Map<String, ChildGender> _genders = {};

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(childrenControllerProvider.notifier).bootstrap();
      await _loadGenders();
      final items = ref.read(childrenControllerProvider).items;
      if (items.isNotEmpty) await _load(items.first.id);
    });
  }

  Future<void> _loadGenders() async {
    final children = ref.read(childrenControllerProvider).items;
    final map = <String, ChildGender>{};
    for (final c in children) {
      var g = await ChildGenderStore.instance.get(c.id);
      if (g == ChildGender.unknown) {
        g = ChildGenderStore.guessFromName(c.name);
      }
      map[c.id] = g;
    }
    if (!mounted) return;
    setState(() {
      _genders
        ..clear()
        ..addAll(map);
    });
  }

  Future<void> _load(String childId) async {
    setState(() {
      _childId = childId;
      _loading = true;
    });
    try {
      final data =
          await ref.read(apiClientProvider).get('/api/v1/rewards/$childId');
      if (!mounted) return;
      setState(() {
        _balance = (data['balance'] as Map<String, dynamic>?) ?? {};
        _ledger = (data['ledger'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _bonus() async {
    final childId = _childId;
    if (childId == null) return;
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Kasih pujian'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Alasan (opsional)',
            hintText: 'Contoh: Rajin belajar hari ini',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.coral),
            child: const Text('Tambah +5'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiClientProvider).post(
        '/api/v1/rewards/$childId/adjust',
        body: {
          'delta': 5,
          'reason': controller.text.trim().isEmpty
              ? 'Pujian dari orang tua'
              : controller.text.trim(),
        },
      );
      await _load(childId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('+5 poin ditambahkan')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  Future<void> _pickChild(List<ChildSummary> items) async {
    final current = _childId;
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pilih anak',
                  style: TextStyle(fontWeight: FontWeight.w900, fontSize: 17),
                ),
              ),
            ),
            for (final c in items)
              ListTile(
                leading: ChildAvatar(
                  name: c.name,
                  gender: _genders[c.id] ??
                      ChildGenderStore.guessFromName(c.name),
                  size: 40,
                ),
                title: Text(
                  c.name,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                trailing: c.id == current
                    ? const Icon(Icons.check_rounded, color: AppColors.teal)
                    : null,
                onTap: () => Navigator.pop(ctx, c.id),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (picked != null) await _load(picked);
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenControllerProvider);
    final items = children.items;
    final selected = items.isEmpty
        ? null
        : items.firstWhere(
            (c) => c.id == _childId,
            orElse: () => items.first,
          );
    final points = (_balance['points'] as num?)?.toInt() ?? 0;
    final streak = (_balance['current_streak'] as num?)?.toInt() ?? 0;
    final name = selected?.name ?? 'Anak';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      floatingActionButton: selected == null
          ? null
          : FloatingActionButton.extended(
              onPressed: _bonus,
              backgroundColor: AppColors.coral,
              icon: const Icon(Icons.favorite_rounded),
              label: const Text(
                'Kasih Pujian (+5)',
                style: TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 16, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                  const Expanded(
                    child: Text(
                      'Hadiah & Poin',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: AppColors.teal,
                onRefresh: () async {
                  final id = _childId;
                  if (id != null) await _load(id);
                },
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  children: [
                    const Text(
                      'Poin dikumpulkan saat anak tiba di sekolah tepat waktu. '
                      'Bisa juga ditambah manual sebagai pujian.',
                      style: TextStyle(
                        color: AppColors.inkSoft,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (items.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'Belum ada anak terhubung.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.inkSoft),
                        ),
                      )
                    else ...[
                      Material(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        child: InkWell(
                          onTap: () => _pickChild(items),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                ChildAvatar(
                                  name: name,
                                  gender: _genders[selected!.id] ??
                                      ChildGenderStore.guessFromName(name),
                                  size: 40,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w900,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                const Icon(
                                  Icons.expand_more_rounded,
                                  color: AppColors.inkSoft,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      if (_loading)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 40),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else ...[
                        _PointsHeroCard(
                          childName: name,
                          points: points,
                          streak: streak,
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Cara Mendapat Poin',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const _EarnRow(
                          icon: Icons.school_rounded,
                          iconBg: Color(0xFFDCEBFF),
                          iconColor: Color(0xFF2563EB),
                          title: 'Tiba di Sekolah Tepat Waktu',
                          subtitle: '+10 poin per hari',
                          points: '+10',
                        ),
                        const SizedBox(height: 8),
                        const _EarnRow(
                          icon: Icons.home_rounded,
                          iconBg: Color(0xFFE8F6F1),
                          iconColor: AppColors.tealDeep,
                          title: 'Pulang Tepat Waktu',
                          subtitle: '+5 poin per hari',
                          points: '+5',
                        ),
                        const SizedBox(height: 8),
                        const _EarnRow(
                          icon: Icons.favorite_rounded,
                          iconBg: Color(0xFFFFE8E6),
                          iconColor: AppColors.coral,
                          title: 'Pujian dari Orang Tua',
                          subtitle: '+5 poin manual',
                          points: '+5',
                        ),
                        const SizedBox(height: 22),
                        const Text(
                          'Riwayat Poin',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_ledger.isEmpty)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 28,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.04),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Column(
                              children: [
                                Icon(
                                  Icons.markunread_mailbox_outlined,
                                  size: 44,
                                  color: Color(0xFF93C5FD),
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Belum ada riwayat poin',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.inkSoft,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Setelah anak check-in sekolah, poin muncul di sini.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: AppColors.inkSoft,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          )
                        else
                          ..._ledger.map((item) {
                            final raw = item['created_at']?.toString();
                            final at =
                                raw == null ? null : DateTime.tryParse(raw);
                            final when = at == null
                                ? (raw ?? '')
                                : '${at.toLocal().day}/${at.toLocal().month} '
                                    '${at.toLocal().hour.toString().padLeft(2, '0')}:'
                                    '${at.toLocal().minute.toString().padLeft(2, '0')}';
                            final delta =
                                (item['delta'] as num?)?.toInt() ?? 0;
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Container(
                                padding: const EdgeInsets.fromLTRB(
                                  12,
                                  12,
                                  14,
                                  12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(16),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.04),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      alignment: Alignment.center,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFE8F6F1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        delta >= 0 ? '+$delta' : '$delta',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          color: AppColors.tealDeep,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            '${item['reason']}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                          Text(
                                            when,
                                            style: const TextStyle(
                                              color: AppColors.inkSoft,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PointsHeroCard extends StatelessWidget {
  const _PointsHeroCard({
    required this.childName,
    required this.points,
    required this.streak,
  });

  final String childName;
  final int points;
  final int streak;

  static const _dayLetters = ['S', 'S', 'R', 'K', 'J', 'S', 'M'];
  static const _dayLabels = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final todayIndex = DateTime.now().weekday - 1; // Mon=0
    final filled = streak.clamp(0, 7);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8913A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFE8913A).withValues(alpha: 0.4),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$points',
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFFE8913A),
                    letterSpacing: -0.8,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Poin $childName',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      streak == 0
                          ? 'Belum ada streak harian'
                          : 'Rajin $streak hari berturut-turut',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontWeight: FontWeight.w600,
                        fontSize: 13.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Contoh: tiba di sekolah +10 poin',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Streak Minggu Ini',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.92),
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < 7; i++)
                _StreakDot(
                  letter: _dayLetters[i],
                  label: _dayLabels[i],
                  active: filled > 0 &&
                      i >= (todayIndex - filled + 1).clamp(0, 6) &&
                      i <= todayIndex,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StreakDot extends StatelessWidget {
  const _StreakDot({
    required this.letter,
    required this.label,
    required this.active,
  });

  final String letter;
  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 34,
          height: 34,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: active
                ? Colors.white
                : Colors.white.withValues(alpha: 0.28),
            shape: BoxShape.circle,
          ),
          child: Text(
            letter,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 13,
              color: active
                  ? const Color(0xFFE8913A)
                  : Colors.white.withValues(alpha: 0.9),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: Colors.white.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

class _EarnRow extends StatelessWidget {
  const _EarnRow({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.points,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String points;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 14, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 22),
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
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: AppColors.inkSoft,
                    fontWeight: FontWeight.w600,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          Text(
            points,
            style: const TextStyle(
              fontWeight: FontWeight.w900,
              fontSize: 16,
              color: AppColors.tealDeep,
            ),
          ),
        ],
      ),
    );
  }
}
