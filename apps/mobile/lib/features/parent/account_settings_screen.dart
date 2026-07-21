import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../auth/auth_controller.dart';

class AccountSettingsScreen extends ConsumerWidget {
  const AccountSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(title: const Text('Pengaturan Akun')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.tealDeep,
                  child: Text(
                    _initials(auth.name),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        auth.name ?? 'Orang tua',
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 17,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Akun orang tua PulangAman',
                        style: TextStyle(
                          color: AppColors.inkSoft,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: const Text(
                    'Notifikasi',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Kabar, SOS, dan zona aman'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Notifikasi mengikuti izin sistem HP.',
                        ),
                      ),
                    );
                  },
                ),
                const Divider(height: 1, indent: 16, endIndent: 16),
                ListTile(
                  leading: const Icon(Icons.lock_outline_rounded),
                  title: const Text(
                    'Privasi',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  subtitle: const Text('Data lokasi hanya untuk keluarga'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'Lokasi anak hanya dibagikan ke orang tua & wali.',
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).logout(),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.coral,
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.logout_rounded),
            label: const Text(
              'Keluar',
              style: TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'PA';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return ('${parts[0][0]}${parts[1][0]}').toUpperCase();
  }
}
