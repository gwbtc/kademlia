::  Pure state transitions and card construction for the Kademlia agent.
::
/-  *kademlia, *kademlia-agent
/+  kad=kademlia
=/  cfg=config  [20 20 3 12 %kademlia-urbit-v1]
=/  protocol=protocol-version  %kademlia-v1
=/  default-request-timeout=@dr  ~m5
=/  max-fails=@ud  3
|_  $:  our=@p
        now=@da
        src=@p
        state=state-2
    ==
++  self-id
  ^-  node-id
  (~(ship-to-node kad cfg) our)
::
++  init
  ^-  state-2
  [%2 ~(empty-table kad cfg) ~ ~ ~ ~ 0v1 [default-request-timeout] ~ 0v1]
::
::  migrate: preserve version-zero lookup/routing state and add defaults.
::
++  migrate
  |=  old=versioned-state
  ^-  state-2
  ?-  -.old
    %0  [%2 routing.old seeds.old active.old pending.old completed.old next-request.old [default-request-timeout] ~ 0v1]
    %1  [%2 routing.old seeds.old active.old pending.old completed.old next-request.old settings.old ~ 0v1]
    %2  old
  ==
::
++  complete
  |=  [id=lookup-id lup=lookup]
  ^-  state-2
  =/  result=(unit (list node-id))  (~(lookup-result kad cfg) lup)
  ?~  result  state
  =.  active.state  (~(del by active.state) id)
  =.  completed.state  (~(put by completed.state) id [target.lup u.result])
  state
::
++  advance
  |=  [id=lookup-id lup=lookup]
  ^-  [(list card:agent:gall) state-2]
  =/  dispatched=[peers=(list node-id) state=lookup]
    (~(dispatch kad cfg) lup)
  =.  lup  state.dispatched
  =.  active.state  (~(put by active.state) id lup)
  ?:  (~(lookup-complete kad cfg) lup)
    [~ (complete id lup)]
  =/  peers=(list node-id)  peers.dispatched
  =/  cards=(list card:agent:gall)  ~
  |-
  ?~  peers  [(flop cards) state]
  =/  peer=node-id  i.peers
  =/  request=request-id  next-request.state
  =/  deadline=@da  (add request-timeout.settings.state now)
  =/  pending=pending-request  [id peer now deadline]
  =.  pending.state  (~(put by pending.state) request pending)
  =.  next-request.state  +(request)
  =/  ship=@p  (~(node-to-ship kad cfg) peer)
  =/  message=peer-message  [%find-node protocol request target.lup]
  =/  poke=card:agent:gall
    :*  %pass  /request/(scot %uv request)
        %agent  [ship %kademlia]
        %poke  %kademlia-message  !>(message)
    ==
  =/  timer=card:agent:gall
    [%pass /timeout/(scot %uv request) %arvo %b %wait deadline]
  $(peers t.peers, cards [timer poke cards])
::
++  fail-request
  |=  [request=request-id cancel=?]
  ^-  [(list card:agent:gall) state-2]
  =/  pending=(unit pending-request)  (~(get by pending.state) request)
  ?~  pending  [~ state]
  =/  pen=pending-request  u.pending
  =.  pending.state  (~(del by pending.state) request)
  =/  cancellation=(list card:agent:gall)
    ?:  cancel
      :~  [%pass /timeout/(scot %uv request) %arvo %b %rest deadline.pen]
      ==
    ~
  =/  active=(unit lookup)  (~(get by active.state) lookup.pen)
  ?~  active  [cancellation state]
  =/  failed=[routing=table state=lookup]
    (~(timeout kad cfg) self-id peer.pen max-fails routing.state u.active)
  =.  routing.state  routing.failed
  =/  advanced=[(list card:agent:gall) state-2]
    (advance lookup.pen state.failed)
  [(weld cancellation -.advanced) +.advanced]
::
++  receive-nodes
  |=  [request=request-id ids=(list node-id)]
  ^-  [(list card:agent:gall) state-2]
  =/  pending=(unit pending-request)  (~(get by pending.state) request)
  ?~  pending  [~ state]
  =/  pen=pending-request  u.pending
  =/  sender=node-id  (~(ship-to-node kad cfg) src)
  ?.  =(sender peer.pen)  [~ state]
  =.  pending.state  (~(del by pending.state) request)
  =/  cancellation=card:agent:gall
    [%pass /timeout/(scot %uv request) %arvo %b %rest deadline.pen]
  =/  active=(unit lookup)  (~(get by active.state) lookup.pen)
  ?~  active  [[cancellation ~] state]
  =/  received=[routing=table state=lookup]
    (~(receive kad cfg) self-id sender now (scag k.cfg ids) routing.state u.active)
  =.  routing.state  routing.received
  =/  advanced=[(list card:agent:gall) state-2]
    (advance lookup.pen state.received)
  [[cancellation -.advanced] +.advanced]
