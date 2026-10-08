export const TITLE_MAX = 60;
export const DETAIL_MAX = 600;

/** Collapse whitespace and cut to at most `max` characters (code points), ending in "…" when cut. */
export function truncate(input: string | null | undefined, max: number): string {
  const s = (input ?? '').replace(/\s+/g, ' ').trim();
  const chars = Array.from(s);
  if (chars.length <= max) return s;
  return chars.slice(0, max - 1).join('').trimEnd() + '…';
}

export const title = (s: string | null | undefined) => truncate(s, TITLE_MAX);
export const detail = (s: string | null | undefined) => truncate(s, DETAIL_MAX);

/** Parse anything date-like into ISO-8601 UTC without milliseconds, or null. */
export function isoUtc(v: string | number | Date | null | undefined): string | null {
  if (v === null || v === undefined || v === '') return null;
  let d: Date;
  if (typeof v === 'string') {
    // Python-style microseconds ("…:00.123456+00:00") → milliseconds for Date.parse.
    d = new Date(v.replace(/(\.\d{3})\d+/, '$1'));
  } else {
    d = new Date(v);
  }
  if (Number.isNaN(d.getTime())) return null;
  return d.toISOString().replace(/\.\d{3}Z$/, 'Z');
}

const ENTITIES: Record<string, string> = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ', '#39': "'" };

export function stripHtml(s: string | null | undefined): string {
  return (s ?? '')
    .replace(/<[^>]*>/g, ' ')
    .replace(/&(#\d+|#x[0-9a-f]+|[a-z]+);/gi, (m, e: string) => {
      const k = e.toLowerCase();
      if (ENTITIES[k] !== undefined) return ENTITIES[k];
      if (k.startsWith('#x')) return String.fromCodePoint(parseInt(k.slice(2), 16));
      if (k.startsWith('#')) return String.fromCodePoint(parseInt(k.slice(1), 10));
      return m;
    })
    .replace(/\s+/g, ' ')
    .trim();
}
