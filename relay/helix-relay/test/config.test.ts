import { describe, expect, it } from 'vitest';
import { loadConfig } from '../src/config.js';
import { createRelay } from '../src/server.js';
import { keyMatches } from '../src/auth.js';

const KEY = 'k'.repeat(32);

describe('config', () => {
  it('defaults to loopback:8790, codex-proxy on 8787, gpt-5.4 / gpt-5.5, 15 min', () => {
    const c = loadConfig({ HELIX_RELAY_KEY: KEY });
    expect(c.host).toBe('127.0.0.1');
    expect(c.port).toBe(8790);
    expect(c.codexProxyUrl).toBe('http://127.0.0.1:8787/v1');
    expect(c.model).toBe('gpt-5.4');
    expect(c.deepModel).toBe('gpt-5.5');
    expect(c.refreshMinutes).toBe(15);
    expect(c.omiMcpUrl).toBe('https://api.omi.me/v1/mcp');
    expect(c.omiDevKey).toBeUndefined();
    expect(c.dataDir).toMatch(/helix-relay[/\\]data$/);
  });

  it('parses env overrides and the RSS list', () => {
    const c = loadConfig({
      HELIX_RELAY_KEY: KEY,
      PORT: '9000',
      HOST: '0.0.0.0',
      RSS_FEEDS: ' https://a.example/rss , ,https://b.example/atom ',
      CODEX_PROXY_URL: 'http://127.0.0.1:9999/v1/',
    });
    expect(c.port).toBe(9000);
    expect(c.host).toBe('0.0.0.0');
    expect(c.rssFeeds).toEqual(['https://a.example/rss', 'https://b.example/atom']);
    expect(c.codexProxyUrl).toBe('http://127.0.0.1:9999/v1');
  });

  it('refuses to start without a strong relay key or with a bad port', () => {
    expect(() => loadConfig({})).toThrow(/HELIX_RELAY_KEY/);
    expect(() => loadConfig({ HELIX_RELAY_KEY: 'short' })).toThrow(/HELIX_RELAY_KEY/);
    expect(() => loadConfig({ HELIX_RELAY_KEY: KEY, PORT: 'abc' })).toThrow(/PORT/);
  });
});

describe('auth helper', () => {
  it('compares bearer keys exactly', () => {
    expect(keyMatches(`Bearer ${KEY}`, KEY)).toBe(true);
    expect(keyMatches(`bearer ${KEY}`, KEY)).toBe(true);
    expect(keyMatches(`Bearer ${KEY.slice(1)}`, KEY)).toBe(false);
    expect(keyMatches(undefined, KEY)).toBe(false);
  });
});

describe('wiring', () => {
  it('createRelay builds an app with real clients without touching the network', async () => {
    const relay = createRelay(loadConfig({ HELIX_RELAY_KEY: KEY, RELAY_DATA_DIR: '/nonexistent-helix-relay' }), { logger: false });
    const res = await relay.app.inject({ method: 'GET', url: '/health' });
    expect(res.json()).toEqual({ ok: true, version: '0.3.0' });
    expect(typeof relay.refreshOnce).toBe('function');
    await relay.app.close();
  });
});
