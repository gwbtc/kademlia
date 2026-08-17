/-  *kademlia
/+  kademlia, *test
|%
::
++  cfg  [20 20 3 12 %kademlia-urbit-v1]
::
++  now  ~2026.7.14..10.00.00
::
++  test-identity-roundtrip
  =/  who  ~sampel-palnet
  %+  expect-eq  !>(who)
  !>((~(node-to-ship kademlia cfg) (~(ship-to-node kademlia cfg) who)))
::
++  test-identity-roundtrip-boundaries
  =/  zero=node-id  0x0
  =/  max=node-id  (@ux (dec (pow 2 128)))
  ;:  weld
    %+  expect-eq  !>(zero)
    !>((~(ship-to-node kademlia cfg) (~(node-to-ship kademlia cfg) zero)))
    %+  expect-eq  !>(max)
    !>((~(ship-to-node kademlia cfg) (~(node-to-ship kademlia cfg) max)))
  ==
::
++  test-distance-symmetric
  =/  a  (~(ship-to-node kademlia cfg) ~zod)
  =/  b  (~(ship-to-node kademlia cfg) ~nec)
  ;:  weld
    %+  expect-eq  !>((~(distance kademlia cfg) a b))
    !>((~(distance kademlia cfg) b a))
    (expect !>(!=(0 (~(distance kademlia cfg) a b))))
  ==
::
++  test-self-has-no-bucket
  =/  a  (~(ship-to-node kademlia cfg) ~zod)
  %+  expect-eq  !>(`(unit @ud)`~)
  !>((~(bucket-index kademlia cfg) a a))
::
++  test-bucket-index-boundaries
  =/  max=node-id  (@ux (dec (pow 2 128)))
  ;:  weld
    %+  expect-eq  !>(`(unit @ud)`[~ 0])
    !>((~(bucket-index kademlia cfg) 0x0 0x1))
    %+  expect-eq  !>(`(unit @ud)`[~ 127])
    !>((~(bucket-index kademlia cfg) 0x0 max))
  ==
::
++  test-node-domain
  =/  max=node-id  (@ux (dec (pow 2 128)))
  ;:  weld
    (expect !>((~(valid-node kademlia cfg) 0x0)))
    (expect !>((~(valid-node kademlia cfg) max)))
    (expect !>((~(valid-node kademlia cfg) (~(ship-to-node kademlia cfg) ~zod))))
    %+  expect-eq  !>(%.n)
    !>((~(valid-node kademlia cfg) (@ux (pow 2 128))))
  ==
::
++  test-closest
  =/  now  ~2026.7.11
  =/  far=contact  [0x8 now 0]
  =/  near=contact  [0x1 now 0]
  =/  middle=contact  [0x4 now 0]
  ;:  weld
    %+  expect-eq  !>([near middle far ~])
    !>((~(closest kademlia cfg) 0x0 3 [far near middle ~]))
    %+  expect-eq  !>([near middle ~])
    !>((~(closest kademlia cfg) 0x0 2 [far near middle ~]))
  ==
::
++  empty-bucket  ^-  bucket  [now [0 ~] [0 ~]]
::
++  spine
  |=  length=@ud
  ^-  table
  =/  remaining=@ud  length
  |-
  ?:  =(0 remaining)  [%leaf empty-bucket]
  [%fork $(remaining (dec remaining)) [%leaf empty-bucket]]
::
++  test-empty-prefix-table
  =/  tab=table  (~(empty-table kademlia cfg) now)
  ;:  weld
    %+  expect-eq  !>(`table`[%leaf now [0 ~] [0 ~]])
    !>(tab)
    %+  expect-eq  !>(0)
    !>((~(bucket-depth kademlia cfg) 0x0 tab))
    (expect !>((~(table-valid kademlia cfg) 0x0 tab)))
  ==
