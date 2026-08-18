::  Minimal ordinary-Ames Kademlia peer-discovery agent.
::
/-  *kademlia-agent
/+  logic=kademlia-agent-logic, default-agent, dbug, verb
|%
+$  card  card:agent:gall
--
::
%+  verb  |
%-  agent:dbug
=|  state=agent-state
=/  verbosity=verbosity  %off
=>  |%
++  log-enabled
  |=  level=log-level
  ^-  ?
  ?-  verbosity
    %off    |
    %info   =(%info level)
    %debug  &
  ==
::
++  log
  |=  [=bowl:gall level=log-level event=*]
  ^-  ~
  ?.  (log-enabled level)  ~
  ~&  [dap.bowl level event]
  ~
::
++  log-completion
  |=  [=bowl:gall id=(unit lookup-id) maintenance=?]
  ^-  ~
  ?~  id  ~
  =/  result=(unit lookup-result)  (~(get by completed.state) u.id)
  ?~  result  ~
  ?:  maintenance
    (log bowl %debug [%refresh-complete u.id (lent contacts.u.result)])
  (log bowl %info [%lookup-complete u.id (lent contacts.u.result)])
--
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
::
++  on-init
  ^-  (quip card _this)
  =.  state  ~(init logic [our.bowl now.bowl src.bowl state])
  [~(refresh-card logic [our.bowl now.bowl src.bowl state]) this]
::
++  on-save  !>(`kademlia-saved-state`[state verbosity])
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  =/  saved=kademlia-saved-state  !<(kademlia-saved-state old)
  =.  state  state.saved
  =.  verbosity  verbosity.saved
  [~(refresh-card logic [our.bowl now.bowl src.bowl state]) this]
