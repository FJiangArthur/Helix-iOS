// Even Hub events -> Conversate intents (spec §4.1, G2 column). Glasses
// temples and the R1 ring send the same OsEventTypeList gestures; the ring is
// told apart by Sys_ItemEvent.eventSource.
import { type EvenHubEvent, EventSourceType, OsEventTypeList } from '@evenrealities/even_hub_sdk';
import type { ConversateIntent, IntentSource } from '../core/intents';
import { menuIdForItem } from './contextMenu';

export type InputAction =
  | { type: 'intent'; intent: ConversateIntent; source: IntentSource }
  | { type: 'menuItem'; menuId: string }
  | { type: 'lifecycle'; phase: 'foreground' | 'background' | 'exit' };

const GESTURES: Partial<Record<OsEventTypeList, ConversateIntent>> = {
  [OsEventTypeList.CLICK_EVENT]: 'SELECT',
  [OsEventTypeList.DOUBLE_CLICK_EVENT]: 'BACK',
  [OsEventTypeList.SCROLL_BOTTOM_EVENT]: 'NEXT',
  [OsEventTypeList.SCROLL_TOP_EVENT]: 'PREV',
  [OsEventTypeList.LONG_PRESS_EVENT]: 'MENU',
};

function gesture(eventType: OsEventTypeList | undefined, source: IntentSource): InputAction | null {
  // Protobuf omits default values, so CLICK_EVENT (0) often arrives as undefined.
  const intent = GESTURES[eventType ?? OsEventTypeList.CLICK_EVENT];
  return intent ? { type: 'intent', intent, source } : null;
}

/** Stateless mapping of one Even Hub event. */
export function mapEvenHubEvent(event: EvenHubEvent): InputAction | null {
  if (event.menuItemClickEvent) {
    const id = event.menuItemClickEvent.itemID;
    const menuId = id === undefined ? null : menuIdForItem(id);
    return menuId ? { type: 'menuItem', menuId } : null;
  }
  const sys = event.sysEvent;
  if (sys) {
    switch (sys.eventType) {
      case OsEventTypeList.FOREGROUND_ENTER_EVENT: return { type: 'lifecycle', phase: 'foreground' };
      case OsEventTypeList.FOREGROUND_EXIT_EVENT: return { type: 'lifecycle', phase: 'background' };
      case OsEventTypeList.ABNORMAL_EXIT_EVENT:
      case OsEventTypeList.SYSTEM_EXIT_EVENT: return { type: 'lifecycle', phase: 'exit' };
      case OsEventTypeList.IMU_DATA_REPORT: return null;
      default:
        if (sys.imuData) return null;
        return gesture(sys.eventType, sys.eventSource === EventSourceType.TOUCH_EVENT_FROM_RING ? 'R1' : 'G2_TOUCHPAD');
    }
  }
  const item = event.textEvent ?? event.listEvent;
  if (item) {
    switch (item.eventType) {
      case OsEventTypeList.FOREGROUND_ENTER_EVENT: return { type: 'lifecycle', phase: 'foreground' };
      case OsEventTypeList.FOREGROUND_EXIT_EVENT: return { type: 'lifecycle', phase: 'background' };
      default: return gesture(item.eventType, 'G2_TOUCHPAD');
    }
  }
  return null;
}

/**
 * Stateful wrapper: the host may report one gesture both as a container
 * event and as a source-aware sysEvent. The same intent from the same source
 * on a different event channel within [windowMillis] is that echo and is
 * dropped. (Cross-source duplicates are IntentDeduper's job.)
 */
export class InputAdapter {
  private last: { intent: ConversateIntent; source: IntentSource; channel: string; at: number } | null = null;

  constructor(private readonly clock: () => number, private readonly windowMillis = 100) {}

  map(event: EvenHubEvent): InputAction | null {
    const action = mapEvenHubEvent(event);
    if (action?.type !== 'intent') return action;
    const channel = event.sysEvent ? 'sys' : event.textEvent ? 'text' : 'list';
    const now = this.clock();
    const l = this.last;
    if (l && l.intent === action.intent && l.source === action.source && l.channel !== channel && now - l.at < this.windowMillis) {
      return null;
    }
    this.last = { intent: action.intent, source: action.source, channel, at: now };
    return action;
  }
}
