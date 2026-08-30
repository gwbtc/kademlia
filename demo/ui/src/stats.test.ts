import { describe, expect, it } from 'vitest';
import { percentile, summarize } from './stats';
import type { RunRecord } from './types';

describe('profiling statistics', () => {
  it('uses nearest-rank percentiles', () => {
    expect(percentile([1, 2, 3, 4, 5], 0.5)).toBe(3);
    expect(percentile([1, 2, 3, 4, 5], 0.95)).toBe(5);
  });

  it('separates failures from completed latency', () => {
    const runs: RunRecord[] = [
      { id: 'a', scenario: 'lookup', startedAt: 10, endedAt: 20, status: 'complete', phases: [] },
      { id: 'b', scenario: 'lookup', startedAt: 10, endedAt: 40, status: 'complete', phases: [] },
      { id: 'c', scenario: 'lookup', startedAt: 10, endedAt: 12, status: 'failed', phases: [] }
    ];
    expect(summarize(runs)).toEqual({ count: 3, failures: 1, min: 10, median: 10, p95: 30, max: 30 });
  });
});
