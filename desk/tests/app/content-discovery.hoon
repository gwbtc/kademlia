/-  *kademlia, *kademlia-agent, *content-routing, *content-discovery, *content-discovery-agent, *bounded-poke
/+  discovery=content-discovery, *test
/=  agent  /app/content-discovery
|%
++  now  ~2026.8.30
++  bowl
  |=  [our=@p src=@p]
  ^-  bowl:gall
  %*  .  *bowl:gall
    our  our
    src  src
    dap  %content-discovery
    now  now
  ==
::
++  get-state
  |=  saved=vase
  ^-  discovery-state
  =/  app=discovery-saved-state  !<(discovery-saved-state saved)
  state.app
::
++  test-init-and-settings
  =/  out  on-init:~(. agent (bowl ~zod ~zod))
  =/  state=discovery-state  (get-state on-save:+.out)
  =/  peek=(unit (unit cage))  (on-peek:+.out /x/settings)
  =/  got=discovery-config  !<(discovery-config q:(need (need peek)))
  =/  delivery-peek=(unit (unit cage))  (on-peek:+.out /x/delivery)
  =/  delivery=delivery-summary
    !<(delivery-summary q:(need (need delivery-peek)))
  ;:  weld
    %+  expect-eq  !>(config.state)
    !>(got)
    %+  expect-eq  !>(0)
    !>((lent ~(tap by active.state)))
    %+  expect-eq  !>(*delivery-summary)
    !>(delivery)
  ==
::
++  test-browse-completes-and-calls-back
  =/  initialized  on-init:~(. agent (bowl ~zod ~zod))
  =/  observed
    %+  on-poke:+.initialized  %content-discovery-command
    !>(`discovery-command`[%observe 0v7 %sink /topic/reply])
  =/  started
    %+  on-poke:+.observed  %content-discovery-command
    !>(`discovery-command`[%browse 0v7 ~[%software]])
  =/  notice=lookup-notice
    [/operation/(scot %uv 0v7) [(topic-key:discovery ~[%software]) ~]]
  =/  finished  (on-poke:+.started %kademlia-result !>(notice))
  =/  state=discovery-state  (get-state on-save:+.finished)
  =/  result=discovery-result
    (need (~(get by completed-public.state) 0v7))
  ;:  weld
    (expect !>(?=(%topic -.result)))
    %+  expect-eq  !>(0)
    !>((lent ~(tap by callbacks.state)))
    (expect !>((gth (lent -.finished) 0)))
  ==
::
::  Kept as a compile-time exercise for the batch transition.  Executing this
::  arm needs live Jael signing, which is covered by the Aqua network test.
++  exercise-advertisement-batch-publishes-leaf-and-edges
  =/  initialized  on-init:~(. agent (bowl ~zod ~zod))
  =/  observed
    %+  on-poke:+.initialized  %content-discovery-command
    !>(`discovery-command`[%observe 0v10 %sink /advertise/reply])
  =/  command=discovery-command
    [%advertise 0v10 ~[%software %urbit %hoon] %demo 0v42 2 1 ~2100.1.1]
  =/  started  (on-poke:+.observed %content-discovery-command !>(command))
  =/  state=discovery-state  (get-state on-save:+.started)
  =/  one=operation  (need (~(get by active.state) 0v1))
  =/  two=operation  (need (~(get by active.state) 0v2))
  =/  three=operation  (need (~(get by active.state) 0v3))
  =/  first=lookup-notice
    [/operation/(scot %uv 0v1) [0x0 ~]]
  =/  after-one  (on-poke:+.started %kademlia-result !>(first))
  =/  second=lookup-notice
    [/operation/(scot %uv 0v2) [0x0 ~]]
  =/  after-two  (on-poke:+.after-one %kademlia-result !>(second))
  =/  third=lookup-notice
    [/operation/(scot %uv 0v3) [0x0 ~]]
  =/  finished  (on-poke:+.after-two %kademlia-result !>(third))
  =/  final=discovery-state  (get-state on-save:+.finished)
  =/  result=discovery-result
    (need (~(get by completed-public.final) 0v10))
  ?>  ?=(%advertised -.result)
  ;:  weld
    %+  expect-eq  !>(3)
    !>((lent ~(tap by origins.state)))
    %+  expect-eq  !>(3)
    !>((lent records.value.result))
    %+  expect-eq  !>(0)
    !>((lent ~(tap by batches.final)))
    %+  expect-eq  !>(0)
    !>((lent ~(tap by task-owner.final)))
    %+  expect-eq  !>(0)
    !>((lent ~(tap by callbacks.final)))
  ==
::
++  test-reset-clears-state
  =/  initialized  on-init:~(. agent (bowl ~zod ~zod))
  =/  started
    %+  on-poke:+.initialized  %content-discovery-command
    !>(`discovery-command`[%browse 0v1 ~[%software]])
  =/  reset
    %+  on-poke:+.started  %content-discovery-command
    !>(`discovery-command`[%reset ~])
  =/  state=discovery-state  (get-state on-save:+.reset)
  ;:  weld
    %+  expect-eq  !>(0)
    !>((lent ~(tap by active.state)))
    %+  expect-eq  !>(0)
    !>((lent ~(tap by origins.state)))
  ==
--
