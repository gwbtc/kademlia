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
^-  agent:gall
|_  =bowl:gall
+*  this  .
    def   ~(. (default-agent this %|) bowl)
::
++  on-init
  ^-  (quip card _this)
  ~&  [%kademlia our.bowl %init]
  =.  state  ~(init logic [our.bowl now.bowl src.bowl state])
  `this
::
++  on-save  !>(state)
::
++  on-load
  |=  old=vase
  ^-  (quip card _this)
  ~&  [%kademlia our.bowl %load]
  `this(state !<(agent-state old))
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
        ~&  [%kademlia our.bowl %set-seeds ships.command]
        =.  state  (~(set-seeds logic [our.bowl now.bowl src.bowl state]) ships.command)
        `this
      %set-request-timeout
        ~&  [%kademlia our.bowl %set-request-timeout duration.command]
        =.  state
          (~(set-request-timeout logic [our.bowl now.bowl src.bowl state]) duration.command)
        `this
      %find
        ~&  [%kademlia our.bowl %find id.command target.command]
        =^  cards  state
          (~(start logic [our.bowl now.bowl src.bowl state]) id.command target.command)
        ~&  [%kademlia our.bowl %dispatch id.command ~(tap by pending.state)]
        [cards this]
      %find-for
        ~&  [%kademlia our.bowl %find-for target.command recipient.command]
        =^  cards  state
          %+  ~(start-for logic [our.bowl now.bowl src.bowl state])
            target.command
          [recipient.command reply-path.command]
        =^  notices  state  ~(notify logic [our.bowl now.bowl src.bowl state])
        [(weld cards notices) this]
      %forget
        ~&  [%kademlia our.bowl %forget id.command]
        =.  state  (~(forget logic [our.bowl now.bowl src.bowl state]) id.command)
        `this
    ==
  ::
      %kademlia-message
    =/  message=peer-message  !<(peer-message vase)
    ?.  =(%kademlia-v1 version.message)
      ~&  [%kademlia our.bowl %ignore-version src.bowl version.message]
      `this
    ?-    -.message
        %find-node
      ~&  [%kademlia our.bowl now.bowl %find-node src.bowl id.message target.message]
      =^  cards  state
        (~(receive-find-node logic [our.bowl now.bowl src.bowl state]) id.message target.message)
      [cards this]
    ::
        %nodes
      ~&  [%kademlia our.bowl now.bowl %nodes src.bowl id.message contacts.message]
      =^  cards  state
        (~(receive-nodes logic [our.bowl now.bowl src.bowl state]) id.message contacts.message)
      =^  notices  state  ~(notify logic [our.bowl now.bowl src.bowl state])
      ~&  [%kademlia our.bowl %advance id.message ~(tap by pending.state)]
      [(weld cards notices) this]
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
      [%x %lookup ~]    [~ ~]
      [%x %lookup @ ~]
    =/  parsed=(unit @uv)  (slaw %uv i.t.t.path)
    ?~  parsed  ~
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
  ~&  [%kademlia our.bowl %poke-failed u.request]
  =^  cards  state
    (~(fail-request logic [our.bowl now.bowl src.bowl state]) u.request &)
  =^  notices  state  ~(notify logic [our.bowl now.bowl src.bowl state])
  ~&  [%kademlia our.bowl %advance-after-failure u.request ~(tap by pending.state)]
  [(weld cards notices) this]
::
++  on-arvo
  |=  [=wire =sign-arvo]
  ^-  (quip card _this)
  ?.  ?=([%timeout @ ~] wire)  (on-arvo:def wire sign-arvo)
  ?.  ?=(%wake +<.sign-arvo)  (on-arvo:def wire sign-arvo)
  =/  request=(unit @uv)  (slaw %uv i.t.wire)
  ?~  request  `this
  ?.  (~(has by pending.state) u.request)  `this
  ~&  [%kademlia our.bowl now.bowl %timeout u.request]
  =^  cards  state
    (~(fail-request logic [our.bowl now.bowl src.bowl state]) u.request |)
  =^  notices  state  ~(notify logic [our.bowl now.bowl src.bowl state])
  ~&  [%kademlia our.bowl %advance-after-timeout u.request ~(tap by pending.state)]
  [(weld cards notices) this]
::
++  on-watch  on-watch:def
++  on-leave  on-leave:def
++  on-fail   on-fail:def
--
