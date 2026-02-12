import { promises as fs } from 'node:fs'
import path from 'node:path'
import { Activity, Sparkles } from 'lucide-react'

const BUCKET_COUNT = 12
const BUCKET_WINDOW_MS = 60 * 60 * 1000

interface PowInfo {
  difficulty?: number
  nonce?: number
  digest?: string
}

interface TraceRecord {
  trace_id: string
  type: string
  timestamp: string
  instruction?: string
  model_name?: string
  hash?: string
  parent_trace_id?: string
  pow?: PowInfo
  metadata?: Record<string, unknown>
}

const cn = (...classes: (string | false | null | undefined)[]) => classes.filter(Boolean).join(' ')

function TypeBadge({ traceType }: { traceType?: string }) {
  const normalized = (traceType ?? 'unknown').toUpperCase()
  const palette: Record<string, string> = {
    ACTION: 'text-emerald-300 border-emerald-500/30 bg-emerald-500/10',
    PLAN: 'text-sky-300 border-sky-500/30 bg-sky-500/10',
    REASONING: 'text-amber-300 border-amber-500/30 bg-amber-500/10'
  }
  const fallback = 'text-zinc-300 border-zinc-500/40 bg-zinc-500/10'
  const classes = palette[normalized] ?? fallback

  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-full border px-2 py-0.5 text-[10px] font-semibold uppercase tracking-widest',
        classes
      )}
    >
      {normalized}
    </span>
  )
}

function formatRelative(timestamp: string) {
  const date = new Date(timestamp)
  if (Number.isNaN(date.getTime())) {
    return 'unknown'
  }
  const diffMs = Date.now() - date.getTime()
  const seconds = Math.floor(diffMs / 1000)
  const minutes = Math.floor(seconds / 60)
  const hours = Math.floor(minutes / 60)

  if (seconds < 60) return `${seconds}s ago`
  if (minutes < 60) return `${minutes}m ago`
  return `${hours}h ago`
}

function Sparkline({ data }: { data: { value: number }[] }) {
  if (!data.length) {
    return <div className="h-28 w-full text-xs text-slate-500">No data</div>
  }

  const width = 320
  const height = 140
  const maxValue = Math.max(...data.map((point) => point.value), 1)
  const step = data.length === 1 ? 1 : (width - 20) / (data.length - 1)

  const points = data.map((point, index) => {
    const x = 10 + index * step
    const y = height - ((point.value / maxValue) * (height - 20)) - 10
    return `${x},${y}`
  })

  const areaPath = ['M', points[0], ...points.slice(1).map((point) => ['L', point].join(' ')), `L ${width - 10} ${height - 10}`, `L 10 ${height - 10}`, 'Z'].join(' ')

  return (
    <svg className="w-full" viewBox={`0 0 ${width} ${height}`} role="img" aria-label="Trace throughput sparkline">
      <defs>
        <linearGradient id="sparkline-gradient" x1="0%" y1="0%" x2="0%" y2="100%">
          <stop offset="0%" stopColor="#0ea5e9" stopOpacity="0.8" />
          <stop offset="100%" stopColor="#0ea5e9" stopOpacity="0.05" />
        </linearGradient>
      </defs>
      <path d={areaPath} fill="url(#sparkline-gradient)" stroke="none" />
      <polyline points={points.join(' ')} fill="none" stroke="#38bdf8" strokeWidth={2} strokeLinecap="round" />
    </svg>
  )
}

const buildBuckets = (traces: TraceRecord[]) => {
  const now = Date.now()
  const chunkStart = now - BUCKET_WINDOW_MS * BUCKET_COUNT
  const buckets = Array.from({ length: BUCKET_COUNT }, (_, idx) => {
    const time = chunkStart + idx * BUCKET_WINDOW_MS
    return {
      label: new Date(time).toLocaleTimeString('en-US', {
        hour12: true,
        hour: 'numeric'
      }),
      value: 0
    }
  })

  traces.forEach((trace) => {
    const ts = new Date(trace.timestamp).getTime()
    if (Number.isNaN(ts)) return
    if (ts < chunkStart) return
    const index = Math.min(
      BUCKET_COUNT - 1,
      Math.floor((ts - chunkStart) / BUCKET_WINDOW_MS)
    )
    buckets[index].value += 1
  })

  return buckets
}