::
++  test-refresh-metadata
  =/  small-cfg=config  [1 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  high=node-id  (@ux (pow 2 127))
  =/  quarter=node-id  (@ux (pow 2 126))
  =/  latest=@da  (add ~h1 now)
  =/  tab=table  (~(empty-table kademlia small-cfg) now)
  =.  tab  (~(record-success kademlia small-cfg) self high now tab)
  =.  tab  (~(record-success kademlia small-cfg) self quarter +(now) tab)
  =/  before-high=bucket  (~(get-bucket kademlia small-cfg) high tab)
  =/  before-quarter=bucket  (~(get-bucket kademlia small-cfg) quarter tab)
  =.  tab  (~(touch-bucket kademlia small-cfg) high latest tab)
  =/  after-high=bucket  (~(get-bucket kademlia small-cfg) high tab)
  =/  after-quarter=bucket  (~(get-bucket kademlia small-cfg) quarter tab)
  ;:  weld
    %+  expect-eq  !>(now)
    !>(refreshed.before-high)
    %+  expect-eq  !>(now)
    !>(refreshed.before-quarter)
    %+  expect-eq  !>(latest)
    !>(refreshed.after-high)
    %+  expect-eq  !>(now)
    !>(refreshed.after-quarter)
    %+  expect-eq  !>(2)
    !>((lent (~(bucket-refs kademlia small-cfg) tab)))
  ==
::
++  test-refresh-target-prefix
  =/  max=node-id  (@ux (dec (pow 2 128)))
  =/  ref=bucket-ref  [4 0xa now]
  =/  target=node-id  (~(refresh-target kademlia cfg) ref max)
  ;:  weld
    (expect !>((~(valid-node kademlia cfg) target)))
    (expect !>((~(prefix-match kademlia cfg) 4 0xa target)))
    %+  expect-eq  !>(0xa)
    !>((rsh [0 124] target))
    %+  expect-eq  !>((dec (pow 2 124)))
    !>((end [0 124] target))
  ==
::
++  test-self-range-splits-recursively
  =/  small-cfg=config  [1 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  high=node-id  (@ux (pow 2 127))
  =/  quarter=node-id  (@ux (pow 2 126))
  =/  eighth=node-id  (@ux (pow 2 125))
  =/  now=@da  ~2026.7.14..10.00.00
  =/  tab=table  (~(empty-table kademlia small-cfg) now)
  =.  tab  (~(record-success kademlia small-cfg) self high now tab)
  =.  tab  (~(record-success kademlia small-cfg) self quarter +(now) tab)
  =.  tab  (~(record-success kademlia small-cfg) self eighth (add 2 now) tab)
  ;:  weld
    %+  expect-eq  !>(1)
    !>((~(bucket-depth kademlia small-cfg) high tab))
    %+  expect-eq  !>(2)
    !>((~(bucket-depth kademlia small-cfg) quarter tab))
    %+  expect-eq  !>(2)
    !>((~(bucket-depth kademlia small-cfg) eighth tab))
    %+  expect-eq  !>(3)
    !>((lent (~(contacts kademlia small-cfg) tab)))
    (expect !>((~(table-valid kademlia small-cfg) self tab)))
  ==
::
++  test-full-nonself-uses-replacements
  =/  small-cfg=config  [1 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  quarter=node-id  (@ux (pow 2 126))
  =/  high=node-id  (@ux (pow 2 127))
  =/  high-quarter=node-id  (@ux (add high quarter))
  =/  now=@da  ~2026.7.14..10.00.00
  =/  tab=table  (~(empty-table kademlia small-cfg) now)
  =.  tab  (~(record-success kademlia small-cfg) self quarter now tab)
  =.  tab  (~(record-success kademlia small-cfg) self high +(now) tab)
  =.  tab  (~(record-success kademlia small-cfg) self high-quarter (add 2 now) tab)
  =/  buc=bucket  (~(get-bucket kademlia small-cfg) high tab)
  ;:  weld
    %+  expect-eq  !>(1)
    !>((~(bucket-depth kademlia small-cfg) high tab))
    %+  expect-eq  !>([[high +(now) 0] ~])
    !>(items.live.buc)
    %+  expect-eq  !>([[high-quarter (add 2 now) 0] ~])
    !>(items.replacements.buc)
    (expect !>((~(table-valid kademlia small-cfg) self tab)))
  ==
::
++  test-live-refresh-does-not-split
  =/  small-cfg=config  [1 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  high=node-id  (@ux (pow 2 127))
  =/  first=@da  ~2026.7.14..10.00.00
  =/  latest=@da  ~2026.7.14..12.00.00
  =/  tab=table  (~(empty-table kademlia small-cfg) now)
  =.  tab  (~(record-success kademlia small-cfg) self high first tab)
  =.  tab  (~(record-success kademlia small-cfg) self high latest tab)
  =/  buc=bucket  (~(get-bucket kademlia small-cfg) high tab)
  ;:  weld
    %+  expect-eq  !>(0)
    !>((~(bucket-depth kademlia small-cfg) high tab))
    %+  expect-eq  !>([[high latest 0] ~])
    !>(items.live.buc)
    (expect !>((~(table-valid kademlia small-cfg) self tab)))
  ==
::
++  test-replacement-refresh
  =/  small-cfg=config  [1 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  quarter=node-id  (@ux (pow 2 126))
  =/  high=node-id  (@ux (pow 2 127))
  =/  a=node-id  (@ux (add high quarter))
  =/  b=node-id  (@ux (add high (pow 2 125)))
  =/  now=@da  ~2026.7.14..10.00.00
  =/  latest=@da  ~2026.7.14..15.00.00
  =/  tab=table  (~(empty-table kademlia small-cfg) now)
  =.  tab  (~(record-success kademlia small-cfg) self quarter now tab)
  =.  tab  (~(record-success kademlia small-cfg) self high +(now) tab)
  =.  tab  (~(record-success kademlia small-cfg) self a (add 2 now) tab)
  =.  tab  (~(record-success kademlia small-cfg) self b (add 3 now) tab)
  =.  tab  (~(record-success kademlia small-cfg) self a latest tab)
  =/  buc=bucket  (~(get-bucket kademlia small-cfg) high tab)
  ;:  weld
    %+  expect-eq  !>([[a latest 0] [b (add 3 now) 0] ~])
    !>(items.replacements.buc)
    %+  expect-eq  !>(2)
    !>(count.replacements.buc)
    (expect !>((~(table-valid kademlia small-cfg) self tab)))
  ==
::
++  test-split-promotes-replacements
  =/  small-cfg=config  [1 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  high=node-id  (@ux (pow 2 127))
  =/  quarter=node-id  (@ux (pow 2 126))
  =/  eighth=node-id  (@ux (pow 2 125))
  =/  now=@da  ~2026.7.14..10.00.00
  =/  initial=table
    [%leaf now [1 [[high now 0] ~]] [1 [[quarter +(now) 0] ~]]]
  =/  tab=table
    (~(record-success kademlia small-cfg) self eighth (add 2 now) initial)
  =/  quarter-bucket=bucket
    (~(get-bucket kademlia small-cfg) quarter tab)
  ;:  weld
    %+  expect-eq  !>(3)
    !>((lent (~(contacts kademlia small-cfg) tab)))
    %+  expect-eq  !>(`contacts`~)
    !>(items.replacements.quarter-bucket)
    (expect !>((~(table-valid kademlia small-cfg) self tab)))
  ==
::
++  test-failure-promotes-in-one-leaf
  =/  small-cfg=config  [1 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  quarter=node-id  (@ux (pow 2 126))
  =/  high=node-id  (@ux (pow 2 127))
  =/  replacement=node-id  (@ux (add high quarter))
  =/  now=@da  ~2026.7.14..10.00.00
  =/  tab=table  (~(empty-table kademlia small-cfg) now)
  =.  tab  (~(record-success kademlia small-cfg) self quarter now tab)
  =.  tab  (~(record-success kademlia small-cfg) self high +(now) tab)
  =.  tab  (~(record-success kademlia small-cfg) self replacement (add 2 now) tab)
  =.  tab  (~(record-failure kademlia small-cfg) self high 1 tab)
  =/  high-bucket=bucket  (~(get-bucket kademlia small-cfg) high tab)
  =/  self-bucket=bucket  (~(get-bucket kademlia small-cfg) quarter tab)
  ;:  weld
    %+  expect-eq  !>([[replacement (add 2 now) 0] ~])
    !>(items.live.high-bucket)
    %+  expect-eq  !>([[quarter now 0] ~])
    !>(items.live.self-bucket)
    (expect !>((~(table-valid kademlia small-cfg) self tab)))
  ==
::
++  test-success-resets-failures
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  id=node-id  (@ux (pow 2 127))
  =/  first=@da  ~2026.7.14..10.00.00
  =/  recovered=@da  ~2026.7.14..12.00.00
  =/  tab=table  (~(empty-table kademlia small-cfg) now)
  =.  tab  (~(record-success kademlia small-cfg) self id first tab)
  =.  tab  (~(record-failure kademlia small-cfg) self id 3 tab)
  =.  tab  (~(record-success kademlia small-cfg) self id recovered tab)
  =/  buc=bucket  (~(get-bucket kademlia small-cfg) id tab)
  ;:  weld
    %+  expect-eq  !>([[id recovered 0] ~])
    !>(items.live.buc)
    (expect !>((~(table-valid kademlia small-cfg) self tab)))
  ==
::
++  test-record-failure-unknown
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  tab=table  (~(empty-table kademlia small-cfg) now)
  %+  expect-eq  !>(tab)
  !>((~(record-failure kademlia small-cfg) self 0x8 2 tab))
::
++  test-zero-capacity-bucket
  =/  zero-cfg=config  [0 0 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  tab=table  (~(empty-table kademlia zero-cfg) now)
  =.  tab
    (~(record-success kademlia zero-cfg) self 0x8 ~2026.7.14..10.00.00 tab)
  ;:  weld
    %+  expect-eq  !>(`table`[%leaf now [0 ~] [0 ~]])
    !>(tab)
    (expect !>((~(table-valid kademlia zero-cfg) self tab)))
  ==
::
++  test-contacts-across-leaves
  =/  small-cfg=config  [1 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  high=node-id  (@ux (pow 2 127))
  =/  quarter=node-id  (@ux (pow 2 126))
  =/  eighth=node-id  (@ux (pow 2 125))
  =/  now=@da  ~2026.7.14..10.00.00
  =/  tab=table  (~(empty-table kademlia small-cfg) now)
  =.  tab  (~(record-success kademlia small-cfg) self high now tab)
  =.  tab  (~(record-success kademlia small-cfg) self quarter +(now) tab)
  =.  tab  (~(record-success kademlia small-cfg) self eighth (add 2 now) tab)
  =/  all=contacts  (~(contacts kademlia small-cfg) tab)
  =/  can=lookup-candidates
    (turn all |=([con=contact] [id.con %unasked]))
  ;:  weld
    %+  expect-eq  !>(3)
    !>((lent all))
    (expect !>((~(has-candidate kademlia small-cfg) high can)))
    (expect !>((~(has-candidate kademlia small-cfg) quarter can)))
    (expect !>((~(has-candidate kademlia small-cfg) eighth can)))
  ==
::
++  test-roster-validation
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  too-wide=contact  [(@ux (pow 2 128)) ~2026.7.14..09.00.00 0]
  =/  a=contact  [0x8 ~2026.7.14..10.00.00 0]
  =/  b=contact  [0x9 ~2026.7.14..11.00.00 0]
  ;:  weld
    (expect !>((~(roster-valid kademlia small-cfg) 2 [2 [b a ~]])))
    (expect !>(!(~(roster-valid kademlia small-cfg) 2 [1 [b a ~]])))
    (expect !>(!(~(roster-valid kademlia small-cfg) 1 [2 [b a ~]])))
    (expect !>(!(~(roster-valid kademlia small-cfg) 2 [2 [a a ~]])))
    (expect !>(!(~(roster-valid kademlia small-cfg) 2 [2 [a b ~]])))
    (expect !>(!(~(roster-valid kademlia small-cfg) 2 [1 [too-wide ~]])))
  ==
::
++  test-bucket-validation
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  a=contact  [0x8 ~2026.7.14..10.00.00 0]
  =/  b=contact  [0x9 ~2026.7.14..11.00.00 0]
  ;:  weld
    (expect !>((~(bucket-valid kademlia small-cfg) [now [1 [a ~]] [1 [b ~]]])))
    (expect !>(!(~(bucket-valid kademlia small-cfg) [now [1 [a ~]] [1 [a ~]]])))
  ==
::
++  test-prefix-table-validation
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  high=node-id  (@ux (pow 2 127))
  =/  now=@da  ~2026.7.14..10.00.00
  =/  good=table  (~(empty-table kademlia small-cfg) now)
  =.  good  (~(record-success kademlia small-cfg) self high now good)
  =/  misplaced=table
    [%fork [%leaf now [1 [[high now 0] ~]] [0 ~]] [%leaf empty-bucket]]
  =/  self-entry=table
    [%leaf now [1 [[self now 0] ~]] [0 ~]]
  =/  nonself-fork=table
    [%fork [%leaf empty-bucket] [%fork [%leaf empty-bucket] [%leaf empty-bucket]]]
  ;:  weld
    (expect !>((~(table-valid kademlia small-cfg) self good)))
    (expect !>(!(~(table-valid kademlia small-cfg) self misplaced)))
    (expect !>(!(~(table-valid kademlia small-cfg) self self-entry)))
    (expect !>(!(~(table-valid kademlia small-cfg) self nonself-fork)))
    (expect !>((~(table-valid kademlia small-cfg) self (spine 128))))
    (expect !>(!(~(table-valid kademlia small-cfg) self (spine 129))))
    (expect !>(!(~(table-valid kademlia small-cfg) (@ux (pow 2 128)) good)))
  ==
::
++  test-lookup-dispatch-alpha
  =/  small-cfg=config  [3 3 2 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  initial=table  (~(empty-table kademlia small-cfg) now)
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) self 0xf initial)
  =.  lup  (~(learn kademlia small-cfg) self [0x8 0xe 0xf ~] lup)
  =/  out=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) lup)
  =/  again=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) +.out)
  ;:  weld
    %+  expect-eq  !>([[0xf %unasked] [0xe %unasked] [0x8 %unasked] ~])
    !>(candidates.lup)
    %+  expect-eq  !>([0xf 0xe ~])
    !>(-.out)
    %+  expect-eq  !>([[0xf %in-flight] [0xe %in-flight] [0x8 %unasked] ~])
    !>(candidates.+.out)
    %+  expect-eq  !>(`(list node-id)`~)
    !>(-.again)
    (expect !>((~(lookup-valid kademlia small-cfg) self +.again)))
  ==
::
++  test-lookup-receive-closer
  =/  small-cfg=config  [3 3 2 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  now=@da  ~2026.8.3..10.00.00
  =/  initial=table  (~(empty-table kademlia small-cfg) now)
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) self 0x0 initial)
  =.  lup  (~(learn kademlia small-cfg) self [0x8 0x9 0xa ~] lup)
  =/  sent=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) lup)
  =/  received=[table lookup]
    (~(receive kademlia small-cfg) self 0x8 now [0x1 0x2 ~] initial +.sent)
  =/  refilled=[(list node-id) lookup]
    (~(dispatch kademlia small-cfg) +.received)
  =/  buc=bucket  (~(get-bucket kademlia small-cfg) 0x8 -.received)
  ;:  weld
    %+  expect-eq  !>([0x8 0x9 ~])
    !>(-.sent)
    %+  expect-eq
      !>([[0x1 %unasked] [0x2 %unasked] [0x8 %succeeded] [0x9 %in-flight] [0xa %unasked] ~])
    !>(candidates.+.received)
    %+  expect-eq  !>([0x1 ~])
    !>(-.refilled)
    %+  expect-eq  !>([[0x8 now 0] ~])
    !>(items.live.buc)
    (expect !>((~(lookup-valid kademlia small-cfg) self +.refilled)))
  ==
::
++  test-lookup-timeout-fallback
  =/  small-cfg=config  [2 2 2 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  now=@da  ~2026.8.3..10.00.00
  =/  tab=table  (~(empty-table kademlia small-cfg) now)
  =.  tab  (~(record-success kademlia small-cfg) self 0x1 now tab)
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) self 0x0 tab)
  =.  lup  (~(learn kademlia small-cfg) self [0x2 0x3 ~] lup)
  =/  sent=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) lup)
  =/  timed=[table lookup]
    (~(timeout kademlia small-cfg) self 0x1 3 tab +.sent)
  =/  refilled=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) +.timed)
  =/  buc=bucket  (~(get-bucket kademlia small-cfg) 0x1 -.timed)
  ;:  weld
    %+  expect-eq  !>([0x1 0x2 ~])
    !>(-.sent)
    %+  expect-eq  !>([0x3 ~])
    !>(-.refilled)
    %+  expect-eq  !>([[0x1 now 1] ~])
    !>(items.live.buc)
    %+  expect-eq
      !>([[0x1 %failed] [0x2 %in-flight] [0x3 %in-flight] ~])
    !>(candidates.+.refilled)
    (expect !>((~(lookup-valid kademlia small-cfg) self +.refilled)))
  ==
