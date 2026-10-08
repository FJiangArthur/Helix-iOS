// ScreenModel -> Even Hub page (spec §7). Pure: given the model, the context
// menu and the previously rendered result, decide between a structural
// rebuild and flicker-free textContainerUpgrade calls.
//
// Layouts (576x288 canvas):
//   live-captions  one full-screen text container, last caption lines
//   live-cue       bordered cue card on top + caption strip below
//   main           full-screen text for menu / panel / cue, panel detail / prep note / ask / blank
//   confirm        centred confirm-end box
// The session owns cursors and pages, so menus and long text are drawn as
// text (with a `>` cursor / `p/n` footer) rather than native lists/scroll.
import { MenuContainerProperty, RebuildPageContainer, TextContainerProperty, TextContainerUpgrade } from '@evenrealities/even_hub_sdk';
import { wrapText } from '../core/captionBuffer';
import { type Cue, CueType } from '../core/cue';
import { HudGlyphs, type ScreenModel } from '../core/screen';
import { fitBytes } from './contextMenu';
import { CANVAS_HEIGHT, CANVAS_WIDTH, TEXT_CREATE_MAX_BYTES } from './validate';

/** Characters per full-width line; conservative estimate of the G2 font (see NOTES.md). */
export const LINE_CHARS = 54;
/** Full-screen lines we fill (the font fits ~10; one is left as headroom). */
export const FULL_LINES = 9;
export const CUE_BODY_LINES = 3;
export const CUE_CAPTION_LINES = 4;
const PAGE_LINES = FULL_LINES - 1; // last line is the `p/n` footer

const ID = { cue: 1, captions: 2, main: 3, confirm: 4 } as const;
type Name = keyof typeof ID;

interface Box {
  name: Name;
  x: number;
  y: number;
  w: number;
  h: number;
  border?: boolean;
  capture?: boolean;
  content: string;
}

export interface RenderResult {
  kind: 'rebuild' | 'upgrade';
  layoutKey: string;
  /** Full page (also used for createStartUpPageContainer on first render). */
  page: RebuildPageContainer;
  upgrades: TextContainerUpgrade[];
  contents: Record<string, string>;
}

export interface RenderOptions {
  menu: MenuContainerProperty;
  previous?: RenderResult | null;
  /** Shown instead of an empty page when no session is running (review: never a black screen). */
  idleHint?: string;
  /** Caption rows in captions-only / pending layouts (prefs.captionLines, 2..5); default fills the screen. */
  captionLines?: number;
  /** Text brightness 1..4 (prefs.brightness) -> `textColor` on every text container; omitted = device default. */
  brightness?: number;
}

export const ASK_LISTENING = 'Ask: listening...';

const fit = (text: string, max = LINE_CHARS) => (text.length <= max ? text : text.slice(0, max - 1).trimEnd() + '~');

/** Same paragraph-aware pagination as Android G1HudComposer.pages(), G2 sizes. */
function pages(text: string): string[][] {
  const lines = text.split('\n').flatMap((p) => (p.trim() === '' ? [''] : wrapText(p, LINE_CHARS)));
  const out: string[][] = [];
  for (let i = 0; i < lines.length; i += PAGE_LINES) out.push(lines.slice(i, i + PAGE_LINES));
  return out.length === 0 ? [[]] : out;
}

const detailText = (cue: Cue) => `${HudGlyphs.CUE} ${CueType.label(cue.type)}  ${cue.title}\n${cue.detail ?? cue.body}`;

export const detailPageCount = (cue: Cue) => pages(detailText(cue)).length;
export const textPageCount = (text: string) => pages(text).length;

function paged(text: string, page: number): string {
  const all = pages(text);
  const index = Math.max(0, Math.min(page, all.length - 1));
  const body = all[index]!.join('\n');
  return all.length > 1 ? `${body}\n[${index + 1}/${all.length}]` : body;
}

/** Menu and dashboard panel: title + `n/N` counter, rows with a `>` cursor, windowed around the cursor. */
function menuText(s: { title: string; items: string[]; cursor: number }): string {
  const visible = FULL_LINES - 1;
  const start = Math.floor(s.cursor / visible) * visible;
  const counter = `${s.cursor + 1}/${s.items.length}`;
  const title = s.title.slice(0, LINE_CHARS - counter.length - 1);
  const header = title + ' '.repeat(Math.max(1, LINE_CHARS - title.length - counter.length)) + counter;
  const rows = s.items.slice(start, start + visible).map((item, i) => fit((start + i === s.cursor ? `${HudGlyphs.CURSOR} ` : '  ') + item));
  return [header, ...rows].join('\n');
}

