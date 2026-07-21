import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme.dart';
import 'child_avatar.dart';
import 'children_controller.dart';
import 'zone_alert_host.dart';

/// Featured child card on parent home: map preview + status + quick metrics.
class ChildHomeMapCard extends StatelessWidget {
  const ChildHomeMapCard({
    super.key,
    required this.child,
    required this.gender,
    required this.position,
    required this.onOpenMap,
    this.batteryLevel,
    this.batteryCharging = false,
    this.stale = true,
    this.updatedAt,
    this.stayDurationLabel,
    this.onRelinkCode,
    this.onRemove,
  });

  final ChildSummary child;
  final ChildGender gender;
  final LatLng? position;
  final VoidCallback onOpenMap;
  final int? batteryLevel;
  final bool batteryCharging;
  final bool stale;
  final DateTime? updatedAt;
  final String? stayDurationLabel;
  final VoidCallback? onRelinkCode;
  final VoidCallback? onRemove;

  String get _where {
    final label = commuteStatusLabel(child.commuteStatus);
    if (label.isNotEmpty) {
      if (child.commuteStatus == 'home') return 'Di rumah · Sudah sampai';
      return label;
    }
    return position == null ? 'Lokasi belum jelas' : 'Terlihat di peta';
  }

  String get _whenBubble {
    if (position == null) return 'Menunggu lokasi...';
    final at = updatedAt ??
        (child.lastSeenAt != null
            ? DateTime.tryParse(child.lastSeenAt!)?.toLocal()
            : null);
    if (at == null) return 'Di sini';
    final hm =
        '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
    return 'Di sini · $hm';
  }

  String get _signalLabel {
    if (position == null || updatedAt == null) return 'Hilang';
    final age = DateTime.now().difference(updatedAt!);
    if (stale || age.inMinutes >= 30) return 'Lemah';
    if (age.inMinutes >= 10) return 'Sedang';
    return 'Kuat';
  }

  Color get _signalColor {
    switch (_signalLabel) {
      case 'Kuat':
        return const Color(0xFF3B82F6);
      case 'Sedang':
        return const Color(0xFFF59E0B);
      default:
        return AppColors.inkSoft;
    }
  }

  String get _batteryLabel {
    final v = batteryLevel;
    if (v == null) return '—';
    return batteryCharging ? '$v%+' : '$v%';
  }

  @override
  Widget build(BuildContext context) {
    final active = !stale && position != null;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onOpenMap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.07),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 168,
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(24),
                  ),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      if (position != null)
                        GoogleMap(
                          key: ValueKey(
                            '${child.id}-${position!.latitude.toStringAsFixed(5)}-'
                            '${position!.longitude.toStringAsFixed(5)}',
                          ),
                          initialCameraPosition: CameraPosition(
                            target: position!,
                            zoom: 15,
                          ),
                          liteModeEnabled: true,
                          markers: {
                            Marker(
                              markerId: MarkerId(child.id),
                              position: position!,
                            ),
                          },
                          zoomControlsEnabled: false,
                          myLocationButtonEnabled: false,
                          mapToolbarEnabled: false,
                          compassEnabled: false,
                          rotateGesturesEnabled: false,
                          scrollGesturesEnabled: false,
                          tiltGesturesEnabled: false,
                          zoomGesturesEnabled: false,
                          onTap: (_) => onOpenMap(),
                        )
                      else
                        Container(
                          color: AppColors.mint.withValues(alpha: 0.55),
                          child: const Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.map_outlined,
                                  size: 36,
                                  color: AppColors.tealDeep,
                                ),
                                SizedBox(height: 6),
                                Text(
                                  'Menunggu lokasi...',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.tealDeep,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      Positioned(
                        left: 14,
                        right: 14,
                        top: 12,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 7,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.tealDeep,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              _whenBubble,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 12.5,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 8, 14),
                child: Column(
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ChildAvatar(
                          name: child.name,
                          gender: gender,
                          size: 46,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      child.name,
                                      style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: active
                                          ? const Color(0xFFD8F5E8)
                                          : const Color(0xFFFFF0E0),
                                      borderRadius: BorderRadius.circular(999),
                                    ),
                                    child: Text(
                                      active ? 'AKTIF' : 'LAMA',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w900,
                                        letterSpacing: 0.4,
                                        color: active
                                            ? AppColors.tealDeep
                                            : const Color(0xFFC46A0A),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Container(
                                    width: 7,
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: active
                                          ? AppColors.teal
                                          : const Color(0xFFE8A11A),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      _where,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w700,
                                        color: position == null
                                            ? AppColors.inkSoft
                                            : AppColors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (onRelinkCode != null || onRemove != null)
                          PopupMenuButton<String>(
                            tooltip: 'Opsi',
                            padding: EdgeInsets.zero,
                            onSelected: (value) {
                              if (value == 'relink') onRelinkCode?.call();
                              if (value == 'remove') onRemove?.call();
                            },
                            itemBuilder: (context) => [
                              if (onRelinkCode != null)
                                PopupMenuItem(
                                  value: 'relink',
                                  child:
                                      Text('Kode masuk ulang ${child.name}'),
                                ),
                              if (onRemove != null)
                                const PopupMenuItem(
                                  value: 'remove',
                                  child: Text('Hapus dari daftar'),
                                ),
                            ],
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: _MetricChip(
                            icon: Icons.battery_std_rounded,
                            iconColor: AppColors.teal,
                            label: 'Baterai',
                            value: _batteryLabel,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricChip(
                            icon: Icons.signal_cellular_alt_rounded,
                            iconColor: _signalColor,
                            label: 'Sinyal',
                            value: _signalLabel,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _MetricChip(
                            icon: Icons.timer_outlined,
                            iconColor: const Color(0xFF8B5CF6),
                            label: 'Waktu',
                            value: stayDurationLabel ?? '—',
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
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F5F7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: iconColor),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.inkSoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
            ),
          ),
        ],
      ),
    );
  }
}
