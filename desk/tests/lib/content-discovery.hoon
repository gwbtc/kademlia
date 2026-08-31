/-  *kademlia, *content-routing, *content-discovery
/+  discovery=content-discovery, routing=content-routing, *test
|%
++  allow
  |=  [signer=node-id message=digest signature=*]
  &
::
++  catalog
  |=  [publisher=node-id revision=@ud value=digest]
  ^-  catalog-record
  =/  topic=topic-path  ~[%software %urbit %hoon]
  =/  body=catalog-body
    [topic (topic-key:discovery topic) publisher revision ~2100.1.1 [%demo value 2]]
  [body [1 `@ux`revision]]
::
++  edge
  |=  [publisher=node-id revision=@ud child=@tas source=topic-path value=digest]
  ^-  edge-record
  =/  parent=topic-path  ~[%software]
  =/  body=edge-body
    [parent (topic-key:discovery parent) child source publisher revision ~2100.1.1 [%demo value 2]]
  [body [1 `@ux`revision]]
::
++  test-topic-validation-and-key
  =/  topic=topic-path  ~[%software %urbit %hoon]
  =/  other=topic-path  ~[%software %urbit %vere]
  =/  deep=topic-path  ~[%a %b %c %d %e %f %g %h %i]
  ;:  weld
    (expect !>((topic-valid:discovery topic)))
    (expect !>(!(topic-valid:discovery ~)))
    (expect !>(!(topic-valid:discovery deep)))
    (expect !>(!=((topic-key:discovery topic) (topic-key:discovery other))))
    (expect !>((lte (met 0 (topic-key:discovery topic)) 128)))
  ==
::
++  test-automatic-edge-generation
  =/  topic=topic-path  ~[%software %urbit %hoon]
  =/  ref=catalog-reference  [%demo 0v42 2]
  =/  out=unsigned-records:discovery
    (advertisement-bodies:discovery topic 0x12 7 ~2100.1.1 ref)
  ?>  ?=(^ out)
  =/  leaf=unsigned-record:discovery  i.out
  =/  rest=unsigned-records:discovery  t.out
  ?>  ?=(^ rest)
  =/  first=unsigned-record:discovery  i.rest
  =/  rest-two=unsigned-records:discovery  t.rest
  ?>  ?=(^ rest-two)
  =/  second=unsigned-record:discovery  i.rest-two
  ?>  ?=(%catalog -.leaf)
  ?>  ?=(%edge -.first)
  ?>  ?=(%edge -.second)
  ;:  weld
    %+  expect-eq  !>(3)
    !>((lent out))
    (expect !>(?=(%catalog -.leaf)))
    (expect !>(?=(%edge -.first)))
    (expect !>(?=(%edge -.second)))
    %+  expect-eq  !>(`topic-path`~[%software])
    !>(parent.body.first)
    %+  expect-eq  !>(%urbit)
    !>(child.body.first)
    %+  expect-eq  !>(`topic-path`~[%software %urbit])
    !>(parent.body.second)
    %+  expect-eq  !>(%hoon)
    !>(child.body.second)
  ==
::
++  test-record-context-validation
  =/  rec=catalog-record  (catalog 0x12 1 0v42)
  ;:  weld
    (expect !>((record-valid:discovery ~2026.8.30 ~[%software %urbit %hoon] allow [%catalog rec])))
    (expect !>(!(record-valid:discovery ~2026.8.30 ~[%software] allow [%catalog rec])))
    (expect !>(!(record-valid:discovery ~2100.1.1 ~[%software %urbit %hoon] allow [%catalog rec])))
    (expect !>(!=((catalog-message:discovery body.rec) digest.catalog.body.rec)))
  ==
::
++  test-selection-and-children
  =/  older=catalog-record  (catalog 0x12 1 0v1)
  =/  newest=catalog-record  (catalog 0x12 2 0v2)
  =/  other=catalog-record  (catalog 0x13 1 0v3)
  =/  source-a=topic-path  ~[%software %urbit %hoon]
  =/  source-b=topic-path  ~[%software %urbit %vere]
  =/  edge-a=edge-record  (edge 0x12 1 %urbit source-a 0v1)
  =/  edge-b=edge-record  (edge 0x13 1 %urbit source-b 0v3)
  =/  records=discovery-records
    ~[[%catalog older] [%edge edge-a] [%catalog other] [%catalog newest] [%edge edge-b]]
  =/  leaf=topic-selection
    (select-admitted:discovery ~2026.8.30 ~[%software %urbit %hoon] records)
  =/  root=topic-selection
    (select-admitted:discovery ~2026.8.30 ~[%software] records)
  ?>  ?=(^ catalogs.leaf)
  ?>  ?=(^ children.root)
  ;:  weld
    %+  expect-eq  !>(2)
    !>((lent catalogs.leaf))
    %+  expect-eq  !>(2)
    !>(revision.body.i.catalogs.leaf)
    %+  expect-eq  !>(1)
    !>((lent children.root))
    %+  expect-eq  !>(%urbit)
    !>(name.i.children.root)
    %+  expect-eq  !>(2)
    !>(~(wyt in supporters.i.children.root))
  ==
::
++  test-equal-revision-conflict
  =/  a=catalog-record  (catalog 0x12 7 0v1)
  =/  b=catalog-record  (catalog 0x12 7 0v2)
  =/  out=topic-selection
    (select-admitted:discovery ~2026.8.30 ~[%software %urbit %hoon] ~[[%catalog a] [%catalog b]])
  ;:  weld
    %+  expect-eq  !>(0)
    !>((lent catalogs.out))
    (expect !>((~(has in conflicts.out) `record-identity`[%catalog 0x12])))
  ==
--
