/-  *kademlia
/+  feistel
::
::  Pure routing-table and identity operations.  Network I/O belongs in the
::  calling Gall agent; this keeps lookup policy deterministic and testable.
::
|_  cfg=config
::  prp: reversible 128-bit permutation between ships and node IDs.
::
++  prp  (abed:feistel [7 1] rounds.cfg tweak.cfg)
::  ship-to-node: encode a routable ship as its canonical node ID.
::
++  ship-to-node
  |=  who=@p
  ^-  node-id
  ?>  (lte (met 0 who) 128)
  (en:prp who)
::
::  valid-node: test whether an atom fits in the 128-bit node-ID domain.
::
++  valid-node
  |=  id=node-id
  ^-  ?
  (lte (met 0 id) 128)
::
::  node-to-ship: decode a valid canonical node ID into its Urbit ship.
::
++  node-to-ship
  |=  id=node-id
  ^-  @p
  ?>  (valid-node id)
  (de:prp id)
::
::  distance: calculate Kademlia's symmetric XOR distance.
::
++  distance
  |=  [a=node-id b=node-id]
  ^-  @ux
  (mix a b)
::
::  bucket-index: find the highest set bit of the XOR distance.
::
::    Identical IDs have no bucket and produce null.  Valid indexes for
::    distinct 128-bit IDs range from 0 through 127.
::
++  bucket-index
  |=  [self=node-id other=node-id]
  ^-  (unit @ud)
  =/  dis  (distance self other)
  ?:  =(0 dis)  ~
  `[idx=(dec (met 0 dis))]
::
::  nearer: test whether contact .a is closer to .target than contact .b.
::
++  nearer
  |=  [target=node-id a=contact b=contact]
  ^-  ?
  (lth (distance target id.a) (distance target id.b))
::
::  closest: return at most .n contacts in increasing XOR-distance order.
::
++  closest
  |=  [target=node-id n=@ud contacts=(list contact)]
  ^-  (list contact)
  (scag n (sort contacts |=([a=contact b=contact] (nearer target a b))))
::
::  get-bucket: retrieve a distance bucket, defaulting to two empty rosters.
::
++  get-bucket
  |=  [idx=@ud tab=table]
  ^-  bucket
  (fall (~(get by tab) idx) [[0 ~] [0 ~]])
::
::  take: remove one contact by ID while preserving order and count.
::
::    Produces the removed contact if found and the resulting roster.  When
::    absent, the original roster is returned unchanged.
::
++  take
  |=  [id=node-id ros=roster]
  ^-  [(unit contact) roster]
  =/  remaining=contacts  items.ros
  =/  before=contacts  ~
  |-
  ?~  remaining  [~ ros]
  ?:  =(id id.i.remaining)
    [`i.remaining [(dec count.ros) (weld (flop before) t.remaining)]]
  $(remaining t.remaining, before [i.remaining before])
::
::  contact-before: compare contacts in routing-roster order.
::
::    Newer observations precede older ones.  Equal observation times prefer
::    fewer failures, with node ID providing a deterministic final tie-break.
::
++  contact-before
  |=  [a=contact b=contact]
  ^-  ?
  ?:  =(seen.a seen.b)
    ?:  =(fails.a fails.b)
      (lth id.a id.b)
    (lth fails.a fails.b)
  (gth seen.a seen.b)
::
::  insert-contact: insert an absent contact in routing-roster order.
::
++  insert-contact
  |=  [con=contact items=contacts]
  ^-  contacts
  ?~  items  [con ~]
  ?:  (contact-before con i.items)
    [con items]
  [i.items (insert-contact con t.items)]
::
::  push: insert an absent contact and cap the roster at .max entries.
::
::    Callers must remove an existing copy first.  The roster remains ordered
::    by +contact-before.  If full, its lowest-priority tail entry is discarded.
::    A zero maximum yields an empty roster.
::
++  push
  |=  [max=@ud con=contact ros=roster]
  ^-  roster
  ?:  =(0 max)  [0 ~]
  =/  items=contacts  (insert-contact con items.ros)
  ?:  (lth count.ros max)
    [+(count.ros) items]
  [max (scag max items)]
::
::  roster-has: test whether a roster contains a node ID.
::
++  roster-has
  |=  [id=node-id ros=roster]
  ^-  ?
  =/  remaining=contacts  items.ros
  |-
  ?~  remaining  |
  ?:  =(id id.i.remaining)  &
  $(remaining t.remaining)