::
++  test-lookup-completion-result
  =/  small-cfg=config  [2 2 2 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  now=@da  ~2026.8.3..10.00.00
  =/  initial=table  (~(empty-table kademlia small-cfg) now)
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) self 0x0 initial)
  =.  lup  (~(learn kademlia small-cfg) self [0x1 0x2 0x3 ~] lup)
  =/  sent=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) lup)
  =/  first=[table lookup]
    (~(receive kademlia small-cfg) self 0x1 now ~ initial +.sent)
  =/  second=[table lookup]
    (~(receive kademlia small-cfg) self 0x2 +(now) ~ -.first +.first)
  =/  after=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) +.second)
  ;:  weld
    (expect !>((~(lookup-complete kademlia small-cfg) +.second)))
    %+  expect-eq  !>(`(unit (list node-id))`[~ [0x1 0x2 ~]])
    !>((~(lookup-result kademlia small-cfg) +.second))
    %+  expect-eq  !>(`(list node-id)`~)
    !>(-.after)
    (expect !>((~(lookup-valid kademlia small-cfg) self +.second)))
  ==
::
++  test-lookup-completion-after-failure
  =/  small-cfg=config  [3 3 2 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  now=@da  ~2026.8.3..10.00.00
  =/  initial=table  (~(empty-table kademlia small-cfg) now)
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) self 0x0 initial)
  =.  lup  (~(learn kademlia small-cfg) self [0x1 0x2 ~] lup)
  =/  sent=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) lup)
  =/  first=[table lookup]
    (~(receive kademlia small-cfg) self 0x1 now ~ initial +.sent)
  =/  second=[table lookup]
    (~(timeout kademlia small-cfg) self 0x2 1 -.first +.first)
  ;:  weld
    (expect !>((~(lookup-complete kademlia small-cfg) +.second)))
    %+  expect-eq  !>(`(unit (list node-id))`[~ [0x1 ~]])
    !>((~(lookup-result kademlia small-cfg) +.second))
    (expect !>((~(lookup-valid kademlia small-cfg) self +.second)))
  ==
