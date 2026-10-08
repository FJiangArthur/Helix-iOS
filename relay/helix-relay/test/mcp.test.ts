import { MockAgent, getGlobalDispatcher, setGlobalDispatcher, type Dispatcher } from 'undici';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { OmiMcpClient, toXItem } from '../src/sources/mcp.js';

const ORIGIN = 'https://api.omi.me';
let agent: MockAgent;
let prev: Dispatcher;
beforeEach(() => {
  prev = getGlobalDispatcher();
  agent = new MockAgent();
  agent.disableNetConnect();
  setGlobalDispatcher(agent);
});
afterEach(async () => {
  setGlobalDispatcher(prev);
  await agent.close();
});

const posts = {
  posts: [
    { id: '2107333902654460173', text: 'Thread about why evals drift over time and how to pin them.', kind: 'bookmark', created_at: '2026-10-06T04:55:29.000Z' },
    { id: '2', text: 'Hello', kind: 'tweet', author: 'karpathy', created_at: '2026-10-06T04:00:00.000Z' },
  ],
};

const logs: string[] = [];
const client = () => new OmiMcpClient({ url: `${ORIGIN}/v1/mcp`, key: 'omi_mcp_k', timeoutMs: 2000 }, (m) => logs.push(m));

describe('Omi MCP get_x_posts', () => {
  it('sends a JSON-RPC tools/call with MCP 2026-07-28 headers and reads structuredContent', async () => {
    let sent: Record<string, unknown> = {};
    let headers: Record<string, string> = {};
    agent
      .get(ORIGIN)
      .intercept({
        path: '/v1/mcp',
        method: 'POST',
        headers: (h) => {
          headers = h as Record<string, string>;
          return true;
        },
        body: (b) => {
          sent = JSON.parse(b) as Record<string, unknown>;
          return true;
        },
      })
      .reply(200, { jsonrpc: '2.0', id: 1, result: { structuredContent: posts, content: [{ type: 'text', text: JSON.stringify(posts) }] } });
    const items = await client().getXPosts(20);
    expect(sent).toMatchObject({ jsonrpc: '2.0', method: 'tools/call', params: { name: 'get_x_posts', arguments: { limit: 20 } } });
    expect(headers['authorization']).toBe('Bearer omi_mcp_k');
    expect(headers['mcp-protocol-version']).toBe('2026-07-28');
    expect(headers['mcp-method']).toBe('tools/call');
    expect(String(headers['accept'])).toContain('text/event-stream');
    expect(items).toEqual([
      { id: '2107333902654460173', title: 'Thread about why evals drift over time and how to pin them.', detail: 'Thread about why evals drift over time and how to pin them.', url: 'https://x.com/i/status/2107333902654460173' },
      { id: '2', title: '@karpathy: Hello', detail: 'Hello', url: 'https://x.com/karpathy/status/2' },
    ]);
  });

  it('accepts an SSE-framed response and falls back to the text block', async () => {
    const msg = { jsonrpc: '2.0', id: 1, result: { content: [{ type: 'text', text: JSON.stringify(posts) }] } };
    agent
      .get(ORIGIN)
      .intercept({ path: '/v1/mcp', method: 'POST' })
      .reply(200, `event: message\ndata: ${JSON.stringify(msg)}\n\n`, { headers: { 'content-type': 'text/event-stream' } });
    expect(await client().getXPosts(5)).toHaveLength(2);
  });

  it('falls back to the legacy initialize handshake on unsupported protocol version', async () => {
    const pool = agent.get(ORIGIN);
    pool
      .intercept({ path: '/v1/mcp', method: 'POST' })
      .reply(200, { jsonrpc: '2.0', id: 1, error: { code: -32022, message: 'unsupported protocol version' } });
    let initBody: Record<string, unknown> = {};
    pool
      .intercept({
        path: '/v1/mcp',
        method: 'POST',
        body: (b) => {
          initBody = JSON.parse(b) as Record<string, unknown>;
          return initBody.method === 'initialize';
        },
      })
      .reply(200, { jsonrpc: '2.0', id: 1, result: { protocolVersion: '2025-03-26' } }, { headers: { 'mcp-session-id': 's1' } });
    pool.intercept({ path: '/v1/mcp', method: 'POST', body: (b) => b.includes('notifications/initialized') }).reply(202, '');
    let sessionHeader = '';
    pool
      .intercept({
        path: '/v1/mcp',
        method: 'POST',
        headers: (h) => {
          sessionHeader = (h as Record<string, string>)['mcp-session-id'] ?? '';
          return true;
        },
        body: (b) => b.includes('tools/call'),
      })
      .reply(200, { jsonrpc: '2.0', id: 2, result: { structuredContent: posts } });
    expect(await client().getXPosts(5)).toHaveLength(2);
    expect(sessionHeader).toBe('s1');
  });

  it('returns [] and logs on tool errors, HTTP errors, or missing key', async () => {
    agent
      .get(ORIGIN)
      .intercept({ path: '/v1/mcp', method: 'POST' })
      .reply(200, { jsonrpc: '2.0', id: 1, result: { isError: true, structuredContent: { error: { code: 'paid_plan_required', message: 'x' } } } });
    logs.length = 0;
    expect(await client().getXPosts(5)).toEqual([]);
    expect(logs.join()).toMatch(/paid_plan_required/);

    agent.get(ORIGIN).intercept({ path: '/v1/mcp', method: 'POST' }).reply(401, 'bad key');
    expect(await client().getXPosts(5)).toEqual([]);

    const noKey = new OmiMcpClient({ url: `${ORIGIN}/v1/mcp`, key: undefined, timeoutMs: 1000 }, () => {});
    expect(await noKey.getXPosts(5)).toEqual([]);
  });

  it('toXItem truncates long posts', () => {
    const x = toXItem({ id: '9', text: 'y'.repeat(700) });
    expect(x?.title.length).toBe(60);
    expect(x?.detail.length).toBe(600);
  });
});
