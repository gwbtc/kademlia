/-  *kademlia
/+  kademlia, *test
|%
::
++  cfg  [20 20 3 12 %kademlia-urbit-v1]
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
++  test-list-bucket-record-success
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  a=contact  [0x8 ~2026.7.14..10.00.00 0]
  =/  b=contact  [0x9 ~2026.7.14..11.00.00 0]
  =/  c=contact  [0xa ~2026.7.14..12.00.00 0]
  =/  d=contact  [0xb ~2026.7.14..13.00.00 0]
  =/  e=contact  [0xc ~2026.7.14..14.00.00 0]
  =/  tab=table  ~
  =.  tab  (~(record-success kademlia small-cfg) self id.a seen.a tab)
  =.  tab  (~(record-success kademlia small-cfg) self id.b seen.b tab)
  =.  tab  (~(record-success kademlia small-cfg) self id.c seen.c tab)
  =.  tab  (~(record-success kademlia small-cfg) self id.d seen.d tab)
  =.  tab  (~(record-success kademlia small-cfg) self id.e seen.e tab)
  =/  buc=bucket  (~(get-bucket kademlia small-cfg) 3 tab)
  ;:  weld
    %+  expect-eq  !>([b a ~])
    !>(items.live.buc)
    %+  expect-eq  !>(2)
    !>(count.live.buc)
    %+  expect-eq  !>([e d ~])
    !>(items.replacements.buc)
    %+  expect-eq  !>(2)
    !>(count.replacements.buc)
    %+  expect-eq  !>([b a ~])
    !>((~(contacts kademlia small-cfg) tab))
    (expect !>((~(table-valid kademlia small-cfg) self tab)))
  ==
::
++  test-list-bucket-refresh
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  a=contact  [0x8 ~2026.7.14..10.00.00 0]
  =/  b=contact  [0x9 ~2026.7.14..11.00.00 0]
  =/  c=contact  [0xa ~2026.7.14..12.00.00 0]
  =/  d=contact  [0xb ~2026.7.14..13.00.00 0]
  =/  refreshed-a=contact  [0x8 ~2026.7.14..15.00.00 0]
  =/  refreshed-c=contact  [0xa ~2026.7.14..16.00.00 0]
  =/  tab=table  ~
  =.  tab  (~(record-success kademlia small-cfg) self id.a seen.a tab)
  =.  tab  (~(record-success kademlia small-cfg) self id.b seen.b tab)
  =.  tab  (~(record-success kademlia small-cfg) self id.c seen.c tab)
  =.  tab  (~(record-success kademlia small-cfg) self id.d seen.d tab)
  =.  tab  (~(record-success kademlia small-cfg) self id.refreshed-a seen.refreshed-a tab)
  =.  tab  (~(record-success kademlia small-cfg) self id.refreshed-c seen.refreshed-c tab)
  =/  buc=bucket  (~(get-bucket kademlia small-cfg) 3 tab)
  ;:  weld
    %+  expect-eq  !>([refreshed-a b ~])
    !>(items.live.buc)
    %+  expect-eq  !>(2)
    !>(count.live.buc)
    %+  expect-eq  !>([refreshed-c d ~])
    !>(items.replacements.buc)
    %+  expect-eq  !>(2)
    !>(count.replacements.buc)
    (expect !>((~(table-valid kademlia small-cfg) self tab)))
  ==
