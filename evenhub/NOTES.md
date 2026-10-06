# Even Hub app — implementation notes and rulings

Format: **Ruling: what — why — cost if wrong.**

## Toolchain

- **Ruling: pin TypeScript 5.9, Vite 6, Vitest 3, evenhub-cli 0.1.14, SDK 0.0.16 exactly — the plan names TS 5 / Vite 6 and npm's latest are TS 7 / Vite 8 / Vitest 5 — cost if wrong: none functional; bump later.**
- **Ruling: `@evenrealities/evenhub-simulator` is not a dependency (run it with `npx`) — it is a native GUI app with a large binary and is only needed for manual preview — cost if wrong: one extra `npx` download.**

## Rendering (src/g2)

- **Ruling: page validation = SDK `validateEvenHubPageContainer` + our own `validatePage` checks — the SDK validator only checks z-order, menu and brightness; event-capture count, canvas bounds, text bytes and list sizes are firmware rules it does not check — cost if wrong: none (stricter).**
- **Ruling: text containers are capped at 999 UTF-8 bytes at create/rebuild (not 1000 chars), list items at 63 bytes — the evenhub-simulator changelog says it mirrors firmware with "text container bytes limit to 999" and "list item text size maximum 63 bytes and 20 items" — cost if wrong: a few characters of headroom lost.**
- **Ruling: menus (in-app Conversate menu, Prep Note picker) are a text container with a `>` cursor, not a native list container — a native list owns its own selection on the glasses and only reports it on click (`List_ItemEvent.currentSelectItemIndex`), so the session's cursor (which the shared vectors test) would desync from what is drawn; text + `textContainerUpgrade` keeps the session authoritative and makes cursor moves flicker-free — cost if wrong: the menu looks less native; switching to a list is local to `render.ts`.**
- **Ruling: cue detail and Prep Note view are paginated by us (8 lines + `[p/n]` footer), not native text scrolling — the session owns `page` and NEXT/PREV are our scroll events — cost if wrong: if the firmware also scrolls an overflowing container we never overflow it, so no conflict.**
- **Ruling: line width estimated at 44 characters, 9 full-screen lines — the G2 font is proportional and the SDK documents no metrics; the firmware wraps text itself, so this only decides how many caption lines we keep — cost if wrong: captions use slightly less of the screen than possible, or the oldest caption line is clipped; tune `LINE_CHARS` after a simulator/hardware look.**
- **Ruling: layout changes (captions-only ↔ cue card ↔ menu/detail ↔ confirm) and any change of the context-menu labels are rebuilds; everything else is `textContainerUpgrade` — borders cannot be changed by an upgrade, and `menuObject` is only sent on create/rebuild, so a toggled label (Pause→Resume) must rebuild — cost if wrong: an extra flicker on toggles.**
- **Ruling: native context menu ids are stable: live items 1..n in `menu.json` order, idle items 101..; `display_off` is hidden on G2 — spec §4.3 says the system adds Display off/Brightness/Close itself — cost if wrong: if the OS does not add Display off, the wearer loses it on G2 (still reachable via the in-app menu, which keeps it).**
