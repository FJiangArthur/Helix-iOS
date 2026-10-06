// Parses the cue-extraction model output (conversate-core/cue-schema.json).
// Port of Android CueParser.kt: tolerates code fences and surrounding prose;
// anything else is rejected (null) and never shown on the lens.
import { CueType } from './cue';

export interface ParsedCue {
  type: CueType;
  title: string;
  body: string;
  detail: string | null;
  entity: string | null;
}

export const TITLE_MAX = 24;
export const BODY_MAX = 220;
export const DETAIL_MAX = 1000;

const DEFAULT_ALLOWED: ReadonlySet<CueType> = new Set<CueType>(['CONCEPT', 'BIO', 'SUGGESTION']);

const squash = (s: string) => s.trim().replace(/\s+/g, ' ');
const bound = (text: string, max: number) => (text.length <= max ? text : text.slice(0, max - 1) + '~');
const str = (v: unknown, fallback: string): string => (typeof v === 'string' ? v : fallback);

/** Parsed cues, or null when [raw] holds no decodable cue envelope. */
export function parseCues(raw: string, allowed: ReadonlySet<CueType> = DEFAULT_ALLOWED): ParsedCue[] | null {
  const start = raw.indexOf('{');
  const end = raw.lastIndexOf('}');
  if (start < 0 || end <= start) return null;
  let envelope: unknown;
  try {
    envelope = JSON.parse(raw.slice(start, end + 1));
  } catch {
    return null;
  }
  if (typeof envelope !== 'object' || envelope === null || Array.isArray(envelope)) return null;
  const cuesField = (envelope as { cues?: unknown }).cues;
  if (cuesField !== undefined && !Array.isArray(cuesField)) return null;
  const cues = (cuesField ?? []) as unknown[];
  const out: ParsedCue[] = [];
  for (const c of cues) {
    if (typeof c !== 'object' || c === null) continue;
    const r = c as Record<string, unknown>;
    const type = CueType.parse(str(r.type, '').trim().toUpperCase());
    if (type === null || !allowed.has(type)) continue;
    const title = squash(str(r.title, ''));
    const body = squash(str(r.body, ''));
    if (title === '' || body === '') continue;
    const detail = typeof r.detail === 'string' ? squash(r.detail) : '';
    const entity = typeof r.entity === 'string' ? r.entity.trim() : '';
    out.push({
      type,
      title: bound(title, TITLE_MAX),
      body: bound(body, BODY_MAX),
      detail: detail === '' ? null : bound(detail, DETAIL_MAX),
      entity: entity === '' ? null : entity,
    });
  }
  return out;
}
