import { FormEvent, useEffect, useMemo, useRef, useState } from 'react';
import { command, subscribe, unsubscribe } from './api';
import { phaseDuration, summarize } from './stats';
import type { DemoEvent, PhaseEvent, ResourceSummary, RunRecord, SnapshotEvent } from './types';

const HISTORY_KEY = 'kademlia-lab-history-v1';

function makeRunId(): string {
  return `run-${Date.now().toString(36)}-${Math.floor(Math.random() * 0xffffff).toString(36)}`;
}

function formatMs(value?: number): string {
  if (value === undefined) return '—';
  return value < 1_000 ? `${value.toFixed(1)} ms` : `${(value / 1_000).toFixed(2)} s`;
}

function formatBytes(value: number): string {
  if (value >= 1_048_576) return `${(value / 1_048_576).toFixed(2)} MiB`;
  if (value >= 1_024) return `${(value / 1_024).toFixed(1)} KiB`;
  return `${value} B`;
}

function loadHistory(): RunRecord[] {
  try {
    return JSON.parse(localStorage.getItem(HISTORY_KEY) || '[]') as RunRecord[];
  } catch {
    return [];
  }
}

export default function App() {
  const [snapshot, setSnapshot] = useState<SnapshotEvent>();
  const [resources, setResources] = useState<ResourceSummary[]>([]);
  const [runs, setRuns] = useState<RunRecord[]>(loadHistory);
  const [selected, setSelected] = useState<string>();
  const [error, setError] = useState<string>();
  const [seed, setSeed] = useState('42');
  const [size, setSize] = useState('262144');
  const [mime, setMime] = useState('application/octet-stream');
  const [lookupShip, setLookupShip] = useState('~zod');
  const [digest, setDigest] = useState('');
  const [publisher, setPublisher] = useState('~zod');
  const [namespace, setNamespace] = useState('demo');
  const [resourceName, setResourceName] = useState('latest');
  const [publishName, setPublishName] = useState(true);
  const [publishTransport, setPublishTransport] = useState<'custom' | 'scry'>('custom');
  const [topic, setTopic] = useState('software/urbit/hoon');
  const [catalogFormat, setCatalogFormat] = useState('kademlia-demo-resource-v1');
  const [topicRevision, setTopicRevision] = useState(1);
  const [seeds, setSeeds] = useState('');
  const [verbosity, setVerbosity] = useState('info');
  const [batchScenario, setBatchScenario] = useState<'lookup' | 'fetch-content' | 'browse-topic'>('fetch-content');
  const [repetitions, setRepetitions] = useState(10);
  const [warmups, setWarmups] = useState(2);
  const [batchRunning, setBatchRunning] = useState(false);
  const waiters = useRef(new Map<string, (event: PhaseEvent) => void>());
  const terminalEvents = useRef(new Map<string, PhaseEvent>());

  useEffect(() => {
    let subscription = 0;
    subscribe(handleEvent).then((id) => (subscription = id)).catch((reason) => setError(String(reason)));
    return () => {
      if (subscription) void unsubscribe(subscription);
    };
  }, []);

  useEffect(() => {
    const completed = runs.filter((run) => run.status !== 'running').slice(0, 200);
    localStorage.setItem(HISTORY_KEY, JSON.stringify(completed));
  }, [runs]);

  function handleEvent(event: DemoEvent) {
    if (event.type === 'snapshot') {
      setSnapshot(event);
      setResources(event.resources);
      setRuns((current) => current.map((run) => run.status === 'running' ? { ...run, status: 'interrupted', endedAt: performance.now() } : run));
      return;
    }

    const at = performance.now();
    setRuns((current) => {
      const index = current.findIndex((run) => run.id === event.run);
      if (index < 0) return current;
      const next = [...current];
      const terminal = event.phase === 'complete' || event.phase === 'failed' || event.phase === 'cancelled';
      const status = event.phase === 'complete'
        ? 'complete'
        : event.phase === 'failed'
          ? 'failed'
          : event.phase === 'cancelled'
            ? 'cancelled'
            : next[index].status;
      next[index] = {
        ...next[index],
        endedAt: terminal ? at : next[index].endedAt,
        status,
        phases: [...next[index].phases, { phase: event.phase, at, event }]
      };
      return next;
    });

    if (event.phase === 'complete' && typeof event.resource === 'object' && event.resource) {
      const resource = event.resource as ResourceSummary;
      setResources((current) => current.some((item) => item.content === resource.content) ? current : [resource, ...current]);
      setDigest(resource.content);
    }

    if (event.phase === 'complete' || event.phase === 'failed' || event.phase === 'cancelled') {
      const waiter = waiters.current.get(event.run);
      if (waiter) {
        waiter(event);
        waiters.current.delete(event.run);
      } else {
        terminalEvents.current.set(event.run, event);
      }
    }
  }

  async function start(scenario: string, body: Record<string, unknown>): Promise<string> {
    const run = makeRunId();
    const startedAt = performance.now();
    setError(undefined);
    setSelected(run);
    setRuns((current) => [{ id: run, scenario, startedAt, status: 'running', phases: [] }, ...current]);
    try {
      await command({ ...body, run });
    } catch (reason) {
      const at = performance.now();
      const failed: PhaseEvent = { type: 'phase', run, phase: 'failed', reason: String(reason) };
      setError(String(reason));
      setRuns((current) => current.map((item) => item.id === run ? {
        ...item,
        status: 'failed',
        endedAt: at,
        phases: [...item.phases, { phase: 'failed', at, event: failed }]
      } : item));
      terminalEvents.current.set(run, failed);
    }
    return run;
  }

  function awaitRun(run: string): Promise<PhaseEvent> {
    const terminal = terminalEvents.current.get(run);
    if (terminal) {
      terminalEvents.current.delete(run);
      return Promise.resolve(terminal);
    }
    return new Promise((resolve) => waiters.current.set(run, resolve));
  }

  async function submitCreate(event: FormEvent) {
    event.preventDefault();
    await start('create resource', { action: 'create', seed, size: Number(size), mime });
  }

  async function submitLookup(event: FormEvent) {
    event.preventDefault();
    await start('node lookup', { action: 'lookup', target: lookupShip });
  }

  async function submitPublish(event: FormEvent) {
    event.preventDefault();
    if (!digest) return;
    await start('publish resource', {
      action: 'publish',
      content: digest,
      transport: publishTransport,
      name: publishName ? { namespace, name: nameSegments(), revision: 1 } : null
    });
  }

  async function submitFetchDigest(event: FormEvent) {
    event.preventDefault();
    if (!digest) return;
    await start('fetch by digest', { action: 'fetch-content', content: digest });
  }

  async function submitFetchName(event: FormEvent) {
    event.preventDefault();
    await start('fetch by name', { action: 'fetch-name', publisher, namespace, name: nameSegments() });
  }

  function nameSegments(): string[] {
    return resourceName.split('/').map((segment) => segment.trim()).filter(Boolean);
  }

  function topicSegments(): string[] {
    return topic.split('/').map((segment) => segment.trim()).filter(Boolean);
  }

  async function submitAdvertiseTopic(event: FormEvent) {
    event.preventDefault();
    if (!digest || topicSegments().length === 0) return;
    await start('advertise topic catalog', {
      action: 'advertise-topic',
      content: digest,
      topic: topicSegments(),
      format: catalogFormat,
      revision: topicRevision
    });
  }

  async function submitBrowseTopic(event: FormEvent) {
    event.preventDefault();
    if (topicSegments().length === 0) return;
    await start('browse topic', { action: 'browse-topic', topic: topicSegments() });
  }

  async function submitNetwork(event: FormEvent) {
    event.preventDefault();
    await command({
      action: 'network',
      seeds: seeds.split(',').map((value) => value.trim()).filter(Boolean),
      requestTimeoutMs: 30_000,
      refreshIntervalMs: 3_600_000,
      verbosity
    });
  }

  async function resetAllState() {
    if (!window.confirm('Clear demo resources, benchmark history, routing contacts, and content records on this ship?')) return;
    setError(undefined);
    try {
      await command({ action: 'reset' });
      localStorage.removeItem(HISTORY_KEY);
      waiters.current.clear();
      terminalEvents.current.clear();
      setResources([]);
      setRuns([]);
      setSelected(undefined);
      setDigest('');
    } catch (reason) {
      setError(String(reason));
    }
  }

  async function runBatch() {
    if (batchRunning) return;
    setBatchRunning(true);
    setError(undefined);
    try {
      const total = warmups + repetitions;
      for (let index = 0; index < total; index += 1) {
        const body = batchScenario === 'lookup'
          ? { action: 'lookup', target: lookupShip }
          : batchScenario === 'browse-topic'
            ? { action: 'browse-topic', topic: topicSegments() }
            : { action: 'fetch-content', content: digest };
        const run = await start(`${batchScenario}${index < warmups ? ' warmup' : ''}`, body);
        await awaitRun(run);
      }
    } catch (reason) {
      setError(String(reason));
    } finally {
      setBatchRunning(false);
    }
  }

  const selectedRun = runs.find((run) => run.id === selected) || runs[0];
  const terminalEvent = selectedRun?.phases.slice().reverse().find((item) =>
    item.phase === 'complete' || item.phase === 'failed' || item.phase === 'cancelled'
  )?.event;
  const terminalReason = typeof terminalEvent?.reason === 'string' ? terminalEvent.reason : undefined;
  const topicResult = selectedRun?.phases.slice().reverse().find((item) => item.phase === 'topic-browse-complete')?.event;
  const measuredRuns = useMemo(() => runs.filter((run) => !run.scenario.includes('warmup')), [runs]);
  const stats = useMemo(() => summarize(measuredRuns), [measuredRuns]);
  const maxPhase = selectedRun ? Math.max(1, ...selectedRun.phases.map((phase) => phase.at - selectedRun.startedAt)) : 1;

  return (
    <main>
      <header className="hero">
        <div>
          <p className="eyebrow">Urbit overlay instrumentation</p>
          <h1>Kademlia <span>Lab</span></h1>
          <p className="lede">Publish deterministic resources, advertise and browse hierarchical topics, and time every overlay boundary from the browser.</p>
        </div>
        <div className="status-card">
          <span className={`status-dot ${snapshot ? 'online' : ''}`} />
          <div><strong>{snapshot ? `~${snapshot.ship.replace(/^~/, '')}` : 'connecting'}</strong><small>demo agent</small></div>
          {snapshot && <div><strong>{snapshot.config.window} × {formatBytes(snapshot.config.chunkBytes)}</strong><small>transfer window</small></div>}
        </div>
      </header>

      {error && <div className="error">{error}</div>}

      <section className="metrics">
        <Metric label="Measured runs" value={String(stats.count)} />
        <Metric label="Median" value={formatMs(stats.median)} />
        <Metric label="P95" value={formatMs(stats.p95)} />
        <Metric label="Failures" value={String(stats.failures)} danger={stats.failures > 0} />
      </section>

      <div className="grid">
        <section className="panel controls">
          <div className="panel-heading"><h2>Operations</h2><span>interactive</span></div>
          <form onSubmit={submitCreate}>
            <h3>Generate resource</h3>
            <label>Seed<input value={seed} onChange={(e) => setSeed(e.target.value)} /></label>
            <label>Size<select value={size} onChange={(e) => setSize(e.target.value)}>
              <option value="1024">1 KiB</option><option value="32768">32 KiB</option>
              <option value="262144">256 KiB</option><option value="1048576">1 MiB</option>
              <option value="8388608">8 MiB</option>
            </select></label>
            <label>MIME<input value={mime} onChange={(e) => setMime(e.target.value)} /></label>
            <button>Create</button>
          </form>

          <form onSubmit={submitPublish}>
            <h3>Publish</h3>
            <ResourceSelect resources={resources} value={digest} onChange={setDigest} />
            <label>Retrieval transport<select value={publishTransport} onChange={(e) => setPublishTransport(e.target.value as 'custom' | 'scry')}><option value="custom">Custom chunk protocol</option><option value="scry">Remote scry</option></select></label>
            <label className="check"><input type="checkbox" checked={publishName} onChange={(e) => setPublishName(e.target.checked)} /> publish named pointer</label>
            {publishName && <div className="row"><input value={namespace} onChange={(e) => setNamespace(e.target.value)} placeholder="namespace" /><input value={resourceName} onChange={(e) => setResourceName(e.target.value)} placeholder="name" /></div>}
            <button disabled={!digest}>Publish records</button>
          </form>

          <form onSubmit={submitAdvertiseTopic}>
            <h3>Advertise topic catalog</h3>
            <ResourceSelect resources={resources} value={digest} onChange={setDigest} />
            <label>Topic path<input value={topic} onChange={(e) => setTopic(e.target.value)} placeholder="software/urbit/hoon" /></label>
            <div className="row"><label>Catalog format<input value={catalogFormat} onChange={(e) => setCatalogFormat(e.target.value)} /></label><label>Revision<input type="number" min="0" value={topicRevision} onChange={(e) => setTopicRevision(Number(e.target.value))} /></label></div>
            <p className="form-note">Publish the resource records first. Its digest is then advertised as an opaque catalog, with parent edges generated automatically.</p>
            <button disabled={!digest || topicSegments().length === 0}>Advertise catalog</button>
          </form>

          <form onSubmit={submitBrowseTopic}>
            <h3>Browse exact topic</h3>
            <label>Topic path<input value={topic} onChange={(e) => setTopic(e.target.value)} placeholder="software/urbit" /></label>
            <button disabled={topicSegments().length === 0}>Find catalogs and children</button>
          </form>

          <form onSubmit={submitFetchDigest}>
            <h3>Fetch by digest</h3>
            <input value={digest} onChange={(e) => setDigest(e.target.value)} placeholder="0v…" />
            <button disabled={!digest}>Discover and fetch</button>
          </form>

          <form onSubmit={submitFetchName}>
            <h3>Fetch by mutable name</h3>
            <input value={publisher} onChange={(e) => setPublisher(e.target.value)} placeholder="~publisher" />
            <div className="row"><input value={namespace} onChange={(e) => setNamespace(e.target.value)} /><input value={resourceName} onChange={(e) => setResourceName(e.target.value)} /></div>
            <button>Resolve and fetch</button>
          </form>

          <form onSubmit={submitLookup}>
            <h3>Node lookup</h3>
            <input value={lookupShip} onChange={(e) => setLookupShip(e.target.value)} placeholder="~sampel-palnet" />
            <button>Find node</button>
          </form>
        </section>

        <section className="panel inspector">
          <div className="panel-heading"><h2>Run inspector</h2><span>{selectedRun?.status || 'idle'}</span></div>
          {!selectedRun ? <div className="empty">Start an operation to see its timing trace.</div> : <>
            <div className="run-title"><strong>{selectedRun.scenario}</strong><code>{selectedRun.id}</code><b>{formatMs(selectedRun.endedAt ? selectedRun.endedAt - selectedRun.startedAt : undefined)}</b></div>
            {terminalReason && <div className="run-reason">{terminalReason}</div>}
            <div className="waterfall">
              {selectedRun.phases.map((phase, index) => {
                const elapsed = phase.at - selectedRun.startedAt;
                const count = typeof phase.event.compatible === 'number'
                  ? `${phase.event.compatible}/${String(phase.event.records ?? '?')} compatible`
                  : undefined;
                return <div className="phase" key={`${phase.phase}-${index}`}>
                  <span>{phase.phase}{count && <small>{count}</small>}</span><div><i style={{ width: `${Math.max(2, (elapsed / maxPhase) * 100)}%` }} /></div><time>{formatMs(elapsed)}</time>
                </div>;
              })}
            </div>
            <div className="phase-grid">
              <Metric label="Lookup" value={formatMs(phaseDuration(selectedRun, 'lookup-complete'))} compact />
              <Metric label="Discovery" value={formatMs(phaseDuration(selectedRun, 'providers-complete'))} compact />
              <Metric label="First byte" value={formatMs(phaseDuration(selectedRun, 'first-byte'))} compact />
              <Metric label="Verified" value={formatMs(phaseDuration(selectedRun, 'verify-complete'))} compact />
            </div>
            {topicResult && <TopicResult event={topicResult} onFetch={(content) => {
              setDigest(content);
              void start('fetch discovered catalog', { action: 'fetch-content', content });
            }} />}
          </>}
        </section>

        <section className="panel benchmark">
          <div className="panel-heading"><h2>Batch runner</h2><span>serial</span></div>
          <div className="row"><select value={batchScenario} onChange={(e) => setBatchScenario(e.target.value as typeof batchScenario)}><option value="fetch-content">Fetch content</option><option value="browse-topic">Browse topic</option><option value="lookup">Node lookup</option></select><label>Runs<input type="number" min="1" max="100" value={repetitions} onChange={(e) => setRepetitions(Number(e.target.value))} /></label><label>Warmups<input type="number" min="0" max="10" value={warmups} onChange={(e) => setWarmups(Number(e.target.value))} /></label></div>
          <button onClick={runBatch} disabled={batchRunning || (batchScenario === 'fetch-content' && !digest) || (batchScenario === 'browse-topic' && topicSegments().length === 0)}>{batchRunning ? 'Running…' : 'Run benchmark'}</button>
          <div className="history">
            {runs.slice(0, 12).map((run) => <button className={run.id === selectedRun?.id ? 'selected' : ''} key={run.id} onClick={() => setSelected(run.id)}><span>{run.scenario}</span><small>{run.status}</small><b>{formatMs(run.endedAt ? run.endedAt - run.startedAt : undefined)}</b></button>)}
          </div>
          <button className="quiet" onClick={() => setRuns([])}>Clear local history</button>
        </section>

        <section className="panel network">
          <div className="panel-heading"><h2>Network controls</h2><span>local agents</span></div>
          <form onSubmit={submitNetwork}>
            <label>Seed ships<input value={seeds} onChange={(e) => setSeeds(e.target.value)} placeholder="~sampel-palnet, ~finned-palmer" /></label>
            <label>Verbosity<select value={verbosity} onChange={(e) => setVerbosity(e.target.value)}><option value="off">Off</option><option value="info">Info</option><option value="debug">Debug</option></select></label>
            <button>Apply configuration</button>
          </form>
          <div className="danger-zone">
            <button className="destructive" type="button" disabled={batchRunning} onClick={resetAllState}>Clear all state</button>
            <small>Resets the demo, routing table, seeds, content and discovery records, active operations, and saved profiling history on this ship.</small>
          </div>
          <p className="hint">Request timeout: 30 s · bucket refresh: 1 h. The Kademlia, content-routing, and content-discovery agents must be installed on this ship.</p>
        </section>
      </div>
    </main>
  );
}

