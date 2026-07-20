import 'package:flutter/material.dart';
import '../attendance/attendance_screen.dart';
import '../community/reports_screen.dart';
import '../rewards/rewards_screen.dart';
import 'guardians_screen.dart';
import 'reminders_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String title, String subtitle, Widget page})>[
      (
        icon: Icons.alarm_rounded,
        title: 'Pengingat jadwal',
        subtitle: 'Belajar, tidur, pesan besar di HP anak',
        page: const RemindersScreen(),
      ),
      (
        icon: Icons.place_outlined,
        title: 'Di mana anak',
        subtitle: 'Ringkasan rumah / sekolah / perjalanan',
        page: const AttendanceScreen(),
      ),
      (
        icon: Icons.star_outline,
        title: 'Hadiah & poin',
        subtitle: 'Poin anak karena tiba tepat waktu',
        page: const RewardsScreen(),
      ),
      (
        icon: Icons.shield_outlined,
        title: 'Wali terpercaya',
        subtitle: 'Orang dewasa yang boleh bantu pantau',
        page: const GuardiansEntryScreen(),
      ),
      (
        icon: Icons.report_outlined,
        title: 'Laporan komunitas',
        subtitle: 'Bagikan area yang perlu dihindari',
        page: const ReportsScreen(),
      ),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Fitur lainnya')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              leading: CircleAvatar(
                radius: 26,
                child: Icon(item.icon, size: 26),
              ),
              title: Text(
                item.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 17,
                ),
              ),
              subtitle: Text(
                item.subtitle,
                style: const TextStyle(fontSize: 14, height: 1.35),
              ),
              trailing: const Icon(Icons.chevron_right, size: 28),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => item.page),
              ),
            ),
          );
        },
      ),
    );
  }
}
