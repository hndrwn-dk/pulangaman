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
  AppRole _role = AppRole.parent;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
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
            colors: [AppColors.sand, AppColors.canvas, Color(0xFFD9EBE4)],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 36, 24, 24),
            children: [
              Text(
                AppStrings.brand,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                      color: AppColors.tealDeep,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.tagline,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppColors.ink.withValues(alpha: 0.8),
                    ),
              ),
              const SizedBox(height: 36),
              Text(AppStrings.loginTitle,
                  style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 16),
              TextField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: AppStrings.nameLabel,
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
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
                        ref.read(authControllerProvider.notifier).login(
                              name: _nameCtrl.text,
                              phone: _phoneCtrl.text,
                              role: _role,
                            );
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
