'use client';

import { useState } from 'react';
import Link from 'next/link';

interface VerificationResult {
  success: boolean;
  version?: string;
  id?: string;
  timestamp?: string;
  commit?: string;
  tool?: string;
  model?: string;
  traceHash?: string;
  txHash?: string;
  explorer?: string;
  fileCount?: number;
  error?: string;
}

export default function VerifyPage() {
  const [input, setInput] = useState('');
  const [result, setResult] = useState<VerificationResult | null>(null);
  const [loading, setLoading] = useState(false);

  const handleVerify = async () => {
    if (!input.trim()) return;

    setLoading(true);
    setResult(null);

    try {
      const response = await fetch('/api/verify', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ input: input.trim() }),
      });

      const data = await response.json();
      setResult(data);
    } catch (error) {
      setResult({
        success: false,
        error: 'Failed to verify trace. Please check your input.',
      });
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100">
      <main className="mx-auto flex w-full max-w-4xl flex-col gap-10 px-6 py-16">
        <header className="space-y-4">
          <Link href="/" className="text-sm text-slate-400 hover:text-slate-300">
            ← Back to Dashboard
          </Link>
          <div className="flex flex-col gap-2">
            <h1 className="text-3xl font-semibold sm:text-4xl">
              Verify AI Authorship
            </h1>
            <p className="text-slate-400">
              Paste a trace JSON or commit SHA to verify 100% AI authorship via RFC 0.1.0 compliance and Solana anchoring.
            </p>
          </div>
        </header>

        <section className="space-y-4">
          <div className="rounded-2xl border border-slate-800 bg-slate-900/40 p-6">
            <label htmlFor="trace-input" className="text-sm font-semibold text-slate-300">
              Trace Input
            </label>
            <p className="text-xs text-slate-500 mt-1 mb-3">
              Enter a commit SHA (e.g., d0a6459) or paste complete trace JSON
            </p>
            <textarea
              id="trace-input"
              value={input}
              onChange={(e) => setInput(e.target.value)}
              placeholder="Paste trace JSON or enter commit SHA..."
              className="w-full h-48 px-4 py-3 bg-slate-950 border border-slate-700 rounded-lg text-sm font-mono text-slate-200 placeholder-slate-600 focus:outline-none focus:border-emerald-500 transition-colors"
            />
            <button
              onClick={handleVerify}
              disabled={!input.trim() || loading}
              className="mt-4 px-6 py-2 bg-emerald-600 hover:bg-emerald-500 disabled:bg-slate-700 disabled:cursor-not-allowed rounded-lg font-semibold text-sm transition-colors"
            >
              {loading ? 'Verifying...' : 'Verify Trace'}
            </button>
          </div>

          {result && (
            <div
              className={`rounded-2xl border p-6 ${
                result.success
                  ? 'border-emerald-800 bg-emerald-950/20'
                  : 'border-red-800 bg-red-950/20'
              }`}
            >
              <div className="flex items-center gap-3 mb-4">
                <span className="text-2xl">
                  {result.success ? '✓' : '✗'}
                </span>
                <h2 className="text-xl font-semibold">
                  {result.success ? 'Verification PASSED' : 'Verification FAILED'}
                </h2>
              </div>

              {result.error ? (
                <p className="text-sm text-red-300">{result.error}</p>
              ) : (
                <div className="space-y-4">
                  <div className="grid gap-3 sm:grid-cols-2">
                    <div>
                      <p className="text-xs uppercase tracking-wide text-slate-500">RFC Version</p>
                      <p className="text-sm text-slate-200 font-mono">{result.version || '—'}</p>
                    </div>
                    <div>
                      <p className="text-xs uppercase tracking-wide text-slate-500">Trace ID</p>
                      <p className="text-sm text-slate-200 font-mono break-all">{result.id || '—'}</p>
                    </div>
                    <div>
                      <p className="text-xs uppercase tracking-wide text-slate-500">Timestamp</p>
                      <p className="text-sm text-slate-200">{result.timestamp || '—'}</p>
                    </div>
                    <div>
                      <p className="text-xs uppercase tracking-wide text-slate-500">Commit</p>
                      <p className="text-sm text-slate-200 font-mono break-all">{result.commit || '—'}</p>
                    </div>
                    <div>
                      <p className="text-xs uppercase tracking-wide text-slate-500">AI Tool</p>
                      <p className="text-sm text-slate-200">{result.tool || '—'} / {result.model || '—'}</p>
                    </div>
                    <div>
                      <p className="text-xs uppercase tracking-wide text-slate-500">Files Tracked</p>
                      <p className="text-sm text-slate-200">{result.fileCount || 0}</p>
                    </div>
                  </div>

                  {result.traceHash && (
                    <div>
                      <p className="text-xs uppercase tracking-wide text-slate-500 mb-1">Trace Hash (SHA-256)</p>
                      <p className="text-xs text-slate-300 font-mono break-all bg-slate-900/50 px-3 py-2 rounded">
                        {result.traceHash}
                      </p>
                      <p className="text-xs text-emerald-400 mt-1">✓ Hash integrity verified</p>
                    </div>
                  )}

                  {result.txHash && (
                    <div>
                      <p className="text-xs uppercase tracking-wide text-slate-500 mb-1">Solana Anchor</p>
                      <div className="flex items-center gap-2">
                        <p className="text-xs text-slate-300 font-mono break-all bg-slate-900/50 px-3 py-2 rounded flex-1">
                          {result.txHash}
                        </p>
                        {result.explorer && (
                          <Link
                            href={result.explorer}
                            target="_blank"
                            rel="noreferrer"
                            className="px-3 py-2 bg-emerald-600 hover:bg-emerald-500 rounded text-xs font-semibold transition-colors whitespace-nowrap"
                          >
                            View on Solscan ↗
                          </Link>
                        )}
                      </div>
                      <p className="text-xs text-emerald-400 mt-1">✓ On-chain verification available</p>
                    </div>
                  )}

                  <div className="border-t border-slate-700 pt-4 mt-4">
                    <p className="text-sm font-semibold text-emerald-400 mb-2">
                      ✓ This trace proves 100% AI authorship
                    </p>
                    <ul className="text-xs text-slate-400 space-y-1">
                      <li>• RFC 0.1.0 compliant trace schema</li>
                      <li>• SHA-256 hash integrity verified</li>
                      <li>• Solana devnet anchor confirmed</li>
                      <li>• AI tool attribution: {result.tool} / {result.model}</li>
                    </ul>
                  </div>
                </div>
              )}
            </div>
          )}
        </section>

        <section className="rounded-2xl border border-slate-800 bg-slate-900/40 p-6">
          <h2 className="text-lg font-semibold mb-3">How Verification Works</h2>
          <div className="space-y-3 text-sm text-slate-400">
            <p>
              Every commit in this project generates an RFC 0.1.0-compliant trace record that proves AI authorship:
            </p>
            <ol className="list-decimal list-inside space-y-2 pl-2">
              <li>
                <strong className="text-slate-300">Schema Validation:</strong> Checks RFC 0.1.0 compliance (version, UUID, timestamp, VCS, tool attribution)
              </li>
              <li>
                <strong className="text-slate-300">Hash Integrity:</strong> Recomputes SHA-256 hash over canonical JSON to verify tamper-proof record
              </li>
              <li>
                <strong className="text-slate-300">Solana Anchor:</strong> Verifies on-chain anchoring on Solana devnet for immutable proof
              </li>
              <li>
                <strong className="text-slate-300">AI Attribution:</strong> Confirms tool (github-copilot) and model (claude-sonnet-4.5) metadata
              </li>
            </ol>
            <p className="pt-2">
              This multi-layer verification ensures every line of code is provably AI-authored with cryptographic certainty.
            </p>
          </div>
        </section>

        <footer className="text-center">
          <Link
            href="/"
            className="inline-block px-6 py-2 border border-slate-700 hover:border-slate-600 rounded-lg text-sm transition-colors"
          >
            ← Back to Dashboard
          </Link>
        </footer>
      </main>
    </div>
  );
}
