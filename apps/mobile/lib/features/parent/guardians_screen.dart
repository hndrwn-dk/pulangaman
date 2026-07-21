import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/strings.dart';
import '../../core/theme.dart';
import '../auth/auth_controller.dart';
import 'child_avatar.dart';
import 'children_controller.dart';

class _GuardianRef {
  _GuardianRef({
    required this.id,
    required this.name,
    required this.phone,
    required this.status,
    required this.childNames,
  });

  final String id;
  final String name;
  final String phone;
  final String status;
  final List<String> childNames;
}

/// Hub Wali Terpercaya (dari tab Lainnya).
class GuardiansEntryScreen extends ConsumerStatefulWidget {
  const GuardiansEntryScreen({super.key});

  @override
  ConsumerState<GuardiansEntryScreen> createState() =>
      _GuardiansEntryScreenState();
}

class _GuardiansEntryScreenState extends ConsumerState<GuardiansEntryScreen> {
  final Map<String, List<Map<String, dynamic>>> _byChild = {};
  final Map<String, ChildGender> _genders = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(childrenControllerProvider.notifier).bootstrap();
      await _loadGenders();
      await _loadAll();
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

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final children = ref.read(childrenControllerProvider).items;
    final api = ref.read(apiClientProvider);
    final next = <String, List<Map<String, dynamic>>>{};
    for (final c in children) {
      try {
        final data = await api.get(
          '/api/v1/guardians',
          query: {'childId': c.id},
        );
        next[c.id] = (data['guardians'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
      } catch (_) {
        next[c.id] = [];
      }
    }
    if (!mounted) return;
    setState(() {
      _byChild
        ..clear()
        ..addAll(next);
      _loading = false;
    });
  }

  List<_GuardianRef> get _activeGuardians {
    final map = <String, _GuardianRef>{};
    final children = ref.read(childrenControllerProvider).items;
    final nameById = {for (final c in children) c.id: c.name};
    for (final entry in _byChild.entries) {
      final childName = nameById[entry.key] ?? 'Anak';
      for (final g in entry.value) {
        final status = g['status']?.toString() ?? '';
        if (status == 'revoked') continue;
        final id = g['guardian_id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final existing = map[id];
        if (existing == null) {
          map[id] = _GuardianRef(
            id: id,
            name: g['name']?.toString() ?? 'Wali',
            phone: g['phone']?.toString() ?? '',
            status: status,
            childNames: [childName],
          );
        } else if (!existing.childNames.contains(childName)) {
          existing.childNames.add(childName);
        }
      }
    }
    return map.values.toList();
  }

  String _initials(String? name) {
    final parts = (name ?? '').trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'PA';
    if (parts.length == 1) {
      final s = parts.first;
      return (s.length >= 2 ? s.substring(0, 2) : s).toUpperCase();
    }
    return ('${parts[0][0]}${parts[1][0]}').toUpperCase();
  }

  Future<void> _openChild(ChildSummary child) async {
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => GuardiansScreen(child: child)),
    );
    await _loadAll();
  }

  Future<void> _inviteFlow(String channel) async {
    final children = ref.read(childrenControllerProvider).items;
    if (children.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tambah anak dulu sebelum undang wali')),
      );
      return;
    }

