::  Pure storage and request state transitions for %content-routing.
::
/-  *kademlia, *kademlia-agent, *content-routing, *content-routing-agent
/+  kad=kademlia, cr=content-routing
=/  kad-cfg=config  [20 20 3 12 %kademlia-urbit-v1]
=/  protocol=content-version  %content-routing-v1
=/  defaults=content-config  [20 3 ~m5 ~d1 ~h12 65.536 64 10.000]
|_  $:  our=@p
        now=@da
        src=@p
        state=content-state-0
        verify=verifier
    ==
++  self-id
  ^-  node-id
  (~(ship-to-node kad kad-cfg) our)
::
++  init
  ^-  content-state-0
  [%0 defaults ~ ~ ~ ~ ~ 0v1 (add refresh.defaults now) 0v1 ~]
::
++  config-valid
  |=  cfg=content-config
  ^-  ?
  ?&  (gth replication.cfg 0)
      (gth concurrency.cfg 0)
      (lte concurrency.cfg replication.cfg)
      (gth request-timeout.cfg 0)
      (gth lease.cfg 0)
      (gth refresh.cfg 0)
      (lth refresh.cfg lease.cfg)
      (gth max-record-bytes.cfg 0)
      (gth max-providers.cfg 0)
      (gth max-replica-keys.cfg 0)
  ==
::
++  set-config
  |=  cfg=content-config
  ^-  content-state-0
  ?>  (config-valid cfg)
  state(config cfg)
::
++  record-key
  |=  rec=record
  ^-  key
  ?-  -.rec
    %pointer   key.body.value.rec
    %provider  (provider-key:cr content.body.value.rec)
  ==
::
++  record-signer
  |=  rec=record
  ^-  node-id
  ?-  -.rec
    %pointer   publisher.body.value.rec
    %provider  provider.body.value.rec
  ==
::
++  record-revision
  |=  rec=record
  ^-  @ud
  ?-  -.rec
    %pointer   revision.body.value.rec
    %provider  revision.body.value.rec
  ==
::
++  record-expiry
  |=  rec=record
  ^-  (unit @da)
  ?-  -.rec
    %pointer   expires.body.value.rec
    %provider  `expires.body.value.rec
  ==
::
++  record-auth-valid
  |=  rec=record
  ^-  ?
  ?-  -.rec
    %pointer
      =/  body=pointer-body  body.value.rec
      (pointer-valid:cr now namespace.body key.body publisher.body verify value.rec)
    %provider
      (provider-valid:cr now content.body.value.rec verify value.rec)
  ==
::
++  record-valid
  |=  rec=record
  ^-  ?
  ?&  (lte (met 3 (jam rec)) max-record-bytes.config.state)
      (record-auth-valid rec)
  ==
::
++  prune-list
  |=  values=leased-records
  ^-  leased-records
  ?~  values  ~
  =/  rest=leased-records  $(values t.values)
  ?:  (lth now lease-until.i.values)  [i.values rest]
  rest
::
++  prune
  ^-  content-state-0
  =/  entries=(list [key leased-records])  ~(tap by replicas.state)
  =/  fresh=(map key leased-records)  ~
  |-
  ?~  entries  state(replicas fresh)
  =/  values=leased-records  (prune-list +.i.entries)
  =?  fresh  ?=(^ values)  (~(put by fresh) -.i.entries values)
  $(entries t.entries)
::
++  lease-horizon
  |=  values=leased-records
  ^-  @da
  ?~  values  *@da
  =/  rest=@da  $(values t.values)
  (max lease-until.i.values rest)
::
++  evict-one
  ^-  content-state-0
  =/  entries=(list [key leased-records])  ~(tap by replicas.state)
  ?~  entries  state
  =/  victim=key  -.i.entries
  =/  horizon=@da  (lease-horizon +.i.entries)
  =/  remaining=(list [key leased-records])  t.entries
  |-
  ?~  remaining  state(replicas (~(del by replicas.state) victim))
  =/  candidate=key  -.i.remaining
  =/  candidate-horizon=@da  (lease-horizon +.i.remaining)
  =/  replace=?
    ?|  (lth candidate-horizon horizon)
        ?&  =(candidate-horizon horizon)
            (lth candidate victim)
        ==
    ==
  $(remaining t.remaining, victim ?:(replace candidate victim), horizon ?:(replace candidate-horizon horizon))
::
++  values-for
  |=  target=key
  ^-  records
  =/  fresh=content-state-0  prune
  =/  values=leased-records  (~(gut by replicas.fresh) [target ~])
  =/  out=records  (turn values |=(item=leased-record value.item))
  =/  origin=(unit record)  (~(get by origins.state) target)
  ?~  origin  out
  [u.origin out]
::
++  signer-count
  |=  values=leased-records
  ^-  @ud
  =/  ids=(set node-id)  ~
  =/  remaining=leased-records  values
  |-
  ?~  remaining  (lent ~(tap in ids))
  =.  ids  (~(put in ids) (record-signer value.i.remaining))
  $(remaining t.remaining)
::
++  put-replica
  |=  rec=record
  ^-  [store-status content-state-0]
  ?.  (lte (met 3 (jam rec)) max-record-bytes.config.state)
    [[%rejected %too-large] state]
  ?.  (record-auth-valid rec)  [[%rejected %invalid] state]
  =/  expiry=(unit @da)  (record-expiry rec)
  ?.  ?~(expiry & (lth now u.expiry))  [[%rejected %expired] state]
  =.  state  prune
  =/  target=key  (record-key rec)
  =/  existing=leased-records  (~(gut by replicas.state) [target ~])
  =/  signer=node-id  (record-signer rec)
  =/  revision=@ud  (record-revision rec)
  =/  same=leased-records
    (skim existing |=(item=leased-record =(signer (record-signer value.item))))
  =/  greatest=@ud
    %+  roll  same
    |=  [item=leased-record best=@ud]
    (max (record-revision value.item) best)
  ?:  (lth revision greatest)  [[%rejected %stale] state]
  =/  at-revision=leased-records
    %+  skim  same
    |=  item=leased-record
    =(revision (record-revision value.item))
  =/  matches=leased-records
    %+  skim  at-revision
    |=  item=leased-record
    =(rec value.item)
  =/  duplicate=(unit leased-record)  ?~(matches ~ `i.matches)
  ?:  ?&  ?=(~ duplicate)
          =(revision greatest)
          (gte (lent at-revision) 2)
      ==
    [[%rejected %conflict-cap] state]
  ?:  ?&  ?=(%provider -.rec)
          ?=(~ same)
          (gte (signer-count existing) max-providers.config.state)
      ==
    [[%rejected %provider-cap] state]
  =/  others=leased-records
    %+  skip  existing
    |=  item=leased-record
    =(signer (record-signer value.item))
  =/  kept=leased-records  ?:(=(revision greatest) (weld at-revision others) others)
  =/  until=@da  (add lease.config.state now)
  =?  until  ?=(^ expiry)  (min until u.expiry)
  =.  kept
    ?:  ?=(^ duplicate)
      [[value.u.duplicate until] (skim kept |=(item=leased-record !=(rec value.item)))]
    [[rec until] kept]
  =?  state  ?&  ?=(~ (~(get by replicas.state) target))
                  (gte (lent ~(tap by replicas.state)) max-replica-keys.config.state)
              ==
    evict-one
  =.  replicas.state  (~(put by replicas.state) target kept)
  [[%accepted ~] state]
