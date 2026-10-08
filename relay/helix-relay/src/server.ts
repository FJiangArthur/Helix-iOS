import { realpathSync } from 'node:fs';
import { pathToFileURL } from 'node:url';
import type { FastifyInstance } from 'fastify';
import { buildApp } from './app.js';
import { loadConfig, type Config } from './config.js';
import { LlmClient } from './llm.js';
import { refresh, startScheduler } from './refresh.js';
import { OmiMcpClient } from './sources/mcp.js';
import { fetchFinnhub, fetchRss } from './sources/news.js';
import { OmiClient } from './sources/omi.js';
import { Store } from './store.js';

export interface Relay {
  app: FastifyInstance;
  store: Store;
  refreshOnce: () => Promise<void>;
}

/** Wire real upstream clients into the HTTP app. Does no I/O until a route or refresh runs. */
export function createRelay(config: Config, opts: { logger: boolean } = { logger: true }): Relay {
  const store = Store.forDataDir(config.dataDir);
  const omi = new OmiClient({ baseUrl: config.omiBaseUrl, key: config.omiDevKey, timeoutMs: config.upstreamTimeoutMs });
  const llm = new LlmClient({ baseUrl: config.codexProxyUrl, key: config.codexProxyKey, timeoutMs: config.upstreamTimeoutMs });
  // Placeholder logger until the app (and its pino logger) exists.
  let log: (msg: string) => void = () => {};
  const mcp = new OmiMcpClient(
    { url: config.omiMcpUrl, key: config.omiMcpKey, timeoutMs: config.upstreamTimeoutMs },
    (m) => log(m),
  );

  const app = buildApp({
    config,
    store,
    patchTodo: (id, completed) => omi.patchActionItem(id, completed),
    streamChat: (req, signal) => llm.streamChat(req, signal),
    now: Date.now,
    logger: opts.logger,
  });
  log = (m) => app.log.warn(m);

  const refreshOnce = () =>
    refresh(
      store,
      {
        listActionItems: () => omi.listActionItems(),
        listMemories: () => omi.listMemories(),
        getXPosts: () => mcp.getXPosts(20),
        fetchFinnhub: () =>
          fetchFinnhub({ baseUrl: config.finnhubBaseUrl, key: config.finnhubKey, timeoutMs: config.upstreamTimeoutMs }),
        fetchRss: () => fetchRss(config.rssFeeds, config.upstreamTimeoutMs, (feed, e) => log(`rss ${feed}: ${String(e)}`)),
        triage: (messages) => llm.complete({ model: config.model, messages }),
      },
      { now: Date.now, timeZone: config.timeZone, log: (m) => log(m) },
    );

  return { app, store, refreshOnce };
}

async function main(): Promise<void> {
  const config = loadConfig();
  const relay = createRelay(config);
  await relay.store.load();
  const stop = startScheduler(
    async () => {
      await relay.refreshOnce();
      relay.app.log.info('refresh complete');
    },
    config.refreshMinutes,
    (m) => relay.app.log.error(m),
  );
  await relay.app.listen({ host: config.host, port: config.port });
  if (config.host !== '127.0.0.1' && config.host !== '::1' && config.host !== 'localhost') {
    relay.app.log.warn(`listening on ${config.host}: expose only inside your tailnet`);
  }
  const shutdown = async (sig: string) => {
    relay.app.log.info(`${sig}: shutting down`);
    stop();
    await relay.app.close();
    process.exit(0);
  };
  process.once('SIGINT', () => void shutdown('SIGINT'));
  process.once('SIGTERM', () => void shutdown('SIGTERM'));
}

const isEntry = (() => {
  try {
    return !!process.argv[1] && import.meta.url === pathToFileURL(realpathSync(process.argv[1])).href;
  } catch {
    return false;
  }
})();

if (isEntry) {
  main().catch((e: unknown) => {
    console.error(`helix-relay failed to start: ${e instanceof Error ? e.message : String(e)}`);
    process.exit(1);
  });
}
