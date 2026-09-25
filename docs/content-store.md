# Unified content-store façade

`%content-store` is the optional application-facing layer over `%kademlia`,
`%content-routing`, and `%content-discovery`. It is useful when an application
wants to publish and retrieve ordinary Urbit values without coordinating the
three protocol agents itself.

The façade does not replace the lower APIs. Applications with a custom data
transport, unusual replica policy, or a need to inspect signed records can use
those agents directly.

## Content identity and storage

The value accepted by `%put` is a `(cask)`: `[mark noun]`. Its immutable content
ID is the content-routing SHA-256 digest of `jam` over that complete cask. This
commits both the mark and the noun.

The façade retains the cask in its Gall state and publishes it at a unique
remote-scry spur. The first `%grow` at that spur is revision 1, so the advertised
locator contains the exact `$spar:ames`, including `/g/x/1/...`. A second `%put`
of the same digest reuses the original page instead of creating a second copy.

`%get` recomputes the digest after remote retrieval before returning or caching
the value. It also enforces `max-content-bytes` before accepting the result.

## Operations

Commands use caller-selected 64-bit IDs:

```hoon
$%  [%put id value=(cask) options=publication-options lifetime=(unit @dr)]
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

The operation completes only after every requested lower-layer publication has
completed. Its result includes the digest, locator, and the provider, pointer,
and topic publication reports. A publication with no accepting replica becomes
a typed failure.

Provider revisions are maintained per digest and increment on each repeated
`%put`, avoiding same-revision conflicts when a locator is renewed. `lifetime`
selects the signed expiry of the provider record and any topic advertisement.
Use `~` to use the configured `publication-lifetime`, or supply a positive
`@dr` override such as `` `~d7 ``. There is no protocol-imposed maximum. A zero
override is rejected as `%invalid`. Named pointers remain non-expiring and are
independent of this lease.

The façade does not schedule automatic renewal: an application which needs a
continuously advertised value must repeat `%put` before its chosen expiry. A
replica will retain the signed record only while its own lease policy and that
expiry permit, so abandoned publications eventually disappear from discovery.
The retained remote-scry page itself remains available independently of record
discovery.

`%get` accepts either an immutable digest or a mutable name:

```hoon
[%content digest]
[%name publisher=@p namespace=@tas name=path]
```

For example, `[%name ~sampel-palnet %releases /packages/kademlia/latest]`
addresses a readable hierarchical name. Its path segments can be appended
directly to an HTTP or scry path when an application exposes a textual API;
content-routing hashes the canonical Hoon path internally for Kademlia lookup.

A name query first selects its signed pointer. A `%content` target then performs
a provider query; a verifiable `%direct` target may proceed immediately. The
façade currently retrieves only `%scry` locators. `%custom` locators are left to
applications using `%content-routing` directly.

`%search` delegates a hierarchical browse to `%content-discovery` and returns
the selected catalogs and immediate child topics. It does not fetch or decode
catalog bodies.

## Callback pattern

Register `%observe` before starting the operation. Completion is delivered to
the selected local agent with mark `%content-store-result`:

```hoon
[%observe 0v7 %my-app /request/0v7]
[%get 0v7 [%content digest]]
```

The notice is:

```hoon
[reply-path=/request/0v7 result=content-store-result]
```

`reply-path` is application correlation data, not a Gall effect wire. The
facade stores only one callback per operation ID and targets it directly at
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
/x/settings/noun
/x/verbosity/noun
/x/operation/<id>/noun
/x/publication/<digest>/noun
/x/content/<digest>/<value-mark>
```

`/x/operation/<id>` returns either `%running` or `%complete`. Content uses its
original mark rather than `%noun`, allowing a caller to request the typed page.
The advertised remote path is the corresponding revision-qualified `%gx` path.

## Failure and consistency model

The façade reports typed failures for invalid or oversized input, unresolved or
conflicting names, absent providers, unsupported locators, empty or oversized
remote scries, digest mismatches, timeouts, and failed lower publications.

Publication spans several Gall agents and is not an atomic transaction. The
remote-scry `%grow` card is emitted before the provider publication cards, so a
successfully advertised locator refers to a page this agent has already asked
Clay/Gall to publish. A later lower-layer failure leaves the local page intact
and returns a failed operation; retrying `%put` reuses the page.

## Configuration and ownership

The defaults are:

```hoon
[request-timeout=~s30 publication-lifetime=~d1 max-content-bytes=8.388.608]
```

The timeout covers final remote scry. Routing and discovery operations retain
their own bounded concurrency and timeout settings. `%content-store` owns the
published casks and façade operations; the lower agents continue to own their
routing tables, signed origins and replicas, protocol queues, and topic index.

Applications still configure bootstrap seeds on `%kademlia`. They do not
normally need to poke the other two protocol agents when using this façade.
