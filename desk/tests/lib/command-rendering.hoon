::  Ensure Aqua's Dojo command path retains tagged command syntax.
::
/-  *kademlia-agent, *content-routing-agent
/+  *test
|%
++  test-kademlia-command-tag
  =/  value=command  [%set-seeds ~[~dev]]
  =/  rendered=tape  ":kademlia-example &kademlia-command {<value>}"
  %+  expect-eq  !>(%.y)
  !>(!=(~ (find "%set-seeds" rendered)))
::
++  test-content-command-tag
  =/  value=content-command
    :-  %find-providers
    [0v2 0v1.oinng.a74ba.t4pes.6mpjg.2utco.u5gg5.7m1cr.qjq8a.eioop.i05o2]
  =/  rendered=tape  ":kademlia-example &content-routing-command {<value>}"
  %+  expect-eq  !>(%.y)
  !>(!=(~ (find "%find-providers" rendered)))
::
++  test-find-providers-inferred-vase
  =/  raw
    :*  %find-providers
        0v2
        0v1.oinng.a74ba.t4pes.6mpjg.2utco.u5gg5.7m1cr.qjq8a.eioop.i05o2
    ==
  =/  value=content-command  !<(content-command !>(raw))
  %+  expect-eq  !>(%find-providers)
  !>(-.value)
--
