/** Community-report helpers used by the route and unit tests. */

/** ~111m grid — do not return or store street-level pins on community reports. */
export function snapReportCoord(value: number): number {
  return Math.round(value * 1000) / 1000;
}

export function canCreateCommunityReport(roles: string[]): boolean {
  return roles.some(
    (role) => role === 'parent' || role === 'guardian' || role === 'school_admin',
  );
}

export function canModerateCommunityReport(roles: string[]): boolean {
  return roles.some((role) => role === 'parent' || role === 'school_admin');
}

export type ReportRow = {
  id: string;
  category: string;
  note: string | null;
  status: string;
  expires_at: Date | string;
  created_at: Date | string;
  verified_at: Date | string | null;
  lat: number | string;
  lng: number | string;
};

/** Public payload: no reporter id/name and snapped coordinates only. */
export function publicReportPayload(row: ReportRow): {
  id: string;
  category: string;
  note: string | null;
  status: string;
  expires_at: Date | string;
  created_at: Date | string;
  verified_at: Date | string | null;
  lat: number;
  lng: number;
} {
  return {
    id: row.id,
    category: row.category,
    note: row.note,
    status: row.status,
    expires_at: row.expires_at,
    created_at: row.created_at,
    verified_at: row.verified_at,
    lat: snapReportCoord(Number(row.lat)),
    lng: snapReportCoord(Number(row.lng)),
  };
}
