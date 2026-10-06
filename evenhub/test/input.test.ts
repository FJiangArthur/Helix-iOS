import { EventSourceType, evenHubEventFromJson, OsEventTypeList } from '@evenrealities/even_hub_sdk';
import { describe, expect, it } from 'vitest';
import { loadMenu } from '../src/core/menu';
import { DEFAULT_PREFS } from '../src/core/screen';
import { ConversateSession } from '../src/core/session';
import { buildContextMenu, contextMenuItemId } from '../src/g2/contextMenu';
import { InputAdapter, mapEvenHubEvent } from '../src/g2/input';

const menu = loadMenu();
buildContextMenu(menu, true, {});

const sys = (eventType: OsEventTypeList | undefined, eventSource?: EventSourceType) =>
  evenHubEventFromJson({ type: 'sysEvent', jsonData: { ...(eventType === undefined ? {} : { eventType }), ...(eventSource === undefined ? {} : { eventSource }) } });
const text = (eventType?: OsEventTypeList) =>
  evenHubEventFromJson({ type: 'textEvent', jsonData: { containerID: 3, containerName: 'main', ...(eventType === undefined ? {} : { eventType }) } });

describe('mapEvenHubEvent', () => {
  const gestures: Array<[OsEventTypeList, string]> = [
    [OsEventTypeList.CLICK_EVENT, 'SELECT'],
    [OsEventTypeList.DOUBLE_CLICK_EVENT, 'BACK'],
    [OsEventTypeList.SCROLL_BOTTOM_EVENT, 'NEXT'],
    [OsEventTypeList.SCROLL_TOP_EVENT, 'PREV'],
    [OsEventTypeList.LONG_PRESS_EVENT, 'MENU'],
  ];

  for (const [type, intent] of gestures) {
    it(`${OsEventTypeList[type]} maps to ${intent} from glasses and ring alike`, () => {
      expect(mapEvenHubEvent(sys(type, EventSourceType.TOUCH_EVENT_FROM_GLASSES_R))).toEqual({ type: 'intent', intent, source: 'G2_TOUCHPAD' });
      expect(mapEvenHubEvent(sys(type, EventSourceType.TOUCH_EVENT_FROM_GLASSES_L))).toEqual({ type: 'intent', intent, source: 'G2_TOUCHPAD' });
      expect(mapEvenHubEvent(sys(type, EventSourceType.TOUCH_EVENT_FROM_RING))).toEqual({ type: 'intent', intent, source: 'R1' });
      expect(mapEvenHubEvent(text(type))).toEqual({ type: 'intent', intent, source: 'G2_TOUCHPAD' });
    });
  }

  it('an omitted eventType (protobuf default 0) is a CLICK', () => {
    expect(mapEvenHubEvent(text())).toEqual({ type: 'intent', intent: 'SELECT', source: 'G2_TOUCHPAD' });
    expect(mapEvenHubEvent(sys(undefined, EventSourceType.TOUCH_EVENT_FROM_RING))).toEqual({ type: 'intent', intent: 'SELECT', source: 'R1' });
  });

  it('long-press release, IMU and audio are not intents', () => {
    expect(mapEvenHubEvent(sys(OsEventTypeList.LONG_PRESS_RELEASE_EVENT))).toBeNull();
    expect(mapEvenHubEvent(evenHubEventFromJson({ type: 'sysEvent', jsonData: { eventType: 8, imuData: { x: 1, y: 2, z: 3 } } }))).toBeNull();
    expect(mapEvenHubEvent(evenHubEventFromJson({ type: 'audioEvent', jsonData: { audioPcm: [0, 0] } }))).toBeNull();
  });

  it('foreground and exit events become lifecycle actions', () => {
    expect(mapEvenHubEvent(sys(OsEventTypeList.FOREGROUND_ENTER_EVENT))).toEqual({ type: 'lifecycle', phase: 'foreground' });
    expect(mapEvenHubEvent(sys(OsEventTypeList.FOREGROUND_EXIT_EVENT))).toEqual({ type: 'lifecycle', phase: 'background' });
    expect(mapEvenHubEvent(sys(OsEventTypeList.SYSTEM_EXIT_EVENT))).toEqual({ type: 'lifecycle', phase: 'exit' });
    expect(mapEvenHubEvent(sys(OsEventTypeList.ABNORMAL_EXIT_EVENT))).toEqual({ type: 'lifecycle', phase: 'exit' });
  });

  it('context menu clicks map to menu.json ids', () => {
    const ev = (itemID: number) => evenHubEventFromJson({ type: 'menuItemClickEvent', jsonData: { itemID } });
    expect(mapEvenHubEvent(ev(contextMenuItemId('pause')!))).toEqual({ type: 'menuItem', menuId: 'pause' });
    expect(mapEvenHubEvent(ev(contextMenuItemId('start')!))).toEqual({ type: 'menuItem', menuId: 'start' });
    expect(mapEvenHubEvent(ev(4242))).toBeNull();
  });
});

