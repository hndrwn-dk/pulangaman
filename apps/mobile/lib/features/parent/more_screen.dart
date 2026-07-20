import 'package:flutter/material.dart';
import '../community/reports_screen.dart';
import 'guardians_screen.dart';
import 'reminders_screen.dart';
import 'zones_screen.dart';

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
        icon: Icons.home_work_outlined,
        title: 'Lokasi penting',
        subtitle: 'Rumah, sekolah, dan rute aman (cari nama tempat)',
        page: const PlacesEntryScreen(),
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
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Icon(item.icon)),
              title: Text(
                item.title,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(item.subtitle),
              trailing: const Icon(Icons.chevron_right),
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
