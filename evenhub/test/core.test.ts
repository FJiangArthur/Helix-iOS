// Unit tests mirroring Android ConversateSessionTest.kt, CueQueueTest.kt,
// CueParserTest.kt, plus the TS-only helpers (caption buffer, prompt, deduper).
import { beforeEach, describe, expect, it } from 'vitest';
import { CaptionBuffer, wrapText } from '../src/core/captionBuffer';
import { type Cue, CueQueue, type CueType } from '../src/core/cue';
import { parseCues } from '../src/core/cueParser';
import { loadCuePrompt } from '../src/core/cuePrompt';
import { IntentDeduper } from '../src/core/intents';
import { loadMenu } from '../src/core/menu';
import { type ConversatePrefs, DEFAULT_PREFS, type ScreenModel } from '../src/core/screen';
import { ConversateSession } from '../src/core/session';

type Live = Extract<ScreenModel, { kind: 'Live' }>;
type Menu = Extract<ScreenModel, { kind: 'Menu' }>;
type Detail = Extract<ScreenModel, { kind: 'CueDetail' }>;

describe('CueQueue', () => {
  const cue = (id: number, type: CueType, at = 0): Cue => ({ id, type, title: `t${id}`, body: `b${id}`, createdAtMillis: at });
  const drain = (q: CueQueue, now: number) => { const out: number[] = []; let c; while ((c = q.poll(now))) out.push(c.id); return out; };

  it('poll returns highest priority, fifo within priority', () => {
    const q = new CueQueue();
    q.offer(cue(1, 'SUGGESTION', 0), 0);
    q.offer(cue(2, 'CONCEPT', 1), 1);
    q.offer(cue(3, 'BIO', 2), 2);
    expect(drain(q, 3)).toEqual([2, 3, 1]);
  });

  it('overflow evicts oldest lowest priority', () => {
    const q = new CueQueue(3);
    q.offer(cue(1, 'SUGGESTION', 0), 0);
    q.offer(cue(2, 'SUGGESTION', 1), 1);
    q.offer(cue(3, 'CONCEPT', 2), 2);
    q.offer(cue(4, 'CONCEPT', 3), 3);
    expect(q.size).toBe(3);
    expect(drain(q, 4)).toEqual([3, 4, 2]);
  });

  it('answer is never evicted and may exceed capacity', () => {
    const q = new CueQueue(3);
    for (let i = 0; i < 3; i++) q.offer(cue(i, 'ANSWER', i), i);
    q.offer(cue(9, 'ANSWER', 9), 9);
    expect(q.size).toBe(4);
    q.offer(cue(10, 'CONCEPT', 10), 10);
    expect(q.size).toBe(4);
  });

  it('stale cues are dropped', () => {
    const q = new CueQueue(3, 90_000);
    q.offer(cue(1, 'CONCEPT', 0), 0);
    expect(q.count(90_001)).toBe(0);
    expect(q.poll(90_001)).toBeNull();
  });
});

