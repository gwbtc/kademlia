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
++  provider-for
  |=  [content=digest who=node-id revision=@ud address=*]
  ^-  record
  =/  body=provider-body
    [content who revision ~2026.8.12 [[%custom %test address] ~]]
  [%provider body [1 `@ux`revision]]
::
++  provider
  |=  [who=node-id revision=@ud address=*]
  ^-  record
  (provider-for content-id who revision address)
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
++  test-record-payload-round-trip
  =/  state=content-state  initial
  =/  engine  [~zod now ~zod state allow]
  =/  rec=record  (provider 0x12 1 'https://one.test')
  =/  payload=@  (~(pack-record logic engine) rec)
  =/  decoded=(unit record)  (~(unpack-record logic engine) payload)
  =/  got=record  (need decoded)
  ;:  weld
    (expect !>(?=(^ decoded)))
    %+  expect-eq  !>(rec)
    !>(got)
  ==
::
++  test-records-payload-round-trip
  =/  state=content-state  initial
  =/  engine  [~zod now ~zod state allow]
  =/  values=records
    [(provider 0x12 1 'https://one.test') (provider 0x13 1 'https://two.test') ~]
  =/  packed=[count=@ud payload=@]  (~(pack-records logic engine) values)
  =/  decoded=(unit records)
    (~(unpack-records logic engine) count.packed payload.packed)
  =/  got=records  (need decoded)
  ;:  weld
    %+  expect-eq  !>(2)
    !>(count.packed)
    (expect !>(?=(^ decoded)))
    %+  expect-eq  !>(values)
    !>(got)
  ==
::
++  test-malformed-record-payloads-rejected
  =/  state=content-state  initial
  =/  engine  [~zod now ~zod state allow]
  =/  valid=[count=@ud payload=@]
    (~(pack-records logic engine) [(provider 0x12 1 'https://one.test') ~])
  ;:  weld
    %+  expect-eq  !>(`(unit record)`~)
    !>((~(unpack-record logic engine) 0))
    %+  expect-eq  !>(`(unit records)`~)
    !>((~(unpack-records logic engine) 2 payload.valid))
    %+  expect-eq  !>(`(unit records)`~)
    !>((~(unpack-records logic engine) 65 payload.valid))
    %+  expect-eq  !>(`(unit records)`~)
    !>((~(unpack-records logic engine) 0 (pow 2 (mul 8 262.144))))
  ==
::
++  test-config-cannot-exceed-wire-limits
  =/  state=content-state  initial
  =/  engine  [~zod now ~zod state allow]
  ;:  weld
    (expect !>(!(~(config-valid logic engine) config.state(max-record-bytes 65.537))))
    (expect !>(!(~(config-valid logic engine) config.state(max-providers 65))))
  ==
::
++  test-id-boundaries
  =/  state=content-state  initial
  =/  engine  [~zod now ~zod state allow]
  ;:  weld
    (expect !>((~(valid-id logic engine) (dec (pow 2 64)))))
    (expect !>(!(~(valid-id logic engine) (pow 2 64))))
    %-  expect-fail
    |.  (~(start-find-providers logic engine) ;;(@uv (pow 2 64)) content-id)
  ==
::
++  test-query-domain-boundaries
  =/  state=content-state  initial
  =/  engine  [~zod now ~zod state allow]
  ;:  weld
    (expect !>((~(valid-query logic engine) [%pointer ;;(@ux (dec (pow 2 128)))])))
    (expect !>(!(~(valid-query logic engine) [%pointer ;;(@ux (pow 2 128))])))
    (expect !>((~(valid-query logic engine) [%providers ;;(@uvI (dec (pow 2 256)))])))
    (expect !>(!(~(valid-query logic engine) [%providers ;;(@uvI (pow 2 256))])))
    %-  expect-fail
    |.  (~(start-find-pointer logic engine) 0v1 %test ;;(@ux (pow 2 128)) 0)
    %-  expect-fail
    |.  (~(start-find-providers logic engine) 0v1 ;;(@uvI (pow 2 256)))
  ==
::
++  test-response-admission
  =/  state=content-state  initial
  =/  peer=node-id  ~(self-id logic [~nec now ~nec state allow])
  =/  pen=pending-content-request  [0v9 peer %.y +(now)]
  =.  pending.state  (~(put by pending.state) 0v1 pen)
  =/  correct  [~zod now ~nec state allow]
  =/  wrong  [~zod now ~bud state allow]
  ;:  weld
    (expect !>((~(response-expected logic correct) 0v1 %.y)))
    (expect !>(!(~(response-expected logic correct) 0v1 %.n)))
    (expect !>(!(~(response-expected logic wrong) 0v1 %.y)))
    (expect !>(!(~(response-expected logic correct) 0v2 %.y)))
  ==
