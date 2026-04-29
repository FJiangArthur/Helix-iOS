# Bundled fonts

Variable fonts shipped with Helix. Selected at render time via `TextStyle.fontWeight`
(no explicit weight entries needed in `pubspec.yaml`).

| Family | File | License | Source |
|--------|------|---------|--------|
| Fraunces | `Fraunces-VariableFont.ttf` | SIL OFL 1.1 (`OFL-Fraunces.txt`) | https://github.com/undercasetype/Fraunces |
| Inter | `Inter-VariableFont.ttf` | SIL OFL 1.1 (`OFL-Inter.txt`) | https://github.com/rsms/inter |
| JetBrains Mono | `JetBrainsMono-VariableFont.ttf` | SIL OFL 1.1 (`OFL-JetBrainsMono.txt`) | https://github.com/JetBrains/JetBrainsMono |

Pubspec `family:` keys: `Fraunces`, `Inter`, `JetBrainsMono` (no spaces in family name —
Dart consumers reference these strings exactly).
