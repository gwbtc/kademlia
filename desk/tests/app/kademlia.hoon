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
++  get-state
  |=  saved=vase
  ^-  agent-state
  =/  app=kademlia-saved-state  !<(kademlia-saved-state saved)
  state.app
::
++  test-init
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.4)
  =/  out  on-init:~(. agent bol)
  =/  saved=agent-state  (get-state on-save:+.out)
  ;:  weld
    %+  expect-eq  !>(3)
    !>((lent -.out))
    %+  expect-eq  !>(0v1)
    !>(next-request.saved)
    %+  expect-eq  !>(~m5)
    !>(request-timeout.settings.saved)
    %+  expect-eq  !>(~h1)
    !>(refresh-interval.settings.saved)
    %+  expect-eq  !>(`(unit @da)`[~ (add ~h1 now.bol)])
    !>(refresh-at.saved)
  ==
::
++  test-load-recreates-refresh-wake
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  saved=kademlia-saved-state  !<(kademlia-saved-state on-save:+.initialized)
  =/  loaded  (on-load:~(. agent bol) !>(saved))
  =/  restored=agent-state  (get-state on-save:+.loaded)
  ;:  weld
    %+  expect-eq  !>(3)
    !>((lent -.loaded))
    %+  expect-eq  !>(state.saved)
    !>(restored)
  ==
::
++  test-local-timeout-command-and-scry
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  command=command  [%set-request-timeout ~m1]
  =/  out  (on-poke:+.initialized %kademlia-command !>(command))
  =/  saved=agent-state  (get-state on-save:+.out)
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
++  test-verbosity-command-scry-and-load
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  initial=kademlia-saved-state
    !<(kademlia-saved-state on-save:+.initialized)
  =/  command=command  [%set-verbosity %debug]
  =/  changed  (on-poke:+.initialized %kademlia-command !>(command))
  =/  saved=kademlia-saved-state  !<(kademlia-saved-state on-save:+.changed)
  =/  peek=(unit (unit cage))  (on-peek:+.changed /x/verbosity)
  =/  got=verbosity  !<(verbosity q:(need (need peek)))
  =/  loaded  (on-load:~(. agent bol) !>(saved))
  =/  restored=kademlia-saved-state  !<(kademlia-saved-state on-save:+.loaded)
  ;:  weld
    %+  expect-eq  !>(%off)
    !>(verbosity.initial)
    %+  expect-eq  !>(%debug)
    !>(got)
    %+  expect-eq  !>(%debug)
    !>(verbosity.restored)
  ==
::
++  test-local-refresh-command-and-scry
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  command=command  [%set-refresh-interval ~m30]
  =/  out  (on-poke:+.initialized %kademlia-command !>(command))
  =/  saved=agent-state  (get-state on-save:+.out)
  =/  peek=(unit (unit cage))  (on-peek:+.out /x/settings)
  =/  result=cage  (need (need peek))
  =/  got=settings  !<(settings q.result)
  ;:  weld
    %+  expect-eq  !>(~m30)
    !>(refresh-interval.settings.saved)
    %+  expect-eq  !>(settings.saved)
    !>(got)
  ==
::
++  test-local-seed-command-and-scry
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  command=command  [%set-seeds [~nec ~nec ~zod ~]]
  =/  out  (on-poke:+.initialized %kademlia-command !>(command))
  =/  saved=agent-state  (get-state on-save:+.out)
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
  =/  saved=agent-state  (get-state on-save:+.out)
  ;:  weld
    %+  expect-eq  !>(3)
    !>((lent -.out))
    %+  expect-eq  !>(1)
    !>((lent (~(contacts kad [20 20 3 12 %kademlia-urbit-v1]) routing.saved)))
  ==
::
++  test-oversized-local-lookup-id-nacks
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  command=command  [%find ;;(@uv (pow 2 64)) 0x1234]
  %-  expect-fail
  |.  (on-poke:+.initialized %kademlia-command !>(command))
::
++  test-oversized-peer-request-id-is-ignored
  =/  bol=bowl:gall  (bowl ~zod ~nec ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  before=agent-state  (get-state on-save:+.initialized)
  =/  message=peer-message
    [%find-node %kademlia-v1 ;;(@uv (pow 2 64)) 0x1234]
  =/  out  (on-poke:+.initialized %kademlia-message !>(message))
  =/  after=agent-state  (get-state on-save:+.out)
  ;:  weld
    %+  expect-eq  !>(2)
    !>((lent -.out))
    %+  expect-eq  !>(before)
    !>(after)
  ==
::
++  test-wrong-protocol-ignored
  =/  bol=bowl:gall  (bowl ~zod ~nec ~2026.8.4)
  =/  initialized  on-init:~(. agent bol)
  =/  before=agent-state  (get-state on-save:+.initialized)
  =/  message=peer-message  [%find-node %other 0v7 0x1234]
  =/  out  (on-poke:+.initialized %kademlia-message !>(message))
  =/  after=agent-state  (get-state on-save:+.out)
  ;:  weld
    %+  expect-eq  !>(2)
    !>((lent -.out))
    %+  expect-eq  !>(before)
    !>(after)
  ==
--
