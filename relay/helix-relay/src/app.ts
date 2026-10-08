import Fastify, { type FastifyInstance } from 'fastify';
import { keyMatches } from './auth.js';
import type { Config } from './config.js';
import { UpstreamError } from './http.js';
import { buildReminders } from './reminders.js';
import { RateLimitedError, toTodo } from './sources/omi.js';
import type { Store } from './store.js';
import type { ChatMessage, PatchTodo, StreamChat } from './types.js';

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
const MAX_QUESTION = 4000;
const MAX_CONTEXT = 20000;
/** SSE keepalive comment interval until the first delta (CONTRACT-0.3 §7). */
export const ASK_PING_MS = 15_000;

const ASK_SYSTEM =
  'You answer questions for a user wearing smart glasses; the answer is read on a tiny display. ' +
  'Be direct and concise: at most 3 short sentences unless the question needs more. ' +
  'No markdown, no lists, no preamble.';

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

  // Malformed JSON etc. → contract-style JSON error.
  app.setErrorHandler((err: { statusCode?: number; message: string }, req, reply) => {
    const status = err.statusCode && err.statusCode >= 400 && err.statusCode < 500 ? err.statusCode : 500;
    if (status === 500) req.log.error({ err }, 'unhandled error');
    reply.code(status).send({ error: status === 500 ? 'internal' : err.message });
  });

  app.get('/health', async () => ({ ok: true, version: VERSION }));

  app.get('/dashboard', async () => deps.store.dashboard());
  app.get('/news', async () => ({ news: deps.store.dashboard().news }));
  app.get('/x', async () => ({ x: deps.store.dashboard().x }));
  app.get('/todos', async () => ({ todos: deps.store.dashboard().todos }));
  app.get('/omi/memories', async () => ({ omi: deps.store.dashboard().omi }));

  app.patch<{ Params: { id: string } }>('/todos/:id', async (req, reply) => {
    const body = req.body as { completed?: unknown } | null | undefined;
    if (!body || typeof body !== 'object' || typeof body.completed !== 'boolean') {
      return reply.code(400).send({ error: 'body must be {"completed": boolean}' });
    }
    try {
      const item = await deps.patchTodo(req.params.id, body.completed);
      const todo = toTodo(item, deps.store.get().dueAtOverrides);
      deps.store.updateTodo(todo);
      deps.store.save().catch((e: unknown) => req.log.warn({ err: e }, 'cache save failed'));
      return { ok: true, todo };
    } catch (e) {
      if (e instanceof RateLimitedError) {
        const secs = Math.max(1, Math.ceil((e.retryAt - deps.now()) / 1000));
        return reply.code(429).header('Retry-After', String(secs)).send({ error: 'rate_limited' });
      }
      if (e instanceof UpstreamError && e.status === 404) return reply.code(404).send({ error: 'not_found' });
      req.log.warn({ err: e }, 'omi PATCH failed');
      return reply.code(502).send({ error: 'upstream_failed' });
    }
  });

  app.get<{ Querystring: { since?: string } }>('/reminders', async (req, reply) => {
    const now = deps.now();
    const raw = req.query.since;
    let since = now - 24 * 3600_000;
    if (raw !== undefined && raw !== '') {
      if (!/^\d+$/.test(raw)) return reply.code(400).send({ error: 'invalid since' });
      since = Number(raw);
    }
    return { reminders: buildReminders(deps.store.dashboard(), since, now, deps.config.timeZone) };
  });

  app.post('/ask', async (req, reply) => {
    const body = req.body as { question?: unknown; context?: unknown; deep?: unknown } | null | undefined;
    if (!body || typeof body !== 'object') return reply.code(400).send({ error: 'body must be JSON' });
    const { question, context, deep } = body;
    if (typeof question !== 'string' || question.trim() === '' || question.length > MAX_QUESTION) {
      return reply.code(400).send({ error: 'question must be a non-empty string' });
    }
    if (context !== undefined && context !== null && typeof context !== 'string') {
      return reply.code(400).send({ error: 'context must be a string' });
    }
    if (deep !== undefined && typeof deep !== 'boolean') return reply.code(400).send({ error: 'deep must be a boolean' });

    const ctx = typeof context === 'string' ? context.slice(-MAX_CONTEXT).trim() : '';
    const messages: ChatMessage[] = [
      { role: 'system', content: ASK_SYSTEM },
      {
        role: 'user',
        content: ctx ? `Recent conversation transcript (context):\n${ctx}\n\nQuestion: ${question.trim()}` : question.trim(),
      },
    ];
    const model = deep === true ? deps.config.deepModel : deps.config.model;

    reply.hijack();
    const res = reply.raw;
    const upstream = new AbortController();
    let finished = false;
    let ping: NodeJS.Timeout | undefined;
    const stopPing = () => {
      if (ping !== undefined) clearInterval(ping);
      ping = undefined;
    };
    res.on('close', () => {
      stopPing();
      if (!finished) upstream.abort(); // client went away mid-stream
    });
    res.writeHead(200, {
      'content-type': 'text/event-stream; charset=utf-8',
      'cache-control': 'no-cache, no-transform',
      connection: 'keep-alive',
      'x-accel-buffering': 'no',
      'access-control-allow-origin': req.headers.origin ?? '*',
      vary: 'Origin',
    });
    const send = (obj: unknown) => {
      if (!res.destroyed) res.write(`data: ${JSON.stringify(obj)}\n\n`);
    };
    // Keep the connection (and the client's first-byte timeout) alive while the model thinks.
    ping = setInterval(() => {
      if (!res.destroyed) res.write(': ping\n\n');
    }, ASK_PING_MS);
    try {
      for await (const delta of deps.streamChat({ model, messages }, upstream.signal)) {
        if (upstream.signal.aborted) break;
        stopPing();
        send({ delta });
      }
      if (!upstream.signal.aborted) send({ done: true });
    } catch (e) {
      if (!upstream.signal.aborted) {
        // Details (status, upstream body) stay in the server log; the client gets a fixed string (§7).
        req.log.warn({ err: e }, 'ask stream failed');
        send({ error: 'upstream error' });
      }
    } finally {
      stopPing();
      finished = true;
      res.end();
    }
  });

  return app;
}