::
++  put-origin
  |=  rec=record
  ^-  content-state-0
  ?>  (record-valid rec)
  =/  target=key  (record-key rec)
  =/  old=(unit record)  (~(get by origins.state) target)
  ?~  old  state(origins (~(put by origins.state) target rec))
  ?>  (gth (record-revision rec) (record-revision u.old))
  state(origins (~(put by origins.state) target rec))
::
++  operation-key
  |=  op=operation
  ^-  key
  ?-  -.kind.op
    %publish         key.kind.op
    %find-pointer    key.kind.op
    %find-providers  key.kind.op
  ==
::
++  lookup-card
  |=  [id=operation-id target=key]
  ^-  card:agent:gall
  =/  command=command
    [%find-for target %content-routing /operation/(scot %uv id)]
  :*  %pass  /lookup/(scot %uv id)
      %agent  [our %kademlia]
      %poke  %kademlia-command  !>(command)
  ==
::
++  start-operation
  |=  [id=operation-id kind=operation-kind]
  ^-  [(list card:agent:gall) content-state-0]
  ?>  !(~(has by active.state) id)
  ?>  !(~(has by completed.state) id)
  =/  op=operation  [kind %.n ~ 0 ~ ~ ~ ~ ~ ~]
  =.  active.state  (~(put by active.state) id op)
  [[(lookup-card id (operation-key op)) ~] state]
::
++  next-operation-id
  ^-  [operation-id content-state-0]
  =/  id=operation-id  next-operation.state
  |-
  ?:  ?|  (~(has by active.state) id)
          (~(has by completed.state) id)
      ==
    $(id +(id))
  =.  next-operation.state  +(id)
  [id state]
::
++  publishing
  |=  target=key
  ^-  ?
  =/  entries=(list [operation-id operation])  ~(tap by active.state)
  |-
  ?~  entries  |
  =/  op=operation  +.i.entries
  ?:  ?&  ?=(%publish -.kind.op)
          =(target key.kind.op)
      ==
    &
  $(entries t.entries)
