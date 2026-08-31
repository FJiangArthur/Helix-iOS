# Test Bug Report

Open issues discovered during native Swift testing. This file is the stable
long-lived list.

| ID | Sev | Component | File:Line | Summary |
|---|---|---|---|---|
| BUG-006 | Info | Audio | `ios/Runner/RNNoiseProcessor.h` | RNNoiseProcessor is header-only; noise reduction toggle has no effect. |

## Fixed

| ID | Sev | Component | File:Line | Summary |
|---|---|---|---|---|
| BUG-007 | Med | Transcription | `ios/Runner/OpenAIRealtimeTranscriber.swift:753` | Partial transcript emission captured `self.currentTranscriptBuffer` in an async block; a `completed` event could reset the buffer first, emitting empty partials. Fixed by capturing the value before dispatch. |
| BUG-008 | Low | Audio | `ios/Runner/AudioResampler.swift:55` | One-shot resample signaled `.noDataNow`, so AVAudioConverter withheld primed frames and returned short output. Fixed with `.endOfStream` flush. |
