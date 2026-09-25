/-  *kademlia, *content-routing, *content-routing-agent, *bounded-poke
/+  logic=content-routing-agent-logic, cr=content-routing, *test
|%
++  now  ~2026.8.10..12.00.00
::
++  allow
  |=  [signer=node-id message=digest signature=*]
  ^-  ?
  &
::
++  deny
  |=  [signer=node-id message=digest signature=*]
  ^-  ?
  |
::
++  explode
  |=  [signer=node-id message=digest signature=*]
  ^-  ?
  !!
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
++  pointer-for
  |=  [namespace=@tas publisher=node-id name=path revision=@ud expires=(unit @da)]
  ^-  record
  =/  target=target  [%content content-id]
  =/  key=key  (pointer-key:cr namespace publisher name)
  [%pointer [namespace key publisher revision expires target] [1 `@ux`revision]]
::
++  pending-for
  |=  [id=operation-id state=content-state]
  ^-  @ud
  %+  roll  ~(tap by pending.state)
  |=  [entry=[content-request-id pending-content-request] count=@ud]
  ?:(=(id operation.+.entry) +(count) count)
::
++  linear-pack-records
  |=  values=records
  ^-  [count=@ud payload=@]
  =/  remaining=records  (scag 64 values)
  =/  kept=records  ~
  =/  count=@ud  0
  =/  payload=@  (jam `records`~)
  |-
  ?~  remaining  [count payload]
  =/  candidate=records  (flop [i.remaining kept])
  =/  candidate-payload=@  (jam candidate)
  ?:  (gth (met 3 candidate-payload) 262.144)
    [count payload]
  %=  $
    remaining  t.remaining
    kept       [i.remaining kept]
    count      +(count)
    payload    candidate-payload
  ==
::
++  test-default-config
  =/  state=content-state  initial
  ;:  weld
    %+  expect-eq  !>(20)
    !>(replication.config.state)
    %+  expect-eq  !>(3)
    !>(concurrency.config.state)
    %+  expect-eq  !>(12)
    !>(global-concurrency.config.state)
    %+  expect-eq  !>(~m5)
    !>(request-timeout.config.state)
    %+  expect-eq  !>(~d1)
    !>(lease.config.state)
    %+  expect-eq  !>(~h12)
    !>(refresh.config.state)
    %+  expect-eq  !>(8)
    !>(refresh-batch.config.state)
    %+  expect-eq  !>(0)
    !>(replica-count.state)
    %+  expect-eq  !>(0)
    !>(pending-count.state)
  ==
::
++  test-record-payload-round-trip
  =/  state=content-state  initial
  =/  engine  [~zod now ~zod state allow]
  =/  rec=record  (provider 0x12 1 'https://one.test')
  =/  payload=@  (~(pack-record logic engine) rec)
  =/  decoded=(unit sized-record)  (~(unpack-record logic engine) payload)
  =/  got=sized-record  (need decoded)
  ;:  weld
    (expect !>(?=(^ decoded)))
    %+  expect-eq  !>(rec)
    !>(value.got)
    %+  expect-eq  !>((met 3 payload))
    !>(bytes.got)
  ==
::
++  test-records-payload-round-trip
  =/  state=content-state  initial
  =/  engine  [~zod now ~zod state allow]
  =/  values=records
    [(provider 0x12 1 'https://one.test') (provider 0x13 1 'https://two.test') ~]
  =/  packed=[count=@ud payload=@]  (~(pack-records logic engine) values)
  =/  decoded=(unit sized-records)
    (~(unpack-records logic engine) count.packed payload.packed)
  =/  got=sized-records  (need decoded)
  =/  got-values=records  (turn got |=(item=sized-record value.item))
  =/  got-sizes=(list @ud)  (turn got |=(item=sized-record bytes.item))
  =/  expected-sizes=(list @ud)
    (turn values |=(item=record (met 3 (jam item))))
  ;:  weld
    %+  expect-eq  !>(2)
    !>(count.packed)
    (expect !>(?=(^ decoded)))
    %+  expect-eq  !>(values)
    !>(got-values)
    %+  expect-eq  !>(expected-sizes)
    !>(got-sizes)
  ==
