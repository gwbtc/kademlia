/-  *kademlia, *kademlia-agent
/+  logic=kademlia-agent-logic, kad=kademlia, *test
|%
++  now  ~2026.8.4..12.00.00
::
++  initial
  |=  [our=@p src=@p]
  ^-  agent-state
  ~(init logic [our now src *agent-state])
::
++  node
  |=  ship=@p
  ^-  node-id
  ~(self-id logic [ship now ship *agent-state])
::
++  pending-count
  |=  state=agent-state
  (lent ~(tap by pending.state))
::
++  first-pending
  |=  state=agent-state
  ^-  [request-id pending-request]
  (head ~(tap by pending.state))
::
++  test-init-and-seeds
  =/  state=agent-state  (initial ~zod ~zod)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~bud ~nec ~zod ~])
  =/  seeds=(list node-id)  ~(seed-list logic [~zod now ~zod state])
  =/  summary=summary  ~(get-summary logic [~zod now ~zod state])
  ;:  weld
    %+  expect-eq  !>(2)
    !>((lent seeds))
    %+  expect-eq  !>(2)
    !>(seeds.summary)
    %+  expect-eq  !>(0)
    !>(pending.summary)
    %+  expect-eq  !>(~m5)
    !>(request-timeout.settings.state)
    %+  expect-eq  !>(~h1)
    !>(refresh-interval.settings.state)
    %+  expect-eq  !>(`(unit @da)`[~ (add ~h1 now)])
    !>(refresh-at.state)
    (expect !>(!(~(has in seeds.state) (node ~zod))))
  ==
::
++  test-id-boundaries
  =/  state=agent-state  (initial ~zod ~zod)
  =/  engine  [~zod now ~zod state]
  ;:  weld
    (expect !>((~(valid-id logic engine) (dec (pow 2 64)))))
    (expect !>(!(~(valid-id logic engine) (pow 2 64))))
    %-  expect-fail
    |.  (~(start logic engine) ;;(@uv (pow 2 64)) 0x0)
  ==
::
++  test-request-id-wrap-skips-pending
  =/  state=agent-state  (initial ~zod ~zod)
  =/  max=request-id  ;;(@uv (dec (pow 2 64)))
  =/  pen=pending-request  [0v9 (node ~nec) now +(now)]
  =.  pending.state  (~(put by pending.state) max pen)
  =.  pending.state  (~(put by pending.state) ;;(@uv 0) pen)
  =.  next-request.state  max
  =/  out=[request-id agent-state]
    ~(take-request-id logic [~zod now ~zod state])
  ;:  weld
    %+  expect-eq  !>(;;(@uv 1))
    !>(-.out)
    %+  expect-eq  !>(;;(@uv 2))
    !>(next-request.+.out)
  ==
::
++  test-lookup-id-wrap-skips-owned-ids
  =/  state=agent-state  (initial ~zod ~zod)
  =/  max=lookup-id  ;;(@uv (dec (pow 2 64)))
  =/  result=lookup-result  [0x1 ~]
  =.  completed.state  (~(put by completed.state) max result)
  =.  completed.state  (~(put by completed.state) ;;(@uv 0) result)
  =.  callbacks.state  (~(put by callbacks.state) ;;(@uv 1) [%sink /result])
  =.  next-lookup.state  max
  =/  out=[lookup-id agent-state]
    ~(take-lookup-id logic [~zod now ~zod state])
  ;:  weld
    %+  expect-eq  !>(;;(@uv 2))
    !>(-.out)
    %+  expect-eq  !>(;;(@uv 3))
    !>(next-lookup.+.out)
  ==
::
++  test-request-timeout-setting
  =/  state=agent-state  (initial ~zod ~zod)
  =.  state  (~(set-request-timeout logic [~zod now ~zod state]) ~s45)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~])
  =/  started=[(list card:agent:gall) lookup-update]
    (~(start logic [~zod now ~zod state]) 0v20 0x1234)
  =/  pen=[request-id pending-request]  (first-pending state.+.started)
  ;:  weld
    %+  expect-eq  !>(~s45)
    !>(request-timeout.settings.state.+.started)
    %+  expect-eq  !>((add ~s45 now))
    !>(deadline.+.pen)
  ==
::
++  test-zero-request-timeout-rejected
  =/  state=agent-state  (initial ~zod ~zod)
  %-  expect-fail
  |.  (~(set-request-timeout logic [~zod now ~zod state]) `@dr`0)
