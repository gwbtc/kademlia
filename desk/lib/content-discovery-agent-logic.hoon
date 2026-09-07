::  Pure storage and request state transitions for %content-discovery.
::
/-  *kademlia, *kademlia-agent, *content-discovery, *content-discovery-agent, *bounded-poke
/+  kad=kademlia, cd=content-discovery, delivery=bounded-poke
=/  kad-cfg=config  [20 20 3 12 %kademlia-urbit-v1]
=/  protocol=discovery-version  %content-discovery-v1
=/  defaults=discovery-config  [20 3 12 ~m5 ~d1 ~h12 8 65.536 64 8 10.000]
=/  refresh-yield=@dr  ~s1
=/  max-wire-record-bytes=@ud  65.536
=/  max-wire-records=@ud  64
=/  max-wire-response-bytes=@ud  262.144
|_  $:  our=@p
        now=@da
        src=@p
        state=discovery-state
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
::  valid-query: reject empty, deep, or oversized topic paths before hashing.
::
++  valid-query
  |=  topic=topic-path
  ^-  ?
  (topic-valid:cd topic)
::
::  response-expected: admit only a pending response of the expected kind and
::  sender.  Call this before decoding any response payload.
::
++  response-expected
  |=  [request=discovery-request-id query=?]
  ^-  ?
  ?.  (valid-id request)  |
  =/  found=(unit pending-discovery-request)  (~(get by pending.state) request)
  ?~  found  |
  =/  pen=pending-discovery-request  u.found
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
::  take-discovery-request-id: allocate an unused peer request ID.
::
++  take-discovery-request-id
  ^-  [discovery-request-id discovery-state]
  =/  id=discovery-request-id  (end 6 next-request.state)
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
  ^-  (unit sized-record)
  =/  size=@ud  (met 3 payload)
  ?.  (lte size max-wire-record-bytes)  ~
  ?.  (lte size max-record-bytes.config.state)  ~
  =/  decoded  (mule |.(;;(record (cue payload))))
  ?:  ?=(%| -.decoded)  ~
  `[p.decoded size]
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
  ^-  (unit sized-records)
  ?:  (gth count max-wire-records)  ~
  ?.  (lte (met 3 payload) max-wire-response-bytes)  ~
  =/  decoded  (mule |.(;;(records (cue payload))))
  ?:  ?=(%| -.decoded)  ~
  ?.  =(count (lent p.decoded))  ~
  =/  remaining=records  p.decoded
  =/  out=sized-records  ~
  |-
  ?~  remaining  `(flop out)
  =/  size=@ud  (met 3 (jam i.remaining))
  ?.  ?&  (lte size max-wire-record-bytes)
          (lte size max-record-bytes.config.state)
      ==
    ~
  $(remaining t.remaining, out [[i.remaining size] out])
::
++  init
  ^-  discovery-state
  [defaults ~ 0 ~ ~ ~ ~ 0 0v1 (add refresh.defaults now) 0v1 ~ ~ ~ ~ ~ ~ ~ ~ ~(init delivery [now *delivery-state])]
::
++  reset-state
  ^-  [(list card:agent:gall) discovery-state]
  =/  kept=[(list card:agent:gall) delivery-state]
    ~(reset delivery [now outbound.state])
  =/  fresh=discovery-state  init
  =.  outbound.fresh  +.kept
  [-.kept fresh]
::
++  config-valid
  |=  cfg=discovery-config
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
      (gth max-records-per-key.cfg 0)
      (lte max-records-per-key.cfg max-wire-records)
      (gth max-records-per-publisher.cfg 0)
      (lte max-records-per-publisher.cfg max-records-per-key.cfg)
      (gth max-replica-keys.cfg 0)
  ==
::
++  set-config
  |=  cfg=discovery-config
  ^-  discovery-state
  ?>  (config-valid cfg)
  state(config cfg)
::
++  record-key
  |=  rec=record
  ^-  key
  (record-key:cd rec)
::
++  record-signer
  |=  rec=record
  ^-  node-id
  (record-publisher:cd rec)
::
++  record-revision
  |=  rec=record
  ^-  @ud
  (record-revision:cd rec)
