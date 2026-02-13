'use client';

import { useState } from 'react';
import Link from 'next/link';
import { CopyButton } from './CopyButton';

interface TraceDetailProps {
  trace: {
    id: string;
    timestamp?: string;
    commitSha?: string;
    source: string;
    files?: number;
    solanaTx?: string;
    hash?: string;
  };
}

export function TraceDetail({ trace }: TraceDetailProps) {
  const [expanded, setExpanded] = useState(false);
  
  const formatTimestamp = (ts?: string) => {
    if (!ts) return "—";
    return new Date(ts).toLocaleString("en-GB", {
      hour12: false,
      day: "2-digit",
      month: "short",
      hour: "2-digit",
      minute: "2-digit",
    });
  };

  return (
    <>
      <button
        onClick={() => setExpanded(!expanded)}
        className="grid grid-cols-6 gap-4 px-6 py-4 text-left hover:bg-slate-800/40 transition-all w-full border-b border-slate-800/50"
      >
        <div className="flex items-center gap-2 min-w-0">
          <span className="text-xs font-mono text-emerald-400 truncate">{trace.id.slice(0, 8)}...</span>
        </div>
        <span className="text-xs text-slate-300">{formatTimestamp(trace.timestamp)}</span>
        <span className="text-xs font-mono text-sky-400 truncate">{trace.commitSha?.slice(0, 7) ?? "—"}</span>
        <span className="text-xs text-slate-300 capitalize">{trace.source}</span>
        <span className="text-xs text-slate-300 text-center">{trace.files ?? "—"}</span>
        <div className="flex items-center justify-end gap-2">
          {trace.solanaTx ? (
            <span className="text-xs text-emerald-400 font-semibold">✓</span>
          ) : (
            <span className="text-xs text-slate-500">—</span>
          )}
          <svg
            className={`w-4 h-4 text-slate-400 transition-transform ${expanded ? 'rotate-180' : ''}`}
            fill="none"
            viewBox="0 0 24 24"
            stroke="currentColor"
          >
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
          </svg>
        </div>
      </button>
      
      {expanded && (
        <div className="px-6 py-5 bg-gradient-to-br from-slate-800/40 to-slate-900/40 border-b border-slate-700/50">
          <div className="grid grid-cols-2 gap-6 text-xs">
            <div>
              <p className="text-slate-500 uppercase tracking-wider mb-1">Trace UUID</p>
              <div className="flex items-center gap-2">
                <p className="font-mono text-slate-300 break-all">{trace.id}</p>
                <CopyButton text={trace.id} label="" />
              </div>
            </div>
            <div>
              <p className="text-slate-500 uppercase tracking-wider mb-1">Commit SHA</p>
              {trace.commitSha ? (
                <div className="flex items-center gap-2">
                  <Link
                    href={`https://github.com/M-DEV-1/agent-audit-log/commit/master`}
                    target="_blank"
                    rel="noreferrer"
                    className="font-mono text-slate-300 hover:text-emerald-200"
                  >
                    {trace.commitSha}
                  </Link>
                  <CopyButton text={trace.commitSha} label="" />
                </div>
              ) : (
                <p className="font-mono text-slate-400">—</p>
              )}
            </div>
            <div>
              <p className="text-slate-500 uppercase tracking-wider mb-1">Timestamp</p>
              <p className="text-slate-300">{trace.timestamp ?? "—"}</p>
            </div>
            <div>
              <p className="text-slate-500 uppercase tracking-wider mb-1">Files Changed</p>
              <p className="text-slate-300">{trace.files ?? "—"}</p>
            </div>
            {trace.hash && (
              <div className="col-span-2">
                <p className="text-slate-500 uppercase tracking-wider mb-1">Trace Hash (SHA-256)</p>
                <div className="flex items-center gap-2">
                  <p className="font-mono text-xs text-slate-300 break-all">{trace.hash}</p>
                  <CopyButton text={trace.hash} label="" />
                </div>
              </div>
            )}
            {trace.solanaTx && (
              <div className="col-span-2">
                <p className="text-slate-500 uppercase tracking-wider mb-1">Solana Anchor</p>
                <div className="flex items-center gap-2 flex-wrap">
                  <Link
                    href={`https://solscan.io/tx/${trace.solanaTx}?cluster=devnet`}
                    target="_blank"
                    rel="noreferrer"
                    className="font-mono text-xs text-emerald-300 hover:text-emerald-200 break-all"
                  >
                    {trace.solanaTx}
                  </Link>
                  <CopyButton text={trace.solanaTx} label="" />
                  <Link
                    href={`/verify`}
                    className="ml-auto px-3 py-1 bg-emerald-600 hover:bg-emerald-500 rounded text-xs font-semibold transition-colors"
                  >
                    Verify Proof
                  </Link>
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </>
  );
}
