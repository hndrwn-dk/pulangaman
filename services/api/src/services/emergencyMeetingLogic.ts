export type ActivateTargetInput = {
  childId: string;
  childName: string;
  meetingPointId: string | null;
  meetingPointName: string | null;
  guardianIds: string[];
};

export type ActivateTargetResult = {
  childId: string;
  childName: string;
  meetingPointId: string | null;
  meetingPointName: string | null;
  notified: boolean;
  reason?: 'no_point_configured';
  guardianIds: string[];
};

/** Build activation snapshot; children without a primary point are not notified. */
export function buildActivationTargets(
  children: ActivateTargetInput[],
): ActivateTargetResult[] {
  return children.map((c) => {
    if (!c.meetingPointId || !c.meetingPointName) {
      return {
        childId: c.childId,
        childName: c.childName,
        meetingPointId: null,
        meetingPointName: null,
        notified: false,
        reason: 'no_point_configured',
        guardianIds: [],
      };
    }
    return {
      childId: c.childId,
      childName: c.childName,
      meetingPointId: c.meetingPointId,
      meetingPointName: c.meetingPointName,
      notified: true,
      guardianIds: [...new Set(c.guardianIds)],
    };
  });
}

/** Unique guardian IDs across notified children (no duplicate FCM). */
export function uniqueGuardianIds(targets: ActivateTargetResult[]): string[] {
  const set = new Set<string>();
  for (const t of targets) {
    if (!t.notified) continue;
    for (const g of t.guardianIds) set.add(g);
  }
  return [...set];
}

export function haversineMeters(
  a: { lat: number; lng: number },
  b: { lat: number; lng: number },
): number {
  const R = 6371000;
  const toRad = (d: number) => (d * Math.PI) / 180;
  const dLat = toRad(b.lat - a.lat);
  const dLng = toRad(b.lng - a.lng);
  const lat1 = toRad(a.lat);
  const lat2 = toRad(b.lat);
  const h =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(lat1) * Math.cos(lat2) * Math.sin(dLng / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(h));
}

/** A child within this radius of their meeting point counts as arrived. */
export const ARRIVAL_RADIUS_METERS = 150;

export function isArrivedAt(
  distanceMeters: number | null,
  radiusM: number = ARRIVAL_RADIUS_METERS,
): boolean {
  if (distanceMeters == null || !Number.isFinite(distanceMeters)) return false;
  return distanceMeters <= radiusM;
}

export function formatDistanceLabel(meters: number | null): string {
  if (meters == null || !Number.isFinite(meters)) return '';
  if (meters >= 1000) return `${(meters / 1000).toFixed(1)} km`;
  return `${Math.round(meters)} m`;
}
