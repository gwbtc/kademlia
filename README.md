# Kademlia for Urbit

This desk contains a Kademlia-style overlay for Urbit: pure routing libraries
and four Gall agent wrappers. An agent gains the protocols by wrapping itself:

```hoon
/+  kademlia-agent, content-routing-agent, content-discovery-agent
/+  content-store-agent
%-  agent:content-store-agent
%-  agent:content-discovery-agent
%-  agent:content-routing-agent
%-  agent:kademlia-agent
^-  agent:gall
|_  =bowl:gall
...
```

`kademlia-agent` works alone. The routing and discovery wrappers each need
`kademlia-agent` below them. `content-store-agent` needs all three below it.
`app/kademlia-example.hoon` is a minimal agent that stacks all four. See [Using the wrappers](#using-the-wrappers).

The desk holds:

- `lib/feistel.hoon`: the supplied Feistel permutation over the complete
  128-bit Ames ship-ID and Kademlia node-ID domain.
- `sur/kademlia.hoon`: stable identity, routing, and lookup-state types.
- `lib/kademlia.hoon`: identity conversion, XOR distance, bucket selection,
  bounded routing-table updates, and a pure iterative node-lookup state
  machine. Its routing table is an adaptive 128-bit prefix tree whose leaves
  use most-recent-first lists with stored live and replacement counts.
- `sur/content-routing.hoon` and `lib/content-routing.hoon`: a separate pure
  layer for signed mutable pointers, content-provider announcements, and
  content verification without coupling Kademlia to an application data type.
- `sur/content-routing-agent.hoon`, `lib/content-routing-agent-logic.hoon`, and
  `lib/content-routing-agent.hoon`: the ordinary-Ames record transport, leased replica
  store, publication/query state machine, Jael-backed signatures, and Gall
  interface layered over node lookup.
- `sur/content-discovery.hoon`, `lib/content-discovery.hoon`,
  `sur/content-discovery-agent.hoon`, `lib/content-discovery-agent-logic.hoon`,
  and `lib/content-discovery-agent.hoon`: an open, signed hierarchical topic index
  whose catalog payloads can be resolved through the content-routing layer.
- `lib/kademlia-agent.hoon`: an agent wrapper that runs iterative `FIND_NODE`
  lookups over ordinary Ames pokes, with its pure transitions in
  `lib/kademlia-agent-logic.hoon`.
- `lib/record-crypto.hoon`: record signing and verification against Jael keys,
  shared by the routing and discovery wrappers.
- `app/kademlia-example.hoon`: the example agent.
- `sur/content-store.hoon`, `lib/content-store-agent-logic.hoon`,
  `lib/content-store-agent.hoon`, and `lib/content-store-client.hoon`: a
  wrapper that publishes typed casks through exact remote-scry pages,
  advertises them through content routing and optional names and topics,
  retrieves and verifies them, and exposes one typed callback API.
- `sur/bounded-poke.hoon` and `lib/bounded-poke.hoon`: the persistent,
  per-peer outbound-poke gate shared by the three protocol wrappers.
- `tests/lib/kademlia.hoon`: unit coverage for the core invariants.
- `tests/lib/content-routing.hoon`: unit coverage for content-routing records,
  validation, revision conflicts, and provider selection.
- `tests/lib/content-discovery.hoon` and the content-routing and discovery
  agent-logic and wrapper tests: record selection, storage, operation, refresh,
  concurrency, callback, and Gall-interface coverage.
- `tests/lib/bounded-poke.hoon`: queue ordering, expiry, acknowledgement,
  cancellation, reset, and response-cap coverage.
- `tests/lib/content-store-agent.hoon` and `tests/lib/content-store-client.hoon`:
  wrapper orchestration, callback, page-reuse, revision, and client-card tests.

## Profiling demo

[`demo/`](demo/) contains Kademlia Lab, a separate Gall application and React
frontend for exercising the overlay interactively. It can generate resources,
publish provider and mutable-name records, fetch resources in parallel chunks,
advertise catalogs in hierarchical topics, browse catalogs and immediate topic
children, run node lookups, and display browser-measured phase timings and
batch percentiles. The complete demo desk—including this project's Kademlia
sources and pinned Urbit dependencies—is assembled with:

```sh
mortar build --config mortar-demo.yaml
```

See [`demo/README.md`](demo/README.md) for the desk, UI, and test workflow.

## Discovery and data transport

Kademlia discovery and data retrieval are separate protocols. Iterative node
lookup and value-location lookup use ordinary Ames messages. A value lookup
returns signed content-routing records rather than application data. Those
records provide either explicit retrieval locators or a digest used for a
second provider lookup.

An exact `$spar:ames` is one supported locator. When it targets Gall, its path
includes the actual revision in `/g/x/<revision>/...`; callers must not assume
or synthesize that revision. Application-defined custom locators are also
supported.
The `%content-routing` agent transports those records over ordinary Ames pokes;
remote scry remains one possible final retrieval mechanism, not a requirement.

An application stacks the wrappers it needs and normally uses only the
highest API. `content-store-agent` provides the simple end-to-end API; see
[`docs/content-store.md`](docs/content-store.md). The content-routing and
content-discovery wrappers call the
kademlia wrapper below them, so an application need not orchestrate their node
lookups. It may send `%kademlia-command` for raw node lookup, send
`%content-routing-command` for pointer/provider resolution, or browse with
`%content-discovery-command` and then pass a selected catalog digest to
content routing for retrieval locations. Overlay seeds and timing remain
configuration on the kademlia wrapper.

## Using the wrappers

Each wrapper handles its own marks and passes everything else to the agent it
wraps:

| Wrapper | Marks | Wires | Scries |
|---|---|---|---|
| `kademlia-agent` | `%kademlia-command`, `%kademlia-message` | `/~/kademlia/...` | `/x/~/kademlia/...` |
| `content-routing-agent` | `%content-routing-command`, `%content-routing-message` | `/~/content-routing/...` | `/x/~/content-routing/...` |
| `content-discovery-agent` | `%content-discovery-command`, `%content-discovery-message` | `/~/content-discovery/...` | `/x/~/content-discovery/...` |
| `content-store-agent` | `%content-store-command` | `/~/content-store/...` | `/x/~/content-store/...` |

The wrapped agent must leave those wires and paths alone. `content-store-agent`
also binds the casks it publishes under `/content-store` in the agent's
`%grow` namespace.

Peers are the same agent on other ships: a wrapper sends protocol messages to
`[ship dap.bowl]`. Each wrapped app therefore forms its own overlay. Two apps
on one ship share no routing table and no records.

To send a command, the wrapped agent pokes itself:

```hoon
[%pass /my-wire %agent [our.bowl dap.bowl] %poke %kademlia-command !>(command)]
```

Commands that take a recipient (`%find-for`, `%observe`) deliver the result as
a poke with the `%kademlia-result`, `%content-routing-result`,
`%content-discovery-result` or `%content-store-result` mark. When the
recipient is the wrapped agent's own
name, the wrapper calls the agent's `+on-poke` directly, with `src.bowl` set to
our ship. Any other recipient gets an ordinary local poke. A reply path must
not start with `/~`; the wrappers keep those for themselves.

Each wrapper saves its state beside the wrapped agent's state, as
`[[%kademlia state] inner]` and so on. Adding a wrapper to a running agent
starts that wrapper with fresh state and passes the old state through.

The wrappers do not apply `dbug` or `verb`; the application applies them.

## Content routing

Content routing is layered above the generic node lookup.  A mutable application
name derives a 128-bit pointer key from its namespace, publisher node ID, and an
ordinary Hoon `path`.  A valid signed pointer selects either a `%direct` list of
retrieval locators or a `%content` digest whose current providers must be found
under a second derived Kademlia key:

```text
stable name -> signed pointer -> direct locator -> fetch
stable name -> signed pointer -> digest -> provider lookup -> locator -> fetch
```

A content digest is SHA-256 of `jam` over the complete `(cask)`, so both its mark
and noun are committed.  After retrieval, `+verify-cask` checks the result
without interpreting application data. Locators may be exact remote-scry
`$spar:ames` values or application-defined `%custom` addresses.
Routing records never embed content themselves.

Pointers have monotonically increasing revisions and optional expiry.  Provider
announcements have revisions and mandatory expiry.  Signature checking is
supplied to the pure library as a gate; access to Urbit identity keys remains an
agent responsibility.  Different signed bodies from one identity at the same
greatest revision are treated as equivocation.  A pointer conflict fails the
selection, while a conflicting provider is excluded without hiding other valid
providers. Provider selection authenticates and groups announcements in one
pass, then sorts only the unique provider identities for deterministic output.

The library implements the pure part of an iterative node lookup. `+start-lookup`
seeds a lookup from the routing table. Each call to `+dispatch` marks up to the
configured `alpha` closest unasked candidates as in-flight and returns their
IDs. The agent is responsible for turning those IDs into ordinary Ames
requests, correlating replies, and scheduling Behn timeouts.

On a valid response, the agent passes the responder and the returned IDs to
`+receive`. This marks the request successful, admits at most the first `k`
returned IDs to the lookup, and records the responder as a verified routing
contact. `+timeout` marks an in-flight request failed and applies the normal
routing failure and replacement policy. Responses and timeouts for candidates
which are not in-flight are no-ops, so late or duplicate events are safe.

The agent repeats dispatch and event handling until `+lookup-complete` is true,
then reads `+lookup-result`. The result is up to `k` closest successful node
IDs. Indirectly mentioned candidates remain local to the lookup and do not enter
the routing table until they answer successfully. The lookup retains all valid
discovered candidates so failed close peers can be replaced by farther ones,
while its active frontier is always the closest `k` nonfailed candidates.
Initial routing contacts are produced in exact XOR-distance order by traversing
the routing prefix tree, sorting only each bounded leaf roster. This avoids
collecting and globally sorting the entire routing table.
Lookup responses likewise deduplicate and sort fresh candidates once before a
linear merge. Dispatch, status settlement, completion, result construction,
and invariant validation traverse the ordered shortlist without intermediate
filter lists or repeated per-candidate status searches.
Incoming node queries walk matching XOR-prefix branches first and stop after
`k` live contacts, instead of collecting and globally sorting the routing table.

## Peer-discovery agent

The `kademlia-agent` wrapper implements the first ordinary-Ames protocol milestone.
Peers exchange typed `%kademlia-message` pokes containing versioned
`%find-node` requests and `%nodes` responses.  Each outbound peer request has a
unique request ID, a configurable Behn timeout (five minutes by default), and
an expected sender identity. Successful responses and poke nacks cancel their
timers; timeout wakes consume the timer normally. Late, duplicate, unsolicited,
and wrong-sender responses are ignored.

Caller lookup IDs and peer request IDs are limited to 64 bits. Caller-supplied
conflicts or oversized IDs nack the local command. Internally allocated IDs
wrap within 64 bits and skip entries still owned by active state; oversized
remote IDs are dropped without a protocol response.

`%nodes` responses carry a count and an atom containing fixed 128-bit chunks,
rather than an unbounded Hoon list.  The protocol accepts at most 20 chunks and
checks the packed atom's bit width before allocating the decoded contact list.
Malformed responses immediately fail a matching request; malformed unsolicited
responses are ignored.

Local `%kademlia-command` pokes can replace bootstrap ships, set the request
timeout with `%set-request-timeout`, set the positive per-bucket refresh
interval with `%set-refresh-interval`, start a caller-ID'd lookup, and forget a
completed result. `%set-verbosity` selects `%off`, `%info`, or `%debug`
application logging and persists independently from the generic `verb` wrapper.
`%find-for` is the internal callback form: it allocates a
lookup ID and pokes a typed `%kademlia-result` notice to the requesting local
agent when lookup completes. Lookup transitions return the exact completed ID,
so callback delivery performs one map lookup rather than scanning every
registered callback after each response or timeout. Commands are accepted only
from the local ship. Read-only
diagnostics are available through `/summary`, `/settings`, `/table`, `/seeds`,
`/delivery`, `/verbosity`, and `/lookup/<id>` Gall scries under `/~/kademlia`,
using the `%noun` output mark. For example:

```hoon
.^(* %gx /=kademlia-example=/~/kademlia/summary/noun)
.^(* %gx /=kademlia-example=/~/kademlia/lookup/0v1/noun)
.^(* %gx /=kademlia-example=/~/kademlia/delivery/noun)
```

See [`docs/kademlia.md`](docs/kademlia.md) for the complete identity model,
routing-table and bucket policy, iterative lookup state machine, refresh
scheduler, peer protocol, Gall API, and invariants.

## Content-record transport wrapper

The separate `content-routing-agent` wrapper keeps Kademlia itself agnostic about
application data. Local `%content-routing-command` pokes publish signed pointer
or provider records, start pointer/provider queries, forget completed operation
results, update transport limits, or set its independent persistent verbosity
with `[%set-verbosity ?(%off %info %debug)]`. The current level is available at
`/~/content-routing/verbosity` through a `%noun` Gall scry. The wrapper asks the
kademlia wrapper below it for the closest nodes, then sends versioned `%content-routing-message`
store/query RPCs to at most three peers per operation and twelve peers across
the agent. A persistent round-robin ready queue shares that global budget among
active operations. Each RPC has a five-minute Behn timeout. Publication
completes only after every selected replica has been accounted for as accepted,
rejected, or timed out.

Remote protocol pokes pass through a persistent per-peer delivery gate. The
`/delivery` Gall scry reports tracked peers, active gates, queued responses,
queued requests, and cumulative queue expirations. Its `overflow-dropped`
counter records responses rejected after a peer already has 32 live responses
queued. Expired responses are pruned before enforcing the cap. Responses are
promoted ahead of requests, and both queues use the configured request timeout.
The cap is per remote peer, separately within each wrapper, and excludes
the one currently active poke. An overflowed response is silently discarded;
the requester observes its normal request timeout. Locally initiated requests
have no count cap because they are already bounded by application concurrency,
but they expire from the delivery queue at the same deadline.

Content operation IDs and transport request IDs follow the same 64-bit local
conflict, internal allocation, and remote rejection rules as Kademlia IDs.
Pointer lookup keys are limited to 128 bits and provider-query content digests
to 256 bits before hashing or replica-map access. Oversized local query inputs
nack, while oversized remote queries are silently dropped.
`%store` and `%records` carry jammed atoms rather than structurally unbounded
record nouns. Receivers check atom size before `cue`; the wire protocol permits
at most 64 KiB per record, 64 records, and 256 KiB for an entire response.
Malformed stores are dropped, while a malformed response immediately fails its
matching pending request.
Response packing finds the longest byte-bounded record prefix by binary search,
requiring at most logarithmically many whole-prefix encodings.
Response IDs, kinds, and senders are matched against pending state before any
response payload is decoded. Unsolicited, late, duplicate, and wrong-sender
responses are therefore dropped without decode work.
Logic transitions explicitly return the operation-completion events produced by
each scheduler pass. The agent uses those events for direct callback-map lookups
instead of comparing and scanning the complete retained-result map after every
response or timeout.

Unsigned local publication bodies are completed with the local 128-bit node ID
and signed using the ship's current Jael Ames key. Receiving replicas resolve
the signer's node ID back to a ship, obtain the public key for the stated life
from Jael, and verify the domain-separated record digest. Replica leases last
24 hours; locally originated records are republished every 12 hours. Defaults
also limit records to 64 KiB, provider identities to 64 per content key, and
the replica store to 10,000 keys with deterministic earliest-expiry eviction.
Reads and ordinary stores prune leases only under the accessed key. A complete
store sweep occurs only when a new key reaches the configured capacity, before
the eviction policy is applied. The state maintains the number of replica keys
alongside the map, so ordinary capacity checks do not traverse the whole store;
targeted pruning, full pruning, and eviction update that count transactionally.
Origin refreshes collect active publication keys once per batch and persist a
queue of keys. At most eight origins are started per wake; an unfinished sweep
continues on a short follow-up wake. This bounds both event size and per-event
work without installing one timer per origin.

Operation results are exposed at `/operation/<id>`. Stored records can be read
at `/records/<key>`, pointer records at `/pointer/<key>`, and provider records at
`/providers/<digest>`, all under the agent's `%gx` namespace with `%noun` output.
The transport returns records and locators only—it does not fetch final content.

See [`docs/content-routing.md`](docs/content-routing.md) for the complete naming
model, pointer and provider semantics, publication and query flows, signature
and conflict policy, transport bounds, and application integration guidance.

## Topic discovery

`%content-discovery` provides application-independent browsing above content
routing. A topic is a nonempty list of up to eight `%tas` segments, with at
most 64 bytes per segment. Each exact path derives its own 128-bit Kademlia key.
Applications publish only an opaque catalog reference:

```hoon
[format=%my-catalog-v1 digest=<content-digest> entries=42]
```

The catalog body is not interpreted by discovery. Its digest can be resolved
and fetched through `%content-routing`, preserving referential transparency for
the catalog payload while allowing its contents to use any application mold.

Advertising `/software/urbit/hoon` publishes one signed catalog record at that
exact path and signed edges at `/software` and `/software/urbit`. No global
empty-root record is created. An exact browse returns the current catalog from
each publisher plus the immediate child names and the authenticated publishers
supporting each child. Catalogs are ordered by publisher and children
lexicographically. The greatest revision wins per publisher and topic; distinct
records at the same greatest revision are reported as conflicts.

The local command API is `%advertise`, `%browse`, `%observe`, `%forget`,
`%set-config`, `%set-verbosity`, and `%reset`. Publication is a batch operation:
its single external ID completes only after the catalog and every generated
edge have each completed bounded Kademlia replication. Peer responses are
bounded to 64 records per key, with an additional default limit of eight
records from one publisher under a key. Records use Jael-backed Ames-key
signatures, leases, periodic refresh, bounded wire atoms, request timeouts, and
the same global fair scheduler as content routing.

See [`docs/content-discovery.md`](docs/content-discovery.md) for the complete
data model, publisher and format semantics, publication and browsing flows,
selection rules, API, resource limits, and application integration guidance.

## Routing buckets

A routing table starts as one empty leaf created by `+empty-table`. Leaves
partition the 128-bit node-ID space by most-significant-bit prefixes. When a
newly verified contact reaches a full leaf whose range contains the local node,
that leaf splits and its contacts are redistributed by the next prefix bit.
Splitting repeats down the local node's branch when necessary.

Each leaf records when a lookup was last started in its range. One global Behn
wake scans the prefix tree and refreshes stale leaves serially, using Gall
entropy to choose a target within each stale prefix. Completion of one
maintenance lookup starts the next overdue leaf; when none remain, the agent
schedules its sole wake for the earliest future deadline. Ordinary lookups also
refresh their target leaf, and split children inherit the parent's timestamp.
Installing seeds into an empty table advances the wake so initial bootstrap
does not wait for the default one-hour interval.
Leaf metadata and live contacts are enumerated with accumulator-based prefix
tree traversals, remaining linear even when splitting produces a deeply skewed
tree.

A full leaf outside the local node's range does not split. New verified contacts
enter its bounded replacement roster and may be promoted after live contacts
fail. Splits are permanent: underfull siblings are not merged. XOR distance is
still used to order lookup candidates; the prefix tree only controls routing
table capacity and coverage.

## Remote-scry constraint

Remote scry is read-only. Gall `+on-peek` is a pure namespace lookup and cannot
mutate the publisher's state or learn the requester's identity. It therefore
serves only as a possible final read after ordinary Ames discovery has supplied
an exact locator. Kademlia record `STORE` and `FIND_RECORDS` are ordinary Ames
messages handled by `%content-routing`; custom retrieval protocols remain
independent of the routing layer.

## Identity domain

Node IDs, lookup keys, and routable Ames identities are 128 bits. This includes
comets, so the Feistel PRP is a bijection over the complete identity domain:
every routable `@p` maps to one node ID and every 128-bit node ID maps back to
one `@p`. `+valid-node` rejects atoms wider than 128 bits. The protocol tweak
and round count are consensus parameters; changing either creates a different
overlay.

`contact.id` is the canonical contact identity. Contacts do not also store a
ship, since that would duplicate information and permit inconsistent pairs.
Decode the node ID with `+node-to-ship` when addressing an Ames peer.

## Building the desk

Install [Mortar](https://github.com/tinnus-napbus/mortar), then assemble the
complete desk from the local sources and pinned `%base-dev` dependencies:

```sh
mortar build
```

The assembled desk is written to `dist/`.  Dependency revisions are pinned in
`mortar.yaml`; update the pin deliberately rather than building against a
moving Urbit branch.

For Aqua, also assemble the runtime-only desk that will be installed in the
virtual ships:

```sh
mortar build --config mortar-pill.yaml
mortar build --config mortar-aqua-base.yaml
mortar build --config mortar-aqua-test.yaml
```

Mount `dist/` as `%kademlia-mortar`, `dist-pill/` as `%kademlia`,
`dist-aqua-base/` as `%kademlia-aqua-base`, and `dist-aqua-test/` as
`%kademlia-test`. The Aqua base is a complete Arvo source desk with a minimal
`/desk/bill`; it omits unrelated background agents whose timers otherwise
dominate a network test. The test-only desk contains the completion observers,
while `%kademlia` contains the wrappers, `%kademlia-example` and
`%kademlia-demo`. Its `/desk/bill` comes from `aqua-pill/` and starts both
agents. The protocol threads drive `%kademlia-example`; the demo thread drives
`%kademlia-demo`.

The Aqua integration coverage is split so each run boots only the fleet it
needs.  `kademlia-network-test` creates three virtual ships and verifies
iterative discovery over the strict route `~bud -> ~dev -> ~wes`:

```hoon
:aqua &pill +pill/solid %kademlia-aqua-base %kademlia %kademlia-test
-kademlia-mortar!kademlia-network-test
```

`content-routing-network-test` creates two ships, publishes a signed mutable
pointer and provider record from `~wes`, then has `~bud` resolve the pointer's
content digest and use it to discover the provider locator:

```hoon
-kademlia-mortar!content-routing-network-test
```

`content-discovery-network-test` advertises a three-segment topic from `~wes`,
then browses every level from `~bud`, checking the automatically generated
parent edges and the exact leaf catalog without host-side polling:

```hoon
-kademlia-mortar!content-discovery-network-test
```

`content-store-network-test` exercises the content-store wrapper across two ships. It
publishes one cask from `~wes` with a provider record, mutable name, and topic
advertisement; `~bud` then retrieves it by digest and name through exact remote
scry and discovers its catalog through the topic API:

```hoon
-kademlia-mortar!content-store-network-test
```

`kademlia-demo-network-test` additionally verifies complete resource retrieval
over both the custom chunk protocol and an exact-revision Ames remote scry,
then advertises and browses a topic through the demo API:

```hoon
-kademlia-mortar!kademlia-demo-network-test
```

The Aqua pill includes both secondary desks. Virtual ships therefore boot with
the wrapped agents and test observers already installed; the threads do not
modify `%base` or copy source files into the ships.
