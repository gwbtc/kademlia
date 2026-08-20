::  Pure storage and request state transitions for %content-routing.
::
/-  *kademlia, *kademlia-agent, *content-routing, *content-routing-agent
/+  kad=kademlia, cr=content-routing
=/  kad-cfg=config  [20 20 3 12 %kademlia-urbit-v1]
=/  protocol=content-version  %content-routing-v1
=/  defaults=content-config  [20 3 12 ~m5 ~d1 ~h12 8 65.536 64 10.000]
=/  refresh-yield=@dr  ~s1
=/  max-wire-record-bytes=@ud  65.536
=/  max-wire-records=@ud  64
=/  max-wire-response-bytes=@ud  262.144
|_  $:  our=@p
        now=@da
        src=@p
        state=content-state
        verify=verifier
    ==
++  self-id
  ^-  node-id
  (~(ship-to-node kad kad-cfg) our)
::
::  valid-id: require operation and peer request IDs to fit in 64 bits.
::
++  valid-id
  |=  id=@
  ^-  ?
  (lte (met 0 id) 64)
::
::  valid-query: enforce the fixed-width key and digest domains before use.
::
++  valid-query
  |=  request=query
  ^-  ?
  ?-  -.request
    %pointer    (identity-valid:cr key.request)
    %providers  (digest-valid:cr content.request)
  ==
::
::  response-expected: admit only a pending response of the expected kind and
::  sender.  Call this before decoding any response payload.
::
++  response-expected
  |=  [request=content-request-id query=?]
  ^-  ?
  ?.  (valid-id request)  |
  =/  found=(unit pending-content-request)  (~(get by pending.state) request)
  ?~  found  |
  =/  pen=pending-content-request  u.found
  ?&  =(peer.pen (~(ship-to-node kad kad-cfg) src))
      =(query kind.pen)
  ==
::
::  bump-id: advance a counter modulo the 64-bit ID space.
::
++  bump-id
  |=  id=@
  ^-  @uv
  (end 6 +(id))
::
::  take-content-request-id: allocate an unused peer request ID.
::
++  take-content-request-id
  ^-  [content-request-id content-state]
  =/  id=content-request-id  (end 6 next-request.state)
  |-
  ?:  (~(has by pending.state) id)
    $(id (bump-id id))
  =.  next-request.state  (bump-id id)
  [id state]
::
::  pack-record: encode one record for bounded transport.
::
++  pack-record
  |=  rec=record
  ^-  @
  =/  payload=@  (jam rec)
  ?>  (lte (met 3 payload) max-wire-record-bytes)
  payload
::
::  unpack-record: decode one record only after enforcing its byte ceiling.
::
++  unpack-record
  |=  payload=@
  ^-  (unit record)
  ?.  (lte (met 3 payload) max-wire-record-bytes)  ~
  ?.  (lte (met 3 payload) max-record-bytes.config.state)  ~
  =/  decoded  (mule |.(;;(record (cue payload))))
  ?:  ?=(%| -.decoded)  ~
  `p.decoded
::
::  pack-records: retain the longest prefix fitting both response ceilings.
::
++  pack-records
  |=  values=records
  ^-  [count=@ud payload=@]
  =/  limited=records  (scag max-wire-records values)
  =/  total=@ud  (lent limited)
  =/  empty-payload=@  (jam `records`~)
  ?~  limited  [0 empty-payload]
  =/  full-payload=@  (jam limited)
  ?:  (lte (met 3 full-payload) max-wire-response-bytes)
    [total full-payload]
  =/  low=@ud  0
  =/  high=@ud  total
  =/  low-payload=@  empty-payload
  |-
  ?:  =(+(low) high)  [low low-payload]
  =/  middle=@ud  (div (add low high) 2)
  =/  candidate=records  (scag middle values)
  =/  candidate-payload=@  (jam candidate)
  ?:  (lte (met 3 candidate-payload) max-wire-response-bytes)
    $(low middle, low-payload candidate-payload)
  $(high middle)
::
::  unpack-records: bound the atom before cueing and require the declared count.
::
++  unpack-records
  |=  [count=@ud payload=@]
  ^-  (unit records)
  ?:  (gth count max-wire-records)  ~
  ?.  (lte (met 3 payload) max-wire-response-bytes)  ~
  =/  decoded  (mule |.(;;(records (cue payload))))
  ?:  ?=(%| -.decoded)  ~
  ?.  =(count (lent p.decoded))  ~
  =/  remaining=records  p.decoded
  |-
  ?~  remaining  `p.decoded
  =/  size=@ud  (met 3 (jam i.remaining))
  ?.  ?&  (lte size max-wire-record-bytes)
          (lte size max-record-bytes.config.state)
      ==
    ~
  $(remaining t.remaining)
