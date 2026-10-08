import { utf8ByteLength } from '@evenrealities/even_hub_sdk';
import { describe, expect, it } from 'vitest';
import type { Cue } from '../src/core/cue';
import { loadMenu } from '../src/core/menu';
import type { ScreenModel } from '../src/core/screen';
import { buildContextMenu, contextMenuItemId, menuIdForItem } from '../src/g2/contextMenu';
import { detailPageCount, renderPage, textPageCount } from '../src/g2/render';
import { validatePage } from '../src/g2/validate';

const menu = loadMenu();
const liveFlags = { paused: false, captions: true, cues: true };
const liveMenu = buildContextMenu(menu, true, liveFlags);
const cue = (over: Partial<Cue> = {}): Cue => ({ id: 1, type: 'CONCEPT', title: 'RAG', body: 'Retrieval augmented generation.', createdAtMillis: 0, ...over });
const live = (over: Partial<Extract<ScreenModel, { kind: 'Live' }>> = {}): ScreenModel => ({
  kind: 'Live', cue: null, pendingCount: 0, captionLines: ['hello there'], captionsOn: true, paused: false, ...over,
});

const longText = 'word '.repeat(600).trim();
const models: Record<string, ScreenModel> = {
  blank: { kind: 'Blank' },
  liveCaptions: live(),
  liveEmpty: live({ captionLines: [] }),
  liveCue: live({ cue: cue() }),
  liveCueDetailMarker: live({ cue: cue({ detail: 'More words.' }) }),
  liveLongCue: live({ cue: cue({ title: 'x'.repeat(24), body: 'é'.repeat(220) }) }),
  livePending: live({ pendingCount: 2 }),
  livePaused: live({ paused: true }),
  liveManyCaptions: live({ captionLines: Array.from({ length: 30 }, (_, i) => `line ${i} `.repeat(5)) }),
  cueDetail: { kind: 'CueDetail', cue: cue({ detail: longText }), page: 2 },
  menu: { kind: 'Menu', title: 'HELIX', items: ['Pause', 'Captions: on', 'Cues: on', 'Prep Note', 'Display off', 'End session'], cursor: 3 },
  bigMenu: { kind: 'Menu', title: 'PREP NOTE', items: Array.from({ length: 25 }, (_, i) => `Note ${i} ${'y'.repeat(80)}`), cursor: 21 },
  prep: { kind: 'PrepNoteView', title: 'Acme', text: longText, page: 1 },
  confirm: { kind: 'ConfirmEnd' },
  panel: { kind: 'Panel', title: 'TO-DO', items: ['[ ] Send Q3 churn deck to Sam', '[x] Book dentist'], cursor: 1 },
  bigPanel: { kind: 'Panel', title: 'NEWS', items: Array.from({ length: 30 }, (_, i) => `Headline ${i} ${'é'.repeat(70)}`), cursor: 17 },
  panelDetail: { kind: 'PanelDetail', title: 'Fed holds rates steady', text: longText, page: 1 },
  ask: { kind: 'Ask' },
};

