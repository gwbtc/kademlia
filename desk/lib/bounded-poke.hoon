::  A persistent, per-peer gate for remote Gall pokes.
::
/-  *bounded-poke
|_  [now=@da state=delivery-state]
::
++  init
  ^-  delivery-state
  [0 ~ 0 0]
::
::  summary: count live delivery state without materializing the peer map.
::
++  summary
  ^-  delivery-summary
  =/  walk
    |=  [entries=(map @p peer-delivery) out=delivery-summary]
    ^-  delivery-summary
    ?~  entries  out
    =.  out  $(entries l.entries, out out)
    =/  peer-state=peer-delivery  q.n.entries
    =.  peers.out  +(peers.out)
    =?  active.out  ?=(^ active.peer-state)  +(active.out)
    =.  queued-responses.out
      (add queued-responses.out (lent responses.peer-state))
    =.  queued-requests.out
      (add queued-requests.out (lent requests.peer-state))
    $(entries r.entries, out out)
  (walk peers.state [0 0 0 0 expired-total.state overflow-dropped.state])
::
++  delivery-wire
  |=  [peer=@p id=delivery-id]
  ^-  wire
  /delivery/(scot %p peer)/(scot %ud id)
::
++  expiry-wire
  |=  [peer=@p deadline=@da]
  ^-  wire
  /delivery-expire/(scot %p peer)/(scot %da deadline)
::
++  poke-card
  |=  item=queued-delivery
  ^-  card:agent:gall
  [%pass (delivery-wire peer.item id.item) note.item]
::
++  wait-card
  |=  [peer=@p deadline=@da]
  ^-  card:agent:gall
  [%pass (expiry-wire peer deadline) %arvo %b %wait deadline]
::
++  rest-card
  |=  [peer=@p deadline=@da]
  ^-  card:agent:gall
  [%pass (expiry-wire peer deadline) %arvo %b %rest deadline]
::
::  earliest: find the earliest deadline in both priority queues.
::
++  earliest
  |=  peer-state=peer-delivery
  ^-  (unit @da)
  =/  out=(unit @da)  ~
  =/  remaining=(list queued-delivery)
    (weld responses.peer-state requests.peer-state)
  |-
  ?~  remaining  out
  =/  deadline=@da  deadline.i.remaining
  ?~  out
    $(remaining t.remaining, out `deadline)
  =?  out  (lth deadline u.out)  `deadline
  $(remaining t.remaining)
::
::  schedule: replace the peer's queue wake if its earliest deadline changed.
::
++  schedule
  |=  [peer=@p peer-state=peer-delivery fired=?]
  ^-  [(list card:agent:gall) peer-delivery]
  =/  old=(unit @da)  wake.peer-state
  =/  new=(unit @da)  (earliest peer-state)
  ?:  =(old new)  [~ peer-state]
  =/  cards=(list card:agent:gall)  ~
  =?  cards  &(?=(^ old) !fired)  [(rest-card peer u.old) cards]
  =?  cards  ?=(^ new)  [(wait-card peer u.new) cards]
  [(flop cards) peer-state(wake new)]
::
::  take-live: prune expired entries and take the oldest live FIFO entry.
::
++  take-live
  |=  queue=(list queued-delivery)
  ^-  $:  selected=(unit queued-delivery)
          kept=(list queued-delivery)
          expired=(list delivery-context)
      ==
  =/  remaining=(list queued-delivery)  (flop queue)
  =/  selected=(unit queued-delivery)  ~
  =/  kept=(list queued-delivery)  ~
  =/  expired=(list delivery-context)  ~
  |-
  ?~  remaining  [selected kept (flop expired)]
  =/  item=queued-delivery  i.remaining
  ?:  (lte deadline.item now)
    $(remaining t.remaining, expired [context.item expired])
  ?~  selected
    $(remaining t.remaining, selected `item)
  $(remaining t.remaining, kept [item kept])
::
::  prune: remove every expired entry without selecting a delivery.
::
++  prune
  |=  queue=(list queued-delivery)
  ^-  [(list queued-delivery) (list delivery-context)]
  =/  remaining=(list queued-delivery)  queue
  =/  kept=(list queued-delivery)  ~
  =/  expired=(list delivery-context)  ~
  |-
  ?~  remaining  [(flop kept) (flop expired)]
  =/  item=queued-delivery  i.remaining
  ?:  (lte deadline.item now)
    $(remaining t.remaining, expired [context.item expired])
  $(remaining t.remaining, kept [item kept])
::
::  put-peer: write a peer state, deleting completely empty entries.
::
++  put-peer
  |=  [peer=@p peer-state=peer-delivery]
  ^-  delivery-state
  ?:  ?&  ?=(~ active.peer-state)
          ?=(~ responses.peer-state)
          ?=(~ requests.peer-state)
          ?=(~ wake.peer-state)
      ==
    state(peers (~(del by peers.state) peer))
  state(peers (~(put by peers.state) peer peer-state))
::
::  enqueue: send immediately or retain the expiring message in agent state.
::
++  enqueue
  |=  [peer=@p deadline=@da context=delivery-context note=note:agent:gall]
  ^-  [id=delivery-id update=delivery-update]
  =/  id=delivery-id  next-id.state
  =.  next-id.state  +(id)
  =/  item=queued-delivery  [id peer deadline context note]
  =/  peer-state=peer-delivery
    (~(gut by peers.state) peer *peer-delivery)
  ?~  active.peer-state
    =/  next=peer-delivery
      [`[id context] responses.peer-state requests.peer-state wake.peer-state]
    =.  state  (put-peer peer next)
    [id [[(poke-card item) ~] ~ ~ state]]
  =?  responses.peer-state  ?=(%response -.context)
    [item responses.peer-state]
  =?  requests.peer-state  ?=(%request -.context)
    [item requests.peer-state]
  =/  scheduled=[(list card:agent:gall) peer-delivery]
    (schedule peer peer-state |)
  =/  cards=(list card:agent:gall)  -.scheduled
  =.  state  (put-peer peer +.scheduled)
  [id [cards ~ ~ state]]
::
::  promote: after an ack, choose the next response or request for this peer.
::
++  promote
  |=  [peer=@p peer-state=peer-delivery]
  ^-  [(list card:agent:gall) (list delivery-context) peer-delivery]
  =/  responses-taken  (take-live responses.peer-state)
  =.  responses.peer-state  kept.responses-taken
  =/  requests-taken=[selected=(unit queued-delivery) kept=(list queued-delivery) expired=(list delivery-context)]
    ?^  selected.responses-taken
      =/  pruned  (prune requests.peer-state)
      [~ -.pruned +.pruned]
    (take-live requests.peer-state)
  =.  requests.peer-state  kept.requests-taken
  =/  expired=(list delivery-context)
    (weld expired.responses-taken expired.requests-taken)
  =/  selected=(unit queued-delivery)
    ?^(selected.responses-taken selected.responses-taken selected.requests-taken)
  =/  cards=(list card:agent:gall)  ~
  ?~  selected
    =^  wake-cards  peer-state  (schedule peer peer-state |)
    [(weld cards wake-cards) expired peer-state]
  =.  active.peer-state  `[id.u.selected context.u.selected]
  =.  cards  [(poke-card u.selected) cards]
  =^  wake-cards  peer-state  (schedule peer peer-state |)
  [(weld cards wake-cards) expired peer-state]
::
::  acknowledge: release exactly the matching active delivery and promote work.
::
++  acknowledge
  |=  [peer=@p id=delivery-id error=(unit tang)]
  ^-  delivery-update
  =/  found=(unit peer-delivery)  (~(get by peers.state) peer)
  ?~  found  [~ ~ ~ state]
  =/  peer-state=peer-delivery  u.found
  ?~  active.peer-state  [~ ~ ~ state]
  ?.  =(id id.u.active.peer-state)  [~ ~ ~ state]
  =/  acked=delivery-ack  [context.u.active.peer-state error]
  =/  inactive=peer-delivery
    [~ responses.peer-state requests.peer-state wake.peer-state]
  =/  promoted=[(list card:agent:gall) (list delivery-context) peer-delivery]
    (promote peer inactive)
  =/  cards=(list card:agent:gall)  -.promoted
  =/  expired=(list delivery-context)  +<.promoted
  =.  state  (put-peer peer +>.promoted)
  =.  expired-total.state  (add expired-total.state (lent expired))
  [cards expired `acked state]