::
++  test-records-payload-longest-fitting-prefix
  =/  state=content-state  initial
  =/  engine  [~zod now ~zod state allow]
  =/  blob=@  (pow 2 (mul 8 40.000))
  =/  make
    |=  [remaining=@ud values=records]
    ^-  records
    ?:  =(0 remaining)  values
    =/  rec=record
      (provider-for content-id (@ux remaining) 1 (add blob remaining))
    $(remaining (dec remaining), values [rec values])
  =/  values=records  (make 8 ~)
  =/  expected=[count=@ud payload=@]  (linear-pack-records values)
  =/  actual=[count=@ud payload=@]  (~(pack-records logic engine) values)
  ;:  weld
    %+  expect-eq  !>(expected)
    !>(actual)
    (expect !>((gth count.actual 0)))
    (expect !>((lth count.actual (lent values))))
  ==
::
++  test-malformed-record-payloads-rejected
  =/  state=content-state  initial
  =/  engine  [~zod now ~zod state allow]
  =/  valid=[count=@ud payload=@]
    (~(pack-records logic engine) [(provider 0x12 1 'https://one.test') ~])
  ;:  weld
    %+  expect-eq  !>(`(unit sized-record)`~)
    !>((~(unpack-record logic engine) 0))
    %+  expect-eq  !>(`(unit sized-records)`~)
    !>((~(unpack-records logic engine) 2 payload.valid))
    %+  expect-eq  !>(`(unit sized-records)`~)
    !>((~(unpack-records logic engine) 65 payload.valid))
    %+  expect-eq  !>(`(unit sized-records)`~)
    !>((~(unpack-records logic engine) 0 (pow 2 (mul 8 262.144))))
  ==
::
++  test-config-cannot-exceed-wire-limits
  =/  state=content-state  initial
  =/  engine  [~zod now ~zod state allow]
  ;:  weld
    (expect !>(!(~(config-valid logic engine) config.state(max-record-bytes 65.537))))
    (expect !>(!(~(config-valid logic engine) config.state(max-providers 65))))
    (expect !>(!(~(config-valid logic engine) config.state(global-concurrency 0))))
    (expect !>(!(~(config-valid logic engine) config.state(refresh-batch 0))))
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
    |.  (~(start-find-pointer logic engine) 0v1 %test ;;(@ux (pow 2 128)) ~)
    %-  expect-fail
    |.  (~(start-find-providers logic engine) 0v1 ;;(@uvI (pow 2 256)))
  ==
::
++  test-response-admission
  =/  state=content-state  initial
  =/  peer=node-id  ~(self-id logic [~nec now ~nec state allow])
  =/  pen=pending-content-request  [0v9 peer %.y +(now) 0]
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
  =/  pen=pending-content-request  [0v9 0x1 %.n +(now) 0]
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
++  test-replica-admission-preserves-order-and-refreshes-duplicate
  =/  state=content-state  initial
  =/  old=record  (provider 0x12 1 %old)
  =/  other=record  (provider 0x13 1 %other)
  =/  newest=record  (provider 0x12 2 %newest)
  =/  stale=record  (provider 0x12 1 %stale)
  =/  a=[store-status content-state]
    (~(put-replica logic [~zod now ~nec state allow]) old)
  =/  b=[store-status content-state]
    (~(put-replica logic [~zod now ~nec +.a allow]) other)
  =/  c=[store-status content-state]
    (~(put-replica logic [~zod now ~nec +.b allow]) newest)
  =/  later=@da  (add ~h1 now)
  =/  refreshed=[store-status content-state]
    (~(put-replica logic [~zod later ~nec +.c allow]) newest)
  =/  rejected=[store-status content-state]
    (~(put-replica logic [~zod later ~nec +.refreshed allow]) stale)
  =/  target=key  (provider-key:cr content-id)
  =/  stored=leased-records
    (~(gut by replicas.+.refreshed) [target ~])
  ?>  ?=(^ stored)
  ;:  weld
    %+  expect-eq  !>(`store-status`[%accepted ~])
    !>(-.refreshed)
    %+  expect-eq  !>(`records`[newest other ~])
    !>((turn stored |=(item=leased-record value.item)))
    %+  expect-eq  !>((add ~d1 later))
    !>(lease-until.i.stored)
    %+  expect-eq  !>(`store-status`[%rejected %stale])
    !>(-.rejected)
    %+  expect-eq  !>(replicas.+.refreshed)
    !>(replicas.+.rejected)
  ==
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
  =.  replica-count.state  2
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
  =.  replica-count.state  1
  =/  out=[store-status content-state]
    (~(put-replica logic [~zod now ~nec state allow]) incoming-record)
  ;:  weld
    %+  expect-eq  !>(`store-status`[%accepted ~])
    !>(-.out)
    (expect !>((~(has by replicas.+.out) expired-key)))
    (expect !>((~(has by replicas.+.out) incoming-key)))
    %+  expect-eq  !>(2)
    !>(replica-count.+.out)
  ==
