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
::  nearest-contacts: collect live routing contacts in exact XOR order.
::
::    Prefix branches matching the target bit are wholly nearer than their
::    siblings, so the traversal stops as soon as .limit contacts are found.
::    Only the bounded live roster of each visited leaf is locally sorted.
::
++  nearest-contacts
  |=  $:  target=node-id
          limit=@ud
          excluded=(unit node-id)
          tab=table
      ==
  ^-  (list contact)
  ?>  (valid-node target)
  =/  walk
    |=  [node=table depth=@ud left=@ud out=(list contact)]
    ^-  [left=@ud out=(list contact)]
    ?:  =(0 left)  [left out]
    ?-  -.node
      %leaf
        =/  available=(list contact)
          ?~  excluded  items.live.buc.node
          %+  skip  items.live.buc.node
          |=  con=contact
          =(u.excluded id.con)
        =/  selected=(list contact)
          (closest target left available)
        =/  remaining=(list contact)  selected
        |-
        ?~  remaining  [left out]
        %=  $
          remaining  t.remaining
          left       (dec left)
          out        [i.remaining out]
        ==
      %fork
        =/  matching=table
          ?:  =(0b0 (node-bit depth target))
            zero.node
          one.node
        =/  other=table
          ?:  =(0b0 (node-bit depth target))
            one.node
          zero.node
        =/  first=[left=@ud out=(list contact)]
          $(node matching, depth +(depth))
        ?:  =(0 left.first)  first
        $(node other, depth +(depth), left left.first, out out.first)
    ==
  =/  found=[left=@ud out=(list contact)]
    (walk tab 0 limit ~)
  (flop out.found)
::
::  empty-table: construct the initial bucket covering the whole ID space.
::
++  empty-table
  |=  refreshed=@da
  ^-  table
  [%leaf refreshed [0 ~] [0 ~]]
::
::  node-bit: read one node-ID bit, most-significant bit first.
::
++  node-bit
  |=  [depth=@ud id=node-id]
  ^-  @ub
  ?>  (lth depth 128)
  (cut 0 [(sub 127 depth) 1] id)
::
::  get-bucket: retrieve the leaf bucket containing an ID.
::
++  get-bucket
  |=  [id=node-id tab=table]
  ^-  bucket
  ?>  (valid-node id)
  =/  depth=@ud  0
  |-
  ?-  -.tab
    %leaf  buc.tab
    %fork  ?:  =(0b0 (node-bit depth id))
              $(tab zero.tab, depth +(depth))
            $(tab one.tab, depth +(depth))
  ==
::
::  bucket-depth: return the prefix length of the leaf containing an ID.
::
++  bucket-depth
  |=  [id=node-id tab=table]
  ^-  @ud
  ?>  (valid-node id)
  =/  depth=@ud  0
  |-
  ?-  -.tab
    %leaf  depth
    %fork  ?:  =(0b0 (node-bit depth id))
              $(tab zero.tab, depth +(depth))
            $(tab one.tab, depth +(depth))
  ==
::
::  bucket-refs: enumerate leaves with their compact prefixes and timestamps.
::
++  bucket-refs
  |=  tab=table
  ^-  (list bucket-ref)
  =/  depth=@ud  0
  =/  prefix=@ux  0x0
  |-
  ?-  -.tab
    %leaf  [[depth prefix refreshed.buc.tab] ~]
    %fork
      =/  zero-refs=(list bucket-ref)
        $(tab zero.tab, depth +(depth), prefix (mul 2 prefix))
      =/  one-refs=(list bucket-ref)
        $(tab one.tab, depth +(depth), prefix (add 1 (mul 2 prefix)))
      (weld zero-refs one-refs)
  ==
::
::  touch-bucket: record that a lookup has begun in the target's leaf.
::
++  touch-bucket
  |=  [id=node-id refreshed=@da tab=table]
  ^-  table
  ?>  (valid-node id)
  =/  depth=@ud  0
  |-
  ?-  -.tab
    %leaf  [%leaf [refreshed live.buc.tab replacements.buc.tab]]
    %fork
      ?:  =(0b0 (node-bit depth id))
        tab(zero $(tab zero.tab, depth +(depth)))
      tab(one $(tab one.tab, depth +(depth)))
  ==