::
::  cancel: remove a delivery only while it remains in the local queue.
::
++  cancel
  |=  [peer=@p id=delivery-id]
  ^-  delivery-update
  =/  found=(unit peer-delivery)  (~(get by peers.state) peer)
  ?~  found  [~ ~ ~ state]
  =/  peer-state=peer-delivery  u.found
  =/  drop
    |=  queue=(list queued-delivery)
    ^-  (list queued-delivery)
    (skim queue |=(item=queued-delivery !=(id id.item)))
  =.  responses.peer-state  (drop responses.peer-state)
  =.  requests.peer-state  (drop requests.peer-state)
  =^  cards  peer-state  (schedule peer peer-state |)
  =.  state  (put-peer peer peer-state)
  [cards ~ ~ state]
::
::  expire: service the currently expected queue wake for a peer.
::
++  expire
  |=  [peer=@p deadline=@da]
  ^-  delivery-update
  =/  found=(unit peer-delivery)  (~(get by peers.state) peer)
  ?~  found  [~ ~ ~ state]
  =/  peer-state=peer-delivery  u.found
  ?.  =(wake.peer-state `deadline)  [~ ~ ~ state]
  =.  wake.peer-state  ~
  =/  responses-pruned  (prune responses.peer-state)
  =/  requests-pruned  (prune requests.peer-state)
  =.  responses.peer-state  -.responses-pruned
  =.  requests.peer-state  -.requests-pruned
  =/  expired=(list delivery-context)
    (weld +.responses-pruned +.requests-pruned)
  =^  cards  peer-state  (schedule peer peer-state &)
  =.  state  (put-peer peer peer-state)
  =.  expired-total.state  (add expired-total.state (lent expired))
  [cards expired ~ state]
::
::  reset: retain active Gall bookkeeping but discard every local queue.
::
++  reset
  ^-  [(list card:agent:gall) delivery-state]
  =/  entries=(list [@p peer-delivery])  ~(tap by peers.state)
  =/  cards=(list card:agent:gall)  ~
  =/  peers=(map @p peer-delivery)  ~
  |-
  ?~  entries  [(flop cards) state(peers peers)]
  =/  [peer=@p peer-state=peer-delivery]  i.entries
  =?  cards  ?=(^ wake.peer-state)
    [(rest-card peer u.wake.peer-state) cards]
  =.  responses.peer-state  ~
  =.  requests.peer-state  ~
  =.  wake.peer-state  ~
  =?  peers  ?=(^ active.peer-state)
    (~(put by peers) peer peer-state)
  $(entries t.entries)
--
