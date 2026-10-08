import { MockAgent, getGlobalDispatcher, setGlobalDispatcher, type Dispatcher } from 'undici';
import { afterEach, beforeEach, describe, expect, it } from 'vitest';
import { fetchFinnhub, fetchRss, mergeNews, parseFeed } from '../src/sources/news.js';

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

const RSS = `<?xml version="1.0"?>
<rss version="2.0"><channel><title>Reuters</title>
<item><title>Fed holds rates steady</title><link>https://www.reuters.com/x</link>
<description>&lt;p&gt;The Federal Reserve kept rates at 4.25-4.50% &amp;amp; signalled one cut.&lt;/p&gt;</description>
<pubDate>Wed, 07 Oct 2026 13:10:00 GMT</pubDate><guid>r1</guid></item>
<item><title>Second</title><link>https://www.reuters.com/y</link><pubDate>Wed, 07 Oct 2026 10:00:00 GMT</pubDate></item>
</channel></rss>`;

const ATOM = `<?xml version="1.0" encoding="utf-8"?>
<feed xmlns="http://www.w3.org/2005/Atom"><title>Blog</title>
<entry><title type="html">Atom &amp;amp; post</title><link rel="alternate" href="https://blog.example.com/p1"/>
<id>tag:blog,1</id><updated>2026-10-07T11:00:00Z</updated><summary>Short summary</summary></entry>
</feed>`;

describe('RSS/Atom', () => {
  it('parses RSS 2.0 items into contract news', () => {
    const items = parseFeed(RSS, 'https://feeds.reuters.com/top');
    expect(items).toHaveLength(2);
    expect(items[0]).toMatchObject({
      title: 'Fed holds rates steady',
      detail: 'The Federal Reserve kept rates at 4.25-4.50% & signalled one cut.',
      source: 'reuters.com',
      url: 'https://www.reuters.com/x',
      publishedAt: '2026-10-07T13:10:00Z',
    });
    expect(items[0]?.id).toMatch(/^r-[0-9a-f]{12}$/);
  });

  it('parses Atom entries', () => {
    const items = parseFeed(ATOM, 'https://blog.example.com/feed');
    expect(items).toEqual([
      expect.objectContaining({ title: 'Atom & post', url: 'https://blog.example.com/p1', source: 'blog.example.com', publishedAt: '2026-10-07T11:00:00Z', detail: 'Short summary' }),
    ]);
  });

  it('returns [] for garbage', () => {
    expect(parseFeed('not xml at all', 'https://x.example/f')).toEqual([]);
  });

  it('fetches several feeds; one failing does not drop the others', async () => {
    agent.get('https://feeds.reuters.com').intercept({ path: '/top', method: 'GET' }).reply(200, RSS);
    agent.get('https://down.example').intercept({ path: '/rss', method: 'GET' }).reply(503, 'nope');
    const items = await fetchRss(['https://feeds.reuters.com/top', 'https://down.example/rss'], 2000);
    expect(items.map((i) => i.title)).toEqual(['Fed holds rates steady', 'Second']);
  });
});

describe('Finnhub', () => {
  it('fetches general news with X-Finnhub-Token', async () => {
    agent
      .get('https://finnhub.io')
      .intercept({ path: '/api/v1/news?category=general', method: 'GET', headers: { 'x-finnhub-token': 'fh' } })
      .reply(200, [
        { id: 77, headline: 'Nvidia unveils new data-center chip', summary: 'The chip targets inference.', source: 'Reuters', url: 'https://example.com/n2', datetime: 1791374400 },
        { bogus: true },
      ]);
    const items = await fetchFinnhub({ baseUrl: 'https://finnhub.io', key: 'fh', timeoutMs: 2000 });
    expect(items).toEqual([
      {
        id: 'f-77',
        title: 'Nvidia unveils new data-center chip',
        detail: 'The chip targets inference.',
        source: 'Reuters',
        url: 'https://example.com/n2',
        publishedAt: new Date(1791374400 * 1000).toISOString().replace('.000Z', 'Z'),
      },
    ]);
  });

  it('returns [] without a key (no request)', async () => {
    await expect(fetchFinnhub({ baseUrl: 'https://finnhub.io', key: undefined, timeoutMs: 1000 })).resolves.toEqual([]);
  });
});

describe('mergeNews', () => {
  it('dedupes by url and sorts newest first', () => {
    const a = { id: 'a', title: 'A', detail: '', source: 's', url: 'https://u/1', publishedAt: '2026-10-07T10:00:00Z' };
    const b = { ...a, id: 'b', title: 'B', url: 'https://u/2', publishedAt: '2026-10-07T12:00:00Z' };
    const dup = { ...a, id: 'c' };
    expect(mergeNews([a], [b, dup]).map((n) => n.id)).toEqual(['b', 'a']);
  });
});
