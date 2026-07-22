import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config.dart';
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
  final _otpCtrl = TextEditingController();
  AppRole _role = AppRole.parent;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _inviteCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    final auth = ref.read(authControllerProvider);
    final notifier = ref.read(authControllerProvider.notifier);

    if (_role == AppRole.child) {
      notifier.joinWithInvite(
        name: _nameCtrl.text,
        inviteCode: _inviteCtrl.text,
      );
      return;
    }

    if (auth.awaitingOtp && !AppConfig.useDevAuth) {
      notifier.confirmOtp(_otpCtrl.text);
      return;
    }

    notifier.login(
      name: _nameCtrl.text,
      phone: _phoneCtrl.text,
      role: _role,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    final showOtp = auth.awaitingOtp &&
        _role != AppRole.child &&
        !AppConfig.useDevAuth;

    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          children: [
            const _BrandHeader(),
            const SizedBox(height: 14),
            const _FeatureRow(),
            const SizedBox(height: 20),
            _LoginCard(
              role: _role,
              nameCtrl: _nameCtrl,
              phoneCtrl: _phoneCtrl,
              inviteCtrl: _inviteCtrl,
              otpCtrl: _otpCtrl,
              showOtp: showOtp,
              error: auth.error,
              loading: auth.loading,
              onRoleChanged: (role) {
                if (auth.awaitingOtp) {
                  ref.read(authControllerProvider.notifier).cancelOtp();
                  _otpCtrl.clear();
                }
                setState(() => _role = role);
              },
              onSubmit: _submit,
              onResendOtp: () =>
                  ref.read(authControllerProvider.notifier).resendOtp(),
              onChangeNumber: () {
                ref.read(authControllerProvider.notifier).cancelOtp();
                _otpCtrl.clear();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDeep.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.asset(
              'assets/images/app_icon.png',
              width: 58,
              height: 58,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppStrings.brand,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: AppColors.tealDeep,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.5,
                        height: 1.1,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppStrings.tagline,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.inkSoft,
                        height: 1.35,
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

class _FeatureRow extends StatelessWidget {
  const _FeatureRow();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        Expanded(
          child: _FeatureCard(
            label: 'Check-in',
            icon: Icons.school_rounded,
            background: Color(0xFFD6EEFC),
            iconBackground: Color(0xFF3B8FD9),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _FeatureCard(
            label: 'Hadiah',
            icon: Icons.star_rounded,
            background: Color(0xFFFFF0C2),
            iconBackground: Color(0xFFE8A820),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          child: _FeatureCard(
            label: 'Waktu Layar',
            icon: Icons.hourglass_bottom_rounded,
            background: Color(0xFFE8DFFB),
            iconBackground: Color(0xFF8B6FD4),
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({
    required this.label,
    required this.icon,
    required this.background,
    required this.iconBackground,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color iconBackground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: AppColors.ink,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginCard extends StatelessWidget {
  const _LoginCard({
    required this.role,
    required this.nameCtrl,
    required this.phoneCtrl,
    required this.inviteCtrl,
    required this.otpCtrl,
    required this.showOtp,
    required this.error,
    required this.loading,
    required this.onRoleChanged,
    required this.onSubmit,
    required this.onResendOtp,
    required this.onChangeNumber,
  });

  final AppRole role;
  final TextEditingController nameCtrl;
  final TextEditingController phoneCtrl;
  final TextEditingController inviteCtrl;
  final TextEditingController otpCtrl;
  final bool showOtp;
  final String? error;
  final bool loading;
  final ValueChanged<AppRole> onRoleChanged;
  final VoidCallback onSubmit;
  final VoidCallback onResendOtp;
  final VoidCallback onChangeNumber;

  @override
  Widget build(BuildContext context) {
    final primaryLabel = role == AppRole.child
        ? AppStrings.loginAction
        : showOtp
            ? AppStrings.verifyOtpAction
            : (AppConfig.useDevAuth
                ? AppStrings.loginAction
                : AppStrings.sendOtpAction);

    return Container(
      padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(32),
        boxShadow: [
          BoxShadow(
            color: AppColors.tealDeep.withValues(alpha: 0.07),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.sky.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  color: AppColors.tealDeep,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                AppStrings.loginTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppColors.tealDeep,
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          if (!showOtp) ...[
            _LoginField(
              label: AppStrings.nameLabel,
              child: TextField(
                controller: nameCtrl,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  hintText: 'Masukkan nama lengkap',
                  hintStyle: TextStyle(color: Color(0xFFB0BDB9)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (role == AppRole.child)
              _LoginField(
                label: AppStrings.inviteCodeLabel,
                helper: Row(
                  children: [
                    Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 15,
                      color: AppColors.amber.withValues(alpha: 0.95),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Minta kode 6 digit dari orang tua',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.inkSoft,
                              fontSize: 13,
                            ),
                      ),
                    ),
                  ],
                ),
                child: TextField(
                  controller: inviteCtrl,
                  textCapitalization: TextCapitalization.characters,
                  decoration: const InputDecoration(
                    hintText: 'Kode undangan',
                    hintStyle: TextStyle(color: Color(0xFFB0BDB9)),
                  ),
                ),
              )
            else
              _LoginField(
                label: AppStrings.phoneLabel,
                child: TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    hintText: '+62812...',
                    hintStyle: TextStyle(color: Color(0xFFB0BDB9)),
                  ),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Peran',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: AppColors.teal,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 10),
            _RoleSelector(
              selected: role,
              onChanged: onRoleChanged,
            ),
          ] else ...[
            Text(
              AppStrings.otpSentHint,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.inkSoft,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              phoneCtrl.text.trim(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: AppColors.tealDeep,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 16),
            _LoginField(
              label: AppStrings.otpLabel,
              child: TextField(
                controller: otpCtrl,
                keyboardType: TextInputType.number,
                maxLength: 6,
                decoration: const InputDecoration(
                  hintText: AppStrings.otpHint,
                  hintStyle: TextStyle(color: Color(0xFFB0BDB9)),
                  counterText: '',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton(
                  onPressed: loading ? null : onResendOtp,
                  child: const Text(AppStrings.resendOtp),
                ),
                TextButton(
                  onPressed: loading ? null : onChangeNumber,
                  child: const Text(AppStrings.changeNumber),
                ),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 14),
            Text(
              error!,
              style: const TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton(
            onPressed: loading ? null : onSubmit,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.teal,
              disabledBackgroundColor: AppColors.teal.withValues(alpha: 0.5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              elevation: 0,
            ),
            child: Text(
              loading ? '...' : primaryLabel,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginField extends StatelessWidget {
  const _LoginField({
    required this.label,
    this.helper,
    required this.child,
  });

  final String label;
  final Widget child;
  final Widget? helper;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.teal,
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 8),
        child,
        if (helper != null) ...[
          const SizedBox(height: 8),
          helper!,
        ],
      ],
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({
    required this.selected,
    required this.onChanged,
  });

  final AppRole selected;
  final ValueChanged<AppRole> onChanged;

  static const _options = [
    (AppRole.parent, 'Orang Tua'),
    (AppRole.child, 'Anak'),
    (AppRole.guardian, 'Wali'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: const Color(0xFFF0F3F2),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          for (var i = 0; i < _options.length; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Expanded(
              child: _RoleOption(
                label: _options[i].$2,
                selected: selected == _options[i].$1,
                onTap: () => onChanged(_options[i].$1),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.tealDeep.withValues(alpha: 0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (selected) ...[
                Container(
                  width: 18,
                  height: 18,
                  decoration: const BoxDecoration(
                    color: AppColors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 13,
                  ),
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    color: selected ? AppColors.tealDeep : AppColors.inkSoft,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