describe('ConversateSession', () => {
  let now = 0;
  beforeEach(() => { now = 0; });
  const session = (prefs: Partial<ConversatePrefs> = {}, pages = 1) =>
    new ConversateSession(loadMenu(), () => now, { ...DEFAULT_PREFS, ...prefs }, () => pages);
  const cue = (id: number, type: CueType = 'CONCEPT'): Cue => ({ id, type, title: `T${id}`, body: `B${id}`, createdAtMillis: now });

  it('idle menu starts a session without prep notes', () => {
    const s = session();
    s.onIntent('MENU');
    expect(s.screen()).toEqual({
      kind: 'Menu', title: 'HELIX', items: ['Start session', 'Ask ChatGPT', 'News', 'X posts', 'To-dos', 'Omi', 'Mode', 'Display'], cursor: 0,
    });
    expect(s.selectContext).toBe(true);
    expect(s.onIntent('SELECT')).toEqual([{ type: 'Start', prepNoteId: null }]);
    expect(s.isLive).toBe(true);
    expect(s.screen().kind).toBe('Live');
  });

  it('start with prep notes shows picker', () => {
    const s = session();
    s.setPrepNotes([{ id: 'n1', title: 'Acme call', text: 'context' }]);
    s.onIntent('MENU'); s.onIntent('SELECT');
    expect(s.screen()).toEqual({ kind: 'Menu', title: 'PREP NOTE', items: ['Skip & start', 'Acme call'], cursor: 0 });
    s.onIntent('NEXT');
    expect(s.onIntent('SELECT')).toEqual([{ type: 'Start', prepNoteId: 'n1' }]);
  });

  it('cue pops, dwells, then collapses to captions', () => {
    const s = session(); s.startLive(null);
    s.onCaptionLines(['hello']);
    s.onCue(cue(1));
    expect((s.screen() as Live).cue).toEqual(cue(1));
    now += 6_001; s.tick();
    const live = s.screen() as Live;
    expect(live.cue).toBeNull();
    expect(live.captionLines).toEqual(['hello']);
  });

  it('auto popup off collapses cues to a count', () => {
    const s = session({ autoPopup: false }); s.startLive(null);
    s.onCue(cue(1)); s.onCue(cue(2));
    expect((s.screen() as Live).pendingCount).toBe(2);
    s.onIntent('SELECT');
    expect((s.screen() as Live).cue?.id).toBe(1);
  });

  it('next on a cue opens paged detail and back returns', () => {
    const s = session({}, 2); s.startLive(null);
    s.onCue(cue(1));
    s.onIntent('NEXT');
    expect(s.screen()).toEqual({ kind: 'CueDetail', cue: cue(1), page: 0 });
    s.onIntent('NEXT'); expect((s.screen() as Detail).page).toBe(1);
    s.onIntent('NEXT'); expect((s.screen() as Detail).page).toBe(1);
    s.onIntent('BACK');
    expect((s.screen() as Live).cue).toBeNull();
  });

  it('cues never interrupt an open menu', () => {
    const s = session(); s.startLive(null);
    s.onIntent('MENU');
    s.onCue(cue(1, 'ANSWER'));
    expect(s.screen().kind).toBe('Menu');
    s.onIntent('BACK');
    expect((s.screen() as Live).cue?.id).toBe(1);
  });

  it('answer preempts a shown concept', () => {
    const s = session(); s.startLive(null);
    s.onCue(cue(1)); s.onCue(cue(2, 'ANSWER'));
    expect((s.screen() as Live).cue?.id).toBe(2);
    now += 6_001; s.tick();
    expect((s.screen() as Live).cue?.id).toBe(1);
  });

  it('double back ends, timeout cancels', () => {
    const s = session(); s.startLive(null);
    s.onIntent('BACK');
    expect(s.screen()).toEqual({ kind: 'ConfirmEnd' });
    now += 3_001; s.tick();
    expect(s.screen().kind).toBe('Live');
    s.onIntent('BACK');
    now += 500;
    expect(s.onIntent('BACK')).toEqual([{ type: 'End' }]);
    expect(s.isLive).toBe(false);
    expect(s.screen()).toEqual({ kind: 'Blank' });
  });

  it('live menu toggles emit effects and relabel', () => {
    const s = session(); s.startLive(null);
    s.onIntent('MENU');
    expect(s.onIntent('SELECT')).toEqual([{ type: 'SetPaused', paused: true }]);
    expect((s.screen() as Menu).items[0]).toBe('Resume');
    s.onIntent('NEXT');
    expect(s.onIntent('SELECT')).toEqual([{ type: 'SetCaptions', on: false }]);
    for (let i = 0; i < 20; i++) s.onIntent('NEXT');
    expect((s.screen() as Menu).cursor).toBe(12);
    expect(s.onIntent('SELECT')).toEqual([{ type: 'End' }]);
  });

  it('cues off drops incoming cues', () => {
    const s = session({ cuesOn: false }); s.startLive(null);
    s.onCue(cue(1));
    expect((s.screen() as Live).cue).toBeNull();
  });

  it('captions off and nothing to show blanks the lens', () => {
    const s = session({ captionsOn: false }); s.startLive(null);
    s.onCaptionLines(['x']);
    expect(s.screen()).toEqual({ kind: 'Blank' });
  });

  it('display off blanks until any intent', () => {
    const s = session(); s.startLive(null);
    s.onIntent('MENU');
    for (let i = 0; i < 11; i++) s.onIntent('NEXT');
    s.onIntent('SELECT');
    expect(s.screen()).toEqual({ kind: 'Blank' });
    s.onIntent('PREV');
    expect(s.screen().kind).toBe('Live');
  });

  it('prep note opens paged view', () => {
    const s = session(); s.setPrepNotes([{ id: 'n1', title: 'Acme', text: 'Ctx' }]);
    s.startLive('n1');
    s.onIntent('MENU'); for (let i = 0; i < 3; i++) s.onIntent('NEXT'); s.onIntent('SELECT');
    expect(s.screen()).toEqual({ kind: 'PrepNoteView', title: 'Acme', text: 'Ctx', page: 0 });
    s.onIntent('BACK');
    expect(s.screen().kind).toBe('Live');
  });

  it('head movement neither wakes display off nor cancels end confirm', () => {
    const s = session(); s.startLive(null);
    s.onIntent('BACK');
    s.onIntent('HEAD_DOWN');
    expect(s.screen()).toEqual({ kind: 'ConfirmEnd' });
    now += 500;
    s.onIntent('PREV');
    s.onIntent('MENU'); for (let i = 0; i < 11; i++) s.onIntent('NEXT'); s.onIntent('SELECT');
    s.onIntent('HEAD_UP');
    expect(s.screen()).toEqual({ kind: 'Blank' });
  });
});

