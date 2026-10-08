import { errorSnippet, fetchWithTimeout, UpstreamError } from '../http.js';
import { detail, title } from '../text.js';
import type { XItem } from '../types.js';

/**
 * Hosted Omi MCP server (https://docs.omi.me/doc/developer/mcp/setup):
 * Streamable HTTP at https://api.omi.me/v1/mcp, `Authorization: Bearer omi_mcp_…`,
 * protocol 2026-07-28 (stateless: no initialize, no Mcp-Session-Id; headers mirror the
 * JSON-RPC method). Older revisions still work via the initialize handshake, which we
 * fall back to when the server answers -32022 (unsupported protocol version).
 * Successful tools/call results carry `structuredContent` plus a text block with the
 * same JSON. `get_x_posts` → `{posts:[{id,text,kind,created_at}]}`.
 */
const PROTOCOL = '2026-07-28';
const LEGACY_PROTOCOL = '2025-03-26';
const CLIENT_INFO = { name: 'helix-relay', version: '0.3.0' };

export interface OmiMcpOptions {
  url: string;
  key: string | undefined;
  timeoutMs: number;
}

interface JsonRpcResponse {
  jsonrpc?: string;
  id?: number | string | null;
  result?: Record<string, unknown>;
  error?: { code: number; message: string };
}

export class OmiMcpClient {
  private nextId = 1;

  constructor(
    private readonly opts: OmiMcpOptions,
    private readonly log: (msg: string) => void = () => {},
  ) {}

  /** Imported X posts/bookmarks, newest first. Any failure → [] (logged). */
  async getXPosts(limit = 20): Promise<XItem[]> {
    if (!this.opts.key) {
      this.log('omi-mcp: OMI_MCP_KEY not configured; x = []');
      return [];
    }
    try {
      const result = await this.callTool('get_x_posts', { limit });
      if (result.isError === true) {
        const err = (result.structuredContent as { error?: { code?: string; message?: string } } | undefined)?.error;
        this.log(`omi-mcp: get_x_posts tool error ${err?.code ?? 'unknown'}: ${err?.message ?? ''}`);
        return [];
      }
      const data = result.structuredContent ?? parseTextBlock(result.content);
      const list = Array.isArray(data) ? data : ((data as { posts?: unknown } | undefined)?.posts ?? []);
      return Array.isArray(list) ? list.map(toXItem).filter((x): x is XItem => x !== null) : [];
    } catch (e) {
      this.log(`omi-mcp: get_x_posts failed: ${(e as Error).message}`);
      return [];
    }
  }

  private async callTool(name: string, args: Record<string, unknown>): Promise<Record<string, unknown>> {
    const params = {
      name,
      arguments: args,
      _meta: {
        'io.modelcontextprotocol/protocolVersion': PROTOCOL,
        'io.modelcontextprotocol/clientCapabilities': {},
        'io.modelcontextprotocol/clientInfo': CLIENT_INFO,
      },
    };
    const first = await this.post({ method: 'tools/call', params }, { 'mcp-protocol-version': PROTOCOL, 'mcp-method': 'tools/call' });
    if (first.msg?.error?.code === -32022) return this.callToolLegacy(name, args);
    return unwrap(first.msg);
  }

  /** Pre-2026 Streamable HTTP: initialize → notifications/initialized → tools/call with Mcp-Session-Id. */
  private async callToolLegacy(name: string, args: Record<string, unknown>): Promise<Record<string, unknown>> {
    const base = { 'mcp-protocol-version': LEGACY_PROTOCOL };
    const init = await this.post(
      { method: 'initialize', params: { protocolVersion: LEGACY_PROTOCOL, capabilities: {}, clientInfo: CLIENT_INFO } },
      {},
    );
    unwrap(init.msg);
    const session: Record<string, string> = init.sessionId ? { 'mcp-session-id': init.sessionId } : {};
    await this.post({ method: 'notifications/initialized' }, { ...base, ...session }, true);
    const call = await this.post({ method: 'tools/call', params: { name, arguments: args } }, { ...base, ...session });
    return unwrap(call.msg);
  }

  private async post(
    body: { method: string; params?: unknown },
    headers: Record<string, string>,
    notification = false,
  ): Promise<{ msg: JsonRpcResponse | undefined; sessionId: string | null }> {
    const payload = notification ? { jsonrpc: '2.0', ...body } : { jsonrpc: '2.0', id: this.nextId++, ...body };
    const res = await fetchWithTimeout(
      this.opts.url,
      {
        method: 'POST',
        headers: {
          authorization: `Bearer ${this.opts.key}`,
          'content-type': 'application/json',
          accept: 'application/json, text/event-stream',
          ...headers,
        },
        body: JSON.stringify(payload),
      },
      this.opts.timeoutMs,
    );
    const sessionId = res.headers.get('mcp-session-id');
    if (!res.ok) throw new UpstreamError('omi-mcp', res.status, await errorSnippet(res));
    if (notification) {
      await res.body?.cancel();
      return { msg: undefined, sessionId };
    }
    const raw = await res.text();
    const ctype = res.headers.get('content-type') ?? '';
    return { msg: ctype.includes('text/event-stream') || raw.startsWith('event:') || raw.startsWith('data:') ? lastSseMessage(raw) : (JSON.parse(raw) as JsonRpcResponse), sessionId };
  }
}

function unwrap(msg: JsonRpcResponse | undefined): Record<string, unknown> {
  if (!msg) throw new Error('empty JSON-RPC response');
  if (msg.error) throw new Error(`JSON-RPC ${msg.error.code}: ${msg.error.message}`);
  if (!msg.result || typeof msg.result !== 'object') throw new Error('JSON-RPC response without result');
  return msg.result;
}

function lastSseMessage(raw: string): JsonRpcResponse | undefined {
  let found: JsonRpcResponse | undefined;
  for (const event of raw.split(/\r?\n\r?\n/)) {
    const data = event
      .split(/\r?\n/)
      .filter((l) => l.startsWith('data:'))
      .map((l) => l.slice(5).trimStart())
      .join('\n');
    if (!data) continue;
    try {
      const m = JSON.parse(data) as JsonRpcResponse;
      if (m && (m.result !== undefined || m.error !== undefined)) found = m;
    } catch {
      /* ignore non-JSON events */
    }
  }
  return found;
}

function parseTextBlock(content: unknown): unknown {
  if (!Array.isArray(content)) return undefined;
  for (const block of content as Array<{ type?: string; text?: string }>) {
    if (block?.type === 'text' && typeof block.text === 'string') {
      try {
        return JSON.parse(block.text);
      } catch {
        /* not JSON */
      }
    }
  }
  return undefined;
}

export function toXItem(v: unknown): XItem | null {
  const o = v as Record<string, unknown> | null;
  if (!o) return null;
  const id = typeof o.id === 'string' || typeof o.id === 'number' ? String(o.id) : '';
  const text = typeof o.text === 'string' ? o.text : '';
  if (!id || !text.trim()) return null;
  const handleRaw = [o.author, o.username, o.screen_name, o.handle].find((h) => typeof h === 'string' && h.trim());
  const handle = typeof handleRaw === 'string' ? handleRaw.trim().replace(/^@/, '') : '';
  const url =
    typeof o.url === 'string' && o.url ? o.url : handle ? `https://x.com/${handle}/status/${id}` : `https://x.com/i/status/${id}`;
  return {
    id,
    title: title(handle ? `@${handle}: ${text}` : text),
    detail: detail(text),
    url,
  };
}
