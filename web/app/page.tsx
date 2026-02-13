export const dynamic = "force-dynamic";

import Link from "next/link";
import { loadTraceSummaries, summarizeTraces } from "@/lib/traces";
import { CopyButton } from "@/components/CopyButton";
import { TraceDetail } from "@/components/TraceDetail";

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
  const recentTraces = traces.slice(0, 12); // Show 12 most recent
  const year = new Date().getUTCFullYear();
  const anchorProgress = analytics.total ? Math.round((analytics.anchored / analytics.total) * 100) : 0;
  const latestTrace = traces[0];
  const sourceDistribution = [
    { label: "RFC traces", value: analytics.bySource.agent },
    { label: "Legacy traces", value: analytics.bySource.legacy },
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

        {/* Hero Stats */}
        <section className="grid gap-4 md:grid-cols-3">
          <div className="group rounded-2xl border border-slate-800 bg-slate-900/40 p-6 transition-all hover:border-slate-700 hover:bg-slate-900/60">
            <p className="text-sm text-slate-400">Total Traces</p>
            <p className="mt-2 text-4xl font-semibold">{analytics.total}</p>
            <p className="mt-1 text-xs text-slate-500">
              {analytics.bySource.agent} RFC · {analytics.bySource.legacy} legacy
            </p>
          </div>
          <div className="group rounded-2xl border border-slate-800 bg-slate-900/40 p-6 transition-all hover:border-emerald-700 hover:bg-slate-900/60">
            <p className="text-sm text-slate-400">Solana Anchored</p>
            <p className="mt-2 text-4xl font-semibold text-emerald-400">{analytics.anchored}</p>
            <p className="mt-1 text-xs text-slate-500">
              {analytics.unanchored} pending anchors
            </p>
          </div>
          <div className="group rounded-2xl border border-slate-800 bg-slate-900/40 p-6 transition-all hover:border-sky-700 hover:bg-slate-900/60">
            <p className="text-sm text-slate-400">Latest Activity</p>
            <p className="mt-2 text-4xl font-semibold">
              {analytics.latestTimestamp ? (
                <span className="flex items-center gap-2">
                  <span className="text-sky-400">Live</span>
                  <span className="relative flex h-3 w-3">
                    <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-sky-400 opacity-75"></span>
                    <span className="relative inline-flex rounded-full h-3 w-3 bg-sky-500"></span>
                  </span>
                </span>
              ) : "Idle"}
            </p>
            <p className="mt-1 text-xs text-slate-500">
              {analytics.latestTimestamp
                ? `${formatTimestamp(analytics.latestTimestamp)}`
                : "Awaiting next trace"}
            </p>
          </div>
        </section>

        {/* Current Workstream + Solana Anchor Health */}
        <section className="grid gap-4 lg:grid-cols-3">
          <div className="rounded-2xl border border-slate-800 bg-slate-900/40 p-6 lg:col-span-2">
            <div className="flex items-start justify-between mb-4">
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
                  View anchor ↗
                </Link>
              )}
            </div>
            <div className="grid gap-4 sm:grid-cols-3">
              <div className="min-w-0">
                <p className="text-xs uppercase tracking-[0.3em] text-slate-500">Trace UUID</p>
                <div className="flex items-center gap-2">
                  <p className="text-sm text-slate-200 break-all font-mono">{latestTrace?.id.slice(0, 8) ?? "–"}...</p>
                  {latestTrace?.id && <CopyButton text={latestTrace.id} label="ID" />}
                </div>
              </div>
              <div className="min-w-0">
                <p className="text-xs uppercase tracking-[0.3em] text-slate-500">Commit</p>
                {latestTrace?.commitSha ? (
                  <div className="flex items-center gap-2">
                    <Link
                      href={`${GITHUB_COMMIT_BASE}/master`}
                      className="text-sm text-slate-200 font-mono break-all hover:text-emerald-200"
                      target="_blank"
                      rel="noreferrer"
                    >
                      {latestTrace.commitSha.slice(0, 7)}
                    </Link>
                    <CopyButton text={latestTrace.commitSha} label="SHA" />
                  </div>
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
                ? "Latest RFC trace with Solana anchor metadata. 100% AI-authored, verifiable on-chain."
                : "Waiting for the first trace to arrive."}
            </p>
          </div>
          
          <div className="rounded-2xl border border-slate-800 bg-slate-900/40 p-6">
            <p className="text-sm text-slate-400">Solana Anchor Health</p>
            <p className="mt-2 text-3xl font-semibold">{anchorProgress}%</p>
            <p className="text-xs uppercase tracking-[0.3em] text-slate-500">of traces anchored</p>
            <div className="mt-4 h-2 rounded-full bg-slate-800">
              <div
                className="h-full rounded-full bg-emerald-400 transition-all"
                style={{ width: `${anchorProgress}%` }}
              />
            </div>
            <p className="mt-3 text-xs text-slate-500">
              {analytics.anchored} confirmed · {analytics.unanchored} pending
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
                      className="h-full rounded-full bg-sky-500 transition-all"
                      style={{ width: `${Math.min(100, Math.max(0, (source.value / Math.max(analytics.total, 1)) * 100))}%` }}
                    />
                  </div>
                </div>
              ))}
            </div>
          </div>
        </section>

        {/* Recent Traces (Merged with Activity Log) */}
        <section className="space-y-4">
          <div className="flex items-center justify-between">
            <div>
              <h2 className="text-xl font-semibold">Recent Traces</h2>
              <p className="text-sm text-slate-500">
                Latest artifacts with RFC compliance and Solana anchor verification
              </p>
            </div>
            <p className="text-xs text-slate-500">
              Live stream · {recentTraces.length} shown
            </p>
          </div>

          <div className="overflow-hidden rounded-2xl border border-slate-800 bg-slate-900/40">
            <div className="grid grid-cols-6 border-b border-slate-800 bg-slate-900/80 px-6 py-3 text-xs uppercase tracking-wider text-slate-400 font-semibold">
              <span>Trace ID</span>
              <span>Timestamp</span>
              <span>Commit</span>
              <span>Source</span>
              <span>Files</span>
              <span className="text-right">Anchor</span>
            </div>
            {recentTraces.length === 0 ? (
              <p className="px-4 py-6 text-sm text-slate-500">No trace files detected yet.</p>
            ) : (
              <div>
                {recentTraces.map((trace) => (
                  <TraceDetail key={`${trace.source}-${trace.id}`} trace={trace} />
                ))}
              </div>
            )}
          </div>
        </section>

        {/* Footer */}
        <footer className="space-y-6 border-t border-slate-800 pt-10">
          <div className="flex flex-wrap items-center justify-between gap-4">
            <div className="flex items-center gap-3">
              <span className="relative flex h-2 w-2">
                <span className="animate-ping absolute inline-flex h-full w-full rounded-full bg-emerald-400 opacity-75"></span>
                <span className="relative inline-flex rounded-full h-2 w-2 bg-emerald-500"></span>
              </span>
              <span className="text-sm text-slate-400">Mission Active</span>
            </div>
            <div className="flex flex-wrap gap-6 text-sm text-slate-500">
              <div>
                <span className="text-slate-400">RFC 0.1.0:</span> {analytics.total} traces
              </div>
              <div>
                <span className="text-slate-400">Anchored:</span> {anchorProgress}%
              </div>
              <div>
                <span className="text-slate-400">Platform:</span> Vercel · Next.js 16
              </div>
            </div>
          </div>
          <div className="flex flex-wrap items-center justify-between gap-4 text-xs text-slate-600">
            <p>
              © {year} Agent Audit Log · Colosseum Hackathon · 100% AI-authored
            </p>
            <div className="flex gap-4">
              <Link href="https://github.com/M-DEV-1/agent-audit-log" className="hover:text-slate-400">
                GitHub
              </Link>
              <Link href="https://agent-audit.mdev1.me" className="hover:text-slate-400">
                Dashboard
              </Link>
              <Link href="https://colosseum.org" className="hover:text-slate-400">
                Colosseum
              </Link>
            </div>
          </div>
        </footer>
      </main>
    </div>
  );
}