::
::  refresh-target: combine a compact leaf prefix with an entropy suffix.
::
++  refresh-target
  |=  [ref=bucket-ref entropy=@]
  ^-  node-id
  ?>  (lte depth.ref 128)
  =/  suffix-bits=@ud  (sub 128 depth.ref)
  =/  high=node-id  (lsh [0 suffix-bits] prefix.ref)
  =/  low=node-id  (end [0 suffix-bits] entropy)
  (con high low)
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
::  roster-side: retain contacts matching one bit of an ID prefix.
::
++  roster-side
  |=  [depth=@ud side=@ub ros=roster]
  ^-  roster
  =/  selected=contacts
    %+  skim  items.ros
    |=  con=contact
    =(side (node-bit depth id.con))
  [(lent selected) selected]
::
::  fill-bucket: promote replacements into unused live capacity.
::
++  fill-bucket
  |=  buc=bucket
  ^-  bucket
  =/  room=@ud
    ?:  (gte count.live.buc k.cfg)  0
    (sub k.cfg count.live.buc)
  =/  promoted=contacts  (scag room items.replacements.buc)
  =/  live=roster
    %+  roll  promoted
    |=  [con=contact out=_live.buc]
    (push k.cfg con out)
  =/  replacements=roster
    :-  (sub count.replacements.buc (lent promoted))
    (slag room items.replacements.buc)
  [refreshed.buc live replacements]
::
::  split-bucket: partition a bucket at one prefix bit and fill both children.
::
++  split-bucket
  |=  [depth=@ud buc=bucket]
  ^-  [zero=bucket one=bucket]
  =/  zero=bucket
    [refreshed.buc (roster-side depth 0b0 live.buc) (roster-side depth 0b0 replacements.buc)]
  =/  one=bucket
    [refreshed.buc (roster-side depth 0b1 live.buc) (roster-side depth 0b1 replacements.buc)]
  [(fill-bucket zero) (fill-bucket one)]
::
::  prefix-match: test whether an ID begins with one compact prefix.
::
++  prefix-match
  |=  [depth=@ud prefix=@ux id=node-id]
  ^-  ?
  ?:  =(0 depth)  &
  =(prefix (rsh [0 (sub 128 depth)] id))
::
::  roster-in-range: verify that every roster contact belongs to one leaf.
::
++  roster-in-range
  |=  [self=node-id depth=@ud prefix=@ux ros=roster]
  ^-  ?
  =/  remaining=contacts  items.ros
  |-
  ?~  remaining  &
  =/  con=contact  i.remaining
  ?:  =(self id.con)  |
  ?.  (prefix-match depth prefix id.con)  |
  $(remaining t.remaining)
::
::  table-valid: verify prefix topology and all bucket invariants.
::
::    Forks may occur only down the range containing .self.  Leaves may be at
::    most 128 bits deep, and every contact must match its leaf prefix.
::
++  table-valid
  |=  [self=node-id tab=table]
  ^-  ?
  ?.  (valid-node self)  |
  =/  depth=@ud  0
  =/  prefix=@ux  0x0
  =/  owns-self=?  &
  |-
  ?-  -.tab
    %leaf
      ?&  (bucket-valid buc.tab)
          (roster-in-range self depth prefix live.buc.tab)
          (roster-in-range self depth prefix replacements.buc.tab)
      ==
    %fork
      ?.  ?&(owns-self (lth depth 128))  |
      =/  self-side=@ub  (node-bit depth self)
      ?:  =(0b0 self-side)
        ?.  ?=([%leaf *] one.tab)  |
        ?&  $(tab zero.tab, depth +(depth), prefix (mul 2 prefix), owns-self &)
            $(tab one.tab, depth +(depth), prefix (add 1 (mul 2 prefix)), owns-self |)
        ==
      ?.  ?=([%leaf *] zero.tab)  |
      ?&  $(tab zero.tab, depth +(depth), prefix (mul 2 prefix), owns-self |)
          $(tab one.tab, depth +(depth), prefix (add 1 (mul 2 prefix)), owns-self &)
      ==
  ==
