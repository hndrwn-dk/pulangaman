import assert from 'node:assert/strict';
import http from 'node:http';
import { describe, it } from 'node:test';
import express from 'express';
import {
  ACCOUNT_DELETION_HTML,
  accountDeletionPageRouter,
} from './accountDeletionPage.js';

describe('GET /account-deletion', () => {
  it('serves a public HTML page with OTP flow and mailto fallback', async () => {
    const app = express();
    app.use(accountDeletionPageRouter);
    const server = http.createServer(app);
    await new Promise<void>((resolve) => {
      server.listen(0, '127.0.0.1', () => resolve());
    });
    const addr = server.address();
    const port = typeof addr === 'object' && addr ? addr.port : 0;

    try {
      const res = await fetch(`http://127.0.0.1:${port}/account-deletion`);
      assert.equal(res.status, 200);
      assert.match(res.headers.get('content-type') ?? '', /html/);
      const html = await res.text();
      assert.equal(html, ACCOUNT_DELETION_HTML);
      assert.match(html, /PulangAman — Hapus Akun/);
      assert.match(html, /Kirim kode OTP/);
      assert.match(html, /Verifikasi &amp; Hapus Akun/);
      assert.match(html, /signInWithPhoneNumber/);
      assert.match(html, /fetch\("\/api\/v1\/account"/);
      assert.match(html, /child_deletion_requires_parent/);
      assert.match(html, /Akun dan data Anda telah dihapus/);
      assert.match(
        html,
        /mailto:support@tursinalabs.com\?subject=Permintaan%20Hapus%20Akun%20PulangAman/,
      );
      assert.match(html, /pulangaman-6e0ad\.firebaseapp\.com/);
      assert.match(html, /1:690043121132:web:b7581a17af238aaa95e4c9/);
    } finally {
      await new Promise<void>((resolve, reject) => {
        server.close((err) => (err ? reject(err) : resolve()));
      });
    }
  });
});
