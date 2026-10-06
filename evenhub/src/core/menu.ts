// Shared menu contract (conversate-core/menu.json). Port of Android MenuSpec.kt.
import menuJson from '@core-contract/menu.json';

export interface MenuItemSpec {
  id: string;
  label?: string;
  labelOn?: string;
  labelOff?: string;
  toggle?: string;
}

export interface MenuSpec {
  version: number;
  idle: MenuItemSpec[];
  live: MenuItemSpec[];
}

export function renderLabel(item: MenuItemSpec, flags: Record<string, boolean>): string {
  if (item.toggle == null) return item.label ?? item.id;
  return flags[item.toggle] === true ? item.labelOn ?? item.id : item.labelOff ?? item.id;
}

export function loadMenu(): MenuSpec {
  return menuJson as MenuSpec;
}
