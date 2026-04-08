---
created: 2026-04-08T03:45:43.947Z
title: Fix LA buttons disappear on answer (Plan C regression)
area: live-activity
status: active
priority: urgent
blocks: merge-c-la-rework
files:
  - ios/HelixLiveActivity/
---

## Problem

Live Activity buttons disappear when an answer is displayed. Regression introduced by Plan C (LA rework) and discovered during hardware testing on user's phone.

**Must land on the C branch before C merges to main** — otherwise the regression ships.

## Solution

TBD — user described it as a "tiny fix". Investigation:
1. Diff Plan C LA view code against main for the answer-displayed state
2. Check if button views are being conditionally removed when `hasActiveAnswer` flag flips
3. Verify LA layout constraints for the answer state
