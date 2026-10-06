/-  *bounded-poke
/+  delivery=bounded-poke, *test
|%
++  now  ~2026.9.2..12.00.00
::
++  note
  |=  [peer=@p value=@ud]
  ^-  delivery-note
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
++  test-response-queue-is-capped-at-thirty-two
  =/  first=[delivery-id delivery-update]
    (~(enqueue delivery [now initial]) ~nec (add ~m1 now) [%request 0v1] (note ~nec 1))
  =/  filled=delivery-state
    =/  left=@ud  32
    =/  state=delivery-state  state.+.first
    |-
    ?:  =(0 left)  state
    =/  id=@uv  ;;(@uv left)
    =/  sent=[delivery-id delivery-update]
      (~(enqueue delivery [now state]) ~nec (add ~m1 now) [%response id] (note ~nec left))
    $(left (dec left), state state.+.sent)
  =/  overflow=[delivery-id delivery-update]
    (~(enqueue delivery [now filled]) ~nec (add ~m1 now) [%response 0v99] (note ~nec 99))
  =/  summary=delivery-summary
    ~(summary delivery [now state.+.overflow])
  ;:  weld
    %+  expect-eq  !>(`delivery-summary`[1 1 32 0 0 1])
    !>(summary)
    %+  expect-eq  !>(0)
    !>((lent cards.+.overflow))
    %+  expect-eq  !>(0)
    !>((lent expired.+.overflow))
  ==
::
++  test-response-cap-prunes-expired-before-dropping
  =/  first=[delivery-id delivery-update]
    (~(enqueue delivery [now initial]) ~nec (add ~m1 now) [%request 0v1] (note ~nec 1))
  =/  deadline=@da  (add ~s1 now)
  =/  filled=delivery-state
    =/  left=@ud  32
    =/  state=delivery-state  state.+.first
    |-
    ?:  =(0 left)  state
    =/  id=@uv  ;;(@uv left)
    =/  sent=[delivery-id delivery-update]
      (~(enqueue delivery [now state]) ~nec deadline [%response id] (note ~nec left))
    $(left (dec left), state state.+.sent)
  =/  later=@da  (add ~s2 now)
  =/  replacement=[delivery-id delivery-update]
    (~(enqueue delivery [later filled]) ~nec (add ~m1 later) [%response 0v99] (note ~nec 99))
  =/  summary=delivery-summary
    ~(summary delivery [later state.+.replacement])
  ;:  weld
    %+  expect-eq  !>(`delivery-summary`[1 1 1 0 32 0])
    !>(summary)
    %+  expect-eq  !>(32)
    !>((lent expired.+.replacement))
  ==
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
::
++  test-load-keeps-a-current-queue
  =/  first=[delivery-id delivery-update]
    (~(enqueue delivery [now initial]) ~nec (add ~m1 now) [%request 0v1] (note ~nec 1))
  =/  second=[delivery-id delivery-update]
    (~(enqueue delivery [now state.+.first]) ~nec (add ~m1 now) [%request 0v2] (note ~nec 2))
  =/  sav=vase  !>([state=[seeds=~ outbound=state.+.second] verbosity=~])
  %+  expect-eq  !>(state.+.second)
  (slap (load:delivery sav ~[%outbound %state]) [%wing ~[%outbound %state]])
::
++  test-load-drops-a-stale-queue
  =/  queued
    :*  id=1
        peer=~nec
        deadline=(add ~m1 now)
        context=`delivery-context`[%request 0v2]
        note=`note:agent:gall`(note ~nec 2)
    ==
  =/  peers
    %-  my
    :~  [~nec `[0 `delivery-context`[%request 0v1]] ~ ~[queued] `(add ~m1 now)]
        [~bud ~ ~[queued] ~ `(add ~m1 now)]
    ==
  =/  sav=vase  !>([state=[seeds=~ outbound=[2 peers 3 4]] verbosity=~])
  =/  got
    !<  [state=[seeds=~ outbound=delivery-state] verbosity=~]
    (load:delivery sav ~[%outbound %state])
  %+  expect-eq
    !>  ^-  delivery-state
    [2 (my [~nec `[0 %request 0v1] ~ ~ ~] ~) 3 4]
  !>(outbound.state.got)
--