::
++  record-expiry
  |=  rec=record
  ^-  (unit @da)
  `(record-expiry:cd rec)
::
++  record-auth-valid
  |=  rec=record
  ^-  ?
  =/  topic=topic-path
    ?-  -.rec
      %catalog  topic.body.value.rec
      %edge     parent.body.value.rec
    ==
  (record-valid:cd now topic verify rec)
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
  (record-valid-for-sized op [rec (met 3 (jam rec))])
::
::  record-valid-for-sized: authenticate a record whose encoded size was
::  retained by the transport decoder, without serializing it again.
::
++  record-valid-for-sized
  |=  [op=operation incoming=sized-record]
  ^-  ?
  ?.  (lte bytes.incoming max-record-bytes.config.state)  |
  =/  rec=record  value.incoming
  ?-  -.kind.op
    %publish
      |
    %browse
      (record-valid:cd now topic.kind.op verify rec)
  ==
::
++  prune-list
  |=  values=leased-records
  ^-  [changed=? values=leased-records]
  =/  changed=(unit leased-records)
    |-
    ?~  values  ~
    =/  rest=(unit leased-records)  $(values t.values)
    ?:  (lth now lease-until.i.values)
      ?~  rest  ~
      `[i.values u.rest]
    ?~  rest  `t.values
    `u.rest
  ?~  changed  [| values]
  [& u.changed]
::
::  prune-all: remove expired leases across the complete replica store.
::
::    This is intentionally reserved for reclaiming capacity.  Ordinary reads
::    and writes use +prune-key so their cost depends only on one key.
::
++  prune-all
  ^-  discovery-state
  =/  rebuild
    |=  $:  entries=(map key leased-records)
            fresh=(map key leased-records)
            count=@ud
        ==
    ^-  [fresh=(map key leased-records) count=@ud]
    ?~  entries  [fresh count]
    =/  left=[fresh=(map key leased-records) count=@ud]
      $(entries l.entries, fresh fresh, count count)
    =/  pruned=[changed=? values=leased-records]
      (prune-list q.n.entries)
    =/  next=[fresh=(map key leased-records) count=@ud]
      ?~  values.pruned  left
      [(~(put by fresh.left) p.n.entries values.pruned) +(count.left)]
    $(entries r.entries, fresh fresh.next, count count.next)
  =/  rebuilt=[fresh=(map key leased-records) count=@ud]
    (rebuild replicas.state ~ 0)
  state(replicas fresh.rebuilt, replica-count count.rebuilt)