::
::  roster-valid: verify the structural invariants of one routing roster.
::
::    The stored count must equal the list length and fit within .max.  Every
::    ID must be valid and unique, and contacts must follow +contact-before.
::
++  roster-valid
  |=  [max=@ud ros=roster]
  ^-  ?
  ?.  ?&  =(count.ros (lent items.ros))
          (lte count.ros max)
      ==
    |
  =/  remaining=contacts  items.ros
  =/  seen=(set node-id)  ~
  =/  previous=(unit contact)  ~
  |-
  ?~  remaining  &
  =/  con=contact  i.remaining
  ?.  (valid-node id.con)  |
  ?:  (~(has in seen) id.con)  |
  =/  ordered=?
    ?~  previous  &
    (contact-before u.previous con)
  ?.  ordered  |
  %=  $
    remaining  t.remaining
    seen       (~(put in seen) id.con)
    previous   `con
  ==
::
::  rosters-disjoint: verify that two rosters share no node IDs.
::
++  rosters-disjoint
  |=  [a=roster b=roster]
  ^-  ?
  =/  remaining=contacts  items.a
  |-
  ?~  remaining  &
  ?:  (roster-has id.i.remaining b)  |
  $(remaining t.remaining)
::
::  bucket-valid: verify capacity, ordering, and disjoint membership.
::
++  bucket-valid
  |=  buc=bucket
  ^-  ?
  ?&  (roster-valid k.cfg live.buc)
      (roster-valid replacement-k.cfg replacements.buc)
      (rosters-disjoint live.buc replacements.buc)
  ==
::
::  roster-in-bucket: verify every roster ID belongs at one distance index.
::
++  roster-in-bucket
  |=  [self=node-id idx=@ud ros=roster]
  ^-  ?
  =/  remaining=contacts  items.ros
  |-
  ?~  remaining  &
  =/  got=(unit @ud)  (bucket-index self id.i.remaining)
  ?~  got  |
  ?.  =(idx u.got)  |
  $(remaining t.remaining)
::
::  table-valid: verify all routing-table and bucket invariants.
::
::    The local ID must be valid; map keys must be 128-bit distance indexes;
::    every bucket must be valid; and every contact must occur in the bucket
::    selected by its XOR distance from .self.  This also excludes .self.
::
++  table-valid
  |=  [self=node-id tab=table]
  ^-  ?
  ?.  (valid-node self)  |
  =/  entries=(list [@ud bucket])  ~(tap by tab)
  |-
  ?~  entries  &
  =/  [idx=@ud buc=bucket]  i.entries
  ?.  (lte idx 127)  |
  ?.  (bucket-valid buc)  |
  ?.  (roster-in-bucket self idx live.buc)  |
  ?.  (roster-in-bucket self idx replacements.buc)  |
  $(entries t.entries)
::
::  record-success: record a successful direct interaction with a node.
::
::    Resets failures, sets the observation time, and moves an existing live
::    contact to the front.  A new or replacement contact enters the live
::    roster when room exists; otherwise it enters the bounded replacement
::    roster.  The local node itself is ignored because it has no bucket.
::
++  record-success
  |=  [self=node-id id=node-id now=@da tab=table]
  ^-  table
  ?>  (valid-node id)
  =/  con=contact  [id now 0]
  =/  idx=(unit @ud)  (bucket-index self id)
  ?~  idx  tab
  =/  buc=bucket  (get-bucket u.idx tab)
  =/  live=roster  live.buc
  =/  replacements=roster  replacements.buc
  =^  old-live  live  (take id live)
  =^  old-replacement  replacements  (take id replacements)
  ?:  |(?=(^ old-live) (lth count.live k.cfg))
    =.  live  (push k.cfg con live)
    (~(put by tab) u.idx [live replacements])
  =.  replacements  (push replacement-k.cfg con replacements)
  (~(put by tab) u.idx [live replacements])
::
::  record-failure: count a failed request to a live routing contact.
::
::    Contacts below .max-fails remain live with an incremented counter.  A
::    contact reaching the threshold is evicted, and the highest-priority
::    replacement is promoted when available.  Unknown and local IDs leave
::    the table unchanged.
::
++  record-failure
  |=  [self=node-id id=node-id max-fails=@ud tab=table]
  ^-  table
  ?>  (valid-node id)
  =/  idx=(unit @ud)  (bucket-index self id)
  ?~  idx  tab
  =/  buc=bucket  (get-bucket u.idx tab)
  =/  live=roster  live.buc
  =/  replacements=roster  replacements.buc
  =^  old-live  live  (take id live)
  ?~  old-live  tab
  =/  failed=contact  u.old-live(fails +(fails.u.old-live))
  ?:  (lth fails.failed max-fails)
    =.  live  (push k.cfg failed live)
    (~(put by tab) u.idx [live replacements])
  =/  repl-items=contacts  items.replacements
  ?~  repl-items
    (~(put by tab) u.idx [live replacements])
  =/  promoted=contact  i.repl-items
  =.  replacements
    [(dec count.replacements) t.repl-items]
  =.  live  (push k.cfg promoted live)
  (~(put by tab) u.idx [live replacements])
::
::  contacts: collect every live contact in the routing table.
::
::    Replacement contacts are intentionally excluded.  Ordering is only
::    meaningful within each individual bucket.
::
++  contacts
  |=  tab=table
  ^-  (list contact)
  %+  roll  ~(tap by tab)
  |=  [[idx=@ud buc=bucket] out=(list contact)]
  (weld items.live.buc out)
::
::  candidate-nearer: compare lookup candidate IDs by XOR distance.
::
++  candidate-nearer
  |=  [target=node-id a=lookup-candidate b=lookup-candidate]
  ^-  ?
  (lth (distance target id.a) (distance target id.b))
::
::  has-candidate: test whether an ID is already known to a lookup.
::
++  has-candidate
  |=  [id=node-id can=lookup-candidates]
  ^-  ?
  =/  remaining=lookup-candidates  can
  |-
  ?~  remaining  |
  ?:  =(id id.i.remaining)  &
  $(remaining t.remaining)
::
::  insert-candidate: insert a candidate in XOR-distance order.
::
::    This arm does not deduplicate; +learn-one enforces that invariant.
::
++  insert-candidate
  |=  [target=node-id new=lookup-candidate can=lookup-candidates]
  ^-  lookup-candidates
  ?~  can  [new ~]
  ?:  (candidate-nearer target new i.can)
    [new can]
  [i.can (insert-candidate target new t.can)]
::
::  learn-one: add one indirectly discovered ID to a lookup shortlist.
::
::    Invalid, local, and duplicate IDs are ignored.  New IDs begin unasked,
::    and all discovered candidates are retained as failure fallbacks.
::
++  learn-one
  |=  [self=node-id id=node-id lup=lookup]
  ^-  lookup
  ?:  |(!(valid-node id) =(self id))  lup
  ?:  (has-candidate id candidates.lup)  lup
  =/  can=lookup-candidates
    (insert-candidate target.lup [id %unasked] candidates.lup)
  lup(candidates can)
::
::  learn: add a list of indirectly discovered IDs to one lookup.
::
::    Learning affects only temporary lookup state; it does not authenticate
::    the peers or insert them into the routing table.
::
++  learn
  |=  [self=node-id ids=(list node-id) lup=lookup]
  ^-  lookup
  %+  roll  ids
  |=  [id=node-id out=_lup]
  (learn-one self id out)
::
::  start-lookup: create a lookup seeded from verified live contacts.
::
::    Routing contacts are converted to IDs, ordered relative to .tar, and
::    added through the same +learn logic as subsequently discovered IDs.
::
++  start-lookup
  |=  [self=node-id tar=node-id tab=table]
  ^-  lookup
  ?>  (valid-node tar)
  ?>  !=(0 alpha.cfg)
  =/  ids=(list node-id)
    (turn (contacts tab) |=([con=contact] id.con))
  (learn self ids [tar ~])
::
::  candidate-status: retrieve the state of a known candidate.
::
++  candidate-status
  |=  [id=node-id can=lookup-candidates]
  ^-  (unit lookup-status)
  ?~  can  ~
  ?:  =(id id.i.can)  `status.i.can
  $(can t.can)
