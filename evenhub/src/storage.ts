// Settings persistence: Even App storage via the bridge, browser localStorage
// outside the Even app (simulator / plain browser), memory as a last resort.
import type { PrepNoteRef } from './core/screen';

export interface KeyValueStore {
  get(key: string): Promise<string | null>;
  set(key: string, value: string): Promise<void>;
}

export interface BridgeStorage {
  getLocalStorage(key: string): Promise<string>;
  setLocalStorage(key: string, value: string): Promise<boolean>;
}

export function bridgeStore(bridge: BridgeStorage): KeyValueStore {
  return {
    async get(key) {
      const v = await bridge.getLocalStorage(key);
      return v === '' || v == null ? null : v;
    },
    async set(key, value) {
      await bridge.setLocalStorage(key, value);
    },
  };
}

export function memoryStore(initial: Record<string, string> = {}): KeyValueStore & { data: Record<string, string> } {
  const data = { ...initial };
  return {
    data,
    async get(key) { return key in data ? data[key]! : null; },
    async set(key, value) { data[key] = value; },
  };
}

export function browserStore(): KeyValueStore {
  try {
    const ls = globalThis.localStorage;
    if (!ls) return memoryStore();
    return {
      async get(key) { try { return ls.getItem(key); } catch { return null; } },
      async set(key, value) { try { ls.setItem(key, value); } catch { /* storage blocked */ } },
    };
  } catch {
    return memoryStore();
  }
}

export const KEYS = {
  apiKey: 'helix.openaiKey',
  prefs: 'helix.prefs',
  prepNotes: 'helix.prepNotes',
  audioSource: 'helix.audioSource',
  mode: 'helix.mode',
  relayUrl: 'helix.relayUrl',
  relayKey: 'helix.relayKey',
} as const;

export const PREP_NOTE_MAX_CHARS = 5_000;

export function parseJson<T>(raw: string | null, fallback: T): T {
  if (raw == null) return fallback;
  try {
    return JSON.parse(raw) as T;
  } catch {
    return fallback;
  }
}

export function sanitizePrepNotes(value: unknown): PrepNoteRef[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((n): n is PrepNoteRef => typeof n === 'object' && n !== null && typeof n.id === 'string' && typeof n.text === 'string')
    .map((n) => ({ id: n.id, title: (typeof n.title === 'string' && n.title.trim()) || 'Untitled', text: n.text.slice(0, PREP_NOTE_MAX_CHARS) }));
}