::
++  prune-key
  |=  target=key
  ^-  discovery-state
  =/  present=?  (~(has by replicas.state) target)
  =/  pruned=[changed=? values=leased-records]
    (prune-list (~(gut by replicas.state) [target ~]))
  ?.  changed.pruned  state
  =/  values=leased-records  values.pruned
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
  ^-  discovery-state
  =/  choose
    |=  $:  entries=(map key leased-records)
            best=(unit [victim=key horizon=@da])
        ==
    ^-  (unit [victim=key horizon=@da])
    ?~  entries  best
    =/  best=(unit [victim=key horizon=@da])
      $(entries l.entries, best best)
    =/  candidate=key  p.n.entries
    =/  candidate-horizon=@da  (lease-horizon q.n.entries)
    =/  replace=?
      ?~  best  &
      ?|  (lth candidate-horizon horizon.u.best)
          ?&  =(candidate-horizon horizon.u.best)
              (lth candidate victim.u.best)
          ==
      ==
    =?  best  replace  `[candidate candidate-horizon]
    $(entries r.entries, best best)
  =/  selected=(unit [victim=key horizon=@da])
    (choose replicas.state ~)
  ?~  selected  state
  %=  state
    replicas       (~(del by replicas.state) victim.u.selected)
    replica-count  (dec replica-count.state)
  ==
::
++  values-for
  |=  target=key
  ^-  records
  =/  pruned=[changed=? values=leased-records]
    (prune-list (~(gut by replicas.state) [target ~]))
  =/  values=leased-records  values.pruned
  =/  out=records  (turn values |=(item=leased-record value.item))
  =/  collect
    |=  [entries=(map [key record-identity] record) values=records]
    ^-  records
    ?~  entries  values
    =/  values=records  $(entries l.entries, values values)
    =?  values  =(target -.p.n.entries)  [q.n.entries values]
    $(entries r.entries, values values)
  (collect origins.state out)
::
++  put-replica
  |=  rec=record
  ^-  [store-status discovery-state]
  (put-replica-sized [rec (met 3 (jam rec))])
::
::  put-replica-sized: admit a transport-decoded replica without re-jamming
::  it solely to recover its already-validated encoded size.
::
++  put-replica-sized
  |=  incoming=sized-record
  ^-  [store-status discovery-state]
  ?.  (lte bytes.incoming max-record-bytes.config.state)
    [[%rejected %too-large] state]
  =/  rec=record  value.incoming
  ?.  (record-auth-valid rec)  [[%rejected %invalid] state]
  =/  expiry=@da  (record-expiry:cd rec)
  ?.  (lth now expiry)  [[%rejected %expired] state]
  =/  target=key  (record-key rec)
  =.  state  (prune-key target)
  =/  existing=leased-records  (~(gut by replicas.state) [target ~])
  =/  signer=node-id  (record-signer rec)
  =/  identity=record-identity  (identity-of:cd rec)
  =/  revision=@ud  (record-revision rec)
  =/  classify
    |=  values=leased-records
    ^-  $:  higher=?
            found-identity=?
            publisher-count=@ud
            equal-count=@ud
            duplicate=(unit leased-record)
            at-revision=leased-records
            others=leased-records
        ==
    ?~  values  [| | 0 0 ~ ~ ~]
    =/  out
      ^-  $:  higher=?
              found-identity=?
              publisher-count=@ud
              equal-count=@ud
              duplicate=(unit leased-record)
              at-revision=leased-records
              others=leased-records
          ==
      $(values t.values)
    =/  item=leased-record  i.values
    =/  item-signer=node-id  (record-signer value.item)
    =?  publisher-count.out  =(signer item-signer)
      +(publisher-count.out)
    ?.  =(identity (identity-of:cd value.item))
      out(others [item others.out])
    =.  found-identity.out  &
    =/  item-revision=@ud  (record-revision value.item)
    ?:  (gth item-revision revision)
      out(higher &)
    ?:  (lth item-revision revision)
      out
    =.  equal-count.out  +(equal-count.out)
    ?:  =(rec value.item)
      out(duplicate `item)
    out(at-revision [item at-revision.out])
  =/  classified  (classify existing)
  ?:  higher.classified  [[%rejected %stale] state]
  ?:  ?&  ?=(~ duplicate.classified)
          (gte equal-count.classified 2)
      ==
    [[%rejected %conflict] state]
  ?:  ?&  =(%.n found-identity.classified)
          (gte publisher-count.classified max-records-per-publisher.config.state)
      ==
    [[%rejected %publisher-cap] state]
  ?:  ?&  =(%.n found-identity.classified)
          (gte (lent existing) max-records-per-key.config.state)
      ==
    [[%rejected %capacity] state]
  =/  kept=leased-records
    (weld at-revision.classified others.classified)
  =/  until=@da  (add lease.config.state now)
  =.  until  (min until expiry)
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
  ^-  discovery-state
  =/  payload=@  (jam rec)
  (put-origin-sized [rec (met 3 payload)])
::
::  put-origin-sized: admit a local record whose encoded size is already known.
::
++  put-origin-sized
  |=  incoming=sized-record
  ^-  discovery-state
  ?>  (lte bytes.incoming max-wire-record-bytes)
  ?>  (lte bytes.incoming max-record-bytes.config.state)
  =/  rec=record  value.incoming
  ?>  (record-auth-valid rec)
  =/  target=key  (record-key rec)
  =/  identity=record-identity  (identity-of:cd rec)
  =/  origin-key=[key record-identity]  [target identity]
  =/  old=(unit record)  (~(get by origins.state) origin-key)
  ?~  old
    =/  count
      |=  [entries=(map [key record-identity] record) total=@ud publisher=@ud]
      ^-  [total=@ud publisher=@ud]
      ?~  entries  [total publisher]
      =/  left=[total=@ud publisher=@ud]
        $(entries l.entries, total total, publisher publisher)
      =/  same-key=?  =(target -.p.n.entries)
      =/  total=@ud  ?:(same-key +(total.left) total.left)
      =/  publisher=@ud
        ?:  ?&  same-key
                =((record-signer rec) (record-signer q.n.entries))
            ==
          +(publisher.left)
        publisher.left
      $(entries r.entries, total total, publisher publisher)
    =/  counts=[total=@ud publisher=@ud]  (count origins.state 0 0)
    ?>  (lth total.counts max-records-per-key.config.state)
    ?>  (lth publisher.counts max-records-per-publisher.config.state)
    state(origins (~(put by origins.state) origin-key rec))
  ?>  (gth (record-revision rec) (record-revision u.old))
  state(origins (~(put by origins.state) origin-key rec))
