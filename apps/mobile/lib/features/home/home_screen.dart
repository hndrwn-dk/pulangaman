import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';

enum UserRoleChoice { parent, child, guardian }

final selectedRoleProvider = StateProvider<UserRoleChoice?>(
  (ref) => null,
);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedRoleProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.sand,
              AppColors.canvas,
              Color(0xFFD9EBE4),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.brand,
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                        color: AppColors.tealDeep,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                      ),
                ),
                const SizedBox(height: 12),
                Text(
                  AppStrings.tagline,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.ink.withValues(alpha: 0.8),
                        height: 1.35,
                      ),
                ),
                const Spacer(),
                _RoleTile(
                  label: AppStrings.roleParent,
                  selected: selected == UserRoleChoice.parent,
                  onTap: () => ref.read(selectedRoleProvider.notifier).state =
                      UserRoleChoice.parent,
                ),
                const SizedBox(height: 12),
                _RoleTile(
                  label: AppStrings.roleChild,
                  selected: selected == UserRoleChoice.child,
                  onTap: () => ref.read(selectedRoleProvider.notifier).state =
                      UserRoleChoice.child,
                ),
                const SizedBox(height: 12),
                _RoleTile(
                  label: AppStrings.roleGuardian,
                  selected: selected == UserRoleChoice.guardian,
                  onTap: () => ref.read(selectedRoleProvider.notifier).state =
                      UserRoleChoice.guardian,
                ),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: selected == null
                        ? null
                        : () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text(AppStrings.phase0Note)),
                            );
                          },
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.teal,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: const Text(AppStrings.continueLabel),
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

class _RoleTile extends StatelessWidget {
  const _RoleTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.teal.withValues(alpha: 0.12) : Colors.white,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                color: selected ? AppColors.teal : Colors.transparent,
                width: 4,
              ),
            ),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: AppColors.ink,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
          ),
        ),
      ),
    );
  }
}
