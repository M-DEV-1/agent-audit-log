# DESIGN — RFC 0.1.0 Compliant Verifiable Autonomous Agent

This document defines the technical architecture for building a verifiable autonomous agent system under the Colosseum Agent Hackathon.

If any conflict exists:
PLAN.md takes precedence.
Refer to TRACE_SCHEMA.md for the TRACE SCHEMA.

Trace records are NOT generated for commits that only modify files inside `.agent-trace/`.
---

## 1. Design Intent

This system exists to demonstrate:

* Autonomous code generation
* Cryptographically verifiable authorship
* RFC-compliant AI attribution (Agent Trace 0.1.0)
* Public auditability
* Minimal but real Solana anchoring

This is not a production system.
Clarity and auditability are prioritized over features or polish.

---

## 2. Architecture Overview

The system is composed of five layers:

1. Code Generation Layer
   The agent writes and modifies repository files.

2. Commit Layer
   All changes are committed using GPG-signed commits.

3. Trace Layer (RFC 0.1.0 Only)
   One Agent Trace Record per commit revision.

4. Cryptographic Extension Layer
   Hash chaining, Proof-of-Work, and Solana anchoring stored inside `metadata`.

5. Presentation Layer
   Read-only web viewer rendering trace records.

Each layer must be independently understandable and verifiable.

---

## 3. Agent Trace Layer (Mandatory RFC Compliance)

All traces MUST strictly conform to:

[https://agent-trace.dev/schemas/v1/trace-record.json](https://agent-trace.dev/schemas/v1/trace-record.json)

No custom top-level fields are permitted.

---

### 3.1 Trace Generation Order (Strict)

For each commit:

1. Agent generates code.
2. Changes are staged.
3. Commit is created and GPG-signed.
4. Commit SHA is retrieved.
5. Git diff for that commit is parsed.
6. A single RFC-compliant Trace Record is generated referencing:

   * `vcs.type = "git"`
   * `vcs.revision = <exact 40-character commit SHA>`
7. The trace file is committed in a separate append-only commit.

Trace generation MUST occur after commit creation.

---

### 3.2 Storage Format

Trace records MUST be stored as:

```
.agent-trace/<commit-sha>.json
```

Each file maps 1:1 to one git revision.

Traces are append-only and must never be modified.

---

### 3.3 Contributor Rules

Each trace MUST:

* Use `contributor.type = "ai"`
* Use `contributor.model_id` exactly matching the runtime model identifier
* Attribute line-level ranges derived from `git diff`

Line numbers must reflect positions at the recorded revision.

---

### 3.4 File Attribution

For each modified file:

* Compute added/modified line ranges using `git diff`.
* Record ranges under `files[].conversations[].ranges[]`.
* Use content hashes for each range when feasible.

No free-form reasoning logs are allowed outside RFC format.

---

## 4. Cryptographic Extensions (Inside metadata Only)

Custom verification logic MUST be stored inside:

```
metadata
```

Allowed extensions:

### 4.1 Hash Chaining

```
metadata.chain = {
  "parent_trace_hash": "<sha256>",
  "self_hash": "<sha256>"
}
```

### 4.2 Proof-of-Work

```
metadata.pow = {
  "nonce": <int>,
  "difficulty": <int>,
  "result_hash": "<sha256>"
}
```

PoW must complete within seconds.
It demonstrates computational commitment, not security.

### 4.3 Solana Anchoring

```
metadata.solana_anchor = {
  "network": "devnet | mainnet",
  "tx_signature": "<signature>",
  "anchored_hash": "<sha256>"
}
```

Only selected traces need anchoring.

Private keys must never be stored in the repository.

---

## 5. Git Commit Binding

All commits must:

* Be GPG-signed
* Use append-only history
* Never be amended or rebased
* Reference the trace ID in the commit message

Example:

```
feat: implement diff-based trace generator

trace-id: <uuid>
revision: <commit-sha>
```

Commit authorship and cryptographic signature prove agent execution.

---

## 6. Error Handling

Errors MUST:

* Be trace-recorded as separate RFC trace files
* Include contextual metadata
* Never be silently retried

Failure transparency is required.

---

## 7. Solana Anchoring Model

The agent may anchor:

* Trace self-hash
* Or Merkle root of multiple traces

Devnet is acceptable.

Anchoring must:

* Log transaction signature
* Be publicly verifiable
* Be reproducible by a third party

---

## 8. Web Viewer

The web interface must:

* Be read-only
* Display trace records from `.agent-trace/`
* Show:

  * Files modified
  * Line ranges
  * Model ID
  * Commit SHA
  * Hash chain
  * PoW data
  * Solana anchor (if present)

No authentication.
No mutation.
Clarity over aesthetics.

---

## 9. Explicit Non-Goals

The system does NOT:

* Track legal ownership
* Track training data provenance
* Evaluate code quality
* Log internal reasoning outside RFC schema

---

## 10. Completion Criteria

The system is complete when:

* Multiple autonomous commits exist
* Each commit has a corresponding RFC-compliant trace
* Traces are hash-chained
* At least one trace is anchored on Solana
* Web viewer displays all trace records
* All commits are GPG-signed

Anything beyond this is optional.

---

## Final Principle

This system will be judged as an artifact of autonomous behavior.

Strict RFC compliance, cryptographic discipline, and restraint are stronger signals than complexity.

Trace content MUST be generated deterministically from:

- commit SHA
- git diff output
- runtime model identifier

The same commit must always produce the same trace record (excluding timestamp).

---
