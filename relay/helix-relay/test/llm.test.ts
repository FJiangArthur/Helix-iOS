import { MockAgent, getGlobalDispatcher, setGlobalDispatcher, type Dispatcher } from 'undici';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { LlmClient, parseSseDeltas } from '../src/llm.js';

const ORIGIN = 'http://127.0.0.1:8787';
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

const llm = (key?: string) => new LlmClient({ baseUrl: `${ORIGIN}/v1`, key, timeoutMs: 2000 });

describe('codex-proxy client', () => {
  it('complete() posts an OpenAI chat completion and returns the message content', async () => {
    let sent: Record<string, unknown> = {};
    let authz: string | undefined;
    agent
      .get(ORIGIN)
      .intercept({
        path: '/v1/chat/completions',
        method: 'POST',
        headers: (h) => {
          authz = (h as Record<string, string>).authorization;
          return true;
        },
        body: (b) => {
          sent = JSON.parse(b) as Record<string, unknown>;
          return true;
        },
      })
      .reply(200, { choices: [{ message: { role: 'assistant', content: '{"ok":1}' } }] });
    const out = await llm('sk-proxy').complete({ model: 'gpt-5.4', messages: [{ role: 'user', content: 'hi' }] });
    expect(out).toBe('{"ok":1}');
    expect(sent).toMatchObject({ model: 'gpt-5.4', stream: false, messages: [{ role: 'user', content: 'hi' }] });
    expect(authz).toBe('Bearer sk-proxy');
  });

  it('omits Authorization when no CODEX_PROXY_KEY is set', async () => {
    let authz: string | undefined = 'unset';
    agent
      .get(ORIGIN)
      .intercept({
        path: '/v1/chat/completions',
        method: 'POST',
        headers: (h) => {
          authz = (h as Record<string, string>).authorization;
          return true;
        },
      })
      .reply(200, { choices: [{ message: { content: 'x' } }] });
    await llm().complete({ model: 'gpt-5.4', messages: [] });
    expect(authz).toBeUndefined();
  });

  it('complete() throws on HTTP errors', async () => {
    agent.get(ORIGIN).intercept({ path: '/v1/chat/completions', method: 'POST' }).reply(502, 'bad gateway');
    await expect(llm().complete({ model: 'gpt-5.4', messages: [] })).rejects.toThrow(/502/);
  });

  it('streamChat() yields content deltas from the SSE stream', async () => {
    const sse = [
      'data: {"choices":[{"delta":{"role":"assistant"}}]}',
      'data: {"choices":[{"delta":{"content":"Hel"}}]}',
      ': keep-alive',
      'data: {"choices":[{"delta":{"content":"lo"}}]}',
      'data: [DONE]',
      '',
    ].join('\n\n');
    let sent: Record<string, unknown> = {};
    agent
      .get(ORIGIN)
      .intercept({
        path: '/v1/chat/completions',
        method: 'POST',
        body: (b) => {
          sent = JSON.parse(b) as Record<string, unknown>;
          return true;
        },
      })
      .reply(200, sse, { headers: { 'content-type': 'text/event-stream' } });
    const parts: string[] = [];
    for await (const d of llm().streamChat({ model: 'gpt-5.5', messages: [] }, new AbortController().signal)) parts.push(d);
    expect(parts).toEqual(['Hel', 'lo']);
    expect(sent).toMatchObject({ model: 'gpt-5.5', stream: true });
  });

  it('parseSseDeltas handles events split across chunk boundaries', async () => {
    async function* chunks() {
      yield 'data: {"choices":[{"delta":{"con';
      yield 'tent":"a"}}]}\n\nda';
      yield 'ta: {"choices":[{"delta":{"content":"b"}}]}\r\n\r\ndata: [DONE]\n\n';
      yield 'data: {"choices":[{"delta":{"content":"ignored"}}]}\n\n';
    }
    const out: string[] = [];
    for await (const d of parseSseDeltas(chunks())) out.push(d);
    expect(out).toEqual(['a', 'b']);
  });

  it('parseSseDeltas surfaces upstream error events', async () => {
    async function* chunks() {
      yield 'data: {"error":{"message":"quota exceeded"}}\n\n';
    }
    const it = parseSseDeltas(chunks());
    await expect(it.next()).rejects.toThrow(/quota exceeded/);
  });
});
