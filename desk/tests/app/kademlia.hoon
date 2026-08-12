/-  *kademlia, *kademlia-agent
/+  kad=kademlia, *test
/=  agent  /app/kademlia
|%
++  bowl
  |=  [our=@p src=@p now=@da]
  ^-  bowl:gall
  %*  .  *bowl:gall
    our  our
    src  src
    dap  %kademlia
    now  now
  ==
::
++  test-init
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.4)
  =/  out  on-init:~(. agent bol)
  =/  saved=state-2  !<(state-2 on-save:+.out)
  ;:  weld
    %+  expect-eq  !>(2)
    !>((lent -.out))
    %+  expect-eq  !>(0v1)
    !>(next-request.saved)
    %+  expect-eq  !>(~m5)
    !>(request-timeout.settings.saved)
  ==
::
++  test-state-zero-migration
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.4)
  =/  old=state-0
    [%0 ~(empty-table kad [20 20 3 12 %kademlia-urbit-v1]) ~ ~ ~ ~ 0v42]
  =/  out  (on-load:~(. agent bol) !>(old))
  =/  saved=state-2  !<(state-2 on-save:+.out)
  ;:  weld
    %+  expect-eq  !>(0v42)
    !>(next-request.saved)
    %+  expect-eq  !>(~m5)
    !>(request-timeout.settings.saved)
  ==
::
++  test-state-one-migration
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.4)
  =/  old=state-1
    :*  %1
        ~(empty-table kad [20 20 3 12 %kademlia-urbit-v1])
        ~  ~  ~  ~  0v42  [~s45]
    ==
  =/  out  (on-load:~(. agent bol) !>(old))
  =/  saved=state-2  !<(state-2 on-save:+.out)
  ;:  weld
    %+  expect-eq  !>(0v42)
    !>(next-request.saved)
    %+  expect-eq  !>(~s45)
    !>(request-timeout.settings.saved)
    %+  expect-eq  !>(0v1)
    !>(next-lookup.saved)
  ==
::
++  test-local-timeout-command-and-scry
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  command=command  [%set-request-timeout ~m1]
  =/  out  (on-poke:+.initialized %kademlia-command !>(command))
  =/  saved=state-2  !<(state-2 on-save:+.out)
  =/  peek=(unit (unit cage))  (on-peek:+.out /x/settings)
  =/  result=cage  (need (need peek))
  =/  got=settings  !<(settings q.result)
  ;:  weld
    %+  expect-eq  !>(~m1)
    !>(request-timeout.settings.saved)
    %+  expect-eq  !>(settings.saved)
    !>(got)
  ==
::
++  test-local-seed-command-and-scry
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  command=command  [%set-seeds [~nec ~nec ~zod ~]]
  =/  out  (on-poke:+.initialized %kademlia-command !>(command))
  =/  saved=state-2  !<(state-2 on-save:+.out)
  =/  peek=(unit (unit cage))  (on-peek:+.out /x/seeds)
  =/  result=cage  (need (need peek))
  =/  seeds=(list node-id)  !<((list node-id) q.result)
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent ~(tap in seeds.saved)))
    %+  expect-eq  !>(1)
    !>((lent seeds))
  ==
::
++  test-remote-command-rejected
  =/  bol=bowl:gall  (bowl ~zod ~nec ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  command=command  [%set-seeds [~bud ~]]
  %-  expect-fail
  |.  (on-poke:+.initialized %kademlia-command !>(command))
::
++  test-empty-find-result-scry
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  command=command  [%find 0v22 0x1234]
  =/  out  (on-poke:+.initialized %kademlia-command !>(command))
  =/  path=path  /x/lookup/(scot %uv 0v22)
  =/  peek=(unit (unit cage))  (on-peek:+.out path)
  =/  result=cage  (need (need peek))
  =/  view=lookup-view  !<(lookup-view q.result)
  ?>  ?=(%complete -.view)
  ;:  weld
    %+  expect-eq  !>(2)
    !>((lent -.out))
    %+  expect-eq  !>(0x1234)
    !>(target.result.view)
    %+  expect-eq  !>(`(list node-id)`~)
    !>(contacts.result.view)
  ==
::
++  test-lookup-prefix-scry
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  peek=(unit (unit cage))  (on-peek:+.initialized /x/lookup)
  %+  expect-eq  !>(`(unit (unit cage))`[~ ~])
  !>(peek)
::
++  test-root-prefix-scry
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  peek=(unit (unit cage))  (on-peek:+.initialized /x)
  %+  expect-eq  !>(`(unit (unit cage))`[~ ~])
  !>(peek)
::
++  test-peer-find-node
  =/  bol=bowl:gall  (bowl ~zod ~nec ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  message=peer-message  [%find-node %kademlia-v1 0v7 0x1234]
  =/  out  (on-poke:+.initialized %kademlia-message !>(message))
  =/  saved=state-2  !<(state-2 on-save:+.out)
  ;:  weld
    %+  expect-eq  !>(3)
    !>((lent -.out))
    %+  expect-eq  !>(1)
    !>((lent (~(contacts kad [20 20 3 12 %kademlia-urbit-v1]) routing.saved)))
  ==
::
++  test-wrong-protocol-ignored
  =/  bol=bowl:gall  (bowl ~zod ~nec ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  before=state-2  !<(state-2 on-save:+.initialized)
  =/  message=peer-message  [%find-node %other 0v7 0x1234]
  =/  out  (on-poke:+.initialized %kademlia-message !>(message))
  =/  after=state-2  !<(state-2 on-save:+.out)
  ;:  weld
    %+  expect-eq  !>(2)
    !>((lent -.out))
    %+  expect-eq  !>(before)
    !>(after)
  ==
--
