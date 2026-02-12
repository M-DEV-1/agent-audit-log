# Commit Sprint Roadmap

We started this repository with 15 commits on the `master` branch. To hit the 100 commit target without pushing meaningless history, each sprint milestone below is designed to produce **auditable, traceable** work. Every item expands into at least one code change + trace pair.

| Milestone | Commit Targets | Notes |
| --- | --- | --- |
| Workspace hygiene | 5 commits | Git plumbing, `.gitignore`, scripts, lint + format automation so future commits stay clean.
| Trace infrastructure upgrades | 10 commits | RFC 0.1.0 compliancy, logger improvements, hash-chain utilities, trace validation tests.
| Viewer feature wave 1 | 15 commits | Layout polish, responsive states, accessibility passes, data loading guards, dark/light themes.
| Viewer feature wave 2 | 15 commits | Filtering, search, comparisons, commit → trace deep links, anchor badges, Grafana-inspired widgets.
| Vercel + runtime hardening | 8 commits | Deployment scaffolding, CLI automation, health checks, preflight diagnostics, smoke tests.
| Solana + PoW enhancements | 10 commits | Anchor batching, PoW difficulty tuning, wallet diagnostics, CLI examples, docs.
| Submission tooling | 7 commits | API helpers, status reporters, README badges, forum updates, audit scripts.
| Bugfix & QA sweeps | 10 commits | Fast-follow fixes captured from manual QA and reviewer feedback.
| Stretch research | 10 commits | Experimental metadata visualizations, notebook prototypes, exploratory branches that still ship code.

Each milestone intentionally leaves buffer commits so we can react to unexpected findings (e.g., deployment failures) without derailing the trace chain. The cumulative target (5 + 10 + 15 + 15 + 8 + 10 + 7 + 10 + 10) puts us at **90 additional commits**, bringing the total to ~105 once complete.

Operational rules:

1. **One trace per code commit.** Trace IDs live in the commit message footer and in `traces/*.json`.
2. **Keep commits reviewable.** Aim for <200 LOC per commit so judges can diff quickly.
3. **Document the wave.** Larger features (viewer waves, Solana enhancements) get their own mini-roadmap PRD in `docs/` to guide the next burst.
4. **Tag deployments.** Every Vercel deploy, forum update, or Solana anchor also gets a trace-only commit so the public narrative stays linear.
