---
created: 2026-04-08T03:45:43.947Z
title: Left eye HUD broken — shows "Even AI Listening" instead of streamed text
area: ble
files:
  - ios/Runner/BluetoothManager.swift
  - lib/services/evenai.dart
  - lib/services/bitmap_hud/bitmap_hud_service.dart
---

## Problem

During a live session, streaming to the glasses is broken on the left lens:
- **Left eye**: stuck on "Even AI Listening" placeholder
- **Right eye**: correctly displays the actual streamed text

This is a dual-BLE divergence — one lens never receives the content frames, or receives them but doesn't render past the listening state. Observed on hardware 2026-04-07.

Likely culprits:
- L/R routing in `BluetoothManager.swift` dual-connection send path
- EvenAI multi-packet chunking (191 bytes/packet) not fanning out to both connections
- Possible race where left connection is still in "listening" screen state when content frames arrive

## Solution

TBD. Investigation steps:
1. Add per-side send logging in BluetoothManager send path — confirm both L and R receive identical packet sequences
2. Check EvenAI screen state code transitions (0x01 → 0x30 → 0x40) on both sides
3. Verify left connection isn't being filtered out by any "primary side" logic
