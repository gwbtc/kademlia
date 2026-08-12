/-  *kademlia, *content-routing
/+  content-routing, *test
|%
::
++  allow
  |=  [signer=node-id message=digest signature=*]
  ^-  ?
  &
::
++  deny
  |=  [signer=node-id message=digest signature=*]
  ^-  ?
  |
::
++  http
  |=  url=@t
  ^-  locator
  [%http url]
::
++  test-cask-digest
  =/  a=(cask)  [%noun 42]
  =/  b=(cask)  [%json 42]
  =/  dig=digest  (digest-cask:content-routing a)
  ;:  weld
    (expect !>((digest-valid:content-routing dig)))
    (expect !>((verify-cask:content-routing dig a)))
    %+  expect-eq  !>(%.n)
    !>((verify-cask:content-routing dig b))
    (expect !>(!=((digest-cask:content-routing a) (digest-cask:content-routing b))))
    %+  expect-eq  !>(%.n)
    !>((digest-valid:content-routing (@uvI (pow 2 256))))
  ==
::
++  test-key-derivation
  =/  publisher=node-id  0x1234
  =/  a=key  (pointer-key:content-routing %app publisher %name)
  =/  b=key  (pointer-key:content-routing %other publisher %name)
  =/  dig=digest  (digest-cask:content-routing `(cask)`[%noun 42])
  =/  providers=key  (provider-key:content-routing dig)
  ;:  weld
    (expect !>((identity-valid:content-routing a)))
    (expect !>((identity-valid:content-routing providers)))
    (expect !>(!=(a b)))
    (expect !>(!=(a providers)))
  ==
::
++  test-locators
  =/  scry=locator  [%scry [~zod /g/x/1/example]]
  =/  web=locator  (http 'https://example.test/data')
  =/  custom=locator  [%custom %ipfs [%cid 0x1234]]
  =/  wide=locator  [%scry [(@p (pow 2 128)) /foo]]
  ;:  weld
    (expect !>((locator-valid:content-routing scry)))
    (expect !>((locator-valid:content-routing web)))
    (expect !>((locator-valid:content-routing custom)))
    %+  expect-eq  !>(%.n)
    !>((locator-valid:content-routing `locator`[%http '']))
    %+  expect-eq  !>(%.n)
    !>((locator-valid:content-routing `locator`[%custom %$ 0]))
    %+  expect-eq  !>(%.n)
    !>((locator-valid:content-routing wide))
    (expect !>((locators-valid:content-routing [scry web custom ~])))
    %+  expect-eq  !>(%.n)
    !>((locators-valid:content-routing ~))
  ==
