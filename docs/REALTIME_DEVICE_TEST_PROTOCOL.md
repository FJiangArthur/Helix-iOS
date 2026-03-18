# Realtime Device Test Protocol

## Goal

Validate the `openaiRealtime` phone-mic path with a stored OpenAI API key using a repeatable manual protocol that captures realtime behavior, performance, and answer usefulness.

## Preconditions

- Physical iPhone
- Stable network connection
- OpenAI API key already stored in app settings
- `transcriptionBackend = openaiRealtime`
- `preferredMicSource = phone`
- Mic and speech permissions granted
- Test modes: General and Interview

## Evidence to Capture

- Screen recording for every scenario
- Console logs from the realtime session
- Screenshot of the configured Settings screen
- Screenshot of the live Assistant view
- Screenshot of the saved History entry

## Scenario Script

### General mode

1. Ask one factual question.
   - Example: "What are the tradeoffs between local speech recognition and cloud speech recognition?"
2. Ask one follow-up question that depends on prior context.
   - Example: "Which option fits a beta release better, and why?"
3. Ask one short actionable request.
   - Example: "Give me a three-step rollout plan."

### Interview mode

1. Ask one behavioral question.
   - Example: "Tell me about a time you handled a production incident."
2. Ask one follow-up probe.
   - Example: "What would you do differently next time?"
3. Ask one STAR-style request.
   - Example: "Help me answer that in STAR format."

## Pass Criteria

### Functional

- Partial transcript appears while speaking
- Final transcript appears after speech ends
- AI response starts without a second manual ask
- One user turn yields one coherent assistant answer
- Session returns to listening after the answer finishes
- Saved history contains the streamed response

### Performance

- First partial transcript in `<= 1.0s`
- Final transcript in `<= 1.5s`
- First AI response delta in `<= 2.5s`
- No crash or hung UI during a 10-minute session
- No visible reconnect loop or repeated response duplication

### Usefulness

Score each scenario from 1 to 5:

| Category | Target |
| --- | --- |
| Transcript accuracy | >= 4 |
| Response relevance | >= 4 |
| Response correctness | >= 4 |
| Actionability | >= 4 |
| Brevity for HUD use | >= 4 |
| Continuity across follow-ups | >= 4 |

## Scorecard Template

| Scenario | Partial latency | Final latency | First AI delta | Accuracy | Relevance | Correctness | Actionability | Brevity | Continuity | Notes |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| General factual |  |  |  |  |  |  |  |  |  |  |
| General follow-up |  |  |  |  |  |  |  |  |  |  |
| General actionable |  |  |  |  |  |  |  |  |  |  |
| Interview behavioral |  |  |  |  |  |  |  |  |  |  |
| Interview follow-up |  |  |  |  |  |  |  |  |  |  |
| Interview STAR |  |  |  |  |  |  |  |  |  |  |

## Failure Logging

For every failure, capture:

- observed behavior
- expected behavior
- scenario name
- whether the failure is functional, performance, or usefulness related
- console log excerpt
- whether retrying the scenario changes the outcome
