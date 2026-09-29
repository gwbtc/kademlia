# Content-store wrapper

`content-store-agent` is the optional application-facing wrapper over
`kademlia-agent`, `content-routing-agent`, and `content-discovery-agent`. It is
useful when an application wants to publish and retrieve ordinary Urbit values
without coordinating the three protocol wrappers itself.

```hoon
/+  kademlia-agent, content-routing-agent, content-discovery-agent
/+  content-store-agent
%-  agent:content-store-agent
%-  agent:content-discovery-agent
%-  agent:content-routing-agent
%-  agent:kademlia-agent
^-  agent:gall
```

The wrapper does not replace the lower APIs. Applications with a custom data
transport, unusual replica policy, or a need to inspect signed records can use
those wrappers directly.

## Content identity and storage

The value accepted by `%put` is a `(cask)`: `[mark noun]`. Its immutable content
ID is the content-routing SHA-256 digest of `jam` over that complete cask. This
commits both the mark and the noun.

The wrapper retains the cask in its state and binds it at a unique spur under
`/content-store` in the wrapped agent's remote-scry namespace. The first `%grow` at that spur is revision 1, so the advertised
locator contains the exact `$spar:ames`, including `/g/x/1/<agent>//1/content-store/...`. A second `%put`
of the same digest reuses the original page instead of creating a second copy.

`%get` recomputes the digest after remote retrieval before returning or caching
the value. It also enforces `max-content-bytes` before accepting the result.

## Operations

Commands use caller-selected 64-bit IDs:

```hoon
$%  [%put id value=(cask) options=publication-options lifetime=(unit @dr)]
    [%pin id content=digest lifetime=(unit @dr)]
    [%unpin id content=digest]
    [%get id query=content-store-query]
    [%search id topic=topic-path]
    [%observe id recipient=@tas reply-path=/]
    [%forget id]
    [%set-config value=content-store-config]
    [%set-verbosity level=?(%off %info %debug)]
==
```

`%put` always publishes a provider record for the remote-scry page. Its options
may additionally publish:

- a mutable, publisher-scoped name through a pointer record; and
- a catalog advertisement at a hierarchical topic.

A named publication supplies a revision policy rather than a caller-managed
revision by default:

```hoon
[ namespace=@tas
  name=path
  revision=name-revision-policy
  lifetime=(unit @dr)
]

$%  [%auto ~]
    [%set value=@ud]
    [%cas expected=@ud value=@ud]
==
```

The operation completes only after every requested lower-layer publication has
completed. Its result includes the digest, locator, and the provider, pointer,
allocated pointer revision, exact pointer expiry, and topic publication
reports. A publication with no accepting replica becomes a typed failure.

Provider revisions are maintained per digest and increment on each repeated
`%put`, avoiding same-revision conflicts when a locator is renewed. `lifetime`
selects the signed expiry of the provider record and any topic advertisement.
Use `~` to use the configured `publication-lifetime`, or supply a positive
`@dr` override such as `` `~d7 ``. There is no protocol-imposed maximum. A zero
override is rejected as `%invalid`. Named-pointer expiry is independent of this
lease and is selected separately in the named-publication options below.

Mutable-name revisions are maintained persistently per `[namespace name]`.
The normal publication option uses `[%auto ~]`, which atomically allocates one
more than the local counter when `%put` is accepted. Concurrent local puts
therefore cannot reuse a revision. Failed replication may leave a harmless gap
in the sequence.

For imports and recovery, `[%set revision]` publishes an explicit revision and
advances the stored counter when that revision is greater. It deliberately
permits an older or equal revision, which may be ignored by readers or create a
same-revision conflict; callers using it own that risk. `[%cas expected value]`
requires the stored counter to equal `expected` and `value` to be greater. A
mismatch returns `%revision-conflict` without starting the publication. The
selected revision is returned as `pointer-revision` in the `%put` result.

`named-publication.lifetime` controls the pointer independently of the `%put`
lifetime used by provider and topic records. `~` expresses permanent publisher
intent and produces a signed pointer with `expires=~`. A positive relative
duration such as `` `~d7 `` is converted to an exact signed expiry when the
operation is accepted. Zero is rejected as `%invalid`; there is currently no
protocol-level maximum. The exact expiry is returned as `pointer-expires` in
the `%put` result.

The wrapper does not schedule automatic renewal: an application which needs a
continuously advertised value must repeat `%put` before its chosen expiry. A
replica will retain the signed record only while its own lease policy and that
expiry permit, so abandoned publications eventually disappear from discovery.
The retained remote-scry page itself remains available independently of record
discovery.

`%pin` preserves and advertises immutable content without creating a mutable
pointer or topic advertisement. It uses an already cached cask when possible;
otherwise it performs provider discovery, retrieves the cask, verifies its
digest, publishes a local remote-scry page, and announces this ship as a new
provider. Repeating `%pin` reuses the page and increments the provider revision.
Its lifetime follows `%put`: `~` selects `publication-lifetime.config`, a
positive duration overrides it, and zero is `%invalid`. The successful result
contains the resolved absolute `expires=@da` and a `fetched` flag indicating
whether network retrieval was required.

