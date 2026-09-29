# Content discovery

`content-discovery-agent` is a signed, decentralized topic index, shipped as an
agent wrapper. Stack it above `kademlia-agent`. It composes with
`content-routing-agent`. It answers
questions such as:

> Which publishers advertise catalogs at `/software/urbit/hoon`, and which
> immediate subtopics exist below `/software/urbit`?

It does not define catalog schemas or transfer catalog payloads. Discovery
returns authenticated metadata containing content digests. Applications fetch
those digests through content routing and interpret the bytes according to the
advertised catalog format.

The three layers have separate jobs:

1. `%kademlia` finds nodes near a 128-bit key.
2. `%content-discovery` finds signed topic records stored near that key.
3. `%content-routing` finds providers or exact locators for immutable content.

## Topics and keys

A topic is a nonempty list of `%tas` segments. For example,
`~[%software %urbit %hoon]` is displayed as `/software/urbit/hoon`. A topic is
limited to eight segments and 64 bytes per segment.

Every exact topic derives the same 128-bit Kademlia key on every node:

```hoon
(end 7 (shax (jam [%kad-content-topic-key-v1 topic])))
```

The domain tag separates topic keys from other hashes in the system.

## Catalog records and formats

A signed catalog body contains:

```hoon
$:  topic=topic-path
    key=key
    publisher=node-id
    revision=@ud
    expires=@da
    catalog=[format=@tas digest=digest entries=@ud]
==
```

- `topic` is the exact advertised path.
- `key` must equal the key derived from that path.
- `publisher` is the canonical 128-bit identity of the signer.
- `revision` orders this publisher's versions.
- `expires` limits the lifetime of the claim.
- `format` tells an application how to decode the catalog payload.
- `digest` content-addresses the payload.
- `entries` is publisher-supplied informational metadata.

Discovery treats the payload as opaque. `%package-index-v1` and
`%documentation-feed-v2` can coexist at one topic even though discovery knows
nothing about either schema. A client filters for supported formats, retrieves
the digest from any provider, verifies it, and applies its format-specific
decoder.

Formats should normally be application-specific and versioned. An incompatible
encoding or semantic change should get a new tag. `entries` is only a hint:
the application must validate the decoded payload and any metadata it relies
on.

## Publishers and decentralization

The publisher identifies who made the claim. Records are signed with the
publisher ship's current Ames key. A replica converts the node ID back to its
ship, obtains the stated life and public key from Jael, and verifies a
domain-separated digest of the record body.

Authentication proves authorship and integrity, not trustworthiness.
Applications may show everyone, use allowlists, merge catalogs, rank
publishers, require agreement, or let users select publishers.

No aggregator is required. Independent identities can publish under the same
topic:

```text
/software/urbit/hoon
  ~nec  -> %package-index-v1, revision 7, digest A
  ~bud  -> %package-index-v1, revision 3, digest B
  ~wes  -> %documentation-v1, revision 2, digest C
```

Revisions are scoped to a publisher and record identity. One publisher's
revision 7 does not supersede another's revision 3. The publisher also need not
host the bytes: content routing may find replicas operated by other providers.
Authorship is separate from storage and transport.

## Automatic parent edges

Kademlia supports exact-key lookup and cannot infer children from a parent key.
An advertisement therefore creates a signed edge at every nonempty strict
prefix. Advertising `/software/urbit/hoon` creates:

```text
/software               -> child %urbit, source /software/urbit/hoon
/software/urbit         -> child %hoon,  source /software/urbit/hoon
/software/urbit/hoon    -> catalog record
```

There is no global empty-root edge; an application must know at least a
relevant first segment.

An edge contains its parent, immediate child, full source topic, publisher,
revision, expiry, and catalog reference. The source keeps independently
advertised descendants distinct: one publisher can advertise both
`/software/urbit/hoon` and `/software/urbit/runtime`. Edge and catalog bodies
use different signature domain tags.

## Advertisement flow

The local command is:

```hoon
[%advertise id topic format catalog entries revision expires]
```

The agent validates the request, constructs and signs the leaf and all edges,
stores them as local origins, and replicates each record to nodes nearest its
topic key. Advertisement is a batch operation: its public ID completes only
after every generated record finishes its bounded replication attempts. The
result reports accepted, rejected, and timed-out peers per record.

Origins are periodically republished while valid. The default refresh interval
is 12 hours, processed in bounded batches rather than one timer per record.

## Browse flow

The local command is:

```hoon
[%browse id topic]
```

The agent derives the topic key, finds nearby Kademlia contacts, and sends
ordinary Ames `%find-topic` requests. It size-checks, context-checks,
cryptographically verifies, and deduplicates returned records before selection.

Browsing is exact. Browsing `/software/urbit` returns catalogs published
exactly there plus authenticated immediate children stored as edges there. It
does not recursively crawl descendants; an application descends by browsing a
returned child path.

The result contains:

