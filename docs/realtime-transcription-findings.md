# Realtime Transcription Findings

## Summary

This work covered the native iOS audio path, OpenAI Realtime session wiring, Flutter settings, and the Home screen presentation for live transcript and realtime assistant responses.

## Findings

1. `AVAudioInputNode.installTap` crashed when a hard-coded `16 kHz / Int16 / mono` format was used directly on the input node.
2. OpenAI Realtime transcription mode and realtime conversation mode require different session setup and payload handling.
3. Partial transcription deltas were being rendered incorrectly because the client replaced the visible partial with the last token instead of accumulating by `item_id`.
4. Stopping a session could surface a false user-facing error when an empty audio buffer was committed.
5. Realtime assistant responses were only published to the assistant stream on final completion, so partial output appeared in the wrong UI area.
6. The Home screen used too much spacing, kept live transcript text inside the status tile, and had an extra helper tile that reduced usable width.

## Fixes Implemented

### Native iOS

- Updated microphone tap installation to use the hardware input format and convert audio before sending to OpenAI.
- Added cleanup for converter and tap state.
- Improved OpenAI websocket diagnostics and keepalive behavior.
- Corrected transcription session setup so the model and related parameters are passed in the expected mode-specific shape.
- Accumulated transcript deltas by `item_id` so streaming text grows correctly.
- Avoided surfacing the known shutdown-only `buffer too small` commit error to the user.

### Flutter Integration

- Added an OpenAI session mode setting with `transcription` and `realtime`.
- Added a configurable realtime prompt override.
- Migrated legacy realtime backend settings to the new mode-based shape.
- Passed session mode and prompt from Flutter to the iOS bridge.
- Prevented duplicate downstream AI generation when OpenAI realtime responses are already active.

### UI

- Realtime assistant text now streams through the chatbot response path instead of waiting for the final chunk.
- Removed the explanatory copy from the active transcription tile.
- Moved live transcript rendering out of the tile into a message-style card below it.
- Removed the extra helper tile and reduced layout padding/margins to use more horizontal space.

## Validation

- Xcode project builds completed successfully after the native changes.
- Targeted Flutter tests passed for conversation engine and listening session behavior.
- `flutter analyze` passed for the updated Home screen file.

## Remaining Notes

- The realtime prompt override is currently a direct instruction string, not an OpenAI hosted prompt ID/version/variables configuration.
- OpenAI Realtime API contracts can evolve; if server-side validation changes, the native session payload may need another adjustment.
