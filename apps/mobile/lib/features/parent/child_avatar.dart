import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../../core/theme.dart';

enum ChildGender { girl, boy, unknown }

class ChildGenderStore {
  ChildGenderStore._();
  static final ChildGenderStore instance = ChildGenderStore._();

  Map<String, ChildGender>? _mem;

  Future<File> _file() async {
    final dir = await getDatabasesPath();
    return File(p.join(dir, 'pa_child_gender.json'));
  }

  Future<Map<String, ChildGender>> _load() async {
    if (_mem != null) return _mem!;
    try {
      final file = await _file();
      if (!await file.exists()) {
        _mem = {};
        return _mem!;
      }
      final raw = jsonDecode(await file.readAsString());
      final map = <String, ChildGender>{};
      if (raw is Map) {
        raw.forEach((key, value) {
          map[key.toString()] = switch (value.toString()) {
            'girl' => ChildGender.girl,
            'boy' => ChildGender.boy,
            _ => ChildGender.unknown,
          };
        });
      }
      _mem = map;
    } catch (_) {
      _mem = {};
    }
    return _mem!;
  }

  Future<ChildGender> get(String childId) async {
    final map = await _load();
    return map[childId] ?? ChildGender.unknown;
  }

  Future<void> set(String childId, ChildGender gender) async {
    final map = await _load();
    map[childId] = gender;
    _mem = map;
    try {
      final file = await _file();
      await file.writeAsString(
        jsonEncode({
          for (final e in map.entries) e.key: e.value.name,
        }),
      );
    } catch (_) {}
  }

  /// Guess from Indonesian nickname heuristics when unset.
  static ChildGender guessFromName(String name) {
    final n = name.trim().toLowerCase();
    if (n.isEmpty) return ChildGender.unknown;
    const girls = [
      'sari', 'putri', 'dewi', 'ayu', 'sinta', 'rani', 'nina', 'dina',
      'rina', 'lila', 'maya', 'nadia', 'aisha', 'fatimah', 'zahra', 'anni',
      'ani', 'wati', 'ika', 'yuli', 'fitri', 'indah', 'mega', 'citra',
    ];
    const boys = [
      'andi', 'budi', 'agus', 'reza', 'dimas', 'rizki', 'fajar', 'bayu',
      'eko', 'joni', 'rudi', 'adi', 'yoga', 'arif', 'ilham', 'fahri',
      'hendra', 'deni', 'tono', 'wahyu', 'rama', 'gilang',
    ];
    for (final g in girls) {
      if (n == g || n.startsWith('$g ') || n.endsWith(' $g')) {
        return ChildGender.girl;
      }
    }
    for (final b in boys) {
      if (n == b || n.startsWith('$b ') || n.endsWith(' $b')) {
        return ChildGender.boy;
      }
    }
    return ChildGender.unknown;
  }
}

class ChildAvatar extends StatelessWidget {
  const ChildAvatar({
    super.key,
    required this.name,
    required this.gender,
    this.size = 56,
    this.selected = false,
    this.showEditBadge = false,
  });

  final String name;
  final ChildGender gender;
  final double size;
  final bool selected;
  final bool showEditBadge;

  Color get _bg {
    switch (gender) {
      case ChildGender.girl:
        return const Color(0xFFFFD6E7);
      case ChildGender.boy:
        return const Color(0xFFD6EEFF);
      case ChildGender.unknown:
        return AppColors.mint;
    }
  }

  Color get _fg {
    switch (gender) {
      case ChildGender.girl:
        return const Color(0xFFC2185B);
      case ChildGender.boy:
        return const Color(0xFF1565C0);
      case ChildGender.unknown:
        return AppColors.tealDeep;
    }
  }

  IconData get _icon {
    switch (gender) {
      case ChildGender.girl:
        return Icons.girl_rounded;
      case ChildGender.boy:
        return Icons.boy_rounded;
      case ChildGender.unknown:
        return Icons.child_care_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final avatar = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _bg,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected ? AppColors.teal : Colors.transparent,
          width: selected ? 3 : 0,
        ),
        boxShadow: selected
            ? [
                BoxShadow(
                  color: AppColors.teal.withValues(alpha: 0.25),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Icon(_icon, color: _fg, size: size * 0.55),
    );

    if (!showEditBadge) return avatar;

    return SizedBox(
      width: size + 4,
      height: size + 4,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.teal,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(Icons.edit, color: Colors.white, size: 12),
            ),
          ),
        ],
      ),
    );
  }
}

Future<ChildGender?> showChildGenderPicker({
  required BuildContext context,
  required String childName,
  required ChildGender current,
}) {
  return showModalBottomSheet<ChildGender>(
    context: context,
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pilih wajah untuk $childName',
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Pilih yang mirip anakmu supaya mudah dikenali.',
                style: TextStyle(color: AppColors.inkSoft),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _GenderChoice(
                      label: 'Anak perempuan',
                      gender: ChildGender.girl,
                      selected: current == ChildGender.girl,
                      onTap: () => Navigator.pop(ctx, ChildGender.girl),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _GenderChoice(
                      label: 'Anak laki-laki',
                      gender: ChildGender.boy,
                      selected: current == ChildGender.boy,
                      onTap: () => Navigator.pop(ctx, ChildGender.boy),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _GenderChoice extends StatelessWidget {
  const _GenderChoice({
    required this.label,
    required this.gender,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final ChildGender gender;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.teal : const Color(0x22075A4F),
            width: selected ? 2 : 1,
          ),
          color: selected ? AppColors.mint.withValues(alpha: 0.35) : Colors.white,
        ),
        child: Column(
          children: [
            ChildAvatar(name: label, gender: gender, size: 64, selected: selected),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
