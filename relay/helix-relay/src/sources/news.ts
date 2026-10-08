import { createHash } from 'node:crypto';
import { XMLParser } from 'fast-xml-parser';
import { errorSnippet, fetchWithTimeout, UpstreamError } from '../http.js';
import { detail, isoUtc, stripHtml, title } from '../text.js';
import type { NewsItem } from '../types.js';

// ---------- Finnhub ----------

export interface FinnhubOptions {
  baseUrl: string;
  key: string | undefined;
  timeoutMs: number;
}

interface FinnhubArticle {
  id: number | string;
  headline: string;
  summary?: string;
  source?: string;
  url: string;
  datetime?: number;
}

/** GET /api/v1/news?category=general (https://finnhub.io/docs/api/market-news). No key → []. */
export async function fetchFinnhub(opts: FinnhubOptions): Promise<NewsItem[]> {
  if (!opts.key) return [];
  const res = await fetchWithTimeout(
    `${opts.baseUrl}/api/v1/news?category=general`,
    { method: 'GET', headers: { 'x-finnhub-token': opts.key, accept: 'application/json' } },
    opts.timeoutMs,
  );
  if (!res.ok) throw new UpstreamError('finnhub', res.status, await errorSnippet(res));
  const body = (await res.json()) as unknown;
  if (!Array.isArray(body)) return [];
  return body.filter(isArticle).map((a) => ({
    id: `f-${a.id}`,
    title: title(stripHtml(a.headline)),
    detail: detail(stripHtml(a.summary)),
    source: a.source?.trim() || 'finnhub',
    url: a.url,
    publishedAt: isoUtc(typeof a.datetime === 'number' ? a.datetime * 1000 : null) ?? isoUtc(Date.now())!,
  }));
}

function isArticle(v: unknown): v is FinnhubArticle {
  const o = v as Record<string, unknown> | null;
  return (
    !!o &&
    (typeof o.id === 'number' || typeof o.id === 'string') &&
    typeof o.headline === 'string' &&
    o.headline.trim() !== '' &&
    typeof o.url === 'string'
  );
}

// ---------- RSS / Atom ----------

const parser = new XMLParser({
  ignoreAttributes: false,
  attributeNamePrefix: '@_',
  textNodeName: '#text',
  processEntities: true,
  htmlEntities: false,
  isArray: (name) => name === 'item' || name === 'entry' || name === 'link',
});

type Node = Record<string, unknown>;

function text(v: unknown): string {
  if (v === null || v === undefined) return '';
  if (typeof v === 'string' || typeof v === 'number') return String(v);
  if (Array.isArray(v)) return text(v[0]);
  if (typeof v === 'object') return text((v as Node)['#text']);
  return '';
}

function hostOf(u: string): string {
  try {
    return new URL(u).hostname.replace(/^www\./, '');
  } catch {
    return 'rss';
  }
}

const shortHash = (s: string) => createHash('sha256').update(s).digest('hex').slice(0, 12);

function atomLink(links: unknown): string {
  if (!Array.isArray(links)) return text(links);
  const nodes = links as unknown[];
  const alt =
    nodes.find((l) => typeof l === 'object' && l && ((l as Node)['@_rel'] ?? 'alternate') === 'alternate') ?? nodes[0];
  if (alt && typeof alt === 'object') return String((alt as Node)['@_href'] ?? text(alt));
  return text(alt);
}

/** Parse an RSS 2.0 or Atom document. Never throws; garbage → []. */
export function parseFeed(xml: string, feedUrl: string): NewsItem[] {
  let doc: Node;
  try {
    doc = parser.parse(xml) as Node;
  } catch {
    return [];
  }
  const out: NewsItem[] = [];
  const rssItems = ((doc.rss as Node | undefined)?.channel as Node | undefined)?.item;
  const atomEntries = (doc.feed as Node | undefined)?.entry;
  const fallbackSource = hostOf(feedUrl);

  if (Array.isArray(rssItems)) {
    for (const it of rssItems as Node[]) {
      const url = text(it.link).trim();
      const t = stripHtml(text(it.title));
      if (!t) continue;
      out.push({
        id: `r-${shortHash(text(it.guid) || url || t)}`,
        title: title(t),
        detail: detail(stripHtml(text(it.description))),
        source: url ? hostOf(url) : fallbackSource,
        url,
        publishedAt: isoUtc(text(it.pubDate) || text(it['dc:date'])) ?? isoUtc(Date.now())!,
      });
    }
  } else if (Array.isArray(atomEntries)) {
    for (const it of atomEntries as Node[]) {
      const url = atomLink(it.link).trim();
      const t = stripHtml(text(it.title));
      if (!t) continue;
      out.push({
        id: `r-${shortHash(text(it.id) || url || t)}`,
        title: title(t),
        detail: detail(stripHtml(text(it.summary) || text(it.content))),
        source: url ? hostOf(url) : fallbackSource,
        url,
        publishedAt: isoUtc(text(it.updated) || text(it.published)) ?? isoUtc(Date.now())!,
      });
    }
  }
  return out;
}

/** Fetch every feed in parallel; a failing feed is skipped (logged by the caller via onError). */
export async function fetchRss(
  feeds: string[],
  timeoutMs: number,
  onError: (feed: string, err: unknown) => void = () => {},
): Promise<NewsItem[]> {
  const results = await Promise.allSettled(
    feeds.map(async (feed) => {
      const res = await fetchWithTimeout(
        feed,
        { method: 'GET', headers: { accept: 'application/rss+xml, application/atom+xml, application/xml, text/xml' } },
        timeoutMs,
      );
      if (!res.ok) throw new UpstreamError(`rss ${hostOf(feed)}`, res.status, '');
      return parseFeed(await res.text(), feed);
    }),
  );
  const out: NewsItem[] = [];
  results.forEach((r, i) => {
    if (r.status === 'fulfilled') out.push(...r.value);
    else onError(feeds[i] ?? '', r.reason);
  });
  return out;
}

/** Concatenate sources, drop duplicate URLs (first wins), newest first. */
export function mergeNews(...lists: NewsItem[][]): NewsItem[] {
  const seen = new Set<string>();
  const out: NewsItem[] = [];
  for (const n of lists.flat()) {
    const key = n.url || n.id;
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(n);
  }
  return out.sort((a, b) => Date.parse(b.publishedAt) - Date.parse(a.publishedAt));
}