::
++  test-content-request-id-wrap-skips-pending
  =/  state=content-state  initial
  =/  max=content-request-id  ;;(@uv (dec (pow 2 64)))
  =/  pen=pending-content-request  [0v9 0x1 %.n +(now)]
  =.  pending.state  (~(put by pending.state) max pen)
  =.  pending.state  (~(put by pending.state) ;;(@uv 0) pen)
  =.  next-request.state  max
  =/  out=[content-request-id content-state]
    ~(take-content-request-id logic [~zod now ~zod state allow])
  ;:  weld
    %+  expect-eq  !>(;;(@uv 1))
    !>(-.out)
    %+  expect-eq  !>(;;(@uv 2))
    !>(next-request.+.out)
  ==
::
++  test-operation-id-wrap-skips-owned-ids
  =/  state=content-state  initial
  =/  max=operation-id  ;;(@uv (dec (pow 2 64)))
  =/  callback=operation-callback  [%sink /result]
  =.  callbacks.state  (~(put by callbacks.state) max callback)
  =.  callbacks.state  (~(put by callbacks.state) ;;(@uv 0) callback)
  =.  background.state  (~(put in background.state) ;;(@uv 1))
  =.  next-operation.state  max
  =/  out=[operation-id content-state]
    ~(next-operation-id logic [~zod now ~zod state allow])
  ;:  weld
    %+  expect-eq  !>(;;(@uv 2))
    !>(-.out)
    %+  expect-eq  !>(;;(@uv 3))
    !>(next-operation.+.out)
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
++  test-values-for-filters-only-requested-key
  =/  state=content-state  initial
  =/  requested=digest  (digest-cask:cr `(cask)`[%noun 1])
  =/  unrelated=digest  (digest-cask:cr `(cask)`[%noun 2])
  =/  requested-record=record  (provider-for requested 0x12 1 %requested)
  =/  unrelated-record=record  (provider-for unrelated 0x13 1 %unrelated)
  =/  requested-key=key  (provider-key:cr requested)
  =/  unrelated-key=key  (provider-key:cr unrelated)
  =.  replicas.state
    (~(put by replicas.state) requested-key [[requested-record (dec now)] ~])
  =.  replicas.state
    (~(put by replicas.state) unrelated-key [[unrelated-record (dec now)] ~])
  =/  values=records
    (~(values-for logic [~zod now ~zod state allow]) requested-key)
  ;:  weld
    %+  expect-eq  !>(`records`~)
    !>(values)
    (expect !>((~(has by replicas.state) unrelated-key)))
  ==
::
++  test-store-prunes-only-target-below-capacity
  =/  state=content-state  initial
  =/  expired=digest  (digest-cask:cr `(cask)`[%noun 1])
  =/  incoming=digest  (digest-cask:cr `(cask)`[%noun 2])
  =/  expired-record=record  (provider-for expired 0x12 1 %expired)
  =/  incoming-record=record  (provider-for incoming 0x13 1 %incoming)
  =/  expired-key=key  (provider-key:cr expired)
  =/  incoming-key=key  (provider-key:cr incoming)
  =.  replicas.state
    (~(put by replicas.state) expired-key [[expired-record (dec now)] ~])
  =/  out=[store-status content-state]
    (~(put-replica logic [~zod now ~nec state allow]) incoming-record)
  ;:  weld
    %+  expect-eq  !>(`store-status`[%accepted ~])
    !>(-.out)
    (expect !>((~(has by replicas.+.out) expired-key)))
    (expect !>((~(has by replicas.+.out) incoming-key)))
  ==
