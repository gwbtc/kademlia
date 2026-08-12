/-  *kademlia, *kademlia-agent, *content-routing, *content-routing-agent
/+  cr=content-routing, *test
/=  agent  /app/content-routing
|%
++  now  ~2026.8.10..12.00.00
::
++  bowl
  |=  [our=@p src=@p]
  ^-  bowl:gall
  %*  .  *bowl:gall
    our  our
    src  src
    dap  %content-routing
    now  now
  ==
::
++  test-init-and-settings-scry
  =/  bol=bowl:gall  (bowl ~zod ~zod)
  =/  out  on-init:~(. agent bol)
  =/  saved=content-state-0  !<(content-state-0 on-save:+.out)
  =/  peek=(unit (unit cage))  (on-peek:+.out /x/settings)
  =/  got=content-config  !<(content-config q:(need (need peek)))
  ;:  weld
    %+  expect-eq  !>(3)
    !>((lent -.out))
    %+  expect-eq  !>(config.saved)
    !>(got)
    %+  expect-eq  !>((add ~h12 now))
    !>(refresh-at.saved)
  ==
::
++  test-query-callback-completes
  =/  bol=bowl:gall  (bowl ~zod ~zod)
  =/  initialized  on-init:~(. agent bol)
  =/  content=digest  (digest-cask:cr `(cask)`[%noun 42])
  =/  command=content-command  [%find-providers 0v7 content]
  =/  started  (on-poke:+.initialized %content-routing-command !>(command))
  =/  saved=content-state-0  !<(content-state-0 on-save:+.started)
  =/  notice=lookup-notice  [/operation/(scot %uv 0v7) [(provider-key:cr content) ~]]
  =/  finished  (on-poke:+.started %kademlia-result !>(notice))
  =/  path=path  /x/operation/(scot %uv 0v7)
  =/  peek=(unit (unit cage))  (on-peek:+.finished path)
  =/  view=operation-view  !<(operation-view q:(need (need peek)))
  ?>  ?=(%complete -.view)
  ?>  ?=(%providers -.value.view)
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent ~(tap by active.saved)))
    %+  expect-eq  !>(`providers`~)
    !>(records.selection.value.value.view)
  ==
--