::
++  test-prune-key-updates-replica-count
  =/  state=content-state  initial
  =/  rec=record  (provider 0x12 1 %expired)
  =/  target=key  (provider-key:cr content-id)
  =.  replicas.state
    (~(put by replicas.state) target [[rec (dec now)] ~])
  =.  replica-count.state  1
  =/  out=content-state
    (~(prune-key logic [~zod now ~zod state allow]) target)
  ;:  weld
    (expect !>(!(~(has by replicas.out) target)))
    %+  expect-eq  !>(0)
    !>(replica-count.out)
  ==
::
++  test-prune-list-change-reporting
  =/  state=content-state  initial
  =/  engine  [~zod now ~zod state allow]
  =/  a=leased-record  [(provider 0x11 1 %a) +(now)]
  =/  b=leased-record  [(provider 0x12 1 %b) (dec now)]
  =/  c=leased-record  [(provider 0x13 1 %c) (add 2 now)]
  =/  d=leased-record  [(provider 0x14 1 %d) now]
  =/  unchanged=[changed=? values=leased-records]
    (~(prune-list logic engine) [a c ~])
  =/  head=[changed=? values=leased-records]
    (~(prune-list logic engine) [b a c ~])
  =/  middle=[changed=? values=leased-records]
    (~(prune-list logic engine) [a b c ~])
  =/  tail=[changed=? values=leased-records]
    (~(prune-list logic engine) [a c d ~])
  =/  all=[changed=? values=leased-records]
    (~(prune-list logic engine) [b d ~])
  ;:  weld
    %+  expect-eq  !>(`[changed=? values=leased-records]`[| [a c ~]])
    !>(unchanged)
    %+  expect-eq  !>(`[changed=? values=leased-records]`[& [a c ~]])
    !>(head)
    %+  expect-eq  !>(`[changed=? values=leased-records]`[& [a c ~]])
    !>(middle)
    %+  expect-eq  !>(`[changed=? values=leased-records]`[& [a c ~]])
    !>(tail)
    %+  expect-eq  !>(`[changed=? values=leased-records]`[& ~])
    !>(all)
  ==
::
++  test-prune-key-unchanged-count
  =/  state=content-state  initial
  =/  rec=record  (provider 0x12 1 %live)
  =/  target=key  (provider-key:cr content-id)
  =.  replicas.state
    (~(put by replicas.state) target [[rec +(now)] ~])
  =.  replica-count.state  1
  =/  out=content-state
    (~(prune-key logic [~zod now ~zod state allow]) target)
  ;:  weld
    %+  expect-eq  !>(state)
    !>(out)
    %+  expect-eq  !>(1)
    !>(replica-count.out)
  ==
::
++  test-prune-all-recomputes-replica-count
  =/  state=content-state  initial
  =/  expired=digest  (digest-cask:cr `(cask)`[%noun 1])
  =/  live=digest  (digest-cask:cr `(cask)`[%noun 2])
  =/  expired-record=record  (provider-for expired 0x12 1 %expired)
  =/  live-record=record  (provider-for live 0x13 1 %live)
  =/  expired-key=key  (provider-key:cr expired)
  =/  live-key=key  (provider-key:cr live)
  =.  replicas.state
    (~(put by replicas.state) expired-key [[expired-record (dec now)] ~])
  =.  replicas.state
    (~(put by replicas.state) live-key [[live-record +(now)] ~])
  =.  replica-count.state  2
  =/  out=content-state
    ~(prune-all logic [~zod now ~zod state allow])
  ;:  weld
    (expect !>(!(~(has by replicas.out) expired-key)))
    (expect !>((~(has by replicas.out) live-key)))
    %+  expect-eq  !>(1)
    !>(replica-count.out)
  ==