`%unpin` clears local retention intent. It does not send a network withdrawal,
delete the cached cask, or remove an exact remote-scry revision; the last signed
provider record expires naturally. Automatic renewal and cache eviction are
not currently performed, so a client that wants continuous discoverability
must repeat `%pin` before expiry.

`%get` accepts either an immutable digest or a mutable name:

```hoon
[%content digest]
[%name publisher=@p namespace=@tas name=path]
```

For example, `[%name ~sampel-palnet %releases /packages/kademlia/latest]`
addresses a readable hierarchical name. Its path segments can be appended
directly to an HTTP or scry path when an application exposes a textual API;
content-routing hashes the canonical Hoon path internally for Kademlia lookup.
Names must contain one to sixteen nonempty segments, each at most 64 bytes.

A name query first selects its signed pointer. A `%content` target then performs
a provider query; a verifiable `%direct` target may proceed immediately. The
wrapper currently retrieves only `%scry` locators. `%custom` locators are left to
applications using `content-routing-agent` directly.

`%search` delegates a hierarchical browse to `content-discovery-agent` and returns
the selected catalogs and immediate child topics. It does not fetch or decode
catalog bodies.

## Callback pattern

The wrapped agent sends commands by poking itself with the
`%content-store-command` mark. Register `%observe` before starting the
operation. Completion is delivered to the selected local agent with mark
`%content-store-result`. When the recipient is the wrapped agent's own name,
the wrapper calls its `+on-poke` directly, with `src.bowl` set to our ship:

```hoon
[%observe 0v7 %my-app /request/0v7]
[%get 0v7 [%content digest]]
```

The notice is:

```hoon
[reply-path=/request/0v7 result=content-store-result]
```

`reply-path` is application correlation data, not a Gall effect wire. It must
not start with `/~`. The wrapper stores only one callback per operation ID and targets it directly at
completion. The lower content-routing and discovery IDs are encoded in their
callback paths, so no second correlation map is needed.

[`desk/lib/content-store-client.hoon`](../desk/lib/content-store-client.hoon)
provides command constructors and `+start`, which returns the observe poke
before the operation poke.

Completed results remain readable until `%forget`. A late `%observe` therefore
receives the retained result immediately.

## Scries

The Gall `%gx` namespace exposes:

```text
/x/~/content-store/settings/noun
/x/~/content-store/verbosity/noun
/x/~/content-store/operation/<id>/noun
/x/~/content-store/publications/noun
/x/~/content-store/provider/<digest>/noun
/x/~/content-store/pins/noun
/x/~/content-store/publication/<digest>/noun
/x/~/content-store/content/<digest>/<value-mark>
/x/~/content-store/cask/<digest>/noun
/x/~/content-store/names/noun
/x/~/content-store/name/<publisher>/<namespace>/<name...>/noun
```

`/operation/<id>` returns either `%running` or `%complete`. Content uses its
original mark rather than `%noun`, allowing a caller to request the typed page.
The advertised remote path is the corresponding revision-qualified `%gx` path.

`/publications` returns the local map of successful provider publications;
`/provider/<digest>` returns one entry, and `/pins` returns the set of
digests whose pin intent is active. Each publication records its resolved
locator, provider revision, exact expiry, accepted publication result, and
whether it was pinned or originated through `%put`. These are local management
views, not live queries of the DHT. The older `/publication/<digest>` view
continues to return the local remote-scry page descriptor.

`/cask/<digest>` returns the whole `(cask)` as a noun, for a reader that lacks
the value's mark.

`/name/<publisher>/<namespace>/<name...>` returns the digest that name last
settled on here. Our own name settles when `%put` is accepted, before its
records replicate, so a second `%put` can read the first. Another publisher's
name settles when a `%get` of it completes. `/names` returns the whole index. With `/content`,
it lets an agent read the latest value it has fetched for a name without
keeping its own copy. The index is local and may trail the network.

## Failure and consistency model

The wrapper reports typed failures for invalid or oversized input, unresolved or
conflicting names, absent providers, unsupported locators, empty or oversized
remote scries, digest mismatches, timeouts, and failed lower publications.

Publication spans several layers and is not an atomic transaction. The
remote-scry `%grow` card is emitted before the provider publication starts, so
a successfully advertised locator refers to a page this agent has already
asked Gall to publish. Commands for the layers below run in the same event; a
crash in one fails the operation with `%dependency-failed`. A later lower-layer failure leaves the local page intact
and returns a failed operation; retrying `%put` reuses the page.

## Configuration and ownership

The defaults are:

```hoon
[request-timeout=~s30 publication-lifetime=~d1 max-content-bytes=8.388.608]
```

The timeout covers final remote scry. Routing and discovery operations retain
their own bounded concurrency and timeout settings. The wrapper owns the
published casks and its operations; the lower wrappers continue to own their
routing tables, signed origins and replicas, protocol queues, and topic index.

Applications still configure bootstrap seeds with `%kademlia-command`. They do
not normally need the other two protocol wrappers' commands when using this
one.
