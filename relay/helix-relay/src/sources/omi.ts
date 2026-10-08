import { errorSnippet, fetchWithTimeout, retryAfterMs, UpstreamError } from '../http.js';
import { detail, isoUtc, title } from '../text.js';
import type { OmiActionItem, OmiItem, OmiMemory, TodoItem } from '../types.js';

export class RateLimitedError extends Error {
  constructor(
    readonly bucket: string,
    readonly retryAt: number,
  ) {
    super(`omi ${bucket}: rate limited until ${new Date(retryAt).toISOString()}`);
  }
}

type Bucket = 'action-read' | 'action-write' | 'memory-read';

export interface OmiClientOptions {
  baseUrl: string;
  key: string | undefined;
  timeoutMs: number;
}

/**
 * Omi developer REST API (https://docs.omi.me/doc/developer/api/overview).
 * Rate limits are per bucket (reads/writes are separate); on 429 we stop calling
 * that bucket until Retry-After elapses.
 */
export class OmiClient {
  private readonly retryAt = new Map<Bucket, number>();

  constructor(
    private readonly opts: OmiClientOptions,
    private readonly now: () => number = Date.now,
  ) {}

  async listActionItems(): Promise<OmiActionItem[]> {
    const res = await this.request('action-read', '/v1/dev/user/action-items?limit=100&offset=0', { method: 'GET' });
    const body = (await res.json()) as unknown;
    return asList(body).filter(isActionItem);
  }

  async patchActionItem(id: string, completed: boolean): Promise<OmiActionItem> {
    const res = await this.request('action-write', `/v1/dev/user/action-items/${encodeURIComponent(id)}`, {
      method: 'PATCH',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ completed }),
    });
    const body = (await res.json()) as unknown;
    if (!isActionItem(body)) throw new UpstreamError('omi', res.status, 'unexpected PATCH response');
    return body;
  }

  async listMemories(): Promise<OmiMemory[]> {
    try {
      const res = await this.request('memory-read', '/v1/dev/user/memories?limit=50&offset=0', { method: 'GET' });
      const body = (await res.json()) as unknown;
      return asList(body).filter(isMemory);
    } catch (e) {
      // Valid key, but Omi has not enabled developer memory access for this account yet.
      if (e instanceof UpstreamError && e.status === 403 && e.message.includes('developer_memory_access_not_ready')) {
        return [];
      }
      throw e;
    }
  }

  private async request(bucket: Bucket, path: string, init: { method: string; headers?: Record<string, string>; body?: string }) {
    if (!this.opts.key) throw new Error('OMI_DEV_KEY is not configured');
    const until = this.retryAt.get(bucket) ?? 0;
    if (this.now() < until) throw new RateLimitedError(bucket, until);
    const res = await fetchWithTimeout(
      `${this.opts.baseUrl}${path}`,
      { ...init, headers: { ...init.headers, authorization: `Bearer ${this.opts.key}`, accept: 'application/json' } },
      this.opts.timeoutMs,
    );
    if (res.status === 429) {
      const at = retryAfterMs(res.headers.get('retry-after'), this.now());
      this.retryAt.set(bucket, at);
      await res.body?.cancel();
      throw new RateLimitedError(bucket, at);
    }
    if (!res.ok) throw new UpstreamError('omi', res.status, await errorSnippet(res));
    return res;
  }
}

function asList(body: unknown): unknown[] {
  if (Array.isArray(body)) return body;
  if (body && typeof body === 'object') {
    for (const k of ['items', 'action_items', 'memories', 'data']) {
      const v = (body as Record<string, unknown>)[k];
      if (Array.isArray(v)) return v;
    }
  }
  return [];
}

function isActionItem(v: unknown): v is OmiActionItem {
  const o = v as Record<string, unknown> | null;
  return !!o && typeof o.id === 'string' && typeof o.description === 'string' && typeof o.completed === 'boolean';
}

function isMemory(v: unknown): v is OmiMemory {
  const o = v as Record<string, unknown> | null;
  return !!o && typeof o.id === 'string' && typeof o.content === 'string';
}

/** Omi action item → contract todo. `dueOverrides` holds LLM-extracted times for items Omi has no due_at for. */
export function toTodo(item: OmiActionItem, dueOverrides: Record<string, string>): TodoItem {
  const full = item.description.replace(/\s+/g, ' ').trim();
  const t = title(full);
  return {
    id: item.id,
    title: t,
    detail: t === full ? '' : detail(full),
    completed: item.completed,
    dueAt: isoUtc(item.due_at) ?? isoUtc(dueOverrides[item.id]) ?? null,
  };
}

export function toOmiItem(m: OmiMemory): OmiItem {
  return {
    id: m.id,
    title: title(m.content),
    detail: detail(m.content),
    createdAt: isoUtc(m.created_at) ?? new Date(0).toISOString().replace(/\.\d{3}Z$/, 'Z'),
  };
}