::
++  test-refresh-interval-setting
  =/  state=agent-state  (initial ~zod ~zod)
  =/  old=@da  (add ~h1 now)
  =/  out=[(list card:agent:gall) agent-state]
    (~(set-refresh-interval logic [~zod now ~zod state]) ~m45)
  =/  rest=card:agent:gall
    [%pass /refresh/(scot %da old) %arvo %b %rest old]
  =/  fresh=@da  (add ~m45 now)
  =/  wait=card:agent:gall
    [%pass /refresh/(scot %da fresh) %arvo %b %wait fresh]
  ;:  weld
    %+  expect-eq  !>(~m45)
    !>(refresh-interval.settings.+.out)
    %+  expect-eq  !>(`(unit @da)`[~ fresh])
    !>(refresh-at.+.out)
    (expect !>((lien -.out |=(card=card:agent:gall =(rest card)))))
    (expect !>((lien -.out |=(card=card:agent:gall =(wait card)))))
  ==
::
++  test-zero-refresh-interval-rejected
  =/  state=agent-state  (initial ~zod ~zod)
  %-  expect-fail
  |.  (~(set-refresh-interval logic [~zod now ~zod state]) `@dr`0)
::
++  test-seeds-trigger-bootstrap-wake
  =/  state=agent-state  (initial ~zod ~zod)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~])
  =/  out=[(list card:agent:gall) agent-state]
    ~(bootstrap logic [~zod now ~zod state])
  ;:  weld
    %+  expect-eq  !>(2)
    !>((lent -.out))
    %+  expect-eq  !>(`(unit @da)`[~ +(now)])
    !>(refresh-at.+.out)
  ==
::
++  test-stale-refresh-wake-ignored
  =/  state=agent-state  (initial ~zod ~zod)
  =/  out=[(list card:agent:gall) agent-state]
    (~(run-refresh logic [~zod now ~zod state]) +(now) 0x1234)
  ;:  weld
    %+  expect-eq  !>(`(list card:agent:gall)`~)
    !>(-.out)
    %+  expect-eq  !>(state)
    !>(+.out)
  ==
::
++  test-refresh-completion-schedules-next-wake
  =/  state=agent-state  (initial ~zod ~zod)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~])
  =/  deadline=@da  (add ~h1 now)
  =/  fired=[(list card:agent:gall) agent-state]
    (~(run-refresh logic [~zod deadline ~zod state]) deadline 0x1234)
  =/  id=lookup-id  (need maintenance.+.fired)
  =/  pen=[request-id pending-request]  (first-pending +.fired)
  =/  answered=[(list card:agent:gall) lookup-update]
    (~(receive-nodes logic [~zod +(deadline) ~nec +.fired]) -.pen 0 0)
  =/  continued=[(list card:agent:gall) agent-state]
    (~(continue-refresh logic [~zod +(deadline) ~zod state.+.answered]) id 0xabcd)
  =/  next=@da  (add ~h1 deadline)
  ;:  weld
    %+  expect-eq  !>(2)
    !>((lent -.fired))
    (expect !>((~(has by active.+.fired) id)))
    %+  expect-eq  !>(`(unit lookup-id)`~)
    !>(maintenance.+.continued)
    %+  expect-eq  !>(`(unit @da)`[~ next])
    !>(refresh-at.+.continued)
    %+  expect-eq  !>(1)
    !>((lent -.continued))
    (expect !>(!(~(has by completed.+.continued) id)))
  ==
::
++  test-refresh-completion-starts-next-stale-bucket
  =/  state=agent-state  (initial ~zod ~zod)
  =/  empty=bucket  [now [0 ~] [0 ~]]
  =.  routing.state  [%fork [%leaf empty] [%leaf empty]]
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~])
  =/  deadline=@da  (add ~h1 now)
  =/  first=[(list card:agent:gall) agent-state]
    (~(run-refresh logic [~zod deadline ~zod state]) deadline 0x0)
  =/  first-id=lookup-id  (need maintenance.+.first)
  =/  pen=[request-id pending-request]  (first-pending +.first)
  =/  answered=[(list card:agent:gall) lookup-update]
    (~(receive-nodes logic [~zod +(deadline) ~nec +.first]) -.pen 0 0)
  =/  second=[(list card:agent:gall) agent-state]
    (~(continue-refresh logic [~zod +(deadline) ~zod state.+.answered]) first-id 0x0)
  =/  second-id=lookup-id  (need maintenance.+.second)
  =/  second-lookup=lookup  (need (~(get by active.+.second) second-id))
  ;:  weld
    (expect !>(!=(first-id second-id)))
    (expect !>(?=(~ refresh-at.+.second)))
    (expect !>((~(prefix-match kad [20 20 3 12 %kademlia-urbit-v1]) 1 0x1 target.second-lookup)))
    (expect !>((gth (lent -.second) 0)))
  ==