::
++  operation-key
  |=  op=operation
  ^-  key
  ?-  -.kind.op
    %publish         key.kind.op
    %browse          key.kind.op
  ==
::
++  lookup-card
  |=  [id=operation-id target=key]
  ^-  card:agent:gall
  =/  command=command
    [%find-for target %content-discovery /operation/(scot %uv id)]
  :*  %pass  /lookup/(scot %uv id)
      %agent  [our %kademlia]
      %poke  %kademlia-command  !>(command)
  ==
::
++  start-operation
  |=  [id=operation-id kind=operation-kind]
  ^-  [(list card:agent:gall) discovery-state]
  ?>  (valid-id id)
  ?>  !(~(has by active.state) id)
  ?>  !(~(has by completed.state) id)
  =/  op=operation  [kind %.n ~ 0 ~ ~ ~ ~ ~ ~]
  =.  active.state  (~(put by active.state) id op)
  [[(lookup-card id (operation-key op)) ~] state]
::
++  next-operation-id
  ^-  [operation-id discovery-state]
  =/  id=operation-id  (end 6 next-operation.state)
  |-
  ?:  ?|  (~(has by active.state) id)
          (~(has by completed.state) id)
          (~(has by callbacks.state) id)
          (~(has by batches.state) id)
          (~(has by completed-public.state) id)
          (~(has in background.state) id)
      ==
    $(id (bump-id id))
  =.  next-operation.state  (bump-id id)
  [id state]
::
++  publishing-records
  ^-  (set [key record-identity])
  =/  collect
    |=  [entries=(map operation-id operation) targets=(set [key record-identity])]
    ^-  (set [key record-identity])
    ?~  entries  targets
    =/  targets=(set [key record-identity])
      $(entries l.entries, targets targets)
    =/  op=operation  q.n.entries
    =?  targets  ?=(%publish -.kind.op)
      (~(put in targets) [key.kind.op (identity-of:cd value.kind.op)])
    $(entries r.entries, targets targets)
  (collect active.state ~)
::
++  refresh-card
  ^-  card:agent:gall
  [%pass /refresh %arvo %b %wait refresh-at.state]
::
++  refresh-origins
  ^-  [(list card:agent:gall) discovery-state]
  =/  publishing=(set [key record-identity])  publishing-records
  =/  queue=(list [key record-identity])  refresh-queue.state
  =?  queue  ?=(~ queue)
    =/  collect
      |=  [entries=(map [key record-identity] record) out=(list [key record-identity])]
      ^-  (list [key record-identity])
      ?~  entries  out
      $(entries r.entries, out [p.n.entries $(entries l.entries, out out)])
    (collect origins.state ~)
  =/  cards=(list card:agent:gall)  ~
  =/  left=@ud  refresh-batch.config.state
  |-
  ?:  |(?=(~ queue) =(0 left))
    =.  refresh-queue.state  queue
    =/  delay=@dr  ?:(?=(~ queue) refresh.config.state refresh-yield)
    =.  refresh-at.state  (add delay now)
    [(flop [refresh-card cards]) state]
  =/  target=[key record-identity]  i.queue
  =/  remaining=(list [key record-identity])  t.queue
  ?:  (~(has in publishing) target)
    $(queue remaining, left (dec left))
  =/  found=(unit record)  (~(get by origins.state) target)
  ?~  found
    $(queue remaining, left (dec left))
  =/  rec=record  u.found
  =^  id  state  next-operation-id
  =^  started  state  (start-operation id [%publish rec -.target (pack-record rec)])
  =.  background.state  (~(put in background.state) id)
  %=  $
    queue  remaining
    left   (dec left)
    cards  (weld (flop started) cards)
  ==
::
++  start-publish
  |=  [id=operation-id rec=record]
  ^-  [(list card:agent:gall) discovery-state]
  =/  payload=@  (jam rec)
  =/  size=@ud  (met 3 payload)
  =.  state  (put-origin-sized [rec size])
  (start-operation id [%publish rec (record-key rec) payload])
