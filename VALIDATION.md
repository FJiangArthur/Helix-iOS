# Helix-iOS Validation Gate

This repo validates the Swift-native app and the `NativeHelix` headless
package. The old cross-platform analyzer, test, coverage, and simulator-build
gates are retired.

## Mandatory Gate

```bash
bash scripts/run_gate.sh
```

Exit code 0 means the gate passed. Do not merge or ship if any gate fails.

The gate runs:

- `bash scripts/security_gate.sh --repo`
- a headless package boundary check: no SwiftUI app code under
  `NativeHelix/Sources`
- `swift build --package-path NativeHelix --target HelixRuntime`
- `swift test --package-path NativeHelix`
- a guard that fails if `HELIX_RUN_CONVERSATION_EVAL=1` tries to re-enable
  the retired conversation harness

## iOS 27 Simulator Validation

For app-target validation after code changes:

```bash
xcodebuild -workspace "ios/Even Companion.xcworkspace" -scheme Runner \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO build
```

For foreground proof, install and launch the built app on a dedicated
`Helix-QA-*` simulator. Do not reuse `0D7C3AB2` or `6D249AFF`.

## Native Package Tests

Fast package-only check:

```bash
bash scripts/run_native_swift_gate.sh
```

Focused test examples:

```bash
swift test --package-path NativeHelix --filter NativeConversationTests/testQuestionDetectionAndDuplicateSuppression
swift test --package-path NativeHelix --filter NativeConversationTests/testAudioFilePipelineEmitsTranscriptQuestionStreamingAnswerAndHudEvents
swift test --package-path NativeHelix --filter NativeConversationTests/testG1HudPresenterPaginatesAndPacketizesAnswerText
```

Live OpenAI smoke testing is opt-in:

```bash
HELIX_RUN_LIVE_OPENAI_EVAL=1 \
  swift test --package-path NativeHelix \
  --filter NativeConversationTests/testLiveOpenAIAnswerProviderWithEnvironmentKeyWhenRequested
```

The live test skips by default and fails if explicitly enabled without a key.
Store the key in local `.env` as `OPENAI_API_KEY=...`; `.env` is ignored and
must not be committed.

## Main Commit Gate

Local hooks are stored in `.githooks` and this checkout uses:

```bash
bash scripts/install_git_hooks.sh
```

On branches other than `main`, the pre-commit hook runs the staged security
gate. On `main`, `scripts/run_commit_gate.sh` blocks the commit unless all of
these pass:

- `bash scripts/security_gate.sh --staged`
- `swift test --package-path NativeHelix --filter NativeConversationTests`
- `bash scripts/run_native_swift_gate.sh`
- `bash scripts/run_gate.sh`
- the live OpenAI smoke test with `OPENAI_API_KEY` loaded from `.env`

The pre-push hook runs the same extensive gate for pushes to `main`.

## Release Validation

Release lanes archive the native Xcode workspace:

```bash
cd ios
bundle exec fastlane ios ship
```

Versioning is sourced from the top-level `VERSION` file and mirrored into the
Xcode project build settings.
