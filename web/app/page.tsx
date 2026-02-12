import { promises as fs } from 'node:fs'
import path from 'node:path'

interface TraceSummary {
  trace_id: string
  type: string
  timestamp: string
  instruction?: string
  output?: any
}

export default async function Home() {
  const tracesDir = path.resolve(process.cwd(), 'traces')
  const files = await fs.readdir(tracesDir)
  const traces = await Promise.all(
    files
      .filter((file) => file.endsWith('.json'))
      .map(async (file) => {
        const content = await fs.readFile(path.join(tracesDir, file), 'utf-8')
        return JSON.parse(content) as TraceSummary
      })
  )
  const sorted = traces.sort((a, b) => (a.timestamp > b.timestamp ? -1 : 1))

  return (
    <div>
      <h1 className="text-3xl mb-6">Agent Audit Log Traces</h1>
      <div className="space-y-4">
        {sorted.map((trace) => (
          <article key={trace.trace_id} className="border border-slate-700 rounded-lg p-4 bg-slate-900/60">
            <header className="flex justify-between text-sm text-slate-400">
              <span>{trace.trace_id}</span>
              <span>{trace.type}</span>
            </header>
            <p className="text-xs text-slate-500">{trace.timestamp}</p>
            <p className="font-semibold text-lg">{trace.instruction ?? 'No instruction provided'}</p>
            <div className="mt-2 text-sm text-slate-300">
              <pre className="whitespace-pre-wrap">{JSON.stringify(trace.output ?? {}, null, 2)}</pre>
            </div>
          </article>
        ))}
      </div>
    </div>
  )
}
