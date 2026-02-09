# PLAN — Autonomous Agent Execution Rules

This document defines **binding rules** for the autonomous agent.
These rules exist to ensure safety, auditability, and hackathon compliance.

If any instruction conflicts with this file, THIS FILE TAKES PRECEDENCE.

---

## 1. Authority & Autonomy

After this file and AGENT_MISSION.md are committed:

- Humans WILL NOT write or modify code
- Humans WILL NOT amend commits
- Humans WILL NOT edit logs or data
- Humans WILL NOT guide implementation choices

All development decisions are the agent’s responsibility.

---

## 2. Hard Constraints (Do NOT violate)

The agent MUST:

1. Operate autonomously after mission start
2. Log every meaningful decision and action
3. Use append-only logs (no deletion, no mutation)
4. Use append-only git history (no force-push, no rebase)
5. Keep the system auditable by third parties

The agent MUST NOT:

- Rewrite history
- Hide errors
- Manually “clean up” logs
- Introduce human-in-the-loop logic
- Store secrets in the repository
- Optimize for aesthetics over correctness

Violating these invalidates the project.

---

## 3. Required Components (In Order)

The agent MUST build the system in the following order:

1. **Decision Logging System**
2. **Hash chaining of logs**
3. **Proof-of-Work over decisions**
4. **Git commit binding**
5. **Solana anchoring**
6. **Read-only web viewer**

Skipping steps is NOT allowed.

---

## 4. Logging Rules (Strict)
## Logging Rules — AgentTrace Compliance (Mandatory)

All logs must comply with the AgentTrace specification (https://agent-trace.dev/).
AgentTrace describes a structured trace format linking:

- Plans
- Decisions
- Tool calls
- Outputs

Each log entry MUST include:

1. `trace_id` — unique identifier for the trace
2. `type` — one of the allowed AgentTrace types (e.g., PLAN, ACTION, TOOL, RESULT)
3. `timestamp`
4. `model_name`
5. `prompt` or `instruction`
6. `input` — inputs to the action
7. `output` — outputs from the agent or tool
8. `parent_trace_id` — linking chain
9. `context` — environment context ideally minimal
10. `meta` — additional metadata (optional)

A valid example (AgentTrace JSON):

```jsonc
{
  "trace_id": "uuid-v4",
  "type": "PLAN",
  "timestamp": "2026-02-10T12:34:56Z",
  "model_name": "gpt-4o",
  "instruction": "Implement decision logging",
  "input": {},
  "output": {
    "schema": "AgentTrace",
    "fields": ["timestamp","plan","details"]
  },
  "parent_trace_id": null,
  "context": {},
  "meta": {}
}
```

All subsequent actions must reference the parent trace via parent_trace_id to form a trace graph.

Agent MUST NOT generate freeform logs that are not AgentTrace-compliant.

Compliance means:

Conformance to the specification

Trace chains that can be verified

Well-formed JSON trace documents

Refer to: https://agent-trace.dev/ for any doubts and details.

## 5. Error Handling Rules

Errors MUST:

- Be logged explicitly
- Include context
- Never be silently retried without logging

Failing loudly is preferred to hiding failures.

---

## 6. Scope Control

The agent MUST bias toward:

- minimal implementations
- incremental progress
- clarity over cleverness

If a feature is not required to demonstrate autonomy or verifiability,
it SHOULD NOT be built.

---

## 7. Evaluation Standard

Assume this repository will be audited by:
- hackathon judges
- other agents
- skeptical humans

Design accordingly.

---

## 8. Final Rule

If unsure:
- log the uncertainty
- choose the simplest safe option
- proceed incrementally
