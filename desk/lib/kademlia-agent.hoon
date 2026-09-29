::  kademlia-agent: agent wrapper for Kademlia peer discovery
::
::    usage: %-(agent:kademlia-agent your-agent)
::
::    The wrapper keeps its wires under /~/kademlia and serves its scries
::    under /x/~/kademlia.  It handles the %kademlia-command and
::    %kademlia-message marks and sends peer messages to the same agent name
::    on other ships.  Everything else passes through to the wrapped agent.
::
/-  *kademlia-agent
/+  logic=kademlia-agent-logic, delivery=bounded-poke
|%
+$  card  card:agent:gall
::
++  agent
  |=  inner=agent:gall
  =|  state=agent-state
  =/  verbosity=verbosity  %off
  =>  |%
      ++  work
        |_  [=bowl:gall cards=(list card)]
        ++  cor     .
        ++  engine  [our.bowl now.bowl src.bowl dap.bowl state]
        ++  abet    [cards=(flop cards) inner=inner state=state verbosity=verbosity]
        ::
        ++  log
          |=  [level=log-level event=*]
          ^-  ~
          ?.  ?-  verbosity
                %off    |
                %info   =(%info level)
                %debug  &
              ==
            ~
          ~&  [dap.bowl level event]
          ~
        ::
        ::  below: keep the wrapped agent and the cards it produced.
        ::
        ++  below
          |=  out=(quip card agent:gall)
          ^+  cor
          cor(inner +.out, cards (weld (flop -.out) cards))
        ::
        ::  emit: namespace our cards.  A result for the wrapped agent
        ::  goes straight to its +on-poke.
        ::
        ++  emit
          |=  new=(list card)
          ^+  cor
          ?~  new  cor
          ?.  ?=(%pass -.i.new)
            $(new t.new, cards [i.new cards])
          =/  home=(unit lookup-notice)
            ?.  ?=([%agent ^ %poke %kademlia-result *] q.i.new)  ~
            ?.  =([our.bowl dap.bowl] +<.q.i.new)  ~
            =/  notice=lookup-notice  !<(lookup-notice q.cage.task.q.i.new)
            ?:  ?=([%~.~ *] reply-path.notice)  ~
            `notice
          ?~  home
            $(new t.new, cards [i.new(p [%~.~ %kademlia p.i.new]) cards])
          =^  out  inner
            %+  ~(on-poke inner bowl(src our.bowl))
              %kademlia-result
            !>(u.home)
          $(new t.new, cards (weld (flop out) cards))
        ::
        ++  step
          |=  transition=[cards=(list card) update=lookup-update]
          ^+  cor
          =.  state  state.update.transition
          ?~  completion.update.transition  (emit cards.transition)
          =/  id=lookup-id  u.completion.update.transition
          =/  result=(unit lookup-result)  (~(get by completed.state) id)
          ?~  result  (emit cards.transition)
          =/  ignored
            ?:  =(maintenance.state `id)
              (log %debug [%refresh-complete id (lent contacts.u.result)])
            (log %info [%lookup-complete id (lent contacts.u.result)])
          =^  notified  state  (~(notify logic engine) id)
          =^  continued  state  (~(continue-refresh logic engine) id eny.bowl)
          (emit :(weld cards.transition notified continued))
        ::
        ++  init
          ^+  cor
          =.  state  ~(init logic engine)
          (emit ~(refresh-card logic engine))
        ::
        ++  load
          |=  saved=kademlia-saved-state
          ^+  cor
          =.  state  state.saved
          =.  verbosity  verbosity.saved
          (emit ~(refresh-card logic engine))
        ::
        ++  poke-command
          |=  =command
          ^+  cor
          ?>  =(src.bowl our.bowl)
          ?-  -.command
            %reset
              =/  cancel=(list card)
                ?~  refresh-at.state  ~
                :~  :*  %pass  /refresh/(scot %da u.refresh-at.state)
                        %arvo  %b  %rest  u.refresh-at.state
                ==  ==
              =^  delivery-cards  state  ~(reset-state logic engine)
              =.  verbosity  %off
              (emit :(weld cancel delivery-cards ~(refresh-card logic engine)))
            %set-seeds
              =/  ignored  (log %info [%seeds-set (lent ships.command)])
              =.  state  (~(set-seeds logic engine) ships.command)
              =^  new  state  ~(bootstrap logic engine)
              (emit new)
            %set-request-timeout
              =/  ignored  (log %info [%request-timeout-set duration.command])
              =.  state  (~(set-request-timeout logic engine) duration.command)
              cor
            %set-refresh-interval
              =/  ignored  (log %info [%refresh-interval-set duration.command])
              =^  new  state
                (~(set-refresh-interval logic engine) duration.command)
              (emit new)
            %set-verbosity
              =.  verbosity  level.command
              =/  ignored  (log %info [%verbosity-set level.command])
              cor
            %find
              ?>  (~(valid-id logic engine) id.command)
              ?>  (~(valid-node-id logic engine) target.command)
              =/  ignored  (log %info [%lookup-start id.command target.command])
              (step (~(start logic engine) id.command target.command))
            %find-for
              ?>  (~(valid-node-id logic engine) target.command)
              =/  ignored
                %+  log  %info
                [%lookup-start-for target.command recipient.command reply-path.command]
              %-  step
              %+  ~(start-for logic engine)
                target.command
              [recipient.command reply-path.command]
            %forget
              ?>  (~(valid-id logic engine) id.command)
              =/  ignored  (log %debug [%lookup-forget id.command])
              =.  state  (~(forget logic engine) id.command)
              cor
          ==
        ::
        ++  poke-message
          |=  message=peer-message
          ^+  cor
          ?.  =(%kademlia-v1 version.message)
            =/  ignored
              (log %debug [%peer-version-ignored src.bowl version.message])
            cor
          ?-    -.message
              %find-node
            ?.  (~(valid-id logic engine) id.message)  cor
            ?.  (~(valid-node-id logic engine) target.message)  cor
            =/  ignored
              (log %debug [%peer-find-node src.bowl id.message target.message])
            =^  new  state
              (~(receive-find-node logic engine) id.message target.message)
            (emit new)
          ::
              %nodes
            ?.  (~(valid-id logic engine) id.message)  cor
            =/  ignored
              (log %debug [%peer-nodes src.bowl id.message count.message])
            %-  step
            %+  ~(receive-nodes logic engine)
              id.message
            [count.message packed.message]
          ==
        ::
        ++  agent-sign
          |=  [=wire =sign:agent:gall]
          ^+  cor
          ?.  ?=([%delivery @ @ ~] wire)  cor
          ?.  ?=(%poke-ack -.sign)  cor
          =/  peer=(unit @p)  (slaw %p i.t.wire)
          =/  id=(unit @ud)  (slaw %ud i.t.t.wire)
          ?~  peer  cor
          ?~  id  cor
          =/  ignored
            ?~  p.sign  ~
            (log %debug [%delivery-poke-failed u.peer u.id])
          (step (~(delivery-ack logic engine) u.peer u.id p.sign))
        ::
        ++  wake
          |=  =wire
          ^+  cor
          ?+    wire  cor
              [%refresh @ ~]
            =/  deadline=(unit @da)  (slaw %da i.t.wire)
            ?~  deadline  cor
            =/  ignored  (log %debug [%refresh-wake u.deadline])
            =^  new  state
              (~(run-refresh logic engine) u.deadline eny.bowl)
            (emit new)
          ::
              [%delivery-expire @ @ ~]
            =/  peer=(unit @p)  (slaw %p i.t.wire)
            =/  deadline=(unit @da)  (slaw %da i.t.t.wire)
            ?~  peer  cor
            ?~  deadline  cor
            =^  new  state
              (~(delivery-expire logic engine) u.peer u.deadline)
            (emit new)
          ::
              [%timeout @ ~]
            =/  request=(unit @uv)  (slaw %uv i.t.wire)
            ?~  request  cor
            ?.  (~(has by pending.state) u.request)  cor
            =/  ignored  (log %debug [%request-timeout u.request])
            (step (~(fail-request logic engine) u.request |))
          ==
        --
      --
  ^-  agent:gall
  |_  =bowl:gall
  +*  this  .
      og    ~(. inner bowl)
      up    ~(. work bowl ~)
  ::
  ++  on-init
    ^-  (quip card _this)
    =/  out  abet:(below:init:up on-init:og)
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-save
    !>([[%kademlia `kademlia-saved-state`[state verbosity]] on-save:og])
  ::
  ++  on-load
    |=  ole=vase
    ^-  (quip card _this)
    ?.  ?=([[%kademlia *] *] q.ole)
      =/  out  abet:(below:init:up (on-load:og ole))
      [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
    =+  !<([[%kademlia old=kademlia-saved-state] ile=vase] ole)
    =/  out  abet:(below:(load:up old) (on-load:og ile))
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-poke
    |=  [=mark =vase]
    ^-  (quip card _this)
    =/  out
      ?+  mark  abet:(below:up (on-poke:og mark vase))
        %kademlia-command  abet:(poke-command:up !<(command vase))
        %kademlia-message  abet:(poke-message:up !<(peer-message vase))
      ==
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-peek
    |=  =path
    ^-  (unit (unit cage))
    ?.  ?=([%x %~.~ %kademlia *] path)  (on-peek:og path)
    =/  engine  engine:up
    ?+    t.t.t.path  [~ ~]
        [%summary ~]    ``noun+!>(~(get-summary logic engine))
        [%table ~]      ``noun+!>(routing.state)
        [%seeds ~]      ``noun+!>(~(seed-list logic engine))
        [%settings ~]   ``noun+!>(settings.state)
        [%delivery ~]   ``noun+!>(~(summary delivery [now.bowl outbound.state]))
        [%verbosity ~]  ``noun+!>(verbosity)
        [%lookup @ ~]
      =/  parsed=(unit @uv)  (slaw %uv i.t.t.t.t.path)
      ?~  parsed  ~
      ?.  (~(valid-id logic engine) u.parsed)  ~
      =/  view=(unit lookup-view)  (~(get-lookup logic engine) u.parsed)
      ?~  view  ~
      ``noun+!>(u.view)
    ==
  ::
  ++  on-agent
    |=  [=wire =sign:agent:gall]
    ^-  (quip card _this)
    =/  out
      ?.  ?=([%~.~ %kademlia *] wire)
        abet:(below:up (on-agent:og wire sign))
      abet:(agent-sign:up t.t.wire sign)
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-arvo
    |=  [=wire =sign-arvo]
    ^-  (quip card _this)
    =/  out
      ?.  ?=([%~.~ %kademlia *] wire)
        abet:(below:up (on-arvo:og wire sign-arvo))
      ?.  ?=(%wake +<.sign-arvo)  abet:up
      abet:(wake:up t.t.wire)
    [cards.out this(inner inner.out, state state.out, verbosity verbosity.out)]
  ::
  ++  on-watch
    |=  =path
    ^-  (quip card _this)
    =^  cards  inner  (on-watch:og path)
    [cards this]
  ::
  ++  on-leave
    |=  =path
    ^-  (quip card _this)
    =^  cards  inner  (on-leave:og path)
    [cards this]
  ::
  ++  on-fail
    |=  [=term =tang]
    ^-  (quip card _this)
    =^  cards  inner  (on-fail:og term tang)
    [cards this]
  --
--