describe('renderPage', () => {
  for (const [name, model] of Object.entries(models)) {
    it(`${name} renders a page the SDK and firmware limits accept`, () => {
      const r = renderPage(model, { menu: liveMenu });
      expect(r.kind).toBe('rebuild');
      const v = validatePage(r.page);
      expect(v, JSON.stringify(v)).toEqual({ valid: true });
      expect(r.page.menuObject).toEqual(liveMenu);
    });
  }

  it('caption-only change is an upgrade, not a rebuild', () => {
    const first = renderPage(live({ captionLines: ['a'] }), { menu: liveMenu });
    const second = renderPage(live({ captionLines: ['a', 'b'] }), { menu: liveMenu, previous: first });
    expect(second.kind).toBe('upgrade');
    expect(second.upgrades).toEqual([{ containerID: 3, containerName: 'main', content: 'a\nb' }]);
  });

  it('caption change under a shown cue upgrades only the caption container', () => {
    const first = renderPage(live({ cue: cue(), captionLines: ['a'] }), { menu: liveMenu });
    const second = renderPage(live({ cue: cue(), captionLines: ['b'] }), { menu: liveMenu, previous: first });
    expect(second.kind).toBe('upgrade');
    expect(second.upgrades.map((u) => u.containerName)).toEqual(['captions']);
  });

  it('identical model yields an empty upgrade', () => {
    const first = renderPage(live(), { menu: liveMenu });
    const again = renderPage(live(), { menu: liveMenu, previous: first });
    expect(again.kind).toBe('upgrade');
    expect(again.upgrades).toEqual([]);
  });

  it('a cue appearing is structural (rebuild)', () => {
    const first = renderPage(live(), { menu: liveMenu });
    expect(renderPage(live({ cue: cue() }), { menu: liveMenu, previous: first }).kind).toBe('rebuild');
  });

  it('menu cursor moves are upgrades of the same layout', () => {
    const m = models.menu as Extract<ScreenModel, { kind: 'Menu' }>;
    const first = renderPage(m, { menu: liveMenu });
    const second = renderPage({ ...m, cursor: 4 }, { menu: liveMenu, previous: first });
    expect(second.kind).toBe('upgrade');
    expect(second.upgrades[0]!.content).toContain('> Display off');
  });

  it('a changed context menu forces a rebuild so menuObject is re-sent', () => {
    const first = renderPage(live(), { menu: liveMenu });
    const paused = buildContextMenu(menu, true, { ...liveFlags, paused: true });
    const second = renderPage(live(), { menu: paused, previous: first });
    expect(second.kind).toBe('rebuild');
    expect(second.page.menuObject).toEqual(paused);
  });

  it('cue card shows type label, title, body and a more marker', () => {
    const r = renderPage(live({ cue: cue({ type: 'SUGGESTION', detail: 'd' }) }), { menu: liveMenu });
    const cueText = r.page.textObject!.find((t) => t.containerName === 'cue')!;
    expect(cueText.content).toBe('* IDEA  RAG\nRetrieval augmented generation. >>');
    expect(cueText.borderWidth).toBeGreaterThan(0);
  });

  it('pending cues show a count line above captions', () => {
    const r = renderPage(live({ pendingCount: 2 }), { menu: liveMenu });
    expect(r.page.textObject![0]!.content!.split('\n')[0]).toBe('* 2 new cues');
  });

  it('detail pages slice the wrapped detail text', () => {
    const c = cue({ detail: longText });
    const pages = detailPageCount(c);
    expect(pages).toBeGreaterThan(2);
    const last = renderPage({ kind: 'CueDetail', cue: c, page: pages - 1 }, { menu: liveMenu });
    expect(last.page.textObject![0]!.content).toContain(`${pages}/${pages}`);
    expect(textPageCount('short')).toBe(1);
  });

  it('every text container fits the 999-byte create limit', () => {
    for (const model of Object.values(models)) {
      for (const t of renderPage(model, { menu: liveMenu }).page.textObject ?? []) {
        expect(utf8ByteLength(t.content ?? '')).toBeLessThanOrEqual(999);
      }
    }
  });
});

