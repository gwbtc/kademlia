/-  *content-routing, cd=content-discovery, *content-store
/+  client=content-store-client, *test
|%
++  test-command-constructors
  =/  value=(cask)  [%noun 42]
  =/  put=content-store-command  (put:client 0v1 value [~ ~] `~h6)
  =/  get=content-store-command  (get-content:client 0v2 0v42)
  =/  name=content-store-command  (get-name:client 0v3 ~zod %demo %latest)
  =/  search=content-store-command  (search:client 0v4 ~[%software %urbit])
  ;:  weld
    %+  expect-eq
      !>(`content-store-command`[%put 0v1 value [~ ~] `~h6])
    !>(put)
    (expect !>(?=(%get -.get)))
    (expect !>(?=(%get -.name)))
    (expect !>(?=(%search -.search)))
  ==
::
++  test-start-orders-two-cards
  =/  command=content-store-command  (get-content:client 0v7 0v42)
  =/  cards=(list card:agent:gall)
    (start:client ~zod 0v7 %sink /reply command)
  %+  expect-eq  !>(2)
  !>((lent cards))
::
++  test-publication-option-constructors
  =/  name=named-publication  [%demo %latest 7]
  =/  topic=topic-publication  [~[%software %urbit] %catalog 12 3]
  ;:  weld
    %+  expect-eq  !>(`publication-options`[~ ~])
    !>(unnamed:client)
    %+  expect-eq  !>(`publication-options`[`name ~])
    !>((with-name:client %demo %latest 7))
    %+  expect-eq  !>(`publication-options`[~ `topic])
    !>((with-topic:client ~[%software %urbit] %catalog 12 3))
    %+  expect-eq  !>(`publication-options`[`name `topic])
    !>((with-name-and-topic:client name topic))
  ==
--