::
++  test-zero-capacity-bucket
  =/  zero-cfg=config  [0 0 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  tab=table  ~
  =.  tab
    (~(record-success kademlia zero-cfg) self 0x8 ~2026.7.14..10.00.00 tab)
  =/  buc=bucket  (~(get-bucket kademlia zero-cfg) 3 tab)
  ;:  weld
    %+  expect-eq  !>(`bucket`[[0 ~] [0 ~]])
    !>(buc)
    %+  expect-eq  !>(`contacts`~)
    !>((~(contacts kademlia zero-cfg) tab))
    (expect !>((~(table-valid kademlia zero-cfg) self tab)))
  ==
::
++  test-replacement-refresh
  =/  small-cfg=config  [1 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  a=contact  [0x8 ~2026.7.14..10.00.00 0]
  =/  b=contact  [0x9 ~2026.7.14..11.00.00 0]
  =/  c=contact  [0xa ~2026.7.14..12.00.00 0]
  =/  refreshed-b=contact  [0x9 ~2026.7.14..13.00.00 0]
  =/  tab=table  ~
  =.  tab  (~(record-success kademlia small-cfg) self id.a seen.a tab)
  =.  tab  (~(record-success kademlia small-cfg) self id.b seen.b tab)
  =.  tab  (~(record-success kademlia small-cfg) self id.c seen.c tab)
  =.  tab
    (~(record-success kademlia small-cfg) self id.refreshed-b seen.refreshed-b tab)
  =/  buc=bucket  (~(get-bucket kademlia small-cfg) 3 tab)
  ;:  weld
    %+  expect-eq  !>([a ~])
    !>(items.live.buc)
    %+  expect-eq  !>([refreshed-b c ~])
    !>(items.replacements.buc)
    %+  expect-eq  !>(2)
    !>(count.replacements.buc)
    (expect !>((~(table-valid kademlia small-cfg) self tab)))
  ==
::
++  test-replacement-moves-to-live
  =/  one-cfg=config  [1 2 3 12 %kademlia-urbit-v1]
  =/  two-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  a=contact  [0x8 ~2026.7.14..10.00.00 0]
  =/  b=contact  [0x9 ~2026.7.14..11.00.00 0]
  =/  refreshed-b=contact  [0x9 ~2026.7.14..12.00.00 0]
  =/  tab=table  ~
  =.  tab  (~(record-success kademlia one-cfg) self id.a seen.a tab)
  =.  tab  (~(record-success kademlia one-cfg) self id.b seen.b tab)
  =.  tab
    (~(record-success kademlia two-cfg) self id.refreshed-b seen.refreshed-b tab)
  =/  buc=bucket  (~(get-bucket kademlia two-cfg) 3 tab)
  ;:  weld
    %+  expect-eq  !>([refreshed-b a ~])
    !>(items.live.buc)
    %+  expect-eq  !>(2)
    !>(count.live.buc)
    %+  expect-eq  !>(`contacts`~)
    !>(items.replacements.buc)
    %+  expect-eq  !>(0)
    !>(count.replacements.buc)
    (expect !>((~(table-valid kademlia two-cfg) self tab)))
  ==
::
++  test-duplicate-prevention
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  first=@da  ~2026.7.14..10.00.00
  =/  latest=@da  ~2026.7.14..12.00.00
  =/  tab=table  ~
  =.  tab  (~(record-success kademlia small-cfg) self 0x8 first tab)
  =.  tab  (~(record-success kademlia small-cfg) self 0x8 +(first) tab)
  =.  tab  (~(record-success kademlia small-cfg) self 0x8 latest tab)
  =/  buc=bucket  (~(get-bucket kademlia small-cfg) 3 tab)
  ;:  weld
    %+  expect-eq  !>([[0x8 latest 0] ~])
    !>(items.live.buc)
    %+  expect-eq  !>(1)
    !>(count.live.buc)
    %+  expect-eq  !>(`contacts`~)
    !>(items.replacements.buc)
    (expect !>((~(table-valid kademlia small-cfg) self tab)))
  ==
::
++  test-success-resets-failures
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  first=@da  ~2026.7.14..10.00.00
  =/  recovered=@da  ~2026.7.14..11.00.00
  =/  tab=table  ~
  =.  tab  (~(record-success kademlia small-cfg) self 0x8 first tab)
  =.  tab  (~(record-failure kademlia small-cfg) self 0x8 3 tab)
  =.  tab  (~(record-success kademlia small-cfg) self 0x8 recovered tab)
  =/  buc=bucket  (~(get-bucket kademlia small-cfg) 3 tab)
  ;:  weld
    %+  expect-eq  !>([[0x8 recovered 0] ~])
    !>(items.live.buc)
    %+  expect-eq  !>(1)
    !>(count.live.buc)
    (expect !>((~(table-valid kademlia small-cfg) self tab)))
  ==
::
++  test-contacts-across-buckets
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  now=@da  ~2026.7.14..10.00.00
  =/  tab=table  ~
  =.  tab  (~(record-success kademlia small-cfg) self 0x1 now tab)
  =.  tab  (~(record-success kademlia small-cfg) self 0x2 +(now) tab)
  =.  tab  (~(record-success kademlia small-cfg) self 0x4 (add 2 now) tab)
  =.  tab  (~(record-success kademlia small-cfg) self 0x8 (add 3 now) tab)
  =/  all=contacts  (~(contacts kademlia small-cfg) tab)
  =/  can=lookup-candidates
    (turn all |=([con=contact] [id.con %unasked]))
  ;:  weld
    %+  expect-eq  !>(4)
    !>((lent all))
    (expect !>((~(has-candidate kademlia small-cfg) 0x1 can)))
    (expect !>((~(has-candidate kademlia small-cfg) 0x2 can)))
    (expect !>((~(has-candidate kademlia small-cfg) 0x4 can)))
    (expect !>((~(has-candidate kademlia small-cfg) 0x8 can)))
    (expect !>((~(table-valid kademlia small-cfg) self tab)))
  ==
::
++  test-record-failure-and-promote
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  a=contact  [0x8 ~2026.7.14..10.00.00 0]
  =/  b=contact  [0x9 ~2026.7.14..11.00.00 0]
  =/  c=contact  [0xa ~2026.7.14..12.00.00 0]
  =/  d=contact  [0xb ~2026.7.14..13.00.00 0]
  =/  failed-a=contact  a(fails 1)
  =/  tab=table  ~
  =.  tab  (~(record-success kademlia small-cfg) self id.a seen.a tab)
  =.  tab  (~(record-success kademlia small-cfg) self id.b seen.b tab)
  =.  tab  (~(record-success kademlia small-cfg) self id.c seen.c tab)
  =.  tab  (~(record-success kademlia small-cfg) self id.d seen.d tab)
  =.  tab  (~(record-failure kademlia small-cfg) self id.a 2 tab)
  =/  retained=bucket  (~(get-bucket kademlia small-cfg) 3 tab)
  =.  tab  (~(record-failure kademlia small-cfg) self id.a 2 tab)
  =/  promoted=bucket  (~(get-bucket kademlia small-cfg) 3 tab)
  ;:  weld
    %+  expect-eq  !>([b failed-a ~])
    !>(items.live.retained)
    %+  expect-eq  !>([d c ~])
    !>(items.replacements.retained)
    %+  expect-eq  !>([d b ~])
    !>(items.live.promoted)
    %+  expect-eq  !>(2)
    !>(count.live.promoted)
    %+  expect-eq  !>([c ~])
    !>(items.replacements.promoted)
    %+  expect-eq  !>(1)
    !>(count.replacements.promoted)
  ==
::
++  test-record-failure-unknown
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  tab=table  ~
  %+  expect-eq  !>(tab)
  !>((~(record-failure kademlia small-cfg) self 0x8 2 tab))
::
++  test-record-failure-without-replacement
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  now=@da  ~2026.7.14..10.00.00
  =/  tab=table  ~
  =.  tab  (~(record-success kademlia small-cfg) self 0x8 now tab)
  =.  tab  (~(record-failure kademlia small-cfg) self 0x8 1 tab)
  =/  buc=bucket  (~(get-bucket kademlia small-cfg) 3 tab)
  ;:  weld
    %+  expect-eq  !>(`contacts`~)
    !>(items.live.buc)
    %+  expect-eq  !>(0)
    !>(count.live.buc)
    %+  expect-eq  !>(`contacts`~)
    !>(items.replacements.buc)
    %+  expect-eq  !>(0)
    !>(count.replacements.buc)
  ==
::
++  test-roster-validation
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  a=contact  [0x8 ~2026.7.14..10.00.00 0]
  =/  b=contact  [0x9 ~2026.7.14..11.00.00 0]
  =/  too-wide=contact  [(@ux (pow 2 128)) ~2026.7.14..12.00.00 0]
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
    (expect !>((~(bucket-valid kademlia small-cfg) [[1 [a ~]] [1 [b ~]]])))
    (expect !>(!(~(bucket-valid kademlia small-cfg) [[1 [a ~]] [1 [a ~]]])))
  ==
::
++  test-table-validation
  =/  small-cfg=config  [2 2 3 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  now=@da  ~2026.7.14..10.00.00
  =/  good=table  ~
  =.  good  (~(record-success kademlia small-cfg) self 0x8 now good)
  =.  good  (~(record-success kademlia small-cfg) self 0x9 +(now) good)
  =/  misplaced=table  ~
  =.  misplaced
    (~(put by misplaced) 2 [[1 [[0x8 now 0] ~]] [0 ~]])
  =/  self-entry=table  ~
  =.  self-entry
    (~(put by self-entry) 0 [[1 [[self now 0] ~]] [0 ~]])
  =/  invalid-index=table  ~
  =.  invalid-index
    (~(put by invalid-index) 128 [[0 ~] [0 ~]])
  ;:  weld
    (expect !>((~(table-valid kademlia small-cfg) self good)))
    (expect !>(!(~(table-valid kademlia small-cfg) self misplaced)))
    (expect !>(!(~(table-valid kademlia small-cfg) self self-entry)))
    (expect !>(!(~(table-valid kademlia small-cfg) self invalid-index)))
    (expect !>(!(~(table-valid kademlia small-cfg) (@ux (pow 2 128)) ~)))
  ==
::
++  test-lookup-dispatch-alpha
  =/  small-cfg=config  [3 3 2 12 %kademlia-urbit-v1]
  =/  self=node-id  0x0
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) self 0xf ~)
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
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) self 0x0 ~)
  =.  lup  (~(learn kademlia small-cfg) self [0x8 0x9 0xa ~] lup)
  =/  sent=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) lup)
  =/  received=[table lookup]
    (~(receive kademlia small-cfg) self 0x8 now [0x1 0x2 ~] ~ +.sent)
  =/  refilled=[(list node-id) lookup]
    (~(dispatch kademlia small-cfg) +.received)
  =/  buc=bucket  (~(get-bucket kademlia small-cfg) 3 -.received)
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
  =/  tab=table  ~
  =.  tab  (~(record-success kademlia small-cfg) self 0x1 now tab)
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) self 0x0 tab)
  =.  lup  (~(learn kademlia small-cfg) self [0x2 0x3 ~] lup)
  =/  sent=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) lup)
  =/  timed=[table lookup]
    (~(timeout kademlia small-cfg) self 0x1 3 tab +.sent)
  =/  refilled=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) +.timed)
  =/  buc=bucket  (~(get-bucket kademlia small-cfg) 0 -.timed)
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
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) self 0x0 ~)
  =.  lup  (~(learn kademlia small-cfg) self [0x1 0x2 0x3 ~] lup)
  =/  sent=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) lup)
  =/  first=[table lookup]
    (~(receive kademlia small-cfg) self 0x1 now ~ ~ +.sent)
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
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) self 0x0 ~)
  =.  lup  (~(learn kademlia small-cfg) self [0x1 0x2 ~] lup)
  =/  sent=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) lup)
  =/  first=[table lookup]
    (~(receive kademlia small-cfg) self 0x1 now ~ ~ +.sent)
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
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) 0x0 0xf ~)
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
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) 0x0 0xf ~)
  =.  lup  (~(learn kademlia small-cfg) 0x0 [0x8 ~] lup)
  =/  success=[table lookup]
    (~(receive kademlia small-cfg) 0x0 0x8 now [0x1 ~] ~ lup)
  =/  failure=[table lookup]
    (~(timeout kademlia small-cfg) 0x0 0x8 1 ~ lup)
  ;:  weld
    %+  expect-eq  !>(`table`~)
    !>(-.success)
    %+  expect-eq  !>(lup)
    !>(+.success)
    %+  expect-eq  !>(`table`~)
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
  =/  lup=lookup  (~(start-lookup kademlia small-cfg) self 0x0 ~)
  =.  lup  (~(learn kademlia small-cfg) self [0x8 ~] lup)
  =/  sent=[(list node-id) lookup]  (~(dispatch kademlia small-cfg) lup)
  =/  out=[table lookup]
    (~(receive kademlia small-cfg) self 0x8 now [self too-wide 0x1 0x2 ~] ~ +.sent)
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
