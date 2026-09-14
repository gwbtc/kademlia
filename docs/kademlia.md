# Kademlia layer

`%kademlia` is the peer-discovery and iterative node-lookup layer. It maintains
a bounded routing table, maps Urbit ships into a 128-bit XOR metric, and finds
the live nodes nearest an arbitrary 128-bit target. It knows nothing about
content, topics, or application records; higher layers use its results to pick
the peers that should store or answer for a key.

## Identity and distance

Every routable `@p`, including 128-bit comets, is mapped bijectively to a
128-bit node ID by a Feistel permutation. The reverse mapping is deterministic,
so contacts store only their canonical node ID. The Feistel round count and
tweak are protocol parameters: the tweak domain-separates this identity scheme,
and changing either parameter creates a different overlay.

Distance is XOR:

```hoon
(con a b)
```

Smaller XOR values are nearer. The metric is symmetric and gives every target
a deterministic ordering of nodes without implying geographic or network
proximity.

## Routing table

The table is a prefix tree over the 128-bit node-ID space. A leaf bucket stores:

```hoon
[ refreshed=@da
  live=[count=@ud items=(list contact)]
  replacements=[count=@ud items=(list contact)]
]
```

Contacts are `[id seen fails]`. Both rosters are ordered newest observation
first; ties prefer fewer failures and then the lower node ID. Counts are cached
and checked as structural invariants.

The live roster holds up to `k` directly verified contacts. The replacement
roster holds up to `replacement-k` verified candidates that can be promoted
when live contacts fail. A node learned indirectly from another peer does not
enter either roster merely because it was mentioned; it becomes a routing
contact only after answering a direct request.

### Splitting

The table begins as one bucket covering the entire ID space. When a successful
new contact reaches a full bucket:

- if the bucket's range contains the local node, it splits on the next
  most-significant ID bit and insertion is retried;
- otherwise the live roster remains unchanged and the contact enters the
  replacement roster.

Only the branch containing the local node can continue splitting. The sibling
at each split remains a leaf. This is standard Kademlia's asymmetric capacity:
the table has fine resolution near the local identity without allocating 128
full buckets in advance. Splits are permanent; underfull siblings are not
merged.

Splitting partitions both rosters in one traversal, preserves their ordering,
and promotes replacements if either child gains spare live capacity.

### Successes and failures

A successful direct interaction resets a contact to zero failures and moves it
to the front according to the current observation time. An existing live
contact is updated without scanning the replacement roster.

A failed request increments the live contact's failure count. Below the
configured threshold it stays live, reordered by the roster comparator. At the
threshold it is evicted; the newest replacement in that bucket is promoted if
one exists. Failures never merge the prefix tree.

## Iterative lookup

A lookup contains a target, a cached in-flight count, and a nearest-first list
of candidates. Candidate states are `%unasked`, `%in-flight`, `%succeeded`, or
`%failed`.

The lookup proceeds as follows:

1. Seed candidates from the routing table in exact XOR-distance order.
2. Dispatch up to `alpha` closest unasked candidates in the active frontier.
3. Send each a `%find-node` Ames request.
4. On `%nodes`, mark the responder successful, record it as a routing contact,
   validate the returned IDs, and merge at most `k` fresh IDs into the ordered
   candidate list.
5. On timeout or poke nack, mark the candidate failed and apply routing-table
   failure policy.
6. Repeat until no request is in flight and no unasked candidate remains in the
   closest nonfailed `k`-candidate frontier.

The result contains up to `k` closest successful nodes. The lookup may retain
more than `k` candidates so farther nodes can replace failed close nodes, but
dispatch and completion consider only the active frontier. Late, duplicate,
wrong-sender, and unsolicited responses do not change the lookup.

Initial candidates are produced by nearest-first traversal of the bucket tree,
sorting only bounded leaf rosters. Incoming `%find-node` requests use the same
prefix-aware traversal and stop after `k` contacts instead of sorting the whole
table.

## Ames protocol and bounds

Peers exchange:

```hoon
[%find-node version id target]
[%nodes version id count packed]
```

The node list is an atom of fixed 128-bit chunks, not an unbounded Hoon list.
Receivers validate its declared count and bit width before decoding, and accept
at most 20 IDs. Request IDs and caller lookup IDs are limited to 64 bits.
Outbound requests remember their lookup, expected peer, send time, and Behn
deadline. Response metadata is matched before payload decoding.

## Bucket refresh

Each leaf records when a lookup was last begun in its range. One global Behn
timer finds the oldest overdue leaf, derives a random target inside its prefix,
and starts a maintenance lookup. Completion advances to the next overdue leaf;
when none is due, the next timer is set to the earliest future deadline.

This avoids one timer per bucket. Ordinary lookups also touch their target
bucket, and split children inherit their parent's timestamp.

## Gall API

Local `%kademlia-command` operations include:

- `%set-seeds` for bootstrap ships;
- `%set-request-timeout` and `%set-refresh-interval`;
- `%find` with a caller-supplied lookup ID;
- `%find-for`, which allocates an ID and delivers a typed callback;
- `%forget`, `%set-verbosity`, and `%reset`.

`%find-for` stores `[recipient reply-path]` against the lookup ID. Completion
uses the exact completed ID for one callback-map lookup, then pokes the target
application with `%kademlia-result`. The reply path is application correlation
data rather than Gall's effect wire.

Diagnostics are exposed under `%gx` at `/summary`, `/settings`, `/table`,
`/seeds`, `/verbosity`, `/delivery`, and `/lookup/<id>`, with `/noun` appended
as the output mark when scrying through Gall. `/delivery` reports current
tracked peers, active per-peer poke gates, queued responses, queued requests,
and cumulative queue expirations. Its `overflow-dropped` field counts responses
discarded after the per-peer queue reaches its limit of 32. Locally
initiated request queues are limited by expiry rather than count.

## Configuration and invariants

The pure library configuration is:

```hoon
[k replacement-k alpha rounds tweak]
```

The production agent uses `[20 20 3 12 %kademlia-urbit-v1]`: 20 live contacts,
20 replacements, three parallel requests, 12 Feistel rounds, and the named
identity-domain tweak. It evicts a live contact on its third failed request.
Validation checks 128-bit identities, roster counts and capacity, uniqueness,
ordering, live/replacement disjointness, contact prefix membership, legal
prefix-tree topology, candidate ordering and uniqueness, and agreement between
the cached and actual in-flight count.

## Source map

- [`desk/sur/kademlia.hoon`](../desk/sur/kademlia.hoon): pure routing types.
- [`desk/lib/kademlia.hoon`](../desk/lib/kademlia.hoon): identity conversion,
  buckets, nearest traversal, lookup transitions, and invariants.
- [`desk/sur/kademlia-agent.hoon`](../desk/sur/kademlia-agent.hoon): Gall
  commands, peer messages, callbacks, and persistent state.
- [`desk/lib/kademlia-agent-logic.hoon`](../desk/lib/kademlia-agent-logic.hoon):
  request scheduling, completions, and refresh policy.
- [`desk/app/kademlia.hoon`](../desk/app/kademlia.hoon): Ames, Behn, Gall,
  diagnostics, and logging.
