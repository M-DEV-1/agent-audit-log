export const dynamic = "force-dynamic";

import Link from "next/link";
import { loadTraceSummaries, summarizeTraces } from "@/lib/traces";

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

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100">
      <main className="mx-auto flex w-full max-w-6xl flex-col gap-10 px-6 py-16">
        <header className="space-y-4">
          <p className="text-sm uppercase tracking-[0.3em] text-slate-400">
            Agent Audit Log · Mission Control
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