describe('ConversateSession 0.3 (overlays, pickers, panels, ask)', () => {
  let now = 0;
  beforeEach(() => { now = 0; });
  const session = (prefs: Partial<ConversatePrefs> = {}) =>
    new ConversateSession(loadMenu(), () => now, { ...DEFAULT_PREFS, ...prefs }, () => 1, (t) => (t.length > 20 ? 2 : 1));
  const openIdle = (s: ConversateSession, id: string) => {
    s.onIntent('MENU');
    const i = loadMenu().idle.findIndex((m) => m.id === id);
    for (let k = 0; k < i; k++) s.onIntent('NEXT');
    return s.onIntent('SELECT');
  };

  it('defaults prefs for caption lines and brightness', () => {
    expect(DEFAULT_PREFS.captionLines).toBe(5);
    expect(DEFAULT_PREFS.brightness).toBe(3);
  });

  it('mode picker cursor follows setMode from the phone', () => {
    const s = session();
    s.setMode('DISPLAY_ONLY');
    expect(s.currentMode).toBe('DISPLAY_ONLY');
    openIdle(s, 'mode');
    expect(s.screen()).toMatchObject({ kind: 'Menu', title: 'MODE', cursor: 2 });
  });

  it('mode picker uses the injected spec (G2 variant) for labels and ids', () => {
    const base = loadMenu();
    const variant = { ...base, pickers: { ...base.pickers!, mode: { title: 'MODE', items: [{ id: 'GLASSES_MIC', label: 'Glasses mic' }, ...base.pickers!.mode.items] } } };
    const s = new ConversateSession(variant, () => now);
    s.setMode('GLASSES_MIC');
    openIdle(s, 'mode');
    expect(s.screen()).toMatchObject({ items: ['Glasses mic', 'Phone mic', 'Omi pendant', 'Display only'], cursor: 0 });
    s.onIntent('NEXT');
    expect(s.onIntent('SELECT')).toEqual([{ type: 'SetMode', mode: 'PHONE_MIC' }]);
  });

  it('cue time cycles to the next listed value even from an unlisted one', () => {
    const s = session({ cueDurationMillis: 7_000 });
    openIdle(s, 'display');
    s.onIntent('NEXT');
    expect(s.onIntent('SELECT')).toEqual([{ type: 'SetPref', id: 'cueSeconds', value: 10 }]);
    expect(s.currentPrefs.cueDurationMillis).toBe(10_000);
  });

  it('display picker changes prefs, captions pref toggles captionsOn', () => {
    const s = session();
    openIdle(s, 'display');
    for (let i = 0; i < 3; i++) s.onIntent('NEXT');
    s.onIntent('SELECT');
    expect(s.currentPrefs.captionsOn).toBe(false);
    s.onIntent('PREV'); s.onIntent('SELECT');
    expect(s.currentPrefs.brightness).toBe(4);
  });

  it('panel rows arriving while closed are shown on open; cursor clamps on replace', () => {
    const s = session();
    s.setPanelRows('news', [{ id: 'a', title: 'A', detail: 'aa' }, { id: 'b', title: 'B', detail: 'bb' }]);
    expect(openIdle(s, 'news')).toEqual([{ type: 'RequestPanel', kind: 'news' }]);
    expect(s.screen()).toEqual({ kind: 'Panel', title: 'NEWS', items: ['A', 'B'], cursor: 0 });
    s.onIntent('NEXT'); s.onIntent('NEXT');
    expect(s.screen()).toMatchObject({ cursor: 1 });
    s.setPanelRows('news', [{ id: 'a', title: 'A', detail: 'aa' }]);
    expect(s.screen()).toMatchObject({ items: ['A'], cursor: 0 });
  });

  it('panel detail pages and returns to the panel', () => {
    const s = session();
    s.setPanelRows('x', [{ id: 'a', title: 'Post', detail: 'a long enough detail text' }]);
    openIdle(s, 'x');
    s.onIntent('SELECT');
    expect(s.screen()).toEqual({ kind: 'PanelDetail', title: 'Post', text: 'a long enough detail text', page: 0 });
    s.onIntent('NEXT'); s.onIntent('NEXT');
    expect(s.screen()).toMatchObject({ page: 1 });
    s.onIntent('BACK');
    expect(s.screen()).toMatchObject({ kind: 'Panel', title: 'X POSTS' });
  });

  it('empty panel SELECT is a no-op', () => {
    const s = session();
    openIdle(s, 'omi');
    expect(s.onIntent('SELECT')).toEqual([]);
    expect(s.screen()).toEqual({ kind: 'Panel', title: 'OMI', items: ['Nothing here'], cursor: 0 });
  });

  it('ask text outside the Ask overlay is ignored', () => {
    const s = session();
    expect(s.onAskText('hello')).toEqual([]);
    expect(s.isAsking).toBe(false);
    openIdle(s, 'ask');
    expect(s.isAsking).toBe(true);
    expect(s.onAskText('  ')).toEqual([]);
    expect(s.onAskText('Why?')).toEqual([{ type: 'AskQuestion', text: 'Why?' }]);
    expect(s.isAsking).toBe(false);
  });

  it('showAnswer opens the answer as a cue detail when not live; BACK returns home', () => {
    const s = session();
    const answer: Cue = { id: 9, type: 'ANSWER', title: 'Answer', body: 'Canberra.', createdAtMillis: 0 };
    s.showAnswer(answer);
    expect(s.screen()).toEqual({ kind: 'CueDetail', cue: answer, page: 0 });
    s.onIntent('BACK');
    expect(s.screen()).toEqual({ kind: 'Blank' });
  });

  it('showAnswer while the Ask overlay is open cancels it first (AskCancel)', () => {
    const s = session();
    openIdle(s, 'ask');
    const answer: Cue = { id: 9, type: 'ANSWER', title: 'Answer', body: 'Canberra.', createdAtMillis: 0 };
    expect(s.showAnswer(answer)).toEqual([{ type: 'AskCancel' }]);
    expect(s.isAsking).toBe(false);
    expect(s.screen()).toEqual({ kind: 'CueDetail', cue: answer, page: 0 });
    expect(s.showAnswer(answer)).toEqual([]);
  });

  it('live ask from the live menu returns to the live screen', () => {
    const s = session(); s.startLive(null);
    s.onIntent('MENU');
    for (let i = 0; i < 4; i++) s.onIntent('NEXT');
    expect(s.onIntent('SELECT')).toEqual([{ type: 'AskListen' }]);
    expect(s.screen()).toEqual({ kind: 'Ask' });
    s.onAskText('Q?');
    expect(s.screen().kind).toBe('Live');
  });
});

