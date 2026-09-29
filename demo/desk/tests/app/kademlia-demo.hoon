/-  *content-routing, *content-routing-agent, *kademlia, *kademlia-demo
/-  cd=content-discovery, cda=content-discovery-agent
/+  kad=kademlia, cr=content-routing, demo=kademlia-demo, *test
/=  agent  /app/kademlia-demo
|%
+$  kademlia-command  command
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
++  strip
  |=  c=card:agent:gall
  ^-  *
  ?.  ?=([%pass * %agent * %poke *] c)  -.c
  [p.c +<.q.c p.cage.task.q.c q.q.cage.task.q.c]
::
++  get-state
  |=  saved=vase
  =+  !<([* routing=vase] saved)
  =+  !<([* kademlia=vase] routing)
  =+  !<([* inner=vase] kademlia)
  !<(demo-state inner)
::
++  test-init
  =/  out  on-init:~(. agent (bowl ~zod ~zod ~2026.8.21))
  =/  state=demo-state  (get-state on-save:+.out)
  ;:  weld
    %+  expect-eq  !>(32.768)
    !>(chunk-bytes.config.state)
    %+  expect-eq  !>(4)
    !>(window.config.state)
    %+  expect-eq  !>(0)
    !>((lent ~(tap by resources.state)))
  ==
::
++  test-create-and-scry
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.21)
  =/  initialized  on-init:~(. agent bol)
  =/  command=demo-command  [%create %create-test 42 1.024 'text/plain']
  =/  out  (on-poke:+.initialized %kademlia-demo-command !>(command))
  =/  state=demo-state  (get-state on-save:+.out)
  =/  peek=(unit (unit cage))  (on-peek:+.out /x/resources)
  ;:  weld
    (expect !>((gth (lent -.out) 0)))
    %+  expect-eq  !>(1)
    !>((lent ~(tap by resources.state)))
    (expect !>(?=(^ peek)))
  ==
::
++  test-invalid-size-does-not-store
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.21)
  =/  initialized  on-init:~(. agent bol)
  =/  command=demo-command  [%create %too-large 1 9.000.000 'text/plain']
  =/  out  (on-poke:+.initialized %kademlia-demo-command !>(command))
  =/  state=demo-state  (get-state on-save:+.out)
  ;:  weld
    (expect !>((gth (lent -.out) 0)))
    %+  expect-eq  !>(0)
    !>((lent ~(tap by resources.state)))
  ==
::
++  test-remote-command-rejected
  =/  initialized  on-init:~(. agent (bowl ~zod ~nec ~2026.8.21))
  =/  command=demo-command  [%create %remote 1 1.024 'text/plain']
  %-  expect-fail
  |.  (on-poke:+.initialized %kademlia-demo-command !>(command))
::
++  test-full-operation-table-is-rejected-cleanly
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.21)
  =/  initialized  on-init:~(. agent bol)
  =/  one
    (on-poke:+.initialized %kademlia-demo-command !>(`demo-command`[%lookup %one ~nec]))
  =/  two
    (on-poke:+.one %kademlia-demo-command !>(`demo-command`[%lookup %two ~nec]))
  =/  three
    (on-poke:+.two %kademlia-demo-command !>(`demo-command`[%lookup %three ~nec]))
  =/  four
    (on-poke:+.three %kademlia-demo-command !>(`demo-command`[%lookup %four ~nec]))
  =/  rejected
    (on-poke:+.four %kademlia-demo-command !>(`demo-command`[%fetch %five [%content 0v1]]))
  =/  state=demo-state  (get-state on-save:+.rejected)
  ;:  weld
    %+  expect-eq  !>(4)
    !>((lent ~(tap by active.state)))
    (expect !>(?=(^ -.rejected)))
  ==