function cueCard(cue: Cue): string {
  const header = fit(`${HudGlyphs.CUE} ${CueType.label(cue.type)}  ${cue.title}`);
  const body = wrapText(cue.body, LINE_CHARS);
  const shown = body.slice(0, CUE_BODY_LINES);
  if (cue.detail != null || body.length > CUE_BODY_LINES) {
    const i = Math.max(0, shown.length - 1);
    shown[i] = fit(shown[i] ?? '', LINE_CHARS - HudGlyphs.MORE.length - 1) + ' ' + HudGlyphs.MORE;
  }
  return [header, ...shown].join('\n');
}

function layout(model: ScreenModel, idleHint?: string, captionLimit = FULL_LINES): { key: string; boxes: Box[] } {
  const full = (content: string): Box[] => [{ name: 'main', x: 0, y: 0, w: CANVAS_WIDTH, h: CANVAS_HEIGHT, capture: true, content }];
  switch (model.kind) {
    case 'Blank':
      return { key: 'main', boxes: full(idleHint ?? ' ') };
    case 'Menu':
    case 'Panel':
      return { key: 'main', boxes: full(menuText(model)) };
    case 'PanelDetail':
      return { key: 'main', boxes: full(paged(`${model.title}\n${model.text}`, model.page)) };
    case 'Ask':
      return { key: 'main', boxes: full(`${ASK_LISTENING}\n\nSay your question.\nDouble-tap to cancel.`) };
    case 'CueDetail':
      return { key: 'main', boxes: full(paged(detailText(model.cue), model.page)) };
    case 'PrepNoteView':
      return { key: 'main', boxes: full(paged(`${model.title}\n${model.text}`, model.page)) };
    case 'ConfirmEnd':
      return {
        key: 'confirm',
        boxes: [{ name: 'confirm', x: 88, y: 84, w: 400, h: 120, border: true, capture: true, content: 'End session?\n\nDouble-tap again to end\nAny other tap cancels' }],
      };
    case 'Live': {
      if (model.paused) return { key: 'live-captions', boxes: full(`${HudGlyphs.PAUSED} Paused\nLong-press for menu`) };
      const captions = model.captionsOn ? model.captionLines.map((l) => fit(l)) : [];
      if (model.cue) {
        return {
          key: 'live-cue',
          boxes: [
            { name: 'cue', x: 0, y: 0, w: CANVAS_WIDTH, h: 130, border: true, content: cueCard(model.cue) },
            { name: 'captions', x: 0, y: 134, w: CANVAS_WIDTH, h: 154, capture: true, content: captions.slice(-CUE_CAPTION_LINES).join('\n') || ' ' },
          ],
        };
      }
      if (model.pendingCount > 0) {
        const head = `${HudGlyphs.CUE} ${model.pendingCount} new cue${model.pendingCount === 1 ? '' : 's'}`;
        return { key: 'live-captions', boxes: full([head, ...captions.slice(-Math.min(captionLimit, FULL_LINES - 1))].join('\n')) };
      }
      return { key: 'live-captions', boxes: full(captions.slice(-Math.min(captionLimit, FULL_LINES)).join('\n') || ' ') };
    }
  }
}

function container(b: Box, textColor?: number): TextContainerProperty {
  return new TextContainerProperty({
    xPosition: b.x,
    yPosition: b.y,
    width: b.w,
    height: b.h,
    borderWidth: b.border ? 1 : 0,
    borderColor: b.border ? 15 : 0,
    borderRadius: b.border ? 6 : 0,
    paddingLength: 4,
    containerID: ID[b.name],
    containerName: b.name,
    isEventCapture: b.capture ? 1 : 0,
    content: b.content,
    ...(textColor === undefined ? {} : { textColor }),
  });
}

export function renderPage(model: ScreenModel, opts: RenderOptions): RenderResult {
  const { key, boxes } = layout(model, opts.idleHint, opts.captionLines);
  const textColor = opts.brightness === undefined ? undefined : Math.max(1, Math.min(4, Math.round(opts.brightness)));
  for (const b of boxes) b.content = fitBytes(b.content, TEXT_CREATE_MAX_BYTES);
  const menuSig = JSON.stringify((opts.menu.menuItems ?? []).map((i) => [i.itemID, i.itemName]));
  const layoutKey = `${key}|b${textColor ?? '-'}|${menuSig}`;
  const contents: Record<string, string> = Object.fromEntries(boxes.map((b) => [b.name, b.content]));
  const page = new RebuildPageContainer({ containerTotalNum: boxes.length, textObject: boxes.map((b) => container(b, textColor)), menuObject: opts.menu });
  const prev = opts.previous;
  if (!prev || prev.layoutKey !== layoutKey) return { kind: 'rebuild', layoutKey, page, upgrades: [], contents };
  const upgrades = boxes
    .filter((b) => prev.contents[b.name] !== b.content)
    .map((b) => new TextContainerUpgrade({ containerID: ID[b.name], containerName: b.name, content: b.content }));
  return { kind: 'upgrade', layoutKey, page, upgrades, contents };
}
