'use client';

import Link from 'next/link';

const GITHUB_COMMIT_BASE = "https://github.com/M-DEV-1/agent-audit-log/commit";

interface RecentCommit {
  sha: string;
  shortSha: string;
  message: string;
  timestamp: string;
  hasTrace: boolean;
}

interface RecentCommitsListProps {
  commits: RecentCommit[];
}

function timeAgo(timestamp: string): string {
  const now = Date.now();
  const then = new Date(timestamp).getTime();
  const diffMs = now - then;
  const diffMins = Math.floor(diffMs / 60000);
  if (diffMins < 1) return "just now";
  if (diffMins < 60) return `${diffMins}m ago`;
  const diffHours = Math.floor(diffMins / 60);
  if (diffHours < 24) return `${diffHours}h ago`;
  const diffDays = Math.floor(diffHours / 24);
  return `${diffDays}d ago`;
}

export function RecentCommitsList({ commits }: RecentCommitsListProps) {
  if (commits.length === 0) {
    return (
      <div className="rounded-2xl border border-slate-800 bg-slate-900/40 p-6">
        <p className="text-sm text-slate-500">No recent commits found.</p>
      </div>
    );
  }

  return (
    <div className="rounded-2xl border border-slate-800 bg-slate-900/40 overflow-hidden">
      <div className="px-6 py-4 border-b border-slate-800 bg-slate-900/80">
        <h3 className="text-sm font-semibold text-slate-300 uppercase tracking-wider">
          Recent Commits
        </h3>
      </div>
      <ul className="divide-y divide-slate-800/50">
        {commits.map((commit) => (
          <li
            key={commit.sha}
            className="px-6 py-3 flex items-center gap-4 hover:bg-slate-800/30 transition-colors"
          >
            <span className={`flex-shrink-0 w-2 h-2 rounded-full ${
              commit.hasTrace ? 'bg-emerald-400' : 'bg-slate-600'
            }`} />
            <Link
              href={`${GITHUB_COMMIT_BASE}/${commit.sha}`}
              target="_blank"
              rel="noreferrer"
              className="font-mono text-xs text-sky-400 hover:text-sky-300 flex-shrink-0"
            >
              {commit.shortSha}
            </Link>
            <span className="text-sm text-slate-300 truncate flex-1">
              {commit.message}
            </span>
            <span className="text-xs text-slate-500 flex-shrink-0">
              {timeAgo(commit.timestamp)}
            </span>
          </li>
        ))}
      </ul>
    </div>
  );
}