::
++  test-empty-lookup-completes
  =/  state=agent-state  (initial ~zod ~zod)
  =/  out=[(list card:agent:gall) lookup-update]
    (~(start logic [~zod now ~zod state]) 0v1 0x1234)
  =/  view=(unit lookup-view)
    (~(get-lookup logic [~zod now ~zod state.+.out]) 0v1)
  =/  got=lookup-view  (need view)
  ?>  ?=(%complete -.got)
  ;:  weld
    %+  expect-eq  !>(`(list card:agent:gall)`~)
    !>(-.out)
    %+  expect-eq  !>(`(unit lookup-id)`[~ 0v1])
    !>(completion.+.out)
    %+  expect-eq  !>(`(list node-id)`~)
    !>(contacts.result.got)
  ==
::
++  test-empty-callback-lookup-notifies
  =/  state=agent-state  (initial ~zod ~zod)
  =/  started=[(list card:agent:gall) lookup-update]
    %+  ~(start-for logic [~zod now ~zod state])
      0x1234
    [%sink /lookup-result]
  =/  notified=[(list card:agent:gall) agent-state]
    (~(notify logic [~zod now ~zod state.+.started]) 0v1)
  =/  result=lookup-result  [0x1234 ~]
  =/  notice=lookup-notice  [/lookup-result result]
  =/  expected=card:agent:gall
    :*  %pass  /callback/(scot %uv 0v1)
        %agent  [~zod %sink]
        %poke  %kademlia-result  !>(notice)
    ==
  ;:  weld
    %+  expect-eq  !>(`(list card:agent:gall)`~)
    !>(-.started)
    %+  expect-eq  !>(`(list card:agent:gall)`[expected ~])
    !>(-.notified)
    %+  expect-eq  !>(0)
    !>((lent ~(tap by callbacks.+.notified)))
    %+  expect-eq  !>(0)
    !>((lent ~(tap by completed.+.notified)))
    %+  expect-eq  !>(0v2)
    !>(next-lookup.+.notified)
  ==
::
++  test-notify-targets-one-callback
  =/  state=agent-state  (initial ~zod ~zod)
  =/  one=lookup-result  [0x1 ~]
  =/  two=lookup-result  [0x2 ~]
  =.  completed.state  (~(put by completed.state) 0v1 one)
  =.  completed.state  (~(put by completed.state) 0v2 two)
  =.  callbacks.state  (~(put by callbacks.state) 0v1 [%one /one])
  =.  callbacks.state  (~(put by callbacks.state) 0v2 [%two /two])
  =/  notified=[(list card:agent:gall) agent-state]
    (~(notify logic [~zod now ~zod state]) 0v1)
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent -.notified))
    (expect !>(!(~(has by callbacks.+.notified) 0v1)))
    (expect !>(!(~(has by completed.+.notified) 0v1)))
    (expect !>((~(has by callbacks.+.notified) 0v2)))
    (expect !>((~(has by completed.+.notified) 0v2)))
  ==
::
++  test-seeded-dispatch
  =/  state=agent-state  (initial ~zod ~zod)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~bud ~])
  =/  out=[(list card:agent:gall) lookup-update]
    (~(start logic [~zod now ~zod state]) 0v2 0x1234)
  =/  summary=summary  ~(get-summary logic [~zod now ~zod state.+.out])
  ;:  weld
    %+  expect-eq  !>(4)
    !>((lent -.out))
    %+  expect-eq  !>(2)
    !>(pending.summary)
    %+  expect-eq  !>(1)
    !>(active.summary)
    %+  expect-eq  !>(0v3)
    !>(next-request.state.+.out)
  ==
