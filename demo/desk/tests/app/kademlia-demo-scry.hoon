::  Focused tests for the demo's Gall remote-scry publication.
::
/-  *content-routing, *content-routing-agent, *kademlia, *kademlia-demo
/+  kad=kademlia, cr=content-routing, demo=kademlia-demo, *test
/=  agent  /app/kademlia-demo
|%
++  bowl
  |=  [our=@p src=@p now=@da]
  ^-  bowl:gall
  %*  .  *bowl:gall
    our  our
    src  src
    dap  %kademlia-demo
    now  now
  ==
::
++  has-card
  |=  [needle=card:agent:gall hay=(list card:agent:gall)]
  ^-  ?
  ?~  hay  %.n
  ?|  =(needle i.hay)
      $(hay t.hay)
  ==
::
++  get-state
  |=  saved=vase
  !<(demo-state saved)
::
++  test-scry-publication-grows-an-exact-resource
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.21)
  =/  initialized  on-init:~(. agent bol)
  =/  res=resource  (make-resource:demo 42 1.024 'text/plain')
  =/  created
    %-  on-poke:+.initialized
    :-  %kademlia-demo-command
    !>(`demo-command`[%create %create 42 1.024 'text/plain'])
  =/  published
    %-  on-poke:+.created
    :-  %kademlia-demo-command
    !>(`demo-command`[%publish %publish content.res %scry ~])
  =/  cards=(list card:agent:gall)  -.published
  =/  expected-payload=resource-payload
    ['text/plain' 1.024 (repeat-byte:demo 1.024 fill.res)]
  =/  expected=card:agent:gall
    :*  %pass  /scry-publish/publish  %grow
        /resource/(scot %uv content.res)/(scot %da now.bol)/publish
        [%kademlia-demo-resource expected-payload]
    ==
  ;:  weld
    (expect !>((has-card expected cards)))
    %+  expect-eq  !>(content.res)
    !>((digest-cask:cr [%kademlia-demo-resource expected-payload]))
  ==
::
++  test-scry-response-completes-and-verifies-fetch
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.21)
  =/  initialized  on-init:~(. agent bol)
  =/  res=resource  (make-resource:demo 42 1.024 'text/plain')
  =/  payload=resource-payload
    ['text/plain' 1.024 (repeat-byte:demo 1.024 fill.res)]
  =/  started
    %-  on-poke:+.initialized
    :-  %kademlia-demo-command
    !>(`demo-command`[%fetch %fetch [%content content.res]])
  =/  provider-id=node-id
    (~(ship-to-node kad [20 20 3 12 %kademlia-urbit-v1]) ~nec)
  =/  spar=spar:ames
    [~nec /g/x/1/kademlia-demo//1/resource/(scot %uv content.res)/(scot %da now.bol)/publish]
  =/  record=provider
    [[content.res provider-id 1 ~2100.1.1 ~[[%scry spar]]] [1 0x0]]
  =/  result=operation-result  [%providers [[~[record] ~] ~ ~]]
  =/  notice=operation-notice
    [[%fetch-providers (scot %uv 0v1) %fetch ~] result]
  =/  discovered
    (on-poke:+.started %content-routing-result !>(notice))
  =/  deadline=@da  (add now.bol ~s30)
  =/  responded
    %-  on-arvo:+.discovered
    :-  /scry/fetch/(scot %da deadline)
    [%ames %sage spar [%kademlia-demo-resource payload]]
  =/  final=demo-state  (get-state on-save:+.responded)
  ;:  weld
    %+  expect-eq  !>(0)
    !>((lent ~(tap by active.final)))
    (expect !>((gth (lent -.responded) 0)))
  ==
--
