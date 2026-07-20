import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../core/theme.dart';
import 'child_avatar.dart';
import 'children_controller.dart';
import 'kabar_models.dart';
import 'zone_alert_host.dart';

/// Find My Kids–inspired child card: map preview + status strip.
class ChildHomeMapCard extends StatelessWidget {
  const ChildHomeMapCard({
    super.key,
    required this.child,
    required this.gender,
    required this.position,
    required this.onOpenMap,
    this.kabar,
    this.onOpenKabar,
  });

  final ChildSummary child;
  final ChildGender gender;
  final LatLng? position;
  final VoidCallback onOpenMap;
  final ChildKabarMessage? kabar;
  final VoidCallback? onOpenKabar;

  String get _where {
    final label = commuteStatusLabel(child.commuteStatus);
    if (label.isNotEmpty) return label;
    return position == null ? 'Lokasi belum jelas' : 'Terlihat di peta';
  }

  String get _whenBubble {
    final raw = child.lastSeenAt;
    if (raw == null || raw.isEmpty) return 'Belum ada sinyal';
    final at = DateTime.tryParse(raw);
    if (at == null) return formatLastSeen(raw);
    final local = at.toLocal();
    final now = DateTime.now();
    final sameDay = local.year == now.year &&
        local.month == now.month &&
        local.day == now.day;
    final hm =
        '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
    if (sameDay) return 'Di sini · $hm';
    return 'Di sini · ${local.day}/${local.month} $hm';
  }

  @override
  Widget build(BuildContext context) {
    final urgent = kabar?.isUrgent == true;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onOpenMap,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: urgent
                  ? AppColors.coral.withValues(alpha: 0.55)
                  : AppColors.teal.withValues(alpha: 0.35),
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 188,
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
                                size: 40,
                                color: AppColors.tealDeep,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Menunggu lokasi anak...',
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
                      left: 12,
                      right: 12,
                      top: 12,
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.tealDeep,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _whenBubble,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ChildAvatar(
                      name: child.name,
                      gender: gender,
                      size: 48,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.name,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _where,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: position == null &&
                                      commuteStatusLabel(child.commuteStatus)
                                          .isEmpty
                                  ? AppColors.inkSoft
                                  : AppColors.tealDeep,
                            ),
                          ),
                          if (kabar != null) ...[
                            const SizedBox(height: 6),
                            InkWell(
                              onTap: onOpenKabar,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    urgent
                                        ? Icons.priority_high_rounded
                                        : Icons.chat_bubble_outline,
                                    size: 18,
                                    color: urgent
                                        ? AppColors.coral
                                        : AppColors.teal,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      kabar!.text,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        height: 1.3,
                                        color: urgent
                                            ? AppColors.coral
                                            : AppColors.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            'Ketuk kartu untuk buka peta',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.inkSoft.withValues(alpha: 0.9),
                            ),
                          ),
                        ],
                      ),
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