::
++  init
  ^-  content-state
  [defaults ~ 0 ~ ~ ~ ~ 0v1 (add refresh.defaults now) 0v1 ~ ~ ~ ~ ~]
::
++  config-valid
  |=  cfg=content-config
  ^-  ?
  ?&  (gth replication.cfg 0)
      (gth concurrency.cfg 0)
      (lte concurrency.cfg replication.cfg)
      (gth global-concurrency.cfg 0)
      (gth request-timeout.cfg 0)
      (gth lease.cfg 0)
      (gth refresh.cfg 0)
      (lth refresh.cfg lease.cfg)
      (gth refresh-batch.cfg 0)
      (gth max-record-bytes.cfg 0)
      (lte max-record-bytes.cfg max-wire-record-bytes)
      (gth max-providers.cfg 0)
      (lte max-providers.cfg max-wire-records)
      (gth max-replica-keys.cfg 0)
  ==
::
++  set-config
  |=  cfg=content-config
  ^-  content-state
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
::  record-valid-for: authenticate a bounded record for one lookup context.
::
::    Operation records pass this gate once, before entering the admitted
::    pointer or provider lists.  Completion may therefore select those
::    lists without repeating signature and invariant verification.
::
++  record-valid-for
  |=  [op=operation rec=record]
  ^-  ?
  ?.  (lte (met 3 (jam rec)) max-record-bytes.config.state)  |
  ?-  -.kind.op
    %publish
      |
    %find-pointer
      ?.  ?=(%pointer -.rec)  |
      (pointer-valid:cr now namespace.kind.op key.kind.op publisher.kind.op verify value.rec)
    %find-providers
      ?.  ?=(%provider -.rec)  |
      (provider-valid:cr now content.kind.op verify value.rec)
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
::  prune-all: remove expired leases across the complete replica store.
::
::    This is intentionally reserved for reclaiming capacity.  Ordinary reads
::    and writes use +prune-key so their cost depends only on one key.
::
++  prune-all
  ^-  content-state
  =/  entries=(list [key leased-records])  ~(tap by replicas.state)
  =/  fresh=(map key leased-records)  ~
  =/  count=@ud  0
  |-
  ?~  entries  state(replicas fresh, replica-count count)
  =/  values=leased-records  (prune-list +.i.entries)
  ?~  values  $(entries t.entries)
  %=  $
    entries  t.entries
    fresh    (~(put by fresh) -.i.entries values)
    count    +(count)
  ==
::
++  prune-key
  |=  target=key
  ^-  content-state
  =/  present=?  (~(has by replicas.state) target)
  =/  values=leased-records
    (prune-list (~(gut by replicas.state) [target ~]))
  ?~  values
    ?.  present  state
    %=  state
      replicas       (~(del by replicas.state) target)
      replica-count  (dec replica-count.state)
    ==
  state(replicas (~(put by replicas.state) target values))
::
++  lease-horizon
  |=  values=leased-records
  ^-  @da
  ?~  values  *@da
  =/  rest=@da  $(values t.values)
  (max lease-until.i.values rest)
::
++  evict-one
  ^-  content-state
  =/  entries=(list [key leased-records])  ~(tap by replicas.state)
  ?~  entries  state
  =/  victim=key  -.i.entries
  =/  horizon=@da  (lease-horizon +.i.entries)
  =/  remaining=(list [key leased-records])  t.entries
  |-
  ?~  remaining
    %=  state
      replicas       (~(del by replicas.state) victim)
      replica-count  (dec replica-count.state)
    ==
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
  =/  values=leased-records
    (prune-list (~(gut by replicas.state) [target ~]))
  =/  out=records  (turn values |=(item=leased-record value.item))
  =/  origin=(unit record)  (~(get by origins.state) target)
  ?~  origin  out
  [u.origin out]
