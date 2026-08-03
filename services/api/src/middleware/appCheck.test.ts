import assert from 'node:assert/strict';
import { describe, it } from 'node:test';
import type { NextFunction, Request, Response } from 'express';
import { config } from '../config.js';
import { requireAppCheck } from './appCheck.js';

function mockRes() {
  const state: { statusCode?: number; body?: unknown } = {};
  const res = {
    status(code: number) {
      state.statusCode = code;
      return this;
    },
    json(body: unknown) {
      state.body = body;
      return this;
    },
  } as unknown as Response;
  return { res, state };
}

describe('requireAppCheck', () => {
  it('defaults APP_CHECK_ENFORCE to false (monitor mode)', () => {
    assert.equal(config.APP_CHECK_ENFORCE, false);
  });

  it('allows missing token in monitor mode', async () => {
    assert.equal(config.APP_CHECK_ENFORCE, false);
    const { res, state } = mockRes();
    let nextCalled = false;
    const next: NextFunction = () => {
      nextCalled = true;
    };
    const req = {
      header: () => undefined,
      path: '/join',
    } as unknown as Request;

    await requireAppCheck(req, res, next);

    assert.equal(nextCalled, true);
    assert.equal(state.statusCode, undefined);
  });
});