::
++  start-browse
  |=  [id=operation-id topic=topic-path]
  ^-  [(list card:agent:gall) discovery-state]
  ?>  (topic-valid:cd topic)
  (start-operation id [%browse topic (topic-key:cd topic)])
::
++  merge-records
  |=  [op=operation incoming=records]
  ^-  operation
  ?~  incoming  op
  =/  rec=record  i.incoming
  ?:  (~(has in admitted.op) rec)
    $(incoming t.incoming)
  ?.  (record-valid-for op rec)
    $(incoming t.incoming)
  =.  admitted.op  (~(put in admitted.op) rec)
  =.  records.op  [rec records.op]
  $(op op, incoming t.incoming)
::
::  merge-sized-records: merge transport-decoded records while reusing the
::  individual encoded sizes established at the unpacking boundary.
::
++  merge-sized-records
  |=  [op=operation incoming=sized-records]
  ^-  operation
  ?~  incoming  op
  =/  rec=record  value.i.incoming
  ?:  (~(has in admitted.op) rec)
    $(incoming t.incoming)
  ?.  (record-valid-for-sized op i.incoming)
    $(incoming t.incoming)
  =.  admitted.op  (~(put in admitted.op) rec)
  =.  records.op  [rec records.op]
  $(op op, incoming t.incoming)
::
++  finish
  |=  [id=operation-id op=operation]
  ^-  [operation-completion discovery-state]
  =/  result=operation-result
    ?-  -.kind.op
      %publish
        =/  publication=publication-result
          [(identity-of:cd value.kind.op) (operation-key op) accepted.op rejected.op timed-out.op]
        [%published publication]
      %browse
        =/  selected=topic-selection
          (select-admitted:cd now topic.kind.op records.op)
        [%topic topic.kind.op selected responders.op timed-out.op]
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
    %browse
      =/  vals=records  (values-for key.kind.op)
      (merge-records op(responders (~(put in responders.op) peer)) vals)
  ==