::
++  test-network-emits-typed-kademlia-commands
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.21)
  =/  initialized  on-init:~(. agent bol)
  =/  command=demo-command
    [%network ~[~bud ~nec] ~s30 ~h1 %debug]
  =/  out  (on-poke:+.initialized %kademlia-demo-command !>(command))
  =/  cards=(list card:agent:gall)  -.out
  =/  expected=(list card:agent:gall)
    :~  [%pass /kademlia/seeds %agent [~zod %kademlia-demo] %poke %kademlia-command !>(`kademlia-command`[%set-seeds ~[~bud ~nec]])]
        [%pass /kademlia/request-timeout %agent [~zod %kademlia-demo] %poke %kademlia-command !>(`kademlia-command`[%set-request-timeout ~s30])]
        [%pass /kademlia/refresh-interval %agent [~zod %kademlia-demo] %poke %kademlia-command !>(`kademlia-command`[%set-refresh-interval ~h1])]
        [%pass /kademlia/verbosity %agent [~zod %kademlia-demo] %poke %kademlia-command !>(`kademlia-command`[%set-verbosity %debug])]
        [%pass /discovery/0v0/network-config %agent [~zod %kademlia-demo] %poke %content-discovery-command !>(`discovery-command:cda`[%set-config [20 3 12 ~s30 ~d1 ~h12 8 65.536 64 8 10.000]])]
        [%pass /discovery/0v0/network-verbosity %agent [~zod %kademlia-demo] %poke %content-discovery-command !>(`discovery-command:cda`[%set-verbosity %debug])]
    ==
  ::
  ::  compare passes by value: vases carry their types, which are
  ::  costly to print, and the verb wrapper adds its own gives
  %+  expect-eq
    !>((turn expected strip))
  !>((turn (skim cards |=(c=card:agent:gall ?=(%pass -.c))) strip))