describe('InputAdapter', () => {
  it('collapses one gesture delivered as both a text and a sys event', () => {
    let now = 0;
    const a = new InputAdapter(() => now);
    expect(a.map(text(OsEventTypeList.SCROLL_BOTTOM_EVENT))).not.toBeNull();
    now = 20;
    expect(a.map(sys(OsEventTypeList.SCROLL_BOTTOM_EVENT, EventSourceType.TOUCH_EVENT_FROM_GLASSES_R))).toBeNull();
    now = 400;
    expect(a.map(sys(OsEventTypeList.SCROLL_BOTTOM_EVENT, EventSourceType.TOUCH_EVENT_FROM_GLASSES_R))).not.toBeNull();
    now = 420;
    expect(a.map(sys(OsEventTypeList.SCROLL_BOTTOM_EVENT, EventSourceType.TOUCH_EVENT_FROM_GLASSES_R))).not.toBeNull();
  });
});

describe('ConversateSession.activateMenuItem', () => {
  let now = 0;
  const session = () => new ConversateSession(loadMenu(), () => now, DEFAULT_PREFS);

  it('starts a session from the idle menu id', () => {
    const s = session();
    expect(s.activateMenuItem('start')).toEqual([{ type: 'Start', prepNoteId: null }]);
    expect(s.isLive).toBe(true);
  });

  it('opens the prep note picker when notes exist', () => {
    const s = session();
    s.setPrepNotes([{ id: 'n1', title: 'Acme', text: 'ctx' }]);
    expect(s.activateMenuItem('start')).toEqual([]);
    expect(s.screen()).toEqual({ kind: 'Menu', title: 'PREP NOTE', items: ['Skip & start', 'Acme'], cursor: 0 });
  });

  it('toggles live items without leaving a menu open', () => {
    const s = session(); s.startLive(null);
    expect(s.activateMenuItem('pause')).toEqual([{ type: 'SetPaused', paused: true }]);
    expect(s.screen().kind).toBe('Live');
    expect(s.activateMenuItem('captions')).toEqual([{ type: 'SetCaptions', on: false }]);
    expect(s.activateMenuItem('prep_note')).toEqual([]);
    expect(s.screen().kind).toBe('PrepNoteView');
    expect(s.activateMenuItem('end')).toEqual([{ type: 'End' }]);
    expect(s.isLive).toBe(false);
  });

  it('closes an open in-app menu and ignores ids not in the current context', () => {
    const s = session(); s.startLive(null);
    s.onIntent('MENU');
    expect(s.activateMenuItem('cues')).toEqual([{ type: 'SetCues', on: false }]);
    expect(s.screen().kind).toBe('Live');
    expect(s.activateMenuItem('start')).toEqual([]);
    expect(s.activateMenuItem('nope')).toEqual([]);
  });
});
