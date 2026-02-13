export const dynamic = "force-dynamic";

import Link from "next/link";
import { loadTraceSummaries, summarizeTraces } from "@/lib/traces";

const GITHUB_COMMIT_BASE = "https://github.com/M-DEV-1/agent-audit-log/commit";

function formatTimestamp(timestamp?: string) {
  if (!timestamp) return "Unknown";
  try {
    const date = new Date(timestamp);
    return date.toLocaleString("en-GB", {
      hour12: false,
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit",
    });
  } catch {
    return timestamp;
  }
}

export default async function Home() {
  const traces = await loadTraceSummaries();
  const analytics = summarizeTraces(traces);
  const topTraces = traces.slice(0, 8);
  const year = new Date().getUTCFullYear();
  const anchorProgress = analytics.total ? Math.round((analytics.anchored / analytics.total) * 100) : 0;
  const latestTrace = traces[0];
  const activityLog = traces.slice(0, 6);
  const sourceDistribution = [
    { label: "RFC traces", value: analytics.bySource.agent },
    { label: "Legacy traces", value: analytics.bySource.legacy },
  ];

  const nextPhaseStatus = [
    { label: "Next ship", value: "Status Panel (highlights what ships next)" },
    { label: "Mission focus", value: "Phase 3 prep · Meta Mission Board context" },
    { label: "Trace discipline", value: "Build → commit → trace → anchor → push" },
  ];

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100">
      <main className="mx-auto flex w-full max-w-6xl flex-col gap-10 px-6 py-16">
        <header className="space-y-4">
          <p className="text-sm uppercase tracking-[0.3em] text-slate-400">
            Agent Audit Log · Mission Control · Live Trace Dashboard
          </p>
          <div className="flex flex-col gap-2">
            <h1 className="text-3xl font-semibold sm:text-4xl">
              Trace Intelligence Dashboard
            </h1>
            <p className="text-slate-400">
              Autonomous telemetry for the Colosseum mission — commits, traces, and Solana anchors rendered in real time.
            </p>
          </div>
        </header>

        <section className="grid gap-4 md:grid-cols-3">
          <div className="rounded-2xl border border-slate-800 bg-slate-900/40 p-6">
            <p className="text-sm text-slate-400">Total Traces</p>
            <p className="mt-2 text-4xl font-semibold">{analytics.total}</p>
            <p className="mt-1 text-xs text-slate-500">
              {analytics.bySource.agent} RFC · {analytics.bySource.legacy} legacy
            </p>
          </div>
          <div className="rounded-2xl border border-slate-800 bg-slate-900/40 p-6">
            <p className="text-sm text-slate-400">Solana Anchored</p>
            <p className="mt-2 text-4xl font-semibold">{analytics.anchored}</p>
            <p className="mt-1 text-xs text-slate-500">
              {analytics.unanchored} pending anchors
            </p>
          </div>
          <div className="rounded-2xl border border-slate-800 bg-slate-900/40 p-6">
            <p className="text-sm text-slate-400">Latest Activity</p>
            <p className="mt-2 text-4xl font-semibold">
              {analytics.latestTimestamp ? "Live" : "Idle"}
            </p>
            <p className="mt-1 text-xs text-slate-500">
              {analytics.latestTimestamp
                ? `${formatTimestamp(analytics.latestTimestamp)} · ${analytics.latestCommit ?? "–"}`
                : "Awaiting next trace"}
            </p>
          </div>
        </section>

        <section className="grid gap-4 lg:grid-cols-3">
          <div className="rounded-2xl border border-slate-800 bg-slate-900/40 p-6 lg:col-span-2">
            <div className="flex items-start justify-between">
              <div>
                <p className="text-sm text-slate-400">Current Workstream</p>
                <h2 className="text-2xl font-semibold break-words max-w-full">
                  {latestTrace?.label ?? latestTrace?.id ?? "No trace yet"}
                </h2>
              </div>
              {latestTrace?.solanaTx && (
                <Link
                  href={`https://solscan.io/tx/${latestTrace.solanaTx}?cluster=devnet`}
                  className="text-xs text-emerald-300 hover:text-emerald-200"
                  target="_blank"
                  rel="noreferrer"
                >
                  View anchor
                </Link>
              )}
            </div>
            <div className="mt-4 grid gap-4 sm:grid-cols-3">
              <div className="min-w-0">
                <p className="text-xs uppercase tracking-[0.3em] text-slate-500">Trace ID</p>
                <p className="text-sm text-slate-200 break-words">{latestTrace?.id ?? "–"}</p>
              </div>
              <div className="min-w-0">
                <p className="text-xs uppercase tracking-[0.3em] text-slate-500">Commit</p>
                {latestTrace?.commitSha ? (
                  <Link
                    href={`${GITHUB_COMMIT_BASE}/master`}
                    className="text-sm text-slate-200 font-mono break-all hover:text-emerald-200"
                    target="_blank"
                    rel="noreferrer"
                  >
                    {latestTrace.commitSha}
                  </Link>
                ) : (
                  <p className="text-sm text-slate-200 font-mono">—</p>
                )}
              </div>
              <div className="min-w-0">
                <p className="text-xs uppercase tracking-[0.3em] text-slate-500">Timestamp</p>
                <p className="text-sm text-slate-200 break-words">{formatTimestamp(latestTrace?.timestamp)}</p>
              </div>
            </div>
            <p className="mt-4 text-sm text-slate-400">
              {latestTrace
                ? "Live viewer telemetry. This workstream tracks the latest RFC or legacy artifact and its Solana anchor metadata."
                : "Waiting for the first trace to arrive so we can kick off the Phase 2 tracking ribbon."}
            </p>
          </div>
          <div className="rounded-2xl border border-slate-800 bg-slate-900/40 p-6">
            <p className="text-sm text-slate-400">Solana anchor health</p>
            <p className="mt-2 text-3xl font-semibold">{anchorProgress}%</p>
            <p className="text-xs uppercase tracking-[0.3em] text-slate-500">of traces anchored</p>
            <div className="mt-4 h-2 rounded-full bg-slate-800">
              <div
                className="h-full rounded-full bg-emerald-400"
                style={{ width: `${anchorProgress}%` }}
              />
            </div>
            <p className="mt-3 text-xs text-slate-500">
              {analytics.anchored} confirmed anchors · {analytics.unanchored} pending
            </p>
            <div className="mt-4 space-y-2">
              {sourceDistribution.map((source) => (
                <div key={source.label} className="text-xs text-slate-400">
                  <p className="flex items-center justify-between text-xs text-slate-400">
                    <span>{source.label}</span>
                    <span className="font-semibold text-white">{source.value}</span>
                  </p>
                  <div className="mt-1 h-1 rounded-full bg-slate-900">
                    <div
                      className="h-full rounded-full bg-sky-500"
                      style={{ width: `${Math.min(100, Math.max(0, (source.value / Math.max(analytics.total, 1)) * 100))}%` }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        <section className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-xl font-semibold">Recent traces</h2>
              <p className="text-sm text-slate-500">
                Latest eight artifacts across RFC and legacy traces. Filters, charts, and drawers arrive next.
              </p>
            </div>
            <p className="text-xs text-slate-500">
              Data source: `traces/` + `.agent-trace/`
            </p>
          </div>

          <div className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900/40">
            <div className="grid grid-cols-6 border-b border-slate-800 bg-slate-900/70 px-4 py-2 text-xs uppercase tracking-wide text-slate-500">
              <span>ID</span>
              <span>Timestamp</span>
              <span>Commit</span>
              <span>Source</span>
              <span>Files</span>
              <span>Solana</span>
            </div>
            {topTraces.length === 0 ? (
              <p className="px-4 py-6 text-sm text-slate-500">No trace files detected yet.</p>
            ) : (
              <div className="divide-y divide-slate-800">
                {topTraces.map((trace) => (
                  <div
                    key={`${trace.source}-${trace.id}`}
                    className="grid grid-cols-6 px-4 py-3 text-sm text-slate-200"
                  >
                    <span className="truncate font-mono text-xs text-slate-300">
                      {trace.id}
                    </span>
                    <span className="text-xs text-slate-400">
                      {formatTimestamp(trace.timestamp)}
                    </span>
                    <span className="truncate font-mono text-xs text-slate-400">
                      {trace.commitSha ?? "—"}
                    </span>
                    <span className="text-xs capitalize text-slate-400">{trace.source}</span>
                    <span className="text-xs text-slate-300">{trace.files ?? "—"}</span>
                    <span className="text-xs">
                      {trace.solanaTx ? (
                        <Link
                          href={`https://solscan.io/tx/${trace.solanaTx}?cluster=devnet`}
                          className="text-emerald-300 hover:text-emerald-200"
                          target="_blank"
                          rel="noreferrer"
                        >
                          Anchored
                        </Link>
                      ) : (
                        <span className="text-slate-500">Pending</span>
                      )}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </section>

        <section className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <h2 className="text-xl font-semibold">Rolling activity log</h2>
              <p className="text-sm text-slate-500">
                Most recent traces, sorted newest first. Each entry links to the Solana anchor (if available) and the last commit descriptor.
              </p>
            </div>
            <p className="text-xs text-slate-500">Live stream · Refreshed on every build</p>
          </div>

          <div className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900/40">
            <div className="grid grid-cols-4 border-b border-slate-800 bg-slate-900/70 px-4 py-2 text-xs uppercase tracking-wide text-slate-500">
              <span>Trace</span>
              <span>Source</span>
              <span>Commit</span>
              <span>Solana</span>
            </div>
            {activityLog.length === 0 ? (
              <p className="px-4 py-6 text-sm text-slate-500">No activity yet.</p>
            ) : (
              <div className="divide-y divide-slate-800">
                {activityLog.map((trace) => (
                  <div
                    key={trace.path}
                    className="grid grid-cols-4 gap-2 px-4 py-3 text-sm text-slate-200"
                    style={{ gridTemplateColumns: "2fr 1fr 1fr auto" }}
                  >
                    <div className="min-w-0">
                      <p className="text-xs font-semibold text-slate-300 truncate">{trace.label ?? trace.id}</p>
                      <p className="text-xs text-slate-500 truncate">{formatTimestamp(trace.timestamp)}</p>
                    </div>
                    <span className="text-xs capitalize text-slate-400 truncate">{trace.source}</span>
                    <span className="text-xs font-mono text-slate-400 truncate">{trace.commitSha ?? "—"}</span>
                    <span className="text-xs">
                      {trace.solanaTx ? (
                        <Link
                          href={`https://solscan.io/tx/${trace.solanaTx}?cluster=devnet`}
                          className="text-emerald-300 hover:text-emerald-200"
                          target="_blank"
                          rel="noreferrer"
                        >
                          View anchor
                        </Link>
                      ) : (
                        <span className="text-slate-500">Pending</span>
                      )}
                    </span>
                  </div>
                ))}
              </div>
            )}
          </div>
        </section>
        <section className="space-y-4">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <div>
              <h2 className="text-xl font-semibold">Status Panel</h2>
              <p className="text-sm text-slate-500">Highlights what ships next so the roadmap stays transparent.</p>
            </div>
            <p className="text-xs uppercase tracking-[0.3em] text-slate-500">Live</p>
          </div>
          <div className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900/30 p-4">
            <div className="grid gap-3 sm:grid-cols-3">
              {nextPhaseStatus.map((item) => (
                <div key={item.label} className="rounded-xl border border-slate-800 bg-slate-950/60 p-3">
                  <p className="text-[0.65rem] uppercase tracking-[0.3em] text-slate-500">{item.label}</p>
                  <p className="mt-2 text-sm text-slate-100">{item.value}</p>
                </div>
              ))}
            </div>
          </div>
        </section>



                <footer className="mt-4 flex flex-col gap-2 border-t border-slate-900/60 pt-6 text-sm text-slate-500 sm:flex-row sm:items-center sm:justify-between">
          <p>© {year} Agent Audit Log · Colosseum Agent Hackathon</p>
          <div className="flex flex-wrap gap-4 text-slate-300">
            <Link
              href="https://github.com/M-DEV-1"
              className="transition hover:text-white"
              target="_blank"
              rel="noreferrer"
            >
              github.com/M-DEV-1
            </Link>
            <Link
              href="https://colosseum.com/projects/agent-audit-log"
              className="transition hover:text-white"
              target="_blank"
              rel="noreferrer"
            >
              Colosseum project page
            </Link>
          </div>
        </footer>
      </main>
    </div>
  );
}
// TODO: Refine footer link alignment on mobile resolutions
