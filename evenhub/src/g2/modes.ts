// G2 operating modes (contract 0.3 §3, G2 mapping). The contract's mode ids
// are PHONE_MIC / OMI / DISPLAY_ONLY; G2 has its own glasses microphone and no
// Omi pendant path, so its glasses picker offers Glasses mic / Phone mic /
// Display only. GLASSES_MIC is G2-only (reserved on G1 for spec 0.2.0 Plan F).
import type { MenuSpec } from '../core/menu';

export type G2Mode = 'GLASSES_MIC' | 'PHONE_MIC' | 'DISPLAY_ONLY';

export const G2_MODES: ReadonlyArray<{ id: G2Mode; label: string }> = [
  { id: 'GLASSES_MIC', label: 'Glasses mic' },
  { id: 'PHONE_MIC', label: 'Phone mic' },
  { id: 'DISPLAY_ONLY', label: 'Display only' },
];

export const DEFAULT_G2_MODE: G2Mode = 'GLASSES_MIC';
export const OMI_UNAVAILABLE = 'Omi not available on G2';

export function isG2Mode(v: unknown): v is G2Mode {
  return G2_MODES.some((m) => m.id === v);
}

/** menu.json with the mode picker replaced by the G2 modes; menus, panels and display picker unchanged. */
export function g2MenuSpec(base: MenuSpec): MenuSpec {
  return {
    ...base,
    pickers: { ...base.pickers, mode: { title: base.pickers.mode.title, items: G2_MODES.map((m) => ({ ...m })) } },
  };
}