::
++  test-lookup-empty-completes
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  initial=table  (~(empty-table kademlia small-cfg) now)
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) 0x0 0xf initial)
  =/  sent=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) lup)
  ;:  weld
    (expect !>((~(lookup-complete kademlia small-cfg) lup)))
    %+  expect-eq  !>(`(unit (list node-id))`[~ ~])
    !>((~(lookup-result kademlia small-cfg) lup))
    %+  expect-eq  !>(`(list node-id)`~)
    !>(-.sent)
  ==
::
++  test-lookup-stale-events-ignored
  =/  small-cfg=config  [2 2 1 12 %kademlia-urbit-v1]
  =/  now=@da  ~2026.8.3..10.00.00
  =/  initial=table  (~(empty-table kademlia small-cfg) now)
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) 0x0 0xf initial)
  =.  lup  (~(learn kademlia small-cfg) 0x0 [0x8 ~] lup)
  =/  success=[table lookup]
    (~(receive kademlia small-cfg) 0x0 0x8 now [0x1 ~] initial lup)
  =/  failure=[table lookup]
    (~(timeout kademlia small-cfg) 0x0 0x8 1 initial lup)
  ;:  weld
    %+  expect-eq  !>(initial)
    !>(-.success)
    %+  expect-eq  !>(lup)
    !>(+.success)
    %+  expect-eq  !>(initial)
    !>(-.failure)
    %+  expect-eq  !>(lup)
    !>(+.failure)
  ==
