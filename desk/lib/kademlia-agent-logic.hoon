::  Pure state transitions and card construction for the Kademlia agent.
::
/-  *kademlia, *kademlia-agent
/+  kad=kademlia
=/  cfg=config  [20 20 3 12 %kademlia-urbit-v1]
=/  protocol=protocol-version  %kademlia-v1
=/  default-request-timeout=@dr  ~m5
=/  default-refresh-interval=@dr  ~h1
=/  refresh-yield=@dr  ~s1
=/  max-fails=@ud  3
=/  max-response-nodes=@ud  20
|_  $:  our=@p
        now=@da
        src=@p
        state=agent-state
    ==
++  self-id
  ^-  node-id
  (~(ship-to-node kad cfg) our)
::
::  valid-id: require lookup and peer request IDs to fit in 64 bits.
::
++  valid-id
  |=  id=@
  ^-  ?
  (lte (met 0 id) 64)
::
::  valid-node-id: expose the configured 128-bit node-ID validation.
::
++  valid-node-id
  |=  id=node-id
  ^-  ?
  (~(valid-node kad cfg) id)
::
::  bump-id: advance a counter modulo the 64-bit ID space.
::
++  bump-id
  |=  id=@
  ^-  @uv
  (end 6 +(id))
::
::  take-request-id: allocate an unused peer request ID.
::
++  take-request-id
  ^-  [request-id agent-state]
  =/  id=request-id  (end 6 next-request.state)
  |-
  ?:  (~(has by pending.state) id)
    $(id (bump-id id))
  =.  next-request.state  (bump-id id)
  [id state]
