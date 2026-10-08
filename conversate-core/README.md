# Conversate Core

Language-neutral contract shared by the Helix Android G1 app (`android/`) and the
G2 Even Hub app (`evenhub/`, Plan D). Spec:
`docs/superpowers/specs/2026-10-04-conversate-g1-g2-design.md`.

- `menu.json` — menu items by context. Toggle items render `labelOn`/`labelOff`
  from the named flag; others render `label`.
- `prompts/*.json` — LLM prompt templates. `{{name}}` placeholders.
- `cue-schema.json` — JSON Schema the cue prompt must return.
- `vectors/` — behaviour vectors every implementation must pass.

Android packages this directory as Java resources (`build.gradle.kts`), so files
are read with `ClassLoader.getResource("<path>")`. Changing a file here changes
both apps: run both test suites.

## 0.3 additions
- `CONTRACT-0.3.md` — normative semantics for mode/display pickers, dashboard panels, Ask, and the helix-relay HTTP API.
- `fixtures/relay-*.json` — canonical relay responses; app tests use them for fake relays.
- `vectors/session-pickers.json`, `vectors/session-panels.json` — new behaviour vectors (runner step types `panelRows`, `askText`; expect field `title`).