interface TopicCatalog {
  publisher: string;
  revision: number;
  format: string;
  content: string;
  entries: number;
}

interface TopicChild {
  name: string;
  supporters: string[];
}

function TopicResult({ event, onFetch }: { event: PhaseEvent; onFetch: (content: string) => void }) {
  const catalogs = Array.isArray(event.catalogs) ? event.catalogs as TopicCatalog[] : [];
  const children = Array.isArray(event.children) ? event.children as TopicChild[] : [];
  const conflicts = Array.isArray(event.conflicts) ? event.conflicts : [];
  const topic = Array.isArray(event.topic) ? event.topic.join('/') : '';
  return <div className="topic-result">
    <div className="topic-result-heading"><strong>/{topic}</strong><span>{String(event.responders ?? 0)} responders · {String(event.timedOut ?? 0)} timed out</span></div>
    <div className="topic-columns">
      <div><h3>Catalogs <b>{catalogs.length}</b></h3>{catalogs.length === 0 ? <p>None at this exact path.</p> : catalogs.map((catalog) => <article key={`${catalog.publisher}-${catalog.revision}`}><strong>{catalog.format}</strong><small>{catalog.publisher} · revision {catalog.revision} · {catalog.entries} entries</small><code>{catalog.content}</code><button type="button" onClick={() => onFetch(catalog.content)}>Fetch catalog</button></article>)}</div>
      <div><h3>Immediate children <b>{children.length}</b></h3>{children.length === 0 ? <p>None.</p> : children.map((child) => <article key={child.name}><strong>/{child.name}</strong><small>{child.supporters.length} authenticated supporter{child.supporters.length === 1 ? '' : 's'}</small></article>)}</div>
    </div>
    {conflicts.length > 0 && <div className="topic-conflicts">{conflicts.length} conflicting record identit{conflicts.length === 1 ? 'y' : 'ies'}</div>}
  </div>;
}

function Metric({ label, value, danger, compact }: { label: string; value: string; danger?: boolean; compact?: boolean }) {
  return <div className={`metric ${danger ? 'danger' : ''} ${compact ? 'compact' : ''}`}><small>{label}</small><strong>{value}</strong></div>;
}

function ResourceSelect({ resources, value, onChange }: { resources: ResourceSummary[]; value: string; onChange: (value: string) => void }) {
  return <select value={value} onChange={(event) => onChange(event.target.value)}><option value="">Select a local resource</option>{resources.map((resource) => <option key={resource.content} value={resource.content}>{formatBytes(resource.size)} · {resource.content.slice(0, 22)}…</option>)}</select>;
}
