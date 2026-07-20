import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import 'auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController(text: '+62812');
  final _inviteCtrl = TextEditingController();
  AppRole _role = AppRole.parent;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);

    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.sand, AppColors.canvas, AppColors.mint],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.86),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: const BoxDecoration(
                        color: AppColors.amber,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.home_rounded, color: AppColors.tealDeep, size: 34),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppStrings.brand,
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  color: AppColors.tealDeep,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -1,
                                ),
                          ),
                          const Text(AppStrings.tagline),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _FeatureBubble(icon: Icons.school, label: 'Check-in', color: AppColors.sky),
                  const SizedBox(width: 8),
                  _FeatureBubble(icon: Icons.star, label: 'Hadiah', color: AppColors.amber),
                  const SizedBox(width: 8),
                  _FeatureBubble(icon: Icons.hourglass_bottom, label: 'Waktu layar', color: AppColors.lavender),
                ],
              ),
              const SizedBox(height: 28),
              Text(AppStrings.loginTitle,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      )),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: AppStrings.nameLabel,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              if (_role == AppRole.child)
                TextField(
                  controller: _inviteCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    labelText: AppStrings.inviteCodeLabel,
                    hintText: 'Contoh: A7K2M9',
                    border: OutlineInputBorder(),
                    helperText: 'Minta kode 6 digit dari orang tua',
                  ),
                )
              else
                TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: AppStrings.phoneLabel,
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 16),
              SegmentedButton<AppRole>(
                segments: const [
                  ButtonSegment(value: AppRole.parent, label: Text('Orang tua')),
                  ButtonSegment(value: AppRole.child, label: Text('Anak')),
                  ButtonSegment(value: AppRole.guardian, label: Text('Wali')),
                ],
                selected: {_role},
                onSelectionChanged: (v) => setState(() => _role = v.first),
              ),
              if (auth.error != null) ...[
                const SizedBox(height: 12),
                Text(auth.error!, style: const TextStyle(color: AppColors.danger)),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: auth.loading
                    ? null
                    : () {
                        if (_role == AppRole.child) {
                          ref.read(authControllerProvider.notifier).joinWithInvite(
                                name: _nameCtrl.text,
                                inviteCode: _inviteCtrl.text,
                              );
                        } else {
                          ref.read(authControllerProvider.notifier).login(
                                name: _nameCtrl.text,
                                phone: _phoneCtrl.text,
                                role: _role,
                              );
                        }
                      },
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.teal,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(
                  auth.loading ? '...' : AppStrings.loginAction,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureBubble extends StatelessWidget {
  const _FeatureBubble({required this.icon, required this.label, required this.color});

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppColors.tealDeep),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}