::
++  test-eviction-preserves-replica-count
  =/  state=content-state  initial
  =.  state
    (~(set-config logic [~zod now ~zod state allow]) config.state(max-replica-keys 1))
  =/  old=digest  (digest-cask:cr `(cask)`[%noun 1])
  =/  incoming=digest  (digest-cask:cr `(cask)`[%noun 2])
  =/  old-record=record  (provider-for old 0x12 1 %old)
  =/  incoming-record=record  (provider-for incoming 0x13 1 %incoming)
  =/  old-key=key  (provider-key:cr old)
  =/  incoming-key=key  (provider-key:cr incoming)
  =.  replicas.state
    (~(put by replicas.state) old-key [[old-record +(now)] ~])
  =.  replica-count.state  1
  =/  out=[store-status content-state]
    (~(put-replica logic [~zod now ~nec state allow]) incoming-record)
  ;:  weld
    %+  expect-eq  !>(`store-status`[%accepted ~])
    !>(-.out)
    (expect !>(!(~(has by replicas.+.out) old-key)))
    (expect !>((~(has by replicas.+.out) incoming-key)))
    %+  expect-eq  !>(1)
    !>(replica-count.+.out)
    %+  expect-eq  !>(1)
    !>(~(wyt by replicas.+.out))
  ==
::
++  test-eviction-selects-oldest-horizon-and-key-tie
  =/  state=content-state  initial
  =/  one=digest  (digest-cask:cr `(cask)`[%noun 11])
  =/  two=digest  (digest-cask:cr `(cask)`[%noun 22])
  =/  three=digest  (digest-cask:cr `(cask)`[%noun 33])
  =/  one-key=key  (provider-key:cr one)
  =/  two-key=key  (provider-key:cr two)
  =/  three-key=key  (provider-key:cr three)
  =/  tied=@da  (add ~h1 now)
  =.  replicas.state
    (~(put by replicas.state) one-key [[(provider-for one 0x11 1 %one) tied] ~])
  =.  replicas.state
    (~(put by replicas.state) two-key [[(provider-for two 0x12 1 %two) tied] ~])
  =.  replicas.state
    %+  ~(put by replicas.state)  three-key
    [[(provider-for three 0x13 1 %three) (add ~h2 now)] ~]
  =.  replica-count.state  3
  =/  victim=key  (min one-key two-key)
  =/  survivor=key  (max one-key two-key)
  =/  out=content-state
    ~(evict-one logic [~zod now ~zod state allow])
  ;:  weld
    (expect !>(!(~(has by replicas.out) victim)))
    (expect !>((~(has by replicas.out) survivor)))
    (expect !>((~(has by replicas.out) three-key)))
    %+  expect-eq  !>(2)
    !>(replica-count.out)
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
  =.  replica-count.state  2
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
    %+  expect-eq  !>(2)
    !>(replica-count.+.out)
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
  ?>  ?=(^ completions.+.found)
  =/  completion=operation-completion  i.completions.+.found
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
++  test-local-publication-reuses-packed-record
  =/  state=content-state  initial
  =/  rec=record  (provider 0x12 1 %packed)
  =/  expected=@  (jam rec)
  =/  started=[(list card:agent:gall) content-state]
    (~(start-publish logic [~zod now ~zod state allow]) 0v1 rec)
  =/  active=(unit operation)  (~(get by active.+.started) 0v1)
  =/  op=operation  (need active)
  ?>  ?=(%publish -.kind.op)
  =/  origin=(unit record)
    (~(get by origins.+.started) key.kind.op)
  ;:  weld
    %+  expect-eq  !>(expected)
    !>(payload.kind.op)
    %+  expect-eq  !>(rec)
    !>((need origin))
  ==