::
++  message-for
  |=  [request=discovery-request-id op=operation]
  ^-  discovery-message
  ?-  -.kind.op
    %publish
      [%store protocol request payload.kind.op]
    %browse
      [%find-topic protocol request topic.kind.op]
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
  ^-  discovery-state
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
  ^-  [id=(unit operation-id) out=discovery-state]
  ?~  ready.state  [~ state]
  =/  item=[operation-id (qeu operation-id)]  ~(get to ready.state)
  =/  out=discovery-state
    state(ready +.item, queued (~(del in queued.state) -.item))
  [`-.item out]
::
::  advance-one: perform local work and dispatch at most one remote request.
::
++  advance-one
  |=  [id=operation-id op=operation]
  ^-  $:  cards=(list card:agent:gall)
          completion=(unit operation-completion)
          out=discovery-state
      ==
  ?~  remaining.op
    ?:  =(0 in-flight.op)
      =/  finished=[operation-completion discovery-state]  (finish id op)
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
  =^  request  state  take-discovery-request-id
  =/  deadline=@da  (add request-timeout.config.state now)
  =/  query=?  !=(%publish -.kind.next)
  =/  message=discovery-message  (message-for request next)
  =/  ship=@p  (~(node-to-ship kad kad-cfg) peer)
  =/  note=note:agent:gall
    [%agent [ship %content-discovery] %poke %content-discovery-message !>(message)]
  =/  sent=[delivery-id delivery-update]
    (~(enqueue delivery [now outbound.state]) ship deadline [%request request] note)
  =.  outbound.state  state.+.sent
  =/  pen=pending-discovery-request  [id peer query deadline -.sent]
  =.  pending.state  (~(put by pending.state) request pen)
  =.  pending-count.state  +(pending-count.state)
  =.  in-flight.next  +(in-flight.next)
  =/  timer=card:agent:gall
    [%pass /timeout/(scot %uv request) %arvo %b %wait deadline]
  =.  active.state  (~(put by active.state) id next)
  [(weld cards.+.sent [timer ~]) ~ state]
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
        (gte pending-count.state global-concurrency.config.state)
    ==
  ?:  stopped
    [(flop cards) (flop completions) state]
  =/  popped=[id=(unit operation-id) out=discovery-state]  pop-ready
  =.  state  out.popped
  ?~  id.popped  [(flop cards) (flop completions) state]
  =/  id=operation-id  u.id.popped
  =/  found=(unit operation)  (~(get by active.state) id)
  ?~  found  $(cards cards, completions completions)
  =/  advanced=[cards=(list card:agent:gall) completion=(unit operation-completion) out=discovery-state]
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
  |=  [request=discovery-request-id status=store-status]
  ^-  [(list card:agent:gall) operation-update]
  ?.  (response-expected request %.n)  [~ ~ state]
  =/  found=(unit pending-discovery-request)  (~(get by pending.state) request)
  =/  pen=pending-discovery-request  (need found)
  =.  pending.state  (~(del by pending.state) request)
  =.  pending-count.state  (dec pending-count.state)
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
  |=  [request=discovery-request-id values=sized-records]
  ^-  [(list card:agent:gall) operation-update]
  ?.  (response-expected request %.y)  [~ ~ state]
  =/  found=(unit pending-discovery-request)  (~(get by pending.state) request)
  =/  pen=pending-discovery-request  (need found)
  =.  pending.state  (~(del by pending.state) request)
  =.  pending-count.state  (dec pending-count.state)
  =/  active=(unit operation)  (~(get by active.state) operation.pen)
  ?~  active  [~ ~ state]
  =/  op=operation  u.active
  =.  in-flight.op  (dec in-flight.op)
  =.  responders.op  (~(put in responders.op) peer.pen)
  =.  op  (merge-sized-records op (scag max-records-per-key.config.state values))
  =.  active.state  (~(put by active.state) operation.pen op)
  =.  state  (enqueue operation.pen)
  =/  rest=card:agent:gall
    [%pass /timeout/(scot %uv request) %arvo %b %rest deadline.pen]
  =/  more=[(list card:agent:gall) operation-update]  pump
  [[rest -.more] +.more]
::
++  fail-request
  |=  [request=discovery-request-id cancel=?]
  ^-  [(list card:agent:gall) operation-update]
  ?.  (valid-id request)  [~ ~ state]
  =/  found=(unit pending-discovery-request)  (~(get by pending.state) request)
  ?~  found  [~ ~ state]
  =/  pen=pending-discovery-request  u.found
  =/  ship=@p  (~(node-to-ship kad kad-cfg) peer.pen)
  =/  dropped=delivery-update
    (~(cancel delivery [now outbound.state]) ship delivery.pen)
  =.  outbound.state  state.dropped
  =.  pending.state  (~(del by pending.state) request)
  =.  pending-count.state  (dec pending-count.state)
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
  [(weld cards.dropped (weld cancellation -.more)) +.more]
::
++  send-response
  |=  [ship=@p request=discovery-request-id message=discovery-message]
  ^-  [(list card:agent:gall) discovery-state]
  =/  deadline=@da  (add request-timeout.config.state now)
  =/  note=note:agent:gall
    [%agent [ship %content-discovery] %poke %content-discovery-message !>(message)]
  =/  sent=[delivery-id delivery-update]
    (~(enqueue delivery [now outbound.state]) ship deadline [%response request] note)
  =.  outbound.state  state.+.sent
  [cards.+.sent state]
::
++  delivery-ack
  |=  [peer=@p id=delivery-id error=(unit tang)]
  ^-  [(list card:agent:gall) operation-update]
  =/  updated=delivery-update
    (~(acknowledge delivery [now outbound.state]) peer id error)
  =.  outbound.state  state.updated
  ?~  acked.updated  [cards.updated ~ state]
  ?~  error.u.acked.updated  [cards.updated ~ state]
  ?.  ?=(%request -.context.u.acked.updated)  [cards.updated ~ state]
  =/  failed=[(list card:agent:gall) operation-update]
    (fail-request id.context.u.acked.updated &)
  [(weld cards.updated -.failed) +.failed]
::
++  delivery-expire
  |=  [peer=@p deadline=@da]
  ^-  [(list card:agent:gall) operation-update]
  =/  updated=delivery-update
    (~(expire delivery [now outbound.state]) peer deadline)
  =.  outbound.state  state.updated
  [cards.updated ~ state]
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
  ^-  discovery-state
  ?>  (valid-id id)
  ?>  !(~(has by active.state) id)
  state(completed (~(del by completed.state) id))
--
