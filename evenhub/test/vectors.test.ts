// Runs the shared conversate-core vectors with the same semantics as Android's
// SessionVectorTest.kt and CueParserTest.kt. The vectors are the arbiter: never
// edit them to make this pass.
import { readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { describe, expect, it } from 'vitest';
import { type Cue, CueType } from '../src/core/cue';
import { parseCues } from '../src/core/cueParser';
import type { ConversateIntent } from '../src/core/intents';
import { loadMenu } from '../src/core/menu';
import type { PanelKind, PanelRow, ScreenModel, SessionEffect } from '../src/core/screen';
import { ConversateSession } from '../src/core/session';

const vectorsDir = fileURLToPath(new URL('../../conversate-core/vectors/', import.meta.url));
const read = (name: string) => JSON.parse(readFileSync(vectorsDir + name, 'utf8'));

function label(e: SessionEffect): string {
  switch (e.type) {
    case 'Start': return `Start:${e.prepNoteId}`;
    case 'End': return 'End';
    case 'SetPaused': return `SetPaused:${e.paused}`;
    case 'SetCaptions': return `SetCaptions:${e.on}`;
    case 'SetCues': return `SetCues:${e.on}`;
    case 'SetMode': return `SetMode:${e.mode}`;
    case 'SetPref': return `SetPref:${e.id}=${e.value}`;
    case 'RequestPanel': return `RequestPanel:${e.kind}`;
    case 'ToggleTodo': return `ToggleTodo:${e.id}=${e.done}`;
    case 'AskListen': return 'AskListen';
    case 'AskCancel': return 'AskCancel';
    case 'AskQuestion': return `AskQuestion:${e.text}`;
  }
}

function check(where: string, e: Record<string, any>, s: ConversateSession) {
  const screen: ScreenModel = s.screen();
  if ('kind' in e) expect(screen.kind, where).toBe(e.kind);
  if ('live' in e) expect(s.isLive, where).toBe(e.live);
  if ('title' in e) expect((screen as { title?: string }).title, where).toBe(e.title);
  if ('cueId' in e) {
    const id = screen.kind === 'Live' ? screen.cue?.id ?? null : screen.kind === 'CueDetail' ? screen.cue.id : null;
    expect(id, where).toBe(e.cueId);
  }
  if ('pendingCount' in e) expect((screen as Extract<ScreenModel, { kind: 'Live' }>).pendingCount, where).toBe(e.pendingCount);
  if ('cursor' in e) expect((screen as Extract<ScreenModel, { kind: 'Menu' }>).cursor, where).toBe(e.cursor);
  if ('items' in e) expect((screen as Extract<ScreenModel, { kind: 'Menu' }>).items, where).toEqual(e.items);
  if ('page' in e) {
    const page = screen.kind === 'CueDetail' || screen.kind === 'PrepNoteView' || screen.kind === 'PanelDetail' ? screen.page : -1;
    expect(page, where).toBe(e.page);
  }
}

function runSessionVector(file: string) {
  const root = read(file);
  const name: string = root.name;
  let now = 0;
  const p = root.prefs ?? {};
  const s = new ConversateSession(loadMenu(), () => now, {
    captionsOn: p.captionsOn ?? true,
    cuesOn: p.cuesOn ?? true,
    autoPopup: p.autoPopup ?? true,
    cueDurationMillis: p.cueDurationMillis ?? 6000,
    captionLines: p.captionLines ?? 5,
    brightness: p.brightness ?? 3,
  });
  if (root.prepNotes) s.setPrepNotes(root.prepNotes.map((n: any) => ({ id: n.id, title: n.title, text: n.text })));
  (root.steps as Record<string, any>[]).forEach((step, i) => {
    const where = `${name} step ${i}`;
    if ('advance' in step) now += step.advance;
    let effects: SessionEffect[] = [];
    if ('start' in step) effects = s.startLive(step.start ?? null);
    if ('captions' in step) s.onCaptionLines(step.captions);
    if (step.cue) {
      const c = step.cue;
      const cue: Cue = { id: c.id, type: CueType.valueOf(c.type), title: c.title, body: c.body, createdAtMillis: now };
      s.onCue(cue);
    }
    if (step.tick === true) s.tick();
    if (step.panelRows) {
      const rows: PanelRow[] = step.panelRows.rows.map((r: any) => ({ id: r.id, title: r.title, detail: r.detail ?? '', done: r.done }));
      s.setPanelRows(step.panelRows.kind as PanelKind, rows);
    }
    if ('askText' in step) effects = s.onAskText(step.askText);
    if ('intent' in step) effects = s.onIntent(step.intent as ConversateIntent);
    if ('effects' in step) expect(effects.map(label), where).toEqual(step.effects);
    if (step.expect) check(where, step.expect, s);
  });
}

const sessionFiles = readdirSync(vectorsDir).filter((f) => /^session-.*\.json$/.test(f)).sort();

describe('shared session vectors', () => {
  it('finds the vector files', () => {
    expect(sessionFiles.length).toBeGreaterThanOrEqual(3);
  });
  for (const file of sessionFiles) {
    it(file, () => runSessionVector(file));
  }
});

describe('shared cue-parse vectors', () => {
  const cases: Record<string, any>[] = read('cue-parse.json');
  for (const c of cases) {
    it(c.name, () => {
      const result = parseCues(c.raw);
      if (c.rejected === true) expect(result).toBeNull();
      else expect(result!.map((x) => x.title)).toEqual(c.titles);
    });
  }
});
