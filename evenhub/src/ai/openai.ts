// Minimal OpenAI chat-completions client (browser fetch, user's own key).
export const CHAT_URL = 'https://api.openai.com/v1/chat/completions';
export const CUE_MODEL = 'gpt-4.1-mini';

export type FetchFn = (url: string, init: RequestInit) => Promise<Response>;

const defaultFetch: FetchFn = (url, init) => fetch(url, init);

async function chat(apiKey: string, body: Record<string, unknown>, fetchFn: FetchFn, signal?: AbortSignal): Promise<string> {
  const res = await fetchFn(CHAT_URL, {
    method: 'POST',
    headers: { Authorization: `Bearer ${apiKey}`, 'Content-Type': 'application/json' },
    body: JSON.stringify(body),
    signal,
  });
  if (!res.ok) throw new Error(`OpenAI HTTP ${res.status}`);
  const json = (await res.json()) as { choices?: Array<{ message?: { content?: string | null } }> };
  return (json.choices?.[0]?.message?.content ?? '').trim();
}

/** Cue extraction: JSON mode, deterministic. Returns the raw model text. */
export function openaiClassify(apiKey: string, prompt: string, maxTokens: number, fetchFn: FetchFn = defaultFetch): Promise<string> {
  return chat(apiKey, {
    model: CUE_MODEL,
    temperature: 0,
    max_tokens: maxTokens,
    response_format: { type: 'json_object' },
    messages: [{ role: 'user', content: prompt }],
  }, fetchFn);
}

/** Answer to a question heard in the conversation, directly speakable. */
export function openaiAnswer(
  apiKey: string,
  question: string,
  context: string,
  maxSentences: number,
  fetchFn: FetchFn = defaultFetch,
): Promise<string> {
  const system =
    `You answer questions heard in a live conversation; the answer is shown on smart glasses. ` +
    `Reply with the answer itself in at most ${maxSentences} sentences of plain text, no markdown, ` +
    `never "you could say" or "here's a suggestion". If you do not know, say so briefly.`;
  return chat(apiKey, {
    model: CUE_MODEL,
    temperature: 0.2,
    max_tokens: 200,
    messages: [
      { role: 'system', content: system },
      { role: 'user', content: `Context (recent transcript and prep note):\n${context || '(none)'}\n\nQuestion: ${question}` },
    ],
  }, fetchFn);
}
