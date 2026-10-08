import { afterEach, describe, expect, it } from 'vitest';
import type { FastifyInstance } from 'fastify';
import { buildTestApp, KEY } from './helpers.js';

let app: FastifyInstance;
afterEach(async () => {
  await app?.close();
});

describe('auth + health + CORS', () => {
  it('GET /health needs no auth and reports version 0.3.0', async () => {
    app = buildTestApp();
    const res = await app.inject({ method: 'GET', url: '/health' });
    expect(res.statusCode).toBe(200);
    expect(res.json()).toEqual({ ok: true, version: '0.3.0' });
  });

  it.each([
    ['missing header', undefined],
    ['wrong key', `Bearer ${KEY}x`],
    ['wrong scheme', `Basic ${KEY}`],
    ['empty bearer', 'Bearer '],
  ])('rejects %s with 401 JSON', async (_label, auth) => {
    app = buildTestApp();
    const headers: Record<string, string> = auth ? { authorization: auth } : {};
    for (const [method, url] of [
      ['GET', '/dashboard'],
      ['GET', '/reminders?since=0'],
      ['PATCH', '/todos/t1'],
      ['POST', '/ask'],
      ['GET', '/nope'],
    ] as const) {
      const res = await app.inject({ method, url, headers });
      expect(res.statusCode, `${method} ${url}`).toBe(401);
      expect(res.json()).toEqual({ error: 'unauthorized' });
      expect(res.headers['content-type']).toMatch(/application\/json/);
    }
  });

  it('accepts the correct bearer key', async () => {
    app = buildTestApp();
    const res = await app.inject({ method: 'GET', url: '/dashboard', headers: { authorization: `Bearer ${KEY}` } });
    expect(res.statusCode).toBe(200);
  });

  it('answers CORS preflight for any origin without auth', async () => {
    app = buildTestApp();
    const res = await app.inject({
      method: 'OPTIONS',
      url: '/dashboard',
      headers: {
        origin: 'https://even-hub.example',
        'access-control-request-method': 'GET',
        'access-control-request-headers': 'authorization',
      },
    });
    expect(res.statusCode).toBe(204);
    expect(res.headers['access-control-allow-origin']).toBe('https://even-hub.example');
    expect(res.headers['access-control-allow-headers']).toBe('authorization, content-type');
    expect(String(res.headers['access-control-allow-methods'])).toContain('PATCH');
  });

  it('adds CORS headers to normal and 401 responses', async () => {
    app = buildTestApp();
    const ok = await app.inject({
      method: 'GET',
      url: '/dashboard',
      headers: { origin: 'https://x.example', authorization: `Bearer ${KEY}` },
    });
    expect(ok.headers['access-control-allow-origin']).toBe('https://x.example');
    const denied = await app.inject({ method: 'GET', url: '/dashboard', headers: { origin: 'https://x.example' } });
    expect(denied.statusCode).toBe(401);
    expect(denied.headers['access-control-allow-origin']).toBe('https://x.example');
  });
});
