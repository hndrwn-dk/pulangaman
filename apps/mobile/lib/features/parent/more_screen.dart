import 'package:flutter/material.dart';
import '../community/reports_screen.dart';
import '../community/safe_route_screen.dart';
import 'guardians_screen.dart';
import 'zones_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <({IconData icon, String title, Widget page})>[
      (icon: Icons.fence, title: 'Zona aman', page: const ZonesEntryScreen()),
      (icon: Icons.shield_outlined, title: 'Wali terpercaya', page: const GuardiansEntryScreen()),
      (icon: Icons.report_outlined, title: 'Laporan komunitas', page: const ReportsScreen()),
      (icon: Icons.route, title: 'Rute aman', page: const SafeRouteScreen()),
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
              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w800)),
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
