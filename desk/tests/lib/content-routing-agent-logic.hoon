/-  *kademlia, *content-routing, *content-routing-agent
/+  logic=content-routing-agent-logic, cr=content-routing, *test
|%
++  now  ~2026.8.10..12.00.00
::
++  allow
  |=  [signer=node-id message=digest signature=*]
  ^-  ?
  &
::
++  initial
  ^-  content-state
  ~(init logic [~zod now ~zod *content-state allow])
::
++  content-id
  ^-  digest
  (digest-cask:cr `(cask)`[%noun 42])
::
++  provider
  |=  [who=node-id revision=@ud url=@t]
  ^-  record
  =/  body=provider-body
    [content-id who revision ~2026.8.12 [[%http url] ~]]
  [%provider body [1 `@ux`revision]]
::
++  test-default-config
  =/  state=content-state  initial
  ;:  weld
    %+  expect-eq  !>(20)
    !>(replication.config.state)
    %+  expect-eq  !>(3)
    !>(concurrency.config.state)
    %+  expect-eq  !>(~m5)
    !>(request-timeout.config.state)
    %+  expect-eq  !>(~d1)
    !>(lease.config.state)
    %+  expect-eq  !>(~h12)
    !>(refresh.config.state)
  ==
::
++  test-replica-revision-and-conflict-cap
  =/  state=content-state  initial
  =/  one=record  (provider 0x12 1 'https://one.test')
  =/  two=record  (provider 0x12 2 'https://two.test')
  =/  conflict=record  (provider 0x12 2 'https://conflict.test')
  =/  excess=record  (provider 0x12 2 'https://excess.test')
  =/  a=[store-status content-state]
    (~(put-replica logic [~zod now ~nec state allow]) one)
  =/  b=[store-status content-state]
    (~(put-replica logic [~zod now ~nec +.a allow]) two)
  =/  c=[store-status content-state]
    (~(put-replica logic [~zod now ~nec +.b allow]) conflict)
  =/  d=[store-status content-state]
    (~(put-replica logic [~zod now ~nec +.c allow]) excess)
  =/  key=key  (provider-key:cr content-id)
  =/  values=records
    (~(values-for logic [~zod now ~zod +.d allow]) key)
  ;:  weld
    %+  expect-eq  !>(`store-status`[%accepted ~])
    !>(-.a)
    %+  expect-eq  !>(`store-status`[%accepted ~])
    !>(-.b)
    %+  expect-eq  !>(`store-status`[%accepted ~])
    !>(-.c)
    %+  expect-eq  !>(`store-status`[%rejected %conflict-cap])
    !>(-.d)
    %+  expect-eq  !>(2)
    !>((lent values))
    %-  expect
    !>  %+  levy  values
        |=  rec=record
        ?-  -.rec
          %pointer   =(2 revision.body.value.rec)
          %provider  =(2 revision.body.value.rec)
        ==
  ==
::
++  test-provider-cap
  =/  state=content-state  initial
  =.  state
    (~(set-config logic [~zod now ~zod state allow]) config.state(max-providers 1))
  =/  first=[store-status content-state]
    (~(put-replica logic [~zod now ~nec state allow]) (provider 0x12 1 'https://one.test'))
  =/  second=[store-status content-state]
    (~(put-replica logic [~zod now ~nec +.first allow]) (provider 0x13 1 'https://two.test'))
  %+  expect-eq  !>(`store-status`[%rejected %provider-cap])
  !>(-.second)
::
++  test-local-publication-completes
  =/  state=content-state  initial
  =/  rec=record  (provider 0x12 1 'https://one.test')
  =/  started=[(list card:agent:gall) content-state]
    (~(start-publish logic [~zod now ~zod state allow]) 0v1 rec)
  =/  found=[(list card:agent:gall) content-state]
    (~(receive-lookup logic [~zod now ~zod +.started allow]) 0v1 ~)
  =/  view=(unit operation-view)
    (~(get-operation logic [~zod now ~zod +.found allow]) 0v1)
  =/  got=operation-view  (need view)
  ?>  ?=(%complete -.got)
  ?>  ?=(%published -.value.got)
  ;:  weld
    %+  expect-eq  !>(`(list card:agent:gall)`~)
    !>(-.found)
    %+  expect-eq  !>(1)
    !>((lent ~(tap in accepted.value.value.got)))
    (expect !>((~(has in accepted.value.value.got) ~(self-id logic [~zod now ~zod +.found allow]))))
  ==
::
++  test-local-provider-query
  =/  state=content-state  initial
  =/  rec=record  (provider 0x12 1 'https://one.test')
  ?>  ?=(%provider -.rec)
  =.  state  (~(put-origin logic [~zod now ~zod state allow]) rec)
  =/  started=[(list card:agent:gall) content-state]
    (~(start-find-providers logic [~zod now ~zod state allow]) 0v2 content-id)
  =/  found=[(list card:agent:gall) content-state]
    (~(receive-lookup logic [~zod now ~zod +.started allow]) 0v2 ~)
  =/  view=(unit operation-view)
    (~(get-operation logic [~zod now ~zod +.found allow]) 0v2)
  =/  got=operation-view  (need view)
  ?>  ?=(%complete -.got)
  ?>  ?=(%providers -.value.got)
  %+  expect-eq  !>(`providers`[value.rec ~])
  !>(records.selection.value.value.got)
::
++  test-concurrency-bound
  =/  state=content-state  initial
  =/  rec=record  (provider 0x12 1 'https://one.test')
  =/  started=[(list card:agent:gall) content-state]
    (~(start-publish logic [~zod now ~zod state allow]) 0v3 rec)
  =/  found=[(list card:agent:gall) content-state]
    (~(receive-lookup logic [~zod now ~zod +.started allow]) 0v3 [0x10 0x20 0x30 0x40 ~])
  ;:  weld
    %+  expect-eq  !>(3)
    !>((lent ~(tap by pending.+.found)))
    %+  expect-eq  !>(6)
    !>((lent -.found))
  ==
::
++  test-origin-refresh-is-background
  =/  state=content-state  initial
  =/  rec=record  (provider 0x12 1 'https://one.test')
  =.  state  (~(put-origin logic [~zod now ~zod state allow]) rec)
  =/  later=@da  (add ~h12 now)
  =/  refreshed=[(list card:agent:gall) content-state]
    ~(refresh-origins logic [~zod later ~zod state allow])
  ;:  weld
    %+  expect-eq  !>(2)
    !>((lent -.refreshed))
    %+  expect-eq  !>(1)
    !>((lent ~(tap in background.+.refreshed)))
    %+  expect-eq  !>(1)
    !>((lent ~(tap by active.+.refreshed)))
    %+  expect-eq  !>((add ~h12 later))
    !>(refresh-at.+.refreshed)
  ==
--
