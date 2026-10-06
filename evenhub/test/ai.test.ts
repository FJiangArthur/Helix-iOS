import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { AnswerEngine, isQuestion } from '../src/ai/answers';
import { CueEngine } from '../src/ai/cueEngine';
import { CHAT_URL, openaiAnswer, openaiClassify } from '../src/ai/openai';
import type { Cue } from '../src/core/cue';
import { loadCuePrompt } from '../src/core/cuePrompt';

const ok = (content: string) => new Response(JSON.stringify({ choices: [{ message: { content } }] }), { status: 200 });

describe('openai client', () => {
  it('classify posts a json-mode chat completion with gpt-4.1-mini at temperature 0', async () => {
    const calls: Array<{ url: string; init: RequestInit }> = [];
    const out = await openaiClassify('k', 'PROMPT', 600, async (url, init) => { calls.push({ url, init }); return ok('{"cues":[]}'); });
    expect(out).toBe('{"cues":[]}');
    expect(calls[0]!.url).toBe(CHAT_URL);
    expect((calls[0]!.init.headers as Record<string, string>).Authorization).toBe('Bearer k');
    const body = JSON.parse(calls[0]!.init.body as string);
    expect(body).toMatchObject({ model: 'gpt-4.1-mini', temperature: 0, max_tokens: 600, response_format: { type: 'json_object' } });
    expect(body.messages).toEqual([{ role: 'user', content: 'PROMPT' }]);
  });

  it('throws on HTTP errors', async () => {
    await expect(openaiClassify('k', 'p', 10, async () => new Response('nope', { status: 401 }))).rejects.toThrow('401');
  });

  it('answer asks for at most N sentences of directly speakable text', async () => {
    let body: any;
    const out = await openaiAnswer('k', 'What was Q3 revenue?', 'ctx', 3, async (_u, init) => { body = JSON.parse(init.body as string); return ok(' $4M. '); });
    expect(out).toBe('$4M.');
    expect(body.messages[0].content).toContain('at most 3 sentences');
    expect(body.messages.at(-1).content).toContain('What was Q3 revenue?');
  });
});

describe('isQuestion', () => {
  it('detects ? endings and wh/aux openers', () => {
    expect(isQuestion('So what is the plan?')).toBe(true);
    expect(isQuestion('How does RAG work')).toBe(true);
    expect(isQuestion('Can you explain the budget')).toBe(true);
    expect(isQuestion('I think so.')).toBe(false);
    expect(isQuestion('Why')).toBe(false); // too short to answer
    expect(isQuestion('')).toBe(false);
  });
});

describe('CueEngine', () => {
  beforeEach(() => { vi.useFakeTimers(); vi.setSystemTime(0); });
  afterEach(() => { vi.useRealTimers(); });

  const make = (classify: (p: string, n: number) => Promise<string>) => {
    const cues: Cue[] = [];
    const engine = new CueEngine({ classify, prompt: loadCuePrompt(), clock: () => Date.now(), emit: (c) => cues.push(c) });
    return { engine, cues };
  };

  it('debounces finals 1.5 s and emits the first fresh cue', async () => {
    const prompts: string[] = [];
    const { engine, cues } = make(async (p) => { prompts.push(p); return '{"cues":[{"type":"CONCEPT","title":"RAG","body":"Retrieval.","entity":"RAG"}]}'; });
    engine.onFinal('we should use');
    await vi.advanceTimersByTimeAsync(1000);
    engine.onFinal('RAG for this');
    await vi.advanceTimersByTimeAsync(1499);
    expect(prompts.length).toBe(0);
    await vi.advanceTimersByTimeAsync(1);
    expect(prompts.length).toBe(1);
    expect(prompts[0]).toContain('we should use RAG for this');
    expect(cues.map((c) => [c.type, c.title])).toEqual([['CONCEPT', 'RAG']]);
  });

  it('enforces the 8 s gap and never repeats an entity', async () => {
    const { engine, cues } = make(async () => '{"cues":[{"type":"CONCEPT","title":"RAG","body":"b","entity":"RAG"},{"type":"BIO","title":"Ada","body":"b"}]}');
    engine.onFinal('one');
    await vi.advanceTimersByTimeAsync(1500);
    engine.onFinal('two');
    await vi.advanceTimersByTimeAsync(1500); // only 1.5 s after the last cue: gated
    expect(cues.length).toBe(1);
    await vi.advanceTimersByTimeAsync(7000);
    engine.onFinal('three');
    await vi.advanceTimersByTimeAsync(1500);
    expect(cues.map((c) => c.title)).toEqual(['RAG', 'Ada']);
  });

  it('counts failures, drops malformed output and resets', async () => {
    let mode = 'throw';
    const { engine, cues } = make(async () => { if (mode === 'throw') throw new Error('x'); return 'not json'; });
    engine.onFinal('a'); await vi.advanceTimersByTimeAsync(1500);
    engine.onFinal('b'); await vi.advanceTimersByTimeAsync(1500);
    expect(engine.failures).toBe(2);
    mode = 'junk';
    engine.onFinal('c'); await vi.advanceTimersByTimeAsync(1500);
    expect(engine.failures).toBe(0);
    expect(cues).toEqual([]);
    engine.reset();
    expect(engine.failures).toBe(0);
  });

  it('a call in flight during reset never emits', async () => {
    let release!: (v: string) => void;
    const { engine, cues } = make(() => new Promise((r) => { release = r; }));
    engine.onFinal('x'); await vi.advanceTimersByTimeAsync(1500);
    engine.reset();
    release('{"cues":[{"type":"CONCEPT","title":"T","body":"B"}]}');
    await vi.advanceTimersByTimeAsync(0);
    expect(cues).toEqual([]);
  });
});

describe('AnswerEngine', () => {
  it('answers questions not spoken by the wearer as ANSWER cues', async () => {
    const cues: Cue[] = [];
    let n = 0;
    const engine = new AnswerEngine({
      answer: async (q) => `Answer to ${q}`,
      clock: () => 5,
      nextId: () => ++n,
      emit: (c) => cues.push(c),
    });
    await engine.onFinal('What is the budget?', 'other');
    await engine.onFinal('Where are we going?', 'self');
    await engine.onFinal('Fine.', 'other');
    expect(cues).toEqual([{ id: 1, type: 'ANSWER', title: 'Answer', body: 'Answer to What is the budget?', detail: null, createdAtMillis: 5 }]);
  });

  it('long answers keep a body under 220 chars and the rest as detail', async () => {
    const cues: Cue[] = [];
    const long = 'x '.repeat(400).trim();
    const engine = new AnswerEngine({ answer: async () => long, clock: () => 0, nextId: () => 1, emit: (c) => cues.push(c) });
    await engine.onFinal('Why is that?', 'unknown');
    expect(cues[0]!.body.length).toBeLessThanOrEqual(220);
    expect(cues[0]!.detail!.length).toBeLessThanOrEqual(1000);
  });
});
