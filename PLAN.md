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

1. RFC 0.1.0 Commit-Bound Trace System
2. Hash chaining inside metadata
3. Proof-of-Work inside metadata
4. Git commit binding (GPG-signed, trace-referenced)
5. Solana anchoring
6. Read-only web viewer

Skipping steps is NOT allowed.


## 4. Logging Rules (Strict)

## Logging Rules — RFC Agent Trace 0.1.0 (Mandatory)

All traces MUST strictly conform to the Agent Trace RFC 0.1.0 specification.

The trace schema defined at:
https://agent-trace.dev/schemas/v1/trace-record.json

is authoritative.

The agent MUST:

1. Generate one Trace Record per commit revision.
2. Bind `vcs.type` = "git".
3. Bind `vcs.revision` = exact 40-character git commit SHA.
4. Attribute file changes using line-level ranges derived from git diff.
5. Use contributor.type = "ai".
6. Use contributor.model_id = the exact runtime model identifier.
7. Store any custom fields ONLY inside `metadata`.
8. Log every meaningful decision and action
9. Generate RFC-compliant trace records for every code-producing commit.

The agent MUST NOT:

- Invent new top-level fields.
- Use non-RFC schemas.
- Store decision traces in a non-compliant format.

Agent MUST NOT generate freeform logs that are not AgentTrace-compliant.
Trace records MUST NOT be generated for commits that only modify files inside `.agent-trace/`.

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

Trace Layer (RFC 0.1.0 compliant)
- Generate trace records after commit
- Use git diff to compute line ranges
- Store traces in .agent-trace/<commit-sha>.json
- No decision-layer custom format
