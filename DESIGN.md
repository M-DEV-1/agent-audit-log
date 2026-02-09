# DESIGN — Verifiable Autonomous Agent System

This document provides **technical guidance and guardrails** for building
a verifiable autonomous agent system under the Colosseum Agent Hackathon.

This document explains **how** to approach the implementation safely and
incrementally. It does **not** prescribe exact implementation steps.

If there is any conflict:
PLAN.md takes precedence over this document.

---

## 1. Design Intent

This system exists to demonstrate:

- autonomous planning
- autonomous execution
- verifiable provenance of work
- cryptographic traceability
- minimal but real Solana integration

It is **not** intended to be a production product. It is to be built for demonstrability. The agent may choose to work on a demo-service to include more traces, as time passes by.

Clarity, auditability, and correctness are prioritized over performance,
feature count, or UX polish.

---

## 2. Mental Model (Layered Architecture)

The system should be reasoned about in **layers**, built bottom-up:

1. **Decision Layer**
   - planning
   - intent formation
   - reasoning steps

2. **Action Layer**
   - file writes
   - tool invocations
   - commits

3. **Trace Layer (AgentTrace)**
   - structured trace nodes
   - parent–child relationships
   - deterministic schemas

4. **Proof Layer**
   - hashing
   - lightweight proof-of-work

5. **Anchor Layer**
   - Solana anchoring
   - immutable timestamps

6. **Presentation Layer**
   - read-only log viewer UI
   - human observability via a Deployed Website

Each layer must be understandable in isolation.

---

## 3. AgentTrace (Mandatory)

All planning and execution MUST be recorded using the
**AgentTrace specification**:

https://agent-trace.dev/

AgentTrace provides a **formal execution trace**, not a free-form log.

---

## 4. Trace Types and Flow

The agent should emit trace nodes using the following conceptual flow:

```

PLAN → ACTION → TOOL → RESULT → COMMIT

````

Not all steps are required for every operation, but **ordering must be
preserved**.

### Required Trace Types

Each trace MUST include a `type` field from:

- `PLAN`
- `ACTION`
- `TOOL`
- `RESULT`
- `COMMIT`
- `ERROR`

---

## 5. AgentTrace Schema (Required Fields)

Each trace entry MUST include at minimum:

```jsonc
{
  "trace_id": "uuid-v4",
  "type": "PLAN | ACTION | TOOL | RESULT | COMMIT | ERROR",
  "timestamp": "ISO-8601",
  "model_name": "string",
  "instruction": "string",
  "input": {},
  "output": {},
  "parent_trace_id": "uuid-v4 | null",
  "context": {},
  "meta": {}
}
````

### Guidance

* `trace_id` must be unique
* `parent_trace_id` forms a DAG / chain
* `context` should be minimal and stable
* `meta` may include non-critical metadata

Do NOT introduce undocumented fields.

---

## 6. Trace Storage

Recommended structure:

```
/traces/
├─ 2026-02-10T12-00-00.json
├─ 2026-02-10T12-01-32.json
└─ ...
```

Acceptable formats:

* one JSON object per file
* newline-delimited JSON

Rules:

* traces are append-only
* traces are never edited or deleted
* ordering is determined by timestamps + parent relationships

---

## 7. Hashing & Chain Integrity

All Traces should be verifiable on-chain. 

Each trace SHOULD include:

* a content hash
* the hash of its parent trace

This creates a **tamper-evident chain**.

Guidance:

* use a standard cryptographic hash
* use the most novel solution which matches the feasibility of the project
* simplicity > cleverness

---

## 8. Proof-of-Work (PoW)

### Purpose

PoW exists to demonstrate:

* irreversible effort
* temporal cost
* commitment to decisions

It is **not** intended for security.

### Guidance

* difficulty should be configurable
* PoW should complete in milliseconds to seconds
* each PoW must log:

  * input hash
  * nonce
  * difficulty
  * resulting hash

Avoid:

* parallel mining
* adaptive difficulty
* performance tuning

---

## 9. Git Commit Binding

Commits must be **trace-bound**.

Each commit SHOULD:

* reference one or more trace IDs
* correspond to logged actions
* be small and incremental

### Recommended Commit Message Pattern

```
feat(logging): implement trace writer
trace-id: <uuid>
parent-trace-id: <uuid | null>
```

Rules:

* commits must never be amended
* commits must never be squashed
* history must remain append-only

---

## 10. Solana Anchoring

### Purpose

Solana provides:

* public immutability
* timestamped verification
* third-party auditability

### Guidance

* anchor selected trace hashes, not all data
* devnet is acceptable unless otherwise required
* log transaction signatures in AgentTrace

Avoid:

* managing raw private keys in code
* silent RPC retries
* unlogged failures

---

## 11. Web Viewer (Next.js)

### Scope

The web interface is **read-only**.

It exists solely to allow humans to observe:

* traces
* hashes
* PoW results
* Solana anchors

### Requirements

* no authentication
* no mutation
* no real-time guarantees
* clarity over aesthetics

Static rendering or server rendering is sufficient.

---

## 12. Failure Modes to Actively Avoid

* Overengineering
* Feature creep
* Silent retries
* “Cleanup” commits
* Cosmetic refactors
* Human intervention

When uncertain:
**log → act → commit → move on**

---

## 13. Completion Criteria

The system can be considered complete when:

* multiple autonomous commits exist
* all commits are trace-bound
* traces are hash-chained
* PoW is demonstrated
* at least one trace hash is anchored on Solana
* logs are viewable via the web interface

Anything beyond this is optional.

---

## Final Note

This system will be judged as an **artifact of agent behavior**.

Transparency, discipline, and restraint are stronger signals
than sophistication.

