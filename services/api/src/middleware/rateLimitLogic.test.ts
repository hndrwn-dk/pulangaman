import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import { shouldBypassRateLimit } from './rateLimitLogic.js';

describe('shouldBypassRateLimit', () => {
  it('lets DELETE through so parent polling cannot starve child deletion', () => {
    assert.equal(shouldBypassRateLimit('DELETE'), true);
    assert.equal(shouldBypassRateLimit('delete'), true);
  });

  it('still limits reads and other writes', () => {
    assert.equal(shouldBypassRateLimit('GET'), false);
    assert.equal(shouldBypassRateLimit('POST'), false);
    assert.equal(shouldBypassRateLimit('PUT'), false);
  });
});
