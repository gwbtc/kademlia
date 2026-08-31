# Kademlia Lab

Kademlia Lab is a small profiling application built on the `%kademlia`,
`%content-routing`, and `%content-discovery` agents. It generates deterministic
resources, advertises them through content routing and hierarchical topics,
transfers them in bounded parallel chunks, and emits phase events that the
browser timestamps with `performance.now()`.

The UI supports:

- node lookups;
- deterministic resource generation;
- provider and optional mutable-name publication using either the custom
  chunk transport or an exact-revision Ames remote-scry locator;
- retrieval by digest or mutable name;
- publication of signed topic catalogs, with automatic parent-edge records;
- exact-topic browsing that returns catalogs and authenticated immediate
  children, with a direct path from a discovered catalog to retrieval;
- per-run lookup, discovery, first-byte, transfer, and verification timing;
- serial warm-up and measured batches with median and p95 summaries; and
- Kademlia seed, timeout, refresh, and verbosity controls.

The Network controls panel also has a **Clear all state** action for starting a
fresh test. After confirmation it resets the demo resources and operations,
the local Kademlia routing table and seeds, content-routing origins and
replicas, published remote-scry pages, and the browser's saved profiling
history.

Resources are intentionally compact descriptors in the agent's normal state.
The custom transport regenerates bytes from the seed as peers request chunks,
so benchmarking an 8 MiB resource does not add an 8 MiB noun to every transfer
event. Choosing remote scry instead materializes the resource once and publishes
it as an immutable `%grow` page. Its content-routing locator names the exact
`/g/x/1/kademlia-demo//1/resource/...` path, so retrieval does not have to guess
a Gall revision. Both transports verify the complete resource digest before
reporting success.

## Build the desk

From the repository root:

```sh
mortar build -config mortar-demo.yaml
```

The complete desk is written to `demo/dist`. Mount or copy that directory into
a `%kademlia-demo` desk, commit it, and install the desk. The demo desk already
contains the Kademlia, content-routing, and content-discovery agents it depends
on.

## Run the frontend in development

Install and start Vite from `demo/ui`:

```sh
npm install
npm run dev
```

The Urbit Vite plugin proxies requests to the ship selected by its normal
`SHIP_URL`/login setup. Open the URL printed by Vite. The production bundle is
built with:

```sh
npm run build
```

The result in `demo/ui/dist` can be uploaded as a Landscape glob for the
`/apps/kademlia-demo/` route declared by `desk.docket-0`. The checked-in docket
currently references the development glob hosted by `~zod`. Rebuilding the UI
changes the glob hash, so a release must upload the new directory through
`/docket/upload` and commit the resulting `glob-http` or `glob-ames` reference.

## Tests

The desk contains pure resource/chunk tests and Gall-agent state tests under
`demo/desk/tests`. The frontend timing statistics have Vitest coverage.

```sh
npm run check
npm test
```

An Aqua scenario in `ted/kademlia-demo-network-test.hoon` boots `~bud` and
`~wes`, publishes a 256 KiB resource on `~wes`, fetches and verifies it on
`~bud`, advertises its catalog at `/software/urbit/hoon`, and discovers the
`hoon` child by browsing `/software/urbit`. With the repository's
`%kademlia-mortar` and `%kademlia-test` desks in the Aqua pill, run it as:

```hoon
-kademlia-mortar!kademlia-demo-network-test
```

The Gall agent deliberately clears active profiling operations and transfer
requests on upgrade while preserving locally generated resource descriptors.
This prevents stale Ames or Behn effects from resuming a benchmark with an
invalid browser clock origin.
