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
- `tests/lib/kademlia.hoon`: unit coverage for the core invariants.

## Discovery and data transport

Kademlia discovery and data retrieval are separate protocols. Iterative node
lookup and value-location lookup use ordinary Ames messages. When a lookup
finds published data, its discovery result carries the publisher's exact
`$spar:ames`: `[ship path]`. The path includes the actual Gall revision in
`/g/x/<revision>/...`; callers must not assume or synthesize that revision.

The exact `$spar` can then be used for a remote scry. The fetched noun is
publisher-owned application data and remains opaque to Kademlia: the overlay
does not define its mold, revision scheme, expiry policy, or interpretation.
The ordinary Ames discovery message protocol and its `$spar` result will be
defined with the Gall agent, where message correlation and authentication also
belong.

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
