import type { RunRecord, RunStats } from './types';

export function percentile(sorted: number[], fraction: number): number {
  if (sorted.length === 0) return 0;
  const index = Math.max(0, Math.ceil(sorted.length * fraction) - 1);
  return sorted[Math.min(index, sorted.length - 1)];
}

export function summarize(runs: RunRecord[]): RunStats {
  const complete = runs
    .filter((run) => run.status === 'complete' && run.endedAt !== undefined)
    .map((run) => run.endedAt! - run.startedAt)
    .sort((a, b) => a - b);

  return {
    count: runs.length,
    failures: runs.filter((run) => run.status !== 'complete').length,
    min: complete[0] ?? 0,
    median: percentile(complete, 0.5),
    p95: percentile(complete, 0.95),
    max: complete.at(-1) ?? 0
  };
}

export function phaseDuration(run: RunRecord, phase: string): number | undefined {
  const item = run.phases.find((candidate) => candidate.phase === phase);
  return item ? item.at - run.startedAt : undefined;
}