::
++  test-node-payload-round-trip
  =/  state=agent-state  (initial ~zod ~zod)
  =/  max-node=node-id  (@ux (dec (pow 2 128)))
  =/  ids=(list node-id)  [0x0 max-node 0x1234 0x0 ~]
  =/  payload=[count=@ud packed=@]
    (~(pack-nodes logic [~zod now ~zod state]) ids)
  =/  decoded=(list node-id)
    (~(unpack-nodes logic [~zod now ~zod state]) count.payload packed.payload)
  ;:  weld
    %+  expect-eq  !>(4)
    !>(count.payload)
    %+  expect-eq  !>(ids)
    !>(decoded)
  ==
::
++  test-node-payload-limit
  =/  state=agent-state  (initial ~zod ~zod)
  =/  ids=(list node-id)
    (turn (gulf 0 20) |=(id=@ud (@ux id)))
  =/  payload=[count=@ud packed=@]
    (~(pack-nodes logic [~zod now ~zod state]) ids)
  =/  decoded=(list node-id)
    (~(unpack-nodes logic [~zod now ~zod state]) count.payload packed.payload)
  ;:  weld
    %+  expect-eq  !>(20)
    !>(count.payload)
    %+  expect-eq  !>((scag 20 ids))
    !>(decoded)
  ==
::
++  test-invalid-node-payloads
  =/  state=agent-state  (initial ~zod ~zod)
  =/  engine  [~zod now ~zod state]
  ;:  weld
    (expect !>(!(~(valid-node-payload logic engine) 21 0)))
    (expect !>(!(~(valid-node-payload logic engine) 1 (pow 2 128))))
    (expect !>(!(~(valid-node-payload logic engine) 0 1)))
    (expect !>((~(valid-node-payload logic engine) 20 (dec (pow 2 2.560)))))
  ==
::
++  test-response-admits-only-sender
  =/  state=agent-state  (initial ~zod ~zod)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~])
  =/  started=[(list card:agent:gall) lookup-update]
    (~(start logic [~zod now ~zod state]) 0v3 0x0)
  =/  pen=[request-id pending-request]  (first-pending state.+.started)
  =/  returned=node-id  (node ~bud)
  =/  payload=[count=@ud packed=@]
    (~(pack-nodes logic [~zod +(now) ~nec state.+.started]) [returned ~])
  =/  received=[(list card:agent:gall) lookup-update]
    %+  ~(receive-nodes logic [~zod +(now) ~nec state.+.started])
      -.pen
    [count.payload packed.payload]
  =/  cancellation=card:agent:gall
    [%pass /timeout/(scot %uv -.pen) %arvo %b %rest deadline.+.pen]
  =/  contacts=(list contact)
    (~(contacts kad [20 20 3 12 %kademlia-urbit-v1]) routing.state.+.received)
  =/  contact=contact  (head contacts)
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent contacts))
    %+  expect-eq  !>((node ~nec))
    !>(id.contact)
    %+  expect-eq  !>(1)
    !>((pending-count state.+.received))
    (expect !>((lien -.received |=(got=card:agent:gall =(cancellation got)))))
  ==
::
++  test-wrong-sender-is-ignored
  =/  state=agent-state  (initial ~zod ~zod)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~])
  =/  started=[(list card:agent:gall) lookup-update]
    (~(start logic [~zod now ~zod state]) 0v4 0x0)
  =/  pen=[request-id pending-request]  (first-pending state.+.started)
  =/  received=[(list card:agent:gall) lookup-update]
    (~(receive-nodes logic [~zod +(now) ~bud state.+.started]) -.pen 0 0)
  ;:  weld
    %+  expect-eq  !>(`(list card:agent:gall)`~)
    !>(-.received)
    %+  expect-eq  !>(state.+.started)
    !>(state.+.received)
  ==
::
++  test-invalid-response-fails-request
  =/  state=agent-state  (initial ~zod ~zod)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~])
  =/  started=[(list card:agent:gall) lookup-update]
    (~(start logic [~zod now ~zod state]) 0v22 0x0)
  =/  pen=[request-id pending-request]  (first-pending state.+.started)
  =/  cancellation=card:agent:gall
    [%pass /timeout/(scot %uv -.pen) %arvo %b %rest deadline.+.pen]
  =/  failed=[(list card:agent:gall) lookup-update]
    %+  ~(receive-nodes logic [~zod +(now) ~nec state.+.started])
      -.pen
    [1 (pow 2 128)]
  =/  view=(unit lookup-view)
    (~(get-lookup logic [~zod +(now) ~zod state.+.failed]) 0v22)
  ;:  weld
    %+  expect-eq  !>(0)
    !>((pending-count state.+.failed))
    %+  expect-eq  !>(`(unit lookup-id)`[~ 0v22])
    !>(completion.+.failed)
    (expect !>(?=([~ [%complete *]] view)))
    (expect !>((lien -.failed |=(card=card:agent:gall =(cancellation card)))))
  ==
