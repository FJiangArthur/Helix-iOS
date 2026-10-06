// Maps conversate-core/menu.json onto the G2 native contextual menu
// (`menuObject`, spec §4.3). Item ids are stable: live items are 1..n in
// menu.json order, idle items 101..; system-owned ids are hidden because the
// glasses OS adds its own Display off / Brightness / Close entries.
import { MenuContainerProperty, MenuItemProperty, utf8ByteLength } from '@evenrealities/even_hub_sdk';
import { type MenuSpec, renderLabel } from '../core/menu';

const IDLE_BASE = 100;
export const MENU_NAME_MAX_BYTES = 32;
export const MENU_MAX_ITEMS = 10;
/** Shown by the glasses OS itself on G2. */
export const SYSTEM_OWNED_IDS: ReadonlySet<string> = new Set(['display_off']);

let spec: MenuSpec | null = null;

function table(menu: MenuSpec): Map<string, number> {
  const ids = new Map<string, number>();
  menu.live.forEach((item, i) => ids.set(item.id, i + 1));
  menu.idle.forEach((item, i) => ids.set(item.id, IDLE_BASE + i + 1));
  return ids;
}

/** Truncate to [maxBytes] UTF-8 bytes without splitting a code point. */
export function fitBytes(text: string, maxBytes: number): string {
  if (utf8ByteLength(text) <= maxBytes) return text;
  let out = '';
  for (const ch of text) {
    if (utf8ByteLength(out + ch + '~') > maxBytes) break;
    out += ch;
  }
  return out + '~';
}

export function buildContextMenu(menu: MenuSpec, live: boolean, flags: Record<string, boolean>): MenuContainerProperty {
  spec = menu;
  const ids = table(menu);
  const items = (live ? menu.live : menu.idle)
    .filter((item) => !SYSTEM_OWNED_IDS.has(item.id))
    .slice(0, MENU_MAX_ITEMS)
    .map((item) => new MenuItemProperty({ itemID: ids.get(item.id)!, itemName: fitBytes(renderLabel(item, flags), MENU_NAME_MAX_BYTES) }));
  return new MenuContainerProperty({ menuItems: items });
}

export function contextMenuItemId(menuId: string, menu: MenuSpec | null = spec): number | null {
  if (!menu) return null;
  return table(menu).get(menuId) ?? null;
}

export function menuIdForItem(itemID: number, menu: MenuSpec | null = spec): string | null {
  if (!menu) return null;
  for (const [id, n] of table(menu)) if (n === itemID) return id;
  return null;
}
