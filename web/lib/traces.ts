import { promises as fs } from "fs";
import path from "path";

const LEGACY_TRACES_DIR = path.resolve(process.cwd(), "../traces");
const RFC_TRACES_DIR = path.resolve(process.cwd(), "../.agent-trace");
const LEGACY_TRACES_REMOTE_DIR = "traces";
const RFC_TRACES_REMOTE_DIR = ".agent-trace";

const GITHUB_REPO =
  process.env.NEXT_PUBLIC_GITHUB_REPO ??
  process.env.GITHUB_REPO ??
  "M-DEV-1/agent-audit-log";
const [GITHUB_OWNER, GITHUB_NAME] = GITHUB_REPO.split("/");
const GITHUB_API_BASE = `https://api.github.com/repos/${GITHUB_OWNER}/${GITHUB_NAME}/contents`;

const githubHeaders: Record<string, string> = {
  "User-Agent": "agent-audit-log-viewer",
};

if (process.env.GITHUB_TOKEN) {
  githubHeaders.Authorization = `Bearer ${process.env.GITHUB_TOKEN}`;
}

type TraceFileRef =
  | { type: "local"; path: string }
  | { type: "remote"; path: string; downloadUrl: string };

export type TraceSource = "legacy" | "agent";

export interface TraceSummary {
  id: string;
  source: TraceSource;
  timestamp?: string;
  commitSha?: string;
  label?: string;
  files?: number;
  filePaths?: string[];
  solanaTx?: string;
  hash?: string;
  path: string;
  extra?: Record<string, unknown>;
}

export interface TraceAnalytics {
  total: number;
  anchored: number;
  unanchored: number;
  bySource: Record<TraceSource, number>;
  latestTimestamp?: string;
  latestCommit?: string;
}

type LegacyTraceJson = {
  trace_id?: string;
  timestamp?: string;
  hash?: string;
  type?: string;
  instruction?: string;
  git_revision?: string;
  files?: Array<{ path?: string }>;
  metadata?: Record<string, unknown>;
  [key: string]: unknown;
};

type AgentTraceJson = {
  version: string;
  id: string;
  timestamp: string;
  vcs?: {
    type?: string;
    revision?: string;
  };
  tool?: {
    name?: string;
    version?: string;
  };
  files?: Array<{ path: string }>;
  metadata?: Record<string, unknown>;
};

async function readJsonFile<T>(ref: TraceFileRef): Promise<T | null> {
  try {
    const payload =
      ref.type === "local"
        ? await fs.readFile(ref.path, "utf-8")
        : await fetch(ref.downloadUrl, { headers: githubHeaders, cache: "no-store" }).then((res) => {
            if (!res.ok) {
              throw new Error(`GitHub fetch failed: ${res.status}`);
            }
            return res.text();
          });
    return JSON.parse(payload) as T;
  } catch (error) {
    console.warn(`[trace-loader] Failed to parse ${ref.path}:`, error);
    return null;
  }
}

async function listLocalJsonFiles(dir: string): Promise<TraceFileRef[]> {
  try {
    const files = await fs.readdir(dir);
    return files
      .filter((file) => file.endsWith(".json"))
      .map((file) => ({ type: "local" as const, path: path.join(dir, file) }));
  } catch {
    return [];
  }
}

async function listGitHubJsonFiles(dir: string): Promise<TraceFileRef[]> {
  try {
    const url = `${GITHUB_API_BASE}/${dir.replace(/^\/+/, "")}`;
    const res = await fetch(url, { headers: githubHeaders, cache: "no-store" });
    if (!res.ok) return [];
    const data = (await res.json()) as Array<{
      type: string;
      name: string;
      path: string;
      download_url?: string;
    }>;
    return data
      .filter((item) => item.type === "file" && item.name.endsWith(".json") && item.download_url)
      .map((item) => ({
        type: "remote" as const,
        path: item.path,
        downloadUrl: item.download_url!,
      }));
  } catch (error) {
    console.warn(`[trace-loader] Failed to list GitHub directory ${dir}:`, error);
    return [];
  }
}

async function listJsonFiles(localDir: string, remoteDir: string): Promise<TraceFileRef[]> {
  const local = await listLocalJsonFiles(localDir);
  if (local.length > 0) return local;
  return listGitHubJsonFiles(remoteDir);
}

async function loadLegacyTraces(): Promise<TraceSummary[]> {
  const files = await listJsonFiles(LEGACY_TRACES_DIR, LEGACY_TRACES_REMOTE_DIR);
  const records = await Promise.all(
    files.map(async (fileRef) => {
      const data = await readJsonFile<LegacyTraceJson>(fileRef);
      if (!data) return null;
      const fileName = path.basename(fileRef.path, ".json");
      return {
        id: data.trace_id ?? fileName,
        source: "legacy" as const,
        timestamp: data.timestamp,
        commitSha: typeof data.git_revision === "string" ? data.git_revision : undefined,
        label: data.instruction ?? data.type ?? "Legacy Trace",
        files: Array.isArray(data.files) ? data.files.length : undefined,
        filePaths: Array.isArray(data.files)
          ? (data.files.map((file) => file?.path).filter(Boolean) as string[])
          : undefined,
        solanaTx:
          (data.metadata?.solana_tx as string | undefined) ??
          (data.metadata?.anchor_tx as string | undefined),
        hash: data.hash,
        path: fileRef.path,
        extra: {
          type: data.type,
          model: (data as { model_name?: string }).model_name,
        },
      } satisfies TraceSummary;
    })
  );

  return records.filter(Boolean) as TraceSummary[];
}

