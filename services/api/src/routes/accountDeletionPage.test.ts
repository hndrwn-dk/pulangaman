import assert from 'node:assert/strict';
import http from 'node:http';
import { describe, it } from 'node:test';
import express from 'express';
import {
  PUBLIC_ACCOUNT_DELETION_URL,
  accountDeletionPageRouter,
} from './accountDeletionPage.js';

describe('GET /account-deletion', () => {
  it('redirects to the public tursinalabs.com deletion page', async () => {
    const app = express();
    app.use(accountDeletionPageRouter);
    const server = http.createServer(app);
    await new Promise<void>((resolve) => {
      server.listen(0, '127.0.0.1', () => resolve());
    });
    const addr = server.address();
    const port = typeof addr === 'object' && addr ? addr.port : 0;

    try {
      const res = await fetch(`http://127.0.0.1:${port}/account-deletion`, {
        redirect: 'manual',
      });
      assert.equal(res.status, 302);
      assert.equal(res.headers.get('location'), PUBLIC_ACCOUNT_DELETION_URL);
      assert.equal(
        PUBLIC_ACCOUNT_DELETION_URL,
        'https://www.tursinalabs.com/pulangaman/account-deletion',
      );
    } finally {
      await new Promise<void>((resolve, reject) => {
        server.close((err) => (err ? reject(err) : resolve()));
      });
    }
  });
});