::
++  test-remote-publication-completes-after-stored
  =/  state=content-state  initial
  =.  state
    (~(set-config logic [~zod now ~zod state allow]) config.state(replication 2, concurrency 1))
  =/  rec=record  (provider 0x12 1 %remote)
  =/  peer=node-id  ~(self-id logic [~nec now ~nec state allow])
  =/  started=[(list card:agent:gall) content-state]
    (~(start-publish logic [~zod now ~zod state allow]) 0v1 rec)
  =/  found=[(list card:agent:gall) operation-update]
    (~(receive-lookup logic [~zod now ~zod +.started allow]) 0v1 [peer ~])
  ?>  =(1 ~(wyt by pending.state.+.found))
  =/  pending-entries=(list [content-request-id pending-content-request])
    ~(tap by pending.state.+.found)
  ?>  ?=(^ pending-entries)
  =/  request=content-request-id  -.i.pending-entries
  =/  stored=[(list card:agent:gall) operation-update]
    (~(receive-stored logic [~zod now ~nec state.+.found allow]) request [%accepted ~])
  ?>  ?=(^ completions.+.stored)
  =/  completion=operation-completion  i.completions.+.stored
  ?>  ?=(%published -.result.completion)
  ;:  weld
    %+  expect-eq  !>(0v1)
    !>(id.completion)
    %+  expect-eq  !>(2)
    !>((lent ~(tap in accepted.value.result.completion)))
    (expect !>(!(~(has by active.state.+.stored) 0v1)))
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
++  test-operation-admission-checks-query-context
  =/  state=content-state  initial
  =/  other=digest  (digest-cask:cr `(cask)`[%noun 43])
  =/  correct=record  (provider-for content-id 0x12 1 %correct)
  =/  wrong=record  (provider-for other 0x13 1 %wrong)
  =/  op=operation
    [[%find-providers content-id (provider-key:cr content-id)] %.y ~ 0 ~ ~ ~ ~ ~ ~ ~]
  =/  merged=operation
    (~(merge-records logic [~zod now ~nec state allow]) op [wrong correct ~])
  =/  pointer=record  (pointer-for %test 0x12 ~[%name] 1 `~2026.8.12)
  =/  pointer-key=key  (pointer-key:cr %test 0x12 ~[%name])
  =/  pointer-op=operation
    [[%find-pointer %other 0x12 pointer-key] %.y ~ 0 ~ ~ ~ ~ ~ ~ ~]
  =/  pointer-merged=operation
    (~(merge-records logic [~zod now ~nec state allow]) pointer-op [pointer ~])
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent providers.merged))
    %+  expect-eq  !>(0)
    !>((lent pointers.merged))
    %+  expect-eq  !>(0)
    !>((lent pointers.pointer-merged))
    %+  expect-eq  !>(0)
    !>((lent providers.pointer-merged))
  ==
::
++  test-operation-admission-deduplicates-records
  =/  state=content-state  initial
  =/  rec=record  (provider 0x12 1 %duplicate)
  =/  size=@ud  (met 3 (jam rec))
  =/  op=operation
    [[%find-providers content-id (provider-key:cr content-id)] %.y ~ 0 ~ ~ ~ ~ ~ ~ ~]
  =/  local=operation
    (~(merge-records logic [~zod now ~nec state allow]) op [rec rec ~])
  =/  decoded=operation
    %+  ~(merge-sized-records logic [~zod now ~nec state allow])  op
    [[rec size] [rec size] ~]
  =/  repeated=operation
    %+  ~(merge-sized-records logic [~zod now ~nec state explode])  decoded
    [[rec size] ~]
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent providers.local))
    %+  expect-eq  !>(1)
    !>(~(wyt in admitted.local))
    %+  expect-eq  !>(1)
    !>((lent providers.decoded))
    %+  expect-eq  !>(1)
    !>(~(wyt in admitted.decoded))
    %+  expect-eq  !>(decoded)
    !>(repeated)
  ==
::
++  test-operation-completion-does-not-reverify-records
  =/  state=content-state  initial
  =/  provider-rec=record  (provider 0x12 1 %provider)
  =/  provider-op=operation
    [[%find-providers content-id (provider-key:cr content-id)] %.y ~ 0 ~ ~ ~ ~ ~ ~ ~]
  =/  provider-op=operation
    (~(merge-records logic [~zod now ~nec state allow]) provider-op [provider-rec ~])
  =/  provider-finished=[operation-completion content-state]
    (~(finish logic [~zod now ~nec state deny]) 0v1 provider-op)
  =/  provider-result=operation-result  result.-.provider-finished
  ?>  ?=(%providers -.provider-result)
  =/  pointer-rec=record  (pointer-for %test 0x12 ~[%name] 1 `~2026.8.12)
  ?>  ?=(%pointer -.pointer-rec)
  =/  pointer-key=key  (pointer-key:cr %test 0x12 ~[%name])
  =/  pointer-op=operation
    [[%find-pointer %test 0x12 pointer-key] %.y ~ 0 ~ ~ ~ ~ ~ ~ ~]
  =/  pointer-op=operation
    (~(merge-records logic [~zod now ~nec state allow]) pointer-op [pointer-rec ~])
  =/  pointer-finished=[operation-completion content-state]
    (~(finish logic [~zod now ~nec state deny]) 0v2 pointer-op)
  =/  pointer-result=operation-result  result.-.pointer-finished
  ?>  ?=(%pointer -.pointer-result)
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent records.selection.value.provider-result))
    %+  expect-eq  !>(`pointer-selection`[%found value.pointer-rec])
    !>(selection.value.pointer-result)
  ==
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
    %+  expect-eq  !>(3)
    !>(pending-count.state.+.found)
    %+  expect-eq  !>(6)
    !>((lent -.found))
    (expect !>(?=(~ completions.+.found)))
  ==