describe('CueParser extras', () => {
  it('newlines in fields are collapsed', () => {
    const [cue] = parseCues('{"cues":[{"type":"BIO","title":"Ada\\nLovelace","body":"First\\n\\nprogrammer."}]}')!;
    expect(cue!.title).toBe('Ada Lovelace');
    expect(cue!.body).toBe('First programmer.');
  });

  it('fields are bounded', () => {
    const raw = `{"cues":[{"type":"CONCEPT","title":"t","body":"${'b'.repeat(400)}","detail":"${'d'.repeat(2000)}"}]}`;
    const [cue] = parseCues(raw)!;
    expect(cue!.body.length).toBeLessThanOrEqual(220);
    expect(cue!.detail!.length).toBeLessThanOrEqual(1000);
  });
});

describe('IntentDeduper', () => {
  it('drops the same intent from another source within 250 ms only', () => {
    let now = 0;
    const d = new IntentDeduper(() => now);
    expect(d.accept('NEXT', 'G2_TOUCHPAD')).toBe(true);
    now = 100;
    expect(d.accept('NEXT', 'R1')).toBe(false);
    expect(d.accept('NEXT', 'G2_TOUCHPAD')).toBe(true);
    now = 400;
    expect(d.accept('NEXT', 'R1')).toBe(true);
  });
});

