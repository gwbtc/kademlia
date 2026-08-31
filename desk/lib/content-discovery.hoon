/-  *kademlia, *content-routing, *content-discovery
::
::  Pure key derivation, record policy, and selection for hierarchical topics.
::
|%
+$  verifier
  $-([signer=node-id message=digest signature=*] ?)
::
++  topic-valid
  |=  topic=topic-path
  ^-  ?
  ?~  topic  |
  =/  remaining=topic-path  topic
  =/  count=@ud  0
  |-
  ?~  remaining  (lte count 8)
  ?:  (gte count 8)  |
  ?.  ?&  !=(%$ i.remaining)
          (lte (met 3 i.remaining) 64)
      ==
    |
  $(remaining t.remaining, count +(count))
::
++  catalog-reference-valid
  |=  ref=catalog-reference
  ^-  ?
  ?&  !=(%$ format.ref)
      (lte (met 3 format.ref) 64)
      (lte (met 0 digest.ref) 256)
  ==
::
++  topic-key
  |=  topic=topic-path
  ^-  key
  ?>  (topic-valid topic)
  (end 7 (shax (jam [%kad-content-topic-key-v1 topic])))
::
++  strict-prefix
  |=  [parent=topic-path source=topic-path child=@tas]
  ^-  ?
  =/  p=topic-path  parent
  =/  s=topic-path  source
  |-
  ?~  p
    ?~  s  |
    =(child i.s)
  ?~  s  |
  ?.  =(i.p i.s)  |
  $(p t.p, s t.s)
::
++  catalog-body-valid
  |=  body=catalog-body
  ^-  ?
  ?&  (topic-valid topic.body)
      =(key.body (topic-key topic.body))
      (lte (met 0 publisher.body) 128)
      (catalog-reference-valid catalog.body)
  ==
::
++  edge-body-valid
  |=  body=edge-body
  ^-  ?
  ?&  (topic-valid parent.body)
      (topic-valid source.body)
      !=(%$ child.body)
      (lte (met 3 child.body) 64)
      =(key.body (topic-key parent.body))
      (lte (met 0 publisher.body) 128)
      (strict-prefix parent.body source.body child.body)
      (catalog-reference-valid catalog.body)
  ==
::
++  record-key
  |=  record=discovery-record
  ^-  key
  ?-  -.record
    %catalog  key.body.value.record
    %edge     key.body.value.record
  ==
::
++  record-publisher
  |=  record=discovery-record
  ^-  node-id
  ?-  -.record
    %catalog  publisher.body.value.record
    %edge     publisher.body.value.record
  ==
::
++  record-revision
  |=  record=discovery-record
  ^-  @ud
  ?-  -.record
    %catalog  revision.body.value.record
    %edge     revision.body.value.record
  ==
::
++  record-expiry
  |=  record=discovery-record
  ^-  @da
  ?-  -.record
    %catalog  expires.body.value.record
    %edge     expires.body.value.record
  ==
::
++  identity-of
  |=  record=discovery-record
  ^-  record-identity
  ?-  -.record
    %catalog  [%catalog publisher.body.value.record]
    %edge     [%edge publisher.body.value.record source.body.value.record]
  ==
::
++  catalog-message
  |=  body=catalog-body
  ^-  digest
  (shax (jam [%kad-content-topic-catalog-sign-v1 body]))
::
++  edge-message
  |=  body=edge-body
  ^-  digest
  (shax (jam [%kad-content-topic-edge-sign-v1 body]))
::
++  record-valid
  |=  [now=@da expected=topic-path verify=verifier record=discovery-record]
  ^-  ?
  ?-  -.record
    %catalog
      =/  rec=catalog-record  value.record
      ?&  (catalog-body-valid body.rec)
          =(expected topic.body.rec)
          (lth now expires.body.rec)
          (verify publisher.body.rec (catalog-message body.rec) signature.rec)
      ==
    %edge
      =/  rec=edge-record  value.record
      ?&  (edge-body-valid body.rec)
          =(expected parent.body.rec)
          (lth now expires.body.rec)
          (verify publisher.body.rec (edge-message body.rec) signature.rec)
      ==
  ==