const getTypeBreakdown = (traces: TraceRecord[]) => {
  const counts: Record<string, number> = {}
  traces.forEach((trace) => {
    const key = trace.type ?? 'UNKNOWN'
    counts[key] = (counts[key] ?? 0) + 1
  })
  return counts
}

export default async function Home() {
  const tracesDir = path.resolve(process.cwd(), 'traces')
  const entries = await fs.readdir(tracesDir)
  const files = entries.filter((file) => file.endsWith('.json'))

  const records = await Promise.all(
    files.map(async (file) => {
      const raw = await fs.readFile(path.join(tracesDir, file), 'utf-8')
      return JSON.parse(raw) as TraceRecord
    })
  )

  const traces = records
    .filter((trace) => trace.timestamp)
    .sort((a, b) => new Date(b.timestamp).getTime() - new Date(a.timestamp).getTime())

  const sortedTraces = traces
  const totalTraces = sortedTraces.length
  const typeBreakdown = getTypeBreakdown(sortedTraces)
  const chartBuckets = buildBuckets(sortedTraces)
  const recentTraces = sortedTraces.slice(0, 6)
  const powTraces = sortedTraces.filter((trace) => typeof trace.pow?.difficulty === 'number')
  const totalPowDifficulty = powTraces.reduce((acc, trace) => acc + (trace.pow?.difficulty ?? 0), 0)
  const avgDifficulty = powTraces.length ? totalPowDifficulty / powTraces.length : 0
  const topPowTraces = powTraces
    .sort((a, b) => (b.pow?.difficulty ?? 0) - (a.pow?.difficulty ?? 0))
    .slice(0, 3)

  const activeBucket = chartBuckets[chartBuckets.length - 1]?.value ?? 0
  const recentCount = chartBuckets.slice(-3).reduce((sum, bucket) => sum + bucket.value, 0)
  const majorTypeCount = Math.max(...Object.values(typeBreakdown), 1)
  const heroTrace = sortedTraces[0]

  return (
    <div className="space-y-10">
      <header className="space-y-3">
        <div className="flex flex-wrap items-center justify-between gap-3">
          <div>
            <p className="text-lg font-semibold uppercase tracking-[0.4em] text-slate-500">Agent Trace Observatory</p>
            <h1 className="text-4xl font-bold text-white">Grafana-style transparency</h1>
          </div>
          <div className="flex items-center gap-2 rounded-full border border-slate-800 bg-slate-900/50 px-4 py-2 text-sm text-slate-300">
            <Sparkles size={16} /> Live activity & analytics
          </div>
        </div>
        <p className="max-w-3xl text-sm text-slate-400">
          Trace every decision, POW, and Solana anchor with a single glance. Charts aggregate throughput, type breakdowns
          surface context, and the live stream keeps pace with the latest commits.
        </p>
      </header>

      <section className="grid gap-6 md:grid-cols-3">
        <div className="rounded-2xl border border-slate-800/60 bg-slate-900/60 p-5 shadow-xl shadow-slate-950/20">
          <p className="text-sm uppercase tracking-[0.4em] text-slate-500">Traces recorded</p>
          <h2 className="mt-1 text-3xl font-semibold text-white">{totalTraces}</h2>
          <p className="text-xs text-slate-400">{recentCount} trace{s(recentCount)} captured in the last 3 hours</p>
        </div>
        <div className="rounded-2xl border border-slate-800/60 bg-gradient-to-br from-slate-900/80 to-slate-900/40 p-5 shadow-xl shadow-slate-950/30">
          <p className="text-sm uppercase tracking-[0.4em] text-slate-500">Avg. PoW difficulty</p>
          <h2 className="mt-1 text-3xl font-semibold text-white">{avgDifficulty.toFixed(2)}</h2>
          <p className="text-xs text-slate-400">{powTraces.length} traces ran PoW</p>
        </div>
        <div className="rounded-2xl border border-slate-800/60 bg-slate-900/60 p-5 shadow-xl shadow-slate-950/20">
          <p className="text-sm uppercase tracking-[0.4em] text-slate-500">Latest trace</p>
          <h2 className="mt-1 text-3xl font-semibold text-white">{heroTrace?.trace_id ?? 'Pending'}</h2>
          <p className="text-xs text-slate-400">{heroTrace ? formatRelative(heroTrace.timestamp) : 'No traces yet'}</p>
        </div>
      </section>

      <section className="grid gap-6 lg:grid-cols-[1.6fr,1fr]">
        <div className="rounded-3xl border border-slate-800/60 bg-slate-900/50 p-6">
          <div className="flex items-center justify-between gap-3">
            <div>
              <p className="text-sm uppercase tracking-[0.4em] text-slate-500">Trace throughput</p>
              <h3 className="text-2xl font-semibold text-white">{activeBucket} traces · active bucket</h3>
            </div>
            <span className="text-xs uppercase tracking-[0.3em] text-slate-400">Updated hourly</span>
          </div>
          <div className="mt-6">
            <Sparkline data={chartBuckets.map((bucket) => ({ value: bucket.value }))} />
          </div>
          <div className="mt-6 grid gap-3 md:grid-cols-3">
            {Object.entries(typeBreakdown).map(([type, count]) => (
              <div key={type} className="space-y-1">
                <div className="flex items-center justify-between gap-3">
                  <TypeBadge traceType={type} />
                  <span className="text-sm font-semibold text-white">{count}</span>
                </div>
                <div className="h-1 rounded-full bg-slate-800">
                  <span
                    className="block h-1 rounded-full bg-gradient-to-r from-emerald-400 to-cyan-400"
                    style={{ width: `${(count / majorTypeCount) * 100}%` }}
                  />
                </div>
              </div>
            ))}
          </div>
        </div>
        <div className="space-y-5">
          <div className="rounded-3xl border border-slate-800/60 bg-gradient-to-b from-slate-900/80 to-slate-900/40 p-5">
            <p className="text-sm uppercase tracking-[0.4em] text-slate-400">PoW leaderboard</p>
            <h3 className="mt-1 text-xl font-semibold text-white">Highest difficulties</h3>
            <div className="mt-4 space-y-3">
              {topPowTraces.length ? (
                topPowTraces.map((trace) => (
                  <div key={trace.trace_id} className="flex items-center justify-between rounded-2xl border border-slate-800/50 bg-slate-950/20 p-3">
                    <div>
                      <p className="text-sm font-semibold text-white">{trace.trace_id}</p>
                      <p className="text-xs text-slate-400">{trace.instruction ?? 'No instruction provided'}</p>
                    </div>
                    <div className="text-right text-xs text-slate-400">
                      <p>Difficulty {trace.pow?.difficulty ?? 0}</p>
                      <p>Nonce {trace.pow?.nonce ?? '—'}</p>
                    </div>
                  </div>
                ))
              ) : (
                <p className="text-sm text-slate-400">No PoW traces yet</p>
              )}
            </div>
          </div>
          <div className="rounded-3xl border border-slate-800/60 bg-slate-900/60 p-5">
            <p className="text-sm uppercase tracking-[0.4em] text-slate-400">Trace output</p>
            <p className="text-xs text-slate-500">Showing {recentTraces.length} most recent entries</p>
            <div className="mt-4 space-y-3">
              {recentTraces.map((trace) => (
                <div key={trace.trace_id} className="rounded-2xl border border-slate-800/50 bg-slate-950/40 p-3">
                  <div className="flex items-center justify-between">
                    <TypeBadge traceType={trace.type} />
                    <span className="text-xs text-slate-500">{formatRelative(trace.timestamp)}</span>
                  </div>
                  <p className="mt-2 text-sm font-semibold text-white">{trace.instruction ?? 'No instruction'}</p>
                  <p className="text-xs text-slate-400">
                    {trace.model_name ?? 'unknown model'} · {trace.trace_id}
                  </p>
                </div>
              ))}
            </div>
          </div>
        </div>
      </section>
    </div>
  )
}

function s(value: number) {
  return value === 1 ? '' : 's'
}