describe('CaptionBuffer', () => {
  it('wraps on spaces and hard-splits long words', () => {
    expect(wrapText('aaa bbb ccc', 7)).toEqual(['aaa bbb', 'ccc']);
    expect(wrapText('abcdefghij', 4)).toEqual(['abcd', 'efgh', 'ij']);
    expect(wrapText('   ', 5)).toEqual([]);
  });

  it('shows committed finals plus the current partial, last N lines', () => {
    const b = new CaptionBuffer((t) => wrapText(t, 10), 2);
    b.onSegment({ text: 'hello there', isFinal: true });
    b.onSegment({ text: 'general', isFinal: false });
    expect(b.lines()).toEqual(['there', 'general']);
    b.onSegment({ text: 'general kenobi', isFinal: true });
    expect(b.lines()).toEqual(['there', 'general', 'kenobi'].slice(-2));
    b.clear();
    expect(b.lines()).toEqual([]);
  });

  it('keeps only the last finals', () => {
    const b = new CaptionBuffer((t) => wrapText(t, 100), 5, 2);
    ['a', 'b', 'c'].forEach((t) => b.onSegment({ text: t, isFinal: true }));
    expect(b.lines()).toEqual(['b c']);
  });
});

describe('cue prompt', () => {
  it('renders the shared template placeholders', () => {
    const p = loadCuePrompt();
    expect(p.maxTokens).toBe(600);
    const text = p.render('we use RAG', '', []);
    expect(text).toContain('we use RAG');
    expect(text).toContain('Never repeat these already-shown cues: (none)');
    expect(text).not.toContain('{{');
    expect(p.render('x', 'notes', ['A', 'B'])).toContain('already-shown cues: A, B');
  });
});