::
++  receive-find-node
  |=  [request=request-id target=node-id]
  ^-  [(list card:agent:gall) state-2]
  ?.  (~(valid-node kad cfg) target)  [~ state]
  =/  sender=node-id  (~(ship-to-node kad cfg) src)
  =.  routing.state  (~(record-success kad cfg) self-id sender now routing.state)
  =/  known=(list contact)
    %+  skip  (~(contacts kad cfg) routing.state)
    |=  con=contact
    =(sender id.con)
  =/  nearest=(list contact)  (~(closest kad cfg) target k.cfg known)
  =/  ids=(list node-id)  (turn nearest |=(con=contact id.con))
  =/  message=peer-message  [%nodes protocol request ids]
  :-  :~  :*  %pass  /response/(scot %uv request)
             %agent  [src %kademlia]
             %poke  %kademlia-message  !>(message)
         ==
      ==
  state
::
++  set-seeds
  |=  ships=(list @p)
  ^-  state-2
  =/  ids=(set node-id)  ~
  =/  remaining=(list @p)  ships
  |-
  ?~  remaining  state(seeds ids)
  =/  id=node-id  (~(ship-to-node kad cfg) i.remaining)
  =?  ids  !=(id self-id)  (~(put in ids) id)
  $(remaining t.remaining)
::
::  set-request-timeout: update the positive timeout used for new requests.
::
++  set-request-timeout
  |=  duration=@dr
  ^-  state-2
  ?>  (gth duration 0)
  state(request-timeout.settings duration)
::
++  start
  |=  [id=lookup-id target=node-id]
  ^-  [(list card:agent:gall) state-2]
  ?>  (~(valid-node kad cfg) target)
  ?>  !(~(has by active.state) id)
  ?>  !(~(has by completed.state) id)
  =/  lup=lookup  (~(start-lookup kad cfg) self-id target routing.state)
  =.  lup  (~(learn kad cfg) self-id ~(tap in seeds.state) lup)
  (advance id lup)
::
::  start-for: allocate an internal lookup ID and remember its local callback.
::
++  start-for
  |=  [target=node-id callback=lookup-callback]
  ^-  [(list card:agent:gall) state-2]
  =/  id=lookup-id  next-lookup.state
  |-
  ?:  ?|  (~(has by active.state) id)
          (~(has by completed.state) id)
          (~(has by callbacks.state) id)
      ==
    $(id +(id))
  =.  next-lookup.state  +(id)
  =.  callbacks.state  (~(put by callbacks.state) id callback)
  (start id target)
::
::  notify: emit each completed callback exactly once.
::
++  notify
  ^-  [(list card:agent:gall) state-2]
  =/  remaining=(list [lookup-id lookup-callback])  ~(tap by callbacks.state)
  =/  cards=(list card:agent:gall)  ~
  |-
  ?~  remaining  [(flop cards) state]
  =/  id=lookup-id  -.i.remaining
  =/  callback=lookup-callback  +.i.remaining
  =/  result=(unit lookup-result)  (~(get by completed.state) id)
  ?~  result  $(remaining t.remaining)
  =/  notice=lookup-notice  [wire.callback u.result]
  =/  card=card:agent:gall
    :*  %pass  /callback/(scot %uv id)
        %agent  [our recipient.callback]
        %poke  %kademlia-result  !>(notice)
    ==
  =.  callbacks.state  (~(del by callbacks.state) id)
  =.  completed.state  (~(del by completed.state) id)
  $(remaining t.remaining, cards [card cards])
::
++  forget
  |=  id=lookup-id
  ^-  state-2
  ?>  !(~(has by active.state) id)
  state(completed (~(del by completed.state) id))
::
++  get-summary
  ^-  summary
  :*  self-id
      (lent ~(tap in seeds.state))
      (lent ~(tap by active.state))
      (lent ~(tap by pending.state))
      (lent ~(tap by completed.state))
  ==
::
++  seed-list
  ^-  (list node-id)
  (sort ~(tap in seeds.state) |=([a=node-id b=node-id] (lth a b)))
::
++  get-lookup
  |=  id=lookup-id
  ^-  (unit lookup-view)
  =/  active=(unit lookup)  (~(get by active.state) id)
  ?^  active  `[%running u.active]
  =/  completed=(unit lookup-result)  (~(get by completed.state) id)
  ?~  completed  ~
  `[%complete u.completed]
--
