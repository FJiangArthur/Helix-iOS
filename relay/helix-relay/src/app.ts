import Fastify, { type FastifyInstance } from 'fastify';
import { keyMatches } from './auth.js';
import type { Config } from './config.js';
import type { Store } from './store.js';
import type { PatchTodo, StreamChat } from './types.js';

export const VERSION = '0.3.0';

export interface AppDeps {
  config: Config;
  store: Store;
  patchTodo: PatchTodo;
  streamChat: StreamChat;
  now: () => number;
  logger: boolean;
}

const ALLOW_HEADERS = 'authorization, content-type';
const ALLOW_METHODS = 'GET, POST, PATCH, OPTIONS';

export function buildApp(deps: AppDeps): FastifyInstance {
  const app = Fastify({
    logger: deps.logger ? { level: process.env.LOG_LEVEL ?? 'info' } : false,
    bodyLimit: 64 * 1024,
  });

  // CORS (CONTRACT-0.3 §7): any origin; the bearer key is the protection.
  app.addHook('onRequest', async (req, reply) => {
    const origin = req.headers.origin;
    reply.header('Access-Control-Allow-Origin', origin ?? '*');
    reply.header('Vary', 'Origin');
    if (req.method === 'OPTIONS') {
      reply
        .code(204)
        .header('Access-Control-Allow-Methods', ALLOW_METHODS)
        .header('Access-Control-Allow-Headers', ALLOW_HEADERS)
        .header('Access-Control-Max-Age', '600');
      return reply.send();
    }
    if (req.method === 'GET' && req.url.split('?')[0] === '/health') return;
    if (!keyMatches(req.headers.authorization, deps.config.relayKey)) {
      return reply.code(401).send({ error: 'unauthorized' });
    }
  });

  app.get('/health', async () => ({ ok: true, version: VERSION }));

  app.get('/dashboard', async () => deps.store.dashboard());

  return app;
}