```hoon
$:  topic=topic-path
    selection=[catalogs=(list catalog-record)
               children=(list [name=@tas supporters=(set node-id)])
               conflicts=(set record-identity)]
    responders=(set node-id)
    timed-out=(set node-id)
==
```

A child's supporters are authenticated publishers whose selected edges claim
that child. This is evidence of signed claims, not a global vote or trust score.

## Revisions and conflicts

Selection is independent for each identity:

- a catalog identity is `[%catalog publisher]`;
- an edge identity is `[%edge publisher source]`.

Expired records are ignored and the greatest revision wins. If different
records exist at the greatest revision, that identity is reported as a
conflict and contributes neither a selected catalog nor child. This represents
one publisher signing incompatible versions of the same logical record.
Different publishers advertising different catalogs is normal, not a conflict.

## Storage and limits

Peers retain accepted records as leased replicas. Signed expiry limits the
claim; the local lease controls retention without refresh. Reads and stores
prune the accessed key, while capacity pressure can trigger a complete prune
and deterministic eviction.

Defaults are 20 replicas, three requests per operation, 12 globally, a
five-minute timeout, one-day leases, 12-hour refresh, eight refreshes per batch,
64 KiB per record, 64 records per key, eight records per publisher per key, and
10,000 replica keys.

Discovery is intentionally not an unbounded database query. A very populous
topic may not expose every publisher in one response. Large deployments may
need narrower topic partitions, application pagination or secondary indexes,
or a future selection protocol.

## Gall API

The local commands are `%advertise`, `%browse`, `%observe`, `%forget`,
`%set-config`, `%set-verbosity`, and `%reset`.

An application allocates a 64-bit operation ID, sends `%observe` with its app
and reply path before starting `%advertise` or `%browse`. On completion,
the wrapper pokes it with `%content-discovery-result`; when the recipient is
the wrapped agent, the wrapper calls its `+on-poke` directly. The reply path
is application data, not Gall's effect wire; it must not start with `/~`. Completed results remain readable
until `%forget` removes them. Results and stored records can also be read under
`%gx` below `/~/content-discovery` at `/operation/<id>` and `/records/<key>`, appending `/noun` as the
requested mark. Configuration and delivery state are exposed at `/settings`,
`/verbosity`, and `/delivery`. The delivery summary reports current tracked
peers, active per-peer poke gates, queued responses, queued requests, cumulative
queue expirations, and the `overflow-dropped` counter. At most 32 live
peer-triggered responses are queued per peer in this agent, in addition to one
active poke. Excess responses are silently discarded, leaving the requester to
time out. Locally initiated requests remain count-unbounded and expire at the
same configured request deadline.

The peer protocol uses `%store`, `%stored`, `%find-topic`, and `%topic-records`
over Ames. Packed payloads have explicit atom-size and record-count bounds.

## Retrieving a catalog

A browse returns references, not bytes. For a supported record, an application:

1. applies its publisher and format policy;
2. asks `%content-routing` for providers of the digest;
3. retrieves through a compatible locator or application transport;
4. verifies the complete content digest; and
5. decodes and validates the advertised format.

A catalog can contain further content digests, producing a compact index of
independently replicated immutable resources. Content-routing pointers can be
used where an application wants mutable names instead.

The optional `content-store-agent` wrapper wraps browsing as `%search` and can
publish a cask, its provider record, and a topic advertisement as one observed
operation. It deliberately returns browse records without interpreting or
recursively fetching catalog bodies. See
[`docs/content-store.md`](content-store.md).

## Demo and source map

Kademlia Lab in [`demo/`](../demo/) can publish a resource, advertise its digest
under a topic, browse parent and leaf topics from another ship, inspect
catalogs and child supporters, and fetch a discovered catalog. The Aqua threads
`/ted/kademlia-demo-network-test` and `/ted/content-discovery-network-test`
exercise the application and lower-level flows respectively.

Implementation files:

- [`desk/sur/content-discovery.hoon`](../desk/sur/content-discovery.hoon): data
  model.
- [`desk/lib/content-discovery.hoon`](../desk/lib/content-discovery.hoon): keys,
  validation, edge generation, signatures, and selection.
- [`desk/sur/content-discovery-agent.hoon`](../desk/sur/content-discovery-agent.hoon):
  protocol, commands, operations, configuration, and state.
- [`desk/lib/content-discovery-agent-logic.hoon`](../desk/lib/content-discovery-agent-logic.hoon):
  replication, storage, scheduling, refresh, and results.
- [`desk/sur/bounded-poke.hoon`](../desk/sur/bounded-poke.hoon) and
  [`desk/lib/bounded-poke.hoon`](../desk/lib/bounded-poke.hoon): shared
  persistent per-peer delivery gating, expiry, and response limits.
- [`desk/lib/content-discovery-agent.hoon`](../desk/lib/content-discovery-agent.hoon):
  the agent wrapper: Gall, Ames, Behn, callbacks, and logging.
- [`desk/lib/record-crypto.hoon`](../desk/lib/record-crypto.hoon): Jael-backed
  signing and verification.
