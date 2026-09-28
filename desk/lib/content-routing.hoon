/-  *kademlia, *content-routing
::
::  Pure content naming and provider-record policy.  Network transport,
::  persistence, and access to signing keys belong to the calling agent.
::
|%
::  digest-valid: test whether an atom fits the sha-256 digest domain.
::
++  digest-valid
  |=  dig=digest
  ^-  ?
  (lte (met 0 dig) 256)
::
::  identity-valid: test the shared 128-bit Kademlia identity/key domain.
::
++  identity-valid
  |=  value=@
  ^-  ?
  (lte (met 0 value) 128)
::
::  name-valid: bound publisher-scoped mutable paths before key derivation.
::
++  name-valid
  |=  name=path
  ^-  ?
  ?~  name  |
  =/  remaining=path  name
  =/  count=@ud  0
  |-
  ?~  remaining  (lte count 16)
  ?:  (gte count 16)  |
  ?.  ?&  !=(%$ i.remaining)
          (lte (met 3 i.remaining) 64)
      ==
    |
  $(remaining t.remaining, count +(count))
::
::  digest-cask: commit to both the mark and noun of a cask.
::
++  digest-cask
  |=  value=(cask)
  ^-  digest
  (shax (jam value))
::
::  verify-cask: verify a cask against an expected content digest.
::
++  verify-cask
  |=  [expected=digest value=(cask)]
  ^-  ?
  =(expected (digest-cask value))
::
::  pointer-key: derive a publisher-scoped 128-bit mutable-name key.
::
++  pointer-key
  |=  [namespace=@tas publisher=node-id name=path]
  ^-  key
  ?>  !=(%$ namespace)
  ?>  (name-valid name)
  (end 7 (shax (jam [%kad-content-pointer-key-v1 namespace publisher name])))
::
::  provider-key: derive the 128-bit lookup key for one content digest.
::
++  provider-key
  |=  content=digest
  ^-  key
  (end 7 (shax (jam [%kad-content-provider-key-v1 content])))
::
::  pointer-message: produce the domain-separated digest to sign or verify.
::
++  pointer-message
  |=  body=pointer-body
  ^-  digest
  (shax (jam [%kad-content-pointer-sign-v1 body]))
::
::  provider-message: produce the domain-separated digest to sign or verify.
::
++  provider-message
  |=  body=provider-body
  ^-  digest
  (shax (jam [%kad-content-provider-sign-v1 body]))
::
::  locator-valid: verify the structural invariants of one locator.
::
++  locator-valid
  |=  loc=locator
  ^-  ?
  ?-  -.loc
    %scry
      (identity-valid ship.spar.loc)
    %custom
      !=(%$ protocol.loc)
  ==
::
::  locators-valid: require a nonempty list of valid locators.
::
++  locators-valid
  |=  locs=locators
  ^-  ?
  ?~  locs  |
  =/  remaining=locators  locs
  |-
  ?~  remaining  &
  ?.  (locator-valid i.remaining)  |
  $(remaining t.remaining)
::
::  target-valid: verify a content-discovery or direct-retrieval target.
::
++  target-valid
  |=  tar=target
  ^-  ?
  ?-  -.tar
    %content
      (digest-valid digest.tar)
    %direct
      ?&  ?~(digest.tar & (digest-valid u.digest.tar))
          (locators-valid locations.tar)
      ==
  ==
::
::  pointer-body-valid: verify non-cryptographic pointer invariants.
::
++  pointer-body-valid
  |=  body=pointer-body
  ^-  ?
  ?&  !=(%$ namespace.body)
      (identity-valid key.body)
      (identity-valid publisher.body)
      (target-valid target.body)
  ==
::
::  provider-body-valid: verify non-cryptographic provider invariants.
::
++  provider-body-valid
  |=  body=provider-body
  ^-  ?
  ?&  (digest-valid content.body)
      (identity-valid provider.body)
      (locators-valid locations.body)
  ==
::
::  pointer-fresh: pointers without expiry remain valid indefinitely.
::
++  pointer-fresh
  |=  [now=@da expires=(unit @da)]
  ^-  ?
  ?~  expires  &
  (lth now u.expires)
::
::  pointer-valid: authenticate a fresh pointer for the expected name owner.
::
++  pointer-valid
  |=  $:  now=@da
          expected-namespace=@tas
          expected-key=key
          expected-publisher=node-id
          verify=verifier
          record=pointer
      ==
  ^-  ?
  =/  body=pointer-body  body.record
  ?&  (pointer-body-valid body)
      =(expected-namespace namespace.body)
      =(expected-key key.body)
      =(expected-publisher publisher.body)
      (pointer-fresh now expires.body)
      (verify publisher.body (pointer-message body) signature.record)
  ==
::
::  provider-valid: authenticate a fresh announcement for expected content.
::
++  provider-valid
  |=  [now=@da expected=digest verify=verifier record=provider]
  ^-  ?
  =/  body=provider-body  body.record
  ?&  (provider-body-valid body)
      =(expected content.body)
      (lth now expires.body)
      (verify provider.body (provider-message body) signature.record)
  ==
