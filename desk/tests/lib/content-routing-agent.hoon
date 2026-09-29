/-  *kademlia, *kademlia-agent, *content-routing, *content-routing-agent, *bounded-poke
/+  kad=kademlia, cr=content-routing, *test, default-agent
/+  content-routing-agent, kademlia-agent
|%
++  agent  (agent:content-routing-agent stub)
::
::  stub: wrapped agent.  it swallows lookup commands, emits the cards
::  poked at it as %test-cards, and saves the result marks it was poked with.
::
++  stub
  =|  got=(list mark)
  ^-  agent:gall
  |_  =bowl:gall
  +*  this  .
      def   ~(. (default-agent this %|) bowl)
  ++  on-init   `this
  ++  on-save   !>(got)
  ++  on-load   |=(vase `this)
  ++  on-watch  on-watch:def
  ++  on-leave  on-leave:def
  ++  on-peek   on-peek:def
  ++  on-agent  on-agent:def
  ++  on-arvo   on-arvo:def
  ++  on-fail   on-fail:def
  ++  on-poke
    |=  [=mark =vase]
    ^-  (quip card:agent:gall _this)
    ?+  mark  [~ this(got [mark got])]
      %kademlia-command  `this
      %test-cards        [!<((list card:agent:gall) vase) this]
    ==
  --
::
++  get-saved
  |=  saved=vase
  ^-  content-saved-state
  =+  !<([[%content-routing app=content-saved-state] *] saved)
  app
::
++  put-saved
  |=  app=content-saved-state
  ^-  vase
  !>([[%content-routing app] !>(~)])
::
++  result
  |=  notice=lookup-notice
  ^-  vase
  !>  ^-  (list card:agent:gall)
  :_  ~
  :*  %pass  /callback  %agent  [~zod %content-routing]
      %poke  %kademlia-result
      !>(notice(reply-path [%~.~ %content-routing reply-path.notice]))
  ==
::
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
++  get-state
  |=  saved=vase
  ^-  content-state
  state:(get-saved saved)
::
++  test-init-and-settings-scry
  =/  bol=bowl:gall  (bowl ~zod ~zod)
  =/  out  on-init:~(. agent bol)
  =/  saved=content-state  (get-state on-save:+.out)
  =/  peek=(unit (unit cage))  (on-peek:+.out /x/~/content-routing/settings)
  =/  got=content-config  !<(content-config q:(need (need peek)))
  =/  delivery-peek=(unit (unit cage))  (on-peek:+.out /x/~/content-routing/delivery)
  =/  delivery=delivery-summary
    !<(delivery-summary q:(need (need delivery-peek)))
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent -.out))
    %+  expect-eq  !>(config.saved)
    !>(got)
    %+  expect-eq  !>((add ~h12 now))
    !>(refresh-at.saved)
    %+  expect-eq  !>(*delivery-summary)
    !>(delivery)
  ==
::
++  test-query-callback-completes
  =/  bol=bowl:gall  (bowl ~zod ~zod)
  =/  initialized  on-init:~(. agent bol)
  =/  content=digest  (digest-cask:cr `(cask)`[%noun 42])
  =/  observe=content-command
    [%observe 0v7 %test-recipient /test/reply]
  =/  observed  (on-poke:+.initialized %content-routing-command !>(observe))
  =/  command=content-command  [%find-providers 0v7 content]
  =/  started  (on-poke:+.observed %content-routing-command !>(command))
  =/  saved=content-state  (get-state on-save:+.started)
  =/  notice=lookup-notice  [/operation/(scot %uv 0v7) [(provider-key:cr content) ~]]
  =/  finished  (on-poke:+.started %test-cards (result notice))
  =/  final=content-state  (get-state on-save:+.finished)
  =/  path=path  /x/~/content-routing/operation/(scot %uv 0v7)
  =/  peek=(unit (unit cage))  (on-peek:+.finished path)
  =/  view=operation-view  !<(operation-view q:(need (need peek)))
  ?>  ?=(%complete -.view)
  ?>  ?=(%providers -.value.view)
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent ~(tap by active.saved)))
    %+  expect-eq  !>(`providers`~)
    !>(records.selection.value.value.view)
    %+  expect-eq  !>(1)
    !>((lent -.finished))
    %+  expect-eq  !>(0)
    !>((lent ~(tap by callbacks.final)))
  ==
::
++  test-verbosity-command-scry-and-load
  =/  bol=bowl:gall  (bowl ~zod ~zod)
  =/  initialized  on-init:~(. agent bol)
  =/  initial=content-saved-state
    (get-saved on-save:+.initialized)
  =/  command=content-command  [%set-verbosity %info]
  =/  changed
    (on-poke:+.initialized %content-routing-command !>(command))
  =/  saved=content-saved-state  (get-saved on-save:+.changed)
  =/  peek=(unit (unit cage))  (on-peek:+.changed /x/~/content-routing/verbosity)
  =/  got=verbosity  !<(verbosity q:(need (need peek)))
  =/  loaded  (on-load:~(. agent bol) (put-saved saved))
  =/  restored=content-saved-state  (get-saved on-save:+.loaded)
  ;:  weld
    %+  expect-eq  !>(%off)
    !>(verbosity.initial)
    %+  expect-eq  !>(%info)
    !>(got)
    %+  expect-eq  !>(%info)
    !>(verbosity.restored)
  ==
::
++  test-callback-persists-and-forget-cleans-up
  =/  bol=bowl:gall  (bowl ~zod ~zod)
  =/  initialized  on-init:~(. agent bol)
  =/  observe=content-command
    [%observe 0v8 %test-recipient /test/reply]
  =/  observed  (on-poke:+.initialized %content-routing-command !>(observe))
  =/  saved=content-saved-state  (get-saved on-save:+.observed)
  =/  loaded  (on-load:~(. agent bol) (put-saved saved))
  =/  restored=content-state  (get-state on-save:+.loaded)
  =/  forget=content-command  [%forget 0v8]
  =/  forgotten  (on-poke:+.loaded %content-routing-command !>(forget))
  =/  final=content-state  (get-state on-save:+.forgotten)
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent ~(tap by callbacks.restored)))
    %+  expect-eq  !>(0)
    !>((lent ~(tap by callbacks.final)))
  ==
::
++  test-observe-completed-operation-notifies-immediately
  =/  bol=bowl:gall  (bowl ~zod ~zod)
  =/  initialized  on-init:~(. agent bol)
  =/  content=digest  (digest-cask:cr `(cask)`[%noun 42])
  =/  command=content-command  [%find-providers 0v9 content]
  =/  started  (on-poke:+.initialized %content-routing-command !>(command))
  =/  notice=lookup-notice
    [/operation/(scot %uv 0v9) [(provider-key:cr content) ~]]
  =/  finished  (on-poke:+.started %test-cards (result notice))
  =/  observe=content-command
    [%observe 0v9 %test-recipient /test/reply]
  =/  observed  (on-poke:+.finished %content-routing-command !>(observe))
  =/  final=content-state  (get-state on-save:+.observed)
  ;:  weld
    %+  expect-eq  !>(1)
    !>((lent -.observed))
    %+  expect-eq  !>(0)
    !>((lent ~(tap by callbacks.final)))
  ==
::
++  test-oversized-local-operation-id-nacks
  =/  bol=bowl:gall  (bowl ~zod ~zod)
  =/  initialized  on-init:~(. agent bol)
  =/  command=content-command
    [%find-providers ;;(@uv (pow 2 64)) ;;(@uvI 1)]
  %-  expect-fail
  |.  (on-poke:+.initialized %content-routing-command !>(command))
::
++  test-oversized-peer-request-id-is-ignored
  =/  bol=bowl:gall  (bowl ~zod ~nec)
  =/  initialized  on-init:~(. agent bol)
  =/  before=content-state  (get-state on-save:+.initialized)
  =/  message=content-message
    [%find-records %content-routing-v1 ;;(@uv (pow 2 64)) [%providers ;;(@uvI 1)]]
  =/  out  (on-poke:+.initialized %content-routing-message !>(message))
  =/  after=content-state  (get-state on-save:+.out)
  ;:  weld
    %+  expect-eq  !>(0)
    !>((lent -.out))
    %+  expect-eq  !>(before)
    !>(after)
  ==
::
++  test-oversized-peer-queries-are-ignored
  =/  bol=bowl:gall  (bowl ~zod ~nec)
  =/  initialized  on-init:~(. agent bol)
  =/  before=content-state  (get-state on-save:+.initialized)
  =/  pointer=content-message
    [%find-records %content-routing-v1 0v1 [%pointer ;;(@ux (pow 2 128))]]
  =/  pointer-out  (on-poke:+.initialized %content-routing-message !>(pointer))
  =/  pointer-state=content-state  (get-state on-save:+.pointer-out)
  =/  providers=content-message
    [%find-records %content-routing-v1 0v2 [%providers ;;(@uvI (pow 2 256))]]
  =/  providers-out  (on-poke:+.pointer-out %content-routing-message !>(providers))
  =/  providers-state=content-state  (get-state on-save:+.providers-out)
  ;:  weld
    %+  expect-eq  !>(before)
    !>(pointer-state)
    %+  expect-eq  !>(before)
    !>(providers-state)
  ==
::
++  test-oversized-local-query-inputs-nack
  =/  bol=bowl:gall  (bowl ~zod ~zod)
  =/  initialized  on-init:~(. agent bol)
  ;:  weld
    %-  expect-fail
    |.  %+  on-poke:+.initialized
          %content-routing-command
        !>(`content-command`[%find-pointer 0v1 %test ;;(@ux (pow 2 128)) 0])
    %-  expect-fail
    |.  %+  on-poke:+.initialized
          %content-routing-command
        !>(`content-command`[%find-providers 0v2 ;;(@uvI (pow 2 256))])
  ==
::
++  test-response-admission-precedes-processing
  =/  home=bowl:gall  (bowl ~zod ~zod)
  =/  initialized  on-init:~(. agent home)
  =/  state=content-state  (get-state on-save:+.initialized)
  =/  cfg=config  [20 20 3 12 %kademlia-urbit-v1]
  =/  peer=node-id  (~(ship-to-node kad cfg) ~nec)
  =.  pending.state
    (~(put by pending.state) 0v3 `pending-content-request`[0v30 peer %.y +(now) 0])
  =.  pending.state
    (~(put by pending.state) 0v4 `pending-content-request`[0v40 peer %.n +(now) 0])
  =.  pending-count.state  2
  =/  records-message=content-message
    [%records %content-routing-v1 0v3 1 0]
  =/  stored-message=content-message
    [%stored %content-routing-v1 0v4 [%accepted ~]]
  =/  wrong-loaded
    (on-load:~(. agent (bowl ~zod ~bud)) (put-saved [state %off]))
  =/  wrong-records
    (on-poke:+.wrong-loaded %content-routing-message !>(records-message))
  =/  wrong-records-state=content-state  (get-state on-save:+.wrong-records)
  =/  wrong-stored
    (on-poke:+.wrong-loaded %content-routing-message !>(stored-message))
  =/  wrong-stored-state=content-state  (get-state on-save:+.wrong-stored)
  =/  correct-loaded
    (on-load:~(. agent (bowl ~zod ~nec)) (put-saved [state %off]))
  =/  correct-records
    (on-poke:+.correct-loaded %content-routing-message !>(records-message))
  =/  correct-records-state=content-state  (get-state on-save:+.correct-records)
  =/  correct-stored
    (on-poke:+.correct-loaded %content-routing-message !>(stored-message))
  =/  correct-stored-state=content-state  (get-state on-save:+.correct-stored)
  ;:  weld
    (expect !>((~(has by pending.wrong-records-state) 0v3)))
    (expect !>((~(has by pending.wrong-stored-state) 0v4)))
    (expect !>(!(~(has by pending.correct-records-state) 0v3)))
    (expect !>(!(~(has by pending.correct-stored-state) 0v4)))
    %+  expect-eq  !>(1)
    !>(pending-count.correct-records-state)
    %+  expect-eq  !>(1)
    !>(pending-count.correct-stored-state)
  ==
::
++  test-malformed-store-payload-is-ignored
  =/  bol=bowl:gall  (bowl ~zod ~nec)
  =/  initialized  on-init:~(. agent bol)
  =/  before=content-state  (get-state on-save:+.initialized)
  =/  message=content-message  [%store %content-routing-v1 0v1 0]
  =/  out  (on-poke:+.initialized %content-routing-message !>(message))
  =/  after=content-state  (get-state on-save:+.out)
  ;:  weld
    %+  expect-eq  !>(0)
    !>((lent -.out))
    %+  expect-eq  !>(before)
    !>(after)
  ==
::
++  test-reset-restores-empty-default-state
  =/  bol=bowl:gall  (bowl ~zod ~zod)
  =/  initialized  on-init:~(. agent bol)
  =/  changed-config=content-config
    [1 1 1 ~s1 ~d2 ~d1 1 1.024 2 3]
  =/  changed
    %+  on-poke:+.initialized  %content-routing-command
    !>(`content-command`[%set-config changed-config])
  =/  reset
    (on-poke:+.changed %content-routing-command !>(`content-command`[%reset ~]))
  =/  state=content-state  (get-state on-save:+.reset)
  ;:  weld
    %+  expect-eq  !>(20)
    !>(replication.config.state)
    %+  expect-eq  !>(0)
    !>(replica-count.state)
    %+  expect-eq  !>(0)
    !>((lent ~(tap by origins.state)))
  ==
::
++  stack  (agent:content-routing-agent (agent:kademlia-agent stub))
::
++  test-stacked-lookup-completes-in-one-event
  =/  bol=bowl:gall  (bowl ~zod ~zod)
  =/  initialized  on-init:~(. stack bol)
  =/  observed
    %+  on-poke:+.initialized  %content-routing-command
    !>(`content-command`[%observe 0v7 %content-routing /reply])
  =/  finished
    %+  on-poke:+.observed  %content-routing-command
    !>  ^-  content-command
    [%find-providers 0v7 (digest-cask:cr `(cask)`[%noun 42])]
  =/  final=content-state  (get-state on-save:+.finished)
  =+  !<([* below=vase] on-save:+.finished)
  =+  !<([* inner=vase] below)
  ;:  weld
    %+  expect-eq  !>(0)
    !>(~(wyt by active.final))
    %+  expect-eq  !>(0)
    !>(~(wyt by callbacks.final))
    %+  expect-eq  !>(`(list mark)`~[%content-routing-result])
    !>(!<((list mark) inner))
    %+  expect-eq  !>(0)
    !>((lent -.finished))
  ==
::
++  test-untagged-state-loads-fresh
  =/  bol=bowl:gall  (bowl ~zod ~zod)
  =/  loaded  (on-load:~(. stack bol) !>(%old))
  =/  state=content-state  (get-state on-save:+.loaded)
  ;:  weld
    %+  expect-eq  !>((add ~h12 now))
    !>(refresh-at.state)
    %+  expect-eq  !>(2)
    !>((lent -.loaded))
  ==
--
