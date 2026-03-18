# Helix Roadmap Runbook

## Purpose

Describe how the agent should operate while generating and validating the roadmap package so the run remains inspectable and repeatable.

## Operating Procedure

1. Review repo-truth sources before drafting.
   - Read current entry points, settings, core services, native speech files, active plans, TODOs, and CI config.
   - Prefer current code and recent specs over older narrative docs when they conflict.

2. Capture planning constraints before writing the roadmap.
   - Confirm current product surfaces.
   - Confirm architecture constraints.
   - Confirm verification constraints and tooling gaps.

3. Draft support docs first.
   - `spec.md` records target, inputs, and hard constraints.
   - `plans.md` records milestones and acceptance criteria.
   - `documentation.md` records the live audit trail.

4. Draft the roadmap source.
   - Keep the structure scannable.
   - Include milestone framing, a week-by-week table, dependencies, and risks.
   - Keep all claims traceable to repo evidence.

5. Generate the `.docx`.
   - Use a local conversion path that works in the current environment.
   - Keep intermediates under `tmp/docs/`.
   - Write the final artifact under `output/doc/`.

6. Verify continuously.
   - Re-check the generated document by converting it back to text.
   - Generate a local preview if the environment supports it.
   - Attempt tests, lint, typecheck, and build commands. If blocked by sandboxing or environment constraints, log the blocker clearly.

7. Update the audit log after each meaningful step.
   - Include command intent, result, and any repo finding that changes the roadmap.

## Decision Rules

- Favor current code over stale documentation.
- Favor incremental roadmap items over rewrite plans.
- Treat audio session stability, native iOS paths, and hardware validation as first-order release risks.
- Call out missing CI and integration coverage explicitly instead of assuming they exist.

## Delivery Checklist

- `spec.md` complete
- `plans.md` complete
- `implement.md` complete
- `documentation.md` updated through final verification
- `helix_6_week_roadmap.md` complete
- `helix_6_week_roadmap.docx` generated
- Verification results logged
