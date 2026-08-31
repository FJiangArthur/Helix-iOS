# Helix Engine and Conversation UI QA

Date: 2026-08-31

Release: `2.2.98+202608312013`

Target branch: `main`

Status: engineering acceptance complete for the available simulator/emulator
system; physical-phone, G1 hardware, and recorded-video proof remain pending

## Acceptance result

| Area | User-visible acceptance | Result |
|---|---|---|
| Speech finalization | Spoken input becomes an ordered final transcript without requiring the user to stop the session | Pass |
| Question pickup | Clear, statement-form, multi-question, Unicode-punctuation, and multilingual questions are detected and deduplicated | Pass |
| Automatic answer | High-confidence questions begin answering automatically; independent questions do not wait behind a slow older answer | Pass |
| Conversation UI | Transcript, detected question, and assistant answer render as attributed timeline/chat items rather than scalar or debug text | Pass |
| Speaker truth | Known speaker metadata is displayed; unknown speakers are not invented | Pass |
| Automatic note | Useful facts, decisions, and action items are captured, deduplicated, visible, reversible, and protected from credential capture | Pass |
| Deep answer | The explicit **Think deeper** action routes through the higher-reasoning answer path | Pass |
| G1 delivery | UI distinguishes phone-only preview, sending, acknowledged, partial-lens, and failed delivery | Pass in protocol and simulator tests; physical G1 pending |
| Session lifecycle | Start, graceful stop, rapid restart, clear/new conversation, save, and relaunch remain usable | Pass |

## What changed

- The question pipeline now uses multilingual LLM classification with a fast
  deterministic path, recognizes `?`, `？`, and `؟`, normalizes Unicode for
  deduplication, and reserves questions before concurrent answer generation.
- Automatic answers stream independently and are restored to conversation order
  for presentation. Automatic high-confidence answers remain the default;
  **Think deeper** is the explicit slower path.
- Both app shells now render a semantic conversation timeline with user and
  Helix authorship, speaker metadata when known, real source/model provenance,
  and truthful phone/G1 delivery state.
- Automatic Knowledge capture is project-scoped, classifies facts, decisions,
  action items, and trustworthy answers, and preserves FAST/SMART provenance.
  It upgrades the same answer identity without duplication and compares the
  complete stored item before reporting a successful Undo.
- Capture rejects detected questions, model clarification questions, and
  credential material expressed with Unicode separators, NFKC variants, or
  compact/camel-case labels such as `APIKey`, `privateKey`, `seedPhrase`,
  `cardNumber`, and `accessToken`. Deterministic/fallback answers remain manual
  save only.
- Known and unknown speaker identity stays explicit. A user can rename a
  speaker or mark themselves without Helix inventing attribution or changing
  another source-provided identity.
- G1 plain-text HUD delivery uses `0x71` screen-status framing in each `0x4E`
  packet, one-based pages, left-before-right writes, acknowledgement gating and
  retry, batch cancellation, and explicit partial/single-lens outcomes. Local
  pagination is never presented as acknowledged hardware delivery.
- Transcription, answer, HUD, and session jobs are generation-owned so a stop or
  rapid restart cannot leak stale work into a new conversation.

## End-to-end product evidence

### Android live audio flow

System: `emulator-5558`

Fixture: `android/app/src/debug/assets/helix_debug_fixture.wav`

Content: “What is the capital of France?”

Format: mono PCM, 24 kHz, about 1.81 seconds

The final APK was installed, launched, pulled back from the emulator, and
hash-compared with the build output. The audible fixture was then injected
through the app's debug microphone path. The resulting transcript, question,
streamed answer, model identity, phone-only delivery truth, and controls were
inspected in the rendered UI.

