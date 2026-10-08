import { buildApp, type AppDeps } from '../src/app.js';
import { loadConfig, type Config } from '../src/config.js';
import { Store } from '../src/store.js';

export const KEY = 'test-relay-key-0123456789abcdef';

export function testConfig(env: Record<string, string> = {}): Config {
  return loadConfig({
    HELIX_RELAY_KEY: KEY,
    OMI_DEV_KEY: 'omi_dev_test',
    OMI_MCP_KEY: 'omi_mcp_test',
    FINNHUB_KEY: 'fh_test',
    RSS_FEEDS: '',
    RELAY_DATA_DIR: '/nonexistent-helix-relay-test-dir',
    RELAY_TZ: 'America/Los_Angeles',
    ...env,
  });
}

export function buildTestApp(overrides: Partial<AppDeps> = {}) {
  const config = overrides.config ?? testConfig();
  const deps: AppDeps = {
    config,
    store: overrides.store ?? new Store(null),
    patchTodo:
      overrides.patchTodo ??
      (async () => {
        throw new Error('patchTodo not stubbed');
      }),
    streamChat:
      overrides.streamChat ??
      (async function* () {
        throw new Error('streamChat not stubbed');
      }),
    now: overrides.now ?? (() => Date.now()),
    logger: false,
  };
  return buildApp(deps);
}

export const auth = { authorization: `Bearer ${KEY}` };