::
::  record-success: record a successful direct interaction with a node.
::
::    A full leaf on the local node's prefix path is split and retried.  Full
::    leaves outside that path retain new contacts in their replacement cache.
::
++  record-success
  |=  [self=node-id id=node-id now=@da tab=table]
  ^-  table
  ?>  (valid-node self)
  ?>  (valid-node id)
  ?:  =(self id)  tab
  =/  con=contact  [id now 0]
  =/  depth=@ud  0
  =/  owns-self=?  &
  |-
  ?-  -.tab
    %fork
      =/  side=@ub  (node-bit depth id)
      =/  self-side=@ub  (node-bit depth self)
      =/  child-owns=?  &(owns-self =(side self-side))
      ?:  =(0b0 side)
        =/  child=table
          $(tab zero.tab, depth +(depth), owns-self child-owns)
        tab(zero child)
      =/  child=table
        $(tab one.tab, depth +(depth), owns-self child-owns)
      tab(one child)
    %leaf
      =/  live=roster  live.buc.tab
      =/  replacements=roster  replacements.buc.tab
      =^  old-live  live  (take id live)
      =^  old-replacement  replacements  (take id replacements)
      ?:  ?=(^ old-live)
        [%leaf refreshed.buc.tab (push k.cfg con live) replacements]
      ?:  (lth count.live k.cfg)
        [%leaf refreshed.buc.tab (push k.cfg con live) replacements]
      ?:  ?&(owns-self !=(0 k.cfg) (lth depth 128))
        =/  children=[zero=bucket one=bucket]
          (split-bucket depth [refreshed.buc.tab live replacements])
        $(tab [%fork [%leaf zero.children] [%leaf one.children]])
      [%leaf refreshed.buc.tab live (push replacement-k.cfg con replacements)]
  ==
::
::  record-failure: count a failed request to a live routing contact.
::
::    Eviction and replacement promotion affect only the contact's leaf.  The
::    prefix tree is never merged after removals.
::
++  record-failure
  |=  [self=node-id id=node-id max-fails=@ud tab=table]
  ^-  table
  ?>  (valid-node self)
  ?>  (valid-node id)
  ?:  =(self id)  tab
  =/  depth=@ud  0
  |-
  ?-  -.tab
    %fork
      ?:  =(0b0 (node-bit depth id))
        =/  child=table  $(tab zero.tab, depth +(depth))
        tab(zero child)
      =/  child=table  $(tab one.tab, depth +(depth))
      tab(one child)
    %leaf
      =/  live=roster  live.buc.tab
      =/  replacements=roster  replacements.buc.tab
      =^  old-live  live  (take id live)
      ?~  old-live  tab
      =/  failed=contact  u.old-live(fails +(fails.u.old-live))
      ?:  (lth fails.failed max-fails)
        [%leaf refreshed.buc.tab (push k.cfg failed live) replacements]
      =/  repl-items=contacts  items.replacements
      ?~  repl-items  [%leaf refreshed.buc.tab live replacements]
      =/  promoted=contact  i.repl-items
      =.  replacements  [(dec count.replacements) t.repl-items]
      [%leaf refreshed.buc.tab (push k.cfg promoted live) replacements]
  ==
::
::  contacts: collect every live contact in the routing table.
::
::    Replacement contacts are intentionally excluded.  Ordering is only
::    meaningful within each individual leaf bucket.
::
++  contacts
  |=  tab=table
  ^-  (list contact)
  =/  collect
    |=  [node=table out=(list contact)]
    ^-  (list contact)
    ?-  -.node
      %leaf  (weld items.live.buc.node out)
      %fork
        $(node zero.node, out $(node one.node, out out))
    ==
  (collect tab ~)
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
::  insert-candidate: insert a candidate uniquely in XOR-distance order.
::
++  insert-candidate
  |=  [target=node-id new=lookup-candidate can=lookup-candidates]
  ^-  lookup-candidates
  ?~  can  [new ~]
  ?:  =(id.new id.i.can)  can
  ?:  (candidate-nearer target new i.can)
    [new can]
  [i.can (insert-candidate target new t.can)]
