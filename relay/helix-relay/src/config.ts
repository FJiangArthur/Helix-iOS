import path from 'node:path';
import { fileURLToPath } from 'node:url';

export interface Config {
  relayKey: string;
  host: string;
  port: number;
  omiBaseUrl: string;
  omiDevKey: string | undefined;
  omiMcpUrl: string;
  omiMcpKey: string | undefined;
  finnhubBaseUrl: string;
  finnhubKey: string | undefined;
  rssFeeds: string[];
  codexProxyUrl: string;
  codexProxyKey: string | undefined;
  model: string;
  deepModel: string;
  dataDir: string;
  refreshMinutes: number;
  timeZone: string;
  upstreamTimeoutMs: number;
}

const DEFAULT_DATA_DIR = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..', 'data');

function opt(v: string | undefined): string | undefined {
  const t = v?.trim();
  return t ? t : undefined;
}

function int(v: string | undefined, dflt: number, name: string): number {
  if (v === undefined || v.trim() === '') return dflt;
  const n = Number(v);
  if (!Number.isInteger(n) || n <= 0) throw new Error(`${name} must be a positive integer`);
  return n;
}

export function loadConfig(env: Record<string, string | undefined> = process.env): Config {
  const relayKey = opt(env.HELIX_RELAY_KEY);
  if (!relayKey || relayKey.length < 24) {
    throw new Error('HELIX_RELAY_KEY is missing or shorter than 24 chars (run ./setup.sh to generate one)');
  }
  return {
    relayKey,
    host: opt(env.HOST) ?? '127.0.0.1',
    port: int(env.PORT, 8790, 'PORT'),
    omiBaseUrl: (opt(env.OMI_BASE_URL) ?? 'https://api.omi.me').replace(/\/+$/, ''),
    omiDevKey: opt(env.OMI_DEV_KEY),
    omiMcpUrl: opt(env.OMI_MCP_URL) ?? 'https://api.omi.me/v1/mcp',
    omiMcpKey: opt(env.OMI_MCP_KEY),
    finnhubBaseUrl: (opt(env.FINNHUB_BASE_URL) ?? 'https://finnhub.io').replace(/\/+$/, ''),
    finnhubKey: opt(env.FINNHUB_KEY),
    rssFeeds: (env.RSS_FEEDS ?? '')
      .split(',')
      .map((s) => s.trim())
      .filter(Boolean),
    codexProxyUrl: (opt(env.CODEX_PROXY_URL) ?? 'http://127.0.0.1:8787/v1').replace(/\/+$/, ''),
    codexProxyKey: opt(env.CODEX_PROXY_KEY),
    model: opt(env.RELAY_MODEL) ?? 'gpt-5.4',
    deepModel: opt(env.RELAY_DEEP_MODEL) ?? 'gpt-5.5',
    dataDir: opt(env.RELAY_DATA_DIR) ?? DEFAULT_DATA_DIR,
    refreshMinutes: int(env.REFRESH_MINUTES, 15, 'REFRESH_MINUTES'),
    timeZone: opt(env.RELAY_TZ) ?? Intl.DateTimeFormat().resolvedOptions().timeZone,
    upstreamTimeoutMs: int(env.UPSTREAM_TIMEOUT_MS, 20000, 'UPSTREAM_TIMEOUT_MS'),
  };
}
