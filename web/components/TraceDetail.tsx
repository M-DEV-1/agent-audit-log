'use client';

import { useState } from 'react';
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

  return (
    <div className="border-t border-slate-800">
      <button
        onClick={() => setExpanded(!expanded)}
        className="w-full px-4 py-3 text-left text-sm text-slate-200 transition-colors hover:bg-slate-800/50 flex items-center justify-between"
      >
        <div className="flex items-center gap-3">
          <span className="truncate font-mono text-xs text-slate-300">{trace.id}</span>
          <span className="text-xs capitalize text-slate-400">{trace.source}</span>
        </div>
        <svg
          className={`w-4 h-4 text-slate-400 transition-transform ${expanded ? 'rotate-180' : ''}`}
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M19 9l-7 7-7-7" />
        </svg>
      </button>
      {expanded && (
        <div className="px-4 pb-4 space-y-3 bg-slate-800/30">
          <div className="grid grid-cols-2 gap-4 text-xs">
            <div>
              <p className="text-slate-500 uppercase tracking-wider mb-1">Trace UUID</p>
              <div className="flex items-center gap-2">
                <p className="font-mono text-slate-300 break-all">{trace.id}</p>
                <CopyButton text={trace.id} label="" />
              </div>
            </div>
            <div>
              <p className="text-slate-500 uppercase tracking-wider mb-1">Commit SHA</p>
              <div className="flex items-center gap-2">
                <p className="font-mono text-slate-300">{trace.commitSha ?? "—"}</p>
                {trace.commitSha && <CopyButton text={trace.commitSha} label="" />}
              </div>
            </div>
            <div>
              <p className="text-slate-500 uppercase tracking-wider mb-1">Source Type</p>
              <p className="text-slate-300 capitalize">{trace.source}</p>
            </div>
            <div>
              <p className="text-slate-500 uppercase tracking-wider mb-1">Files Changed</p>
              <p className="text-slate-300">{trace.files ?? "—"}</p>
            </div>
            {trace.hash && (
              <div className="col-span-2">
                <p className="text-slate-500 uppercase tracking-wider mb-1">Trace Hash</p>
                <div className="flex items-center gap-2">
                  <p className="font-mono text-xs text-slate-300 break-all">{trace.hash}</p>
                  <CopyButton text={trace.hash} label="" />
                </div>
              </div>
            )}
            {trace.solanaTx && (
              <div className="col-span-2">
                <p className="text-slate-500 uppercase tracking-wider mb-1">Solana Transaction</p>
                <div className="flex items-center gap-2">
                  <a
                    href={`https://solscan.io/tx/${trace.solanaTx}?cluster=devnet`}
                    target="_blank"
                    rel="noreferrer"
                    className="font-mono text-xs text-emerald-300 hover:text-emerald-200 break-all"
                  >
                    {trace.solanaTx}
                  </a>
                  <CopyButton text={trace.solanaTx} label="" />
                </div>
              </div>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