::
::  set-candidate-status: replace the state of a known candidate.
::
++  set-candidate-status
  |=  [id=node-id status=lookup-status can=lookup-candidates]
  ^-  lookup-candidates
  ?~  can  ~
  ?:  =(id id.i.can)
    [i.can(status status) t.can]
  [i.can $(can t.can)]
::
::  in-flight-count: count requests currently owned by a lookup.
::
++  in-flight-count
  |=  lup=lookup
  ^-  @ud
  =/  is-flying=$-(lookup-candidate ?)
    |=  one=lookup-candidate
    =(%in-flight status.one)
  (lent (skim candidates.lup is-flying))
::
::  active-frontier: return the closest .k candidates not known to have failed.
::
++  active-frontier
  |=  lup=lookup
  ^-  lookup-candidates
  =/  is-usable=$-(lookup-candidate ?)
    |=  one=lookup-candidate
    !=(%failed status.one)
  =/  usable=lookup-candidates  (skim candidates.lup is-usable)
  (scag k.cfg usable)
::
::  dispatch: atomically fill available alpha slots from the active frontier.
::
::    Selected candidates become in-flight in the returned lookup.  The IDs
::    are returned in increasing XOR-distance order for the caller to request.
::
++  dispatch
  |=  lup=lookup
  ^-  [(list node-id) lookup]
  =/  flying=@ud  (in-flight-count lup)
  ?:  (gte flying alpha.cfg)  [~ lup]
  =/  available=@ud  (sub alpha.cfg flying)
  =/  is-unasked=$-(lookup-candidate ?)
    |=  one=lookup-candidate
    =(%unasked status.one)
  =/  unasked=lookup-candidates  (skim (active-frontier lup) is-unasked)
  =/  ids=(list node-id)
    (turn (scag available unasked) |=([one=lookup-candidate] id.one))
  =/  out=lookup
    %+  roll  ids
    |=  [id=node-id acc=_lup]
    acc(candidates (set-candidate-status id %in-flight candidates.acc))
  [ids out]