| Event | Timestamp | Delta |
|---|---:|---:|
| Session start | 20:27:03.293 | — |
| Speech energy observed | 20:27:04.206 | — |
| First transcript delta | 20:27:05.473 | 1.267 s after speech |
| Transcript complete | 20:27:07.380 | 3.174 s after speech |
| Question accepted | 20:27:07.387 | 7 ms after transcript completion |
| First answer token | 20:27:08.813 | 1.426 s after question acceptance |
| Answer complete | 20:27:08.915 | 1.528 s after question acceptance |
| Clean stop | 20:27:30.787 | UI returned to Idle |

The rendered conversation identified the source as **Unknown speaker** rather
than inventing a person, promoted the transcript to one question item, and
displayed the FAST response in a separate Helix card. The card identified the
actual model `gpt-4.1-mini-2025-04-14`, showed **Phone only**, and exposed
**Think deeper**. It did not render an implementation dump or raw state object.

The explicit deeper action was replayed against the same installed APK. SMART
question acceptance occurred at 20:27:45.172, the first token arrived in
0.776 seconds, and completion arrived in 0.826 seconds. The second card
identified `gpt-4.1-2025-04-14`; it did not overwrite the FAST card or create a
second question.

Automatic Knowledge was also replayed on the installed APK with a fresh factual
question. The UI showed **Saved automatically to Helix Knowledge · Facts**,
included the complete question/answer provenance, and exposed **Undo**. The
Undo action was invoked through its accessibility node. A persisted-state
check then showed the control note (`nonce 2027`) present and the undone note
(`nonce 2030`) absent. The SMART answer for the undo target completed in
0.970 seconds with `gpt-4.1-2025-04-14`.

Evidence:

- `/tmp/helix-2.2.98-final-exact-audio-immutable.log`
- `/tmp/helix-2.2.98-final-exact-audio-immutable.xml`
- `/tmp/helix-2.2.98-final-exact-audio-immutable.png`
- `/tmp/helix-2.2.98-final-exact-deeper-immutable.log`
- `/tmp/helix-2.2.98-final-exact-deeper-immutable.xml`
- `/tmp/helix-2.2.98-final-exact-deeper-immutable.png`
- `/tmp/helix-2.2.98-final-exact-note2-immutable.log`
- `/tmp/helix-2.2.98-final-exact-note2-receipt-immutable.xml`
- `/tmp/helix-2.2.98-final-exact-note2-receipt-immutable.png`
- `/tmp/helix-2.2.98-final-exact-note2-after-undo-immutable.png`
- `/tmp/helix-2.2.98-final-note-undo-verification.json`
- `/tmp/helix-2.2.98-installed-immutable-final.apk`

### iOS rendered conversation flow

The 58 app unit tests ran on dedicated simulator
`Helix-QA-Final-27-20260831-2000`
(`509C4F2B-18F0-4559-82A4-A869E625639B`, iPhone 17 Pro, iOS 27.0). The complete
14-case UI suite ran on dedicated simulator `Helix-QA-20260831060238`
(`C6A8766A-0964-404D-8ECB-084374236601`, iPhone 17 Pro, iOS 26.5); the iOS 26.5
runtime was used after the iOS 27 beta runtime developed a CoreSimulator launch
RPC failure between UI cases.

The final simulator build exercised the message-driven conversation timeline,
text-question path, explicit manual Knowledge save, durable relaunch,
new-conversation reset, offline G1 truth, speaker rename and **Mark as Me**,
session persistence, microphone start/stop, and deeper-answer control. The
result bundle retains screenshots of separate user/Helix cards and the
multi-speaker flow.

Evidence:

- `/tmp/helix-2.2.98-ios-unit-immutable-final-2003.xcresult`
- `/tmp/helix-2.2.98-ios-ui-immutable-final-2022.xcresult`

## Automated regression matrix