::
++  test-global-concurrency-is-fair-across-operations
  =/  state=content-state  initial
  =.  state
    (~(set-config logic [~zod now ~zod state allow]) config.state(global-concurrency 2))
  =/  one=record  (provider-for content-id 0x12 1 %one)
  =/  other=digest  (digest-cask:cr `(cask)`[%noun 43])
  =/  two=record  (provider-for other 0x13 1 %two)
  =/  first=[(list card:agent:gall) content-state]
    (~(start-publish logic [~zod now ~zod state allow]) 0v1 one)
  =/  second=[(list card:agent:gall) content-state]
    (~(start-publish logic [~zod now ~zod +.first allow]) 0v2 two)
  =/  first-ready=[(list card:agent:gall) operation-update]
    %+  ~(receive-lookup logic [~zod now ~zod +.second allow])  0v1
    [0x10 0x20 0x30 0x40 ~]
  =/  both-ready=[(list card:agent:gall) operation-update]
    %+  ~(receive-lookup logic [~zod now ~zod state.+.first-ready allow])  0v2
    [0x50 0x60 0x70 0x80 ~]
  =/  freed-one=[(list card:agent:gall) operation-update]
    (~(fail-request logic [~zod now ~zod state.+.both-ready allow]) 0v1 |)
  =/  freed-two=[(list card:agent:gall) operation-update]
    (~(fail-request logic [~zod now ~zod state.+.freed-one allow]) 0v2 |)
  ;:  weld
    %+  expect-eq  !>(2)
    !>(~(wyt by pending.state.+.both-ready))
    %+  expect-eq  !>(2)
    !>(pending-count.state.+.both-ready)
    %+  expect-eq  !>(0)
    !>((pending-for 0v2 state.+.both-ready))
    %+  expect-eq  !>(2)
    !>(~(wyt by pending.state.+.freed-one))
    %+  expect-eq  !>(2)
    !>(pending-count.state.+.freed-one)
    %+  expect-eq  !>(2)
    !>(~(wyt by pending.state.+.freed-two))
    %+  expect-eq  !>(2)
    !>(pending-count.state.+.freed-two)
    %+  expect-eq  !>(1)
    !>((pending-for 0v2 state.+.freed-two))
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
++  test-origin-refresh-is-batched
  =/  state=content-state  initial
  =.  state
    (~(set-config logic [~zod now ~zod state allow]) config.state(refresh-batch 1))
  =/  one=digest  (digest-cask:cr `(cask)`[%noun 1])
  =/  two=digest  (digest-cask:cr `(cask)`[%noun 2])
  =/  three=digest  (digest-cask:cr `(cask)`[%noun 3])
  =.  state
    (~(put-origin logic [~zod now ~zod state allow]) (provider-for one 0x11 1 %one))
  =.  state
    (~(put-origin logic [~zod now ~zod state allow]) (provider-for two 0x12 1 %two))
  =.  state
    (~(put-origin logic [~zod now ~zod state allow]) (provider-for three 0x13 1 %three))
  =/  first-now=@da  (add ~h12 now)
  =/  first=[(list card:agent:gall) content-state]
    ~(refresh-origins logic [~zod first-now ~zod state allow])
  =/  second-now=@da  (add ~s1 first-now)
  =/  second=[(list card:agent:gall) content-state]
    ~(refresh-origins logic [~zod second-now ~zod +.first allow])
  =/  third-now=@da  (add ~s1 second-now)
  =/  third=[(list card:agent:gall) content-state]
    ~(refresh-origins logic [~zod third-now ~zod +.second allow])
  ;:  weld
    %+  expect-eq  !>(1)
    !>(~(wyt by active.+.first))
    %+  expect-eq  !>(2)
    !>((lent refresh-queue.+.first))
    %+  expect-eq  !>((add ~s1 first-now))
    !>(refresh-at.+.first)
    %+  expect-eq  !>(2)
    !>(~(wyt by active.+.second))
    %+  expect-eq  !>(1)
    !>((lent refresh-queue.+.second))
    %+  expect-eq  !>(3)
    !>(~(wyt by active.+.third))
    %+  expect-eq  !>(0)
    !>((lent refresh-queue.+.third))
    %+  expect-eq  !>((add ~h12 third-now))
    !>(refresh-at.+.third)
  ==