::
++  refresh-card
  ^-  card:agent:gall
  [%pass /refresh %arvo %b %wait refresh-at.state]
::
++  refresh-origins
  ^-  [(list card:agent:gall) content-state-0]
  =/  entries=(list [key record])  ~(tap by origins.state)
  =/  cards=(list card:agent:gall)  ~
  |-
  ?~  entries
    =.  refresh-at.state  (add refresh.config.state now)
    [(flop [refresh-card cards]) state]
  =/  target=key  -.i.entries
  =/  rec=record  +.i.entries
  ?:  (publishing target)
    $(entries t.entries)
  =^  id  state  next-operation-id
  =^  started  state  (start-operation id [%publish rec target])
  =.  background.state  (~(put in background.state) id)
  $(entries t.entries, cards (weld (flop started) cards))
::
++  start-publish
  |=  [id=operation-id rec=record]
  ^-  [(list card:agent:gall) content-state-0]
  =.  state  (put-origin rec)
  (start-operation id [%publish rec (record-key rec)])
::
++  start-find-pointer
  |=  [id=operation-id namespace=@tas publisher=node-id name=*]
  ^-  [(list card:agent:gall) content-state-0]
  =/  target=key  (pointer-key:cr namespace publisher name)
  (start-operation id [%find-pointer namespace publisher target])
::
++  start-find-providers
  |=  [id=operation-id content=digest]
  ^-  [(list card:agent:gall) content-state-0]
  (start-operation id [%find-providers content (provider-key:cr content)])
::
++  merge-records
  |=  [op=operation incoming=records]
  ^-  operation
  ?~  incoming  op
  =/  rec=record  i.incoming
  =/  op
    ?:  (record-valid rec)
      ?-  -.rec
        %pointer   op(pointers [value.rec pointers.op])
        %provider  op(providers [value.rec providers.op])
      ==
    op
  $(op op, incoming t.incoming)
::
++  finish
  |=  [id=operation-id op=operation]
  ^-  content-state-0
  =/  result=operation-result
    ?-  -.kind.op
      %publish
        [%published (operation-key op) accepted.op rejected.op timed-out.op]
      %find-pointer
        =/  selected=pointer-selection
          (select-pointer:cr now namespace.kind.op key.kind.op publisher.kind.op verify pointers.op)
        [%pointer selected responders.op timed-out.op]
      %find-providers
        =/  selected=provider-selection
          (select-providers:cr now content.kind.op verify providers.op)
        [%providers selected responders.op timed-out.op]
    ==
  =.  active.state  (~(del by active.state) id)
  ?:  (~(has in background.state) id)
    state(background (~(del in background.state) id))
  state(completed (~(put by completed.state) id result))
::
++  local-response
  |=  [peer=node-id op=operation]
  ^-  operation
  ?-  -.kind.op
    %publish
      op(accepted (~(put in accepted.op) peer))
    %find-pointer
      =/  vals=records  (values-for key.kind.op)
      (merge-records op(responders (~(put in responders.op) peer)) vals)
    %find-providers
      =/  vals=records  (values-for key.kind.op)
      (merge-records op(responders (~(put in responders.op) peer)) vals)
  ==
::
++  message-for
  |=  [request=content-request-id op=operation]
  ^-  content-message
  ?-  -.kind.op
    %publish
      [%store protocol request value.kind.op]
    %find-pointer
      [%find-records protocol request [%pointer key.kind.op]]
    %find-providers
      [%find-records protocol request [%providers content.kind.op]]
  ==
::
++  advance
  |=  [id=operation-id op=operation]
  ^-  [(list card:agent:gall) content-state-0]
  ?~  remaining.op
    ?:  =(0 in-flight.op)
      [~ (finish id op)]
    =.  active.state  (~(put by active.state) id op)
    [~ state]
  ?:  (gte in-flight.op concurrency.config.state)
    =.  active.state  (~(put by active.state) id op)
    [~ state]
  =/  queue=(list node-id)  remaining.op
  =/  pair=[node-id (list node-id)]  ?>(?=(^ queue) queue)
  =/  [peer=node-id rest=(list node-id)]  pair
  =/  next=operation  op(remaining rest)
  ?:  =(peer self-id)
    $(op (local-response peer next))
  =/  request=content-request-id  next-request.state
  =.  next-request.state  +(request)
  =/  deadline=@da  (add request-timeout.config.state now)
  =/  query=?  !=(%publish -.kind.next)
  =/  pen=pending-content-request  [id peer query deadline]
  =.  pending.state  (~(put by pending.state) request pen)
  =.  in-flight.next  +(in-flight.next)
  =/  message=content-message  (message-for request next)
  =/  ship=@p  (~(node-to-ship kad kad-cfg) peer)
  =/  poke=card:agent:gall
    :*  %pass  /request/(scot %uv request)
        %agent  [ship %content-routing]
        %poke  %content-routing-message  !>(message)
    ==
  =/  timer=card:agent:gall
    [%pass /timeout/(scot %uv request) %arvo %b %wait deadline]
  =.  active.state  (~(put by active.state) id next)
  =/  more=[(list card:agent:gall) content-state-0]  $(op next)
  [(weld [poke timer ~] -.more) +.more]