    ChildSummary selected = children.first;
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+62');
    final emailCtrl = TextEditingController();

    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    channel == 'whatsapp'
                        ? 'Undang via WhatsApp'
                        : channel == 'email'
                            ? 'Undang via Email'
                            : 'Undang via Link',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selected.id,
                    decoration: const InputDecoration(labelText: 'Untuk anak'),
                    items: children
                        .map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.name),
                          ),
                        )
                        .toList(),
                    onChanged: (id) {
                      if (id == null) return;
                      setLocal(() {
                        selected = children.firstWhere((c) => c.id == id);
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Nama wali',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: phoneCtrl,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Nomor WhatsApp / telepon',
                    ),
                  ),
                  if (channel == 'email') ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email (opsional)',
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style:
                        FilledButton.styleFrom(backgroundColor: AppColors.teal),
                    child: const Text('Lanjut'),
                  ),
                ],
              );
            },
          ),
        );
      },
    );

    if (ok != true || !mounted) return;
    final name = nameCtrl.text.trim();
    final phone = phoneCtrl.text.trim();
    if (name.isEmpty || phone.length < 8) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nama dan nomor wajib diisi')),
      );
      return;
    }

    try {
      await ref.read(apiClientProvider).post(
        '/api/v1/guardians/invite',
        body: {
          'childId': selected.id,
          'guardianName': name,
          'guardianPhone': phone,
        },
      );
      await _loadAll();

      final message =
          'Halo $name, kamu diundang jadi Wali Terpercaya untuk '
          '${selected.name} di PulangAman. '
          'Download aplikasi lalu masuk dengan nomor $phone untuk menerima undangan.';

      if (channel == 'whatsapp') {
        final digits = phone.replaceAll(RegExp(r'[^\d]'), '');
        final uri = Uri.parse(
          'https://wa.me/$digits?text=${Uri.encodeComponent(message)}',
        );
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (channel == 'email') {
        final email = emailCtrl.text.trim();
        final uri = Uri(
          scheme: 'mailto',
          path: email.isEmpty ? null : email,
          queryParameters: {
            'subject': 'Undangan Wali Terpercaya PulangAman',
            'body': message,
          },
        );
        await launchUrl(uri);
      } else {
        await Clipboard.setData(ClipboardData(text: message));
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Link undangan disalin')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal undang: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final children = ref.watch(childrenControllerProvider);
    final auth = ref.watch(authControllerProvider);
    final guardians = _activeGuardians;
    final activeCount = guardians.length;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wali Terpercaya',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          '$activeCount wali aktif',
                          style: const TextStyle(
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
            Expanded(
              child: RefreshIndicator(
                color: AppColors.teal,
                onRefresh: _loadAll,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDCEBFF),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            color: Color(0xFFE8913A),
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Undang wali yang sudah dikenal. Tidak ada pencarian '
                              'orang asing demi keamanan anak.',
                              style: TextStyle(
                                color: Color(0xFF1E3A5F),
                                fontWeight: FontWeight.w600,
                                height: 1.35,
                                fontSize: 13.5,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel('WALI AKTIF'),
                    const SizedBox(height: 8),
                    Container(
                      decoration: _cardDecoration,
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.tealDeep,
                                  child: Text(
                                    _initials(auth.name),
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w900,
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
                                        auth.name ?? 'Orang tua',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w900,
                                          fontSize: 15.5,
                                        ),
                                      ),
                                      const Text(
                                        'Admin · Semua anak',
                                        style: TextStyle(
                                          color: AppColors.inkSoft,
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFD8F5E8),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'ANDA',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.tealDeep,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (_loading)
                            const Padding(
                              padding: EdgeInsets.all(20),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else
                            ...guardians.map((g) {
                              return Column(
                                children: [
                                  const Divider(height: 1, indent: 14, endIndent: 14),
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                      14,
                                      12,
                                      14,
                                      12,
                                    ),
                                    child: Row(
                                      children: [
                                        CircleAvatar(
                                          radius: 22,
                                          backgroundColor:
                                              const Color(0xFFDCEBFF),
                                          child: Text(
                                            _initials(g.name),
                                            style: const TextStyle(
                                              color: Color(0xFF2563EB),
                                              fontWeight: FontWeight.w900,
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
                                                g.name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w900,
                                                  fontSize: 15,
                                                ),
                                              ),
                                              Text(
                                                g.status == 'invited'
                                                    ? 'Menunggu · ${g.childNames.join(', ')}'
                                                    : 'Aktif · ${g.childNames.join(', ')}',
                                                style: const TextStyle(
                                                  color: AppColors.inkSoft,
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12.5,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const _SectionLabel('AKSES PER ANAK'),
                    const SizedBox(height: 8),
                    if (children.items.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: _cardDecoration,
                        child: const Text(
                          AppStrings.noChildren,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.inkSoft),
                        ),
                      )
                    else
                      Container(
                        decoration: _cardDecoration,
                        child: Column(
                          children: [
                            for (var i = 0; i < children.items.length; i++) ...[
                              if (i > 0)
                                const Divider(
                                  height: 1,
                                  indent: 70,
                                  endIndent: 14,
                                ),
                              _ChildAccessRow(
                                child: children.items[i],
                                gender: _genders[children.items[i].id] ??
                                    ChildGenderStore.guessFromName(
                                      children.items[i].name,
                                    ),
                                guardians: (_byChild[children.items[i].id] ??
                                        const [])
                                    .where((g) => g['status'] != 'revoked')
                                    .toList(),
                                onTap: () => _openChild(children.items[i]),
                              ),
                            ],
                          ],
                        ),
                      ),
                    const SizedBox(height: 20),
                    const _SectionLabel('UNDANG WALI BARU'),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                      decoration: _cardDecoration,
                      child: Column(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3E8FF),
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: const Icon(
                              Icons.person_add_alt_1_rounded,
                              color: Color(0xFF7C3AED),
                              size: 28,
                            ),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Tambah Wali Terpercaya',
                            style: TextStyle(
                              fontWeight: FontWeight.w900,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Wali akan menerima undangan via WhatsApp atau email',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: AppColors.inkSoft,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _InviteChannelButton(
                                  icon: Icons.chat_rounded,
                                  label: 'WhatsApp',
                                  bg: const Color(0xFFD8F5E8),
                                  fg: AppColors.tealDeep,
                                  onTap: () => _inviteFlow('whatsapp'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _InviteChannelButton(
                                  icon: Icons.email_outlined,
                                  label: 'Email',
                                  bg: const Color(0xFFDCEBFF),
                                  fg: const Color(0xFF2563EB),
                                  onTap: () => _inviteFlow('email'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _InviteChannelButton(
                                  icon: Icons.link_rounded,
                                  label: 'Link',
                                  bg: const Color(0xFFE8ECF0),
                                  fg: AppColors.ink,
                                  onTap: () => _inviteFlow('link'),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
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

final BoxDecoration _cardDecoration = BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(18),
  boxShadow: [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.05),
      blurRadius: 14,
      offset: const Offset(0, 5),
    ),
  ],
);

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.8,
        color: AppColors.inkSoft,
      ),
    );
  }
}

class _ChildAccessRow extends StatelessWidget {
  const _ChildAccessRow({
    required this.child,
    required this.gender,
    required this.guardians,
    required this.onTap,
  });

  final ChildSummary child;
  final ChildGender gender;
  final List<Map<String, dynamic>> guardians;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final names = guardians
        .map((g) => g['name']?.toString() ?? '')
        .where((n) => n.isNotEmpty)
        .take(2)
        .join(', ');
    final subtitle = guardians.isEmpty
        ? '0 wali · Tambah wali'
        : '${guardians.length} wali${names.isEmpty ? '' : ' · $names'}';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
          child: Row(
            children: [
              ChildAvatar(name: child.name, gender: gender, size: 44),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 15.5,
                      ),
                    ),
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
              const Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteChannelButton extends StatelessWidget {
  const _InviteChannelButton({
    required this.icon,
    required this.label,
    required this.bg,
    required this.fg,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color bg;
  final Color fg;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: fg, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 12.5,
                  color: fg,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Detail wali untuk satu anak.
class GuardiansScreen extends ConsumerStatefulWidget {
  const GuardiansScreen({super.key, required this.child});

  final ChildSummary child;

  @override
  ConsumerState<GuardiansScreen> createState() => _GuardiansScreenState();
}

class _GuardiansScreenState extends ConsumerState<GuardiansScreen> {
  List<Map<String, dynamic>> _guardians = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiClientProvider);
      final data = await api.get('/api/v1/guardians', query: {
        'childId': widget.child.id,
      });
      setState(() {
        _guardians = (data['guardians'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .toList();
        _loading = false;
      });
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  Future<void> _invite() async {
    final nameCtrl = TextEditingController();
    final phoneCtrl = TextEditingController(text: '+62');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text(AppStrings.inviteGuardian),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration:
                  const InputDecoration(labelText: AppStrings.nameLabel),
            ),
            TextField(
              controller: phoneCtrl,
              decoration:
                  const InputDecoration(labelText: AppStrings.phoneLabel),
              keyboardType: TextInputType.phone,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.teal),
            child: const Text(AppStrings.save),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final api = ref.read(apiClientProvider);
      await api.post('/api/v1/guardians/invite', body: {
        'childId': widget.child.id,
        'guardianName': nameCtrl.text.trim(),
        'guardianPhone': phoneCtrl.text.trim(),
      });
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal: $e')),
      );
    }
  }

  Future<void> _revoke(String guardianId) async {
    final api = ref.read(apiClientProvider);
    await api.post('/api/v1/guardians/revoke', body: {
      'childId': widget.child.id,
      'guardianId': guardianId,
    });
    await _load();
  }

  String _firstLetter(String? name) {
    final t = (name ?? '').trim();
    if (t.isEmpty) return 'W';
    return t[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final active = _guardians.where((g) => g['status'] != 'revoked').toList();
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _invite,
        backgroundColor: AppColors.teal,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text(AppStrings.inviteGuardian),
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
                  Expanded(
                    child: Text(
                      'Wali · ${widget.child.name}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : RefreshIndicator(
                      color: AppColors.teal,
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                        children: [
                          if (active.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(24),
                              decoration: _cardDecoration,
                              child: const Text(
                                'Belum ada wali untuk anak ini.',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: AppColors.inkSoft,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            )
                          else
                            ...active.map((g) {
                              final status = g['status']?.toString() ?? '';
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(
                                    14,
                                    12,
                                    8,
                                    12,
                                  ),
                                  decoration: _cardDecoration,
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 22,
                                        backgroundColor:
                                            const Color(0xFFDCEBFF),
                                        child: Text(
                                          _firstLetter(g['name']?.toString()),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w900,
                                            color: Color(0xFF2563EB),
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
                                              '${g['name']}',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w900,
                                              ),
                                            ),
                                            Text(
                                              '${g['phone']} · $status',
                                              style: const TextStyle(
                                                color: AppColors.inkSoft,
                                                fontWeight: FontWeight.w600,
                                                fontSize: 12.5,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Cabut akses',
                                        icon: const Icon(
                                          Icons.block,
                                          color: AppColors.danger,
                                        ),
                                        onPressed: () => _revoke(
                                          g['guardian_id'] as String,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }),
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