::
++  test-unsolicited-invalid-response-is-ignored
  =/  state=agent-state  (initial ~zod ~zod)
  =/  received=[(list card:agent:gall) lookup-update]
    (~(receive-nodes logic [~zod +(now) ~nec state]) 0v404 21 0)
  ;:  weld
    %+  expect-eq  !>(`(list card:agent:gall)`~)
    !>(-.received)
    %+  expect-eq  !>(state)
    !>(state.+.received)
  ==
::
++  test-timeout-completes-and-is-stale-safe
  =/  state=agent-state  (initial ~zod ~zod)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~])
  =/  started=[(list card:agent:gall) lookup-update]
    (~(start logic [~zod now ~zod state]) 0v5 0x0)
  =/  pen=[request-id pending-request]  (first-pending state.+.started)
  =/  failed=[(list card:agent:gall) lookup-update]
    (~(fail-request logic [~zod (add ~s10 now) ~zod state.+.started]) -.pen |)
  =/  stale=[(list card:agent:gall) lookup-update]
    (~(fail-request logic [~zod (add ~s20 now) ~zod state.+.failed]) -.pen |)
  =/  view=(unit lookup-view)
    (~(get-lookup logic [~zod (add ~s20 now) ~zod state.+.stale]) 0v5)
  ;:  weld
    %+  expect-eq  !>(0)
    !>((pending-count state.+.failed))
    %+  expect-eq  !>(`(unit lookup-id)`[~ 0v5])
    !>(completion.+.failed)
    %+  expect-eq  !>(`(unit lookup-id)`~)
    !>(completion.+.stale)
    (expect !>(?=([~ [%complete *]] view)))
    %+  expect-eq  !>(state.+.failed)
    !>(state.+.stale)
  ==
::
++  test-poke-failure-cancels-timer
  =/  state=agent-state  (initial ~zod ~zod)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~])
  =/  started=[(list card:agent:gall) lookup-update]
    (~(start logic [~zod now ~zod state]) 0v21 0x0)
  =/  pen=[request-id pending-request]  (first-pending state.+.started)
  =/  cancellation=card:agent:gall
    [%pass /timeout/(scot %uv -.pen) %arvo %b %rest deadline.+.pen]
  =/  failed=[(list card:agent:gall) lookup-update]
    (~(fail-request logic [~zod +(now) ~zod state.+.started]) -.pen &)
  ;:  weld
    %+  expect-eq  !>(`(list card:agent:gall)`[cancellation ~])
    !>(-.failed)
    %+  expect-eq  !>(0)
    !>((pending-count state.+.failed))
  ==
::
++  test-incoming-find-node
  =/  state=agent-state  (initial ~zod ~zod)
  =/  first=[(list card:agent:gall) agent-state]
    (~(receive-find-node logic [~zod now ~nec state]) 0v10 0x0)
  =/  second=[(list card:agent:gall) agent-state]
    (~(receive-find-node logic [~zod +(now) ~bud +.first]) 0v11 (node ~nec))
  =/  contacts=(list contact)
    (~(contacts kad [20 20 3 12 %kademlia-urbit-v1]) routing.+.second)
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent -.first))
    %+  expect-eq  !>(1)
    !>((lent -.second))
    %+  expect-eq  !>(2)
    !>((lent contacts))
  ==
::
++  test-forget-result
  =/  state=agent-state  (initial ~zod ~zod)
  =/  completed=[(list card:agent:gall) lookup-update]
    (~(start logic [~zod now ~zod state]) 0v12 0x1)
  =/  forgotten=agent-state
    (~(forget logic [~zod now ~zod state.+.completed]) 0v12)
  %+  expect-eq  !>(`(unit lookup-view)`~)
  !>((~(get-lookup logic [~zod now ~zod forgotten]) 0v12))
--