::
++  receive-lookup
  |=  [id=operation-id contacts=(list node-id)]
  ^-  [(list card:agent:gall) content-state-0]
  =/  found=(unit operation)  (~(get by active.state) id)
  ?~  found  [~ state]
  =/  op=operation  u.found
  ?.  =(%.n phase.op)  [~ state]
  =/  candidates=(list node-id)  [self-id contacts]
  =/  ordered=(list node-id)
    %+  sort  candidates
    |=  [a=node-id b=node-id]
    (lth (~(distance kad kad-cfg) (operation-key op) a) (~(distance kad kad-cfg) (operation-key op) b))
  =.  phase.op  %.y
  =.  remaining.op  (scag replication.config.state ordered)
  (advance id op)
::
++  receive-stored
  |=  [request=content-request-id status=store-status]
  ^-  [(list card:agent:gall) content-state-0]
  =/  found=(unit pending-content-request)  (~(get by pending.state) request)
  ?~  found  [~ state]
  =/  pen=pending-content-request  u.found
  ?.  =(peer.pen (~(ship-to-node kad kad-cfg) src))  [~ state]
  ?.  =(%.n kind.pen)  [~ state]
  =.  pending.state  (~(del by pending.state) request)
  =/  active=(unit operation)  (~(get by active.state) operation.pen)
  ?~  active  [~ state]
  =/  op=operation  u.active
  =.  in-flight.op  (dec in-flight.op)
  =.  op
    ?-  -.status
      %accepted  op(accepted (~(put in accepted.op) peer.pen))
      %rejected  op(rejected (~(put by rejected.op) peer.pen reason.status))
    ==
  =/  rest=card:agent:gall
    [%pass /timeout/(scot %uv request) %arvo %b %rest deadline.pen]
  =/  more=[(list card:agent:gall) content-state-0]  (advance operation.pen op)
  [[rest -.more] +.more]
::
++  receive-records
  |=  [request=content-request-id values=records]
  ^-  [(list card:agent:gall) content-state-0]
  =/  found=(unit pending-content-request)  (~(get by pending.state) request)
  ?~  found  [~ state]
  =/  pen=pending-content-request  u.found
  ?.  =(peer.pen (~(ship-to-node kad kad-cfg) src))  [~ state]
  ?.  =(%.y kind.pen)  [~ state]
  =.  pending.state  (~(del by pending.state) request)
  =/  active=(unit operation)  (~(get by active.state) operation.pen)
  ?~  active  [~ state]
  =/  op=operation  u.active
  =.  in-flight.op  (dec in-flight.op)
  =.  responders.op  (~(put in responders.op) peer.pen)
  =.  op  (merge-records op (scag max-providers.config.state values))
  =/  rest=card:agent:gall
    [%pass /timeout/(scot %uv request) %arvo %b %rest deadline.pen]
  =/  more=[(list card:agent:gall) content-state-0]  (advance operation.pen op)
  [[rest -.more] +.more]
::
++  fail-request
  |=  [request=content-request-id cancel=?]
  ^-  [(list card:agent:gall) content-state-0]
  =/  found=(unit pending-content-request)  (~(get by pending.state) request)
  ?~  found  [~ state]
  =/  pen=pending-content-request  u.found
  =.  pending.state  (~(del by pending.state) request)
  =/  active=(unit operation)  (~(get by active.state) operation.pen)
  ?~  active  [~ state]
  =/  op=operation  u.active
  =.  in-flight.op  (dec in-flight.op)
  =.  timed-out.op  (~(put in timed-out.op) peer.pen)
  =/  cancellation=(list card:agent:gall)
    ?:(cancel [[%pass /timeout/(scot %uv request) %arvo %b %rest deadline.pen] ~] ~)
  =/  more=[(list card:agent:gall) content-state-0]  (advance operation.pen op)
  [(weld cancellation -.more) +.more]
::
++  get-operation
  |=  id=operation-id
  ^-  (unit operation-view)
  =/  active=(unit operation)  (~(get by active.state) id)
  ?^  active  `[%running u.active]
  =/  done=(unit operation-result)  (~(get by completed.state) id)
  ?~  done  ~
  `[%complete u.done]
::
++  forget
  |=  id=operation-id
  ^-  content-state-0
  ?>  !(~(has by active.state) id)
  state(completed (~(del by completed.state) id))
--