describe('renderPage 0.3 (panels, ask, display prefs)', () => {
  it('panel shows title + counter header and a > cursor on the selected row', () => {
    const r = renderPage(models.panel!, { menu: liveMenu });
    const lines = r.page.textObject![0]!.content!.split('\n');
    expect(lines[0]).toMatch(/^TO-DO\s+2\/2$/);
    expect(lines[1]).toBe('  [ ] Send Q3 churn deck to Sam');
    expect(lines[2]).toBe('> [x] Book dentist');
  });

  it('panel cursor moves are upgrades', () => {
    const p = models.panel as Extract<ScreenModel, { kind: 'Panel' }>;
    const first = renderPage(p, { menu: liveMenu });
    expect(renderPage({ ...p, cursor: 0 }, { menu: liveMenu, previous: first }).kind).toBe('upgrade');
  });

  it('big panel scrolls to the window holding the cursor', () => {
    const text = renderPage(models.bigPanel!, { menu: liveMenu }).page.textObject![0]!.content!;
    expect(text).toContain('18/30');
    expect(text).toContain('> Headline 17');
  });

  it('panel detail is paged with the title on the first page and a footer', () => {
    const first = renderPage({ kind: 'PanelDetail', title: 'Fed', text: longText, page: 0 }, { menu: liveMenu });
    const content = first.page.textObject![0]!.content!;
    expect(content.startsWith('Fed\n')).toBe(true);
    expect(content).toMatch(/\[1\/\d+\]$/);
  });

  it('ask screen says it is listening', () => {
    expect(renderPage({ kind: 'Ask' }, { menu: liveMenu }).page.textObject![0]!.content).toContain('Ask: listening...');
  });

  it('captionLines caps caption rows in captions-only and pending layouts', () => {
    const many = live({ captionLines: ['a', 'b', 'c', 'd', 'e', 'f'] });
    expect(renderPage(many, { menu: liveMenu, captionLines: 2 }).page.textObject![0]!.content).toBe('e\nf');
    const pending = live({ captionLines: ['a', 'b', 'c'], pendingCount: 1 });
    expect(renderPage(pending, { menu: liveMenu, captionLines: 2 }).page.textObject![0]!.content).toBe('* 1 new cue\nb\nc');
  });

  it('brightness sets textColor on every text container and a change rebuilds', () => {
    for (const model of Object.values(models)) {
      const r = renderPage(model, { menu: liveMenu, brightness: 2 });
      expect(validatePage(r.page)).toEqual({ valid: true });
      for (const t of r.page.textObject ?? []) expect(t.textColor).toBe(2);
    }
    const first = renderPage(live(), { menu: liveMenu, brightness: 2 });
    expect(renderPage(live(), { menu: liveMenu, brightness: 4, previous: first }).kind).toBe('rebuild');
  });
});

describe('context menu', () => {
  it('maps the first 10 menu.json live items to stable non-zero ids (contract 0.3 §1)', () => {
    expect(liveMenu.menuItems!.map((i) => i.itemName)).toEqual([
      'Pause', 'Captions: on', 'Cues: on', 'Prep Note', 'Ask ChatGPT', 'News', 'X posts', 'To-dos', 'Omi', 'Mode',
    ]);
    const ids = liveMenu.menuItems!.map((i) => i.itemID);
    expect(new Set(ids).size).toBe(ids.length);
    expect(ids.every((id) => Number.isInteger(id) && id! > 0)).toBe(true);
    expect(menuIdForItem(contextMenuItemId('end')!)).toBe('end');
    expect(contextMenuItemId('display_off')).not.toBeNull();
    expect(menuIdForItem(999)).toBeNull();
  });

  it('idle context menu offers Start session', () => {
    const idle = buildContextMenu(menu, false, liveFlags);
    expect(idle.menuItems!.map((i) => i.itemName)).toEqual(['Start session', 'Ask ChatGPT', 'News', 'X posts', 'To-dos', 'Omi', 'Mode', 'Display']);
    expect(menuIdForItem(idle.menuItems![0]!.itemID!)).toBe('start');
  });

  it('labels relabel with toggle flags', () => {
    const m = buildContextMenu(menu, true, { paused: true, captions: false, cues: false });
    expect(m.menuItems!.slice(0, 3).map((i) => i.itemName)).toEqual(['Resume', 'Captions: off', 'Cues: off']);
  });
});

describe('validatePage', () => {
  it('rejects zero or two event-capture containers and oversize text', () => {
    const base = { xPosition: 0, yPosition: 0, width: 100, height: 100, containerID: 1, containerName: 'a', content: 'x' };
    expect(validatePage({ containerTotalNum: 1, textObject: [{ ...base, isEventCapture: 0 }] }).valid).toBe(false);
    expect(validatePage({ containerTotalNum: 2, textObject: [{ ...base, isEventCapture: 1 }, { ...base, containerID: 2, containerName: 'b', isEventCapture: 1 }] }).valid).toBe(false);
    expect(validatePage({ containerTotalNum: 1, textObject: [{ ...base, isEventCapture: 1, content: 'x'.repeat(1000) }] }).valid).toBe(false);
    expect(validatePage({ containerTotalNum: 1, textObject: [{ ...base, isEventCapture: 1, width: 600 }] }).valid).toBe(false);
    expect(validatePage({ containerTotalNum: 1, textObject: [{ ...base, isEventCapture: 1 }] }).valid).toBe(true);
  });
});