::
++  put-replica
  |=  rec=record
  ^-  [store-status content-state]
  ?.  (lte (met 3 (jam rec)) max-record-bytes.config.state)
    [[%rejected %too-large] state]
  ?.  (record-auth-valid rec)  [[%rejected %invalid] state]
  =/  expiry=(unit @da)  (record-expiry rec)
  ?.  ?~(expiry & (lth now u.expiry))  [[%rejected %expired] state]
  =/  target=key  (record-key rec)
  =.  state  (prune-key target)
  =/  existing=leased-records  (~(gut by replicas.state) [target ~])
  =/  signer=node-id  (record-signer rec)
  =/  revision=@ud  (record-revision rec)
  =/  provider=?  ?=(%provider -.rec)
  =/  classify
    |=  values=leased-records
    ^-  $:  higher=?
            found-signer=?
            equal-count=@ud
            duplicate=(unit leased-record)
            at-revision=leased-records
            others=leased-records
            signers=(set node-id)
        ==
    ?~  values  [| | 0 ~ ~ ~ ~]
    =/  out
      ^-  $:  higher=?
              found-signer=?
              equal-count=@ud
              duplicate=(unit leased-record)
              at-revision=leased-records
              others=leased-records
              signers=(set node-id)
          ==
      $(values t.values)
    =/  item=leased-record  i.values
    =/  item-signer=node-id  (record-signer value.item)
    =/  all-signers=(set node-id)
      ?:(provider (~(put in signers.out) item-signer) signers.out)
    ?:  !=(signer item-signer)
      out(others [item others.out], signers all-signers)
    =.  found-signer.out  &
    =/  item-revision=@ud  (record-revision value.item)
    ?:  (gth item-revision revision)
      out(higher &, signers all-signers)
    ?:  (lth item-revision revision)
      out(signers all-signers)
    =.  equal-count.out  +(equal-count.out)
    ?:  =(rec value.item)
      out(duplicate `item, signers all-signers)
    out(at-revision [item at-revision.out], signers all-signers)
  =/  classified  (classify existing)
  ?:  higher.classified  [[%rejected %stale] state]
  ?:  ?&  ?=(~ duplicate.classified)
          (gte equal-count.classified 2)
      ==
    [[%rejected %conflict-cap] state]
  ?:  ?&  provider
          =(%.n found-signer.classified)
          (gte ~(wyt in signers.classified) max-providers.config.state)
      ==
    [[%rejected %provider-cap] state]
  =/  kept=leased-records
    (weld at-revision.classified others.classified)
  =/  until=@da  (add lease.config.state now)
  =?  until  ?=(^ expiry)  (min until u.expiry)
  =.  kept
    ?:  ?=(^ duplicate.classified)
      [[value.u.duplicate.classified until] kept]
    [[rec until] kept]
  =/  adding-key=?  ?=(~ (~(get by replicas.state) target))
  =?  state  ?&  adding-key
                  (gte replica-count.state max-replica-keys.config.state)
              ==
    prune-all
  =?  state  ?&  adding-key
                  (gte replica-count.state max-replica-keys.config.state)
              ==
    evict-one
  =.  replicas.state  (~(put by replicas.state) target kept)
  =?  replica-count.state  adding-key  +(replica-count.state)
  [[%accepted ~] state]
::
++  put-origin
  |=  rec=record
  ^-  content-state
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
  ^-  [(list card:agent:gall) content-state]
  ?>  (valid-id id)
  ?>  !(~(has by active.state) id)
  ?>  !(~(has by completed.state) id)
  =/  op=operation  [kind %.n ~ 0 ~ ~ ~ ~ ~ ~]
  =.  active.state  (~(put by active.state) id op)
  [[(lookup-card id (operation-key op)) ~] state]
::
++  next-operation-id
  ^-  [operation-id content-state]
  =/  id=operation-id  (end 6 next-operation.state)
  |-
  ?:  ?|  (~(has by active.state) id)
          (~(has by completed.state) id)
          (~(has by callbacks.state) id)
          (~(has in background.state) id)
      ==
    $(id (bump-id id))
  =.  next-operation.state  (bump-id id)
  [id state]
::
++  publishing-keys
  ^-  (set key)
  =/  entries=(list [operation-id operation])  ~(tap by active.state)
  =/  targets=(set key)  ~
  |-
  ?~  entries  targets
  =/  op=operation  +.i.entries
  ?.  ?=(%publish -.kind.op)
    $(entries t.entries)
  $(entries t.entries, targets (~(put in targets) key.kind.op))
::
++  refresh-card
  ^-  card:agent:gall
  [%pass /refresh %arvo %b %wait refresh-at.state]
::
++  refresh-origins
  ^-  [(list card:agent:gall) content-state]
  =/  publishing=(set key)  publishing-keys
  =/  queue=(list key)  refresh-queue.state
  =?  queue  ?=(~ queue)
    %+  turn  ~(tap by origins.state)
    |=  entry=[key record]
    -.entry
  =/  cards=(list card:agent:gall)  ~
  =/  left=@ud  refresh-batch.config.state
  |-
  ?:  |(?=(~ queue) =(0 left))
    =.  refresh-queue.state  queue
    =/  delay=@dr  ?:(?=(~ queue) refresh.config.state refresh-yield)
    =.  refresh-at.state  (add delay now)
    [(flop [refresh-card cards]) state]
  =/  target=key  i.queue
  =/  remaining=(list key)  t.queue
  ?:  (~(has in publishing) target)
    $(queue remaining, left (dec left))
  =/  found=(unit record)  (~(get by origins.state) target)
  ?~  found
    $(queue remaining, left (dec left))
  =/  rec=record  u.found
  =^  id  state  next-operation-id
  =^  started  state  (start-operation id [%publish rec target (pack-record rec)])
  =.  background.state  (~(put in background.state) id)
  %=  $
    queue  remaining
    left   (dec left)
    cards  (weld (flop started) cards)
  ==
::
++  start-publish
  |=  [id=operation-id rec=record]
  ^-  [(list card:agent:gall) content-state]
  =.  state  (put-origin rec)
  (start-operation id [%publish rec (record-key rec) (pack-record rec)])
::
++  start-find-pointer
  |=  [id=operation-id namespace=@tas publisher=node-id name=*]
  ^-  [(list card:agent:gall) content-state]
  ?>  (identity-valid:cr publisher)
  =/  target=key  (pointer-key:cr namespace publisher name)
  (start-operation id [%find-pointer namespace publisher target])
::
++  start-find-providers
  |=  [id=operation-id content=digest]
  ^-  [(list card:agent:gall) content-state]
  ?>  (digest-valid:cr content)
  (start-operation id [%find-providers content (provider-key:cr content)])
::
++  merge-records
  |=  [op=operation incoming=records]
  ^-  operation
  ?~  incoming  op
  =/  rec=record  i.incoming
  =/  op
    ?:  (record-valid-for op rec)
      ?-  -.rec
        %pointer   op(pointers [value.rec pointers.op])
        %provider  op(providers [value.rec providers.op])
      ==
    op
  $(op op, incoming t.incoming)
::
++  finish
  |=  [id=operation-id op=operation]
  ^-  [operation-completion content-state]
  =/  result=operation-result
    ?-  -.kind.op
      %publish
        [%published (operation-key op) accepted.op rejected.op timed-out.op]
      %find-pointer
        =/  selected=pointer-selection
          (select-admitted-pointer:cr now pointers.op)
        [%pointer selected responders.op timed-out.op]
      %find-providers
        =/  selected=provider-selection
          (select-admitted-providers:cr now providers.op)
        [%providers selected responders.op timed-out.op]
    ==
  =.  active.state  (~(del by active.state) id)
  ?:  (~(has in background.state) id)
    [[id result] state(background (~(del in background.state) id))]
  [[id result] state(completed (~(put by completed.state) id result))]
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
      [%store protocol request payload.kind.op]
    %find-pointer
      [%find-records protocol request [%pointer key.kind.op]]
    %find-providers
      [%find-records protocol request [%providers content.kind.op]]
  ==
::
++  operation-ready
  |=  op=operation
  ^-  ?
  ?.  phase.op  |
  ?~  remaining.op
    =(0 in-flight.op)
  (lth in-flight.op concurrency.config.state)
::
::  enqueue: schedule one request-phase operation exactly once.
::
++  enqueue
  |=  id=operation-id
  ^-  content-state
  ?:  (~(has in queued.state) id)  state
  =/  found=(unit operation)  (~(get by active.state) id)
  ?~  found  state
  ?.  (operation-ready u.found)  state
  =.  ready.state  (~(put to ready.state) id)
  =.  queued.state  (~(put in queued.state) id)
  state
::
::  pop-ready: take the oldest scheduled operation and clear membership.
::
++  pop-ready
  ^-  [id=(unit operation-id) out=content-state]
  ?~  ready.state  [~ state]
  =/  item=[operation-id (qeu operation-id)]  ~(get to ready.state)
  =/  out=content-state
    state(ready +.item, queued (~(del in queued.state) -.item))
  [`-.item out]
