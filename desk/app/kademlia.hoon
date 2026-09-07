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
  |=  [=bowl:gall id=lookup-id result=lookup-result maintenance=?]
  ^-  ~
  ?:  maintenance
    (log bowl %debug [%refresh-complete id (lent contacts.result)])
  (log bowl %info [%lookup-complete id (lent contacts.result)])
::
++  apply-lookup-transition
  |=  $:  =bowl:gall
          transition=[cards=(list card) update=lookup-update]
      ==
  ^-  [(list card) agent-state]
  =/  out=agent-state  state.update.transition
  ?~  completion.update.transition  [cards.transition out]
  =/  id=lookup-id  u.completion.update.transition
  =/  result=(unit lookup-result)  (~(get by completed.out) id)
  ?~  result  [cards.transition out]
  =/  maintenance=?  =(maintenance.out `id)
  =/  ignored  (log-completion bowl id u.result maintenance)
  =/  notified=[(list card) agent-state]
    (~(notify logic [our.bowl now.bowl src.bowl out]) id)
  =/  continued=[(list card) agent-state]
    (~(continue-refresh logic [our.bowl now.bowl src.bowl +.notified]) id eny.bowl)
  :_  +.continued
  (weld cards.transition (weld -.notified -.continued))
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
      %reset
        =/  cancel=(list card)
          ?~  refresh-at.state  ~
          ~[[%pass /refresh/(scot %da u.refresh-at.state) %arvo %b %rest u.refresh-at.state]]
        =^  delivery-cards  state
          ~(reset-state logic [our.bowl now.bowl src.bowl state])
        =.  verbosity  %off
        :_  this
        (weld cancel (weld delivery-cards ~(refresh-card logic [our.bowl now.bowl src.bowl state])))
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
        =/  transition=[cards=(list card) update=lookup-update]
          (~(start logic [our.bowl now.bowl src.bowl state]) id.command target.command)
        =^  cards  state  (apply-lookup-transition bowl transition)
        [cards this]
      %find-for
        ?>  (~(valid-node-id logic [our.bowl now.bowl src.bowl state]) target.command)
        =/  ignored
          (log bowl %info [%lookup-start-for target.command recipient.command reply-path.command])
        =/  transition=[cards=(list card) update=lookup-update]
          %+  ~(start-for logic [our.bowl now.bowl src.bowl state])
            target.command
          [recipient.command reply-path.command]
        =^  cards  state  (apply-lookup-transition bowl transition)
        [cards this]
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
      =/  ignored  (log bowl %debug [%peer-nodes src.bowl id.message count.message])
      =/  transition=[cards=(list card) update=lookup-update]
        %+  ~(receive-nodes logic [our.bowl now.bowl src.bowl state])
          id.message
        [count.message packed.message]
      =^  cards  state  (apply-lookup-transition bowl transition)
      [cards this]
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
  ?.  ?=([%delivery @ @ ~] wire)  (on-agent:def wire sign)
  ?.  ?=(%poke-ack -.sign)  (on-agent:def wire sign)
  =/  peer=(unit @p)  (slaw %p i.t.wire)
  =/  id=(unit @ud)  (slaw %ud i.t.t.wire)
  ?~  peer  `this
  ?~  id  `this
  =/  ignored
    ?~  p.sign  ~
    (log bowl %debug [%delivery-poke-failed u.peer u.id])
  =/  transition=[cards=(list card) update=lookup-update]
    (~(delivery-ack logic [our.bowl now.bowl src.bowl state]) u.peer u.id p.sign)
  =^  cards  state  (apply-lookup-transition bowl transition)
  [cards this]
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
  ?:  ?=([%delivery-expire @ @ ~] wire)
    ?.  ?=(%wake +<.sign-arvo)  (on-arvo:def wire sign-arvo)
    =/  peer=(unit @p)  (slaw %p i.t.wire)
    =/  deadline=(unit @da)  (slaw %da i.t.t.wire)
    ?~  peer  `this
    ?~  deadline  `this
    =^  cards  state
      (~(delivery-expire logic [our.bowl now.bowl src.bowl state]) u.peer u.deadline)
    [cards this]
  ?.  ?=([%timeout @ ~] wire)  (on-arvo:def wire sign-arvo)
  ?.  ?=(%wake +<.sign-arvo)  (on-arvo:def wire sign-arvo)
  =/  request=(unit @uv)  (slaw %uv i.t.wire)
  ?~  request  `this
  ?.  (~(has by pending.state) u.request)  `this
  =/  ignored  (log bowl %debug [%request-timeout u.request])
  =/  transition=[cards=(list card) update=lookup-update]
    (~(fail-request logic [our.bowl now.bowl src.bowl state]) u.request |)
  =^  cards  state  (apply-lookup-transition bowl transition)
  [cards this]
::
++  on-watch  on-watch:def
++  on-leave  on-leave:def
++  on-fail   on-fail:def
--
