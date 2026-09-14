# Content routing layer

`%content-routing` is a signed record-discovery protocol layered above
Kademlia. It maps mutable names and immutable content digests to retrieval
information. It never transports application payloads: it returns signed
pointers and provider locators, after which the application performs the
actual fetch.

Typical resolution paths are:

```text
stable name -> signed pointer -> direct locator -> fetch
stable name -> signed pointer -> digest -> provider records -> locator -> fetch
digest -> provider records -> locator -> fetch
```

## Immutable content

A content digest is SHA-256 over `jam` of a complete `(cask)`:

```hoon
(shax (jam value))
```

Because a cask includes both mark and noun, the digest commits to the data and
its declared type. `+verify-cask` recomputes this commitment after retrieval.
The routing layer remains agnostic about the application's mold.

## Locators and targets

A locator tells an application how it may retrieve content:

```hoon
$%  [%scry spar=spar:ames]
    [%custom protocol=@tas address=*]
==
```

An `%scry` locator must be an exact Ames remote-scry address, including the
actual Gall revision. Discovery cannot guess that revision. `%custom` permits
an application-defined protocol and opaque address, such as the demo's bounded
chunk transport.

A pointer target is either:

- `[%content digest]`, requiring a provider lookup; or
- `[%direct digest=(unit digest) locations]`, supplying locators immediately
  and optionally committing to the retrieved content.

Locator presence is not proof that retrieval will succeed. Applications choose
supported protocols, try providers, enforce their own size/time limits, and
verify a supplied digest.

## Pointer records

A pointer gives a publisher-scoped mutable name a current target:

```hoon
$:  namespace=@tas
    key=key
    publisher=node-id
    revision=@ud
    expires=(unit @da)
    target=target
==
```

Its 128-bit Kademlia key is derived from namespace, publisher, and the opaque
name noun:

```hoon
(end 7 (shax (jam [%kad-content-pointer-key-v1 namespace publisher name])))
```

Including the publisher means two identities can use the same namespace and
name without collision. The name is not placed in the record; callers who know
it derive the same key. Pointer expiry is optional, allowing either permanent
or time-bounded mutable names.

Pointers are signed over a domain-separated digest. Selection authenticates
the expected namespace, key, publisher, freshness, and signature. The greatest
revision wins. Different bodies signed by that publisher at the greatest
revision produce `%conflict`; no target is selected.

## Provider records

A provider announces retrieval locations for immutable content:

```hoon
$:  content=digest
    provider=node-id
    revision=@ud
    expires=@da
    locations=(list locator)
==
```

The provider lookup key is:

```hoon
(end 7 (shax (jam [%kad-content-provider-key-v1 content])))
```

Provider expiry is mandatory because availability is temporary. Selection
keeps the greatest fresh revision independently for each provider. If one
provider signs different bodies at its greatest revision, that provider is
reported as conflicting and excluded; other valid providers remain usable.

The publisher of a pointer and the providers of its target need not be the
same identities. This separates naming authority from hosting and supports
replication.

## Signatures and admission

Record signatures contain an Ames key life and signature value. Local bodies
are completed with the ship's canonical node ID and signed through Jael.
Replicas recover the signer ship from the node ID, obtain the public key for
the stated life, and verify a type-specific domain-separated message.

Before admission, the agent checks context, bit widths, expiry, encoded byte
size, signature, revision policy, per-key provider limits, and store capacity.
Network records are authenticated once during admission. Final selection only
rechecks time-dependent expiry and revision/conflict rules.

## Publication flow

Applications publish with `%publish-pointer` or `%publish-provider`. The agent:

1. validates and signs the local record;
2. stores it as an origin for refresh;
3. asks `%kademlia` for nodes nearest the derived record key;
4. sends bounded `%store` requests under a fair global scheduler; and
5. reports accepted, rejected, and timed-out replicas.

Publication completes after every selected replica is accounted for. Origins
are refreshed every 12 hours by default, in bounded batches. Replicas use
one-day local leases in addition to signed record expiry.

## Query flow

`%find-pointer` derives the name key; `%find-providers` derives the content key.
Both first perform a Kademlia node lookup, then send `%find-records` to nearby
peers. Responses are authenticated, deduplicated, and accumulated before
pointer or provider selection.

Operations share a persistent round-robin queue. By default each operation has
three concurrent requests and the agent permits twelve globally, preventing a
single query from monopolizing the Ames request budget.

The result includes selected records plus responder and timeout sets. Query
completion does not fetch content and does not assert that a returned locator
is currently reachable.

## Ames protocol and resource limits

Peers exchange:

```hoon
[%store version id payload]
[%stored version id status]
[%find-records version id request]
[%records version id count payload]
```

Records travel as jammed atoms. Receivers validate request metadata and sender
before decoding, check atom size before `cue`, and bound record count and total
response bytes. Malformed matching responses fail their pending request;
unsolicited, late, duplicate, and wrong-sender responses are discarded without
payload work.

Defaults include 20 replicas, three requests per operation, twelve globally, a
five-minute timeout, 64 KiB per record, 64 provider identities per content key,
and 10,000 replica keys. Responses contain at most 64 records and 256 KiB. The
store caches its key count, prunes accessed keys normally, and performs a full
prune plus deterministic earliest-expiry eviction only under capacity pressure.

## Gall API

Local commands are `%publish-pointer`, `%publish-provider`, `%find-pointer`,
`%find-providers`, `%observe`, `%forget`, `%set-config`, `%set-verbosity`, and
`%reset`.

Applications associate a 64-bit operation ID with `[recipient reply-path]` by
using `%observe`. Completion targets that callback directly with a typed
`%content-routing-result`. The reply path is application correlation data, not
Gall's effect wire. Results can also be read under `%gx` at
`/operation/<id>`, `/records/<key>`, `/pointer/<key>`, and
`/providers/<digest>`, appending `/noun` as the requested mark. `/delivery`
reports current tracked peers, active per-peer poke gates, queued responses,
queued requests, cumulative queue expirations, and the reserved
`overflow-dropped` counter.

## Relationship to topic discovery

`%content-discovery` catalog records contain a content digest but not the
catalog bytes. An application browses a topic, filters catalog formats and
publishers, then asks content routing for providers of the chosen digest. A
catalog may itself contain digests for independently routed resources.

This composition preserves referential transparency where desired while still
supporting mutable names through pointer records.

## Source map

- [`desk/sur/content-routing.hoon`](../desk/sur/content-routing.hoon): digests,
  locators, pointers, providers, and selections.
- [`desk/lib/content-routing.hoon`](../desk/lib/content-routing.hoon): key and
  digest derivation, validation, signatures, and conflict selection.
- [`desk/sur/content-routing-agent.hoon`](../desk/sur/content-routing-agent.hoon):
  commands, peer protocol, operations, limits, and state.
- [`desk/lib/content-routing-agent-logic.hoon`](../desk/lib/content-routing-agent-logic.hoon):
  storage, scheduling, refresh, publication, and queries.
- [`desk/app/content-routing.hoon`](../desk/app/content-routing.hoon): Gall,
  Kademlia callbacks, Ames, Behn, Jael, scries, and logging.
