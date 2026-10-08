import { errorSnippet, fetchWithTimeout, UpstreamError } from './http.js';
import type { ChatMessage } from './types.js';

export interface LlmOptions {
  /** OpenAI-compatible base, e.g. http://127.0.0.1:8787/v1 (codex-proxy). */
  baseUrl: string;
  key: string | undefined;
  timeoutMs: number;
}

export interface ChatRequest {
  model: string;
  messages: ChatMessage[];
}

/** Streams are long-lived; allow far more than a single JSON call. */
const STREAM_TIMEOUT_FACTOR = 9;

export class LlmClient {
  constructor(private readonly opts: LlmOptions) {}

  private headers(): Record<string, string> {
    const h: Record<string, string> = { 'content-type': 'application/json' };
    if (this.opts.key) h.authorization = `Bearer ${this.opts.key}`;
    return h;
  }

  /** Non-streaming chat completion; returns the first choice's text. */
  async complete(req: ChatRequest, signal?: AbortSignal): Promise<string> {
    const res = await fetchWithTimeout(
      `${this.opts.baseUrl}/chat/completions`,
      { method: 'POST', headers: this.headers(), body: JSON.stringify({ ...req, stream: false }), signal },
      this.opts.timeoutMs * 3,
    );
    if (!res.ok) throw new UpstreamError('codex-proxy', res.status, await errorSnippet(res));
    const body = (await res.json()) as { choices?: Array<{ message?: { content?: unknown } }> };
    const content = body.choices?.[0]?.message?.content;
    if (typeof content !== 'string') throw new Error('codex-proxy: response without message content');
    return content;
  }

  /** Streaming chat completion; yields text deltas. Aborting `signal` cancels the upstream request. */
  async *streamChat(req: ChatRequest, signal: AbortSignal): AsyncGenerator<string> {
    const res = await fetchWithTimeout(
      `${this.opts.baseUrl}/chat/completions`,
      {
        method: 'POST',
        headers: { ...this.headers(), accept: 'text/event-stream' },
        body: JSON.stringify({ ...req, stream: true }),
        signal,
      },
      this.opts.timeoutMs * STREAM_TIMEOUT_FACTOR,
    );
    if (!res.ok) throw new UpstreamError('codex-proxy', res.status, await errorSnippet(res));
    if (!res.body) throw new Error('codex-proxy: empty stream');
    const decoder = new TextDecoder();
    async function* text(): AsyncGenerator<string> {
      for await (const chunk of res.body as AsyncIterable<Uint8Array>) yield decoder.decode(chunk, { stream: true });
    }
    // An early return by the consumer propagates into the body iterator, which cancels the stream.
    yield* parseSseDeltas(text());
  }
}

/** Parse OpenAI-style SSE (`data: {choices:[{delta:{content}}]}` … `data: [DONE]`) into text deltas. */
export async function* parseSseDeltas(chunks: AsyncIterable<string>): AsyncGenerator<string> {
  let buf = '';
  for await (const chunk of chunks) {
    buf += chunk.replace(/\r\n/g, '\n');
    let idx: number;
    while ((idx = buf.indexOf('\n\n')) !== -1) {
      const event = buf.slice(0, idx);
      buf = buf.slice(idx + 2);
      const data = event
        .split('\n')
        .filter((l) => l.startsWith('data:'))
        .map((l) => l.slice(5).trimStart())
        .join('\n');
      if (!data) continue;
      if (data === '[DONE]') return;
      let msg: { choices?: Array<{ delta?: { content?: unknown } }>; error?: { message?: string } | string };
      try {
        msg = JSON.parse(data) as typeof msg;
      } catch {
        continue;
      }
      if (msg.error) {
        throw new Error(typeof msg.error === 'string' ? msg.error : (msg.error.message ?? 'upstream error'));
      }
      const content = msg.choices?.[0]?.delta?.content;
      if (typeof content === 'string' && content.length > 0) yield content;
    }
  }
}