::
::  Generate the unsigned leaf record followed by one edge for every strict,
::  nonempty prefix.  The caller signs each body before transport.
::
+$  unsigned-record
  $%  [%catalog body=catalog-body]
      [%edge body=edge-body]
  ==
+$  unsigned-records  (list unsigned-record)
::
++  advertisement-bodies
  |=  $:  topic=topic-path
          publisher=node-id
          revision=@ud
          expires=@da
          catalog=catalog-reference
      ==
  ^-  unsigned-records
  ?>  (topic-valid topic)
  ?>  (catalog-reference-valid catalog)
  =/  leaf=catalog-body
    [topic (topic-key topic) publisher revision expires catalog]
  =/  prefixes=(list [parent=topic-path child=@tas])  ~
  =/  built=topic-path  ~
  =/  remaining=topic-path  topic
  |-
  ?~  remaining
    =/  edges=unsigned-records
      %+  turn  (flop prefixes)
      |=  item=[parent=topic-path child=@tas]
      [%edge parent.item (topic-key parent.item) child.item topic publisher revision expires catalog]
    [[%catalog leaf] edges]
  =/  next=topic-path  (snoc built i.remaining)
  ?~  t.remaining
    $(remaining ~, built next)
  =.  prefixes  [[next i.t.remaining] prefixes]
  $(remaining t.remaining, built next, prefixes prefixes)
::
::  Select the greatest non-conflicting revision for each record identity,
::  then aggregate immediate children and their authenticated supporters.
::
+$  choice  [record=discovery-record conflict=?]
::
++  select-admitted
  |=  [now=@da topic=topic-path records=discovery-records]
  ^-  topic-selection
  =/  choices=(map record-identity choice)  ~
  =/  remaining=discovery-records  records
  |-
  ?~  remaining
    =/  entries=(list (pair record-identity choice))  ~(tap by choices)
    =/  catalogs=(list catalog-record)  ~
    =/  children=(map @tas (set node-id))  ~
    =/  conflicts=(set record-identity)  ~
    =/  pending=(list (pair record-identity choice))  entries
    |-
    ?~  pending
      =/  cats=(list catalog-record)
        %+  sort  catalogs
        |=  [a=catalog-record b=catalog-record]
        (lth publisher.body.a publisher.body.b)
      =/  kids=(list child-selection)
        %+  sort  ~(tap by children)
        |=  [a=(pair @tas (set node-id)) b=(pair @tas (set node-id))]
        (aor -.a -.b)
      [cats kids conflicts]
    =/  id=record-identity  -.i.pending
    =/  selected=choice  +.i.pending
    ?:  conflict.selected
      $(pending t.pending, conflicts (~(put in conflicts) id))
    =/  record=discovery-record  record.selected
    ?-  -.record
      %catalog
        $(pending t.pending, catalogs [value.record catalogs])
      %edge
        =/  child=@tas  child.body.value.record
        =/  old=(set node-id)  (~(gut by children) [child ~])
        =/  fresh=(set node-id)
          (~(put in old) publisher.body.value.record)
        $(pending t.pending, children (~(put by children) child fresh))
    ==
  =/  record=discovery-record  i.remaining
  ?.  (lth now (record-expiry record))
    $(remaining t.remaining)
  =/  id=record-identity  (identity-of record)
  =/  old=(unit choice)  (~(get by choices) id)
  ?~  old
    $(remaining t.remaining, choices (~(put by choices) id [record |]))
  =/  prior=choice  u.old
  =/  revision=@ud  (record-revision record)
  =/  old-revision=@ud  (record-revision record.prior)
  ?:  (gth revision old-revision)
    $(remaining t.remaining, choices (~(put by choices) id [record |]))
  ?:  (lth revision old-revision)
    $(remaining t.remaining)
  =/  canonical=discovery-record  record.prior
  =?  canonical  (dor record canonical)  record
  =/  conflict=?  |(conflict.prior !=(record record.prior))
  $(remaining t.remaining, choices (~(put by choices) id [canonical conflict]))
--