async function loadAgentTraces(): Promise<TraceSummary[]> {
  const files = await listJsonFiles(RFC_TRACES_DIR, RFC_TRACES_REMOTE_DIR);
  const records = await Promise.all(
    files.map(async (fileRef) => {
      const data = await readJsonFile<AgentTraceJson>(fileRef);
      if (!data) return null;
      const fileName = path.basename(fileRef.path, ".json");
      return {
        id: data.id ?? fileName,
        source: "agent" as const,
        timestamp: data.timestamp,
        commitSha: data.vcs?.revision,
        label: data.metadata?.commit_message as string | undefined,
        files: Array.isArray(data.files) ? data.files.length : undefined,
        filePaths: Array.isArray(data.files)
          ? data.files.map((file) => file.path)
          : undefined,
        solanaTx:
          (data.metadata?.solana_tx as string | undefined) ??
          ((data.metadata?.solana_anchor as { tx_hash?: string })?.tx_hash ?? undefined),
        hash: data.metadata?.trace_hash as string | undefined,
        path: fileRef.path,
        extra: {
          tool: data.tool,
        },
      } satisfies TraceSummary;
    })
  );

  return records.filter(Boolean) as TraceSummary[];
}

export async function loadTraceSummaries(): Promise<TraceSummary[]> {
  const [legacy, agent] = await Promise.all([loadLegacyTraces(), loadAgentTraces()]);
  return [...legacy, ...agent].sort((a, b) => {
    const aTs = a.timestamp ? Date.parse(a.timestamp) : 0;
    const bTs = b.timestamp ? Date.parse(b.timestamp) : 0;
    return bTs - aTs;
  });
}

export function summarizeTraces(traces: TraceSummary[]): TraceAnalytics {
  const total = traces.length;
  const anchored = traces.filter((trace) => Boolean(trace.solanaTx)).length;
  const bySource: Record<TraceSource, number> = {
    legacy: traces.filter((trace) => trace.source === "legacy").length,
    agent: traces.filter((trace) => trace.source === "agent").length,
  };
  const latest = traces.at(0);

  return {
    total,
    anchored,
    unanchored: total - anchored,
    bySource,
    latestTimestamp: latest?.timestamp,
    latestCommit: latest?.commitSha,
  };
}

export interface TimelineDataPoint {
  hour: string;
  count: number;
  anchored: number;
}

export interface VelocityMetrics {
  commitsLast24h: number;
  commitsPerHour: number;
  peakHour: string;
  peakCount: number;
}

export function buildCommitTimeline(traces: TraceSummary[]): TimelineDataPoint[] {
  const now = new Date();
  const last24Hours: TimelineDataPoint[] = [];
  
  // Create 24 hourly buckets
  for (let i = 23; i >= 0; i--) {
    const hourDate = new Date(now.getTime() - i * 60 * 60 * 1000);
    const hourKey = `${hourDate.getHours().toString().padStart(2, '0')}:00`;
    last24Hours.push({ hour: hourKey, count: 0, anchored: 0 });
  }
  
  // Fill buckets with trace data
  traces.forEach(trace => {
    if (!trace.timestamp) return;
    const traceTime = new Date(trace.timestamp);
    const hoursDiff = Math.floor((now.getTime() - traceTime.getTime()) / (60 * 60 * 1000));
    
    if (hoursDiff >= 0 && hoursDiff < 24) {
      const bucketIndex = 23 - hoursDiff;
      last24Hours[bucketIndex].count++;
      if (trace.solanaTx) {
        last24Hours[bucketIndex].anchored++;
      }
    }
  });
  
  return last24Hours;
}

export function calculateVelocity(traces: TraceSummary[]): VelocityMetrics {
  const now = new Date();
  const last24h = traces.filter(trace => {
    if (!trace.timestamp) return false;
    const traceTime = new Date(trace.timestamp);
    return (now.getTime() - traceTime.getTime()) < 24 * 60 * 60 * 1000;
  });
  
  const timeline = buildCommitTimeline(traces);
  const peak = timeline.reduce((max, point) => 
    point.count > max.count ? point : max, 
    { hour: '00:00', count: 0, anchored: 0 }
  );
  
  return {
    commitsLast24h: last24h.length,
    commitsPerHour: last24h.length > 0 ? +(last24h.length / 24).toFixed(2) : 0,
    peakHour: peak.hour,
    peakCount: peak.count
  };
}
