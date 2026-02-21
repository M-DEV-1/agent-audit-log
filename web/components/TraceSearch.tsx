'use client';

import { useState, useMemo } from 'react';

interface TraceSearchProps {
  onFilterChange: (query: string) => void;
  totalCount: number;
  filteredCount: number;
}

export function TraceSearch({ onFilterChange, totalCount, filteredCount }: TraceSearchProps) {
  const [query, setQuery] = useState('');

  const handleChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const value = e.target.value;
    setQuery(value);
    onFilterChange(value);
  };

  const handleClear = () => {
    setQuery('');
    onFilterChange('');
  };

  return (
    <div className="flex items-center gap-3">
      <div className="relative flex-1 max-w-sm">
        <svg
          className="absolute left-3 top-1/2 -translate-y-1/2 w-4 h-4 text-slate-500"
          fill="none"
          viewBox="0 0 24 24"
          stroke="currentColor"
        >
          <path
            strokeLinecap="round"
            strokeLinejoin="round"
            strokeWidth={2}
            d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z"
          />
        </svg>
        <input
          type="text"
          value={query}
          onChange={handleChange}
          placeholder="Filter by commit, ID, or source…"
          className="w-full pl-10 pr-8 py-2 text-sm bg-slate-800/60 border border-slate-700 rounded-lg text-slate-200 placeholder-slate-500 focus:outline-none focus:border-sky-500 focus:ring-1 focus:ring-sky-500 transition-colors"
        />
        {query && (
          <button
            onClick={handleClear}
            className="absolute right-2 top-1/2 -translate-y-1/2 text-slate-400 hover:text-slate-200 transition-colors"
          >
            <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        )}
      </div>
      {query && (
        <span className="text-xs text-slate-500">
          {filteredCount} of {totalCount} traces
        </span>
      )}
    </div>
  );
}

/**
 * Hook: filter traces by a search query.
 * Matches against trace ID, commit SHA, source, or label.
 */
export function useTraceFilter<T extends { id: string; commitSha?: string; source: string }>(
  traces: T[]
) {
  const [query, setQuery] = useState('');

  const filtered = useMemo(() => {
    if (!query.trim()) return traces;
    const q = query.toLowerCase();
    return traces.filter(
      (t) =>
        t.id.toLowerCase().includes(q) ||
        (t.commitSha?.toLowerCase().includes(q) ?? false) ||
        t.source.toLowerCase().includes(q)
    );
  }, [traces, query]);

  return { query, setQuery, filtered, totalCount: traces.length };
}