::
++  test-lookup-response-cap-and-validation
  =/  small-cfg=config  [3 3 1 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  now=@da  ~2026.8.3..10.00.00
  =/  too-wide=node-id  (@ux (pow 2 128))
  =/  initial=table  (~(empty-table kademlia small-cfg) now)
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) self 0x0 initial)
  =.  lup  (~(learn kademlia small-cfg) self [0x8 ~] lup)
  =/  sent=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) lup)
  =/  out=[table lookup]
    (~(receive kademlia small-cfg) self 0x8 now [self too-wide 0x1 0x2 ~] initial +.sent)
  ;:  weld
    %+  expect-eq  !>([[0x1 %unasked] [0x8 %succeeded] ~])
    !>(candidates.+.out)
    (expect !>(!(~(has-candidate kademlia small-cfg) 0x2 candidates.+.out)))
    (expect !>((~(lookup-valid kademlia small-cfg) self +.out)))
  ==
::
++  test-lookup-validation
  =/  small-cfg=config  [2 2 1 12 %kademlia-urbit-v1]
  =/  zero-alpha-cfg=config  [2 2 0 12 %kademlia-urbit-v1]
  =/  self=node-id  0x8
  =/  too-wide=node-id  (@ux (pow 2 128))
  =/  good=lookup  [0x0 [[0x1 %unasked] [0x2 %failed] ~]]
  =/  bad-target=lookup  [too-wide ~]
  =/  local=lookup  [0x0 [[self %unasked] ~]]
  =/  duplicate=lookup
    [0x0 [[0x1 %unasked] [0x1 %succeeded] ~]]
  =/  unordered=lookup
    [0x0 [[0x2 %unasked] [0x1 %unasked] ~]]
  =/  over-alpha=lookup
    [0x0 [[0x1 %in-flight] [0x2 %in-flight] ~]]
  ;:  weld
    (expect !>((~(lookup-valid kademlia small-cfg) self good)))
    (expect !>(!(~(lookup-valid kademlia zero-alpha-cfg) self good)))
    (expect !>(!(~(lookup-valid kademlia small-cfg) self bad-target)))
    (expect !>(!(~(lookup-valid kademlia small-cfg) self local)))
    (expect !>(!(~(lookup-valid kademlia small-cfg) self duplicate)))
    (expect !>(!(~(lookup-valid kademlia small-cfg) self unordered)))
    (expect !>(!(~(lookup-valid kademlia small-cfg) self over-alpha)))
  ==
--
