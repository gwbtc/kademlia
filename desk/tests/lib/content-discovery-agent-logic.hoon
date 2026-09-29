/-  *kademlia, *content-routing, *content-discovery, *content-discovery-agent, *bounded-poke
/+  logic=content-discovery-agent-logic, discovery=content-discovery, *test
|%
++  now  ~2026.8.30
++  allow
  |=  [signer=node-id message=digest signature=*]
  &
++  initial
  ^-  discovery-state
  ~(init logic [~zod now ~zod %test *discovery-state allow])
::
++  catalog-record-for
  |=  [publisher=node-id revision=@ud digest=@uvI]
  ^-  record
  =/  topic=topic-path  ~[%software %urbit %hoon]
  =/  body=catalog-body
    [topic (topic-key:discovery topic) publisher revision ~2100.1.1 [%demo digest 1]]
  [%catalog body [1 `@ux`revision]]
::
++  edge-record-for
  |=  [publisher=node-id source=topic-path revision=@ud]
  ^-  record
  =/  parent=topic-path  ~[%software]
  =/  body=edge-body
    [parent (topic-key:discovery parent) %urbit source publisher revision ~2100.1.1 [%demo 0v1 1]]
  [%edge body [1 `@ux`revision]]
::
++  test-default-config-and-state
  =/  state=discovery-state  initial
  ;:  weld
    %+  expect-eq  !>(20)
    !>(replication.config.state)
    %+  expect-eq  !>(64)
    !>(max-records-per-key.config.state)
    %+  expect-eq  !>(8)
    !>(max-records-per-publisher.config.state)
    %+  expect-eq  !>(0)
    !>(replica-count.state)
  ==
::
++  test-record-wire-round-trip
  =/  state=discovery-state  initial
  =/  engine  [~zod now ~zod %test state allow]
  =/  rec=record  (catalog-record-for 0x12 1 0v42)
  =/  payload=@  (~(pack-record logic engine) rec)
  =/  decoded=sized-record  (need (~(unpack-record logic engine) payload))
  ;:  weld
    %+  expect-eq  !>(rec)
    !>(value.decoded)
    %+  expect-eq  !>((met 3 payload))
    !>(bytes.decoded)
  ==
::
++  test-replica-revision-and-conflict
  =/  state=discovery-state  initial
  =/  low=record  (catalog-record-for 0x12 1 0v1)
  =/  high=record  (catalog-record-for 0x12 2 0v2)
  =/  conflict=record  (catalog-record-for 0x12 2 0v3)
  =/  one=[store-status discovery-state]
    (~(put-replica logic [~zod now ~zod %test state allow]) low)
  =/  two=[store-status discovery-state]
    (~(put-replica logic [~zod now ~zod %test +.one allow]) high)
  =/  three=[store-status discovery-state]
    (~(put-replica logic [~zod now ~zod %test +.two allow]) conflict)
  =/  key=key  (record-key:discovery high)
  =/  values=records  (~(values-for logic [~zod now ~zod %test +.three allow]) key)
  ;:  weld
    %+  expect-eq  !>(`store-status`[%accepted ~])
    !>(-.one)
    %+  expect-eq  !>(`store-status`[%accepted ~])
    !>(-.two)
    %+  expect-eq  !>(`store-status`[%accepted ~])
    !>(-.three)
    %+  expect-eq  !>(2)
    !>((lent values))
  ==
::
++  test-topic-capacity
  =/  state=discovery-state  initial
  =.  config.state  config.state(max-records-per-key 1)
  =/  one=record  (edge-record-for 0x12 ~[%software %urbit %hoon] 1)
  =/  two=record  (edge-record-for 0x13 ~[%software %urbit %vere] 1)
  =/  first=[store-status discovery-state]
    (~(put-replica logic [~zod now ~zod %test state allow]) one)
  =/  second=[store-status discovery-state]
    (~(put-replica logic [~zod now ~zod %test +.first allow]) two)
  ;:  weld
    %+  expect-eq  !>(`store-status`[%accepted ~])
    !>(-.first)
    %+  expect-eq  !>(`store-status`[%rejected %capacity])
    !>(-.second)
  ==
::
++  test-publisher-capacity
  =/  state=discovery-state  initial
  =.  config.state  config.state(max-records-per-publisher 1)
  =/  one=record  (edge-record-for 0x12 ~[%software %urbit %hoon] 1)
  =/  two=record  (edge-record-for 0x12 ~[%software %urbit %vere] 1)
  =/  first=[store-status discovery-state]
    (~(put-replica logic [~zod now ~zod %test state allow]) one)
  =/  second=[store-status discovery-state]
    (~(put-replica logic [~zod now ~zod %test +.first allow]) two)
  ;:  weld
    %+  expect-eq  !>(`store-status`[%accepted ~])
    !>(-.first)
    %+  expect-eq  !>(`store-status`[%rejected %publisher-cap])
    !>(-.second)
  ==
::
++  test-multiple-origins-share-topic-key
  =/  state=discovery-state  initial
  =/  one=record  (edge-record-for 0x12 ~[%software %urbit %hoon] 1)
  =/  two=record  (edge-record-for 0x12 ~[%software %urbit %vere] 1)
  =.  state  (~(put-origin logic [~zod now ~zod %test state allow]) one)
  =.  state  (~(put-origin logic [~zod now ~zod %test state allow]) two)
  =/  key=key  (record-key:discovery one)
  ;:  weld
    %+  expect-eq  !>(2)
    !>((lent (~(values-for logic [~zod now ~zod %test state allow]) key)))
    %+  expect-eq  !>(2)
    !>((lent ~(tap by origins.state)))
  ==
::
++  test-origin-publisher-capacity
  =/  state=discovery-state  initial
  =.  config.state  config.state(max-records-per-publisher 1)
  =/  one=record  (edge-record-for 0x12 ~[%software %urbit %hoon] 1)
  =/  two=record  (edge-record-for 0x12 ~[%software %urbit %vere] 1)
  =.  state  (~(put-origin logic [~zod now ~zod %test state allow]) one)
  =/  attempt
    %-  mule
    |.  (~(put-origin logic [~zod now ~zod %test state allow]) two)
  ;:  weld
    (expect !>(?=(%| -.attempt)))
    %+  expect-eq  !>(1)
    !>((lent ~(tap by origins.state)))
  ==
::
++  test-responses-share-peer-gate
  =/  state=discovery-state  initial
  =/  message=discovery-message
    [%stored %content-discovery-v1 0v1 [%accepted ~]]
  =/  first=[(list card:agent:gall) discovery-state]
    (~(send-response logic [~zod now ~zod %test state allow]) ~nec 0v1 message)
  =/  second=[(list card:agent:gall) discovery-state]
    (~(send-response logic [~zod now ~zod %test +.first allow]) ~nec 0v2 message)
  =/  peer=peer-delivery  (need (~(get by peers.outbound.+.second) ~nec))
  ;:  weld
    (expect !>(?=(^ active.peer)))
    %+  expect-eq  !>(1)
    !>((lent responses.peer))
    %+  expect-eq  !>(0)
    !>((lent requests.peer))
  ==
--
