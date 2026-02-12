# Next.js Trace Viewer Roadmap

## Phase 1 – Data + Schema Alignment (In Progress)
- Re-read `TRACE_SCHEMA.md` to ensure loaders mirror the RFC 0.1.0 structure.
- Build a reusable trace loader in `web/lib/traces.ts` that:
  - Reads both `traces/*.json` (legacy mission logs) and `.agent-trace/*.json` (RFC-compliant records).
  - Normalizes data into typed structures (commit metadata, contributor ranges, Solana anchor metadata).
  - Handles missing directories, malformed JSON, and empty states gracefully.
- Expose helper selectors (latest trace, counts, anchor coverage) for dashboard widgets.

## Phase 2 – UI Architecture with shadcn/ui
- Install shadcn components via `npx shadcn@latest add <component>`.
- Reference the component index at https://ui.shadcn.com/llms.txt for available primitives.
- Establish foundational layout primitives: `sidebar`, `card`, `tabs`, `drawer`, `area-chart` (via chart-friendly components) to mimic a Grafana-like control plane.

## Phase 3 – Analytics Data Plumbing
- Shape the loader output into analytics-friendly series (traces per hour, anchor success rate, contributor mix).
- Add lightweight data transforms in `lib/traces.ts` for chart-ready datasets.

## Phase 4 – Dashboard UI Build
- Replace the landing page with a Trace Analytics dashboard:
  - Hero metrics (total traces, anchored %, latest commit SHA, time since last commit).
  - Timeline/stacked charts for commit cadence and contributor activity.
  - Filterable trace table + detail drawer showing file ranges, content hashes, and download buttons.
  - Solana status widget (Tx hash, Solscan link, copy-to-clipboard).

## Phase 5 – Solana Anchoring Automation
- For every trace created, call the AgentWallet Solana action to anchor the trace hash, capturing Tx IDs.
- Persist Tx metadata inside the `.agent-trace/<sha>.json` `metadata` block and surface it in the UI.

## Phase 6 – Documentation + Cadence
- Update `README.md` with viewer usage, deployment URL, and anchoring workflow.
- Maintain 15–20 minute commit cadence with matching RFC traces + Solana anchors toward the 100+ trace goal.