::
++  test-origin-refresh-skips-active-publication-key
  =/  state=content-state  initial
  =/  other-content=digest  (digest-cask:cr `(cask)`[%noun 43])
  =/  one=record  (provider-for content-id 0x12 1 'https://one.test')
  =/  two=record  (provider-for other-content 0x13 1 'https://two.test')
  =/  active-publish=[(list card:agent:gall) content-state]
    (~(start-publish logic [~zod now ~zod state allow]) 0v9 one)
  =.  state  +.active-publish
  =.  state  (~(put-origin logic [~zod now ~zod state allow]) two)
  =/  later=@da  (add ~h12 now)
  =/  refreshed=[(list card:agent:gall) content-state]
    ~(refresh-origins logic [~zod later ~zod state allow])
  =/  publishing=(set key)
    ~(publishing-keys logic [~zod later ~zod +.refreshed allow])
  ;:  weld
    %+  expect-eq  !>(2)
    !>((lent ~(tap by active.+.refreshed)))
    %+  expect-eq  !>(1)
    !>((lent ~(tap in background.+.refreshed)))
    %+  expect-eq  !>(2)
    !>((lent ~(tap in publishing)))
    %+  expect-eq  !>(2)
    !>((lent -.refreshed))
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
  ?>  ?=(^ completions.+.finished)
  =/  completion=operation-completion  i.completions.+.finished
  ;:  weld
    %+  expect-eq  !>(id)
    !>(id.completion)
    (expect !>(!(~(has in background.state.+.finished) id)))
    (expect !>(!(~(has by completed.state.+.finished) id)))
  ==
::
++  test-responses-share-peer-gate-and-reset-drops-queue
  =/  state=content-state  initial
  =/  message=content-message
    [%stored %content-routing-v1 0v1 [%accepted ~]]
  =/  first=[(list card:agent:gall) content-state]
    (~(send-response logic [~zod now ~zod state allow]) ~nec 0v1 message)
  =/  second=[(list card:agent:gall) content-state]
    (~(send-response logic [~zod now ~zod +.first allow]) ~nec 0v2 message)
  =/  before=peer-delivery  (need (~(get by peers.outbound.+.second) ~nec))
  =/  reset=[(list card:agent:gall) content-state]
    ~(reset-state logic [~zod now ~zod +.second allow])
  =/  after=peer-delivery  (need (~(get by peers.outbound.+.reset) ~nec))
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent responses.before))
    %+  expect-eq  !>(active.before)
    !>(active.after)
    (expect !>(?&(?=(~ responses.after) ?=(~ requests.after) ?=(~ wake.after))))
  ==
--