::
::  receive: apply a successful response from an in-flight candidate.
::
::    The responder becomes successful and a verified routing contact.  At
::    most .k raw returned IDs are learned; invalid, local, and duplicate IDs
::    among them are ignored.  Stale or unsolicited responses are no-ops.
::
++  receive
  |=  $:  self=node-id
          id=node-id
          now=@da
          returned=(list node-id)
          tab=table
          lup=lookup
      ==
  ^-  [table lookup]
  =/  status=(unit lookup-status)  (candidate-status id candidates.lup)
  ?~  status  [tab lup]
  ?.  =(%in-flight u.status)  [tab lup]
  =/  out=lookup
    lup(candidates (set-candidate-status id %succeeded candidates.lup))
  =.  out  (learn self (scag k.cfg returned) out)
  [(record-success self id now tab) out]
::
::  timeout: apply failure to an in-flight candidate and routing contact.
::
::    The candidate is removed from consideration, allowing farther known IDs
::    into the frontier.  Stale or unsolicited timeout events are no-ops.
::
++  timeout
  |=  [self=node-id id=node-id max-fails=@ud tab=table lup=lookup]
  ^-  [table lookup]
  =/  status=(unit lookup-status)  (candidate-status id candidates.lup)
  ?~  status  [tab lup]
  ?.  =(%in-flight u.status)  [tab lup]
  =/  out=lookup
    lup(candidates (set-candidate-status id %failed candidates.lup))
  [(record-failure self id max-fails tab) out]
::
::  lookup-complete: test whether the active frontier has settled.
::
::    Completion requires no in-flight requests and no unasked candidates in
::    the closest .k nonfailed candidates.
::
++  lookup-complete
  |=  lup=lookup
  ^-  ?
  ?:  !=(0 (in-flight-count lup))  |
  =/  is-unasked=$-(lookup-candidate ?)
    |=  one=lookup-candidate
    =(%unasked status.one)
  =/  unasked=lookup-candidates  (skim (active-frontier lup) is-unasked)
  =(0 (lent unasked))
::
::  lookup-result: return the closest responsive IDs after completion.
::
++  lookup-result
  |=  lup=lookup
  ^-  (unit (list node-id))
  ?.  (lookup-complete lup)  ~
  =/  is-successful=$-(lookup-candidate ?)
    |=  one=lookup-candidate
    =(%succeeded status.one)
  =/  successful=lookup-candidates
    (skim (active-frontier lup) is-successful)
  `(turn successful |=([one=lookup-candidate] id.one))
::
::  lookup-valid: verify ordering and state-machine invariants.
::
::    IDs must be valid, unique, nonlocal, and distance ordered.  Target and
::    local IDs must be valid, configured alpha must be positive, and in-flight
::    state may not exceed it.
::
++  lookup-valid
  |=  [self=node-id lup=lookup]
  ^-  ?
  ?.  ?&  (valid-node self)
          (valid-node target.lup)
          !=(0 alpha.cfg)
          (lte (in-flight-count lup) alpha.cfg)
      ==
    |
  =/  remaining=lookup-candidates  candidates.lup
  =/  seen=(set node-id)  ~
  =/  previous=(unit lookup-candidate)  ~
  |-
  ?~  remaining  &
  =/  one=lookup-candidate  i.remaining
  ?.  (valid-node id.one)  |
  ?:  =(self id.one)  |
  ?:  (~(has in seen) id.one)  |
  =/  ordered=?
    ?~  previous  &
    (candidate-nearer target.lup u.previous one)
  ?.  ordered  |
  %=  $
    remaining  t.remaining
    seen       (~(put in seen) id.one)
    previous   `one
  ==
::
::  default-config: conventional bucket, replacement, and Feistel settings.
::
++  default-config
  ^-  config
  [20 20 3 12 %kademlia-urbit-v1]
--
