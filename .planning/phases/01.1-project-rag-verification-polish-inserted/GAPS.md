# Phase 1.1 Walkthrough — Gaps and Findings

This is a **living document** appended during the Plan 02 simulator walkthrough. Each finding is either a **blocker** (blocks-feature-use, must be fixed in this phase before the phase is considered clean) or a **polish** item (UX paper-cut — captured here for a later phase, does not block Phase 1.1 exit).

Findings that map back to the pre-walkthrough gate result belong in the *Out-of-scope / pre-existing* section instead of *Findings* — they are pre-existing state, not walkthrough discoveries.

**Gate baseline:** see `GATE_BASELINE.md` in this directory.
**Walkthrough commit:** _{filled in by Plan 02 at start — `git rev-parse --short HEAD` before the walkthrough begins}_

## Findings

_Append entries below as issues are discovered. Number them F-01, F-02, ... in discovery order. Use the template in the next section for each entry._

### Template for each entry

Copy-paste the block below and fill in each field. Omit a field entirely if "N/A" — do not leave it blank with placeholder text.

```
#### F-NN — {one-line summary}

- **Severity:** blocker | polish
- **Walkthrough step:** {SC number + step description, e.g. "SC-2 step 4: Ask probe question"}
- **Anchor:** {file:line OR "runtime/UI only"}
- **Repro:** numbered steps a second engineer could follow cold
  1. ...
  2. ...
  3. ...
- **Observed:** {what actually happened — exact text, screen, error if any}
- **Expected:** {what the plan or CONTEXT said should happen}
- **Recommended next action:** fix in this phase | fold into Phase 2 | backlog as todo
- **Evidence:** evidence/{screenshot.png} (or evidence/{clip.mov}, etc.)
```

## Out-of-scope / pre-existing (auto-triaged)

Items matching anything in `GATE_BASELINE.md` are pre-existing and go here, not in Findings. Plan 02 auto-triages these and does not halt on them.

- (none yet — Plan 02 will populate from GATE_BASELINE.md as they surface)

## Summary (filled at walkthrough end)

- **Blockers:** _{N}_
- **Polish items:** _{N}_
- **Pre-existing:** _{N}_
- **Phase verdict:** _{CLEAN | GAPS — triggers `/gsd:plan-phase 1.1 --gaps`}_
