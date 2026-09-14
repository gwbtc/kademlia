/-  *bounded-poke
/+  delivery=bounded-poke, *test
|%
++  now  ~2026.9.2..12.00.00
::
++  note
  |=  [peer=@p value=@ud]
  ^-  note:agent:gall
  [%agent [peer %sink] %poke %noun !>(value)]
::
++  initial
  ^-  delivery-state
  ~(init delivery [now *delivery-state])
::
++  peer-state
  |=  [peer=@p state=delivery-state]
  ^-  peer-delivery
  (need (~(get by peers.state) peer))
::
++  test-first-poke-sends-immediately
  =/  out=[delivery-id delivery-update]
    (~(enqueue delivery [now initial]) ~nec (add ~m1 now) [%request 0v1] (note ~nec 1))
  =/  remote=card:agent:gall
    [%pass /delivery/~nec/0 %agent [~nec %sink] %poke %noun !>(1)]
  =/  got=peer-delivery  (peer-state ~nec state.+.out)
  ;:  weld
    %+  expect-eq  !>(0)
    !>(-.out)
    %+  expect-eq  !>(~[remote])
    !>(cards.+.out)
    %+  expect-eq  !>(`(unit active-delivery)`[~ [0 [%request 0v1]]])
    !>(active.got)
    (expect !>(?&(?=(~ responses.got) ?=(~ requests.got) ?=(~ wake.got))))
  ==
::
++  test-responses-promote-before-requests
  =/  first=[delivery-id delivery-update]
    (~(enqueue delivery [now initial]) ~nec (add ~m1 now) [%request 0v1] (note ~nec 1))
  =/  second=[delivery-id delivery-update]
    (~(enqueue delivery [now state.+.first]) ~nec (add ~m1 now) [%request 0v2] (note ~nec 2))
  =/  third=[delivery-id delivery-update]
    (~(enqueue delivery [now state.+.second]) ~nec (add ~m1 now) [%response 0v9] (note ~nec 9))
  =/  before=delivery-summary
    ~(summary delivery [now state.+.third])
  =/  acked=delivery-update
    (~(acknowledge delivery [now state.+.third]) ~nec -.first ~)
  =/  got=peer-delivery  (peer-state ~nec state.acked)
  =/  after=delivery-summary
    ~(summary delivery [now state.acked])
  ;:  weld
    %+  expect-eq  !>(`delivery-summary`[1 1 1 1 0 0])
    !>(before)
    %+  expect-eq  !>(`(unit delivery-ack)`[~ [[%request 0v1] ~]])
    !>(acked.acked)
    %+  expect-eq  !>(`(unit active-delivery)`[~ [-.third [%response 0v9]]])
    !>(active.got)
    %+  expect-eq  !>(1)
    !>((lent requests.got))
    (expect !>(?=(~ responses.got)))
    %+  expect-eq  !>(`delivery-summary`[1 1 0 1 0 0])
    !>(after)
  ==
::
++  test-queued-deliveries-expire-while-active-remains
  =/  first=[delivery-id delivery-update]
    (~(enqueue delivery [now initial]) ~nec (add ~m1 now) [%request 0v1] (note ~nec 1))
  =/  deadline=@da  (add ~s5 now)
  =/  second=[delivery-id delivery-update]
    (~(enqueue delivery [now state.+.first]) ~nec deadline [%request 0v2] (note ~nec 2))
  =/  expired=delivery-update
    (~(expire delivery [deadline state.+.second]) ~nec deadline)
  =/  got=peer-delivery  (peer-state ~nec state.expired)
  =/  summary=delivery-summary
    ~(summary delivery [deadline state.expired])
  ;:  weld
    %+  expect-eq  !>(~[[%request 0v2]])
    !>(expired.expired)
    %+  expect-eq  !>(`(unit active-delivery)`[~ [-.first [%request 0v1]]])
    !>(active.got)
    (expect !>(?&(?=(~ requests.got) ?=(~ wake.got))))
    %+  expect-eq  !>(`delivery-summary`[1 1 0 0 1 0])
    !>(summary)
  ==
::
++  test-cancel-never-releases-active-delivery
  =/  first=[delivery-id delivery-update]
    (~(enqueue delivery [now initial]) ~nec (add ~m1 now) [%request 0v1] (note ~nec 1))
  =/  canceled=delivery-update
    (~(cancel delivery [now state.+.first]) ~nec -.first)
  =/  got=peer-delivery  (peer-state ~nec state.canceled)
  %+  expect-eq  !>(`(unit active-delivery)`[~ [-.first [%request 0v1]]])
  !>(active.got)
::
++  test-stale-ack-is-a-no-op
  =/  first=[delivery-id delivery-update]
    (~(enqueue delivery [now initial]) ~nec (add ~m1 now) [%request 0v1] (note ~nec 1))
  =/  stale=delivery-update
    (~(acknowledge delivery [now state.+.first]) ~nec +(-.first) ~)
  ;:  weld
    %+  expect-eq  !>(`(list card:agent:gall)`~)
    !>(cards.stale)
    %+  expect-eq  !>(`(unit delivery-ack)`~)
    !>(acked.stale)
    %+  expect-eq  !>(state.+.first)
    !>(state.stale)
  ==
::
++  test-reset-keeps-active-and-discards-queues
  =/  first=[delivery-id delivery-update]
    (~(enqueue delivery [now initial]) ~nec (add ~m1 now) [%request 0v1] (note ~nec 1))
  =/  second=[delivery-id delivery-update]
    (~(enqueue delivery [now state.+.first]) ~nec (add ~m1 now) [%request 0v2] (note ~nec 2))
  =/  third=[delivery-id delivery-update]
    (~(enqueue delivery [now state.+.second]) ~nec (add ~m1 now) [%response 0v9] (note ~nec 9))
  =/  reset=[(list card:agent:gall) delivery-state]
    ~(reset delivery [now state.+.third])
  =/  got=peer-delivery  (peer-state ~nec +.reset)
  =/  summary=delivery-summary
    ~(summary delivery [now +.reset])
  ;:  weld
    %+  expect-eq  !>(`(unit active-delivery)`[~ [-.first [%request 0v1]]])
    !>(active.got)
    (expect !>(?&(?=(~ responses.got) ?=(~ requests.got) ?=(~ wake.got))))
    %+  expect-eq  !>(1)
    !>((lent -.reset))
    %+  expect-eq  !>(`delivery-summary`[1 1 0 0 0 0])
    !>(summary)
  ==
--
