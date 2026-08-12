/-  *kademlia, *kademlia-agent
/+  logic=kademlia-agent-logic, kad=kademlia, *test
|%
++  now  ~2026.8.4..12.00.00
::
++  initial
  |=  [our=@p src=@p]
  ^-  state-2
  ~(init logic [our now src *state-2])
::
++  node
  |=  ship=@p
  ^-  node-id
  ~(self-id logic [ship now ship *state-2])
::
++  pending-count
  |=  state=state-2
  (lent ~(tap by pending.state))
::
++  first-pending
  |=  state=state-2
  ^-  [request-id pending-request]
  (head ~(tap by pending.state))
::
++  test-init-and-seeds
  =/  state=state-2  (initial ~zod ~zod)
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
    (expect !>(!(~(has in seeds.state) (node ~zod))))
  ==
::
++  test-request-timeout-setting
  =/  state=state-2  (initial ~zod ~zod)
  =.  state  (~(set-request-timeout logic [~zod now ~zod state]) ~s45)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~])
  =/  started=[(list card:agent:gall) state-2]
    (~(start logic [~zod now ~zod state]) 0v20 0x1234)
  =/  pen=[request-id pending-request]  (first-pending +.started)
  ;:  weld
    %+  expect-eq  !>(~s45)
    !>(request-timeout.settings.+.started)
    %+  expect-eq  !>((add ~s45 now))
    !>(deadline.+.pen)
  ==
::
++  test-zero-request-timeout-rejected
  =/  state=state-2  (initial ~zod ~zod)
  %-  expect-fail
  |.  (~(set-request-timeout logic [~zod now ~zod state]) `@dr`0)
::
++  test-empty-lookup-completes
  =/  state=state-2  (initial ~zod ~zod)
  =/  out=[(list card:agent:gall) state-2]
    (~(start logic [~zod now ~zod state]) 0v1 0x1234)
  =/  view=(unit lookup-view)
    (~(get-lookup logic [~zod now ~zod +.out]) 0v1)
  =/  got=lookup-view  (need view)
  ?>  ?=(%complete -.got)
  ;:  weld
    %+  expect-eq  !>(`(list card:agent:gall)`~)
    !>(-.out)
    %+  expect-eq  !>(`(list node-id)`~)
    !>(contacts.result.got)
  ==
::
++  test-empty-callback-lookup-notifies
  =/  state=state-2  (initial ~zod ~zod)
  =/  started=[(list card:agent:gall) state-2]
    %+  ~(start-for logic [~zod now ~zod state])
      0x1234
    [%sink /lookup-result]
  =/  notified=[(list card:agent:gall) state-2]
    ~(notify logic [~zod now ~zod +.started])
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
++  test-seeded-dispatch
  =/  state=state-2  (initial ~zod ~zod)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~bud ~])
  =/  out=[(list card:agent:gall) state-2]
    (~(start logic [~zod now ~zod state]) 0v2 0x1234)
  =/  summary=summary  ~(get-summary logic [~zod now ~zod +.out])
  ;:  weld
    %+  expect-eq  !>(4)
    !>((lent -.out))
    %+  expect-eq  !>(2)
    !>(pending.summary)
    %+  expect-eq  !>(1)
    !>(active.summary)
    %+  expect-eq  !>(0v3)
    !>(next-request.+.out)
  ==
::
++  test-response-admits-only-sender
  =/  state=state-2  (initial ~zod ~zod)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~])
  =/  started=[(list card:agent:gall) state-2]
    (~(start logic [~zod now ~zod state]) 0v3 0x0)
  =/  pen=[request-id pending-request]  (first-pending +.started)
  =/  returned=node-id  (node ~bud)
  =/  received=[(list card:agent:gall) state-2]
    (~(receive-nodes logic [~zod +(now) ~nec +.started]) -.pen [returned ~])
  =/  cancellation=card:agent:gall
    [%pass /timeout/(scot %uv -.pen) %arvo %b %rest deadline.+.pen]
  =/  contacts=(list contact)
    (~(contacts kad [20 20 3 12 %kademlia-urbit-v1]) routing.+.received)
  =/  contact=contact  (head contacts)
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent contacts))
    %+  expect-eq  !>((node ~nec))
    !>(id.contact)
    %+  expect-eq  !>(1)
    !>((pending-count +.received))
    (expect !>((lien -.received |=(got=card:agent:gall =(cancellation got)))))
  ==
::
++  test-wrong-sender-is-ignored
  =/  state=state-2  (initial ~zod ~zod)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~])
  =/  started=[(list card:agent:gall) state-2]
    (~(start logic [~zod now ~zod state]) 0v4 0x0)
  =/  pen=[request-id pending-request]  (first-pending +.started)
  =/  received=[(list card:agent:gall) state-2]
    (~(receive-nodes logic [~zod +(now) ~bud +.started]) -.pen ~)
  ;:  weld
    %+  expect-eq  !>(`(list card:agent:gall)`~)
    !>(-.received)
    %+  expect-eq  !>(+.started)
    !>(+.received)
  ==
::
++  test-timeout-completes-and-is-stale-safe
  =/  state=state-2  (initial ~zod ~zod)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~])
  =/  started=[(list card:agent:gall) state-2]
    (~(start logic [~zod now ~zod state]) 0v5 0x0)
  =/  pen=[request-id pending-request]  (first-pending +.started)
  =/  failed=[(list card:agent:gall) state-2]
    (~(fail-request logic [~zod (add ~s10 now) ~zod +.started]) -.pen |)
  =/  stale=[(list card:agent:gall) state-2]
    (~(fail-request logic [~zod (add ~s20 now) ~zod +.failed]) -.pen |)
  =/  view=(unit lookup-view)
    (~(get-lookup logic [~zod (add ~s20 now) ~zod +.stale]) 0v5)
  ;:  weld
    %+  expect-eq  !>(0)
    !>((pending-count +.failed))
    (expect !>(?=([~ [%complete *]] view)))
    %+  expect-eq  !>(+.failed)
    !>(+.stale)
  ==
::
++  test-poke-failure-cancels-timer
  =/  state=state-2  (initial ~zod ~zod)
  =.  state  (~(set-seeds logic [~zod now ~zod state]) [~nec ~])
  =/  started=[(list card:agent:gall) state-2]
    (~(start logic [~zod now ~zod state]) 0v21 0x0)
  =/  pen=[request-id pending-request]  (first-pending +.started)
  =/  cancellation=card:agent:gall
    [%pass /timeout/(scot %uv -.pen) %arvo %b %rest deadline.+.pen]
  =/  failed=[(list card:agent:gall) state-2]
    (~(fail-request logic [~zod +(now) ~zod +.started]) -.pen &)
  ;:  weld
    %+  expect-eq  !>(`(list card:agent:gall)`[cancellation ~])
    !>(-.failed)
    %+  expect-eq  !>(0)
    !>((pending-count +.failed))
  ==
::
++  test-incoming-find-node
  =/  state=state-2  (initial ~zod ~zod)
  =/  first=[(list card:agent:gall) state-2]
    (~(receive-find-node logic [~zod now ~nec state]) 0v10 0x0)
  =/  second=[(list card:agent:gall) state-2]
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
  =/  state=state-2  (initial ~zod ~zod)
  =/  completed=[(list card:agent:gall) state-2]
    (~(start logic [~zod now ~zod state]) 0v12 0x1)
  =/  forgotten=state-2
    (~(forget logic [~zod now ~zod +.completed]) 0v12)
  %+  expect-eq  !>(`(unit lookup-view)`~)
  !>((~(get-lookup logic [~zod now ~zod forgotten]) 0v12))
--