::
::  choose-pointer: select the greatest accepted pointer in one traversal.
::
::    The accumulator retains only the greatest revision, its canonical
::    duplicate, and whether distinct bodies occurred at that revision.
::
++  choose-pointer
  |=  [records=pointers admit=$-(pointer ?)]
  ^-  pointer-selection
  =/  remaining=pointers  records
  =/  best=(unit pointer)  ~
  =/  greatest=@ud  0
  =/  conflict=?  |
  |-
  ?~  remaining
    ?~  best  [%none ~]
    ?:  conflict  [%conflict greatest]
    [%found u.best]
  =/  candidate=pointer  i.remaining
  ?.  (admit candidate)
    $(remaining t.remaining)
  =/  revision=@ud  revision.body.candidate
  ?~  best
    $(remaining t.remaining, best `candidate, greatest revision, conflict |)
  ?:  (gth revision greatest)
    $(remaining t.remaining, best `candidate, greatest revision, conflict |)
  ?:  (lth revision greatest)
    $(remaining t.remaining)
  =/  chosen=pointer  u.best
  =/  conflict=?  |(conflict !=(body.candidate body.chosen))
  =?  chosen  (dor signature.candidate signature.chosen)  candidate
  $(remaining t.remaining, best `chosen, conflict conflict)
::
::  select-pointer: authenticate, context-check, and select pointers.
::
++  select-pointer
  |=  $:  now=@da
          expected-namespace=@tas
          expected-key=key
          expected-publisher=node-id
          verify=verifier
          records=pointers
      ==
  ^-  pointer-selection
  =/  admit=$-(pointer ?)
    |=  candidate=pointer
    (pointer-valid now expected-namespace expected-key expected-publisher verify candidate)
  (choose-pointer records admit)
::
::  select-admitted-pointer: recheck expiry and select admitted pointers.
::
::    The caller must already have authenticated each record and checked it
::    against the lookup context.  This arm deliberately performs no
::    cryptographic verification.
::
++  select-admitted-pointer
  |=  [now=@da records=pointers]
  ^-  pointer-selection
  =/  admit=$-(pointer ?)
    |=  candidate=pointer
    (pointer-fresh now expires.body.candidate)
  (choose-pointer records admit)
::
::  provider-choice: the greatest revision observed for one provider.
::
::    .conflict records whether distinct bodies exist at that revision.
::    .best is the canonical duplicate selected by signature noun order.
::
+$  provider-choice
  [best=provider conflict=?]
::
::  choose-providers: select one latest accepted record per provider.
::
::    An equivocating provider is excluded and reported without affecting
::    other providers.  The admission gate and grouping run in one pass; no
::    provider causes a rescan of the input list.
::
++  choose-providers
  |=  [records=providers admit=$-(provider ?)]
  ^-  provider-selection
  =/  remaining=providers  records
  =/  choices=(map node-id provider-choice)  ~
  |-
  ?~  remaining
    =/  entries=(list (pair node-id provider-choice))
      %+  sort  ~(tap by choices)
      |=  [a=(pair node-id provider-choice) b=(pair node-id provider-choice)]
      (lth -.a -.b)
    =/  pending=(list (pair node-id provider-choice))  entries
    =/  selected=providers  ~
    =/  conflicts=(set node-id)  ~
    |-
    ?~  pending  [(flop selected) conflicts]
    =/  id=node-id  -.i.pending
    =/  choice=provider-choice  +.i.pending
    ?:  conflict.choice
      $(pending t.pending, conflicts (~(put in conflicts) id))
    $(pending t.pending, selected [best.choice selected])
  =/  candidate=provider  i.remaining
  ?.  (admit candidate)
    $(remaining t.remaining)
  =/  id=node-id  provider.body.candidate
  =/  old=(unit provider-choice)  (~(get by choices) id)
  ?~  old
    $(remaining t.remaining, choices (~(put by choices) id [candidate |]))
  =/  choice=provider-choice  u.old
  =/  candidate-revision=@ud  revision.body.candidate
  =/  chosen-revision=@ud  revision.body.best.choice
  ?:  (gth candidate-revision chosen-revision)
    $(remaining t.remaining, choices (~(put by choices) id [candidate |]))
  ?:  (lth candidate-revision chosen-revision)
    $(remaining t.remaining)
  =/  canonical=provider  best.choice
  =?  canonical  (dor signature.candidate signature.canonical)  candidate
  =/  conflict=?  |(conflict.choice !=(body.candidate body.best.choice))
  $(remaining t.remaining, choices (~(put by choices) id [canonical conflict]))
::
::  select-providers: authenticate, context-check, and select providers.
::
++  select-providers
  |=  [now=@da expected=digest verify=verifier records=providers]
  ^-  provider-selection
  =/  admit=$-(provider ?)
    |=  candidate=provider
    (provider-valid now expected verify candidate)
  (choose-providers records admit)
::
::  select-admitted-providers: recheck expiry and select admitted providers.
::
::    The caller must already have authenticated each record and checked it
::    against the lookup context.  This arm deliberately performs no
::    cryptographic verification.
::
++  select-admitted-providers
  |=  [now=@da records=providers]
  ^-  provider-selection
  =/  admit=$-(provider ?)
    |=  candidate=provider
    (lth now expires.body.candidate)
  (choose-providers records admit)
--
