# Baseline Validation

Baseline version: **2.2.95+202607012117**

This baseline is the Swift-native Helix app shell plus `NativeHelix` headless
package. Legacy cross-platform tooling, method/event channels, and Flutter/Dart
UI are outside the supported baseline.

## Required Local Setup

Install the repository hooks after cloning or after resetting Git config:

```bash
bash scripts/install_git_hooks.sh
```

The installer marks the hook and gate scripts executable, then sets:

```bash
git config core.hooksPath .githooks
```

## Manual Gate

Run the mandatory gate before completing any code change:

```bash
bash scripts/run_gate.sh
```

The gate checks repository secrets, the headless package boundary, the native
Swift package build/tests, and the retired eval boundary.

## Commit And Push Gate

Commits on `main` run:

```bash
bash scripts/run_commit_gate.sh
```

That script requires local `.env` to contain `OPENAI_API_KEY`, then runs staged
security checks, native package tests, the native Swift gate, the mandatory gate,
and the live OpenAI provider smoke test.

Pushes to `main` run the same extensive gate through `.githooks/pre-push`.

## Simulator Policy

Use only a dedicated `Helix-QA-*` simulator for foreground validation. Do not
reuse `0D7C3AB2` or `6D249AFF`. Delete or shut down dedicated Helix simulators
after validation to avoid memory pressure.