::
::  take-lookup-id: allocate an unused internally-owned lookup ID.
::
++  take-lookup-id
  ^-  [lookup-id agent-state]
  =/  id=lookup-id  (end 6 next-lookup.state)
  |-
  ?:  ?|  (~(has by active.state) id)
          (~(has by completed.state) id)
          (~(has by callbacks.state) id)
          =(maintenance.state `id)
      ==
    $(id (bump-id id))
  =.  next-lookup.state  (bump-id id)
  [id state]
::
++  init
  ^-  agent-state
  :*  (~(empty-table kad cfg) now)
      ~  ~  ~  ~  0v1
      [default-request-timeout default-refresh-interval]
      ~  0v1
      `(add default-refresh-interval now)
      ~
  ==
::
::  refresh-card: recreate the one currently expected global refresh wake.
::
++  refresh-card
  ^-  (list card:agent:gall)
  ?~  refresh-at.state  ~
  :~  [%pass /refresh/(scot %da u.refresh-at.state) %arvo %b %wait u.refresh-at.state]
  ==
::
++  complete
  |=  [id=lookup-id lup=lookup result=(list node-id)]
  ^-  agent-state
  =.  active.state  (~(del by active.state) id)
  =.  completed.state  (~(put by completed.state) id [target.lup result])
  state
::
++  advance
  |=  [id=lookup-id lup=lookup]
  ^-  [(list card:agent:gall) lookup-update]
  =/  dispatched=[peers=(list node-id) state=lookup]
    (~(dispatch kad cfg) lup)
  =.  lup  state.dispatched
  =.  active.state  (~(put by active.state) id lup)
  =/  result=(unit (list node-id))  (~(lookup-result kad cfg) lup)
  ?^  result
    [~ `id (complete id lup u.result)]
  =/  peers=(list node-id)  peers.dispatched
  =/  cards=(list card:agent:gall)  ~
  |-
  ?~  peers  [(flop cards) ~ state]
  =/  peer=node-id  i.peers
  =^  request  state  take-request-id
  =/  deadline=@da  (add request-timeout.settings.state now)
  =/  pending=pending-request  [id peer now deadline]
  =.  pending.state  (~(put by pending.state) request pending)
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
  ^-  [(list card:agent:gall) lookup-update]
  ?.  (valid-id request)  [~ ~ state]
  =/  pending=(unit pending-request)  (~(get by pending.state) request)
  ?~  pending  [~ ~ state]
  =/  pen=pending-request  u.pending
  =.  pending.state  (~(del by pending.state) request)
  =/  cancellation=(list card:agent:gall)
    ?:  cancel
      :~  [%pass /timeout/(scot %uv request) %arvo %b %rest deadline.pen]
      ==
    ~
  =/  active=(unit lookup)  (~(get by active.state) lookup.pen)
  ?~  active  [cancellation ~ state]
  =/  failed=[routing=table state=lookup]
    (~(timeout kad cfg) self-id peer.pen max-fails routing.state u.active)
  =.  routing.state  routing.failed
  =/  advanced=[(list card:agent:gall) lookup-update]
    (advance lookup.pen state.failed)
  [(weld cancellation -.advanced) +.advanced]
::
::  pack-nodes: encode at most twenty IDs as fixed 128-bit chunks.  The first
::    list item occupies the least-significant chunk.
::
++  pack-nodes
  |=  ids=(list node-id)
  ^-  [count=@ud packed=@]
  =/  bounded=(list node-id)  (scag max-response-nodes ids)
  [(lent bounded) (rep [7 1] bounded)]
::
::  valid-node-payload: enforce the protocol count and packed-atom bounds.
::
++  valid-node-payload
  |=  [count=@ud packed=@]
  ^-  ?
  ?:  (gth count max-response-nodes)  |
  (lte (met 0 packed) (mul count 128))
::
::  unpack-nodes: decode exactly .count fixed-width chunks, retaining zero IDs.
::
++  unpack-nodes
  |=  [count=@ud packed=@]
  ^-  (list node-id)
  ?>  (valid-node-payload count packed)
  =/  index=@ud  0
  =/  ids=(list node-id)  ~
  |-
  ?:  =(index count)  (flop ids)
  $(index +(index), ids [`node-id`(cut 7 [index 1] packed) ids])
::
++  receive-nodes
  |=  [request=request-id count=@ud packed=@]
  ^-  [(list card:agent:gall) lookup-update]
  ?.  (valid-id request)  [~ ~ state]
  =/  pending=(unit pending-request)  (~(get by pending.state) request)
  ?~  pending  [~ ~ state]
  =/  pen=pending-request  u.pending
  =/  sender=node-id  (~(ship-to-node kad cfg) src)
  ?.  =(sender peer.pen)  [~ ~ state]
  ?.  (valid-node-payload count packed)
    (fail-request request &)
  =/  ids=(list node-id)  (unpack-nodes count packed)
  =.  pending.state  (~(del by pending.state) request)
  =/  cancellation=card:agent:gall
    [%pass /timeout/(scot %uv request) %arvo %b %rest deadline.pen]
  =/  active=(unit lookup)  (~(get by active.state) lookup.pen)
  ?~  active  [[cancellation ~] ~ state]
  =/  received=[routing=table state=lookup]
    (~(receive kad cfg) self-id sender now (scag k.cfg ids) routing.state u.active)
  =.  routing.state  routing.received
  =/  advanced=[(list card:agent:gall) lookup-update]
    (advance lookup.pen state.received)
  [[cancellation -.advanced] +.advanced]
::
++  receive-find-node
  |=  [request=request-id target=node-id]
  ^-  [(list card:agent:gall) agent-state]
  ?.  (valid-id request)  [~ state]
  ?.  (~(valid-node kad cfg) target)  [~ state]
  =/  sender=node-id  (~(ship-to-node kad cfg) src)
  =.  routing.state  (~(record-success kad cfg) self-id sender now routing.state)
  =/  nearest=(list contact)
    (~(nearest-contacts kad cfg) target k.cfg `sender routing.state)
  =/  ids=(list node-id)  (turn nearest |=(con=contact id.con))
  =/  payload=[count=@ud packed=@]  (pack-nodes ids)
  =/  message=peer-message  [%nodes protocol request count.payload packed.payload]
  :-  :~  :*  %pass  /response/(scot %uv request)
             %agent  [src %kademlia]
             %poke  %kademlia-message  !>(message)
         ==
      ==
  state
::
++  set-seeds
  |=  ships=(list @p)
  ^-  agent-state
  =/  ids=(set node-id)  ~
  =/  remaining=(list @p)  ships
  |-
  ?~  remaining  state(seeds ids)
  =/  id=node-id  (~(ship-to-node kad cfg) i.remaining)
  =?  ids  !=(id self-id)  (~(put in ids) id)
  $(remaining t.remaining)
::
::  bootstrap: advance the global wake when fresh seeds can populate an empty table.
::
++  bootstrap
  ^-  [(list card:agent:gall) agent-state]
  ?:  ?|  ?=(~ seeds.state)
          ?=(^ maintenance.state)
          ?=(^ (~(contacts kad cfg) routing.state))
      ==
    [~ state]
  =/  cards=(list card:agent:gall)  ~
  =.  cards
    ?~  refresh-at.state  cards
    [[%pass /refresh/(scot %da u.refresh-at.state) %arvo %b %rest u.refresh-at.state] cards]
  =/  deadline=@da  +(now)
  =.  refresh-at.state  `deadline
  =.  cards
    [[%pass /refresh/(scot %da deadline) %arvo %b %wait deadline] cards]
  [(flop cards) state]
::
::  set-request-timeout: update the positive timeout used for new requests.
::
++  set-request-timeout
  |=  duration=@dr
  ^-  agent-state
  ?>  (gth duration 0)
  state(request-timeout.settings duration)
::
::  set-refresh-interval: replace the cadence and the one outstanding wake.
::
++  set-refresh-interval
  |=  duration=@dr
  ^-  [(list card:agent:gall) agent-state]
  ?>  (gth duration 0)
  =.  refresh-interval.settings.state  duration
  =/  cards=(list card:agent:gall)  ~
  =.  cards
    ?~  refresh-at.state  cards
    [[%pass /refresh/(scot %da u.refresh-at.state) %arvo %b %rest u.refresh-at.state] cards]
  =.  refresh-at.state  ~
  ?:  ?=(^ maintenance.state)
    [(flop cards) state]
  =/  scheduled=[(list card:agent:gall) agent-state]  schedule-next-refresh
  [(weld (flop cards) -.scheduled) +.scheduled]
::
++  start
  |=  [id=lookup-id target=node-id]
  ^-  [(list card:agent:gall) lookup-update]
  ?>  (valid-id id)
  ?>  (~(valid-node kad cfg) target)
  ?>  !(~(has by active.state) id)
  ?>  !(~(has by completed.state) id)
  =.  routing.state  (~(touch-bucket kad cfg) target now routing.state)
  =/  lup=lookup  (~(start-lookup kad cfg) self-id target routing.state)
  =.  lup  (~(learn kad cfg) self-id ~(tap in seeds.state) lup)
  (advance id lup)
::
::  refresh-ref-before: order bucket references by age, then prefix identity.
::
++  refresh-ref-before
  |=  [a=bucket-ref b=bucket-ref]
  ^-  ?
  ?:  !=(refreshed.a refreshed.b)  (lth refreshed.a refreshed.b)
  ?:  !=(depth.a depth.b)  (lth depth.a depth.b)
  (lth prefix.a prefix.b)
::
::  due-refresh: return the stalest leaf whose interval has elapsed.
::
++  due-refresh
  ^-  (unit bucket-ref)
  =/  refs=(list bucket-ref)  (~(bucket-refs kad cfg) routing.state)
  =/  chosen=(unit bucket-ref)  ~
  |-
  ?~  refs  chosen
  =/  ref=bucket-ref  i.refs
  ?:  (gth (add refresh-interval.settings.state refreshed.ref) now)
    $(refs t.refs)
  ?~  chosen
    $(refs t.refs, chosen `ref)
  ?:  (refresh-ref-before ref u.chosen)
    $(refs t.refs, chosen `ref)
  $(refs t.refs)
::
::  next-refresh-deadline: find the earliest future due time across all leaves.
::
++  next-refresh-deadline
  ^-  @da
  =/  tab=table  routing.state
  |-
  ?-  -.tab
    %leaf  (add refresh-interval.settings.state refreshed.buc.tab)
    %fork
      =/  zero-due=@da  $(tab zero.tab)
      =/  one-due=@da  $(tab one.tab)
      ?:  (lth zero-due one-due)  zero-due
      one-due
  ==
::
::  schedule-next-refresh: install the sole global wake for the earliest leaf.
::
++  schedule-next-refresh
  ^-  [(list card:agent:gall) agent-state]
  ?>  ?=(~ maintenance.state)
  =/  due=@da  next-refresh-deadline
  =/  deadline=@da  ?:((lte due now) +(now) due)
  =.  refresh-at.state  `deadline
  :-  :~  [%pass /refresh/(scot %da deadline) %arvo %b %wait deadline]
      ==
  state
::
::  drive-refresh: start one stale-bucket lookup or schedule the next wake.
::
++  drive-refresh
  |=  entropy=@
  ^-  [(list card:agent:gall) agent-state]
  ?.  =(~ maintenance.state)  [~ state]
  =/  due=(unit bucket-ref)  due-refresh
  ?~  due  schedule-next-refresh
  =/  target=node-id  (~(refresh-target kad cfg) u.due entropy)
  =^  id  state  take-lookup-id
  =.  maintenance.state  `id
  =/  started=[(list card:agent:gall) lookup-update]  (start id target)
  =.  state  state.+.started
  ?~  completion.+.started
    [-.started state]
  ::  An empty lookup completed synchronously.  Reap it and yield via Behn.
  =.  completed.state  (~(del by completed.state) id)
  =.  maintenance.state  ~
  =/  deadline=@da  (add refresh-yield now)
  =.  refresh-at.state  `deadline
  =/  timer=card:agent:gall
    [%pass /refresh/(scot %da deadline) %arvo %b %wait deadline]
  [(weld -.started [timer ~]) state]
::
::  run-refresh: consume a matching global wake and begin a refresh step.
::
++  run-refresh
  |=  [deadline=@da entropy=@]
  ^-  [(list card:agent:gall) agent-state]
  ?.  =(refresh-at.state `deadline)  [~ state]
  =.  refresh-at.state  ~
  ?:  ?=(^ maintenance.state)  [~ state]
  (drive-refresh entropy)
::
::  continue-refresh: after a maintenance lookup settles, start the next due leaf.
::
++  continue-refresh
  |=  [id=lookup-id entropy=@]
  ^-  [(list card:agent:gall) agent-state]
  ?.  =(maintenance.state `id)  [~ state]
  ?.  (~(has by completed.state) id)  [~ state]
  =.  completed.state  (~(del by completed.state) id)
  =.  maintenance.state  ~
  (drive-refresh entropy)
::
::  start-for: allocate an internal lookup ID and remember its local callback.
::
++  start-for
  |=  [target=node-id callback=lookup-callback]
  ^-  [(list card:agent:gall) lookup-update]
  =^  id  state  take-lookup-id
  =.  callbacks.state  (~(put by callbacks.state) id callback)
  (start id target)
::
::  notify: emit the callback for one completed lookup, if it has one.
::
++  notify
  |=  id=lookup-id
  ^-  [(list card:agent:gall) agent-state]
  =/  callback=(unit lookup-callback)  (~(get by callbacks.state) id)
  ?~  callback  [~ state]
  =/  result=(unit lookup-result)  (~(get by completed.state) id)
  ?~  result  [~ state]
  =/  notice=lookup-notice  [reply-path.u.callback u.result]
  =/  card=card:agent:gall
    :*  %pass  /callback/(scot %uv id)
        %agent  [our recipient.u.callback]
        %poke  %kademlia-result  !>(notice)
    ==
  =.  callbacks.state  (~(del by callbacks.state) id)
  =.  completed.state  (~(del by completed.state) id)
  [[card ~] state]
::
++  forget
  |=  id=lookup-id
  ^-  agent-state
  ?>  (valid-id id)
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
      refresh-at.state
      maintenance.state
  ==
::
++  seed-list
  ^-  (list node-id)
  (sort ~(tap in seeds.state) |=([a=node-id b=node-id] (lth a b)))
::
++  get-lookup
  |=  id=lookup-id
  ^-  (unit lookup-view)
  ?.  (valid-id id)  ~
  =/  active=(unit lookup)  (~(get by active.state) id)
  ?^  active  `[%running u.active]
  =/  completed=(unit lookup-result)  (~(get by completed.state) id)
  ?~  completed  ~
  `[%complete u.completed]
--