::
::  advance-one: perform local work and dispatch at most one remote request.
::
++  advance-one
  |=  [id=operation-id op=operation]
  ^-  $:  cards=(list card:agent:gall)
          completion=(unit operation-completion)
          out=content-state
      ==
  ?~  remaining.op
    ?:  =(0 in-flight.op)
      =/  finished=[operation-completion content-state]  (finish id op)
      [~ `-.finished +.finished]
    =.  active.state  (~(put by active.state) id op)
    [~ ~ state]
  ?:  (gte in-flight.op concurrency.config.state)
    =.  active.state  (~(put by active.state) id op)
    [~ ~ state]
  =/  queue=(list node-id)  remaining.op
  =/  pair=[node-id (list node-id)]  ?>(?=(^ queue) queue)
  =/  [peer=node-id rest=(list node-id)]  pair
  =/  next=operation  op(remaining rest)
  ?:  =(peer self-id)
    $(op (local-response peer next))
  =^  request  state  take-content-request-id
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
  [[poke timer ~] ~ state]
::
::  pump: fairly fill the process-wide request budget from the ready queue.
::
::    Each queue turn dispatches at most one remote request for one operation,
::    then requeues that operation behind its peers if it can send more.
::
++  pump
  ^-  [(list card:agent:gall) operation-update]
  =/  cards=(list card:agent:gall)  ~
  =/  completions=(list operation-completion)  ~
  |-
  =/  stopped=?
    ?|  ?=(~ ready.state)
        (gte ~(wyt by pending.state) global-concurrency.config.state)
    ==
  ?:  stopped
    [(flop cards) (flop completions) state]
  =/  popped=[id=(unit operation-id) out=content-state]  pop-ready
  =.  state  out.popped
  ?~  id.popped  [(flop cards) (flop completions) state]
  =/  id=operation-id  u.id.popped
  =/  found=(unit operation)  (~(get by active.state) id)
  ?~  found  $(cards cards, completions completions)
  =/  advanced=[cards=(list card:agent:gall) completion=(unit operation-completion) out=content-state]
    (advance-one id u.found)
  =.  state  out.advanced
  =?  completions  ?=(^ completion.advanced)
    [u.completion.advanced completions]
  =.  state  (enqueue id)
  %=  $
    cards        (weld (flop cards.advanced) cards)
    completions  completions
  ==
::
++  receive-lookup
  |=  [id=operation-id contacts=(list node-id)]
  ^-  [(list card:agent:gall) operation-update]
  ?.  (valid-id id)  [~ ~ state]
  =/  found=(unit operation)  (~(get by active.state) id)
  ?~  found  [~ ~ state]
  =/  op=operation  u.found
  ?.  =(%.n phase.op)  [~ ~ state]
  =/  candidates=(list node-id)  [self-id contacts]
  =/  ordered=(list node-id)
    %+  sort  candidates
    |=  [a=node-id b=node-id]
    (lth (~(distance kad kad-cfg) (operation-key op) a) (~(distance kad kad-cfg) (operation-key op) b))
  =.  phase.op  %.y
  =.  remaining.op  (scag replication.config.state ordered)
  =.  active.state  (~(put by active.state) id op)
  =.  state  (enqueue id)
  pump
::
++  receive-stored
  |=  [request=content-request-id status=store-status]
  ^-  [(list card:agent:gall) operation-update]
  ?.  (response-expected request %.n)  [~ ~ state]
  =/  found=(unit pending-content-request)  (~(get by pending.state) request)
  =/  pen=pending-content-request  (need found)
  =.  pending.state  (~(del by pending.state) request)
  =/  active=(unit operation)  (~(get by active.state) operation.pen)
  ?~  active  [~ ~ state]
  =/  op=operation  u.active
  =.  in-flight.op  (dec in-flight.op)
  =.  op
    ?-  -.status
      %accepted  op(accepted (~(put in accepted.op) peer.pen))
      %rejected  op(rejected (~(put by rejected.op) peer.pen reason.status))
    ==
  =.  active.state  (~(put by active.state) operation.pen op)
  =.  state  (enqueue operation.pen)
  =/  rest=card:agent:gall
    [%pass /timeout/(scot %uv request) %arvo %b %rest deadline.pen]
  =/  more=[(list card:agent:gall) operation-update]  pump
  [[rest -.more] +.more]
::
++  receive-records
  |=  [request=content-request-id values=records]
  ^-  [(list card:agent:gall) operation-update]
  ?.  (response-expected request %.y)  [~ ~ state]
  =/  found=(unit pending-content-request)  (~(get by pending.state) request)
  =/  pen=pending-content-request  (need found)
  =.  pending.state  (~(del by pending.state) request)
  =/  active=(unit operation)  (~(get by active.state) operation.pen)
  ?~  active  [~ ~ state]
  =/  op=operation  u.active
  =.  in-flight.op  (dec in-flight.op)
  =.  responders.op  (~(put in responders.op) peer.pen)
  =.  op  (merge-records op (scag max-providers.config.state values))
  =.  active.state  (~(put by active.state) operation.pen op)
  =.  state  (enqueue operation.pen)
  =/  rest=card:agent:gall
    [%pass /timeout/(scot %uv request) %arvo %b %rest deadline.pen]
  =/  more=[(list card:agent:gall) operation-update]  pump
  [[rest -.more] +.more]
::
++  fail-request
  |=  [request=content-request-id cancel=?]
  ^-  [(list card:agent:gall) operation-update]
  ?.  (valid-id request)  [~ ~ state]
  =/  found=(unit pending-content-request)  (~(get by pending.state) request)
  ?~  found  [~ ~ state]
  =/  pen=pending-content-request  u.found
  =.  pending.state  (~(del by pending.state) request)
  =/  active=(unit operation)  (~(get by active.state) operation.pen)
  ?~  active  [~ ~ state]
  =/  op=operation  u.active
  =.  in-flight.op  (dec in-flight.op)
  =.  timed-out.op  (~(put in timed-out.op) peer.pen)
  =.  active.state  (~(put by active.state) operation.pen op)
  =.  state  (enqueue operation.pen)
  =/  cancellation=(list card:agent:gall)
    ?:(cancel [[%pass /timeout/(scot %uv request) %arvo %b %rest deadline.pen] ~] ~)
  =/  more=[(list card:agent:gall) operation-update]  pump
  [(weld cancellation -.more) +.more]
::
++  get-operation
  |=  id=operation-id
  ^-  (unit operation-view)
  ?.  (valid-id id)  ~
  =/  active=(unit operation)  (~(get by active.state) id)
  ?^  active  `[%running u.active]
  =/  done=(unit operation-result)  (~(get by completed.state) id)
  ?~  done  ~
  `[%complete u.done]
::
++  forget
  |=  id=operation-id
  ^-  content-state
  ?>  (valid-id id)
  ?>  !(~(has by active.state) id)
  state(completed (~(del by completed.state) id))
--
