import { fetch, type RequestInit, type Response } from 'undici';

export class UpstreamError extends Error {
  constructor(
    readonly source: string,
    readonly status: number,
    message: string,
  ) {
    super(`${source}: HTTP ${status}${message ? ` ${message}` : ''}`);
  }
}

/** undici fetch with a hard timeout (combined with an optional caller signal). */
export async function fetchWithTimeout(url: string, init: RequestInit, timeoutMs: number): Promise<Response> {
  const timeout = AbortSignal.timeout(timeoutMs);
  const signal = init.signal ? AbortSignal.any([init.signal as AbortSignal, timeout]) : timeout;
  return fetch(url, { ...init, signal });
}

export async function errorSnippet(res: Response): Promise<string> {
  try {
    return (await res.text()).slice(0, 200);
  } catch {
    return '';
  }
}

/** Retry-After header → epoch ms (seconds or HTTP-date); defaults to 60 s. */
export function retryAfterMs(header: string | null, now: number): number {
  if (header) {
    const secs = Number(header);
    if (Number.isFinite(secs) && secs >= 0) return now + secs * 1000;
    const at = Date.parse(header);
    if (!Number.isNaN(at)) return Math.max(now, at);
  }
  return now + 60_000;
}