::
++  on-poke
  |=  [=mark =vase]
  ^-  (quip card _this)
  ?+    mark  (on-poke:def mark vase)
      %kademlia-command
    ?>  =(src.bowl our.bowl)
    =/  command=command  !<(command vase)
    ?-  -.command
      %set-seeds
        =/  ignored  (log bowl %info [%seeds-set (lent ships.command)])
        =.  state  (~(set-seeds logic [our.bowl now.bowl src.bowl state]) ships.command)
        =^  cards  state  ~(bootstrap logic [our.bowl now.bowl src.bowl state])
        [cards this]
      %set-request-timeout
        =/  ignored  (log bowl %info [%request-timeout-set duration.command])
        =.  state
          (~(set-request-timeout logic [our.bowl now.bowl src.bowl state]) duration.command)
        `this
      %set-refresh-interval
        =/  ignored  (log bowl %info [%refresh-interval-set duration.command])
        =^  cards  state
          (~(set-refresh-interval logic [our.bowl now.bowl src.bowl state]) duration.command)
        [cards this]
      %set-verbosity
        =.  verbosity  level.command
        =/  ignored  (log bowl %info [%verbosity-set level.command])
        `this
      %find
        ?>  (~(valid-id logic [our.bowl now.bowl src.bowl state]) id.command)
        ?>  (~(valid-node-id logic [our.bowl now.bowl src.bowl state]) target.command)
        =/  ignored  (log bowl %info [%lookup-start id.command target.command])
        =^  cards  state
          (~(start logic [our.bowl now.bowl src.bowl state]) id.command target.command)
        [cards this]
      %find-for
        ?>  (~(valid-node-id logic [our.bowl now.bowl src.bowl state]) target.command)
        =/  ignored
          (log bowl %info [%lookup-start-for target.command recipient.command reply-path.command])
        =^  cards  state
          %+  ~(start-for logic [our.bowl now.bowl src.bowl state])
            target.command
          [recipient.command reply-path.command]
        =^  notices  state  ~(notify logic [our.bowl now.bowl src.bowl state])
        [(weld cards notices) this]
      %forget
        ?>  (~(valid-id logic [our.bowl now.bowl src.bowl state]) id.command)
        =/  ignored  (log bowl %debug [%lookup-forget id.command])
        =.  state  (~(forget logic [our.bowl now.bowl src.bowl state]) id.command)
        `this
    ==
  ::
      %kademlia-message
    =/  message=peer-message  !<(peer-message vase)
    ?.  =(%kademlia-v1 version.message)
      =/  ignored  (log bowl %debug [%peer-version-ignored src.bowl version.message])
      `this
    ?-    -.message
        %find-node
      ?.  (~(valid-id logic [our.bowl now.bowl src.bowl state]) id.message)  `this
      ?.  (~(valid-node-id logic [our.bowl now.bowl src.bowl state]) target.message)  `this
      =/  ignored
        (log bowl %debug [%peer-find-node src.bowl id.message target.message])
      =^  cards  state
        (~(receive-find-node logic [our.bowl now.bowl src.bowl state]) id.message target.message)
      [cards this]
    ::
        %nodes
      ?.  (~(valid-id logic [our.bowl now.bowl src.bowl state]) id.message)  `this
      =/  pending=(unit pending-request)  (~(get by pending.state) id.message)
      =/  maintenance=?
        ?^  pending  =(maintenance.state `lookup.u.pending)
        |
      =/  ignored  (log bowl %debug [%peer-nodes src.bowl id.message count.message])
      =^  cards  state
        %+  ~(receive-nodes logic [our.bowl now.bowl src.bowl state])
          id.message
        [count.message packed.message]
      =^  notices  state  ~(notify logic [our.bowl now.bowl src.bowl state])
      =^  maintenance-cards  state
        (~(continue-refresh logic [our.bowl now.bowl src.bowl state]) eny.bowl)
      =/  ignored
        (log-completion bowl ?~(pending ~ `lookup.u.pending) maintenance)
      [(weld cards (weld notices maintenance-cards)) this]
    ==
  ==
::
++  on-peek
  |=  =path
  ^-  (unit (unit cage))
  =/  engine  [our.bowl now.bowl src.bowl state]
  ?+    path  (on-peek:def path)
      [%x ~]            [~ ~]
      [%x %summary ~]   ``noun+!>(~(get-summary logic engine))
      [%x %table ~]     ``noun+!>(routing.state)
      [%x %seeds ~]     ``noun+!>(~(seed-list logic engine))
      [%x %settings ~]  ``noun+!>(settings.state)
      [%x %verbosity ~]  ``noun+!>(verbosity)
      [%x %lookup ~]    [~ ~]
      [%x %lookup @ ~]
    =/  parsed=(unit @uv)  (slaw %uv i.t.t.path)
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
  ?.  ?=([%request @ ~] wire)  (on-agent:def wire sign)
  ?.  ?=(%poke-ack -.sign)  (on-agent:def wire sign)
  ?~  p.sign  `this
  =/  request=(unit @uv)  (slaw %uv i.t.wire)
  ?~  request  `this
  =/  pending=(unit pending-request)  (~(get by pending.state) u.request)
  =/  maintenance=?
    ?^  pending  =(maintenance.state `lookup.u.pending)
    |
  =/  ignored  (log bowl %debug [%request-poke-failed u.request])
  =^  cards  state
    (~(fail-request logic [our.bowl now.bowl src.bowl state]) u.request &)
  =^  notices  state  ~(notify logic [our.bowl now.bowl src.bowl state])
  =^  maintenance-cards  state
    (~(continue-refresh logic [our.bowl now.bowl src.bowl state]) eny.bowl)
  =/  ignored
    (log-completion bowl ?~(pending ~ `lookup.u.pending) maintenance)
  [(weld cards (weld notices maintenance-cards)) this]
::
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?:  ?=([%refresh @ ~] wire)
    ?.  ?=(%wake +<.sign-arvo)  (on-arvo:def wire sign-arvo)
    =/  deadline=(unit @da)  (slaw %da i.t.wire)
    ?~  deadline  `this
    =/  ignored  (log bowl %debug [%refresh-wake u.deadline])
    =^  cards  state
      (~(run-refresh logic [our.bowl now.bowl src.bowl state]) u.deadline eny.bowl)
    [cards this]
  ?.  ?=([%timeout @ ~] wire)  (on-arvo:def wire sign-arvo)
  ?.  ?=(%wake +<.sign-arvo)  (on-arvo:def wire sign-arvo)
  =/  request=(unit @uv)  (slaw %uv i.t.wire)
  ?~  request  `this
  ?.  (~(has by pending.state) u.request)  `this
  =/  pending=(unit pending-request)  (~(get by pending.state) u.request)
  =/  maintenance=?
    ?^  pending  =(maintenance.state `lookup.u.pending)
    |
  =/  ignored  (log bowl %debug [%request-timeout u.request])
  =^  cards  state
    (~(fail-request logic [our.bowl now.bowl src.bowl state]) u.request |)
  =^  notices  state  ~(notify logic [our.bowl now.bowl src.bowl state])
  =^  maintenance-cards  state
    (~(continue-refresh logic [our.bowl now.bowl src.bowl state]) eny.bowl)
  =/  ignored
    (log-completion bowl ?~(pending ~ `lookup.u.pending) maintenance)
  [(weld cards (weld notices maintenance-cards)) this]
::
++  on-watch  on-watch:def
++  on-leave  on-leave:def
++  on-fail   on-fail:def
--