| Suite | Result | Artifact |
|---|---:|---|
| NativeHelix package | 162 executed; 0 failed; 1 intentional live-key skip | `/tmp/helix-2.2.98-final-gate-immutable-1947.log` |
| Native question pipeline | 32/32 passed | `NativeQuestionPipelineRegressionTests` |
| Native Knowledge safety | 21/21 passed | `KnowledgeRemovalTests` |
| Native G1 commands | 19/19 passed | `G1CommandsTests` |
| iOS app unit tests | 58/58 passed | `/tmp/helix-2.2.98-ios-unit-immutable-final-2003.xcresult` |
| Full iOS UI | 14/14 passed | `/tmp/helix-2.2.98-ios-ui-immutable-final-2022.xcresult` |
| Android unit tests | 698 executed; 0 failures/errors; 1 intentional live-network skip | `/tmp/helix-2.2.98-android-immutable-final-1947.log` |
| Android debug build | Passed | `/tmp/helix-2.2.98-android-immutable-final-1947.log` |
| Required repository gate | All four gates passed | `/tmp/helix-2.2.98-final-gate-immutable-1947.log` |
| Desktop Swift live-provider smoke | Blocked by local credential: HTTP 401 | `scripts/run_commit_gate.sh` |

Fresh Android APK:

- Path: `android/app/build/outputs/apk/debug/app-debug.apk`
- Size: 20,576,519 bytes
- SHA-256: `ff7d3aae237bab6399c855821dc7a66425e8e7bbf1910a266bec1d52173d10f3`
- Installed pull-back: `/tmp/helix-2.2.98-installed-immutable-final.apk`
- Installed pull-back SHA-256: identical to the build output

The repository gate includes the security/boundary checks, the full 162-test
Swift package run, and the retired-evaluation validation.

The additional main-branch hook smoke test was attempted with both the July
`.env` key and the distinct current ambient desktop key; OpenAI rejected both
with HTTP 401, so this check is not reported as passing. This is a local
credential-readiness boundary rather than an inferred provider pass. The exact
installed Android artifact independently completed live OpenAI FAST, SMART,
and automatic-Knowledge answer paths during the end-to-end replay above.
Refresh the ignored `.env` credential before relying on the desktop hook again.

## Pre-fix baseline

With the stored default `gpt-live-transcribe` model, the Android app displayed
the full partial transcript but did not finalize it after 20 seconds. Stopping
the session removed the partial without adding a final timeline entry, detected
question, or answer. The app also showed “No audio detected” even though its
diagnostics had observed speech energy.

The causes were a missing final-boundary grace period, a watchdog that ignored
previously observed speech, and generation ownership that allowed stop/restart
races. With `gpt-4o-mini-transcribe`, server VAD had already shown that the same
fixture could commit in about 2.8 seconds, isolating the client finalization
path rather than basic classification as the blocking baseline defect.

The baseline delivery UI also showed both “Glasses not connected — answer
stayed on phone” and “On glasses · page 1 of 1.” The latter was inferred from
local pagination rather than a device acknowledgement. The corrected UI now
reports only the evidence-backed delivery state.

The baseline iOS UI exposed one mutable transcript, detected-question, and
answer value in a large workspace panel. New results overwrote old values. The
corrected UI preserves a multi-turn, attributed conversation timeline.

## Remaining proof boundary

No physical iPhone, physical Android/Fold, or Even G1 glasses were connected
during final acceptance. Simulator/emulator behavior and protocol-level G1
acknowledgement, retry, page, cancellation, and single-lens tests are green, but
they do not constitute physical radio, microphone, touchpad, display, or
dual-lens proof. A hardware pass should repeat the same audio, stop/restart,
note, deep-answer, and G1 acknowledgement scenarios when those devices are
available.

No Helix video corpus was present in the repository, Desktop, Downloads, or
Movies during the final scoped search. The only discoverable Helix media
fixtures were `android/app/src/debug/assets/helix_debug_fixture.wav` and
`android/app/src/test/resources/q1_24k.wav`. Recorded-video transcription was
therefore not executed and remains a separate acceptance gate when those files
are made available in the workspace.

This report is included in the single aggregate `main` commit; use repository
`HEAD` for the immutable commit identity.