::
++  test-publish-callbacks-complete-the-run
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.21)
  =/  initialized  on-init:~(. agent bol)
  =/  res=resource  (make-resource:demo 7 1.024 'text/plain')
  =/  created
    (on-poke:+.initialized %kademlia-demo-command !>(`demo-command`[%create %create 7 1.024 'text/plain']))
  =/  published
    %+  on-poke:+.created  %kademlia-demo-command
    !>(`demo-command`[%publish %publish content.res %custom `[namespace=%demo name='latest' revision=1]])
  =/  accepted=(set node-id)  (silt ~[0x1])
  =/  provider-result=operation-result  [%published 0x1 accepted ~ ~]
  =/  provider-notice=operation-notice
    [[%publish-provider (scot %uv 0v1) %publish ~] provider-result]
  =/  provider
    (on-poke:+.published %content-routing-result !>(provider-notice))
  =/  provider-state=demo-state  (get-state on-save:+.provider)
  =/  provider-op=operation  (need (~(get by active.provider-state) %publish))
  ?>  ?=(%publish -.kind.provider-op)
  =/  publication=publication-state  state.kind.provider-op
  =/  pointer-result=operation-result  [%published 0x2 accepted ~ ~]
  =/  pointer-notice=operation-notice
    [[%publish-pointer (scot %uv 0v2) %publish ~] pointer-result]
  =/  pointer
    (on-poke:+.provider %content-routing-result !>(pointer-notice))
  =/  pointer-state=demo-state  (get-state on-save:+.pointer)
  ;:  weld
    %+  expect-eq  !>(%.y)
    !>(provider-done.publication)
    %+  expect-eq  !>(%.n)
    !>(pointer-done.publication)
    %+  expect-eq  !>(0)
    !>((lent ~(tap by active.pointer-state)))
    (expect !>(?=(^ -.pointer)))
  ==
::
++  test-digest-fetch-provider-callback-starts-transfer
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.21)
  =/  initialized  on-init:~(. agent bol)
  =/  content=digest  0v1
  =/  started
    (on-poke:+.initialized %kademlia-demo-command !>(`demo-command`[%fetch %fetch [%content content]]))
  =/  provider-id=node-id
    (~(ship-to-node kad [20 20 3 12 %kademlia-urbit-v1]) ~nec)
  =/  record=provider
    [[content provider-id 1 ~2100.1.1 ~[[%custom %kademlia-demo-v1 0]]] [1 0x0]]
  =/  result=operation-result  [%providers [[~[record] ~] ~ ~]]
  =/  notice=operation-notice
    [[%fetch-providers (scot %uv 0v1) %fetch ~] result]
  =/  received
    (on-poke:+.started %content-routing-result !>(notice))
  =/  state=demo-state  (get-state on-save:+.received)
  =/  op=operation  (need (~(get by active.state) %fetch))
  ?>  ?=(%fetch -.kind.op)
  =/  fetch=fetch-state  state.kind.op
  ;:  weld
    %+  expect-eq  !>(`(unit digest)``content)
    !>(content.fetch)
    %+  expect-eq  !>(`(unit node-id)``provider-id)
    !>(provider.fetch)
    (expect !>((gth in-flight.fetch 0)))
  ==
::
++  test-load-retains-resources-and-clears-operations
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.21)
  =/  initialized  on-init:~(. agent bol)
  =/  created
    (on-poke:+.initialized %kademlia-demo-command !>(`demo-command`[%create %one 7 1.024 'text/plain']))
  =/  started
    (on-poke:+.created %kademlia-demo-command !>(`demo-command`[%lookup %two ~nec]))
  =/  before=demo-state  (get-state on-save:+.started)
  =/  loaded  (on-load:~(. agent bol) on-save:+.started)
  =/  after=demo-state  (get-state on-save:+.loaded)
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent ~(tap by active.before)))
    %+  expect-eq  !>(0)
    !>((lent ~(tap by active.after)))
    %+  expect-eq  !>(1)
    !>((lent ~(tap by resources.after)))
  ==
::
++  test-topic-advertisement-callback-completes-run
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.21)
  =/  initialized  on-init:~(. agent bol)
  =/  res=resource  (make-resource:demo 7 1.024 'text/plain')
  =/  created
    (on-poke:+.initialized %kademlia-demo-command !>(`demo-command`[%create %create 7 1.024 'text/plain']))
  =/  advertised
    %+  on-poke:+.created  %kademlia-demo-command
    !>(`demo-command`[%advertise-topic %topic-ad content.res ~[%software %urbit] %demo 1])
  =/  before=demo-state  (get-state on-save:+.advertised)
  =/  accepted=(set node-id)  (silt ~[0x1])
  =/  publication=publication-result:cda
    [[%catalog 0x1] 0x2 accepted ~ ~]
  =/  result=discovery-result:cda  [%advertised ~[publication]]
  =/  notice=operation-notice:cda
    [[%topic-advertise (scot %uv 0v1) %topic-ad ~] result]
  =/  finished
    (on-poke:+.advertised %content-discovery-result !>(notice))
  =/  after=demo-state  (get-state on-save:+.finished)
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent ~(tap by active.before)))
    %+  expect-eq  !>(0)
    !>((lent ~(tap by active.after)))
    (expect !>((gte (lent -.finished) 3)))
  ==
::
++  test-topic-browse-callback-exposes-selection
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.21)
  =/  initialized  on-init:~(. agent bol)
  =/  started
    %+  on-poke:+.initialized  %kademlia-demo-command
    !>(`demo-command`[%browse-topic %topic-browse ~[%software]])
  =/  child=child-selection:cd  [%urbit (silt ~[0x1])]
  =/  selected=topic-selection:cd  [~ ~[child] ~]
  =/  browse=browse-result:cda
    [~[%software] selected (silt ~[0x1]) ~]
  =/  notice=operation-notice:cda
    [[%topic-browse (scot %uv 0v1) %topic-browse ~] [%topic browse]]
  =/  finished
    (on-poke:+.started %content-discovery-result !>(notice))
  =/  state=demo-state  (get-state on-save:+.finished)
  ;:  weld
    %+  expect-eq  !>(0)
    !>((lent ~(tap by active.state)))
    (expect !>((gte (lent -.finished) 3)))
  ==
::
++  test-peer-chunk-request
  =/  home=bowl:gall  (bowl ~zod ~zod ~2026.8.21)
  =/  initialized  on-init:~(. agent home)
  =/  created
    (on-poke:+.initialized %kademlia-demo-command !>(`demo-command`[%create %one 7 1.024 'text/plain']))
  =/  res=resource  (make-resource:demo 7 1.024 'text/plain')
  =/  remote  (on-load:~(. agent (bowl ~zod ~nec ~2026.8.21)) on-save:+.created)
  =/  message=transfer-message
    [%chunk-request %kademlia-demo-v1 0v1 content.res 32 128]
  =/  out  (on-poke:+.remote %kademlia-demo-message !>(message))
  (expect !>((gth (lent -.out) 0)))
::
++  test-reset-clears-demo-state-and-emits-stack-resets
  =/  bol=bowl:gall  (bowl ~zod ~zod ~2026.8.21)
  =/  initialized  on-init:~(. agent bol)
  =/  created
    (on-poke:+.initialized %kademlia-demo-command !>(`demo-command`[%create %one 7 1.024 'text/plain']))
  =/  res=resource  (make-resource:demo 7 1.024 'text/plain')
  =/  published
    (on-poke:+.created %kademlia-demo-command !>(`demo-command`[%publish %publish content.res %scry ~]))
  =/  active
    (on-poke:+.published %kademlia-demo-command !>(`demo-command`[%lookup %two ~nec]))
  =/  reset
    (on-poke:+.active %kademlia-demo-command !>(`demo-command`[%reset ~]))
  =/  state=demo-state  (get-state on-save:+.reset)
  ;:  weld
    %+  expect-eq  !>(0)
    !>((lent ~(tap by resources.state)))
    %+  expect-eq  !>(0)
    !>((lent ~(tap by active.state)))
    %+  expect-eq  !>(0)
    !>((lent ~(tap in scry-spurs.state)))
    (expect !>((gte (lent -.reset) 5)))
  ==
--
