# Kademlia for Urbit

This desk contains the first, deliberately pure layer of a Kademlia-style
overlay for Urbit:

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
- `app/kademlia.hoon`: a headless Gall agent that runs iterative `FIND_NODE`
  lookups over ordinary Ames pokes, with its pure transitions in
  `lib/kademlia-agent-logic.hoon`.
- `tests/lib/kademlia.hoon`: unit coverage for the core invariants.
- `tests/lib/content-routing.hoon`: unit coverage for content-routing records,
  validation, revision conflicts, and provider selection.

## Discovery and data transport

Kademlia discovery and data retrieval are separate protocols. Iterative node
lookup and value-location lookup use ordinary Ames messages. A value lookup
returns signed content-routing records rather than application data. Those
records provide either explicit retrieval locators or a digest used for a
second provider lookup.

An exact `$spar:ames` is one supported locator. Its path includes the actual
Gall revision in `/g/x/<revision>/...`; callers must not assume or synthesize
that revision. HTTP and application-defined custom locators are also supported.
The ordinary Ames discovery protocol will be defined with the Gall agent, where
message correlation and network authentication belong.

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
completed result. Commands are accepted only from the local ship. Read-only
diagnostics are available through `/summary`, `/settings`, `/table`, `/seeds`,
and `/lookup/<id>` Gall scries using the `%noun` output mark. For example:

```hoon
.^(* %gx /=kademlia=/summary/noun)
.^(* %gx /=kademlia=/lookup/0v1/noun)
```

The agent currently implements peer discovery only.  Pointer and provider
record transport, publication, and signing remain separate future milestones.

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
serves only as the final read after ordinary Ames discovery has supplied an
exact locator. Kademlia's remote `STORE` RPC would require a separate write
transport and is intentionally outside this design.

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
```

Mount `dist/` as `%kademlia-mortar` on the host ship and `dist-pill/` as
`%kademlia`.  Keeping the Aqua test harness out of `%kademlia` also keeps its
`/sys/vane/ames` source out of the secondary desk used by `+pill/solid`.

The `kademlia-network-test` Aqua thread is the end-to-end integration test.  It
creates four virtual ships and verifies iterative discovery over the strict
route `~bud -> ~dev -> ~marbud -> ~mardev`:

```hoon
:aqua &pill +pill/solid %base %kademlia
-kademlia-mortar!kademlia-network-test
```

The Aqua pill includes the runtime `%kademlia` desk as a secondary desk.  The
virtual ships therefore boot with the agent already installed; the thread does
not modify `%base` or copy source files into the ships.
