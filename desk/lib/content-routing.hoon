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
  |=  [namespace=@tas publisher=node-id name=*]
  ^-  key
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
::  greatest-pointer-revision: find the greatest revision in a nonempty list.
::
++  greatest-pointer-revision
  |=  records=pointers
  ^-  @ud
  ?~  records  0
  (max revision.body.i.records $(records t.records))
::
::  pointer-bodies-agree: test whether every record has one pointer body.
::
++  pointer-bodies-agree
  |=  [expected=pointer-body records=pointers]
  ^-  ?
  ?~  records  &
  ?.  =(expected body.i.records)  |
  $(records t.records)
::
::  canonical-pointer: choose one duplicate by deterministic noun order.
::
++  canonical-pointer
  |=  records=pointers
  ^-  pointer
  ?>  ?=(^ records)
  =/  best=pointer  i.records
  =/  remaining=pointers  t.records
  |-
  ?~  remaining  best
  =/  candidate=pointer  i.remaining
  =?  best  (dor signature.candidate signature.best)  candidate
  $(remaining t.remaining)
::
::  valid-pointers: retain authenticated pointers for one expected name.
::
++  valid-pointers
  |=  $:  now=@da
          expected-namespace=@tas
          expected-key=key
          expected-publisher=node-id
          verify=verifier
          records=pointers
      ==
  ^-  pointers
  ?~  records  ~
  =/  rest=pointers
    $(records t.records)
  ?:  (pointer-valid now expected-namespace expected-key expected-publisher verify i.records)
    [i.records rest]
  rest
::
::  pointers-at-revision: retain pointers at one exact revision.
::
++  pointers-at-revision
  |=  [revision=@ud records=pointers]
  ^-  pointers
  ?~  records  ~
  =/  rest=pointers  $(records t.records)
  ?:  =(revision revision.body.i.records)
    [i.records rest]
  rest
::
::  select-pointer: choose the greatest valid revision or report equivocation.
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
  =/  valid=pointers
    (valid-pointers now expected-namespace expected-key expected-publisher verify records)
  ?~  valid  [%none ~]
  =/  greatest=@ud  (greatest-pointer-revision valid)
  =/  latest=pointers  (pointers-at-revision greatest valid)
  =/  first=pointer  (canonical-pointer latest)
  ?.  (pointer-bodies-agree body.first latest)  [%conflict greatest]
  [%found first]
::
::  provider-choice: the greatest revision observed for one provider.
::
::    .conflict records whether distinct bodies exist at that revision.
::    .best is the canonical duplicate selected by signature noun order.
::
+$  provider-choice
  [best=provider conflict=?]
::
::  select-providers: select one latest announcement per provider.
::
::    An equivocating provider is excluded and reported without affecting
::    valid announcements from other providers.  Records are authenticated
::    and grouped in one pass; no provider causes a rescan of the input list.
::
++  select-providers
  |=  [now=@da expected=digest verify=verifier records=providers]
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
  ?.  (provider-valid now expected verify candidate)
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
--
