import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import {
  canCreateCommunityReport,
  canModerateCommunityReport,
  publicReportPayload,
  snapReportCoord,
} from './reportsLogic.js';

describe('snapReportCoord', () => {
  it('rounds to ~111m grid', () => {
    assert.equal(snapReportCoord(-6.208876), -6.209);
    assert.equal(snapReportCoord(106.845599), 106.846);
  });
});

describe('canCreateCommunityReport', () => {
  it('allows parent, guardian, and school admin', () => {
    assert.equal(canCreateCommunityReport(['parent']), true);
    assert.equal(canCreateCommunityReport(['guardian']), true);
    assert.equal(canCreateCommunityReport(['school_admin']), true);
  });

  it('blocks child accounts', () => {
    assert.equal(canCreateCommunityReport(['child']), false);
    assert.equal(canCreateCommunityReport([]), false);
  });
});

describe('canModerateCommunityReport', () => {
  it('allows parent and school admin to remove', () => {
    assert.equal(canModerateCommunityReport(['parent']), true);
    assert.equal(canModerateCommunityReport(['school_admin']), true);
    assert.equal(canModerateCommunityReport(['guardian']), false);
    assert.equal(canModerateCommunityReport(['child']), false);
  });
});

describe('publicReportPayload', () => {
  it('omits reporter identity and snaps coordinates', () => {
    const payload = publicReportPayload({
      id: 'r1',
      category: 'hazard',
      note: 'Jalan licin',
      status: 'active',
      expires_at: '2026-09-28T00:00:00.000Z',
      created_at: '2026-09-27T00:00:00.000Z',
      verified_at: null,
      lat: -6.208876,
      lng: 106.845599,
    });
    assert.equal(payload.lat, -6.209);
    assert.equal(payload.lng, 106.846);
    assert.equal('reporter_id' in payload, false);
    assert.equal('reporter_name' in payload, false);
  });
});
