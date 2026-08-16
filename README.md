# Kademlia for Urbit

This desk contains a Kademlia-style overlay for Urbit, including pure routing
libraries and two headless Gall agents:

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
  `app/content-routing.hoon`: the ordinary-Ames record transport, leased replica
  store, publication/query state machine, Jael-backed signatures, and Gall
  interface layered over node lookup.
- `app/kademlia.hoon`: a headless Gall agent that runs iterative `FIND_NODE`
  lookups over ordinary Ames pokes, with its pure transitions in
  `lib/kademlia-agent-logic.hoon`.
- `tests/lib/kademlia.hoon`: unit coverage for the core invariants.
- `tests/lib/content-routing.hoon`: unit coverage for content-routing records,
  validation, revision conflicts, and provider selection.
- `tests/lib/content-routing-agent-logic.hoon` and
  `tests/app/content-routing.hoon`: transport storage, operation, refresh,
  concurrency, callback, and Gall-interface coverage.

## Discovery and data transport

Kademlia discovery and data retrieval are separate protocols. Iterative node
lookup and value-location lookup use ordinary Ames messages. A value lookup
returns signed content-routing records rather than application data. Those
records provide either explicit retrieval locators or a digest used for a
second provider lookup.

An exact `$spar:ames` is one supported locator. Its path includes the actual
Gall revision in `/g/x/<revision>/...`; callers must not assume or synthesize
that revision. HTTP and application-defined custom locators are also supported.
The `%content-routing` agent transports those records over ordinary Ames pokes;
remote scry remains one possible final retrieval mechanism, not a requirement.

## Content routing

Content routing is layered above the generic node lookup.  A mutable application
name derives a 128-bit pointer key from its namespace, publisher node ID, and an
opaque name noun.  A valid signed pointer selects either a `%direct` list of
retrieval locators or a `%content` digest whose current providers must be found
under a second derived Kademlia key:

```text
stable name -> signed pointer -> direct locator -> fetch
stable name -> signed pointer -> digest -> provider lookup -> locator -> fetch
```

A content digest is SHA-256 of `jam` over the complete `(cask)`, so both its mark
and noun are committed.  After retrieval, `+verify-cask` checks the result
without interpreting application data.  Locators may be exact remote-scry
`$spar:ames` values, HTTP URLs, or application-defined `%custom` addresses.
Routing records never embed content themselves.

Pointers have monotonically increasing revisions and optional expiry.  Provider
announcements have revisions and mandatory expiry.  Signature checking is
supplied to the pure library as a gate; access to Urbit identity keys remains an
agent responsibility.  Different signed bodies from one identity at the same
greatest revision are treated as equivocation.  A pointer conflict fails the
selection, while a conflicting provider is excluded without hiding other valid
providers.

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

## Peer-discovery agent

The `%kademlia` agent implements the first ordinary-Ames protocol milestone.
Peers exchange typed `%kademlia-message` pokes containing versioned
`%find-node` requests and `%nodes` responses.  Each outbound peer request has a
unique request ID, a configurable Behn timeout (five minutes by default), and
an expected sender identity. Successful responses and poke nacks cancel their
timers; timeout wakes consume the timer normally. Late, duplicate, unsolicited,
and wrong-sender responses are ignored.

Local `%kademlia-command` pokes can replace bootstrap ships, set the request
timeout with `%set-request-timeout`, start a caller-ID'd lookup, and forget a
completed result. `%find-for` is the internal callback form: it allocates a
lookup ID and pokes a typed `%kademlia-result` notice to the requesting local
agent when lookup completes. Commands are accepted only from the local ship. Read-only
diagnostics are available through `/summary`, `/settings`, `/table`, `/seeds`,
and `/lookup/<id>` Gall scries using the `%noun` output mark. For example:

```hoon
.^(* %gx /=kademlia=/summary/noun)
.^(* %gx /=kademlia=/lookup/0v1/noun)
```

## Content-record transport agent

The separate `%content-routing` agent keeps Kademlia itself agnostic about
application data. Local `%content-routing-command` pokes publish signed pointer
or provider records, start pointer/provider queries, forget completed operation
results, or update transport limits. The agent asks `%kademlia` for the closest
nodes through its callback API, then sends versioned `%content-routing-message`
store/query RPCs to at most three peers concurrently. Each RPC has a five-minute
Behn timeout. Publication completes only after every selected replica has been
accounted for as accepted, rejected, or timed out.

Unsigned local publication bodies are completed with the local 128-bit node ID
and signed using the ship's current Jael Ames key. Receiving replicas resolve
the signer's node ID back to a ship, obtain the public key for the stated life
from Jael, and verify the domain-separated record digest. Replica leases last
24 hours; locally originated records are republished every 12 hours. Defaults
also limit records to 64 KiB, provider identities to 64 per content key, and
the replica store to 10,000 keys with deterministic earliest-expiry eviction.

Operation results are exposed at `/operation/<id>`. Stored records can be read
at `/records/<key>`, pointer records at `/pointer/<key>`, and provider records at
`/providers/<digest>`, all under the agent's `%gx` namespace with `%noun` output.
The transport returns records and locators only—it does not fetch final content.

## Routing buckets

A routing table starts as one empty leaf created by `+empty-table`. Leaves
partition the 128-bit node-ID space by most-significant-bit prefixes. When a
newly verified contact reaches a full leaf whose range contains the local node,
that leaf splits and its contacts are redistributed by the next prefix bit.
Splitting repeats down the local node's branch when necessary.

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
messages handled by `%content-routing`; HTTP and custom retrieval locators work
the same way at the routing layer.

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

Mount `dist/` as `%kademlia-mortar`, `dist-pill/` as `%kademlia`, and
`dist-aqua-base/` as `%kademlia-aqua-base`, and `dist-aqua-test/` as
`%kademlia-test`. The Aqua base is a complete Arvo source desk with a minimal
`/desk/bill`; it omits unrelated background agents whose timers otherwise
dominate a network test. The test-only desk contains the completion observer,
while `%kademlia` contains only the production agents.

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

The Aqua pill includes both secondary desks. Virtual ships therefore boot with
the production agents and test observer already installed; the threads do not
modify `%base` or copy source files into the ships.
