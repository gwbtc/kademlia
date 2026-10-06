import { describe, expect, it } from 'vitest';
import { mutableNameSegments } from './mutableName';

describe('mutable-name JSON representation', () => {
  it('serializes a hierarchical name as a JSON segment array', () => {
    const payload = {
      action: 'fetch-name',
      publisher: '~zod',
      namespace: 'releases',
      name: mutableNameSegments('/packages/kademlia/latest')
    };

    expect(JSON.parse(JSON.stringify(payload))).toEqual({
      action: 'fetch-name',
      publisher: '~zod',
      namespace: 'releases',
      name: ['packages', 'kademlia', 'latest']
    });
  });

  it('rejects empty, over-deep, and over-wide names', () => {
    expect(() => mutableNameSegments('/')).toThrow();
    expect(() => mutableNameSegments('a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q')).toThrow();
    expect(() => mutableNameSegments('x'.repeat(65))).toThrow();
  });
});
