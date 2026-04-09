# Ring Remote: Dead Buttons & Capture Paths

WS-F reference for developers debugging why a particular Bluetooth HID
"ring remote" button does not appear in the Input Inspector.

Helix captures input on four native iOS paths (see
`ios/Runner/InputInspector.swift`):

1. `UIKeyCommand` — keyboard-style keys (a–z, 0–9, arrows, return, etc.)
2. `pressesBegan` / `UIPress` — the firehose below `UIKeyCommand`; keys
   that UIKit filters out still arrive here.
3. `MPRemoteCommandCenter` — media transport controls (play/pause/next/…)
4. `AVSystemController` volume notifications — volume rocker edges.

If pressing a ring button produces nothing in any of the four pills on
the Inspector screen, that button is almost certainly being consumed by
iOS before the app can see it. The table below summarises what is
known.

## Always consumed by iOS (never reaches the app)

| Button                    | Owner          | Notes                                  |
| ------------------------- | -------------- | -------------------------------------- |
| Home / App Switcher       | SpringBoard    | System gesture                         |
| Power / Side button       | SpringBoard    | Lock, Siri long-press, SOS             |
| Ringer/Mute switch        | iOS            | Not deliverable to userland            |
| Screenshot chord          | iOS            | Cannot be intercepted                  |
| Siri long-press           | Siri           | Consumed before UIResponder            |
| Accessibility triple-click| Accessibility  | Owned by AX shortcut                   |

## Conditionally consumed (delivered only in specific modes)

| Button             | Condition                                                 |
| ------------------ | --------------------------------------------------------- |
| Volume Up / Down   | Only when the app holds an active audio session/focus.    |
| Play / Pause       | Only when `MPNowPlayingInfoCenter.nowPlayingInfo` is set. |
| Next / Previous    | Same as Play/Pause — requires a "now playing" stub.       |
| Seek Fwd / Back    | Same — plus the command must be enabled in the center.    |

The Inspector installs a `nowPlayingInfo` stub while it is visible, so
these buttons should appear during capture. At runtime, the background
`InputDispatcher` only installs the stub if the user has already bound
a `mediaCommand:*` signature, to avoid showing a ghost player in
Control Center.

## Delivered to `pressesBegan` but NOT `UIKeyCommand`

| Key type                   | Reason                                            |
| -------------------------- | ------------------------------------------------- |
| Modifier-only (Shift, …)   | `UIKeyCommand` requires a non-modifier input.     |
| Some Fn / HID usage codes  | No mapping to a printable input character.        |
| Media keys on BT keyboards | Routed to `MPRemoteCommandCenter` instead.        |

If the Inspector shows a row in the **pressEvent** pill but nothing in
**keyCommand**, the ring is sending a raw HID usage code that does not
map to a keyboard input. Bind the `pressEvent:<keyCode>` signature.

## Ring buttons that disappear entirely

Most "smart ring" HID devices in our testing re-use a fixed set of
BLE HID reports:

- Camera shutter rings → Volume Up (`volumeChange:up`)
- Media rings         → Play/Pause (`mediaCommand:togglePlayPause`)
- Presentation rings  → Arrow keys (`keyCommand:UIKeyInputRightArrow:0`)
- Generic HID rings   → Sometimes raw HID codes visible only to `pressesBegan`

### Workaround if nothing shows up

1. Check the vendor's companion app for a "remap button" option.
   Remap the target button to a generic key (e.g. `a` or Play/Pause).
2. Confirm in iOS Settings → Bluetooth that the ring is listed as a
   keyboard or HID device, not merely "Connected".
3. Reopen the Inspector after remapping and try again.
4. If the ring still shows nothing, it is emitting a HID usage code
   that iOS filters out entirely. That button cannot be used; pick a
   different one.

## Signature format reference

The signatures displayed in the Inspector and stored in
`SettingsManager.ringBindingSignature` follow these shapes:

```
keyCommand:<input>:<modifierFlags>
pressEvent:<keyCode>
mediaCommand:<command>          # play | pause | togglePlayPause | nextTrack | previousTrack | seekForward | seekBackward | stop
volumeChange:<direction>        # up | down
```

The debounce strategy applied by `InputDispatcher` is documented in
`.planning/orchestration/reports/WS-F-investigation.md` §5.
