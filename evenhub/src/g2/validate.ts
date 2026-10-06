// Page validation: the SDK's own validator (z-order, menu, brightness) plus the
// firmware limits the SDK does not check (plan "Global Constraints" and the
// evenhub-simulator changelog: text ≤999 bytes, list items ≤63 bytes × 20).
import { type EvenHubPageContainerLike, utf8ByteLength, validateEvenHubPageContainer } from '@evenrealities/even_hub_sdk';

export const CANVAS_WIDTH = 576;
export const CANVAS_HEIGHT = 288;
export const TEXT_CREATE_MAX_BYTES = 999;
export const TEXT_UPGRADE_MAX_CHARS = 2000;
export const LIST_MAX_ITEMS = 20;
export const LIST_ITEM_MAX_BYTES = 63;

export type PageValidation = { valid: true } | { valid: false; message: string };

interface Box {
  xPosition?: number;
  yPosition?: number;
  width?: number;
  height?: number;
  isEventCapture?: number;
  containerName?: string;
}

const fail = (message: string): PageValidation => ({ valid: false, message });

export function validatePage(page: EvenHubPageContainerLike & { containerTotalNum?: number }): PageValidation {
  const sdk = validateEvenHubPageContainer(page);
  if (!sdk.valid) return fail(`sdk: ${sdk.code} ${sdk.message}`);
  const texts = (page.textObject ?? []) as Array<Box & { content?: string }>;
  const lists = (page.listObject ?? []) as Array<Box & { itemContainer?: { itemName?: string[]; itemCount?: number } }>;
  const images = (page.imageObject ?? []) as Box[];
  if (texts.length + lists.length > 8) return fail('more than 8 text/list containers');
  if (images.length > 4) return fail('more than 4 image containers');
  const total = texts.length + lists.length + images.length;
  if (total < 1 || total > 12) return fail(`container count ${total} outside 1..12`);
  if (page.containerTotalNum !== total) return fail(`containerTotalNum ${page.containerTotalNum} != ${total}`);
  const capture = [...texts, ...lists].filter((c) => c.isEventCapture === 1).length;
  if (capture !== 1) return fail(`expected exactly one event-capture container, got ${capture}`);
  for (const c of [...texts, ...lists, ...images]) {
    const x = c.xPosition ?? 0, y = c.yPosition ?? 0, w = c.width ?? 0, h = c.height ?? 0;
    if (x < 0 || y < 0 || w <= 0 || h <= 0 || x + w > CANVAS_WIDTH || y + h > CANVAS_HEIGHT) {
      return fail(`container ${c.containerName} outside the ${CANVAS_WIDTH}x${CANVAS_HEIGHT} canvas`);
    }
  }
  for (const t of texts) {
    if (utf8ByteLength(t.content ?? '') > TEXT_CREATE_MAX_BYTES) return fail(`text ${t.containerName} over ${TEXT_CREATE_MAX_BYTES} bytes`);
  }
  for (const l of lists) {
    const names = l.itemContainer?.itemName ?? [];
    if (names.length > LIST_MAX_ITEMS) return fail(`list ${l.containerName} over ${LIST_MAX_ITEMS} items`);
    if (names.some((n) => utf8ByteLength(n) > LIST_ITEM_MAX_BYTES)) return fail(`list ${l.containerName} item over ${LIST_ITEM_MAX_BYTES} bytes`);
  }
  return { valid: true };
}