::
++  test-capacity-sweep-reclaims-expired-key
  =/  state=content-state  initial
  =.  state
    (~(set-config logic [~zod now ~zod state allow]) config.state(max-replica-keys 2))
  =/  expired=digest  (digest-cask:cr `(cask)`[%noun 1])
  =/  live=digest  (digest-cask:cr `(cask)`[%noun 2])
  =/  incoming=digest  (digest-cask:cr `(cask)`[%noun 3])
  =/  expired-record=record  (provider-for expired 0x12 1 %expired)
  =/  live-record=record  (provider-for live 0x13 1 %live)
  =/  incoming-record=record  (provider-for incoming 0x14 1 %incoming)
  =/  expired-key=key  (provider-key:cr expired)
  =/  live-key=key  (provider-key:cr live)
  =/  incoming-key=key  (provider-key:cr incoming)
  =.  replicas.state
    (~(put by replicas.state) expired-key [[expired-record (dec now)] ~])
  =.  replicas.state
    (~(put by replicas.state) live-key [[live-record +(now)] ~])
  =/  out=[store-status content-state]
    (~(put-replica logic [~zod now ~nec state allow]) incoming-record)
  ;:  weld
    %+  expect-eq  !>(`store-status`[%accepted ~])
    !>(-.out)
    (expect !>(!(~(has by replicas.+.out) expired-key)))
    (expect !>((~(has by replicas.+.out) live-key)))
    (expect !>((~(has by replicas.+.out) incoming-key)))
    %+  expect-eq  !>(2)
    !>(~(wyt by replicas.+.out))
  ==
::
++  test-local-publication-completes
  =/  state=content-state  initial
  =/  rec=record  (provider 0x12 1 'https://one.test')
  =/  started=[(list card:agent:gall) content-state]
    (~(start-publish logic [~zod now ~zod state allow]) 0v1 rec)
  =/  found=[(list card:agent:gall) operation-update]
    (~(receive-lookup logic [~zod now ~zod +.started allow]) 0v1 ~)
  =/  view=(unit operation-view)
    (~(get-operation logic [~zod now ~zod state.+.found allow]) 0v1)
  =/  completion=operation-completion  (need completion.+.found)
  =/  got=operation-view  (need view)
  ?>  ?=(%complete -.got)
  ?>  ?=(%published -.value.got)
  ;:  weld
    %+  expect-eq  !>(`(list card:agent:gall)`~)
    !>(-.found)
    %+  expect-eq  !>(1)
    !>((lent ~(tap in accepted.value.value.got)))
    (expect !>((~(has in accepted.value.value.got) ~(self-id logic [~zod now ~zod state.+.found allow]))))
    %+  expect-eq  !>(0v1)
    !>(id.completion)
  ==
::
++  test-local-provider-query
  =/  state=content-state  initial
  =/  rec=record  (provider 0x12 1 'https://one.test')
  ?>  ?=(%provider -.rec)
  =.  state  (~(put-origin logic [~zod now ~zod state allow]) rec)
  =/  started=[(list card:agent:gall) content-state]
    (~(start-find-providers logic [~zod now ~zod state allow]) 0v2 content-id)
  =/  found=[(list card:agent:gall) operation-update]
    (~(receive-lookup logic [~zod now ~zod +.started allow]) 0v2 ~)
  =/  view=(unit operation-view)
    (~(get-operation logic [~zod now ~zod state.+.found allow]) 0v2)
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
  =/  found=[(list card:agent:gall) operation-update]
    (~(receive-lookup logic [~zod now ~zod +.started allow]) 0v3 [0x10 0x20 0x30 0x40 ~])
  ;:  weld
    %+  expect-eq  !>(3)
    !>((lent ~(tap by pending.state.+.found)))
    %+  expect-eq  !>(6)
    !>((lent -.found))
    (expect !>(?=(~ completion.+.found)))
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
::
++  test-background-completion-is-emitted-but-not-retained
  =/  state=content-state  initial
  =/  rec=record  (provider 0x12 1 'https://one.test')
  =.  state  (~(put-origin logic [~zod now ~zod state allow]) rec)
  =/  later=@da  (add ~h12 now)
  =/  refreshed=[(list card:agent:gall) content-state]
    ~(refresh-origins logic [~zod later ~zod state allow])
  =/  entries=(list [operation-id operation])  ~(tap by active.+.refreshed)
  ?>  ?=(^ entries)
  =/  id=operation-id  -.i.entries
  =/  finished=[(list card:agent:gall) operation-update]
    (~(receive-lookup logic [~zod later ~zod +.refreshed allow]) id ~)
  =/  completion=operation-completion  (need completion.+.finished)
  ;:  weld
    %+  expect-eq  !>(id)
    !>(id.completion)
    (expect !>(!(~(has in background.state.+.finished) id)))
    (expect !>(!(~(has by completed.state.+.finished) id)))
  ==
--