::
::  merge-candidates: merge two unique distance-ordered candidate lists.
::
++  merge-candidates
  |=  [target=node-id left=lookup-candidates right=lookup-candidates]
  ^-  lookup-candidates
  ?~  left  right
  ?~  right  left
  ?:  =(id.i.left id.i.right)
    [i.left $(left t.left, right t.right)]
  ?:  (candidate-nearer target i.left i.right)
    [i.left $(left t.left)]
  [i.right $(right t.right)]
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
  =/  can=lookup-candidates
    (insert-candidate target.lup [id %unasked] candidates.lup)
  lup(candidates can)
::
::  learn: batch-add indirectly discovered IDs to one lookup.
::
::    Incoming IDs are deduplicated with a small set, sorted once, and merged
::    with the existing ordered shortlist in one pass.  The merge discards IDs
::    already present while preserving their existing status.  Learning remains
::    temporary and does not authenticate routing contacts.
::
++  learn
  |=  [self=node-id ids=(list node-id) lup=lookup]
  ^-  lookup
  =/  seen=(set node-id)  ~
  =/  remaining=(list node-id)  ids
  =/  fresh=lookup-candidates  ~
  |-
  ?~  remaining
    =/  ordered=lookup-candidates
      %+  sort  fresh
      |=  [a=lookup-candidate b=lookup-candidate]
      (candidate-nearer target.lup a b)
    lup(candidates (merge-candidates target.lup candidates.lup ordered))
  =/  id=node-id  i.remaining
  ?:  |(!(valid-node id) =(self id) (~(has in seen) id))
    $(remaining t.remaining)
  %=  $
    remaining  t.remaining
    seen       (~(put in seen) id)
    fresh      [[id %unasked] fresh]
  ==
::
::  start-lookup: create a lookup seeded from verified live contacts.
::
::    Routing contacts are validated and deduplicated in one pass, then sorted
::    once by distance.  Subsequently discovered IDs use batch +learn merging.
::
++  start-lookup
  |=  [self=node-id tar=node-id tab=table]
  ^-  lookup
  ?>  (valid-node tar)
  ?>  !=(0 alpha.cfg)
  =/  remaining=contacts  (contacts tab)
  =/  seen=(set node-id)  ~
  =/  candidates=lookup-candidates  ~
  |-
  ?~  remaining
    =/  ordered=lookup-candidates
      %+  sort  candidates
      |=  [a=lookup-candidate b=lookup-candidate]
      (candidate-nearer tar a b)
    [tar ordered]
  =/  id=node-id  id.i.remaining
  ?:  |(!(valid-node id) =(self id) (~(has in seen) id))
    $(remaining t.remaining)
  %=  $
    remaining   t.remaining
    seen        (~(put in seen) id)
    candidates  [[id %unasked] candidates]
  ==
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
::  settle-candidate: update a candidate only when it is currently in flight.
::
::    Absence and stale status transitions both return null.  A successful
::    result contains the complete updated list, constructed in one search.
::
++  settle-candidate
  |=  [id=node-id replacement=lookup-status can=lookup-candidates]
  ^-  (unit lookup-candidates)
  ?~  can  ~
  ?:  =(id id.i.can)
    ?.  =(%in-flight status.i.can)  ~
    `[[id.i.can replacement] t.can]
  =/  rest=(unit lookup-candidates)
    $(can t.can)
  ?~  rest  ~
  `[i.can u.rest]
::
::  in-flight-count: count requests currently owned by a lookup.
::
++  in-flight-count
  |=  lup=lookup
  ^-  @ud
  =/  remaining=lookup-candidates  candidates.lup
  =/  count=@ud  0
  |-
  ?~  remaining  count
  =?  count  =(%in-flight status.i.remaining)  +(count)
  $(remaining t.remaining)
