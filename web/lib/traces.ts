import { promises as fs } from "fs";
import path from "path";

const LEGACY_TRACES_DIR = path.resolve(process.cwd(), "../traces");
const RFC_TRACES_DIR = path.resolve(process.cwd(), "../.agent-trace");

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

async function readJsonFile<T>(filePath: string): Promise<T | null> {
  try {
    const data = await fs.readFile(filePath, "utf-8");
    return JSON.parse(data) as T;
  } catch (error) {
    console.warn(`[trace-loader] Failed to parse ${filePath}:`, error);
    return null;
  }
}

async function listJsonFiles(dir: string): Promise<string[]> {
  try {
    const files = await fs.readdir(dir);
    return files
      .filter((file) => file.endsWith(".json"))
      .map((file) => path.join(dir, file));
  } catch {
    return [];
  }
}

async function loadLegacyTraces(): Promise<TraceSummary[]> {
  const files = await listJsonFiles(LEGACY_TRACES_DIR);
  const records = await Promise.all(
    files.map(async (filePath) => {
      const data = await readJsonFile<LegacyTraceJson>(filePath);
      if (!data) return null;
      return {
        id: data.trace_id ?? path.basename(filePath, ".json"),
        source: "legacy" as const,
        timestamp: data.timestamp,
        commitSha: typeof data.git_revision === "string" ? data.git_revision : undefined,
        label: data.instruction ?? data.type ?? "Legacy Trace",
        files: Array.isArray(data.files) ? data.files.length : undefined,
        filePaths: Array.isArray(data.files)
          ? data.files.map((file) => file?.path).filter(Boolean) as string[]
          : undefined,
        solanaTx:
          (data.metadata?.solana_tx as string | undefined) ??
          (data.metadata?.anchor_tx as string | undefined),
        hash: data.hash,
        path: filePath,
        extra: {
          type: data.type,
          model: data.model_name,
        },
      } satisfies TraceSummary;
    })
  );

  return records.filter(Boolean) as TraceSummary[];
}

async function loadAgentTraces(): Promise<TraceSummary[]> {
  const files = await listJsonFiles(RFC_TRACES_DIR);
  const records = await Promise.all(
    files.map(async (filePath) => {
      const data = await readJsonFile<AgentTraceJson>(filePath);
      if (!data) return null;
      return {
        id: data.id ?? path.basename(filePath, ".json"),
        source: "agent" as const,
        timestamp: data.timestamp,
        commitSha: data.vcs?.revision,
        label: data.metadata?.commit_message as string | undefined,
        files: Array.isArray(data.files) ? data.files.length : undefined,
        filePaths: Array.isArray(data.files)
          ? data.files.map((file) => file.path)
          : undefined,
        solanaTx: data.metadata?.solana_tx as string | undefined,
        hash: data.metadata?.trace_hash as string | undefined,
        path: filePath,
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
