import { createHash, timingSafeEqual } from 'node:crypto';

const digest = (s: string) => createHash('sha256').update(s, 'utf8').digest();

/**
 * Constant-time bearer check. Both sides are hashed first so the comparison
 * length is fixed and does not leak the key length.
 */
export function keyMatches(header: string | undefined, key: string): boolean {
  if (!header) return false;
  const m = /^Bearer\s+(.+)$/i.exec(header.trim());
  const presented = m?.[1]?.trim() ?? '';
  const ok = timingSafeEqual(digest(presented), digest(key));
  return ok && presented.length > 0;
}