::
++  test-targets
  =/  dig=digest  (digest-cask:content-routing `(cask)`[%noun 42])
  =/  web=locator  (http 'https://example.test/data')
  ;:  weld
    (expect !>((target-valid:content-routing `target`[%content dig])))
    (expect !>((target-valid:content-routing `target`[%direct ~ [web ~]])))
    (expect !>((target-valid:content-routing `target`[%direct `dig [web ~]])))
    %+  expect-eq  !>(%.n)
    !>((target-valid:content-routing `target`[%direct ~ ~]))
  ==
::
++  test-signing-domains
  =/  dig=digest  (digest-cask:content-routing `(cask)`[%noun 42])
  =/  pointer-body=pointer-body  [%app 0x12 0x34 1 ~ [%content dig]]
  =/  provider-body=provider-body
    [dig 0x34 1 ~2026.8.5 ~[(http 'https://example.test/data')]]
  ;:  weld
    (expect !>(!=((pointer-message:content-routing pointer-body) dig)))
    (expect !>(!=((provider-message:content-routing provider-body) dig)))
    %+  expect-eq  !>((pointer-message:content-routing pointer-body))
    !>((pointer-message:content-routing pointer-body))
  ==
::
++  test-pointer-selection
  =/  now=@da  ~2026.8.4
  =/  dig=digest  (digest-cask:content-routing `(cask)`[%noun 42])
  =/  old=pointer  [[%app 0x12 0x34 1 ~ [%content dig]] [1 0x1]]
  =/  newest=pointer  [[%app 0x12 0x34 2 `~2026.8.5 [%content dig]] [1 0x2]]
  =/  wrong=pointer  [[%other 0x12 0x34 9 ~ [%content dig]] [1 0x3]]
  ;:  weld
    %+  expect-eq  !>(`pointer-selection`[%found newest])
    !>((select-pointer:content-routing now %app 0x12 0x34 allow [old wrong newest ~]))
    %+  expect-eq  !>(`pointer-selection`[%none ~])
    !>((select-pointer:content-routing now %app 0x12 0x34 deny [newest ~]))
    (expect !>((pointer-valid:content-routing now %app 0x12 0x34 allow newest)))
    %+  expect-eq  !>(%.n)
    !>((pointer-valid:content-routing ~2026.8.5 %app 0x12 0x34 allow newest))
    (expect !>((pointer-valid:content-routing ~2100.1.1 %app 0x12 0x34 allow old)))
  ==
::
++  test-pointer-conflict
  =/  now=@da  ~2026.8.4
  =/  a=digest  (digest-cask:content-routing `(cask)`[%noun 1])
  =/  b=digest  (digest-cask:content-routing `(cask)`[%noun 2])
  =/  one=pointer  [[%app 0x12 0x34 7 ~ [%content a]] [1 0x1]]
  =/  duplicate=pointer  [[%app 0x12 0x34 7 ~ [%content a]] [1 0x2]]
  =/  conflict=pointer  [[%app 0x12 0x34 7 ~ [%content b]] [1 0x3]]
  ;:  weld
    %+  expect-eq  !>(`pointer-selection`[%found one])
    !>((select-pointer:content-routing now %app 0x12 0x34 allow [duplicate one ~]))
    %+  expect-eq  !>(`pointer-selection`[%conflict 7])
    !>((select-pointer:content-routing now %app 0x12 0x34 allow [one conflict ~]))
  ==
::
++  test-provider-selection
  =/  now=@da  ~2026.8.4
  =/  dig=digest  (digest-cask:content-routing `(cask)`[%noun 42])
  =/  low=provider
    [[dig 0x20 1 ~2026.8.5 ~[(http 'https://old.test/data')]] [1 0x1]]
  =/  high=provider
    [[dig 0x20 2 ~2026.8.6 ~[(http 'https://new.test/data')]] [1 0x2]]
  =/  other=provider
    [[dig 0x10 1 ~2026.8.5 ~[[%custom %ipfs [%cid 42]]]] [1 0x3]]
  =/  expired=provider
    [[dig 0x30 1 now ~[(http 'https://expired.test/data')]] [1 0x4]]
  =/  out=provider-selection
    (select-providers:content-routing now dig allow [low other expired high ~])
  =/  reordered=provider-selection
    (select-providers:content-routing now dig allow [high expired other low ~])
  ;:  weld
    %+  expect-eq  !>(`providers`[other high ~])
    !>(records.out)
    %+  expect-eq  !>(records.out)
    !>(records.reordered)
    %+  expect-eq  !>(`(set node-id)`~)
    !>(conflicts.out)
  ==
::
++  test-provider-conflict-isolated
  =/  now=@da  ~2026.8.4
  =/  dig=digest  (digest-cask:content-routing `(cask)`[%noun 42])
  =/  a=provider
    [[dig 0x20 4 ~2026.8.6 ~[(http 'https://a.test/data')]] [1 0x1]]
  =/  b=provider
    [[dig 0x20 4 ~2026.8.6 ~[(http 'https://b.test/data')]] [1 0x2]]
  =/  good=provider
    [[dig 0x10 1 ~2026.8.5 ~[(http 'https://good.test/data')]] [1 0x3]]
  =/  out=provider-selection
    (select-providers:content-routing now dig allow [a good b ~])
  ;:  weld
    %+  expect-eq  !>(`providers`[good ~])
    !>(records.out)
    (expect !>((~(has in conflicts.out) 0x20)))
    (expect !>(!(~(has in conflicts.out) 0x10)))
  ==
--