::
::  active-frontier: return the closest .k candidates not known to have failed.
::
++  active-frontier
  |=  lup=lookup
  ^-  lookup-candidates
  =/  remaining=lookup-candidates  candidates.lup
  =/  left=@ud  k.cfg
  |-
  ?:  |(?=(~ remaining) =(0 left))  ~
  ?:  =(%failed status.i.remaining)
    $(remaining t.remaining)
  [i.remaining $(remaining t.remaining, left (dec left))]
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
  =/  walk
    |=  [can=lookup-candidates frontier=@ud slots=@ud]
    ^-  [(list node-id) lookup-candidates]
    ?:  |(?=(~ can) =(0 slots))  [~ can]
    =/  one=lookup-candidate  i.can
    ?:  =(%failed status.one)
      =/  rest=[(list node-id) lookup-candidates]
        $(can t.can)
      [-.rest [one +.rest]]
    ?:  =(0 frontier)  [~ can]
    =/  next-frontier=@ud  (dec frontier)
    ?:  =(%unasked status.one)
      =/  rest=[(list node-id) lookup-candidates]
        $(can t.can, frontier next-frontier, slots (dec slots))
      [[id.one -.rest] [one(status %in-flight) +.rest]]
    =/  rest=[(list node-id) lookup-candidates]
      $(can t.can, frontier next-frontier)
    [-.rest [one +.rest]]
  =/  out=[(list node-id) lookup-candidates]
    (walk candidates.lup k.cfg (sub alpha.cfg flying))
  [-.out lup(candidates +.out)]
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
  =/  updated=(unit lookup-candidates)
    (settle-candidate id %succeeded candidates.lup)
  ?~  updated  [tab lup]
  =/  out=lookup  lup(candidates u.updated)
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
  =/  updated=(unit lookup-candidates)
    (settle-candidate id %failed candidates.lup)
  ?~  updated  [tab lup]
  =/  out=lookup  lup(candidates u.updated)
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
  =/  remaining=lookup-candidates  candidates.lup
  =/  frontier=@ud  k.cfg
  |-
  ?~  remaining  &
  =/  one=lookup-candidate  i.remaining
  ?:  =(%in-flight status.one)  |
  ?:  =(%failed status.one)
    $(remaining t.remaining)
  ?:  =(0 frontier)
    $(remaining t.remaining)
  ?:  =(%unasked status.one)  |
  $(remaining t.remaining, frontier (dec frontier))
::
::  lookup-result: return the closest responsive IDs after completion.
::
++  lookup-result
  |=  lup=lookup
  ^-  (unit (list node-id))
  =/  remaining=lookup-candidates  candidates.lup
  =/  frontier=@ud  k.cfg
  =/  successful=(list node-id)  ~
  |-
  ?~  remaining  `(flop successful)
  =/  one=lookup-candidate  i.remaining
  ?:  =(%in-flight status.one)  ~
  ?:  =(%failed status.one)
    $(remaining t.remaining)
  ?:  =(0 frontier)
    $(remaining t.remaining)
  ?:  =(%unasked status.one)  ~
  %=  $
    remaining   t.remaining
    frontier    (dec frontier)
    successful  [id.one successful]
  ==
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
      ==
    |
  =/  remaining=lookup-candidates  candidates.lup
  =/  seen=(set node-id)  ~
  =/  previous=(unit lookup-candidate)  ~
  =/  flying=@ud  0
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
  =/  next-flying=@ud
    ?:(=(%in-flight status.one) +(flying) flying)
  ?:  (gth next-flying alpha.cfg)  |
  %=  $
    remaining  t.remaining
    seen       (~(put in seen) id.one)
    previous   `one
    flying     next-flying
  ==
::
::  default-config: conventional bucket, replacement, and Feistel settings.
::
++  default-config
  ^-  config
  [20 20 3 12 %kademlia-urbit-v1]
--
