export interface ResourceSummary {
  content: string;
  seed: string;
  size: number;
  mime: string;
}

export interface SnapshotEvent {
  type: 'snapshot';
  ship: string;
  active: number;
  resources: ResourceSummary[];
  config: {
    chunkBytes: number;
    window: number;
    maxResourceBytes: number;
  };
}

export type Phase =
  | 'started'
  | 'lookup-started'
  | 'lookup-complete'
  | 'pointer-started'
  | 'pointer-complete'
  | 'providers-started'
  | 'providers-complete'
  | 'transfer-started'
  | 'first-byte'
  | 'transfer-progress'
  | 'transfer-complete'
  | 'verify-complete'
  | 'complete'
  | 'cancelled'
  | 'failed';

export interface PhaseEvent {
  type: 'phase';
  run: string;
  phase: Phase;
  [key: string]: unknown;
}

export type DemoEvent = SnapshotEvent | PhaseEvent;

export interface TimedPhase {
  phase: Phase;
  at: number;
  event: PhaseEvent;
}

export interface RunRecord {
  id: string;
  scenario: string;
  startedAt: number;
  endedAt?: number;
  status: 'running' | 'complete' | 'failed' | 'cancelled' | 'interrupted';
  phases: TimedPhase[];
}

export interface RunStats {
  count: number;
  failures: number;
  min: number;
  median: number;
  p95: number;
  max: number;
}
